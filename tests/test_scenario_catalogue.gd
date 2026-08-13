extends RefCounted
## Revision-1 rubric catalogue: every supported entry constructs, save-round-
## trips and fingerprints; unsupported identities stay absent.

const CATALOGUE_PATH: String = "res://presentation/dev/catalogue.gd"
const RUN_PATH: String = "user://glassvow_test_catalogue_run_v2.json"
const VIGIL_PATH: String = "user://glassvow_test_catalogue_vigil_v2.json"
const REF_PATH: String = "user://glassvow_test_catalogue_scenario.json"
const BUILD: String = "test-catalogue-sha"


static func run(fails: Array[String]) -> void:
	var script: Script = load(CATALOGUE_PATH) as Script
	if script == null:
		fails.append("catalogue: presentation/dev/catalogue.gd did not load")
		return
	var entries: Array[Dictionary] = _dicts(script.get("ENTRIES"))
	var unsupported: Array[Dictionary] = _dicts(script.get("UNSUPPORTED"))
	if entries.is_empty():
		fails.append("catalogue: ENTRIES is empty")
		return
	_contract(entries, unsupported, fails)
	var content: ContentDB = ContentDB.load_full()
	var kernel: ScenarioKernel = ScenarioKernel.new(content, RUN_PATH, VIGIL_PATH, REF_PATH)
	kernel.clear_profile()
	for entry: Dictionary in entries:
		_supported(kernel, content, entry, fails)
	kernel.clear_profile()


static func _contract(
	entries: Array[Dictionary], unsupported: Array[Dictionary], fails: Array[String]
) -> void:
	var named: Dictionary = {}
	for entry: Dictionary in entries:
		var id: String = str(entry.get("id", ""))
		if not _kebab(id):
			fails.append("catalogue: %s is not a kebab-case id" % id)
		if int(float(str(entry.get("revision", 0)))) != 1:
			fails.append("catalogue: %s is not revision 1" % id)
		if str(entry.get("description", "")).is_empty():
			fails.append("catalogue: %s is missing a one-line description" % id)
		if not ScenarioReference.CATALOGUE.has(id) \
				or int(float(str(ScenarioReference.CATALOGUE[id]))) != 1:
			fails.append("catalogue: CATALOGUE is missing %s@1" % id)
		var ov_v: Variant = entry.get("overrides", {})
		if typeof(ov_v) != TYPE_DICTIONARY:
			fails.append("catalogue: %s overrides are not a Dictionary" % id)
		else:
			var ov: Dictionary = ov_v
			for key_v: Variant in ov.keys():
				if not ScenarioReference.OVERRIDE_KEYS.has(str(key_v)):
					fails.append("catalogue: %s uses non-OVERRIDE_KEY %s" % [id, key_v])
		if named.has(id):
			fails.append("catalogue: duplicate id %s" % id)
		named[id] = true
	for id_v: Variant in ScenarioReference.CATALOGUE.keys():
		var id: String = str(id_v)
		if id != "custom" and not named.has(id):
			fails.append("catalogue: CATALOGUE has no recipe for %s" % id)
	for row: Dictionary in unsupported:
		var id: String = str(row.get("id", ""))
		if ScenarioReference.CATALOGUE.has(id) or named.has(id):
			fails.append("catalogue: unsupported %s must be absent" % id)
		if str(row.get("reason", "")).is_empty():
			fails.append("catalogue: unsupported %s is missing a reason" % id)
		var ghost: ScenarioReference = ScenarioReference.new()
		if ghost.load_from({"id": id, "revision": 1, "seed": 1, "build": BUILD}):
			fails.append("catalogue: unsupported %s loaded as a reference" % id)
		elif ghost.error.find("unknown Scenario") < 0:
			fails.append("catalogue: unsupported %s error was not explicit" % id)


static func _supported(
	kernel: ScenarioKernel, content: ContentDB, entry: Dictionary, fails: Array[String]
) -> void:
	var id: String = str(entry.get("id", ""))
	var marks: Dictionary = {}
	for loc: String in ScenarioReference.LOCALES:
		var ref: ScenarioReference = _ref(entry, loc)
		if not ref.error.is_empty():
			fails.append("catalogue %s %s: reference rejected: %s" % [id, loc, ref.error])
			return
		var first: RunState = kernel.construct(ref)
		if first == null:
			fails.append("catalogue %s %s: construct failed: %s" % [id, loc, kernel.last_error])
			return
		var mark: String = ScenarioKernel.fingerprint(first)
		var again: RunState = kernel.construct(ref)
		if again == null or ScenarioKernel.fingerprint(again) != mark:
			fails.append("catalogue %s %s: identical reference diverged" % [id, loc])
			return
		var encoded: Dictionary = ref.encode()
		var decoded: ScenarioReference = ScenarioReference.new()
		if not decoded.load_from(encoded) or decoded.identity() != "%s@1" % id:
			fails.append("catalogue %s %s: encode/decode failed" % [id, loc])
			return
		var disk: RunState = SaveService.load_run(content, RUN_PATH)
		if disk == null or ScenarioKernel.fingerprint(disk) != mark:
			fails.append("catalogue %s %s: save round-trip diverged" % [id, loc])
			return
		marks[loc] = mark
	if marks.has("en") and marks.has("zh-Hant") and marks["en"] != marks["zh-Hant"]:
		fails.append("catalogue %s: checkpoint must not depend on locale" % id)


static func _ref(entry: Dictionary, locale: String) -> ScenarioReference:
	var ov_v: Variant = entry.get("overrides", {})
	var ov: Dictionary = ov_v if typeof(ov_v) == TYPE_DICTIONARY else {}
	var ref: ScenarioReference = ScenarioReference.new()
	ref.load_from({
		"id": str(entry.get("id", "")),
		"revision": int(float(str(entry.get("revision", 1)))),
		"build": BUILD,
		"seed": int(float(str(entry.get("seed", 0)))),
		"locale": locale,
		"shape": "pad-landscape",
		"overrides": ov.duplicate(true),
	})
	return ref


static func _dicts(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(value) != TYPE_ARRAY:
		return out
	var rows: Array = value
	for row_v: Variant in rows:
		if typeof(row_v) == TYPE_DICTIONARY:
			out.append(row_v)
	return out


static func _kebab(id: String) -> bool:
	if id.is_empty() or id.begins_with("-") or id.ends_with("-") or id.find("--") >= 0:
		return false
	for i: int in range(id.length()):
		var code: int = id.unicode_at(i)
		var dash: bool = code == 45
		var digit: bool = code >= 48 and code <= 57
		var lower: bool = code >= 97 and code <= 122
		if not dash and not digit and not lower:
			return false
	return true
