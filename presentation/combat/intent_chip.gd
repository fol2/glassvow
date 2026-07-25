class_name IntentChip
extends Control
## The enemy's telegraph. A parallel port of the web benchmark's `.intent`:
##
##   .intent { height:30px; padding:0 10px 0 6px; gap:4px; border-radius:9px;
##             border:1.5px solid #05070E; font:800 16.5px Alegreya;
##             background: linear-gradient(
##                 color-mix(currentcolor 20%, rgba(12,15,28,.85)), rgba(7,9,18,.88));
##             box-shadow: currentcolor/30% 0 0 13px,
##                         currentcolor/18% 0 0 9px inset,
##                         rgba(255,255,255,.12) 0 1px 0 inset;
##             text-shadow: currentcolor 0 0 8px }
##   .intent .ic       { margin:-6px 2px -6px -16px }
##   .intent .ui-icon  { width:38px; height:38px; filter:
##                       drop-shadow(currentcolor 0 0 .75px) x3 }
##
## EVERYTHING IS ONE COLOUR. The gradient's top, the outer glow, the inner glow,
## the numeral, its bloom and the icon's rim-light all resolve from `currentcolor`
## — set the kind, and the whole chip retunes. That is the system; the numbers
## below are just how far each layer mixes toward it.
##
## The icon is 38px inside a 30px chip and hangs 16px off the LEFT edge. It is
## meant to break out of its own lozenge; do not "fix" that into a tidy inset.

const ICON_PREFIX: String = "res://assets/art/ui/intent-"

const HEIGHT: float = 30.0
const RADIUS: float = 9.0
const BORDER: float = 1.5
const PAD_L: float = 6.0
const PAD_R: float = 10.0
const PAD_BARE: float = 8.0          ## padding when there is no numeral
const GAP: float = 4.0
const ICON: float = 38.0
const ICON_2ND: float = 28.0         ## the smaller face of a compound intent
const IC_MARGIN_L: float = -16.0     ## the break-out
const IC_MARGIN_R: float = 2.0
const IC_GAP: float = 2.0
const NUM_SIZE: int = 17             ## 16.5px in CSS; Godot font sizes are int

const BORDER_COLOR: Color = Color(0.02, 0.027, 0.055)          # #05070E
const BODY_TOP: Color = Color(0.047, 0.059, 0.110, 0.85)       # rgba(12,15,28,.85)
const BODY_BOT: Color = Color(0.027, 0.035, 0.071, 0.88)       # rgba(7,9,18,.88)
const TOP_HAIRLINE: Color = Color(1.0, 1.0, 1.0, 0.12)
const TINT_MIX: float = 0.20         ## currentcolor into the gradient's top

## The four layers CSS expresses as blurs and Godot has no primitive for. Each
## DEFAULT is what shipped, eyeballed against the live benchmark at 3x; the
## statics let ChipLab dial them side by side with the real thing. If a canvas
## shader ever lands these collapse back into constants.
const GLOW_OUT_DEFAULT: float = 0.30      ## outer halo alpha  (CSS: currentcolor/30%)
const GLOW_SIZE_DEFAULT: int = 8          ## outer halo extent (CSS: 13px gaussian)
const GLOW_IN_DEFAULT: float = 0.13       ## inset ring alpha  (CSS: currentcolor/18%)
const ICON_RIM_DEFAULT: float = 1.5       ## icon rim-light    (CSS: 3 drop-shadows)
const NUM_OUTLINE_DEFAULT: int = 3        ## numeral bloom     (CSS: 0 0 8px)

static var glow_out: float = GLOW_OUT_DEFAULT
static var glow_size: int = GLOW_SIZE_DEFAULT
static var glow_in: float = GLOW_IN_DEFAULT
static var icon_rim: float = ICON_RIM_DEFAULT
static var num_outline: int = NUM_OUTLINE_DEFAULT


static func reset_knobs() -> void:
	glow_out = GLOW_OUT_DEFAULT
	glow_size = GLOW_SIZE_DEFAULT
	glow_in = GLOW_IN_DEFAULT
	icon_rim = ICON_RIM_DEFAULT
	num_outline = NUM_OUTLINE_DEFAULT

var _accent: Color = Color(1.0, 0.553, 0.553)
var _icons: Array[Texture2D] = []
var _amount: Label
var _glow: StyleBoxFlat


## A compound id (`attack_block`) leads with its primary. The benchmark gives all
## four attack_* variants the SAME red, so the colour follows the primary too.
static func primary(intent: StringName) -> String:
	return String(intent).split("_", false)[0]


static func accent_for(intent: StringName) -> Color:
	match primary(intent):
		"attack":
			return Color(1.0, 0.553, 0.553)     # #FF8D8D
		"block":
			return Color(0.498, 0.831, 1.0)     # #7FD4FF  (--blk)
		"buff":
			return Color(0.659, 1.0, 0.620)     # #A8FF9E
		"debuff":
			return Color(0.847, 0.627, 1.0)     # #D8A0FF
		"heal":
			return Color(0.490, 0.859, 0.561)   # #7DDB8F  (--good)
		_:
			return Color(1.0, 0.847, 0.627)     # #FFD8A0  staggered / unknown


## One face per segment of the id: `attack_block` shows the sword AND the shield,
## the second at 28px. That is `.ic .ui-icon:nth-child(n+2) { width:28px }` — the
## compound intents are not a fallback, they are a two-icon layout.
static func icons_for(intent: StringName) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for part: String in String(intent).split("_", false):
		var path: String = ICON_PREFIX + part + ".png"
		if ResourceLoader.exists(path):
			out.append(load(path) as Texture2D)
	return out


func _init(intent: StringName = &"attack", amount_text: String = "") -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_PASS   # benchmark marks it cursor:help

	_amount = Label.new()
	_amount.add_theme_font_override("font", StatusChip.numeral_font())
	_amount.add_theme_font_size_override("font_size", NUM_SIZE)
	_amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_amount)

	set_intent(intent, amount_text)


## `amount_text` is pre-formatted — hand CombatScreen's damage string straight
## through, or "" for an intent that telegraphs no figure.
func set_intent(intent: StringName, amount_text: String) -> void:
	_accent = accent_for(intent)
	_icons = icons_for(intent)
	_amount.text = amount_text
	_amount.add_theme_color_override("font_color", _accent)
	# text-shadow: currentcolor 0 0 8px. Godot has no blurred text shadow, so a
	# wide low-alpha outline stands in for the bloom.
	_amount.add_theme_color_override("font_outline_color",
		Color(_accent.r, _accent.g, _accent.b, 0.30))
	# Kept tight. A wide ring is not a blur — past ~3 it stops reading as bloom
	# and starts eating the glyph, which the benchmark's numeral never does.
	_amount.add_theme_constant_override("outline_size", num_outline)

	# The outer 13px halo, borrowed from StyleBoxFlat's own shadow pass — body
	# transparent, so all it contributes is the glow.
	_glow = StyleBoxFlat.new()
	_glow.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_glow.set_border_width_all(0)
	_glow.set_corner_radius_all(int(RADIUS))
	_glow.shadow_color = Color(_accent.r, _accent.g, _accent.b, glow_out)
	# CSS says 13px, but that is a gaussian falloff; StyleBoxFlat's shadow holds
	# its colour much further out, so 13 here is a cloud where the benchmark has
	# a halo. 8 matches what the real chip looks like at 3x.
	_glow.shadow_size = glow_size

	visible = not _icons.is_empty() or amount_text != ""   # .intent:empty
	_relayout()


func _icons_width() -> float:
	if _icons.is_empty():
		return 0.0
	var w: float = ICON
	for i: int in range(1, _icons.size()):
		w += IC_GAP + ICON_2ND
	return w


func _relayout() -> void:
	var has_text: bool = _amount.text != ""
	var icons_w: float = _icons_width()
	var box: Vector2 = Vector2.ZERO
	if not has_text:
		# `.intent:not(:has(.num))` — centred, even padding, no break-out.
		box = Vector2(BORDER * 2.0 + PAD_BARE * 2.0 + icons_w, HEIGHT)
	else:
		var text_w: float = StatusChip.numeral_font().get_string_size(
			_amount.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, NUM_SIZE).x
		# The negative left margin pulls the icon out of the box, so it costs
		# the layout 16px LESS than its own width.
		var ic_advance: float = icons_w + IC_MARGIN_L + IC_MARGIN_R
		box = Vector2(BORDER + PAD_L + ic_advance + GAP + text_w + PAD_R + BORDER, HEIGHT)
		_amount.size = Vector2(text_w + 1.0, HEIGHT)
		_amount.position = Vector2(box.x - PAD_R - BORDER - text_w, 0.0)
	custom_minimum_size = box
	size = box
	queue_redraw()


func _icon_origin_x() -> float:
	if _amount.text == "":
		return BORDER + PAD_BARE
	return BORDER + PAD_L + IC_MARGIN_L


func _draw() -> void:
	var box: Rect2 = Rect2(Vector2.ZERO, size)
	draw_style_box(_glow, box)

	# Body: a rounded rect carrying a vertical gradient. StyleBoxFlat is a flat
	# fill, so the gradient is per-vertex on the polygon instead.
	var body: PackedVector2Array = _rounded_rect(box.grow(-BORDER * 0.5), RADIUS)
	var top: Color = BODY_TOP.lerp(Color(_accent.r, _accent.g, _accent.b, BODY_TOP.a), TINT_MIX)
	var cols: PackedColorArray = PackedColorArray()
	for p: Vector2 in body:
		cols.append(top.lerp(BODY_BOT, clampf(p.y / maxf(box.size.y, 1.0), 0.0, 1.0)))
	draw_polygon(body, cols)

	# Inset glow: two concentric rings fading inward, standing in for a 9px inner
	# blur Godot has no primitive for. Two, not three — a third ring stops
	# reading as a glow and starts reading as a band.
	for i: int in range(2):
		var inset: float = BORDER + 1.0 + float(i) * 2.0
		var a: float = glow_in * (1.0 - float(i) / 2.0)
		_stroke(_rounded_rect(box.grow(-inset), maxf(RADIUS - inset, 1.0)),
			Color(_accent.r, _accent.g, _accent.b, a), 1.5)

	# The 1px white top hairline, inset by the corner so it reads as a lit edge.
	draw_line(Vector2(RADIUS, BORDER), Vector2(box.size.x - RADIUS, BORDER),
		TOP_HAIRLINE, 1.0)

	_stroke(body, BORDER_COLOR, BORDER)

	# Icons last: they overflow the lozenge and must sit above it.
	var x: float = _icon_origin_x()
	for i: int in range(_icons.size()):
		var px: float = ICON if i == 0 else ICON_2ND
		var rect: Rect2 = Rect2(Vector2(x, (HEIGHT - px) * 0.5), Vector2(px, px))
		StatusChip.draw_outlined_texture(self, _icons[i], rect,
			Color(_accent.r, _accent.g, _accent.b, 0.85), icon_rim)
		x += px + IC_GAP


func _stroke(pts: PackedVector2Array, col: Color, width: float) -> void:
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, col, width, true)


## Rounded-rect outline as a point ring, corner-first so the gradient can colour
## each vertex by its own height.
static func _rounded_rect(r: Rect2, radius: float) -> PackedVector2Array:
	var rad: float = minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var pts: PackedVector2Array = PackedVector2Array()
	var centres: Array[Vector2] = [
		Vector2(r.end.x - rad, r.position.y + rad),   # top-right
		Vector2(r.end.x - rad, r.end.y - rad),        # bottom-right
		Vector2(r.position.x + rad, r.end.y - rad),   # bottom-left
		Vector2(r.position.x + rad, r.position.y + rad),  # top-left
	]
	const SEG: int = 4
	for c: int in range(4):
		var base: float = -PI * 0.5 + float(c) * PI * 0.5
		for s: int in range(SEG + 1):
			var ang: float = base + (PI * 0.5) * (float(s) / float(SEG))
			pts.append(centres[c] + Vector2(cos(ang), sin(ang)) * rad)
	return pts
