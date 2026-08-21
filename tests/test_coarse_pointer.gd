extends RefCounted
## Row 25: coarse-pointer first-tap lift, tooltip long-press, and double
## `_press_release` absorption. Declares coarse through PointerDevice and feeds
## real InputEventScreenTouch through CardView._gui_input — not `_on_card_tapped`.
## Synthetic `mouse_entered` before release (emulate_mouse_from_touch) must lift,
## matching the touch-only path; fine-pointer first tap still arms.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("coarse pointer: %s" % what)


static func run(fails: Array[String]) -> void:
	_predicate_contract(fails)
	_pointer_drift_without_mouse(fails)
	_first_tap_without_synthetic_hover(fails)
	_first_tap_with_synthetic_hover(fails)
	_first_tap_fine_pointer_arms(fails)
	_long_press_tooltip(fails)
	_double_press_absorption(fails)


static func _predicate_contract(fails: Array[String]) -> void:
	_check(fails, PointerDevice.coarse_for(true, false),
		"coarse_for touch-only is coarse")
	_check(fails, not PointerDevice.coarse_for(true, true),
		"coarse_for hybrid touch+mouse is not coarse")
	_check(fails, not PointerDevice.coarse_for(false, false),
		"coarse_for mouse-only is not coarse")
	PointerDevice.declare_coarse(true)
	_check(fails, PointerDevice.coarse(), "declare_coarse(true) is coarse")
	PointerDevice.declare_coarse(false)
	_check(fails, not PointerDevice.coarse(), "declare_coarse(false) is fine")
	PointerDevice.clear_declaration()


static func _pointer_drift_without_mouse(fails: Array[String]) -> void:
	# The sampler is the engine call that reports GLASSVOW-1 on iOS. A no-mouse
	# display must return centre without invoking it at all.
	var sampled: Array[bool] = [false]
	var sample: Callable = func() -> Vector2:
		sampled[0] = true
		return Vector2(100.0, 100.0)
	var target: Vector2 = PointerDrift.target_for(
		Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), false, sample)
	_check(fails, not sampled[0],
		"PointerDrift does not sample an absent mouse")
	_check(fails, target == Vector2.ZERO,
		"PointerDrift targets centre without a mouse")


static func _combat_screen() -> CombatScreen:
	var content: ContentDB = ContentDB.load_slice()
	var game: GlassvowGame = GlassvowGame.new(content, RunState.new_run(content, 347347))
	var screen: CombatScreen = CombatScreen.new(game)
	screen.seq.instant = true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.start_encounter(["sporeling", "sporeling"], "normal", "coarse-pointer")
	return screen


static func _playable_enemy_uid(screen: CombatScreen) -> int:
	for c: CardInst in screen.game.cb.hand:
		var view: CardView = screen._hand.card_view(c.uid)
		if view != null and view.target_kind == "enemy" and view.playable:
			return c.uid
	return -1


static func _touch(view: CardView, pressed: bool, local: Vector2) -> void:
	var ev: InputEventScreenTouch = InputEventScreenTouch.new()
	ev.pressed = pressed
	ev.position = local
	view._gui_input(ev)


static func _mouse_button(view: CardView, pressed: bool, global_pos: Vector2) -> void:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.global_position = global_pos
	view._gui_input(ev)


static func _tap_card(view: CardView, with_synthetic_hover: bool) -> void:
	var local: Vector2 = view.size * 0.5
	_touch(view, true, local)
	if with_synthetic_hover:
		view._on_mouse_entered()
	_touch(view, false, local)


static func _first_tap_without_synthetic_hover(fails: Array[String]) -> void:
	PointerDevice.declare_coarse(true)
	var screen: CombatScreen = _combat_screen()
	var uid: int = _playable_enemy_uid(screen)
	var view: CardView = screen._hand.card_view(uid) if uid >= 0 else null
	_check(fails, uid >= 0 and view != null, "opening hand has a playable enemy card")
	if view == null:
		_teardown(screen)
		PointerDevice.clear_declaration()
		return
	_tap_card(view, false)
	_check(fails, screen._hand.hovered_uid == uid and not screen._targeting,
		"first coarse tap lifts without synthetic hover (row 25)")
	_teardown(screen)
	PointerDevice.clear_declaration()


static func _first_tap_with_synthetic_hover(fails: Array[String]) -> void:
	PointerDevice.declare_coarse(true)
	var screen: CombatScreen = _combat_screen()
	var uid: int = _playable_enemy_uid(screen)
	var view: CardView = screen._hand.card_view(uid) if uid >= 0 else null
	if view == null:
		_check(fails, false, "opening hand has a playable enemy card (hover path)")
		_teardown(screen)
		PointerDevice.clear_declaration()
		return
	var local: Vector2 = view.size * 0.5
	_touch(view, true, local)
	view._on_mouse_entered()
	_check(fails, screen._hand.hovered_uid != uid and not screen._targeting,
		"synthetic mouse_entered does not count as hover on coarse")
	_touch(view, false, local)
	_check(fails, screen._hand.hovered_uid == uid and not screen._targeting,
		"first coarse tap lifts with synthetic hover (row 25)")
	view._on_mouse_exited()
	_check(fails, screen._hand.hovered_uid == uid and not screen._targeting,
		"synthetic mouse_exited does not drop the coarse lift")
	_tap_card(view, true)
	_check(fails, screen._targeting and screen._selected_uid == uid,
		"second coarse tap arms after the lift (row 25)")
	_teardown(screen)
	PointerDevice.clear_declaration()


static func _first_tap_fine_pointer_arms(fails: Array[String]) -> void:
	PointerDevice.declare_coarse(false)
	var screen: CombatScreen = _combat_screen()
	var uid: int = _playable_enemy_uid(screen)
	var view: CardView = screen._hand.card_view(uid) if uid >= 0 else null
	_check(fails, uid >= 0 and view != null, "opening hand has a playable enemy card (fine)")
	if view == null:
		_teardown(screen)
		PointerDevice.clear_declaration()
		return
	var local: Vector2 = view.size * 0.5
	_touch(view, true, local)
	view._on_mouse_entered()
	_check(fails, screen._hand.hovered_uid == uid,
		"fine pointer mouse_entered still writes hovered_uid")
	_touch(view, false, local)
	_check(fails, screen._targeting and screen._selected_uid == uid,
		"fine pointer first tap arms (desktop)")
	_teardown(screen)
	PointerDevice.clear_declaration()


static func _long_press_tooltip(fails: Array[String]) -> void:
	PointerDevice.declare_coarse(true)
	var tips: TooltipLayer = TooltipLayer.new()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(tips)
	tips.source = func(_at: Vector2) -> Dictionary:
		return {"title": "Tip", "body": "Body", "sub": ""}
	var at: Vector2 = Vector2(120.0, 200.0)
	tips.press(at)
	tips._process(0.10)
	tips.press_moved(at + Vector2(TooltipLayer.LONG_PRESS_SLOP + 1.0, 0.0))
	tips._process(0.016)
	_check(fails, not tips._panel.visible and tips._touch_timer < 0.0,
		"long-press slop cancels before the timer fires")
	tips.press(at)
	var elapsed: float = 0.0
	while elapsed < TooltipLayer.LONG_PRESS:
		tips._process(0.016)
		elapsed += 0.016
	_check(fails, tips._panel.visible and str(tips._shown.get("title", "")) == "Tip",
		"coarse long-press shows tooltip after %.0f ms" % (TooltipLayer.LONG_PRESS * 1000.0))
	tips.press_moved(at + Vector2(TooltipLayer.LONG_PRESS_SLOP + 1.0, 0.0))
	tips._process(0.016)
	_check(fails, tips._panel.visible,
		"slop after the tip is shown does not hide it (timer already spent)")
	tree.root.remove_child(tips)
	tips.free()
	PointerDevice.clear_declaration()


static func _double_press_absorption(fails: Array[String]) -> void:
	PointerDevice.declare_coarse(true)
	var screen: CombatScreen = _combat_screen()
	var uid: int = _playable_enemy_uid(screen)
	var view: CardView = screen._hand.card_view(uid) if uid >= 0 else null
	if view == null:
		_check(fails, false, "opening hand has a playable enemy card (double press)")
		_teardown(screen)
		PointerDevice.clear_declaration()
		return
	var local: Vector2 = view.size * 0.5
	var taps: Array[int] = [0]
	var on_tap: Callable = func(tapped_uid: int) -> void:
		if tapped_uid == uid:
			taps[0] += 1
	screen._hand.card_tapped.connect(on_tap)
	_touch(view, true, local)
	_mouse_button(view, true, view.get_global_transform() * local)
	_touch(view, false, local)
	_mouse_button(view, false, view.get_global_transform() * local)
	_check(fails, taps[0] == 1,
		"touch+mouse press_release emits one card_tapped (absorption verified)")
	_check(fails, not screen._targeting,
		"absorbed double release does not arm on first lift tap")
	_teardown(screen)
	PointerDevice.clear_declaration()


static func _teardown(screen: CombatScreen) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.remove_child(screen)
	screen.free()
