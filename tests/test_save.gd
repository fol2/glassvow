extends RefCounted
## Save-loader semantics vs port_fixtures/saves/invalid-cases.json (the web
## _normaliseRunSnapshotForTest verdicts) + round-trip anchors from
## saves/snapshots.json, including a real SaveService file round-trip.
##
## The fixture raws and the port now share the v2 envelope. The fixture omits
## runId from its result projection, so the adapter supplies one stable id.

const Diff: GDScript = preload("res://tests/support/diff.gd")
const TEST_RUN_PATH: String = "user://glassvow_test_run_v2.json"
const TEST_VIGIL_PATH: String = "user://glassvow_test_vigil_v2.json"


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_slice()
	_run_invalid_cases(content, fails)
	_run_snapshot_roundtrips(content, fails)
	_run_transaction_checkpoints(content, fails)
	_run_terminal_receipt(content, fails)
	_pre_rename_vigil_still_loads(fails)


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
		save["v"] = 2
		save["runId"] = "run-fixture-%d" % seed
		save["map"] = {"nodes": [], "visited": []}
		var rs: RunState = RunState.from_save_dict(save, content)
		if rs == null:
			fails.append("save snapshot seed %d: loader rejected a valid snapshot" % seed)
			continue
		var diverged: String = Diff.deep_eq(StateBuild.jsonish(rs.to_save_result_dict()), snapshot)
		if diverged != "":
			fails.append("save snapshot seed %d: projection diverges at %s" % [seed, diverged])
			continue
		# Full file round-trip through SaveService.
		SaveService.clear(TEST_RUN_PATH)
		if not SaveService.store(rs, TEST_RUN_PATH):
			fails.append("save snapshot seed %d: SaveService.store failed" % seed)
			continue
		var reloaded: RunState = SaveService.load_run(content, TEST_RUN_PATH)
		if reloaded == null:
			fails.append("save snapshot seed %d: SaveService.load_run rejected its own save" % seed)
			continue
		var rt_diverged: String = Diff.deep_eq(
			StateBuild.jsonish(reloaded.to_save_result_dict()), snapshot
		)
		if rt_diverged != "":
			fails.append("save snapshot seed %d: file round-trip diverges at %s" % [seed, rt_diverged])
		SaveService.clear(TEST_RUN_PATH)


## Absent fields stay absent (that is what the heal cases exercise).
static func _port_save_from_web_raw(web_raw: Dictionary) -> Dictionary:
	var save: Dictionary = {}
	if web_raw.has("v"):
		save["v"] = StateBuild.ji(web_raw["v"])
	save["runId"] = "run-fixture-invalid-cases"
	for key: String in [
		"seed", "rngState", "act", "floorsClimbed", "aspect", "vow", "art",
		"reveals", "unlocks", "omens", "boon", "boonReceipt", "bossRelicAct", "shards", "map",
		"player", "nodeId", "monument", "quests", "questScratch", "questCompletions",
		"stats", "pendingCombat", "pendingEnemyIds", "pendingQuestId",
		"pendingReward", "pendingRunEnd", "pendingDawn", "pendingHollow",
		"pendingHollowRoute",
	]:
		if web_raw.has(key):
			save[key] = web_raw[key]
	return save


## One table guards the four transaction checkpoints where a lost write would
## duplicate or skip player progress. It also carries the two broad reject
## classes: an unknown id and an impossible pending combination.
static func _run_transaction_checkpoints(content: ContentDB, fails: Array[String]) -> void:
	var base: RunState = RunState.new_run(content, 717, "run-transaction-table")
	var cases: Array[Dictionary] = [
		{
			"tag": "frozen pending combat",
			"patch": {"pendingCombat": "monster", "pendingEnemyIds": ["duskfang"]},
			"accept": true,
		},
		{
			"tag": "partially claimed reward",
			"patch": {"pendingReward": {
				"kind": "monster",
				"rewards": {"gold": 17, "cards": ["strike"], "potion": "healing", "relic": null},
				"taken": {"gold": true, "potion": false, "relic": false, "card": false},
				"perfect": false,
			}},
			"accept": true,
		},
		{
			# D1's payload (reward-embers-3d-plan § cross-lane): the reward
			# remembers what died. Additive — the case above, without it,
			# stays the old-save proof.
			"tag": "reward carrying the slain enemy",
			"patch": {"pendingReward": {
				"kind": "monster",
				"rewards": {"gold": 9, "cards": ["strike"], "potion": null, "relic": null},
				"taken": {"gold": false, "potion": false, "relic": false, "card": false},
				"perfect": false,
				"slain_enemy": {"id": "gloomslime", "hue": 130},
			}},
			"accept": true,
		},
		{
			"tag": "terminal dawn cursor",
			"patch": {"pendingDawn": {"events": [{"t": "questComplete"}], "cursor": 1, "newUnlocks": []}},
			"accept": true,
		},
		{
			"tag": "pending scene cursor",
			"patch": {"pendingScene": {"id": "opening", "cursor": 3}},
			"accept": true,
		},
		{
			"tag": "hollow bequest",
			"patch": {
				"pendingHollow": {"nodeId": "3,2", "type": "event", "paid": false},
				"monument": {"act": 1, "row": 4, "bequest": {"kind": "gold", "amount": 25}, "claimed": false},
			},
			"accept": true,
		},
		{
			"tag": "unknown pending enemy",
			"patch": {"pendingCombat": "monster", "pendingEnemyIds": ["not-an-enemy"]},
			"accept": false,
		},
		{
			"tag": "reward and combat conflict",
			"patch": {
				"pendingCombat": "monster",
				"pendingEnemyIds": ["duskfang"],
				"pendingReward": {
					"kind": "monster",
					"rewards": {"gold": 1, "cards": ["strike"], "potion": null, "relic": null},
					"taken": {"gold": false, "potion": false, "relic": false, "card": false},
					"perfect": false,
				},
			},
			"accept": false,
		},
	]
	for case: Dictionary in cases:
		var save: Dictionary = base.to_save_dict()
		var patch: Dictionary = case["patch"]
		save.merge(patch, true)
		var loaded: RunState = RunState.from_save_dict(save, content)
		if (loaded != null) != case["accept"]:
			fails.append("save transaction %s: expected accept=%s" % [case["tag"], case["accept"]])
			continue
		if loaded != null:
			SaveService.clear(TEST_RUN_PATH)
			if not SaveService.store(loaded, TEST_RUN_PATH):
				fails.append("save transaction %s: atomic store failed" % case["tag"])
			elif SaveService.load_run(content, TEST_RUN_PATH) == null:
				fails.append("save transaction %s: stored checkpoint did not reload" % case["tag"])
			SaveService.clear(TEST_RUN_PATH)


static func _run_terminal_receipt(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = RunState.new_run(content, 818, "run-exactly-once")
	run.act = 1
	run.waystones_lit = 4
	run.stats["slain"] = 3
	run.quests["ownShade"] = {"state": "complete", "progress": 1, "memory": {}}
	run.quest_scratch["ownShade"] = {"fall": {
		"act": 1,
		"row": 4,
		"shadeAspect": 0,
		"bequest": {"kind": "gold", "amount": 25},
	}}
	var vigil: VigilState = VigilState.blank()
	if not vigil.commit_run(run, "death", content) or not vigil.commit_run(run, "death", content):
		fails.append("vigil receipt: retry was not accepted")
		return
	if vigil.deeds["runs"] != 1 or vigil.deeds["slain"] != 3:
		fails.append("vigil receipt: terminal deeds applied more than once")
	if vigil.shards != ["ownShade"]:
		fails.append("vigil receipt: shard applied more than once")
	if typeof(vigil.last_fall) != TYPE_DICTIONARY \
			or vigil.last_fall.get("bequest") != {"kind": "gold", "amount": 25}:
		fails.append("vigil receipt: standing bequest was not preserved")
	SaveService.clear_vigil(TEST_VIGIL_PATH)
	if not SaveService.store_vigil(vigil, TEST_VIGIL_PATH):
		fails.append("vigil receipt: atomic store failed")
	else:
		var reloaded: VigilState = SaveService.load_vigil(TEST_VIGIL_PATH)
		if not reloaded.commit_run(run, "death", content) or reloaded.deeds["runs"] != 1:
			fails.append("vigil receipt: persisted retry was not idempotent")
	SaveService.clear_vigil(TEST_VIGIL_PATH)


## #305 D2: neither envelope bumps. A v2 vigil written with `bestFloor` still
## loads; `bestWaystone` heals to 0 and every neighbouring field survives.
static func _pre_rename_vigil_still_loads(fails: Array[String]) -> void:
	var seeded: VigilState = VigilState.blank()
	seeded.unlocks = ["card:quakeblow"]
	seeded.vow_unlocked = 2
	seeded.runs_played = 7
	seeded.whispers = 4
	seeded.shards = ["paleOnes"]
	seeded.deeds["slain"] = 11
	seeded.deeds["wins"] = 2
	seeded.deeds["bestVow"] = 1
	seeded.news = true
	var raw: Dictionary = seeded.to_dict()
	if int(float(str(raw.get("v", -1)))) != VigilState.VERSION:
		fails.append("pre-rename vigil: envelope is not v2")
		return
	var deeds_v: Variant = raw["deeds"]
	if typeof(deeds_v) != TYPE_DICTIONARY:
		fails.append("pre-rename vigil: to_dict deeds was not a dictionary")
		return
	var deeds: Dictionary = deeds_v
	deeds.erase("bestWaystone")
	deeds["bestFloor"] = 42
	raw["deeds"] = deeds
	var parsed: VigilState = VigilState.from_dict(raw)
	if parsed == null:
		fails.append("pre-rename vigil: from_dict rejected a v2 file with bestFloor")
		return
	SaveService.clear_vigil(TEST_VIGIL_PATH)
	var tmp_path: String = TEST_VIGIL_PATH + ".tmp"
	var f: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		fails.append("pre-rename vigil: could not write fixture")
		return
	f.store_string(JSON.stringify(raw))
	f.flush()
	f.close()
	if DirAccess.rename_absolute(
			ProjectSettings.globalize_path(tmp_path),
			ProjectSettings.globalize_path(TEST_VIGIL_PATH)) != OK:
		fails.append("pre-rename vigil: could not place fixture")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
		return
	var loaded: VigilState = SaveService.load_vigil(TEST_VIGIL_PATH)
	SaveService.clear_vigil(TEST_VIGIL_PATH)
	if int(float(str(loaded.deeds.get("bestWaystone", -1)))) != 0:
		fails.append("pre-rename vigil: bestWaystone healed to %s, not 0" % [
			loaded.deeds.get("bestWaystone")])
	if loaded.deeds.has("bestFloor"):
		fails.append("pre-rename vigil: bestFloor leaked into live deeds")
	if loaded.unlocks != ["card:quakeblow"] or loaded.vow_unlocked != 2 \
			or loaded.runs_played != 7 or loaded.whispers != 4 \
			or loaded.shards != ["paleOnes"] or loaded.news != true \
			or int(float(str(loaded.deeds["slain"]))) != 11 \
			or int(float(str(loaded.deeds["wins"]))) != 2 \
			or int(float(str(loaded.deeds["bestVow"]))) != 1:
		fails.append("pre-rename vigil: neighbouring fields did not survive")
