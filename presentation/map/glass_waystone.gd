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
## Pane radius of an ordinary stone — an unlit one included. Named because the
## bounty chip seats itself off the stone's visible edge and must not be able to
## disagree with what `_draw` actually draws.
const UNLIT_RADIUS: float = 28.0
## The lowest net alpha the bounty chip may fade to, whatever the stone does.
const CHIP_ALPHA_FLOOR: float = 0.88
const DRAG_SLOP: float = 12.0

var index: int = 0
var kind: String = "monster"
var hue: float = 210.0
var reachable: bool = false
var cleared: bool = false
var current: bool = false
var quest_marked: bool = false
## Paid TO the player on kindling — chip text pins the `+`. Zero until the
## screen passes an unlit node's bounty through the ctor.
var bounty: int = 0

var _frame_art: TextureRect
var _glyph_art: TextureRect
var _caption: Label
var _pulse: float = 0.0
## The phase where `0.5 + 0.5·sin(_pulse·2.2)` reads 1.0 — the rim fully lit.
const PULSE_HELD: float = PI / 4.4
var _pressed: bool = false
var _press_at: Vector2 = Vector2.ZERO
## Kindle ceremony — flash envelope (1→0 over 0.45s) and re-entry guard.
var _kindle: float = 0.0
var _kindling: bool = false
## Theme font cached once; draw_string refuses a null Font under warnings-as-errors.
var _chip_font: Font = null
var _chip_coin: Texture2D = null
var _chip_box: StyleBoxFlat = null
var _chip_layer: ChipLayer = null

## Empty rect grown around the drawing so the HIT AREA can be bigger than the
## picture. Zero at the shapes a mouse points at; on a phone it is what keeps a
## waystone tappable after the trail has been scaled down to fit.
var _pad: Vector2 = Vector2.ZERO


func _init(node_index: int, node_kind: String, node_hue: float, caption: String,
		is_quest_marked: bool = false, node_bounty: int = 0) -> void:
	index = node_index
	kind = node_kind
	hue = node_hue
	quest_marked = is_quest_marked
	bounty = node_bounty
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
	# Last child, and only where there is a chip to draw — 6 of 65 stones on
	# seed 717 rather than a node per stone.
	if kind == "unlit" and bounty > 0:
		_chip_layer = ChipLayer.new(self)
		add_child(_chip_layer)
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
	# A child does not redraw with its parent, and the chip dims with `cleared`.
	if _chip_layer != null:
		_chip_layer.queue_redraw()


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
	if _chip_layer != null:
		_chip_layer.queue_redraw()


## The stone's depth fade. Applied here rather than written straight onto
## `modulate` because the chip must not go with it: a child's alpha multiplies
## its parent's, so at the far end of the visible range the stone's 0.12 was
## taking a number the player is meant to READ down with it. The chip divides
## that back out to a floor — never brighter than opaque, never dimmer than
## `CHIP_ALPHA_FLOOR` — so distance still reads on the glass while the bounty
## stays legible (#69 D2, the information-not-decoration rule P4.3 set for
## floaters).
func set_depth_alpha(a: float) -> void:
	modulate.a = a
	if _chip_layer != null:
		_chip_layer.modulate.a = clampf(CHIP_ALPHA_FLOOR / maxf(a, 0.01), 1.0, 8.0)


func _draw() -> void:
	var cx: float = _pad.x + WIDTH * 0.5
	var cy: float = _pad.y + EMBLEM_H * 0.5
	var glow: float = (0.5 + 0.5 * sin(_pulse * 2.2)) if reachable else 0.0
	var radius: float = 38.0 if kind == "boss" \
		else (32.0 if kind in ["elite", "treasure"] else UNLIT_RADIUS)
	if reachable or current:
		draw_circle(Vector2(cx, cy), radius + 12.0,
			Color(GlassStyle.EMBER.r, GlassStyle.EMBER.g, GlassStyle.EMBER.b, 0.08 + glow * 0.05))
	draw_circle(Vector2(cx, cy), radius, Color(0.04, 0.05, 0.10, 0.55 if cleared else 0.86))
	if reachable:
		draw_arc(Vector2(cx, cy), radius + 5.0, 0.0, TAU, 32,
			Color(1.0, 0.96, 0.88, 0.78 + glow * 0.2), 3.0)
	# Keyboard focus speaks the game's own focus language: GOLD corner
	# brackets (GlassStyle.focus_ring's hue), boxed rather than ringed, so it
	# cannot be confused with the warm reachable ring, the glass edge dashes,
	# or the ember pulse. Static by design — no reduce-motion special case.
	if has_focus():
		var half: float = radius + 8.0
		var arm: float = 9.0
		var gold: Color = Color(GlassStyle.GOLD.r, GlassStyle.GOLD.g, GlassStyle.GOLD.b, 0.95)
		for corner: int in range(4):
			var sx: float = -1.0 if corner % 2 == 0 else 1.0
			var sy: float = -1.0 if corner < 2 else 1.0
			var tip: Vector2 = Vector2(cx + sx * half, cy + sy * half)
			draw_line(tip, tip + Vector2(-sx * arm, 0.0), gold, 2.0)
			draw_line(tip, tip + Vector2(0.0, -sy * arm), gold, 2.0)
	if quest_marked:
		var lens: Vector2 = Vector2(cx + radius * 0.78, cy - radius * 0.78)
		draw_circle(lens, 12.0, Color(0.72, 0.96, 1.0, 0.13))
		draw_circle(lens, 7.5, Color(0.54, 0.92, 1.0, 0.28))
		draw_arc(lens, 7.5, 0.0, TAU, 18, Color(0.88, 0.98, 1.0, 0.9), 1.5)
	if _kindle > 0.0:
		draw_circle(Vector2(cx, cy), radius + 8.0,
			Color(1.0, 0.92, 0.78, _kindle * 0.55))
	# The chip is NOT drawn here. A parent's `_draw` runs before its children, so
	# a chip painted in this pass sits under this stone's own art and under every
	# later sibling's — it was being sliced by the neighbour it overlaps (#69 D3).
	# `ChipLayer` is a child at `z_index` 1, which clears both.


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


## One Control per unlit stone, drawn after every sibling so the chip is a label
## rather than something the next stone eats half of. Full-rect, so it shares the
## stone's local coordinates exactly and cannot drift from it.
class ChipLayer extends Control:
	var stone: GlassWaystone = null

	func _init(owner_stone: GlassWaystone) -> void:
		stone = owner_stone
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 1

	func _draw() -> void:
		if stone != null:
			stone.paint_bounty_chip(self)


## The bounty chip: a coin and "+N", nothing else. The dark lantern IS the
## "unlit" statement (§2), so the word would only restate the emblem; the coin
## glyph gives the number its unit the same way the HUD does. Seated INSIDE
## the control rect under the pane — a chip that leaves its own rect lands on
## the lane-below neighbour at every shipped shape (PR #76 DL R1).
##
## `ci` is the `ChipLayer` child, not this stone: see the note in `_draw`.
func paint_bounty_chip(ci: CanvasItem) -> void:
	if _chip_font == null:
		_chip_font = get_theme_font(&"font")
	if _chip_coin == null:
		_chip_coin = load("res://assets/art/ui/coin.png") as Texture2D
	if _chip_font == null:
		return
	var text: String = "+%d" % bounty
	var fs: int = 13
	var tw: float = _chip_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	var icon: float = 13.0
	var chip_w: float = icon + 4.0 + tw + 16.0
	var chip_h: float = 19.0
	# BESIDE the stone, not below it, and the lane pitch is why. Under the pane
	# the chip needed 50 local px of clearance while the shipped lane pitch is
	# 46–50 stage px — smaller than two emblem radii — so at every shape the
	# chip's bottom landed on the face of the stone one lane down whenever that
	# lane was occupied. No vertical seat fixes that: there is no gap to sit in.
	#
	# The walk axis has the room the lane axis does not — 128 px of step at the
	# narrowest shape against a chip that reaches 60 local px from the centre —
	# so the chip sits at the stone's own height, to its right, clear of both
	# lanes by construction. It crosses the dashed edge running to the next
	# node, which is a pale 1px line under an opaque pill: a label over a road,
	# not a label over another lantern (#69 D1).
	var cx: float = _pad.x + WIDTH * 0.5 + UNLIT_RADIUS + chip_w * 0.5 + 4.0
	var cy: float = _pad.y + EMBLEM_H * 0.5
	var a: float = 0.45 if cleared else 1.0
	var rect: Rect2 = Rect2(cx - chip_w * 0.5, cy - chip_h * 0.5, chip_w, chip_h)
	# Rounded pill via stylebox — the map draws no other hard-cornered
	# rectangle, and the border borrows the EMBER family, not the edges' glass.
	if _chip_box == null:
		_chip_box = StyleBoxFlat.new()
		_chip_box.bg_color = Color(0.03, 0.04, 0.08, 0.92)
		_chip_box.border_color = Color(GlassStyle.EMBER.r, GlassStyle.EMBER.g,
			GlassStyle.EMBER.b, 0.30)
		_chip_box.set_border_width_all(1)
		_chip_box.set_corner_radius_all(9)
	ci.draw_style_box(_chip_box, rect)
	var left: float = cx - (icon + 4.0 + tw) * 0.5
	if _chip_coin != null:
		ci.draw_texture_rect(_chip_coin, Rect2(left, cy - icon * 0.5, icon, icon),
			false, Color(1.0, 1.0, 1.0, a))
	ci.draw_string(_chip_font, Vector2(left + icon + 4.0, cy + float(fs) * 0.35), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs,
		Color(1.0, 0.84, 0.58, a))


## Flash → art swap at 0.12s → SPRING bloom. Reduce-motion: instant swap, no ceremony.
func kindle_reveal(true_kind: String) -> void:
	if _kindling or kind != "unlit":
		return
	_kindling = true
	if Preferences.active.reduce_motion:
		_apply_kindle_art(true_kind)
		_kindling = false
		return
	_kindle = 1.0
	queue_redraw()
	Motion.bez(self, _set_kindle_flash, 0.45, Motion.CSS_EASE_OUT)
	get_tree().create_timer(0.12).timeout.connect(_on_kindle_swap.bind(true_kind))


func _set_kindle_flash(t: float) -> void:
	_kindle = 1.0 - t
	queue_redraw()


func _on_kindle_swap(true_kind: String) -> void:
	_apply_kindle_art(true_kind)
	_frame_art.pivot_offset = _frame_art.size * 0.5
	_glyph_art.pivot_offset = _glyph_art.size * 0.5
	# Crossfade-in, not a size pop: the flash draws BEHIND the art children
	# so it cannot mask an instant 1.0→0.82 reset — the new face fades in as
	# it grows instead (PR #76 DL R1 MINOR-6).
	_frame_art.scale = Vector2.ONE * 0.78
	_glyph_art.scale = Vector2.ONE * 0.78
	_frame_art.modulate.a = 0.0
	_glyph_art.modulate.a = 0.0
	Motion.bez(self, _set_kindle_fade, 0.15, Motion.CSS_EASE_OUT)
	Motion.bez(self, _set_kindle_bloom, 0.33, Motion.SPRING) \
		.finished.connect(_on_kindle_done)


func _set_kindle_fade(t: float) -> void:
	_frame_art.modulate.a = t
	_glyph_art.modulate.a = t


func _set_kindle_bloom(t: float) -> void:
	var s: float = lerpf(0.78, 1.0, t)
	_frame_art.scale = Vector2(s, s)
	_glyph_art.scale = Vector2(s, s)


func _on_kindle_done() -> void:
	_kindling = false


func _apply_kindle_art(true_kind: String) -> void:
	kind = true_kind
	_glyph_art.texture = load("res://assets/art/ui/node-%s.png" % _art_kind()) as Texture2D
	_seat_art()
	queue_redraw()
	# The bounty is paid the moment the stone kindles, so the chip has nothing
	# left to promise. It goes with the dark lantern it labelled.
	if _chip_layer != null:
		_chip_layer.queue_free()
		_chip_layer = null

