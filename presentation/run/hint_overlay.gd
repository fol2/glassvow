class_name HintOverlay
extends Control
## Glass callout for one first-run hint. Paint only: the guide owns records.
## Root ignores the pointer so the named action stays live on the element
## beneath; the skip control is the one exception.

const PANEL_W: float = 280.0
const MARGIN: float = 24.0
const IN_S: float = 0.22
const GHOST_S: float = 1.15

var skip_requested: Callable = Callable()

var _panel: PanelContainer
var _body: Label
var _skip: Button
var _ghost: Control
var _anchor: Control = null
var _ghost_from_n: Control = null
var _ghost_to_n: Control = null
var _ghost_from: Vector2 = Vector2.ZERO
var _ghost_to: Vector2 = Vector2.ZERO
var _ghost_on: bool = false
var _ghost_t: float = 0.0
var _tip: Vector2 = Vector2.ZERO


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = GlassStyle.theme()
	visible = false
	modulate.a = 0.0
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", GlassStyle.pane(GlassStyle.GOLD, 0.88))
	_panel.custom_minimum_size = Vector2(PANEL_W, 0.0)
	add_child(_panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_color_override("font_color", GlassStyle.TEXT)
	_body.add_theme_font_size_override("font_size", 16)
	_body.add_theme_font_override("font", GlassStyle.face(GlassStyle.ALEGREYA_400))
	col.add_child(_body)
	_skip = Button.new()
	_skip.visible = false
	_skip.mouse_filter = Control.MOUSE_FILTER_STOP
	GlassStyle.style_button(_skip, GlassStyle.GOLD)
	_skip.pressed.connect(_on_skip)
	col.add_child(_skip)
	_ghost = Control.new()
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.visible = false
	_ghost.custom_minimum_size = Vector2(28.0, 28.0)
	_ghost.size = Vector2(28.0, 28.0)
	add_child(_ghost)


func present(text: String, anchor: Control, offer_skip: bool,
		ghost_from_n: Control = null, ghost_to_n: Control = null) -> void:
	_body.text = text
	_skip.text = Locale.active.t("ui.hint.skip")
	_skip.visible = offer_skip
	_anchor = anchor
	_ghost_from_n = ghost_from_n
	_ghost_to_n = ghost_to_n
	_ghost_on = ghost_from_n != null and ghost_to_n != null and ghost_from_n != ghost_to_n
	_ghost.visible = _ghost_on
	_ghost_t = 0.0
	visible = true
	_place()
	_animate_in()


func dismiss() -> void:
	_anchor = null
	_ghost_from_n = null
	_ghost_to_n = null
	_ghost_on = false
	_ghost.visible = false
	visible = false
	modulate.a = 0.0


func _on_skip() -> void:
	if skip_requested.is_valid():
		skip_requested.call()


func _process(delta: float) -> void:
	if not visible:
		return
	_place()
	if not _ghost_on:
		return
	_ghost_t += delta
	var u: float = fmod(_ghost_t / GHOST_S, 1.0)
	var e: float = Motion.ease(Motion.OUT_SOFT, u)
	_ghost.position = _ghost_from.lerp(_ghost_to, e) - _ghost.size * 0.5
	_ghost.modulate.a = 0.85 if u < 0.85 else 0.85 * (1.0 - (u - 0.85) / 0.15)
	queue_redraw()


func _draw() -> void:
	if not visible or _panel == null:
		return
	var origin: Vector2 = _panel.position + Vector2(_panel.size.x * 0.5, _panel.size.y)
	if _tip.y < _panel.position.y:
		origin = _panel.position + Vector2(_panel.size.x * 0.5, 0.0)
	var gold: Color = Color(GlassStyle.GOLD, 0.85)
	draw_line(origin, _tip, gold, 2.0, true)
	var dir: Vector2 = (_tip - origin).normalized()
	var side: Vector2 = Vector2(-dir.y, dir.x) * 6.0
	draw_colored_polygon(PackedVector2Array([
		_tip, _tip - dir * 12.0 + side, _tip - dir * 12.0 - side,
	]), gold)
	if _ghost_on:
		var c: Vector2 = _ghost.position + _ghost.size * 0.5
		draw_circle(c, 11.0, Color(GlassStyle.GOLD, 0.72))
		draw_arc(c, 14.0, 0.0, TAU, 22, Color(GlassStyle.TEXT, 0.9), 2.0)


func _place() -> void:
	_sync_ghost_ends()
	var stage: Vector2 = size
	if stage.x < 2.0:
		stage = Vector2(1180.0, 820.0)
	_panel.reset_size()
	var panel_s: Vector2 = _panel.get_combined_minimum_size()
	panel_s.x = maxf(panel_s.x, PANEL_W)
	var anchor_c: Vector2 = stage * 0.5
	if _anchor != null and is_instance_valid(_anchor):
		var r: Rect2 = _anchor.get_global_rect()
		anchor_c = r.get_center() - global_position
	_tip = anchor_c
	var pos: Vector2 = Vector2(
		clampf(anchor_c.x - panel_s.x * 0.5, MARGIN, stage.x - panel_s.x - MARGIN),
		anchor_c.y - panel_s.y - 36.0)
	if pos.y < MARGIN:
		pos.y = minf(anchor_c.y + 36.0, stage.y - panel_s.y - MARGIN)
	_panel.position = pos
	_panel.size = panel_s
	queue_redraw()


func _sync_ghost_ends() -> void:
	if not _ghost_on:
		return
	if _ghost_from_n != null and is_instance_valid(_ghost_from_n):
		_ghost_from = _ghost_from_n.get_global_rect().get_center() - global_position
	if _ghost_to_n != null and is_instance_valid(_ghost_to_n):
		_ghost_to = _ghost_to_n.get_global_rect().get_center() - global_position


func _animate_in() -> void:
	if not is_inside_tree() or Preferences.active.reduce_motion:
		modulate.a = 1.0
		return
	modulate.a = 0.0
	_panel.scale = Vector2(0.94, 0.94)
	_panel.pivot_offset = _panel.size * 0.5
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, IN_S)
	tw.tween_property(_panel, "scale", Vector2.ONE, IN_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
