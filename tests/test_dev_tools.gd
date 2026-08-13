extends RefCounted
## DevTools gate, excluded boot parser, and Development-profile isolation.


static func run(fails: Array[String]) -> void:
	if not DevTools.available():
		fails.append("dev tools: available() is false in editor/headless checkout")
	var boot: GDScript = load(DevTools.BOOT) as GDScript
	if boot == null:
		fails.append("dev tools: boot handler did not load")
		return
	_parse(boot, fails)
	_isolation(fails)


static func _parse(boot: GDScript, fails: Array[String]) -> void:
	var good: Dictionary = {
		"id": "custom", "revision": 1, "build": "t", "seed": 1,
		"locale": "en", "shape": "pad-landscape", "overrides": {},
	}
	var ok_v: Variant = boot.call("parse_scenario_arg", _arg(good))
	if not ok_v is ScenarioReference:
		fails.append("dev tools: valid custom@1 was not parsed")
	else:
		var ok: ScenarioReference = ok_v
		if not ok.error.is_empty() or ok.identity() != "custom@1":
			fails.append("dev tools: valid custom@1 rejected: %s" % ok.error)
	var blob_v: Variant = boot.call("parse_scenario_arg", _arg({
		"v": 2, "player": {}, "id": "custom", "revision": 1,
	}))
	if blob_v is ScenarioReference:
		var blob: ScenarioReference = blob_v
		if blob.error.is_empty():
			fails.append("dev tools: save blob was accepted")
	var unk_v: Variant = boot.call("parse_scenario_arg", _arg({
		"id": "custom", "revision": 1, "overrides": {"rng_state": 4},
	}))
	if unk_v is ScenarioReference:
		var unk: ScenarioReference = unk_v
		if unk.error.is_empty():
			fails.append("dev tools: unknown override was accepted")
	if boot.call("parse_scenario_arg", PackedStringArray(["--seed=1"])) != null:
		fails.append("dev tools: absent flag was not null")


static func _isolation(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var before_run: String = _snap(SaveService.RUN_PATH)
	var before_vigil: String = _snap(SaveService.VIGIL_PATH)
	var kernel: ScenarioKernel = ScenarioKernel.new(content)
	kernel.clear_profile()
	var ref: ScenarioReference = ScenarioReference.new()
	ref.load_from({
		"id": "custom", "revision": 1, "build": "t", "seed": 18401,
		"locale": "en", "shape": "pad-landscape", "overrides": {"gold": 3},
	})
	var run: RunState = kernel.construct(ref)
	if run == null:
		fails.append("dev tools: construct failed: %s" % kernel.last_error)
	if _snap(SaveService.RUN_PATH) != before_run:
		fails.append("dev tools: production run path was mutated")
	if _snap(SaveService.VIGIL_PATH) != before_vigil:
		fails.append("dev tools: production Vigil path was mutated")
	kernel.clear_profile()


static func _arg(payload: Dictionary) -> PackedStringArray:
	return PackedStringArray(["--scenario=%s" % JSON.stringify(payload)])


static func _snap(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
