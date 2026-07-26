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


const NUM_RIGHT: float = -2.0

## Where the digits actually SIT. `bottom:-4px` positions a BOX, but a box is not
## what the eye reads — digits carry no descender, so the bottom of "99" IS its
## baseline. Anchoring the baseline is also the only way this placement survives
## a change to NUM_SIZE: the old box height (NUM_SIZE + 4) shifted the numeral
## vertically whenever the size moved, which nobody asked it to do.
##
## 33.0 is where the ported chip already put it — validated at 3x against the
## live benchmark. This states that number instead of arriving at it by accident
## through a guessed line-height.
const NUM_BASELINE: float = 33.0


static func reset_knobs() -> void:
	outline_px = OUTLINE_PX_DEFAULT
	num_outline = NUM_OUTLINE_DEFAULT

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

var _tex: Texture2D = null
var _count: Label


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


## `info` is the content status row. The chip draws from the id and the number
## alone, and the copy it carries is read back by the tooltip layer through the
## screen's own catalogue — so this stays in the signature for callers that
## already pass it, and the chip itself has no use for it.
## The status this chip carries, so the tooltip layer can name it without the
## row having to remember what it built.
var status_id: StringName = &""


func _init(id: StringName, count: int = 1, _info: Dictionary = {}) -> void:
	status_id = id
	_tex = icon_for(id)
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	# Sampled through mipmaps: the source art is 512px drawn at 32.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# PASS, not IGNORE — the hover has to land for the tooltip, but the pointer
	# still reaches the pane behind, which hit-tests its own rect for drop
	# targeting. Flip to IGNORE if assembly finds it steals a drop.
	mouse_filter = Control.MOUSE_FILTER_PASS

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


func set_count(value: int) -> void:
	_count.visible = value >= MIN_SHOWN_COUNT
	if not _count.visible:
		return
	_count.text = str(value)
	var f: FontFile = numeral_font()
	var w: float = f.get_string_size(
		_count.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, NUM_SIZE).x
	# The font's REAL line height — 18 at 12px, where the old box was NUM_SIZE + 4
	# = 16. A 12px Alegreya glyph needs 13 of ascent and 5 of descent, so the
	# numeral was overflowing its own Control by 2px and only looked right
	# because a Label does not clip.
	# right:-2 still sets the right edge; the baseline sets the height.
	_count.size = Vector2(w, f.get_height(NUM_SIZE))
	_count.position = Vector2(SIZE - w - NUM_RIGHT, NUM_BASELINE - f.get_ascent(NUM_SIZE))


func _draw() -> void:
	var box: Rect2 = Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
	if _tex == null:
		_draw_missing(box)
		return
	draw_outlined_texture(self, _tex, box, Color(0.0, 0.0, 0.0, 1.0), outline_px)


## A status whose PNG is not on disk drew NOTHING — an invisible 32px hole with
## a stack count floating next to it, which reads as a layout bug rather than a
## missing file, and costs an afternoon to trace back to a filename. Content is
## data-driven and the statuses will outrun their art at some point, so the gap
## says so out loud.
## ponytail: a red box, not a fallback glyph. Content carries a `glyph` per
## status — use it here the day a missing icon has to look acceptable to a
## PLAYER rather than obvious to us.
func _draw_missing(box: Rect2) -> void:
	var hole: Rect2 = box.grow(-3.0)
	draw_rect(hole, Color(0.0, 0.0, 0.0, 0.55))
	draw_rect(hole, Color(1.0, 0.35, 0.40, 0.90), false, 1.0)


## The `#status-outline` port, also used by IntentChip for its icon rim — same
## geometry, different colour and radius. Modulating the art to a flat colour
## keeps its alpha, which is exactly `feFlood` composited into the dilated mask.
static func draw_outlined_texture(on: CanvasItem, tex: Texture2D, box: Rect2,
		tint: Color, radius: float) -> void:
	for dir: Vector2 in RING:
		on.draw_texture_rect(tex, Rect2(box.position + dir * radius, box.size), false, tint)
	on.draw_texture_rect(tex, box, false, Color.WHITE)
