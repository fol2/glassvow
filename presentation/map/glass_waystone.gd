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
## Pane radius of an ordinary stone — an unlit one included. Read it through
## `pane_radius()`, never directly: the promise this docstring used to make on
## its own was that nothing could disagree with what `_draw` draws, and a
## measurement disagreed anyway (PR #80 PM R2). The function is the promise.
const UNLIT_RADIUS: float = 28.0
## Air between the stone's pane and the bounty pill's near edge, in LOCAL px.
## Named because restating it is how three of this phase's review rounds started;
## `chip_rect()` is the only place it is used.
const CHIP_GAP: float = 4.0
## The pill itself, in LOCAL px: height, coin side, and the numeral's size.
const CHIP_H: float = 21.0
const CHIP_ICON: float = 13.0
const CHIP_FONT_SIZE: int = 27
const DRAG_SLOP: float = 12.0
const GLYPH_KINDS: Array[String] = ["monster", "elite", "rest", "shop", "treasure", "event", "unlit", "monument", "boss"]

var index: int = 0
var kind: String = "monster"
var hue: float = 210.0
var reachable: bool = false
var cleared: bool = false
var current: bool = false
var quest_marked: bool = false
## Paid TO the player on kindling. The coin supplies the unit, so the chip text
## is the numeral alone. Zero until the screen passes a bounty through the ctor.
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
	tooltip_text = caption
	set_state(false, false)
	set_process(true)


func set_state(is_reachable: bool, is_cleared: bool, is_current: bool = false) -> void:
	reachable = is_reachable
	cleared = is_cleared
	current = is_current
	focus_mode = Control.FOCUS_ALL if reachable else Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if reachable else Control.CURSOR_ARROW
	var art_tint: Color = Color("edce91") if reachable or current else Color("9caeae")
	if cleared:
		art_tint.a = 0.5
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


## The stone's depth fade. Named rather than written straight onto `modulate` so
## the reason survives: the bounty chip must NOT fade with the glass it labels
## (#69 D2, the information-not-decoration rule P4.3 set for floaters). It no
## longer can — `MapBand.ChipBand` draws it as a sibling rather than a child, so
## there is no inherited alpha to divide back out. An earlier revision did
## exactly that division and its arithmetic was quoted against a 0.12 the frame
## can never show: on screen a stone bottoms out at 0.665-0.762, not 0.12
## (PR #80 DL R1).
func set_depth_alpha(a: float) -> void:
	modulate.a = a


func _draw() -> void:
	var cx: float = _pad.x + WIDTH * 0.5
	var cy: float = _pad.y + EMBLEM_H * 0.5
	var glow: float = (0.5 + 0.5 * sin(_pulse * 2.2)) if reachable else 0.0
	var radius: float = pane_radius()
	if reachable or current:
		draw_circle(Vector2(cx, cy), radius + 12.0,
			Color(GlassStyle.EMBER.r, GlassStyle.EMBER.g, GlassStyle.EMBER.b, 0.08 + glow * 0.05))
	draw_circle(Vector2(cx, cy), radius, Color(0.025, 0.044, 0.047, 0.75 if cleared else 0.96))
	draw_arc(Vector2(cx, cy), radius - 1.0, 0.0, TAU, 48,
		Color(0.57, 0.60, 0.51, 0.65 if reachable or current else 0.36), 1.2, true)
	if reachable or current:
		draw_arc(Vector2(cx, cy), radius + 5.0, 0.0, TAU, 32,
			Color(0.94, 0.78, 0.48, 0.72 + glow * 0.22), 2.0, true)
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
	# `MapBand.ChipBand` paints it instead, one layer for all stones, seated
	# between the waystones and the veil where paint order alone settles it.


func _art(name: String) -> TextureRect:
	var image: TextureRect = TextureRect.new()
	image.texture = _glyph_texture(name.trim_prefix("node-")) if name != "node-frame" else null
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
	var glyph_side: float = frame_side * 1.12
	_glyph_art.position = centre - Vector2.ONE * glyph_side * 0.5
	_glyph_art.size = Vector2.ONE * glyph_side


## Radius of this stone's pane, in LOCAL px — the visible edge everything else
## measures against: the reachable ring at `+5`, the pulse halo at `+12`, the
## focus bracket at `+8`, and the bounty chip's seat.
##
## A function because it was three-way branching arithmetic inside `_draw`, and
## `UNLIT_RADIUS`'s own docstring already promised nothing could disagree with
## what `_draw` draws. Something did: a review probe re-implemented the branch
## from memory as `38 / 28 unlit / 34 otherwise`, and published an overlap table
## against a radius no ordinary stone has ever drawn (PR #80 PM R2). One
## definition means the next measurement asks the drawing code instead.
func pane_radius() -> float:
	return 38.0 if kind == "boss" \
		else (32.0 if kind in ["elite", "treasure"] else UNLIT_RADIUS)


## Whether this stone has a bounty left to promise. False the moment it kindles.
func has_chip() -> bool:
	return kind == "unlit" and bounty > 0


## One label source for both geometry and paint. The coin already says gold is
## paid to the player; repeating that with a `+` costs the numeral scarce width.
func chip_text() -> String:
	return "%d" % bounty


## The pill's rect in LOCAL px, on the side `flip` chooses. ONE definition:
## `paint_bounty_chip` draws it, `chip_reach()` measures its far edge, and
## `ChipBand` scales it into stage space to see whether one pill lands on
## another.
##
## A rect and not a span, because a span was x-only for a round and that is a
## defect, not a simplification: same-COLUMN stones share `world_x` and differ
## only by lane, so their pills always overlap in x while sitting ≥46 stage px
## apart against the pill's scaled stage-space height. Judged on x alone, 36 of
## 150 bounty stones lost their price for more than half their time on screen
## (PR #80 DL R4).
func chip_rect(flip: bool = false) -> Rect2:
	if _chip_font == null:
		_chip_font = get_theme_font(&"font")
	if _chip_font == null:
		return Rect2()
	var tw: float = _chip_font.get_string_size(chip_text(),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, CHIP_FONT_SIZE).x
	var w: float = CHIP_ICON + 4.0 + tw + 16.0
	var side: float = -1.0 if flip else 1.0
	var centre: Vector2 = _pad + Vector2(WIDTH, EMBLEM_H) * 0.5
	return Rect2(centre.x + side * (pane_radius() + CHIP_GAP + w * 0.5) - w * 0.5,
		centre.y - CHIP_H * 0.5, w, CHIP_H)


## How far the pill reaches from the stone's centre, in LOCAL px. `ChipBand.flips`
## asks this before it knows which side the pill takes, so it is the unflipped
## rect's far edge rather than a second piece of arithmetic.
##
## There is no room to widen it. On seed 17634 at phone-portrait the two
## same-lane bounty stones' candidate pill rects already overlap at the captured
## collision camera, so widening makes that known constraint worse.
## Two earlier notes here were wrong in opposite directions — +12 px of budget from
## the layout book's step FLOOR and a farther depth (DL R2, withdrawn by its own
## author at R3), then −17 px from a nearer one (DL R4). Both were arithmetic
## that was never asked of the drawing code. This one was measured at the
## fixture's own camera.
func chip_reach() -> float:
	var rect: Rect2 = chip_rect()
	if rect.size.x <= 0.0:
		return 0.0
	return rect.end.x - (_pad.x + WIDTH * 0.5)


## The bounty chip: a coin and numeral, nothing else. The dark lantern IS the
## "unlit" statement (§2), so the word would only restate the emblem; the coin
## glyph gives the number its unit the same way the HUD does.
##
## Painted onto `ci` — `MapBand.ChipBand`, which has already set the transform to
## this stone's position and scale, so everything below stays in local units.
## `flip` mirrors the pill to the stone's LEFT; the band decides, because only it
## knows the frame. See the seat comment in the body for why neither side is
## under the stone.
##
## #81 measured the old 13 px `+N` below its 10-stage-px / 4.5:1 floor. Removing
## the redundant `+` bought enough width for the smallest passing integer size:
## 27 px inside a 21 px pill. The paired text-on/text-off 20-seed phone sweep
## bottoms out at 10 stage px; 26 px bottoms out at 9, while a 20 px pill clips
## real glyph pixels. The mask limits contrast to actual numeral pixels and
## proves every glyph remains inside the 21 px pill.
func paint_bounty_chip(ci: CanvasItem, flip: bool = false) -> void:
	if _chip_font == null:
		_chip_font = get_theme_font(&"font")
	if _chip_coin == null:
		_chip_coin = load("res://assets/art/ui/coin.png") as Texture2D
	if _chip_font == null:
		return
	var text: String = chip_text()
	var rect: Rect2 = chip_rect(flip)
	# Derived, not measured again: `chip_rect` already asked the font, and the
	# last second measurement of the same thing in this function was the one
	# review round #80 spent most of its length on (DL R5 NIT).
	var tw: float = rect.size.x - CHIP_ICON - 4.0 - 16.0
	# BESIDE the stone, not below it — and what settles it is a per-run FAILURE
	# RATE, not a geometric impossibility. Measured in stage px with the
	# neighbour's radius asked of `pane_radius()` rather than restated, over 20
	# seeds, taking each run's worst chip-and-lower-neighbour pair:
	#
	#   shape                worst pane   worst ring   runs hit: pane / ring
	#   phone-portrait          +2.76        +6.04          11/20   17/20
	#   pad-portrait            −3.30        −0.40           0/20    0/20
	#   pad-landscape           −2.52        +0.38           0/20    4/20
	#   desktop-landscape       −2.52        +0.38           0/20    4/20
	#   phone-landscape         −2.06        +0.73           0/20    4/20
	#
	# Positive is overlap. "Ring" is a REACHABLE neighbour's focus arc at
	# `radius + 5`; its pulse halo at `radius + 12` overlaps at every shape in
	# every run. So the old seat under the pane lands on a neighbour's ink in
	# more than half of phone-portrait runs and crosses a lit ring in one run in
	# five at three further shapes — while clearing comfortably in the rest.
	# The variance is lane jitter: `jx · LANE_JITTER` wanders each stone ±5 stage
	# px across the lane, which is larger than the 0.4–3.3 px the passing runs
	# clear by. A seat that survives by jitter is not a seat.
	#
	# The walk axis is clear by construction instead: the pill's far edge stays
	# within one map step at every shipped depth, even with the larger numeral.
	# The step is 128 stage px at the narrowest shape and 290 at the widest. The
	# pill crosses the dashed edge running to the next node, which is a
	# pale 1px line under an opaque pill: a label over a road, not a label over
	# another lantern (#69 D1).
	#
	# This table is the THIRD reason written for one unchanged decision. The
	# first mixed local and stage px (PM R1); the second measured against a
	# 34 px radius no ordinary stone draws (PM R2). Both were arithmetic that
	# was never asked of the drawing code — which is now `pane_radius()`.
	var cx: float = rect.get_center().x
	var cy: float = rect.get_center().y
	# `cleared` is not reachable from any path this file can see — `has_chip`
	# requires kind "unlit", and main flips `n.unlit` when the bounty is paid,
	# before the node clears. Kept rather than flattened because the ordering
	# that makes it unreachable lives in `main.gd`, not here, and a dimmed chip
	# is a better failure than a bright one (PR #80 DL R2 NIT).
	var a: float = 0.45 if cleared else 1.0
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
	var left: float = cx - (CHIP_ICON + 4.0 + tw) * 0.5
	if _chip_coin != null:
		ci.draw_texture_rect(_chip_coin,
			Rect2(left, cy - CHIP_ICON * 0.5, CHIP_ICON, CHIP_ICON),
			false, Color(1.0, 1.0, 1.0, a))
	ci.draw_string(_chip_font,
		Vector2(left + CHIP_ICON + 4.0, cy + float(CHIP_FONT_SIZE) * 0.35), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, CHIP_FONT_SIZE,
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
	_glyph_art.texture = _glyph_texture(_art_kind())
	_seat_art()
	queue_redraw()
	# The bounty is paid the moment the stone kindles, so `has_chip` goes false
	# with the dark lantern it labelled and `ChipBand` stops drawing it.


func _glyph_texture(glyph: String) -> AtlasTexture:
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = load("res://assets/art/ui/map-glyphs.svg") as Texture2D
	texture.region = Rect2(maxi(GLYPH_KINDS.find(glyph), 0) * 96, 0, 96, 96)
	texture.filter_clip = true
	return texture
