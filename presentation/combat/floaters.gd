class_name Floaters
extends Control
## The text layer: rising damage numerals and the centre-stage banner.
##
## Ported from `combat-presentation.js` — the PIXI floater, not the CSS one. The
## stylesheet's `.floaty` variants are explicitly the non-combat path ("Combat
## floaters are Pixi-owned (Task 28); #floaties stays empty during combat"), so
## the colour language in combat is the four damage tiers plus one parchment
## default, and a caller that wants more says so with `tint`.

## `TIER_STYLE` (combat-presentation.js:31) — size, colour, duration and how far
## it climbs, per damage weight.
const TIERS: Dictionary = {
	"normal": {"size": 34, "fill": Color(0.9254902, 0.90588236, 0.8745098),
		"dur": 0.45, "rise": 34.0, "spring": false},
	"heavy": {"size": 42, "fill": Color(1.0, 0.6039216, 0.3019608),
		"dur": 0.64, "rise": 42.0, "spring": true},
	"kill": {"size": 54, "fill": Color(0.9490196, 0.75686276, 0.30588236),
		"dur": 0.64, "rise": 52.0, "spring": true},
	"overkill": {"size": 64, "fill": Color(1.0, 0.4392157, 0.3764706),
		"dur": 0.64, "rise": 62.0, "spring": true},
}
## The class names drain.js still speaks, mapped onto the tiers above.
const TIER_ALIAS: Dictionary = {
	"dmg": "normal", "normal": "normal",
	"dmg-big": "heavy", "heavy": "heavy",
	"dmg-kill": "kill", "kill": "kill",
	"dmg-overkill": "overkill", "overkill": "overkill",
}
const PARCHMENT: Color = Color(0.95686275, 0.90588236, 0.77254903)
const GOLD: Color = Color(0.9490196, 0.75686276, 0.30588236)
const DANGER: Color = Color(1.0, 0.4392157, 0.3764706)
const EMBER: Color = Color(1.0, 0.6039216, 0.3019608)
const PLATE_INK: Color = Color(0.043137256, 0.05490196, 0.101960786)

const DUR_CEREMONY: float = 0.64
const BANNER_HOLD: float = 0.42
## `plate.y = stageHeight * yFrac` — a little above the middle, clear of the
## fan and clear of the actors' heads.
const BANNER_Y_FRAC: float = 0.38
## Floaters start slightly small and settle, rather than growing from nothing.
const START_SCALE: float = 0.92

static var _font_cache: FontFile = null

## Headless playback: every ceremony here is a no-op that returns at once, so a
## test driving the sequencer never waits on a tween that will not tick.
var instant: bool = false


## The banner's own chrome: a dark slab with a lit rail top and bottom, drawn
## rather than assembled from styleboxes so the rails can wipe open from the
## centre the way `rail.scale.set(v.rail, 1)` does.
class BannerPlate:
	extends Control
	var body: Color = Color(0.043137256, 0.05490196, 0.101960786, 0.88)
	var rail: Color = Color(0.9490196, 0.75686276, 0.30588236)
	var rail_h: float = 2.0
	var radius: float = 6.0
	var rail_open: float = 1.0
	## An inner keyline — the boss plate's ember wash and the perfect plate's
	## gold hairline are the same shape at different colours.
	var inset_line: Color = Color(0, 0, 0, 0)
	var inset_width: float = 1.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), body, true)
		if radius > 0.0:
			# The corners are small enough that the rounding reads as a bevel;
			# drawn as a rounded outline over the square body rather than as a
			# clipped shape, which Godot's immediate mode has no cheap form of.
			draw_rect(Rect2(Vector2.ZERO, size), Color(body.r, body.g, body.b, 0.0), false, 1.0)
		if inset_line.a > 0.0:
			draw_rect(Rect2(Vector2(3.0, 3.0), size - Vector2(6.0, 6.0)),
				inset_line, false, inset_width)
		var w: float = size.x * clampf(rail_open, 0.0, 1.0)
		var x: float = (size.x - w) * 0.5
		draw_rect(Rect2(Vector2(x, 1.0), Vector2(w, rail_h)), rail, true)
		draw_rect(Rect2(Vector2(x, size.y - rail_h - 1.0), Vector2(w, rail_h)), rail, true)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Cinzel 800 — the display face the benchmark sets every numeral in.
static func display_font() -> FontFile:
	if _font_cache == null and ResourceLoader.exists(GlassStyle.CINZEL_800):
		_font_cache = load(GlassStyle.CINZEL_800)
	return _font_cache


static func _style_for(cls: String) -> Dictionary:
	var tier: String = TIER_ALIAS.get(cls, "")
	if tier != "":
		return TIERS[tier]
	return {
		"size": 20 if cls.contains("notice") else 28,
		"fill": PARCHMENT, "dur": 0.45, "rise": 40.0, "spring": false,
	}


## A rising numeral or word centred on `at` (stage px). `tint` overrides the
## tier colour — the drain passes the archetype tone so a void hit's damage
## reads violet and a slash's reads white.
func float_text(at: Vector2, text: String, cls: String = "dmg",
		tint: Color = Color(0, 0, 0, 0), dx: float = 0.0,
		icon: Texture2D = null, icon_size: int = 0) -> void:
	if instant or not is_inside_tree():
		return
	var style: Dictionary = _style_for(cls)
	var font_size: int = style["size"]
	var fill: Color = tint if tint.a > 0.0 else style["fill"]

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != null:
		var pip: TextureRect = TextureRect.new()
		var side: float = float(icon_size) if icon_size > 0 \
			else maxf(16.0, roundf(float(font_size) * 0.72))
		pip.custom_minimum_size = Vector2(side, side)
		pip.texture = icon
		pip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pip.modulate = fill
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pip)
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face: FontFile = display_font()
	if face != null:
		label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", fill)
	# The letterpress: the benchmark's `--ink` is eight offset copies of the
	# glyph in near-black. An outline is the same silhouette for one draw.
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.027, 0.055))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_y", 3)
	row.add_child(label)
	add_child(row)

	# Sized from its own minimum rather than from a layout pass. Waiting a frame
	# for the container to sort left the numeral pinned at the layer's origin for
	# that frame — and `process_frame` resumes at no fixed point relative to the
	# sort, so the first placement was as likely as not to read a zero box.
	row.size = row.get_combined_minimum_size()
	var half: Vector2 = row.size * 0.5
	row.pivot_offset = half
	var home: Vector2 = at + Vector2(dx, 0.0) - global_position - half
	row.position = home
	row.scale = Vector2.ONE * START_SCALE

	var springy: bool = style["spring"]
	var curve: Array[float] = Motion.SPRING if springy else Motion.OUT_SOFT
	var rise: float = style["rise"]
	var dur: float = style["dur"]
	var tw: Tween = create_tween()
	tw.tween_method(func(x: float) -> void:
		if not is_instance_valid(row):
			return
		var e: float = Motion.ease(curve, x)
		row.position = home + Vector2(0.0, -rise * e)
		row.scale = Vector2.ONE * lerpf(START_SCALE, 1.0, e)
		row.modulate.a = 1.0 - e,
		0.0, 1.0, dur)
	tw.tween_callback(row.queue_free)


## The centre plate. `kind` is one of turn / boss / variant / guard-shattered /
## victory / defeat / perfect; `hold` is how long it sits before it goes.
## Awaitable: the drain blocks on the boss intro and on the perfect banner.
func banner(text: String, kind: String = "turn", hold: float = -1.0) -> void:
	if instant or not is_inside_tree():
		return
	var lines: PackedStringArray = text.split("\n", false)
	var longest: int = text.length()
	for line: String in lines:
		longest = maxi(longest, line.length())

	var w: float = clampf(float(longest) * 18.0, 280.0, 640.0)
	var h: float = 56.0
	var body: Color = Color(PLATE_INK.r, PLATE_INK.g, PLATE_INK.b, 0.88)
	var rail: Color = GOLD
	var label_size: int = 28
	var label_fill: Color = PARCHMENT
	var spacing: float = 0.0
	var inset: Color = Color(0, 0, 0, 0)
	var spring: bool = false
	var slide: Vector2 = Vector2(-24.0, 0.0)
	var dur: float = DUR_CEREMONY
	match kind:
		"boss":
			w = clampf(float(longest) * 22.0, 340.0, 720.0)
			h = 96.0 if lines.size() > 1 else 78.0
			body = Color(0.101960786, 0.03137255, 0.0627451, 0.88)
			rail = DANGER
			label_size = 30
			label_fill = EMBER
			spacing = 4.0
			inset = Color(DANGER.r, DANGER.g, DANGER.b, 0.45)
			spring = true
			slide = Vector2(0.0, 18.0)
			dur = DUR_CEREMONY + 0.08
		"perfect":
			h = 64.0
			label_size = 34
			spacing = 6.0
			inset = Color(GOLD.r, GOLD.g, GOLD.b, 0.55)
			spring = true
			dur = DUR_CEREMONY + 0.08
		"victory":
			h = 64.0
			label_size = 34
			spring = true
		"defeat":
			h = 64.0
			rail = DANGER
			label_size = 34
			spring = true
		"guard-shattered":
			rail = Color(0.62352943, 0.83137256, 1.0)
		"variant":
			inset = Color(0.101960786, 0.13333334, 0.2, 0.35)
		_:
			if lines.size() > 1:
				h = 72.0

	var plate: BannerPlate = BannerPlate.new()
	plate.body = body
	plate.rail = rail
	plate.inset_line = inset
	plate.radius = 2.0 if kind == "boss" else 6.0
	plate.rail_open = 0.01
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size = Vector2(w, h)
	plate.pivot_offset = Vector2(w, h) * 0.5
	add_child(plate)

	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face: FontFile = display_font()
	if face != null:
		label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", label_size)
	label.add_theme_color_override("font_color", label_fill)
	if spacing > 0.0:
		label.add_theme_constant_override("font_extra_spacing_char", int(spacing))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_y", 4)
	plate.add_child(label)

	var home: Vector2 = Vector2(size.x * 0.5 - w * 0.5, size.y * BANNER_Y_FRAC - h * 0.5)
	var curve: Array[float] = Motion.SPRING if spring else Motion.OUT_SOFT
	plate.position = home + slide
	plate.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_method(func(x: float) -> void:
		if not is_instance_valid(plate):
			return
		var e: float = Motion.ease(curve, x)
		plate.position = (home + slide).lerp(home, e)
		plate.modulate.a = e
		plate.rail_open = maxf(0.01, e)
		plate.queue_redraw(),
		0.0, 1.0, dur)
	await tw.finished
	await get_tree().create_timer(maxf(0.0, BANNER_HOLD if hold < 0.0 else hold)).timeout
	if is_instance_valid(plate):
		plate.queue_free()


## Drop everything on the layer at once — used when a fight ends mid-ceremony so
## a banner from the losing turn never outlives the screen it belongs to.
func clear_all() -> void:
	for child: Node in get_children():
		child.queue_free()
