class_name CardView
extends Control
## One card, replicated from the visual benchmark (roguecardv2@6e069118, the
## pre-Pixi build). Every number below was measured off that build's DOM rather
## than eyeballed — its stage is 1180x820, the same virtual resolution this
## project uses, so the CSS pixels transfer 1:1 with no conversion.
##
## Benchmark spec, in stage px:
##   card      152 x 216, radius 11, 2px #05070E border, 1px inset rim in the
##             type tint at 0.40 alpha, drop shadow rgba(0,0,0,.55) 0 8 22
##   cost      36 x 36 hexagon hung at (-8, -8), Cinzel 800, ink #241A05
##   art       148 x 91 window, 1px #05070E rule beneath it
##   name      Cinzel 700 @ 13.5, letter-spacing 0.27, #E8DFC8
##   type      Alegreya 400 @ 10, letter-spacing 2.8, uppercase, type tint
##   text      Alegreya 400 @ 12.8, line-height 16.9, #C6CCDF
##   rarity    24 x 5 pill, radius 3, #3C465E, bottom centre
##
## Art is `assets/art/cards/<id>.jpg`, keyed straight off the content id; a card
## with no art on disk falls back to a bare pane. Below the style sits the raw
## pointer surface for the hand's drag state machine — mouse and touch both
## arrive through _gui_input (no emulate_touch_from_mouse); hover exists only on
## the mouse path by nature.

signal pressed_at(uid: int, global_pos: Vector2)
signal moved_to(uid: int, global_pos: Vector2)
signal released_at(uid: int, global_pos: Vector2)
signal hover_changed(uid: int, hovering: bool)

const ART_DIR: String = "res://assets/art/cards/"

const CARD_W: float = 152.0
const CARD_H: float = 216.0
const EDGE: float = 2.0          # card border; the inner column is 148 wide
const ART_H: float = 91.0
const NAME_H: float = 23.0
const TYPE_H: float = 13.0
const GEM: float = 36.0
## Glare disc diameter. The benchmark's gradient dies out at 55% of the card box;
## an oversized disc keeps the falloff smooth when the cursor sits near an edge.
const GLARE_D: float = 240.0
const GLARE_FADE: float = 0.25

const PARCHMENT: Color = Color(0.910, 0.875, 0.784)   # #E8DFC8 — name
const INK: Color = Color(0.043, 0.055, 0.102)         # #0B0E1A — card stock
const RULE: Color = Color(0.020, 0.027, 0.055)        # #05070E — borders
const BODY_TEXT: Color = Color(0.776, 0.800, 0.875)   # #C6CCDF — rules
const GEM_INK: Color = Color(0.141, 0.102, 0.020)     # #241A05 — cost numeral
const GOLD_LIT: Color = Color(1.000, 0.914, 0.675)    # #FFE9AC — conic highlight
const GOLD_MID: Color = Color(0.949, 0.757, 0.306)    # #F2C14E
const GOLD_DIM: Color = Color(0.702, 0.514, 0.122)    # #B3831F — conic shadow
const GOLD: Color = Color(0.949, 0.757, 0.306)        # #F2C14E — var(--gold)
## The rarity pill is not one colour — styles.css tiers it, and the two top tiers
## also glow. `special` has no rule there, so it falls through to the starter slate.
const RARITY_PILL: Dictionary = {
	"starter": Color(0.235, 0.275, 0.369),    # #3C465E
	"common": Color(0.365, 0.416, 0.533),     # #5D6A88
	"uncommon": Color(0.278, 0.761, 0.878),   # #47C2E0 → #7FE3F2
	"rare": Color(0.949, 0.757, 0.306),       # gold → #FFE9AC
}
## Free cards get a green gem, not gold (.card-cost.free).
const GREEN_LIT: Color = Color(0.851, 0.984, 0.906)   # #D9FBE7
const GREEN_MID: Color = Color(0.216, 0.839, 0.478)   # #37D67A
const GREEN_DIM: Color = Color(0.090, 0.439, 0.243)   # #17703E

var uid: int = 0
var card_id: StringName = &""
## "enemy" needs a drop on an enemy; everything else plays on release above the hand.
var target_kind: String = ""
var unplayable: bool = false
var playable: bool = true
## Layout home assigned by HandView._relayout; snap-back target.
var home_position: Vector2 = Vector2.ZERO
var home_rotation: float = 0.0

var _held: bool = false
var _glare: TextureRect = null
var _glare_tw: Tween = null


func _init(inst: CardInst, data: Dictionary, cost: int) -> void:
	uid = inst.uid
	card_id = inst.id
	target_kind = str(data.get("target", ""))
	var unplayable_flag: bool = data.get("unplayable", false)
	unplayable = unplayable_flag
	var ctype: String = str(data.get("type", ""))
	var tint: Color = _type_tint(ctype)
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	size = custom_minimum_size
	pivot_offset = custom_minimum_size * 0.5

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	# Benchmark stock is a 168deg gradient, not flat: the type tint bleeds in at
	# 15% from the top-left and dies out by 58%. StyleBoxFlat has no gradient, so
	# the tint is folded into the flat fill and the gradient itself is a child
	# below everything else.
	sb.bg_color = INK
	sb.border_color = RULE
	sb.set_border_width_all(int(EDGE))
	sb.set_corner_radius_all(11)
	sb.set_content_margin_all(0)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)

	# The face clips (art must not spill past the radius); the cost gem overhangs
	# the corner and must not. So the card itself is a plain Control — a Container
	# here would also re-fit the gem to the card rect and bury its numeral.
	var layer: Panel = Panel.new()
	layer.add_theme_stylebox_override("panel", sb)
	layer.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)

	# Stock gradient, under the art and everything else.
	var stock: TextureRect = TextureRect.new()
	# grad_tex hands back a 256x256 texture, and TextureRect's default
	# EXPAND_KEEP_SIZE makes that the node's *minimum* size — a 1px rule asked for
	# in offsets still comes out 256px tall. Every gradient here must ignore it.
	stock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stock.texture = GlassStyle.grad_tex(
		PackedColorArray([
			Color(tint.r, tint.g, tint.b, 1.0).lerp(Color(0.063, 0.078, 0.141), 0.85),
			Color(0.035, 0.043, 0.078)]),
		PackedFloat32Array([0.0, 0.58]), false,
		Vector2(0.12, 0.0), Vector2(0.88, 1.0))
	stock.set_anchors_preset(Control.PRESET_FULL_RECT)
	stock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(stock)

	var art_path: String = ART_DIR + String(inst.id) + ".jpg"
	var art: Texture2D = null
	if ResourceLoader.exists(art_path):
		art = load(art_path) as Texture2D
	if art != null:
		var art_rect: TextureRect = TextureRect.new()
		art_rect.texture = art
		art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Source art is 3:2 landscape, the window is 148x91 — cover, don't fit.
		art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art_rect.set_anchors_preset(Control.PRESET_TOP_WIDE)
		art_rect.offset_left = EDGE
		art_rect.offset_right = -EDGE
		art_rect.offset_top = EDGE
		art_rect.offset_bottom = EDGE + ART_H
		art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(art_rect)

	# Art overlays, both from the benchmark's .card-art: a wide radial wash in the
	# type tint, and a 1px light line along the top edge from its inset shadow.
	# The dark line under the window is the `rule` below.
	if art != null:
		var wash: TextureRect = TextureRect.new()
		wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wash.texture = GlassStyle.grad_tex(
			PackedColorArray([Color(tint.r, tint.g, tint.b, 0.14),
				Color(tint.r, tint.g, tint.b, 0.0)]),
			PackedFloat32Array([0.0, 0.75]), true, Vector2(0.5, 0.45), Vector2(1.0, 0.45))
		wash.set_anchors_preset(Control.PRESET_TOP_WIDE)
		wash.offset_left = EDGE
		wash.offset_right = -EDGE
		wash.offset_top = EDGE
		wash.offset_bottom = EDGE + ART_H
		wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(wash)
		var lip: ColorRect = ColorRect.new()
		lip.color = Color(1, 1, 1, 0.09)
		lip.set_anchors_preset(Control.PRESET_TOP_WIDE)
		lip.offset_left = EDGE
		lip.offset_right = -EDGE
		lip.offset_top = EDGE
		lip.offset_bottom = EDGE + 1.0
		lip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(lip)

	var rule: ColorRect = ColorRect.new()
	rule.color = RULE
	rule.set_anchors_preset(Control.PRESET_TOP_WIDE)
	rule.offset_left = EDGE
	rule.offset_right = -EDGE
	rule.offset_top = EDGE + ART_H
	rule.offset_bottom = EDGE + ART_H + 1.0
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rule)

	# 1px inset rim in the type tint — the benchmark's inner box-shadow.
	var rim: Panel = Panel.new()
	var rim_sb: StyleBoxFlat = StyleBoxFlat.new()
	rim_sb.bg_color = Color(0, 0, 0, 0)
	# Tiered rim: commons leaded in the type tint, uncommons silvered, rares gilt.
	var rim_col: Color = Color(tint.r, tint.g, tint.b, 0.40)
	var tier: String = str(data.get("rarity", "starter"))
	if tier == "uncommon":
		rim_col = Color(0.659, 0.847, 0.933, 0.60)   # #A8D8EE
	elif tier == "rare":
		rim_col = Color(GOLD.r, GOLD.g, GOLD.b, 0.80)
	rim_sb.border_color = rim_col
	rim_sb.set_border_width_all(1)
	rim_sb.set_corner_radius_all(9)
	rim.add_theme_stylebox_override("panel", rim_sb)
	rim.set_anchors_preset(Control.PRESET_FULL_RECT)
	rim.offset_left = EDGE
	rim.offset_top = EDGE
	rim.offset_right = -EDGE
	rim.offset_bottom = -EDGE
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rim)

	var display_name: String = str(data.get("name", String(inst.id)))
	if inst.up:
		display_name += "+"
	var name_label: Label = Label.new()
	name_label.text = display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", _font(GlassStyle.CINZEL_700, 0))
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", PARCHMENT)
	name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_label.offset_left = EDGE
	name_label.offset_right = -EDGE
	name_label.offset_top = EDGE + ART_H + 1.0
	name_label.offset_bottom = EDGE + ART_H + 1.0 + NAME_H
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(name_label)

	# The name plate is ruled top and bottom with a 1px gold line that fades out
	# at both ends (styles.css .card-name carries them as background gradients).
	# The lower one is the divider between the name and the type rubric.
	_add_name_rule(layer, EDGE + ART_H + 1.0, 0.22, 0.14)
	_add_name_rule(layer, EDGE + ART_H + 1.0 + NAME_H - 1.0, 0.14, 0.06)

	var type_label: Label = Label.new()
	type_label.text = ctype.to_upper()
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 2.8px of tracking is most of this row's identity — without it the label
	# reads as a caption instead of a rubric.
	type_label.add_theme_font_override("font", _font(GlassStyle.ALEGREYA_400, 3))
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", tint)
	type_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	type_label.offset_left = EDGE
	type_label.offset_right = -EDGE
	type_label.offset_top = EDGE + ART_H + 1.0 + NAME_H
	type_label.offset_bottom = EDGE + ART_H + 1.0 + NAME_H + TYPE_H
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(type_label)

	# Drawn, not laid out by a Label — RichTextLabel cannot do the benchmark's
	# dotted keyword rule and exposes no per-run rects to patch one in. See
	# rules_text.gd. Benchmark leading is 16.9 on a 12.8 font.
	var body: RulesText = RulesText.new(
		str(data.get("text", "")), tint,
		_font(GlassStyle.ALEGREYA_400, 0), _font(GlassStyle.ALEGREYA_700, 0),
		13, 16.9)
	body.plain_color = BODY_TEXT
	body.value_color = PARCHMENT
	# Benchmark text box is 148x84.9 with 4/10/10 padding — baked into the offsets,
	# since neither node type has padding. RulesText centres its own paragraph
	# vertically, so short rules do not hang off the rubric. The rarity pill floats
	# over the tail of this box rather than reserving space, as in the benchmark.
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 10.0
	body.offset_right = -10.0
	body.offset_top = EDGE + ART_H + 1.0 + NAME_H + TYPE_H + 2.0
	body.offset_bottom = -8.0
	layer.add_child(body)

	var rarity: String = str(data.get("rarity", "starter"))
	var pill: Panel = Panel.new()
	var pill_sb: StyleBoxFlat = StyleBoxFlat.new()
	pill_sb.bg_color = RARITY_PILL.get(rarity, RARITY_PILL["starter"])
	pill_sb.set_corner_radius_all(3)
	# Uncommon and rare pills carry a glow in the benchmark; the lower tiers don't.
	if rarity == "uncommon" or rarity == "rare":
		pill_sb.shadow_color = Color(pill_sb.bg_color.r, pill_sb.bg_color.g,
			pill_sb.bg_color.b, 0.55)
		pill_sb.shadow_size = 7 if rarity == "rare" else 6
	pill.add_theme_stylebox_override("panel", pill_sb)
	pill.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pill.offset_left = (CARD_W - 24.0) * 0.5
	pill.offset_right = (CARD_W - 24.0) * 0.5 + 24.0
	pill.offset_top = -10.0
	pill.offset_bottom = -5.0
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(pill)

	# Cursor glare: the benchmark's .card-inner::before — a soft radial highlight
	# that tracks the pointer and fades in over 0.25s. Lives above the art but
	# below nothing else, and inside the clipped subtree so it respects the radius.
	_glare = TextureRect.new()
	_glare.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glare.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(1, 1, 1, 0.17), Color(1, 1, 1, 0.0)]),
		PackedFloat32Array([0.0, 0.55]), true, Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	_glare.size = Vector2(GLARE_D, GLARE_D)
	_glare.modulate = Color(1, 1, 1, 0)
	_glare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_glare)

	# The gem overhangs the corner, so it sits outside the clipped subtree.
	_build_cost_gem(cost, tint)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


## One of the name plate's two hairlines: gold, brightest mid-span, transparent
## at both ends. A three-stop horizontal gradient stands in for the CSS one.
func _add_name_rule(parent: Control, y: float, mid_a: float, edge_a: float) -> void:
	var rule_line: TextureRect = TextureRect.new()
	rule_line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rule_line.texture = GlassStyle.grad_tex(
		PackedColorArray([
			Color(GOLD.r, GOLD.g, GOLD.b, 0.0),
			Color(GOLD.r, GOLD.g, GOLD.b, mid_a),
			Color(GOLD.r, GOLD.g, GOLD.b, mid_a),
			Color(GOLD.r, GOLD.g, GOLD.b, edge_a * 0.0)]),
		PackedFloat32Array([0.04, 0.18, 0.82, 0.96]), false,
		Vector2(0.0, 0.5), Vector2(1.0, 0.5))
	rule_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	rule_line.offset_left = EDGE
	rule_line.offset_right = -EDGE
	rule_line.offset_top = y
	rule_line.offset_bottom = y + 1.0
	rule_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rule_line)


## A pointy-top hexagon in gold leaf, hung off the top-left corner at (-8, -8).
func _build_cost_gem(cost: int, tint: Color) -> void:
	var holder: Control = Control.new()
	holder.position = Vector2(-8.0, -8.0)
	holder.size = Vector2(GEM, GEM)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.top_level = false
	add_child(holder)

	# Benchmark clip-path: polygon(50% 0, 93% 25, 93% 75, 50% 100, 7% 75, 7% 25).
	var hex: Polygon2D = Polygon2D.new()
	hex.polygon = PackedVector2Array([
		Vector2(GEM * 0.50, 0.0), Vector2(GEM * 0.93, GEM * 0.25),
		Vector2(GEM * 0.93, GEM * 0.75), Vector2(GEM * 0.50, GEM),
		Vector2(GEM * 0.07, GEM * 0.75), Vector2(GEM * 0.07, GEM * 0.25),
	])
	# The gem's metal is a conic sweep. A per-vertex ramp reproduces the
	# light-from-upper-left read for one polygon instead of a shader, which is all
	# this 36px badge needs. Cost 0 is struck in green, not gold (.card-cost.free).
	var free: bool = cost == 0 and not unplayable
	var lit: Color = GREEN_LIT if free else GOLD_LIT
	var mid: Color = GREEN_MID if free else GOLD_MID
	var dim: Color = GREEN_DIM if free else GOLD_DIM
	hex.vertex_colors = PackedColorArray([lit, mid, dim, dim, mid, lit])
	holder.add_child(hex)

	# Inner bevel: .card-cost::before, the same hexagon inset 3px carrying a
	# 160deg white-to-black wash. It is what stops the badge reading as a decal.
	var bevel: Polygon2D = Polygon2D.new()
	var inset: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in hex.polygon:
		inset.append(p.lerp(Vector2(GEM, GEM) * 0.5, 3.0 / (GEM * 0.5)))
	bevel.polygon = inset
	bevel.vertex_colors = PackedColorArray([
		Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.10), Color(0, 0, 0, 0.14),
		Color(0, 0, 0, 0.22), Color(0, 0, 0, 0.10), Color(1, 1, 1, 0.22),
	])
	holder.add_child(bevel)

	var edge_line: Line2D = Line2D.new()
	var pts: PackedVector2Array = hex.polygon.duplicate()
	pts.append(hex.polygon[0])
	edge_line.points = pts
	edge_line.width = 1.0
	edge_line.default_color = Color(dim.r, dim.g, dim.b, 0.85)
	holder.add_child(edge_line)

	var cost_label: Label = Label.new()
	cost_label.text = "-" if unplayable else str(cost)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_override("font", _font(GlassStyle.CINZEL_800, 0))
	cost_label.add_theme_font_size_override("font_size", 17)
	cost_label.add_theme_color_override("font_color", GEM_INK)
	cost_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(cost_label)



## Cached FontVariations — one per (face, tracking) pair, built once per run.
## Label wants a Font resource, and a fresh FontVariation per label would re-pay
## the shaping setup on every card the hand deals.
static var _font_cache: Dictionary = {}


static func _font(path: String, tracking: int) -> Font:
	var key: String = path + "#" + str(tracking)
	if _font_cache.has(key):
		var hit: Font = _font_cache[key]
		return hit
	var base: FontFile = load(path) as FontFile
	var fv: FontVariation = FontVariation.new()
	fv.base_font = base
	if tracking != 0:
		fv.spacing_glyph = tracking
	_font_cache[key] = fv
	return fv


## Benchmark type tints, sampled from the pre-Pixi build's computed styles.
static func _type_tint(ctype: String) -> Color:
	match ctype:
		"attack":
			return Color(1.000, 0.349, 0.392)   # #FF5964
		"skill":
			return Color(0.306, 0.659, 0.871)   # #4EA8DE
		"power":
			return Color(0.702, 0.533, 1.000)   # #B388FF
		"status":
			return Color(0.498, 0.682, 0.612)   # #7FAE9C
		"curse":
			return Color(0.780, 0.482, 0.831)   # #C77BD4
		_:
			return GlassStyle.GLASS


func _on_mouse_entered() -> void:
	_fade_glare(1.0)
	hover_changed.emit(uid, true)


func _on_mouse_exited() -> void:
	_fade_glare(0.0)
	hover_changed.emit(uid, false)


func _fade_glare(to: float) -> void:
	if _glare == null:
		return
	if _glare_tw != null and _glare_tw.is_valid():
		_glare_tw.kill()
	_glare_tw = create_tween()
	_glare_tw.tween_property(_glare, "modulate:a", to, GLARE_FADE)


## Centre the glare on the pointer. Called from _gui_input, so it only runs while
## the card is actually under the cursor.
func _track_glare(local_pos: Vector2) -> void:
	if _glare != null:
		_glare.position = local_pos - Vector2(GLARE_D, GLARE_D) * 0.5


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_press_release(mb.pressed, mb.global_position)
		return
	var st: InputEventScreenTouch = event as InputEventScreenTouch
	if st != null:
		# Touch events carry only a control-local position — lift to global.
		_press_release(st.pressed, get_global_transform() * st.position)
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_track_glare(mm.position)
		if _held:
			moved_to.emit(uid, mm.global_position)
		return
	var sd: InputEventScreenDrag = event as InputEventScreenDrag
	if sd != null and _held:
		moved_to.emit(uid, get_global_transform() * sd.position)


func _press_release(pressed: bool, global_pos: Vector2) -> void:
	if pressed:
		_held = true
		pressed_at.emit(uid, global_pos)
	elif _held:
		_held = false
		released_at.emit(uid, global_pos)


## Grey out cards the player cannot afford / play right now.
func set_playable(can: bool) -> void:
	playable = can
	modulate = Color(1, 1, 1, 1) if can else Color(0.6, 0.6, 0.6, 0.8)


func snap_home() -> void:
	position = home_position
	rotation = home_rotation
	scale = Vector2.ONE
