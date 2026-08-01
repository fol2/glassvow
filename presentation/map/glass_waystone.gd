class_name GlassWaystone
extends Control
## A waystone on the path band (concept brief §2): a faceted emblem seated on
## a leaded glass pane, its rim kindled (ember) when reachable and dim glass
## when not.
##
## Every benchmark node type has a compact emblem. An unlit node deliberately
## hides its true face until the player steps onto it.

signal chosen(index: int)

const WIDTH: float = 104.0
const EMBLEM_H: float = 104.0
const CAPTION_H: float = 0.0
const DRAG_SLOP: float = 12.0

var index: int = 0
var kind: String = "monster"
var hue: float = 210.0
var reachable: bool = false
var cleared: bool = false
var current: bool = false
var quest_marked: bool = false

var _frame_art: TextureRect
var _glyph_art: TextureRect
var _caption: Label
var _pulse: float = 0.0
## The phase where `0.5 + 0.5·sin(_pulse·2.2)` reads 1.0 — the rim fully lit.
const PULSE_HELD: float = PI / 4.4
var _pressed: bool = false
var _press_at: Vector2 = Vector2.ZERO

## Empty rect grown around the drawing so the HIT AREA can be bigger than the
## picture. Zero at the shapes a mouse points at; on a phone it is what keeps a
## waystone tappable after the trail has been scaled down to fit.
var _pad: Vector2 = Vector2.ZERO


func _init(node_index: int, node_kind: String, node_hue: float, caption: String,
		is_quest_marked: bool = false) -> void:
	index = node_index
	kind = node_kind
	hue = node_hue
	quest_marked = is_quest_marked
	size = Vector2(WIDTH, EMBLEM_H + CAPTION_H)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	_frame_art = _art("node-frame")
	add_child(_frame_art)
	_glyph_art = _art("node-" + _art_kind())
	add_child(_glyph_art)
	_seat_art()
	_caption = Label.new()
	_caption.text = caption
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 13)
	_caption.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_caption.offset_top = EMBLEM_H - 2
	_caption.offset_bottom = EMBLEM_H + CAPTION_H
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.visible = false
	add_child(_caption)
	tooltip_text = caption
	set_state(false, false)
	set_process(true)


func set_state(is_reachable: bool, is_cleared: bool, is_current: bool = false) -> void:
	reachable = is_reachable
	cleared = is_cleared
	current = is_current
	focus_mode = Control.FOCUS_ALL if reachable else Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if reachable else Control.CURSOR_ARROW
	var art_tint: Color = Color(0.68, 0.70, 0.76, 0.76) if cleared else Color.WHITE
	_frame_art.modulate = art_tint
	_glyph_art.modulate = art_tint
	var text_col: Color = GlassStyle.TEXT if reachable else GlassStyle.TEXT_DIM
	_caption.add_theme_color_override("font_color", Color(text_col.r, text_col.g, text_col.b,
		0.45 if cleared else 1.0))
	queue_redraw()


func _process(delta: float) -> void:
	if not reachable:
		return
	# Under prefers-reduced-motion the kindled rim is information and stays
	# lit — held at the pulse's PEAK, only the beckoning throb stops. The
	# precedent is styles.css:2049, where `.mnode .pale-lens` is forced to
	# opacity 1 — peak, explicitly, for legibility — a deliberate step past
	# :2048's base-state rendering, because a reduced-motion player has lost
	# the throb that also said "you can go here".
	if Preferences.active.reduce_motion:
		if _pulse != PULSE_HELD:
			_pulse = PULSE_HELD
			queue_redraw()
		return
	_pulse = fmod(_pulse + delta, TAU)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	var st: InputEventScreenTouch = event as InputEventScreenTouch
	var key: InputEventKey = event as InputEventKey
	if key != null and reachable and key.pressed and not key.echo \
			and key.keycode in [KEY_ENTER, KEY_SPACE]:
		accept_event()
		chosen.emit(index)
		return
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_pressed = reachable
			_press_at = mb.position
		elif _pressed:
			_pressed = false
			if mb.position.distance_to(_press_at) <= DRAG_SLOP:
				accept_event()
				chosen.emit(index)
		return
	if st != null:
		if st.pressed:
			_pressed = reachable
			_press_at = st.position
		elif _pressed:
			_pressed = false
			if st.position.distance_to(_press_at) <= DRAG_SLOP:
				accept_event()
				chosen.emit(index)


## Grow the hit rect until the stone is at least `min_px` across on screen,
## without moving a pixel of it.
##
## A waystone is 120x150 and the trail scales the whole node, so a phone gets a
## 36x45 target and a phone held sideways a 21x27 one. Both are under the 44pt
## floor Apple's HIG and Android's Material guidance both set, and a target that
## small is not a polish item — it is the thing between the player and the game.
##
## Growing the node is free here because `_draw` measures from `WIDTH` and
## `EMBLEM_H` rather than from `size`, so the picture does not know the rect
## changed. Everything that DOES read the rect — the gem, the caption's centring
## box — is shifted by the same pad, which puts the drawing back in the middle of
## the bigger rect. `WorldMapScreen` seats by centre, so the stone does not move.
##
## The alternative was a second Control per stone to catch input. This is one
## node fewer per waystone across 105 of them, and it cannot drift out of
## alignment with the thing it is standing in front of.
func set_touch_min(min_px: float, draw_scale: float) -> void:
	var base: Vector2 = Vector2(WIDTH, EMBLEM_H + CAPTION_H)
	var want: Vector2 = Vector2.ONE * (min_px / maxf(0.01, draw_scale))
	var pad: Vector2 = ((want - base) * 0.5).max(Vector2.ZERO)
	if pad.is_equal_approx(_pad):
		return
	_caption.offset_top = _pad.y + EMBLEM_H - 2 + (pad.y - _pad.y)
	_caption.offset_bottom = _caption.offset_top + CAPTION_H + 2
	_pad = pad
	size = base + pad * 2.0
	_seat_art()
	queue_redraw()


func _draw() -> void:
	var cx: float = _pad.x + WIDTH * 0.5
	var cy: float = _pad.y + EMBLEM_H * 0.5
	var glow: float = (0.5 + 0.5 * sin(_pulse * 2.2)) if reachable else 0.0
	var rim: Color = GlassStyle.EMBER if reachable else GlassStyle.GLASS
	var rim_a: float = 0.20
	if reachable:
		rim_a = 0.55 + 0.30 * glow
		if has_focus():
			rim_a = 1.0
	elif cleared:
		rim_a = 0.12
	var radius: float = 38.0 if kind == "boss" else (32.0 if kind in ["elite", "treasure"] else 28.0)
	if reachable or current:
		draw_circle(Vector2(cx, cy), radius + 12.0,
			Color(GlassStyle.EMBER.r, GlassStyle.EMBER.g, GlassStyle.EMBER.b, 0.08 + glow * 0.05))
	draw_circle(Vector2(cx, cy), radius, Color(0.04, 0.05, 0.10, 0.55 if cleared else 0.86))
	if reachable:
		draw_arc(Vector2(cx, cy), radius + 5.0, 0.0, TAU, 32,
			Color(1.0, 0.96, 0.88, 0.78 + glow * 0.2), 3.0)
	if quest_marked:
		var lens: Vector2 = Vector2(cx + radius * 0.78, cy - radius * 0.78)
		draw_circle(lens, 12.0, Color(0.72, 0.96, 1.0, 0.13))
		draw_circle(lens, 7.5, Color(0.54, 0.92, 1.0, 0.28))
		draw_arc(lens, 7.5, 0.0, TAU, 18, Color(0.88, 0.98, 1.0, 0.9), 1.5)


func _art(name: String) -> TextureRect:
	var image: TextureRect = TextureRect.new()
	image.texture = load("res://assets/art/ui/%s.png" % name) as Texture2D
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


func _art_kind() -> String:
	return "monument" if kind == "act4" else kind


func _seat_art() -> void:
	var frame_side: float = 86.0 if kind == "boss" \
		else (64.0 if kind in ["elite", "treasure"] else 54.0)
	var centre: Vector2 = _pad + Vector2(WIDTH, EMBLEM_H) * 0.5
	_frame_art.position = centre - Vector2.ONE * frame_side * 0.5
	_frame_art.size = Vector2.ONE * frame_side
	var glyph_side: float = frame_side * 1.28
	_glyph_art.position = centre - Vector2.ONE * glyph_side * 0.5
	_glyph_art.size = Vector2.ONE * glyph_side


## Three spikes above the pane — the affix crown that marks an elite.
func _draw_crown(cx: float, top_y: float, alpha: float) -> void:
	var col: Color = Color(GlassStyle.EMBER.r, GlassStyle.EMBER.g, GlassStyle.EMBER.b,
		clampf(alpha + 0.15, 0.0, 1.0))
	for k: int in range(-1, 2):
		var bx: float = cx + float(k) * 15.0
		var tip: float = top_y - (16.0 if k == 0 else 11.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx - 6.0, top_y), Vector2(bx, tip), Vector2(bx + 6.0, top_y),
		]), col)


