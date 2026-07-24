class_name GlassWaystone
extends Control
## A waystone on the path band (concept brief §2): a faceted emblem seated on
## a leaded glass pane, its rim kindled (ember) when reachable and dim glass
## when not. Composes the combat screen's GlassGem for the creature nodes so
## the map and the fight speak one visual language.
##
## Ships the three slice types — monster, elite, rest. event/shop/treasure/
## boss/monument and the dark-lantern `unlit` marker are designed in §2 but
## unbuilt: their content is not ported, so a drawing for them would be dead
## code today.

signal chosen(index: int)

const WIDTH: float = 120.0
const EMBLEM_H: float = 118.0
const CAPTION_H: float = 32.0

var index: int = 0
var kind: String = "monster"
var hue: float = 210.0
var reachable: bool = false
var cleared: bool = false

var _gem: GlassGem = null
var _caption: Label
var _pulse: float = 0.0


func _init(node_index: int, node_kind: String, node_hue: float, caption: String) -> void:
	index = node_index
	kind = node_kind
	hue = node_hue
	size = Vector2(WIDTH, EMBLEM_H + CAPTION_H)
	if kind != "rest":
		var big: bool = kind == "elite"
		_gem = GlassGem.new()
		_gem.size = Vector2(96, 108) if big else Vector2(74, 86)
		_gem.position = Vector2((WIDTH - _gem.size.x) * 0.5, (EMBLEM_H - _gem.size.y) * 0.5 + 4)
		_gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gem.set_state(hue, 1.0, false)
		add_child(_gem)
	_caption = Label.new()
	_caption.text = caption
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 13)
	_caption.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_caption.offset_top = EMBLEM_H - 2
	_caption.offset_bottom = EMBLEM_H + CAPTION_H
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	set_state(false, false)
	set_process(true)


func set_state(is_reachable: bool, is_cleared: bool) -> void:
	reachable = is_reachable
	cleared = is_cleared
	if _gem != null:
		# A resolved node is a spent husk; an unresolved one still holds light.
		_gem.set_state(hue, 0.25 if cleared else 1.0, cleared)
	var text_col: Color = GlassStyle.TEXT if reachable else GlassStyle.TEXT_DIM
	_caption.add_theme_color_override("font_color", Color(text_col.r, text_col.g, text_col.b,
		0.45 if cleared else 1.0))
	queue_redraw()


func _process(delta: float) -> void:
	if not reachable:
		return
	_pulse = fmod(_pulse + delta, TAU)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not reachable:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	var st: InputEventScreenTouch = event as InputEventScreenTouch
	var hit: bool = (mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT) \
		or (st != null and st.pressed)
	if hit:
		accept_event()
		chosen.emit(index)


func _draw() -> void:
	var cx: float = WIDTH * 0.5
	var cy: float = EMBLEM_H * 0.5
	var glow: float = (0.5 + 0.5 * sin(_pulse * 2.2)) if reachable else 0.0
	var rim: Color = GlassStyle.EMBER if reachable else GlassStyle.GLASS
	var rim_a: float = 0.20
	if reachable:
		rim_a = 0.55 + 0.30 * glow
	elif cleared:
		rim_a = 0.12
	# Leaded pane: an upright hexagon cut, the seat every emblem shares.
	var w: float = 46.0
	var h: float = 56.0
	var pane: PackedVector2Array = PackedVector2Array([
		Vector2(cx, cy - h), Vector2(cx + w, cy - h * 0.45),
		Vector2(cx + w, cy + h * 0.45), Vector2(cx, cy + h),
		Vector2(cx - w, cy + h * 0.45), Vector2(cx - w, cy - h * 0.45),
	])
	draw_colored_polygon(pane, Color(0.04, 0.05, 0.10, 0.55 if cleared else 0.72))
	if reachable:
		var halo: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pane:
			halo.append(Vector2(cx, cy) + (p - Vector2(cx, cy)) * 1.16)
		draw_colored_polygon(halo, Color(rim.r, rim.g, rim.b, 0.06 + 0.05 * glow))
	var outline: PackedVector2Array = pane.duplicate()
	outline.append(pane[0])
	draw_polyline(outline, Color(rim.r, rim.g, rim.b, rim_a), 2.0 if reachable else 1.2)
	match kind:
		"elite":
			_draw_crown(cx, cy - h - 2.0, rim_a)
		"rest":
			_draw_hearth(cx, cy, rim_a)
	if cleared:
		# A spent waystone keeps a cold lead scar across the pane.
		draw_line(Vector2(cx - w * 0.6, cy + h * 0.55), Vector2(cx + w * 0.6, cy - h * 0.55),
			Color(GlassStyle.GLASS.r, GlassStyle.GLASS.g, GlassStyle.GLASS.b, 0.22), 1.4)


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


## The only amber node: a held breath of lantern-fire on a dark road.
func _draw_hearth(cx: float, cy: float, alpha: float) -> void:
	var ember: Color = GlassStyle.EMBER
	var a: float = clampf(alpha + 0.25, 0.0, 1.0) * (0.4 if cleared else 1.0)
	draw_circle(Vector2(cx, cy + 6.0), 26.0, Color(ember.r, ember.g, ember.b, 0.10 * a))
	var flame: PackedVector2Array = PackedVector2Array([
		Vector2(cx, cy - 26.0), Vector2(cx + 13.0, cy + 2.0),
		Vector2(cx + 7.0, cy + 16.0), Vector2(cx - 7.0, cy + 16.0),
		Vector2(cx - 13.0, cy + 2.0),
	])
	draw_colored_polygon(flame, Color(ember.r, ember.g, ember.b, 0.62 * a))
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx, cy - 12.0), Vector2(cx + 6.0, cy + 4.0),
		Vector2(cx, cy + 13.0), Vector2(cx - 6.0, cy + 4.0),
	]), Color(1.0, 0.92, 0.72, 0.75 * a))
	# Lantern cage: two uprights and a crossbar hooding the fire.
	var cage: Color = Color(GlassStyle.GLASS.r, GlassStyle.GLASS.g, GlassStyle.GLASS.b, 0.5 * a)
	draw_line(Vector2(cx - 18.0, cy - 22.0), Vector2(cx - 18.0, cy + 20.0), cage, 1.6)
	draw_line(Vector2(cx + 18.0, cy - 22.0), Vector2(cx + 18.0, cy + 20.0), cage, 1.6)
	draw_line(Vector2(cx - 22.0, cy - 22.0), Vector2(cx + 22.0, cy - 22.0), cage, 1.6)
