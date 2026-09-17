extends RefCounted
## Observation only. Exact JSONL links detect damage, not external authority.
## H's host-authenticated manifest/receipts own native semantic provenance.

const SCHEMA: String = "DD1-ORDINARY-JOURNAL-2"
const SOURCE_PATHS: Array[String] = [
	"res://application/main.gd", "res://application/save_service.gd",
	"res://domain/game.gd", "res://domain/state/run_state.gd",
	"res://domain/state/vigil_state.gd", "res://domain/state/combat_state.gd",
	"res://domain/rules/combat.gd", "res://domain/rules/rewards.gd",
	"res://domain/rules/quests.gd", "res://tools/balance_pilot.gd",
	"res://tools/balance_policy.gd", "res://tools/vow_incentives.gd",
	"res://tests/support/dd1_native_driver_main.gd",
	"res://tests/support/dd1_native_main_route.gd",
	"res://tests/support/dd1_ordinary_capture.gd",
	"res://tests/support/dd1_route_journal.gd",
	"res://tests/support/dd1_unit_grant.gd",
]
var rows: Array[Dictionary] = []
var errors: Array[String] = []
var stack: Array[int] = []
var sink: String = ""
var raw_bytes: int = 0
var max_bytes: int = 67108864
var previous: String = ""
var host: WeakRef


func attach(main: Main) -> void:
	host = weakref(main)


func fail(reason: String) -> void:
	if not errors.has(reason):
		errors.append(reason)


func state() -> Dictionary:
	var main: Main = host.get_ref() if host != null else null
	if main == null:
		return {}
	var out: Dictionary = {"vigil": JSON.stringify(main._vigil.to_dict()), "run": null}
	if main.game == null or main.game.run == null:
		return out
	var game: GlassvowGame = main.game
	out["run"] = JSON.stringify(game.run.to_save_dict())
	out["run_id"] = game.run.run_id
	out["rng"] = str(game.run.rng.get_state())
	out["uid_next"] = game.run.uid
	out["act"] = game.run.act
	out["node_id"] = game.run.node_id
	out["map"] = main._map.to_dict() if main._map != null else null
	if game.cb != null:
		# The native projection includes player/enemies and all four UID zones.
		var combat: Dictionary = game.cb.to_dict()
		combat["object_id"] = str(game.cb.get_instance_id())
		combat["queue_size"] = game.cb.queue.size()
		combat["crosscut_anchor"] = game.cb.crosscut_anchor.idx if game.cb.crosscut_anchor != null else null
		out["combat"] = combat
	return out


func append_row(value: Dictionary) -> bool:
	if not errors.is_empty():
		return false
	var row: Dictionary = value.duplicate(true)
	row["seq"] = rows.size()
	row["previous"] = previous
	var body: String = JSON.stringify(row)
	var line: PackedByteArray = (body + "\n").to_utf8_buffer()
	if line.size() > max_bytes - raw_bytes:
		fail("journal_raw_limit")
		return false
	if not sink.is_empty():
		var mode: FileAccess.ModeFlags = FileAccess.READ_WRITE if FileAccess.file_exists(sink) else FileAccess.WRITE_READ
		var file: FileAccess = FileAccess.open(sink, mode)
		if file == null:
			fail("journal_open")
			return false
		file.seek_end()
		var offset: int = file.get_position()
		if offset != raw_bytes:
			file.close()
			fail("journal_external_change")
			return false
		file.store_buffer(line)
		file.flush()
		var error: Error = file.get_error()
		file.seek(offset)
		var readback: PackedByteArray = file.get_buffer(line.size())
		file.close()
		if error != OK or readback != line:
			fail("journal_write_readback")
			return false
	rows.append(row)
	raw_bytes += line.size()
	previous = body.sha256_text()
	return true


func begin(action: String, inputs: Dictionary = {}) -> int:
	var token: int = rows.size()
	if not append_row({"phase": "begin", "token": token,
			"parent": stack.back() if not stack.is_empty() else -1,
			"action": action, "inputs": inputs, "state": state()}):
		return -1  # No native action is permitted after a failed begin write.
	stack.append(token)
	return token


func finish(token: int, observed: Dictionary = {}) -> void:
	if token < 0 or stack.is_empty() or stack.back() != token:
		fail("unbalanced_observation")
		return
	stack.pop_back()
	append_row({"phase": "end", "token": token, "observed": observed, "state": state()})


func source_bytes(expected: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	var paths: Array = SOURCE_PATHS.duplicate()
	for path_v: Variant in expected:
		if not paths.has(str(path_v)):
			paths.append(str(path_v))
	for path_v: Variant in paths:
		var path: String = str(path_v)
		var sha: String = FileAccess.get_sha256(path)
		if sha.is_empty() or (not expected.is_empty() and expected.get(path) != sha):
			fail("source_unreadable_or_mismatched:" + path)
		result[path] = sha
	return result


func packet() -> Dictionary:
	var raw: String = FileAccess.get_file_as_string(sink) if not sink.is_empty() else ""
	if not sink.is_empty() and raw.to_utf8_buffer().size() != raw_bytes:
		fail("journal_final_readback")
	return {"schema": SCHEMA, "rows": rows.duplicate(true), "errors": errors.duplicate(),
		"open_actions": stack.duplicate(), "raw_bytes": raw_bytes,
		"last_link": previous, "sink": sink, "durable": not sink.is_empty(),
		"journal_bytes": raw}


class ObservedGame:
	extends GlassvowGame
	var observer: WeakRef

	func _init(original: GlassvowGame, main: Main) -> void:
		super(original.content, original.run)
		# Retain the exact live objects, RNG and laws; no replay or Pilot refit.
		rules = original.rules
		rewards = original.rewards
		quests = original.quests
		cb = original.cb
		last_ret = original.last_ret
		observer = weakref(main)

	func apply(cmd: Dictionary) -> Array[Dictionary]:
		var main: Variant = observer.get_ref()
		if main == null or not main.capture.errors.is_empty():
			return []
		var token: int = main.capture.begin("apply", cmd)
		if token < 0:
			return []
		var old: CombatState = cb
		if str(cmd.get("t", "")) == "startCombat" and not main.before_combat_start():
			main.capture.finish(token, {"denied": true})
			return []
		var events: Array[Dictionary] = super.apply(cmd)
		if str(cmd.get("t", "")) == "startCombat":
			main.after_combat_start(old)
		main.capture.finish(token, {"events": events.duplicate(true), "ret": last_ret})
		return events
