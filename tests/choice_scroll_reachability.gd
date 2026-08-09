extends SceneTree
## Headless geometry contract for #72. This is intentionally a separately-run
## test rather than a discovered test_*.gd: the suite's synchronous runner must
## stay at PASS (17 tests), while focus-follow needs real process frames.

const STAGE_SIZE: Vector2i = Vector2i(844, 390)

var _fails: Array[String] = []
var _mutate_follow_focus: bool = false
var _mutate_boon_height: bool = false
var _viewport: SubViewport
var _confirmed: bool = false
var _chosen_id: String = ""
var _embarked: bool = false
var _capture_dir: String = ""

func _initialize() -> void:
	_mutate_follow_focus = "--mutate-follow-focus" in OS.get_cmdline_user_args()
	_mutate_boon_height = "--mutate-boon-height" in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.trim_prefix("--capture-dir=")
	_viewport = SubViewport.new()
	_viewport.size = STAGE_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	call_deferred("_run")

func _run() -> void:
	Locale.active = Locale.new(Locale.CODE_EN)
	await _check_embark()
	await _check_lamplighter_keyboard()
	await _check_lamplighter_mouse_drag()
	await _check_lamplighter_portrait()
	for count: int in [6, 7, 8]:
		await _check_plain_choices(count)
	if _fails.is_empty():
		print("PASS choice scroll reachability (844x390)")
		quit(0)
	else:
		for failure: String in _fails:
			print("FAIL choice_scroll_reachability: %s" % failure)
		quit(1)

func _check_embark() -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var screen: EmbarkScreen = EmbarkScreen.new(
		content.aspects, content.vows, false, 0, false,
		0, 0, &"phone-landscape")
	_hide_backdrop(screen)
	_viewport.add_child(screen)
	await _settle()
	var scroll: ScrollContainer = _vertical_scrolls(screen)[0]
	_check(_viewport.gui_get_focus_owner() == screen._begin,
		"Embark opens with its primary action focused")
	_check_inside("keyboard-focused Embark primary action", screen._begin, scroll)
	await _capture("embark")
	_embarked = false
	screen.begin_requested.connect(func(_aspect: int, _vow: int) -> void:
		_embarked = true)
	await _action(&"ui_accept")
	_check(_embarked, "keyboard-focused Embark primary action activates")
	_drop(screen)

func _check_lamplighter_keyboard() -> void:
	var screen: LamplighterScreen = _lamplighter()
	_viewport.add_child(screen)
	await _settle()
	var scroll: ScrollContainer = _vertical_scrolls(screen)[0]
	if _mutate_follow_focus:
		scroll.follow_focus = false
	if _mutate_boon_height:
		for button: Button in screen._boon_buttons.values():
			button.custom_minimum_size.y = 100
		await _settle()
	_check_boon_copy_clear(screen, "phone-landscape")
	var first_boon: Button = screen._boon_buttons[screen._boon_ids[0]]
	screen._select_boon(screen._boon_ids[0])
	first_boon.grab_focus()
	await process_frame
	await _focus_until(screen._begin)
	var focused: Control = _viewport.gui_get_focus_owner()
	_check(focused == screen._begin, "keyboard reaches CHOOSE A BOON")
	_check_inside("keyboard-focused CHOOSE A BOON", screen._begin, scroll)
	await _capture("lamplighter-keyboard")
	_confirmed = false
	screen.confirmed.connect(func(_boon: String, _art: StringName) -> void:
		_confirmed = true)
	await _action(&"ui_accept")
	_check(_confirmed, "keyboard-focused CHOOSE A BOON activates")
	_drop(screen)

func _check_lamplighter_portrait() -> void:
	_viewport.size = Vector2i(390, 844)
	var screen: LamplighterScreen = _lamplighter(&"phone-portrait")
	_viewport.add_child(screen)
	await _settle()
	_check_boon_copy_clear(screen, "phone-portrait")
	await _capture("lamplighter-portrait")
	_drop(screen)
	_viewport.size = STAGE_SIZE

func _check_lamplighter_mouse_drag() -> void:
	var screen: LamplighterScreen = _lamplighter()
	_viewport.add_child(screen)
	await _settle()
	var scroll: ScrollContainer = _vertical_scrolls(screen)[0]
	screen._select_boon(screen._boon_ids[0])
	var bar_rect: Rect2 = scroll.get_v_scroll_bar().get_global_rect()
	var drag_from: Vector2 = bar_rect.position + Vector2(bar_rect.size.x * 0.5, 40.0)
	var drag_to: Vector2 = bar_rect.position + Vector2(bar_rect.size.x * 0.5, 300.0)
	await _mouse_drag(drag_from, drag_to)
	_check(scroll.scroll_vertical > 0, "mouse drag moves the Lamplighter scrollbar")
	_check_inside("mouse-drag-reached CHOOSE A BOON", screen._begin, scroll)
	await _capture("lamplighter-mouse-drag")
	_confirmed = false
	screen.confirmed.connect(func(_boon: String, _art: StringName) -> void:
		_confirmed = true)
	await _mouse_click(screen._begin.get_global_rect().get_center())
	_check(_confirmed, "mouse-drag-reached CHOOSE A BOON activates by mouse")
	_drop(screen)
func _check_plain_choices(count: int) -> void:
	var choices: Array[Dictionary] = []
	for index: int in count:
		choices.append({"id": "row%d" % index, "label": "CHOICE ROW %d" % (index + 1)})
	var screen: ChoiceScreen = ChoiceScreen.new(
		"PLAIN CHOICES", "Every final control stays reachable.", choices,
		{"shape": "phone-landscape"})
	_viewport.add_child(screen)
	await _settle()
	var scrolls: Array[ScrollContainer] = _vertical_scrolls(screen)
	_check(scrolls.size() == 1, "%d plain choices have one vertical scroll owner" % count)
	if scrolls.is_empty():
		_drop(screen)
		return
	var page: ScrollContainer = scrolls[0]
	var panel_mid: float = screen._panel.get_global_rect().get_center().x
	var viewport_mid: float = page.get_global_rect().get_center().x
	_check(absf(panel_mid - viewport_mid) <= 8.0,
		"%d plain choices keep horizontal centring" % count)
	var last: Button = screen._primary_buttons.back() if not screen._primary_buttons.is_empty() \
		else _buttons(screen).back()
	await _focus_until(last)
	_check_inside("focused final control for %d plain choices" % count, last, page)
	await _capture("plain-%d" % count)
	_chosen_id = ""
	screen.chosen.connect(func(id: String) -> void: _chosen_id = id)
	await _action(&"ui_accept")
	_check(_chosen_id == "row%d" % (count - 1),
		"final control for %d plain choices activates" % count)
	_drop(screen)

func _lamplighter(stage_shape: StringName = &"phone-landscape") -> LamplighterScreen:
	var content: ContentDB = ContentDB.load_full(false)
	var boon_ids: Array[String] = []
	for id_v: Variant in content.boons.keys().slice(0, 3):
		boon_ids.append(str(id_v))
	var aspect: Dictionary = content.aspects[0]
	var screen: LamplighterScreen = LamplighterScreen.new(
		aspect, content.boons, content.arts, boon_ids,
		StringName(str(content.arts.keys()[0])), stage_shape)
	_hide_backdrop(screen)
	return screen

func _check_boon_copy_clear(screen: LamplighterScreen, stage_shape: String) -> void:
	var heading_rect: Rect2 = screen._art_heading.get_global_rect()
	for id: String in screen._boon_ids:
		var description_rect: Rect2 = screen._boon_descriptions[id].get_global_rect()
		var card_rect: Rect2 = screen._boon_buttons[id].get_global_rect()
		print("EVIDENCE %s boon=%s card=%s description=%s heading=%s" % [
			stage_shape, id, card_rect, description_rect, heading_rect])
		_check(card_rect.encloses(description_rect),
			"%s boon description %s stays inside its card" % [stage_shape, id])
		_check(not description_rect.intersects(heading_rect),
			"%s boon description %s does not overlap the art heading" % [stage_shape, id])

func _hide_backdrop(screen: Control) -> void:
	for backdrop: Node in screen.find_children("", "TitleWorld", true, false):
		var canvas: CanvasItem = backdrop as CanvasItem
		if canvas != null:
			canvas.visible = false

func _focus_until(target: Control) -> void:
	for step: int in 24:
		if _viewport.gui_get_focus_owner() == target:
			return
		await _action(&"ui_focus_next")


func _action(action: StringName) -> void:
	var pressed: InputEventAction = InputEventAction.new()
	pressed.action = action
	pressed.pressed = true
	_viewport.push_input(pressed)
	await process_frame
	var released: InputEventAction = InputEventAction.new()
	released.action = action
	released.pressed = false
	_viewport.push_input(released)
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


func _mouse_drag(from: Vector2, to: Vector2) -> void:
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.pressed = true
	down.position = from
	down.global_position = from
	_viewport.push_input(down, true)
	await process_frame
	var prior: Vector2 = from
	for index: int in range(1, 7):
		var at: Vector2 = from.lerp(to, float(index) / 6.0)
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = at
		motion.global_position = at
		motion.relative = at - prior
		motion.screen_relative = motion.relative
		_viewport.push_input(motion, true)
		prior = at
		await process_frame
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to
	up.global_position = to
	_viewport.push_input(up, true)
	await process_frame


func _check_inside(label: String, control: Control, viewport: ScrollContainer) -> void:
	var control_rect: Rect2 = control.get_global_rect()
	var viewport_rect: Rect2 = viewport.get_global_rect()
	var inside: bool = viewport_rect.encloses(control_rect)
	print("EVIDENCE %s viewport=%s control=%s scroll_y=%d" % [
		label, viewport_rect, control_rect, viewport.scroll_vertical])
	_check(inside, "%s is fully inside its scroll viewport" % label)


func _vertical_scrolls(node: Node) -> Array[ScrollContainer]:
	var found: Array[ScrollContainer] = []
	for candidate: Node in node.find_children("", "ScrollContainer", true, false):
		var scroll: ScrollContainer = candidate as ScrollContainer
		if scroll != null and scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			found.append(scroll)
	return found


func _buttons(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	for candidate: Node in node.find_children("", "Button", true, false):
		var button: Button = candidate as Button
		if button != null:
			found.append(button)
	return found


func _settle() -> void:
	for frame: int in 4:
		await process_frame


func _capture(stem: String) -> void:
	if _capture_dir.is_empty():
		return
	if DisplayServer.get_name() == "headless":
		_check(false, "capture %s requires a headed renderer" % stem)
		return
	await process_frame
	var image: Image = _viewport.get_texture().get_image()
	var path: String = _capture_dir.path_join("%s-%dx%d.png" % [
		stem, _viewport.size.x, _viewport.size.y])
	if image == null:
		_check(false, "capture %s has a rendered viewport image" % stem)
		return
	if image.get_size() != _viewport.size:
		_check(false, "capture %s matches the viewport size" % stem)
		return
	var save_error: Error = image.save_png(path)
	if save_error != OK:
		_check(false, "capture %s is written" % stem)
		return
	var proof: Image = Image.load_from_file(path)
	_check(proof != null and proof.get_size() == _viewport.size,
		"capture %s reloads at the viewport size" % stem)
	print("CAPTURE %s" % path)


func _drop(screen: Control) -> void:
	_viewport.remove_child(screen)
	screen.free()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
