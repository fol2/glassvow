extends RefCounted
## Observation only. Hash links detect damaged captures, NOT external authority.
## The host still supplies H's authenticated evidence-boundary context.

const SCHEMA: String = "DD1-ORDINARY-JOURNAL-2"
const SOURCE_PATHS: Array[String] = [
	"res://application/main.gd", "res://application/save_service.gd",
	"res://domain/game.gd", "res://tools/balance_pilot.gd",
	"res://tests/support/dd1_native_driver_main.gd",
	"res://tests/support/dd1_native_main_route.gd",
	"res://tests/support/dd1_ordinary_capture.gd",
	"res://tests/support/dd1_route_journal.gd",
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
	var out: Dictionary = {"vigil": JSON.stringify(main._vigil.to_dict())}
	if main.game == null or main.game.run == null:
		out["run"] = null
		return out
	var game: GlassvowGame = main.game
	out["run"] = JSON.stringify(game.run.to_save_dict())
	out["run_id"] = game.run.run_id
	out["rng"] = str(game.run.rng.get_state())
	out["act"] = game.run.act
	out["node_id"] = game.run.node_id
	out["map"] = main._map.to_dict() if main._map != null else null
	if game.cb != null:
		var hand: Array = []
		for card: CardInst in game.cb.hand:
			hand.append({"uid": str(card.uid), "id": str(card.id), "up": card.up})
		var enemies: Array = []
		for enemy: EnemyCombatant in game.cb.enemies:
			enemies.append({"hp": enemy.hp, "max_hp": enemy.max_hp,
				"block": enemy.block, "chips": enemy.chips,
				"staggered": enemy.staggered, "statuses": enemy.statuses.duplicate(true)})
		out["combat"] = {"object_id": str(game.cb.get_instance_id()),
			"turn": game.cb.turn, "over": game.cb.over, "result": str(game.cb.result),
			"hand": hand, "enemies": enemies, "energy": game.cb.player.energy,
			"queue_size": game.cb.queue.size()}
	return out


func append_row(value: Dictionary) -> void:
	if not errors.is_empty():
		return
	var row: Dictionary = value.duplicate(true)
	row["seq"] = rows.size()
	row["previous"] = previous
	var body: String = JSON.stringify(row)
	var line: String = body + "\n"
	var size: int = line.to_utf8_buffer().size()
	if size > max_bytes - raw_bytes:
		fail("journal_raw_limit")
		return
	if not sink.is_empty():
		var mode: FileAccess.ModeFlags = FileAccess.READ_WRITE if FileAccess.file_exists(sink) else FileAccess.WRITE_READ
		var file: FileAccess = FileAccess.open(sink, mode)
		if file == null:
			fail("journal_open")
			return
		file.seek_end()
		var offset: int = file.get_position()
		file.store_buffer(line.to_utf8_buffer())
		file.flush()
		var error: Error = file.get_error()
		file.seek(offset)
		var readback: PackedByteArray = file.get_buffer(size)
		file.close()
		if error != OK or readback != line.to_utf8_buffer():
			fail("journal_write_readback")
			return
	rows.append(row)
	raw_bytes += size
	previous = body.sha256_text()


func begin(action: String, inputs: Dictionary = {}) -> int:
	var token: int = rows.size()
	append_row({"phase": "begin", "token": token,
		"parent": stack.back() if not stack.is_empty() else -1,
		"action": action, "inputs": inputs, "state": state()})
	stack.append(token)
	return token


func finish(token: int, observed: Dictionary = {}) -> void:
	if stack.is_empty() or stack.back() != token:
		fail("unbalanced_observation")
		return
	stack.pop_back()
	append_row({"phase": "end", "token": token, "observed": observed, "state": state()})


func source_bytes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in SOURCE_PATHS:
		var digest: String = FileAccess.get_sha256(path)
		if digest.is_empty():
			fail("source_unreadable:" + path)
		result[path] = digest
	return result


func packet() -> Dictionary:
	return {"schema": SCHEMA, "rows": rows.duplicate(true), "errors": errors.duplicate(),
		"open_actions": stack.duplicate(), "raw_bytes": raw_bytes,
		"last_link": previous, "sink": sink, "durable": not sink.is_empty(),
		"journal_bytes": FileAccess.get_file_as_string(sink) if not sink.is_empty() else ""}


class ObservedGame:
	extends GlassvowGame
	var observer: WeakRef

	func _init(original: GlassvowGame, main: Main) -> void:
		super(original.content, original.run)
		# Preserve the exact live objects; do not reinitialise RNG, policies or laws.
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
		var old: CombatState = cb
		if str(cmd.get("t", "")) == "startCombat" and not main.before_combat_start():
			main.capture.finish(token, {"denied": true})
			return []
		var events: Array[Dictionary] = super.apply(cmd)
		if str(cmd.get("t", "")) == "startCombat":
			main.after_combat_start(old)
		main.capture.finish(token, {"events": events.duplicate(true), "ret": last_ret})
		return events
