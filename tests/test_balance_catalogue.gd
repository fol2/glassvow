extends RefCounted
## Candidate catalogue isolation and fail-closed #454 seed-contract checks.

const LIVE_FILE: String = "a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1"
const LIVE_SEMANTIC: String = "38e1f4f65901fefd4e6a0f6399c5f76d17355a19c8317f4714c33c9199dbe7aa"


static func run(fails: Array[String]) -> void:
	var before: String = FileAccess.get_sha256(ContentDB.FULL_PATH)
	var opened: Dictionary = BalanceCatalogue.open({})
	if opened.has("error"):
		fails.append("balance catalogue: default open failed: %s" % opened["error"])
		return
	var identity_v: Variant = opened["identity"]
	if typeof(identity_v) != TYPE_DICTIONARY:
		fails.append("balance catalogue: default identity missing")
		return
	var identity: Dictionary = identity_v
	if str(identity.get("contentFileSha256", "")) != before:
		fails.append("balance catalogue: default file SHA does not match live content")
	if str(identity.get("contentSemanticSha256", "")) != LIVE_SEMANTIC:
		fails.append("balance catalogue: semantic SHA expected %s got %s"
			% [LIVE_SEMANTIC, identity.get("contentSemanticSha256", "")])
	if before != LIVE_FILE:
		fails.append("balance catalogue: live file SHA expected %s got %s" % [LIVE_FILE, before])
	_check_stage(fails)
	_check_two_catalogues(fails, before)
	if FileAccess.get_sha256(ContentDB.FULL_PATH) != before:
		fails.append("balance catalogue: live content file changed")


static func _check_stage(fails: Array[String]) -> void:
	if BalanceCatalogue.stage_error({"stage": "f0-controls", "seed0": 5000, "runs": 1}).is_empty():
		fails.append("balance catalogue: F0 must reject acceptance seed 5000")
	if BalanceCatalogue.stage_error({"stage": "f0-controls", "seed0": 5200, "runs": 1}).is_empty():
		fails.append("balance catalogue: F0 must reject reserve seed 5200")
	if BalanceCatalogue.stage_error({"stage": "f0-mini-landscape", "seed0": 6100, "runs": 8,
			"rootSeed": 215}).is_empty():
		fails.append("balance catalogue: F0 must reject exam policy root 215")
	if BalanceCatalogue.stage_error({"stage": "exam", "seed0": 5600, "runs": 1,
			"rootSeed": 215}).is_empty():
		fails.append("balance catalogue: exam must reject fingerprint seeds")
	if not BalanceCatalogue.stage_error({"stage": "f0-controls", "seed0": 6000, "runs": 32,
			"rootSeed": 454}).is_empty():
		fails.append("balance catalogue: F0 controls 6000–6031 / root 454 must pass")
	if not BalanceCatalogue.stage_error({"stage": "fingerprint", "seed0": 5600, "runs": 64}).is_empty():
		fails.append("balance catalogue: fingerprint 5600–5663 must pass")
	var missing: Dictionary = BalanceCatalogue.open({"content": "/no/such/glassvow-candidate.json"})
	if not missing.has("error"):
		fails.append("balance catalogue: missing candidate path must fail closed")


static func _check_two_catalogues(fails: Array[String], live_sha: String) -> void:
	var raw_v: Variant = JSON.parse_string(FileAccess.get_file_as_string(ContentDB.FULL_PATH))
	if typeof(raw_v) != TYPE_DICTIONARY:
		fails.append("balance catalogue: live content did not parse")
		return
	var raw: Dictionary = raw_v
	var left_raw: Dictionary = raw.duplicate(true)
	var right_raw: Dictionary = raw.duplicate(true)
	var left_player: Dictionary = left_raw["player"]
	var right_player: Dictionary = right_raw["player"]
	var left_aspects: Array = left_raw["aspects"]
	var right_aspects: Array = right_raw["aspects"]
	var left_aspect: Dictionary = left_aspects[0]
	var right_aspect: Dictionary = right_aspects[0]
	left_player["maxHp"] = int(float(str(left_player["maxHp"]))) + 2
	right_player["maxHp"] = int(float(str(right_player["maxHp"]))) + 4
	left_aspect["maxHp"] = int(float(str(left_aspect["maxHp"]))) + 2
	right_aspect["maxHp"] = int(float(str(right_aspect["maxHp"]))) + 4
	var left_path: String = "user://balance-456-left.json"
	var right_path: String = "user://balance-456-right.json"
	_write_json(left_path, left_raw)
	_write_json(right_path, right_raw)
	var left: Dictionary = BalanceCatalogue.open({"content": left_path})
	var right: Dictionary = BalanceCatalogue.open({"content": right_path})
	if left.has("error") or right.has("error"):
		fails.append("balance catalogue: candidate open failed: %s / %s"
			% [left.get("error", ""), right.get("error", "")])
		return
	var left_id_v: Variant = left["identity"]
	var right_id_v: Variant = right["identity"]
	if typeof(left_id_v) != TYPE_DICTIONARY or typeof(right_id_v) != TYPE_DICTIONARY:
		fails.append("balance catalogue: candidate identity missing")
		return
	var left_id: Dictionary = left_id_v
	var right_id: Dictionary = right_id_v
	if str(left_id.get("contentFileSha256", "")) == str(right_id.get("contentFileSha256", "")):
		fails.append("balance catalogue: two candidates produced the same file SHA")
	if str(left_id.get("contentFileSha256", "")) == live_sha \
			or str(right_id.get("contentFileSha256", "")) == live_sha:
		fails.append("balance catalogue: candidate SHA collapsed onto the live file")
	var left_db: ContentDB = BalanceCatalogue.load_prepared(left)
	var right_db: ContentDB = BalanceCatalogue.load_prepared(right)
	if left_db == null or right_db == null:
		fails.append("balance catalogue: candidate ContentDB was null")
		return
	if int(float(str(left_db.player.get("maxHp", 0)))) == int(float(str(right_db.player.get("maxHp", 0)))):
		fails.append("balance catalogue: two candidates observed one maxHp")
	var live: ContentDB = ContentDB.load_full(false)
	if live == null or int(float(str(live.player.get("maxHp", 0)))) == int(float(str(left_db.player.get("maxHp", 0)))):
		fails.append("balance catalogue: live catalogue was replaced by a candidate")


static func _write_json(path: String, value: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(value))
