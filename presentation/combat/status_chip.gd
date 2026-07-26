class_name StatusChip
extends Control
## One status readout: the icon, and a stack count only when it is worth saying.
## A parallel port of the web benchmark's `.schip` — see the CSS this mirrors:
##
##   .schip      { width:32px; height:32px; background:none; border:none }
##   .schip-art  { width:32px; height:32px; filter:url(#status-outline) }
##   .schip .n   { position:absolute; right:-2px; bottom:-4px; font:800 12px
##                 Alegreya; tabular-nums; color:#fff; 4-way 1px black shadow }
##
## THERE IS NO SHELL. No pill, no rim, no plate. What separates the art from the
## ground is `#status-outline`: feMorphology dilate 0.9px → flood #000 → merge
## under the source. A black silhouette outline, not a coloured one — because
## the status row sits over the lit SCENE (stone, lanterns, enemy sprites), not
## over flat indigo, and black is what reads against a mid-tone busy ground.
##
## Ported as offset draws rather than a shader: eight black copies of the art at
## 0.9px on a ring, then the art on top. Same result as the dilate, one node, no
## new file.
## ponytail: 9 draw calls per chip. A status row is <10 chips, so this is free —
## move it to a canvas_item shader only if some screen ever shows dozens.

## ── BEYOND THE BENCHMARK ──────────────────────────────────────────────────
## Three things the ported chip cannot do, and one finding that governs all of
## them. `style` picks a treatment; BENCH is the port above, unchanged.
##
## THE FINDING: the chip does not say whether a status is HELPING you. Seventeen
## statuses render as seventeen small dark jewels with the same black halo, and
## the only difference between "you are Cracked" and "you are Annealed" is art
## detail that does not survive being drawn at 32px. In a fight the first
## question is never "which status is that" — it is "am I in trouble". The
## benchmark answers that question nowhere, and a hover tooltip is not an
## answer at combat speed on a device with no cursor.
##
## Every treatment below therefore carries VALENCE before it carries identity:
## you should know the row is bad news before you have read a single icon.
##
## The second finding is the game's own vocabulary. The statuses are not
## abstract buffs — they are named Annealed, Vitrified, Brittle, Cracked,
## Splinters, Dimmed, Alight, Beacon, Warmth, Smolder. Every one of them is a
## state of GLASS or a state of LIGHT. The material was chosen for us; the port
## just never used it.
##
##   SETTING   the chip is a leaded pane. A came bezel in the game's own
##             hexagon cut (GlassWaystone's) holds the art, lit from behind.
##             Brass came = boon, cold iron = affliction, and an affliction's
##             pane is fractured. Valence reads from the SILHOUETTE's colour
##             before the art resolves at all.
##   LAMP      no shell, keeping the benchmark's honesty — but lit. The art is
##             glass with a lamp behind it, throwing its own colour onto the
##             scene. Boons burn warm, afflictions go cold and soak. Stack
##             depth is carried by how far the light reaches.
##   CABOCHON  the card's answer, at chip scale: one shader, an analytic dome
##             normal, a real specular from the room's lamp. See
##             status_gem.gdshader. An affliction is the same gem, soaked and
##             cracked — never a different shape.
enum Style { BENCH, SETTING, LAMP, CABOCHON }
static var style: Style = Style.BENCH

## The four that are done TO you. Everything else is a boon. This is a
## presentation fact, not a domain one — content carries no `tone` for any
## status (all seventeen are null), so the split has to live somewhere, and the
## screen that has to colour them is the honest place for it until content
## grows the field.
## ponytail: a 4-name list, not a lookup service. Move it into content the day
## a status needs valence anywhere other than this chip.
const AFFLICTIONS: Array[StringName] = [&"weak", &"frail", &"vulnerable", &"poison"]

const CAME_BOON: Color = Color(0.784, 0.604, 0.188)     # #C89A30 brass
const CAME_BAD: Color = Color(0.145, 0.157, 0.212)      # cold iron
const GLOW_BOON: Color = Color(1.0, 0.60, 0.30)         # lantern fire
const GLOW_BAD: Color = Color(0.42, 0.62, 0.95)         # cold, and wrong

const ICON_DIR: String = "res://assets/art/statuses/"

## `.schip` is a 32px square. The numeral hangs OUTSIDE it (right:-2, bottom:-4)
## and the row's 6px gap absorbs the overhang, so the box stays 32.
const SIZE: float = 32.0
const NUM_SIZE: int = 12

## The two values that are a JUDGEMENT, not a measurement. The CSS says dilate
## 0.9px and a 1px 4-way text shadow, but Godot's ring outline is continuous
## where the browser stamps corners, so the matching number is not the same
## number. Exposed as statics so ChipLab can dial them against the live
## benchmark; the DEFAULT consts are what shipped.
const OUTLINE_PX_DEFAULT: float = 0.9
const NUM_OUTLINE_DEFAULT: int = 2
static var outline_px: float = OUTLINE_PX_DEFAULT
static var num_outline: int = NUM_OUTLINE_DEFAULT


static func reset_knobs() -> void:
	outline_px = OUTLINE_PX_DEFAULT
	num_outline = NUM_OUTLINE_DEFAULT
const NUM_RIGHT: float = -2.0
const NUM_BOTTOM: float = -4.0

## Below 2 the benchmark renders no `.n` element at all — one stack of anything
## is just the icon. Showing "1" on every chip is noise the row cannot afford.
const MIN_SHOWN_COUNT: int = 2

## Eight-way unit ring: the cheap stand-in for a round dilate. At 0.9px the
## difference between this and a true morphology pass is not visible.
const RING: Array[Vector2] = [
	Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0),
	Vector2(0.70710678, 0.70710678), Vector2(-0.70710678, 0.70710678),
	Vector2(0.70710678, -0.70710678), Vector2(-0.70710678, -0.70710678),
]

const GEM_SHADER: String = "res://presentation/combat/status_gem.gdshader"

var _tex: Texture2D = null
var _count: Label
var _id: StringName = &""
var _count_value: int = 1


static func icon_for(status_id: StringName) -> Texture2D:
	var path: String = ICON_DIR + String(status_id) + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Alegreya is the benchmark's reading face and it carries the chip numerals too
## (`.schip .n` computes to Alegreya 800). Only 400 and 700 are bundled here, so
## 700 is the nearest weight — Cinzel would be the wrong face entirely.
static var _numerals: FontFile = null


static func numeral_font() -> FontFile:
	if _numerals == null:
		_numerals = load(GlassStyle.ALEGREYA_700) as FontFile
	return _numerals


## `info` is optional and only feeds the hover text — the chip needs nothing but
## an id and a number to draw. The benchmark marks these `cursor: help`, so the
## tooltip is parity, not decoration.
func _init(status_id: StringName, count: int = 1, info: Dictionary = {}) -> void:
	_id = status_id
	_tex = icon_for(status_id)
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	# Sampled through mipmaps: the source art is 512px drawn at 32.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# PASS, not IGNORE — the hover has to land for the tooltip, but the pointer
	# still reaches the pane behind, which hit-tests its own rect for drop
	# targeting. Flip to IGNORE if assembly finds it steals a drop.
	mouse_filter = Control.MOUSE_FILTER_PASS
	if not info.is_empty():
		tooltip_text = "%s\n%s" % [str(info.get("name", status_id)), str(info.get("desc", ""))]

	_count = Label.new()
	_count.add_theme_font_override("font", numeral_font())
	_count.add_theme_font_size_override("font_size", NUM_SIZE)
	_count.add_theme_color_override("font_color", Color.WHITE)
	# Stands in for the benchmark's 4-way 1px black text-shadow. Godot's outline
	# rings the glyph instead of stamping four copies — same job, fewer seams.
	_count.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	# 2, not 4: the CSS stamps the shadow at 1px on four diagonals, and Godot's
	# ring is continuous — matching the number gives a visibly fatter halo than
	# the benchmark has. Checked against the real chip at 3x.
	_count.add_theme_constant_override("outline_size", num_outline)
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count)

	set_count(count)
	_apply_style()


func set_count(value: int) -> void:
	_count_value = value
	_count.visible = value >= MIN_SHOWN_COUNT
	if not _count.visible:
		return
	_count.text = str(value)
	var w: float = numeral_font().get_string_size(
		_count.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, NUM_SIZE).x
	var h: float = float(NUM_SIZE) + 4.0
	# right:-2 / bottom:-4 from the box's far edges, so the numeral overhangs.
	_count.size = Vector2(w, h)
	_count.position = Vector2(SIZE - w - NUM_RIGHT, SIZE - h - NUM_BOTTOM)


## Boon or affliction. Positive is the default because most statuses are, and
## because an unknown status should not look like a threat.
static func is_affliction(status_id: StringName) -> bool:
	return AFFLICTIONS.has(status_id)


## The hexagon every emblem in this game is seated in — GlassWaystone cuts the
## same shape for the map. The fight and the road should not disagree about what
## a piece of set glass looks like.
static func _pane(centre: Vector2, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(centre.x, centre.y - h),
		Vector2(centre.x + w, centre.y - h * 0.45),
		Vector2(centre.x + w, centre.y + h * 0.45),
		Vector2(centre.x, centre.y + h),
		Vector2(centre.x - w, centre.y + h * 0.45),
		Vector2(centre.x - w, centre.y - h * 0.45),
	])


func _draw() -> void:
	if _tex == null:
		return
	var box: Rect2 = Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
	match style:
		Style.SETTING:
			_draw_setting(box)
		Style.LAMP:
			_draw_lamp(box)
		Style.CABOCHON:
			# The material shades it, but something still has to be RASTERISED or
			# the shader never runs. Drawing the art itself also gives the
			# fragment stage a sane 0..1 UV across the chip, which draw_rect
			# would not.
			draw_texture_rect(_tex, box, false, Color.WHITE)
		_:
			draw_outlined_texture(self, _tex, box, Color(0.0, 0.0, 0.0, 1.0), outline_px)


## SETTING — the art seated in lead, lit from behind.
func _draw_setting(box: Rect2) -> void:
	var bad: bool = is_affliction(_id)
	var c: Vector2 = box.get_center()
	var came: Color = CAME_BAD if bad else CAME_BOON
	var lamp: Color = GLOW_BAD if bad else GLOW_BOON
	var pane: PackedVector2Array = _pane(c, SIZE * 0.47, SIZE * 0.54)

	# The light BEHIND the pane, spilling past its own edges. Additive, because
	# unlit glass contributes nothing — there is no "off" colour to blend to.
	draw_circle(c, SIZE * 0.62, Color(lamp.r, lamp.g, lamp.b, 0.10 if bad else 0.16))
	draw_colored_polygon(pane, Color(0.02, 0.027, 0.055, 0.88))
	draw_colored_polygon(pane, Color(lamp.r, lamp.g, lamp.b, 0.16 if bad else 0.26))

	# The art, inset so the came reads as holding it rather than overlapping it.
	var inset: float = SIZE * 0.17
	draw_texture_rect(_tex, box.grow(-inset), false,
		Color(1.0, 1.0, 1.0, 0.55 if bad else 1.0))

	# An affliction's pane is broken. Three strikes, not a spiderweb — at 32px
	# anything denser turns into a grey smudge over the art.
	if bad:
		var f: Color = Color(0.86, 0.92, 1.0, 0.62)
		draw_line(c + Vector2(-11.0, -6.0), c + Vector2(4.0, 3.0), f, 1.1)
		draw_line(c + Vector2(4.0, 3.0), c + Vector2(1.0, 12.0), f, 1.0)
		draw_line(c + Vector2(4.0, 3.0), c + Vector2(12.0, -1.0), f, 1.0)

	var ring: PackedVector2Array = pane.duplicate()
	ring.append(pane[0])
	draw_polyline(ring, Color(0.02, 0.027, 0.055, 0.95), 2.6, true)
	draw_polyline(ring, Color(came.r, came.g, came.b, 0.95 if bad else 1.0), 1.3, true)


## LAMP — no shell at all. The art IS the glass; the chip is what gets through.
func _draw_lamp(box: Rect2) -> void:
	var bad: bool = is_affliction(_id)
	var c: Vector2 = box.get_center()
	var lamp: Color = GLOW_BAD if bad else GLOW_BOON
	# Stack depth is REACH. A single stack of Warmth is a candle; nine is a
	# lantern. The numeral still says the exact figure, but the row can be read
	# for how much trouble it is in without reading any of them.
	var depth: float = clampf(log(float(_count_value) + 1.0) / log(10.0), 0.0, 1.0)
	var reach: float = SIZE * (0.52 + 0.34 * depth)

	for i: int in range(3):
		var t: float = 1.0 - float(i) / 3.0
		draw_circle(c, reach * t,
			Color(lamp.r, lamp.g, lamp.b, (0.05 if bad else 0.085) * (0.4 + 0.6 * depth)))

	# An affliction takes light instead of giving it: the art goes dark and only
	# its rim survives, which is what a silhouette against a window looks like.
	if bad:
		draw_outlined_texture(self, _tex, box, Color(lamp.r, lamp.g, lamp.b, 0.85), 1.3)
		draw_texture_rect(_tex, box, false, Color(0.30, 0.36, 0.52, 1.0))
	else:
		draw_outlined_texture(self, _tex, box, Color(0.0, 0.0, 0.0, 0.92), outline_px)


## CABOCHON needs a material rather than draw calls, and SETTING/LAMP need it
## cleared again — a ShaderMaterial left behind would silently re-tint every
## later style the same node is switched to.
func _apply_style() -> void:
	if style != Style.CABOCHON:
		material = null
		return
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(GEM_SHADER) as Shader
	var bad: bool = is_affliction(_id)
	mat.set_shader_parameter("icon", _tex)
	mat.set_shader_parameter("tone", GLOW_BAD if bad else GLOW_BOON)
	mat.set_shader_parameter("affliction", 1.0 if bad else 0.0)
	mat.set_shader_parameter("crack", 1.0 if bad else 0.0)
	material = mat


## The `#status-outline` port, also used by IntentChip for its icon rim — same
## geometry, different colour and radius. Modulating the art to a flat colour
## keeps its alpha, which is exactly `feFlood` composited into the dilated mask.
static func draw_outlined_texture(on: CanvasItem, tex: Texture2D, box: Rect2,
		tint: Color, radius: float) -> void:
	for dir: Vector2 in RING:
		on.draw_texture_rect(tex, Rect2(box.position + dir * radius, box.size), false, tint)
	on.draw_texture_rect(tex, box, false, Color.WHITE)
