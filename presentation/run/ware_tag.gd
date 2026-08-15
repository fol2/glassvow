class_name WareTag
extends Control
## A ware's tag: its name, one effect line and a price chip, tied to the goods
## by a drawn thread and a knot, with no box anywhere. Concept C1's `.tag`
## (`docs/design/2026-08-14-ui-direction/shop-c1.html`), and #242 slice 2.
##
## Everything is `_draw`. Four faces and two primitives cost one node per ware
## instead of five, a Label cannot strike its own text through, and the whole
## block re-flows from a single scale factor — which is what
## `StallLayout.type_scale` feeds it, so the tag shrinks with the painting
## rather than with the window. `reflow()` is the only call that moves anything:
## it measures, sets `size`, and returns the height the caller seats around.
##
## THE STATE GRAMMAR, in one place (mock § STATE AFTER USE):
##
##   SOLD / SPENT — the ware itself is gone (a bare hook, an empty rack pocket,
##     shears already used). The tag stays, its name struck, and the state word
##     stands where the price was.
##   UNAFFORDABLE — the ware stays exactly where it is and only the price turns
##     DANGER. A hole versus a red number: nothing to read to tell them apart.

## Type sizes at the identity shape, in px, measured off the mock's `.tag`.
const NAME_PX: float = 11.5
const EFFECT_PX: float = 13.0
const PRICE_PX: float = 14.5
const EYEBROW_PX: float = 9.5
const STATE_PX: float = 10.0
const EMBLEM_PX: float = 34.0
## Tracking as a fraction of the size it rides on (`letter-spacing` in em).
const NAME_TRACK: float = 0.13
const WIDE_TRACK: float = 0.34
const PRICE_TRACK: float = 0.03
## A tag narrower than this is unreadable whatever its region does, so it grows
## past its region instead and the caller clamps it back inside the frame.
const MIN_WIDTH: float = 118.0
const MIN_PX: int = 7

const NAME_INK: Color = Color("#e6cd92")
const COLD_INK: Color = Color("#bfe2ff")
const MUTED: Color = Color("#a3abc4")
const HALO_INK: Color = Color(0.016, 0.023, 0.055)

var ware_name: String = ""
var effect: String = ""
var price: int = 0
## The quest offer's `GATE` line; empty on everything else.
var eyebrow: String = ""
var state_word: String = ""
var cold: bool = false
## The shears above the merchant's own service.
var emblem: bool = false
## A rack card carries its name and text on its face, so its tag is the price
## row alone — until it sells, when the pocket needs the struck name.
var price_only: bool = false
var sold: bool = false
var affordable: bool = true
## Where the thread ties to the ware, in the PARENT's space. Zero means untied:
## a rack column stands under its own card and needs no thread.
var tie: Vector2 = Vector2.ZERO

var _scale: float = 1.0
var _rows: Array[Dictionary] = []
var _name_face: FontVariation = RunStyle.tracked(GlassStyle.CINZEL_700, 0)
var _wide_face: FontVariation = RunStyle.tracked(GlassStyle.CINZEL_700, 0)
var _price_face: FontVariation = RunStyle.tracked(GlassStyle.CINZEL_700, 0)
var _body_face: Font = GlassStyle.face(GlassStyle.ALEGREYA_400)

static var _halo: GradientTexture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(is_sold: bool, can_pay: bool) -> void:
	sold = is_sold
	affordable = can_pay
	queue_redraw()


## Measure and lay the block out at this width and type scale; returns its
## height. The width is the region's, unless the region has shrunk below what
## the smallest legible tag needs.
func reflow(width: float, factor: float) -> float:
	_scale = maxf(factor, 0.3)
	_rows.clear()
	var w: float = maxf(width, MIN_WIDTH * _scale)
	var y: float = (EMBLEM_PX + 11.0) * _scale if emblem else 0.0
	if not eyebrow.is_empty() and not sold:
		y = _row(y, w, eyebrow, _wide_face, EYEBROW_PX, WIDE_TRACK,
			Color(GlassStyle.GLASS, 0.80), false, false) + 5.0 * _scale
	if sold or not price_only:
		y = _row(y, w, ware_name.to_upper(), _name_face, NAME_PX, NAME_TRACK,
			MUTED if sold else (COLD_INK if cold else NAME_INK), false, sold) \
			+ 4.0 * _scale
	if not price_only and not effect.is_empty():
		y = _row(y, w, effect, _body_face, EFFECT_PX, 0.0,
			Color(RunStyle.TEXT, 0.48 if sold else 0.76), true, false) + 6.0 * _scale
	if sold:
		y = _row(y, w, state_word, _wide_face, STATE_PX, WIDE_TRACK,
			Color(MUTED, 0.98), false, false)
	else:
		y = _row(y, w, "◈  %d" % price, _price_face, PRICE_PX, PRICE_TRACK,
			RunStyle.GOLD if affordable else RunStyle.DANGER, false, false)
	size = Vector2(w, y)
	queue_redraw()
	return y


## One line of the block, appended for `_draw` to walk. Tracking rides on the
## face instance rather than the row, so each tracking value owns its own
## FontVariation — one shared face would draw every row at the last one set.
func _row(y: float, w: float, text: String, font: Font, px: float, track: float,
		colour: Color, wrap: bool, strike: bool) -> float:
	var pt: int = maxi(MIN_PX, int(roundf(px * _scale)))
	var varied: FontVariation = font as FontVariation
	if varied != null:
		varied.spacing_glyph = int(roundf(track * float(pt)))
	if wrap:
		var block: float = font.get_multiline_string_size(text,
			HORIZONTAL_ALIGNMENT_LEFT, w, pt).y
		_rows.append({
			"text": text, "font": font, "px": pt, "y": y, "run": w,
			"colour": colour, "wrap": true, "strike": strike,
		})
		return y + block
	# A name is one line and is never clipped — the mock's `white-space: nowrap`
	# — so a name too long for its region shrinks to fit it instead of losing
	# its last word. Measured: "PHIAL OF HELD LIGHT" lost four characters.
	var run: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pt).x
	if run > w and run > 0.0:
		pt = maxi(MIN_PX, int(floorf(float(pt) * w / run)))
		if varied != null:
			varied.spacing_glyph = int(roundf(track * float(pt)))
		run = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pt).x
	_rows.append({
		"text": text, "font": font, "px": pt, "y": y, "run": run,
		"colour": colour, "wrap": false, "strike": strike,
	})
	return y + font.get_height(pt)


func _draw() -> void:
	if _rows.is_empty():
		return
	# The mock's `.tag::before`: a soft ink bloom so the type holds over a
	# painted background that is neither dark nor even.
	var pad: Vector2 = Vector2(19.0, 15.0) * _scale
	draw_texture_rect(_halo_tex(), Rect2(-pad, size + pad * 2.0), false)
	_draw_thread()
	if emblem:
		_draw_shears(size.x * 0.5, 0.0, EMBLEM_PX * _scale)
	var centred: bool = price_only or emblem
	for row: Dictionary in _rows:
		var font: Font = row["font"]
		var pt: int = row["px"]
		var text: String = row["text"]
		var top: float = row["y"]
		var run: float = row["run"]
		var colour: Color = row["colour"]
		var x0: float = (size.x - run) * 0.5 if centred else 0.0
		var pen: Vector2 = Vector2(x0, top + font.get_ascent(pt))
		if row["wrap"]:
			draw_multiline_string(font, pen, text,
				HORIZONTAL_ALIGNMENT_CENTER if centred else HORIZONTAL_ALIGNMENT_LEFT,
				run, pt, -1, colour)
		else:
			draw_string(font, pen, text, HORIZONTAL_ALIGNMENT_LEFT, -1, pt, colour)
		if row["strike"]:
			var mid: float = top + font.get_height(pt) * 0.52
			draw_line(Vector2(x0, mid), Vector2(x0 + run, mid),
				Color(RunStyle.DANGER, 0.92), maxf(1.0, 1.6 * _scale))


func _draw_thread() -> void:
	if tie == Vector2.ZERO:
		return
	var from: Vector2 = tie - position
	var to: Vector2 = Vector2(clampf(from.x, 2.0, maxf(2.0, size.x - 2.0)),
		0.0 if from.y <= 0.0 else size.y)
	draw_line(from, to, Color(RunStyle.GOLD, 0.22 if sold else 0.58),
		maxf(1.0, _scale))
	draw_circle(to, maxf(1.5, 2.0 * _scale),
		Color(RunStyle.GOLD, 0.30 if sold else 0.85))


## The merchant's shears, drawn rather than shipped as art: two blades crossing
## at a pivot, two handles, two rings.
func _draw_shears(cx: float, top: float, s: float) -> void:
	var steel: Color = Color(0.84, 0.75, 0.58, 0.36 if sold else 0.92)
	var brass: Color = Color(RunStyle.GOLD, 0.32 if sold else 0.86)
	var pivot: Vector2 = Vector2(cx, top + s * 0.54)
	var stroke: float = maxf(1.0, s * 0.055)
	draw_line(Vector2(cx - s * 0.20, top + s * 0.04), pivot, steel, stroke * 1.6)
	draw_line(Vector2(cx + s * 0.20, top + s * 0.04), pivot, steel, stroke * 1.6)
	draw_line(pivot, Vector2(cx - s * 0.21, top + s * 0.76), brass, stroke * 1.5)
	draw_line(pivot, Vector2(cx + s * 0.21, top + s * 0.76), brass, stroke * 1.5)
	draw_arc(Vector2(cx - s * 0.21, top + s * 0.86), s * 0.13, 0.0, TAU, 20,
		brass, stroke)
	draw_arc(Vector2(cx + s * 0.21, top + s * 0.86), s * 0.13, 0.0, TAU, 20,
		brass, stroke)
	draw_circle(pivot, maxf(1.0, s * 0.05), brass)


static func _halo_tex() -> GradientTexture2D:
	if _halo == null:
		_halo = GlassStyle.grad_tex(
			PackedColorArray([Color(HALO_INK, 0.82), Color(HALO_INK, 0.40),
				Color(HALO_INK, 0.0)]),
			PackedFloat32Array([0.0, 0.56, 1.0]), true,
			Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	return _halo
