extends SceneTree
## Focused, frame-backed geometry and input contract for issue #167.
## Phone-landscape reachability for long choice lists lives in
## `choice_scroll_reachability.gd` (844×390). This harness keeps the relic
## wrap + input contract on the identity stage; the retired 390×844 window
## is no longer a shipping surface.

const PAD: Vector2i = Vector2i(1180, 820)
const RELIC_IDS: Array[String] = [
	"shatterersCrown", "hollowCrown", "crownOfTheHearth",
]

var _fails: Array[String] = []
var _viewport: SubViewport
var _capture_dir: String = ""
var _chosen_id: String = ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.trim_prefix("--capture-dir=")
	_viewport = SubViewport.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	call_deferred("_run")


func _run() -> void:
	for locale_code: StringName in [Locale.CODE_EN, Locale.CODE_ZH_HANT]:
		await _check_case(locale_code, &"pad-landscape", PAD)
	if _fails.is_empty():
		print("PASS boss relic choice containment (1180x820 en+zh-Hant)")
		quit(0)
	else:
		for failure: String in _fails:
			print("FAIL boss_relic_choice_containment: %s" % failure)
		quit(1)


func _check_case(locale_code: StringName, stage_shape: StringName,
		expected_size: Vector2i) -> void:
	var stage_size: Vector2i = StageShape.REFERENCES[stage_shape]
	_check(stage_size == expected_size,
		"%s keeps its authored %s reference" % [stage_shape, expected_size])
	_viewport.size = stage_size
	Locale.active = Locale.new(locale_code)
	var content: ContentDB = ContentDB.load_full(false)
	Locale.active.hydrate_content(content)
	var choices: Array[Dictionary] = []
	for id: String in RELIC_IDS:
		var relic: Dictionary = content.relics[id]
		choices.append({
			"id": id,
			"label": "%s\n%s" % [relic.name, relic.text],
			"hint": str(relic.text),
			"icon": "res://assets/art/relics/%s.png" % id,
		})
	choices.append({
		"id": "",
		"label": Locale.active.t("ui.reward.bossTakeNone"),
		"quiet": true,
	})
	var screen: ChoiceScreen = ChoiceScreen.new(
		Locale.active.t("ui.reward.bossCrownTitle"),
		Locale.active.t("ui.reward.bossCrownBody"), choices,
		{"shape": String(stage_shape)})
	_viewport.add_child(screen)
	await _settle()

	var case_name: String = "%s %s" % [locale_code, stage_shape]
	var stage: Rect2 = Rect2(Vector2.ZERO, Vector2(stage_size))
	var labels: Array[Label] = _labels(screen)
	var buttons: Array[Button] = _buttons(screen)
	print("EVIDENCE %s stage=%s panel=%s" % [
		case_name, stage, screen._panel.get_global_rect()])
	_check(labels.size() == 2, "%s has its heading and body" % case_name)
	_check(buttons.size() == 4, "%s has three relic rows and decline" % case_name)
	_check(stage.encloses(screen._panel.get_global_rect()),
		"%s panel stays inside the stage" % case_name)
	for label: Label in labels:
		_check(stage.encloses(label.get_global_rect()),
			"%s copy stays inside the stage: %s" % [case_name, label.text])
	for index: int in buttons.size():
		var button: Button = buttons[index]
		print("EVIDENCE %s choice=%d rect=%s minimum=%s wrap=%d" % [
			case_name, index, button.get_global_rect(), button.get_combined_minimum_size(),
			button.autowrap_mode])
		_check(stage.encloses(button.get_global_rect()),
			"%s choice %d stays inside the stage" % [case_name, index])
		_check(screen._panel.get_global_rect().encloses(button.get_global_rect()),
			"%s choice %d stays inside the panel" % [case_name, index])
		if index < RELIC_IDS.size():
			_check(button.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
				"%s relic choice %d wraps long copy" % [case_name, index])

	await _check_keyboard(case_name, buttons)
	await _check_mouse(case_name, screen, buttons, choices)
	await _capture("boss-relic-%s-%s" % [locale_code, stage_shape])
	_viewport.remove_child(screen)
	screen.free()


func _check_keyboard(case_name: String, buttons: Array[Button]) -> void:
	_check(_viewport.gui_get_focus_owner() == buttons[0],
		"%s opens with the first relic keyboard-focused" % case_name)
	for index: int in range(1, buttons.size()):
		await _action(&"ui_focus_next")
		_check(_viewport.gui_get_focus_owner() == buttons[index],
			"%s keyboard reaches choice %d" % [case_name, index])


func _check_mouse(case_name: String, screen: ChoiceScreen, buttons: Array[Button],
		choices: Array[Dictionary]) -> void:
	screen.chosen.connect(func(id: String) -> void: _chosen_id = id)
	for index: int in buttons.size():
		_chosen_id = "not-chosen"
		await _mouse_click(buttons[index].get_global_rect().get_center())
		_check(_chosen_id == str(choices[index].id),
			"%s mouse activates choice %d" % [case_name, index])


func _labels(node: Node) -> Array[Label]:
	var found: Array[Label] = []
	for candidate: Node in node.find_children("", "Label", true, false):
		var label: Label = candidate as Label
		if label != null:
			found.append(label)
	return found


func _buttons(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	for candidate: Node in node.find_children("", "Button", true, false):
		var button: Button = candidate as Button
		if button != null:
			found.append(button)
	return found


func _action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		_viewport.push_input(event)
		await process_frame


func _mouse_click(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	_viewport.push_input(motion, true)
	await process_frame
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		event.position = at
		event.global_position = at
		_viewport.push_input(event, true)
		await process_frame


func _settle() -> void:
	for frame: int in 5:
		await process_frame


func _capture(stem: String) -> void:
	if _capture_dir.is_empty():
		return
	if DisplayServer.get_name() == "headless":
		_check(false, "capture %s requires a headed renderer" % stem)
		return
	var image: Image = _viewport.get_texture().get_image()
	var path: String = _capture_dir.path_join("%s.png" % stem)
	if image == null or image.get_size() != _viewport.size:
		_check(false, "capture %s matches the stage" % stem)
		return
	var save_error: Error = image.save_png(path)
	_check(save_error == OK, "capture %s is written" % stem)
	if save_error == OK:
		print("CAPTURE %s" % path)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
