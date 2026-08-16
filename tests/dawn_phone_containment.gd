extends SceneTree
## Headless geometry regression for #168. This is separately run because the
## discovered suite is synchronous while container geometry needs real frames.

const PHONE: StringName = &"phone-portrait"
const PAD: StringName = &"pad-landscape"

var _fails: Array[String] = []
var _viewport: SubViewport


func _initialize() -> void:
	_viewport = SubViewport.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	call_deferred("_run")


func _run() -> void:
	var previous: Locale = Locale.active
	for locale_code: StringName in [Locale.CODE_EN, Locale.CODE_ZH_HANT]:
		Locale.active = Locale.new(locale_code)
		await _check_shape(locale_code, PHONE)
		await _check_shape(locale_code, PAD)
	Locale.active = previous
	if _fails.is_empty():
		print("PASS dawn containment (en + zh-Hant, phone + pad)")
		quit(0)
	else:
		for failure: String in _fails:
			print("FAIL dawn_phone_containment: %s" % failure)
		quit(1)


func _check_shape(locale_code: StringName, stage_shape: StringName) -> void:
	var reference: Vector2i = StageShape.REFERENCES[stage_shape]
	_viewport.size = reference
	var events: Array = _events(locale_code)
	# The authentic route opens at cursor zero. A nearly-complete feed can grow
	# the panel enough to hide a first-beat action-wrap regression.
	var screen: DawnScreen = DawnScreen.new(events, 0, stage_shape, _stats())
	_viewport.add_child(screen)
	for frame: int in 4:
		await process_frame
	var stage: Rect2 = Rect2(Vector2.ZERO, Vector2(reference))
	_check_rect(locale_code, stage_shape, "panel", screen._panel, stage)
	_check_rect(locale_code, stage_shape, "four-stat grid", screen._stats_grid, stage)
	_check_rect(locale_code, stage_shape, "status line", screen._progress, stage)
	_check_rect(locale_code, stage_shape, "left action", screen._deck_btn, stage)
	_check_rect(locale_code, stage_shape, "right action", screen._commit_btn, stage)
	if stage_shape == PHONE:
		var left_y: float = screen._deck_btn.get_global_rect().position.y
		var right_y: float = screen._commit_btn.get_global_rect().position.y
		_check(is_equal_approx(left_y, right_y),
			"%s phone actions split across rows: left y=%.1f, right y=%.1f" % [
				locale_code, left_y, right_y])
	# Open the actions without advancing persistence: this test owns input and
	# geometry; the durable cursor handshake remains in test_dawn_screen.gd.
	screen._complete()
	await process_frame
	var fired: Array[bool] = [false, false]
	screen.deck_requested.connect(func() -> void: fired[0] = true)
	screen.commit_requested.connect(func() -> void: fired[1] = true)
	screen._deck_btn.grab_focus()
	await process_frame
	_check(_viewport.gui_get_focus_owner() == screen._deck_btn,
		"%s %s keyboard reaches the left action" % [locale_code, stage_shape])
	await _action(&"ui_focus_next")
	_check(_viewport.gui_get_focus_owner() == screen._commit_btn,
		"%s %s keyboard reaches the right action" % [locale_code, stage_shape])
	await _action(&"ui_accept")
	_check(fired[1], "%s %s keyboard activates the right action" % [
		locale_code, stage_shape])
	await _mouse_click(screen._deck_btn.get_global_rect().get_center())
	_check(fired[0], "%s %s mouse activates the left action" % [
		locale_code, stage_shape])
	screen.free()
	await process_frame


func _check_rect(locale_code: StringName, stage_shape: StringName,
		label: String, control: Control, stage: Rect2) -> void:
	var rect: Rect2 = control.get_global_rect()
	_check(rect.size.x > 0.0 and rect.size.y > 0.0,
		"%s %s %s has non-zero geometry: %s" % [locale_code, stage_shape, label, rect])
	_check(stage.encloses(rect), "%s %s %s escapes %s: %s" % [
		locale_code, stage_shape, label, stage, rect])


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)


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


func _mouse_click(position: Vector2) -> void:
	var pressed: InputEventMouseButton = InputEventMouseButton.new()
	pressed.position = position
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	_viewport.push_input(pressed)
	await process_frame
	var released: InputEventMouseButton = InputEventMouseButton.new()
	released.position = position
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	_viewport.push_input(released)
	await process_frame


func _events(locale_code: StringName) -> Array:
	if locale_code == Locale.CODE_ZH_HANT:
		return [
			{"kind": "whisper", "body": "一聲低語抵達破曉。"},
			{"kind": "quest", "title": "蒼白者", "body": "旅途顯現。"},
			{"kind": "progress", "title": "蒼白者", "body": "旅跡仍在延伸。"},
			{"kind": "shard", "title": "墜落之影", "body": "一片窗片作出回應。"},
			{"kind": "unlock", "title": "新卡牌與遺物加入朝聖之路。"},
			{"kind": "unlock", "title": "王冠之後的封印之門已開。"},
			{"kind": "memory", "title": "守夜銘記", "body": "勝利 · 3 片碎片已點亮"},
		]
	return [
		{"kind": "whisper", "body": "A whisper reaches the dawn."},
		{"kind": "quest", "title": "The Pale Ones", "body": "A journey is revealed."},
		{"kind": "progress", "title": "The Pale Ones", "body": "The trail continues."},
		{"kind": "shard", "title": "The Shade That Fell", "body": "One pane answers."},
		{"kind": "unlock", "title": "New cards and relics join the pilgrimage."},
		{"kind": "unlock", "title": "A sealed door opens beyond the crown."},
		{"kind": "memory", "title": "The Vigil Remembers", "body": "Victory · 3 shards lit"},
	]


func _stats() -> Dictionary:
	return {
		"waystones": 49,
		"slain": 37,
		"elites_bosses": 8,
		"deck_size": 24,
		"damage_dealt": 1324,
		"damage_taken": 71,
		"cards_played": 196,
		"run_time": "42:17",
	}
