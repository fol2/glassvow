extends RefCounted
## Scenario kernel acceptance: deterministic fingerprints, both locales, save
## round-trips, production-profile isolation, and incoherent-state rejection.

const RUN_PATH: String = "user://glassvow_test_dev_run_v2.json"
const VIGIL_PATH: String = "user://glassvow_test_dev_vigil_v2.json"
const REF_PATH: String = "user://glassvow_test_dev_scenario.json"
const BUILD: String = "test-build-sha"


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var kernel: ScenarioKernel = ScenarioKernel.new(content, RUN_PATH, VIGIL_PATH, REF_PATH)
	kernel.clear_profile()
	_fingerprints(kernel, fails)
	_locales(kernel, fails)
	_round_trips(kernel, content, fails)
	_isolation(kernel, content, fails)
	_rejection(kernel, fails)
	_shards(kernel, fails)
	kernel.clear_profile()


static func _fingerprints(kernel: ScenarioKernel, fails: Array[String]) -> void:
	var ref: ScenarioReference = _custom(18301, {"gold": 40, "add_cards": ["cleave"]})
	var first: RunState = kernel.construct(ref)
	if first == null:
		fails.append("scenario fingerprint: construct failed: %s" % kernel.last_error)
		return
	var mark: String = ScenarioKernel.fingerprint(first)
	var again: RunState = kernel.construct(ref)
	if again == null or ScenarioKernel.fingerprint(again) != mark:
		fails.append("scenario fingerprint: identical reference diverged")
	var k2: ScenarioKernel = ScenarioKernel.new(kernel.content, RUN_PATH, VIGIL_PATH, REF_PATH)
	var reset: RunState = k2.reset()
	if reset == null or ScenarioKernel.fingerprint(reset) != mark:
		fails.append("scenario fingerprint: reset diverged")


static func _locales(kernel: ScenarioKernel, fails: Array[String]) -> void:
	var marks: Dictionary = {}
	for loc: String in ["en", "zh-Hant"]:
		var loc_ref: ScenarioReference = _custom(18302, {"hp": 12})
		loc_ref.locale = loc
		var run: RunState = kernel.construct(loc_ref)
		if run == null:
			fails.append("scenario locale %s: construct failed: %s" % [loc, kernel.last_error])
			continue
		if not Locale.new().set_language(StringName(loc)):
			fails.append("scenario locale %s: catalogue missing" % loc)
		marks[loc] = ScenarioKernel.fingerprint(run)
	if marks.has("en") and marks.has("zh-Hant") and marks["en"] != marks["zh-Hant"]:
		fails.append("scenario locale: run checkpoint must not depend on locale")


static func _round_trips(
	kernel: ScenarioKernel, content: ContentDB, fails: Array[String]
) -> void:
	var ref: ScenarioReference = _custom(18303, {
		"act": 1, "gold": 70, "add_relics": ["sweetRoot"], "upgrade_cards": ["strike"],
	})
	var encoded: Dictionary = ref.encode()
	var decoded: ScenarioReference = ScenarioReference.new()
	if not decoded.load_from(encoded) or decoded.identity() != "custom@1":
		fails.append("scenario reference: encode/decode failed")
		return
	var run: RunState = kernel.construct(decoded)
	if run == null:
		fails.append("scenario round-trip: construct failed: %s" % kernel.last_error)
		return
	if run.act != 1 or run.player.gold != 70 or not run.has_relic("sweetRoot"):
		fails.append("scenario round-trip: Custom Scenario controls were not applied")
	var disk: RunState = SaveService.load_run(content, RUN_PATH)
	if disk == null or ScenarioKernel.fingerprint(disk) != ScenarioKernel.fingerprint(run):
		fails.append("scenario round-trip: SaveService load diverged")
	var restarted: ScenarioKernel = ScenarioKernel.new(content, RUN_PATH, VIGIL_PATH, REF_PATH)
	var resumed: RunState = restarted.load_checkpoint()
	if resumed == null or ScenarioKernel.fingerprint(resumed) != ScenarioKernel.fingerprint(run):
		fails.append("scenario round-trip: process-restart load diverged")
	var next: ScenarioReference = _custom(18304, {})
	if restarted.switch_to(next) == null:
		fails.append("scenario switch: construct failed: %s" % restarted.last_error)
	elif ScenarioKernel.fingerprint(restarted.load_checkpoint()) == ScenarioKernel.fingerprint(run):
		fails.append("scenario switch: previous development checkpoint survived")


static func _isolation(
	kernel: ScenarioKernel, content: ContentDB, fails: Array[String]
) -> void:
	var before_run: String = _snap(SaveService.RUN_PATH)
	var before_vigil: String = _snap(SaveService.VIGIL_PATH)
	var plant: RunState = RunState.new_run(content, 7, "prod-isolation")
	SaveService.store(plant, SaveService.RUN_PATH)
	SaveService.store_vigil(VigilState.blank(), SaveService.VIGIL_PATH)
	var planted_run: String = _snap(SaveService.RUN_PATH)
	var planted_vigil: String = _snap(SaveService.VIGIL_PATH)
	var run: RunState = kernel.construct(_custom(18305, {"gold": 9}))
	kernel.reset()
	kernel.switch_to(_custom(18306, {}))
	kernel.clear_profile()
	if run == null:
		fails.append("scenario isolation: construct failed: %s" % kernel.last_error)
	if _snap(SaveService.RUN_PATH) != planted_run:
		fails.append("scenario isolation: production run path was mutated")
	if _snap(SaveService.VIGIL_PATH) != planted_vigil:
		fails.append("scenario isolation: production Vigil path was mutated")
	SaveService.clear(SaveService.RUN_PATH)
	SaveService.clear_vigil(SaveService.VIGIL_PATH)
	if not before_run.is_empty():
		var f: FileAccess = FileAccess.open(SaveService.RUN_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(before_run)
			f.close()
	if not before_vigil.is_empty():
		var vf: FileAccess = FileAccess.open(SaveService.VIGIL_PATH, FileAccess.WRITE)
		if vf != null:
			vf.store_string(before_vigil)
			vf.close()


static func _rejection(kernel: ScenarioKernel, fails: Array[String]) -> void:
	var blob: ScenarioReference = ScenarioReference.new()
	if blob.load_from({"v": 2, "player": {}, "seed": 1, "id": "custom", "revision": 1}):
		fails.append("scenario reject: save blob was accepted")
	var rev: ScenarioReference = ScenarioReference.new()
	if rev.load_from({"id": "custom", "revision": 99, "seed": 1, "build": BUILD}):
		fails.append("scenario reject: unsupported revision was accepted")
	elif rev.error.find("unsupported revision") < 0:
		fails.append("scenario reject: revision error was not explicit")
	if kernel.construct(_custom(18307, {"hp": 99, "max_hp": 10})) != null:
		fails.append("scenario reject: incoherent HP was accepted")
	if kernel.construct(_custom(18308, {"add_cards": ["not-a-card"]})) != null:
		fails.append("scenario reject: unknown card was accepted")
	if kernel.construct(_custom(18309, {"rng_state": 4})) != null:
		fails.append("scenario reject: raw RNG override was accepted")
	var act_four: RunState = kernel.construct(_custom(18310, {"act": 3, "shards": 6}))
	if act_four == null or act_four.act != 3:
		fails.append("scenario boundary: act 3 with six shards was not accepted")
	if kernel.construct(_custom(18311, {"act": 4})) != null:
		fails.append("scenario reject: act 4 index was accepted")


static func _shards(kernel: ScenarioKernel, fails: Array[String]) -> void:
	var counted: RunState = kernel.construct(_custom(18312, {"shards": 6}))
	if counted == null:
		fails.append("scenario shards: count 6 failed: %s" % kernel.last_error)
		return
	if counted.shards != VigilState.QUEST_IDS:
		fails.append("scenario shards: run did not carry the six quest ids")
	var vigil: VigilState = SaveService.load_vigil(VIGIL_PATH)
	if vigil.shards != VigilState.QUEST_IDS:
		fails.append("scenario shards: Vigil did not light the six panes")
	elif not vigil.unlocks.has("emberglass") or not vigil.unlocks.has("act4"):
		fails.append("scenario shards: Vigil unlocks missed emberglass or act4")
	var named: RunState = kernel.construct(_custom(18313, {
		"shards": ["hollowLamplighter", "paleOnes"],
	}))
	if named == null or named.shards != ["paleOnes", "hollowLamplighter"]:
		fails.append("scenario shards: id list was not canonicalised")
	var final_act: RunState = kernel.construct(_custom(18314, {"act": 3, "shards": 6}))
	if final_act == null or final_act.act != 3 or not final_act.is_final_act():
		fails.append("scenario shards: act 3 with six panes was not the final act")
	else:
		var road: WorldMap = WorldMap.from_dict(final_act.map)
		if road == null or road.nodes.size() != 5 or road.region != "rose_window":
			fails.append("scenario shards: act 3 did not sit on the authored map")
	if kernel.construct(_custom(18315, {"shards": 7})) != null \
			or kernel.last_error != "shards 7 is out of range":
		fails.append("scenario reject: shard count 7 was accepted")
	if kernel.construct(_custom(18318, {"act": 3})) != null \
			or kernel.last_error != "act 3 requires six shards":
		fails.append("scenario reject: act 3 without six shards was accepted")
	if kernel.construct(_custom(18319, {"act": 3, "shards": 5})) != null \
			or kernel.last_error != "act 3 requires six shards":
		fails.append("scenario reject: act 3 with five shards was accepted")
	if kernel.construct(_custom(18316, {"shards": ["not-a-quest"]})) != null \
			or kernel.last_error != "unknown shard not-a-quest":
		fails.append("scenario reject: unknown shard was accepted")
	if kernel.construct(_custom(18317, {"shards": ["paleOnes", "paleOnes"]})) != null \
			or kernel.last_error != "duplicate shard paleOnes":
		fails.append("scenario reject: duplicate shard was accepted")
	var again: RunState = kernel.construct(_custom(18312, {"shards": 6}))
	if again == null or ScenarioKernel.fingerprint(again) != ScenarioKernel.fingerprint(counted):
		fails.append("scenario shards: identical six-pane reference diverged")


static func _custom(seed: int, overrides: Dictionary) -> ScenarioReference:
	var ref: ScenarioReference = ScenarioReference.new()
	ref.load_from({
		"id": "custom", "revision": 1, "build": BUILD, "seed": seed,
		"locale": "en", "shape": "pad-landscape", "overrides": overrides,
	})
	return ref


static func _snap(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
