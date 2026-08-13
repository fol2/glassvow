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
	_entries(fails)
	_console(fails)


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
