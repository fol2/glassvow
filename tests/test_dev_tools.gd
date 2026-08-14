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
	_vigil_write(fails)
	_locale_apply(fails)
	_entries(fails)
	_console(fails)
	_vigil_scenario(fails)


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
	var stocked_v: Variant = boot.call("parse_scenario_arg", _arg({
		"id": "shop-stocked", "revision": 1,
	}))
	if not stocked_v is ScenarioReference:
		fails.append("dev tools: shop-stocked id-only was not parsed")
	else:
		var stocked: ScenarioReference = stocked_v
		if not stocked.error.is_empty():
			fails.append("dev tools: shop-stocked id-only rejected: %s" % stocked.error)
		elif stocked.seed != 18501 \
				or int(float(str(stocked.overrides.get("gold", 0)))) != 999 \
				or str(stocked.overrides.get("node", "")) != "9,3" \
				or int(float(str(stocked.overrides.get("act", -1)))) != 0:
			fails.append("dev tools: shop-stocked id-only missed the catalogue recipe")
	var miss_v: Variant = boot.call("parse_scenario_arg", _arg({
		"id": "no-such-scenario", "revision": 1,
	}))
	if not miss_v is ScenarioReference:
		fails.append("dev tools: unknown id-only was not a reference")
	else:
		var miss: ScenarioReference = miss_v
		if miss.error.is_empty():
			fails.append("dev tools: unknown id-only was accepted")
		elif miss.error.find("unknown") < 0:
			fails.append("dev tools: unknown id-only error was not explicit: %s" % miss.error)
	var bypass_v: Variant = boot.call("parse_scenario_arg", _arg({
		"id": "shop-stocked", "revision": 1, "seed": 7,
		"overrides": {"gold": 1},
	}))
	if not bypass_v is ScenarioReference:
		fails.append("dev tools: explicit shop-stocked was not parsed")
	else:
		var bypass: ScenarioReference = bypass_v
		if not bypass.error.is_empty():
			fails.append("dev tools: explicit shop-stocked rejected: %s" % bypass.error)
		elif bypass.seed != 7 \
				or int(float(str(bypass.overrides.get("gold", 0)))) != 1 \
				or bypass.overrides.has("node"):
			fails.append("dev tools: explicit seed/overrides still merged the catalogue")
	var ref_src: String = FileAccess.get_file_as_string(
		"res://application/scenario_reference.gd")
	if ref_src.find("ENTRIES") >= 0:
		fails.append("dev tools: ScenarioReference must not resolve catalogue ENTRIES")


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


static func _vigil_write(fails: Array[String]) -> void:
	var before_vigil: String = _snap(SaveService.VIGIL_PATH)
	var previous_locale: Locale = Locale.active
	var previous_preferences: Preferences = Preferences.active
	Preferences.active = Preferences.new()
	Preferences.active.language = "en"
	Locale.active = Locale.new(Locale.CODE_EN)
	var host: Main = _bare_main()
	var ref: ScenarioReference = ScenarioReference.new()
	ref.load_from({
		"id": "custom", "revision": 1, "build": "t", "seed": 18403,
		"locale": "en", "shape": "pad-landscape", "overrides": {},
	})
	if not host.apply_dev_scenario(ref):
		fails.append("dev tools: apply_dev_scenario failed: %s" % host.last_dev_error)
	elif host._vigil_save_path != ScenarioKernel.VIGIL_PATH:
		fails.append("dev tools: apply_dev_scenario did not bind the kernel Vigil path")
	else:
		host._vigil.whispers = 99
		if not host._store_vigil():
			fails.append("dev tools: redirected Vigil write failed")
		elif _snap(SaveService.VIGIL_PATH) != before_vigil:
			fails.append("dev tools: Console-routed Vigil write touched the player Vigil")
		else:
			var stored: VigilState = SaveService.load_vigil(host._vigil_save_path)
			if stored.whispers != 99:
				fails.append("dev tools: redirected Vigil write missed the Development profile")
	ScenarioKernel.new(host.content).clear_profile()
	host.free()
	Locale.active = previous_locale
	Preferences.active = previous_preferences


static func _locale_apply(fails: Array[String]) -> void:
	var apply_src: String = FileAccess.get_file_as_string("res://application/main.gd")
	var apply_at: int = apply_src.find("func apply_dev_scenario")
	var next_at: int = apply_src.find("\nfunc ", apply_at + 1)
	var body: String = apply_src.substr(apply_at, next_at - apply_at) if apply_at >= 0 else ""
	if body.find("Locale.active") < 0:
		fails.append("dev tools: apply_dev_scenario does not apply locale")
	if body.find("Preferences") >= 0:
		fails.append("dev tools: apply_dev_scenario must not touch Preferences")
	var before_run: String = _snap(SaveService.RUN_PATH)
	var before_vigil: String = _snap(SaveService.VIGIL_PATH)
	var previous_locale: Locale = Locale.active
	var previous_preferences: Preferences = Preferences.active
	Preferences.active = Preferences.new()
	Preferences.active.language = "en"
	Locale.active = Locale.new(Locale.CODE_EN)
	var host: Main = _bare_main()
	var with_loc: ScenarioReference = ScenarioReference.new()
	with_loc.load_from({
		"id": "custom", "revision": 1, "build": "t", "seed": 18404,
		"locale": "zh-Hant", "shape": "pad-landscape", "overrides": {},
	})
	if not host.apply_dev_scenario(with_loc):
		fails.append("dev tools: locale apply failed: %s" % host.last_dev_error)
	elif Locale.active.code != Locale.CODE_ZH_HANT:
		fails.append("dev tools: locale zh-Hant was not applied to Locale.active")
	elif Preferences.active.language != "en":
		fails.append("dev tools: scenario locale leaked into Preferences")
	Locale.active = Locale.new(Locale.CODE_ZH_HANT)
	var none: ScenarioReference = ScenarioReference.new()
	none.load_from({
		"id": "custom", "revision": 1, "build": "t", "seed": 18405,
		"shape": "pad-landscape", "overrides": {},
	})
	if not none.locale.is_empty():
		fails.append("dev tools: omitted locale was stored")
	elif not host.apply_dev_scenario(none):
		fails.append("dev tools: omitted-locale apply failed: %s" % host.last_dev_error)
	elif Locale.active.code != Locale.CODE_ZH_HANT:
		fails.append("dev tools: omitted locale overwrote Locale.active")
	if _snap(SaveService.RUN_PATH) != before_run \
			or _snap(SaveService.VIGIL_PATH) != before_vigil:
		fails.append("dev tools: locale apply mutated a production path")
	ScenarioKernel.new(host.content).clear_profile()
	host.free()
	Locale.active = previous_locale
	Preferences.active = previous_preferences


static func _arg(payload: Dictionary) -> PackedStringArray:
	return PackedStringArray(["--scenario=%s" % JSON.stringify(payload)])


static func _snap(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


static func _entries(fails: Array[String]) -> void:
	var previous: Variant = DevTools.forced
	var sfx: SfxBus = SfxBus.new()
	for want: bool in [false, true]:
		DevTools.forced = want
		var menu: RunMenuPanel = RunMenuPanel.new(StageShape.IDENTITY, false, sfx)
		var main: Main = _bare_main()
		main._show_title()
		var got: bool = _labelled(menu) and main._choice_screen != null \
				and _labelled(main._choice_screen)
		if got != want:
			fails.append("dev tools: entries %s when gate is %s" % [
				"present" if got else "absent", want])
		menu.free()
		main.free()
	DevTools.forced = previous


static func _console(fails: Array[String]) -> void:
	var before_run: String = _snap(SaveService.RUN_PATH)
	var before_vigil: String = _snap(SaveService.VIGIL_PATH)
	var script: GDScript = load(DevTools.CONSOLE) as GDScript
	if script == null:
		fails.append("dev tools: console script did not load")
		return
	var host: Main = _bare_main()
	for code: String in ["en", "zh-Hant"]:
		var previous: Locale = Locale.active
		Locale.active = Locale.new(StringName(code))
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://presentation/dev/locale/%s.json" % code))
		var bundle: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
		var banner: String = str(bundle.get("banner", ""))
		var console: Control = script.new(host, StageShape.IDENTITY)
		if banner.is_empty() or not _has_text(console, banner):
			fails.append("dev tools: %s banner missing" % code)
		if not _has_text(console, "custom@1"):
			fails.append("dev tools: %s catalogue row missing" % code)
		if not _has_text(console, "act-1-map-start@1"):
			fails.append("dev tools: %s named catalogue row missing" % code)
		if not _has_text(console, str(bundle.get("custom", "")).to_upper()):
			fails.append("dev tools: %s custom header missing" % code)
		if not _has_text(console, str(bundle.get("seed", ""))):
			fails.append("dev tools: %s seed field missing" % code)
		console.emit_signal("closed")
		console.free()
		Locale.active = previous
	host.free()
	if _snap(SaveService.RUN_PATH) != before_run \
			or _snap(SaveService.VIGIL_PATH) != before_vigil:
		fails.append("dev tools: console mutated a production path")


static func _vigil_scenario(fails: Array[String]) -> void:
	var before_run: String = _snap(SaveService.RUN_PATH)
	var before_vigil: String = _snap(SaveService.VIGIL_PATH)
	var host: Main = _bare_main()
	var ref: ScenarioReference = ScenarioReference.new()
	ref.load_from({
		"id": "vigil", "revision": 1, "build": "t", "seed": 18501,
		"locale": "en", "shape": "pad-landscape", "overrides": {"shards": 6},
	})
	if not host.apply_dev_scenario(ref):
		fails.append("dev tools: vigil Scenario failed: %s" % host.last_dev_error)
	elif not host._route_screen is VigilScreen:
		fails.append("dev tools: vigil Scenario did not open VigilScreen")
	elif host._vigil == null or host._vigil.shards.size() != 6 \
			or not host._vigil.unlocks.has("emberglass"):
		fails.append("dev tools: vigil Scenario did not plant the rose")
	elif host.game == null or host.game.run.shards.size() != 6:
		fails.append("dev tools: vigil Scenario left a stale run installed")
	ScenarioKernel.new(host.content).clear_profile()
	host.free()
	if _snap(SaveService.RUN_PATH) != before_run \
			or _snap(SaveService.VIGIL_PATH) != before_vigil:
		fails.append("dev tools: vigil Scenario mutated a production path")


static func _labelled(root: Node) -> bool:
	var script: GDScript = load(DevTools.CONSOLE) as GDScript
	return script != null and _has_text(root, str(script.call("entry_label")))


static func _has_text(root: Node, text: String) -> bool:
	if text.is_empty():
		return false
	for node: Node in root.find_children("", "Label", true, false):
		if (node as Label).text == text:
			return true
	for node: Node in root.find_children("", "Button", true, false):
		if (node as Button).text == text:
			return true
	return false


static func _bare_main() -> Main:
	var main: Main = Main.new()
	main.content = ContentDB.load_full()
	main._vigil = VigilState.blank()
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	return main
