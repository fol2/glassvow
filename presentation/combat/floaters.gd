class_name Floaters
extends Control
## The text layer: damage numerals and the centre-stage banner.
##
## Combat floaters are the CSS path: `floatText` (vfx.js:175) appends a
## `.floaty` div and plays a WAAPI list; sizes and colours live on the class
## rules (styles.css:1497–1516, plus `.floaty.staggerf` / `.shatterf` / `.artf`).
## There is no Pixi floater in the benchmark — that landed later. The three
## motion shapes (default rise, `.floaty.crit` blaze, poison drip) ease once
## over the whole iteration with `cubic-bezier(.2,.7,.3,1)`, matching how
## `Motion.ease` + `Motion.keyframe` already drive `.art-cast`.

## Font size per class token drain.js still speaks. Unlisted classes keep the
## `.floaty` base of 32px (styles.css:1499).
const CLASS_SIZE: Dictionary = {
	"dmg": 32, "dmg-big": 42, "dmg-kill": 52, "dmg-overkill": 62,
	"crit": 47,
	"blockedf": 22, "bufff": 22, "debufff": 22,
	"notice": 20, "movef": 14,
	"staggerf": 24, "shatterf": 15, "artf": 26,
}
const BASE_SIZE: int = 32
## Fill per class when the caller passes no `tint`. Base `.floaty` is white;
## `dmg-big` / `dmg-kill` / `dmg-overkill` inherit that white unless tinted.
const CLASS_FILL: Dictionary = {
	"dmg": Color(1.0, 0.8862745, 0.8862745),           # #ffe2e2
	"crit": Color(1.0, 0.84705883, 0.627451),          # #ffd8a0
	"blockedf": Color(0.7490196, 0.83137256, 0.9098039), # #bfd4e8
	"healf": Color(0.7254902, 0.9411765, 0.7647059),   # #b9f0c3
	"poisonf": Color(0.827451, 0.9490196, 0.6313726),  # #d3f2a1
	"blockf": Color(0.8039216, 0.93333334, 1.0),       # #cdeeff
	"goldf": Color(1.0, 0.9137255, 0.6745098),         # #ffe9ac
	"bufff": Color(0.8117647, 0.8901961, 1.0),         # #cfe3ff
	"debufff": Color(0.9098039, 0.78431374, 1.0),      # #e8c8ff
	"staggerf": Color(1.0, 0.84705883, 0.627451),      # #ffd8a0
	"shatterf": Color(0.62352943, 0.83137256, 1.0),    # #9fd4ff
	"artf": Color(1.0, 0.9137255, 0.6745098),          # #ffe9ac
}
const BASE_FILL: Color = Color(1.0, 1.0, 1.0)

## `el.animate(..., { easing: 'cubic-bezier(.2,.7,.3,1)' })` — once per
## iteration, then keyframe offsets read linearly (floatText, vfx.js:211).
const FLOAT_EASE: Array[float] = [0.2, 0.7, 0.3, 1.0]
const DUR_DEFAULT: float = 1.1
const DUR_CRIT: float = 1.25

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
## The room a banner leaves at each end of the stage, together. Nothing upstream
## sets it: the benchmark's banner is a `max-width: 90vw` block and this is the
## same idea stated in px, sized so a phone still shows a plate rather than a bar.
const BANNER_MARGIN: float = 48.0

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
	var path: String = GlassStyle.CINZEL_800
	if _font_cache == null and ResourceLoader.exists(path):
		_font_cache = load(path)
	return _font_cache


static func _size_for(cls: String) -> int:
	var n: int = CLASS_SIZE.get(cls, -1)
	if n > 0:
		return n
	# Longer tokens first so `dmg-overkill` does not land on `dmg`.
	for key: String in ["dmg-overkill", "dmg-kill", "dmg-big", "blockedf",
			"staggerf", "shatterf", "debufff", "poisonf", "notice", "movef",
			"bufff", "artf", "crit", "dmg"]:
		if cls.contains(key):
			n = CLASS_SIZE.get(key, -1)
			if n > 0:
				return n
	return BASE_SIZE


static func _fill_for(cls: String) -> Color:
	var fill: Color = CLASS_FILL.get(cls, Color(0, 0, 0, 0))
	if fill.a > 0.0:
		return fill
	for key: String in ["blockedf", "staggerf", "shatterf", "debufff",
			"poisonf", "healf", "blockf", "goldf", "bufff", "artf", "crit",
			"dmg"]:
		if cls.contains(key):
			fill = CLASS_FILL.get(key, Color(0, 0, 0, 0))
			if fill.a > 0.0:
				return fill
	if cls.contains("notice") or cls.contains("movef"):
		return PARCHMENT
	return BASE_FILL


## A rising (or dripping) numeral centred on `at` (stage px). `tint` overrides
## the class colour — the drain passes the archetype tone so a void hit reads
## violet. Y keyframes are percentages of the element's own height, as in
## `translate(-50%,-90%)` (floatText, vfx.js:175).
func float_text(at: Vector2, text: String, cls: String = "dmg",
		tint: Color = Color(0, 0, 0, 0), dx: float = 0.0,
		icon: Texture2D = null, icon_px: int = 0) -> void:
	if instant or not is_inside_tree():
		return
	var font_size: int = _size_for(cls)
	var fill: Color = tint if tint.a > 0.0 else _fill_for(cls)
	var is_crit: bool = cls.contains("crit")
	var is_poison: bool = cls.contains("poisonf")
	var drift: float = (randf() - 0.5) * 40.0
	if is_poison:
		drift *= 0.4
	var rot_deg: float = 0.0
	if is_crit:
		rot_deg = (randf() - 0.5) * 16.0
	elif cls.contains("dmg"):
		rot_deg = (randf() - 0.5) * 8.0

	var at_off: Array[float]
	var scales: Array[float]
	var alphas: Array[float]
	var y_pct: Array[float]
	var drifts: Array[float]
	var rots: Array[float]
	var brights: Array[float]
	var dur: float = DUR_DEFAULT
	if is_crit:
		dur = DUR_CRIT
		at_off = [0.0, 0.13, 0.34, 1.0]
		scales = [0.5, 1.45, 1.05, 0.98]
		alphas = [0.0, 1.0, 1.0, 0.0]
		y_pct = [-50.0, -92.0, -110.0, -230.0]
		drifts = [0.0, 0.0, 0.0, drift]
		rots = [0.0, rot_deg, rot_deg, rot_deg]
		brights = [3.0, 1.9, 1.0, 1.0]
	elif is_poison:
		# Poison keeps the 1100 ms default — only crit stretches to 1250
		# (floatText, vfx.js:187–198).
		at_off = [0.0, 0.2, 1.0]
		scales = [0.7, 1.05, 0.88]
		alphas = [0.0, 1.0, 0.0]
		y_pct = [-50.0, -26.0, 80.0]
		drifts = [0.0, 0.0, drift]
		rots = [0.0, 0.0, 0.0]
		brights = [1.0, 1.0, 1.0]
	else:
		at_off = [0.0, 0.18, 1.0]
		scales = [0.6, 1.15, 0.95]
		alphas = [0.0, 1.0, 0.0]
		y_pct = [-50.0, -90.0, -230.0]
		drifts = [0.0, 0.0, drift]
		rots = [0.0, rot_deg, rot_deg]
		brights = [1.0, 1.0, 1.0]

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != null:
		var pip: TextureRect = TextureRect.new()
		var side: float = float(icon_px) if icon_px > 0 \
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
	# The letterpress: `.floaty`'s `--ink` is eight offset copies of the glyph
	# in near-black. An outline is the same silhouette for one draw.
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
	var layout: Vector2 = row.get_combined_minimum_size()
	row.size = layout
	row.pivot_offset = layout * 0.5
	var anchor: Vector2 = at + Vector2(dx, 0.0) - global_position
	# `translate(-50%,-50%)` centres on the anchor; later Y percentages are of
	# this unscaled height (CSS resolves % against the layout box).
	var half: Vector2 = layout * 0.5
	row.position = anchor - half
	row.scale = Vector2.ONE * scales[0]
	row.modulate = Color(brights[0], brights[0], brights[0], alphas[0])

	var tw: Tween = create_tween()
	tw.tween_method(func(x: float) -> void:
		if not is_instance_valid(row):
			return
		var t: float = Motion.ease(FLOAT_EASE, x)
		var s: float = Motion.keyframe(t, at_off, scales)
		var a: float = Motion.keyframe(t, at_off, alphas)
		var y: float = Motion.keyframe(t, at_off, y_pct)
		var d: float = Motion.keyframe(t, at_off, drifts)
		var r: float = Motion.keyframe(t, at_off, rots)
		var b: float = Motion.keyframe(t, at_off, brights)
		# Y% of element height, relative to the -50% centre: -90% → −0.4 h.
		var y_off: float = layout.y * ((y + 50.0) / 100.0)
		row.position = anchor - half + Vector2(d, y_off)
		row.scale = Vector2(s, s)
		row.rotation_degrees = r
		row.modulate = Color(b, b, b, a),
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

	# Clamped to the STAGE as well as to its own range. The two ranges below were
	# authored against a 1180-wide stage, where a 720px boss banner is a plate in
	# the middle of the screen; on a 390-wide phone the same number is nearly
	# twice the stage and the banner would have run off both edges.
	var room: float = maxf(CardView.CARD_W, size.x - BANNER_MARGIN)
	var w: float = minf(room, clampf(float(longest) * 18.0, 280.0, 640.0))
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
	var wrap: bool = false
	match kind:
		"boss":
			w = minf(room, clampf(float(longest) * 22.0, 340.0, 720.0))
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
			# `.variant-dialogue` (styles.css:1482-1487): prose on near-opaque
			# night glass (#080a12 at 0.94) behind a pale leaded line
			# (rgba(210,226,255,.48)), capped at min(660px, 86cqw). These are
			# spoken lines, not titles — the label wraps inside the plate
			# instead of demanding one line of stage.
			w = minf(room, minf(size.x * 0.86,
				clampf(float(longest) * 14.0, 320.0, 660.0)))
			body = Color(0.03137255, 0.039215688, 0.07058824, 0.94)
			rail = Color(0.8235294, 0.8862745, 1.0, 0.48)
			inset = Color(0.101960786, 0.13333334, 0.2, 0.35)
			wrap = true
		_:
			if lines.size() > 1:
				h = 72.0

	var face: FontFile = display_font()
	if wrap and face != null:
		# The plate must be tall enough BEFORE it is built — a Label wraps at
		# layout time, after the plate has already committed to 56px. Measured
		# with the same face at the same size, against the width the text will
		# actually get (28px insets each side, the port's read of the
		# benchmark's 40px padding at its own scale).
		var text_w: float = face.get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_size).x
		var rows: int = maxi(1, int(ceilf(text_w / maxf(1.0, w - 56.0))))
		h = 56.0 + float(rows - 1) * 34.0

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
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.offset_left = 28.0
		label.offset_right = -28.0
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
