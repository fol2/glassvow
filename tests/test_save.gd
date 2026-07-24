extends RefCounted
## Save-loader semantics vs port_fixtures/saves/invalid-cases.json (the web
## _normaliseRunSnapshotForTest verdicts) + round-trip anchors from
## saves/snapshots.json, including a real SaveService file round-trip.
##
## The fixture raws are web-shaped (v:2 envelope); the port save lineage is
## v:1 with the same fields for everything the slice carries, so translation
## is a version offset plus a field copy — the reject/heal SEMANTICS are what
## the fixture pins, and those must match verdict-for-verdict.

const Diff: GDScript = preload("res://tests/support/diff.gd")


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_slice()
	_run_invalid_cases(content, fails)
	_run_snapshot_roundtrips(content, fails)


static func _run_invalid_cases(content: ContentDB, fails: Array[String]) -> void:
	var raw: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://port_fixtures/saves/invalid-cases.json")
	)
	if typeof(raw) != TYPE_DICTIONARY:
		fails.append("invalid-cases.json: parse failed")
		return
	var root: Dictionary = raw
	var cases: Array = root["cases"]
	for case_v: Variant in cases:
		var c: Dictionary = case_v
		var tag: String = str(c["tag"])
		var category: String = str(c["category"])
		var web_raw: Dictionary = c["raw"]
		var save: Dictionary = _port_save_from_web_raw(web_raw)
		var rs: RunState = RunState.from_save_dict(save, content)
		if category == "reject":
			if rs != null:
				fails.append("save %s: expected reject, loader accepted" % tag)
			continue
		if rs == null:
			fails.append("save %s: expected heal, loader rejected" % tag)
			continue
		var diverged: String = Diff.deep_eq(StateBuild.jsonish(rs.to_save_result_dict()), c["result"])
		if diverged != "":
			fails.append(
				"save %s: healed result diverges at %s\n      expected: %s\n      actual:   %s"
				% [
					tag, diverged, JSON.stringify(c["result"]).left(400),
					JSON.stringify(rs.to_save_result_dict()).left(400),
				]
			)


static func _run_snapshot_roundtrips(content: ContentDB, fails: Array[String]) -> void:
	var raw: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://port_fixtures/saves/snapshots.json")
	)
	if typeof(raw) != TYPE_DICTIONARY:
		fails.append("snapshots.json: parse failed")
		return
	var root: Dictionary = raw
	var snapshots: Array = root["snapshots"]
	for snap_v: Variant in snapshots:
		var entry: Dictionary = snap_v
		var seed: int = StateBuild.ji(entry["seed"])
		var snapshot: Dictionary = entry["snapshot"]
		# Result projection -> port save envelope -> loader -> projection.
		var save: Dictionary = snapshot.duplicate(true)
		save["v"] = 1
		save["map"] = {"nodes": []}
		var rs: RunState = RunState.from_save_dict(save, content)
		if rs == null:
			fails.append("save snapshot seed %d: loader rejected a valid snapshot" % seed)
			continue
		var diverged: String = Diff.deep_eq(StateBuild.jsonish(rs.to_save_result_dict()), snapshot)
		if diverged != "":
			fails.append("save snapshot seed %d: projection diverges at %s" % [seed, diverged])
			continue
		# Full file round-trip through SaveService.
		SaveService.clear()
		if not SaveService.store(rs):
			fails.append("save snapshot seed %d: SaveService.store failed" % seed)
			continue
		var reloaded: RunState = SaveService.load_run(content)
		if reloaded == null:
			fails.append("save snapshot seed %d: SaveService.load_run rejected its own save" % seed)
			continue
		var rt_diverged: String = Diff.deep_eq(
			StateBuild.jsonish(reloaded.to_save_result_dict()), snapshot
		)
		if rt_diverged != "":
			fails.append("save snapshot seed %d: file round-trip diverges at %s" % [seed, rt_diverged])
		SaveService.clear()


## Web v2 raw -> port v1 save: same save generation, one version offset.
## Absent fields stay absent (that is what the heal cases exercise).
static func _port_save_from_web_raw(web_raw: Dictionary) -> Dictionary:
	var save: Dictionary = {}
	if web_raw.has("v"):
		save["v"] = StateBuild.ji(web_raw["v"]) - 1
	for key: String in [
		"seed", "rngState", "act", "floorsClimbed", "aspect", "vow", "art",
		"reveals", "unlocks", "omens", "boon", "bossRelicAct", "shards", "map",
		"player", "pendingCombat", "pendingEnemyIds",
	]:
		if web_raw.has(key):
			save[key] = web_raw[key]
	return save
