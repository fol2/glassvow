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
##             — border and rim are superseded by the edge system, the one
##             deliberate step past the benchmark here: see card_edge.gdshader.
##   cost      36 x 36 hexagon hung at (-8, -8), Cinzel 800, ink #241A05
##   art       148 x 91 window, 1px #05070E rule beneath it
##   name      Cinzel 700 @ 13.5, letter-spacing 0.27, #E8DFC8
##   type      Alegreya 400 @ 10, letter-spacing 2.8, uppercase, type tint
##   text      Alegreya 400 @ 12.8, line-height 16.9, #C6CCDF
##   rarity    24 x 5 pill, radius 3, #3C465E, bottom centre
##
## The face is a stack of full-width bands, built top-down in _init the way the
## card reads. Every band goes through _band() and every gradient through
## _grad() — see those two for the traps they exist to close.
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

## THE CARD SHAPE. CARD_W x CARD_H with RADIUS corners is the silhouette, and it
## is the one true edge of a card: nothing inside may paint past it.
##
## It is enforced by a dedicated mask node, not by the face. Godot's
## clip_children masks children to the parent's *drawn content*, and a
## StyleBoxFlat drop shadow is drawn content — so clipping against the face made
## the boundary the silhouette PLUS an 8px shadow skirt, and the cursor glare
## painted straight into it. The mask carries the shape alone.
##
## Consequence worth knowing before adding anything: whatever the mask draws IS
## the card's edge. Give it a glow, an outline or a bloom and you have widened
## the card for everything inside it. Effects that must exceed the silhouette
## (the cost gem does) go outside the mask as siblings instead.
const CARD_W: float = 152.0
const CARD_H: float = 216.0
const RADIUS: int = 11
const EDGE: float = 2.0          # card border; the inner column is 148 wide
const SHADOW_COLOR: Color = Color(0, 0, 0, 0.55)
const SHADOW_SIZE: int = 8
const SHADOW_OFFSET: Vector2 = Vector2(0, 4)
const ART_H: float = 91.0
const NAME_H: float = 23.0
const TYPE_H: float = 13.0
const GEM: float = 36.0
const PILL_W: float = 24.0
## Each row's top derived from the one above it, so changing a band's height
## carries the rest with it instead of leaving five hand-summed offsets behind.
const ART_Y: float = EDGE
const RULE_Y: float = ART_Y + ART_H              # 1px divider under the window
const NAME_Y: float = RULE_Y + 1.0
const TYPE_Y: float = NAME_Y + NAME_H
const BODY_Y: float = TYPE_Y + TYPE_H + 2.0
## Glare disc diameter. The benchmark's gradient dies out at 55% of the card box;
## an oversized disc keeps the falloff smooth when the cursor sits near an edge.
const GLARE_D: float = 240.0
const GLARE_FADE: float = 0.25

const PARCHMENT: Color = Color(0.910, 0.875, 0.784)   # #E8DFC8 — name
const INK: Color = Color(0.043, 0.055, 0.102)         # #0B0E1A — card stock
const RULE: Color = Color(0.020, 0.027, 0.055)        # #05070E — borders
const BODY_TEXT: Color = Color(0.776, 0.800, 0.875)   # #C6CCDF — rules
const GEM_INK: Color = Color(0.141, 0.102, 0.020)     # #241A05 — cost numeral
## Gold leaf as a three-stop ramp: the gem's conic sweep, and GOLD alone
## wherever the benchmark writes var(--gold).
const GOLD_LIT: Color = Color(1.000, 0.914, 0.675)    # #FFE9AC — highlight
const GOLD: Color = Color(0.949, 0.757, 0.306)        # #F2C14E
const GOLD_DIM: Color = Color(0.702, 0.514, 0.122)    # #B3831F — shadow
## Free cards get a green gem, not gold (.card-cost.free).
const GREEN_LIT: Color = Color(0.851, 0.984, 0.906)   # #D9FBE7
const GREEN: Color = Color(0.216, 0.839, 0.478)       # #37D67A
const GREEN_DIM: Color = Color(0.090, 0.439, 0.243)   # #17703E

## Benchmark type tints, sampled from the pre-Pixi build's computed styles.
const TYPE_TINT: Dictionary = {
	"attack": Color(1.000, 0.349, 0.392),     # #FF5964
	"skill": Color(0.306, 0.659, 0.871),      # #4EA8DE
	"power": Color(0.702, 0.533, 1.000),      # #B388FF
	"status": Color(0.498, 0.682, 0.612),     # #7FAE9C
	"curse": Color(0.780, 0.482, 0.831),      # #C77BD4
}
## The rarity pill is not one colour — styles.css tiers it, and the two top tiers
## also glow. `special` has no rule there, so it falls through to the starter slate.
const RARITY_PILL: Dictionary = {
	"starter": Color(0.235, 0.275, 0.369),    # #3C465E
	"common": Color(0.365, 0.416, 0.533),     # #5D6A88
	"uncommon": Color(0.278, 0.761, 0.878),   # #47C2E0 → #7FE3F2
	"rare": GOLD,                             # → #FFE9AC
}
## The edge system: type is the colour of the glass, rarity is the finish of
## the cut. One shader owns border, rim, corner gold and hover glint — the
## finish tiers are documented at the top of card_edge.gdshader. Curse
## overrides its rarity to leaden: that glass drinks light instead.
const EDGE_SHADER: Shader = preload("res://presentation/combat/card_edge.gdshader")
const FINISH: Dictionary = {
	"starter": 0, "common": 1, "uncommon": 2, "rare": 3, "special": 0,
}
const FINISH_LEADEN: int = 4

## Cached FontVariations — one per (face, tracking) pair, built once per run.
## Label wants a Font resource, and a fresh FontVariation per label would re-pay
## the shaping setup on every card the hand deals.
static var _font_cache: Dictionary = {}
## Gradient textures keyed by what actually varies. GradientTexture2D rasterises
## 256x256, so a per-card texture costs ~256 KB — 244 of them for a 61-card
## sheet. Everything here depends on the card's *type* at most, never its id.
static var _tex_cache: Dictionary = {}

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
var _edge_mat: ShaderMaterial = null


func _init(inst: CardInst, data: Dictionary, cost: int) -> void:
	uid = inst.uid
	card_id = inst.id
	target_kind = str(data.get("target", ""))
	var unplayable_flag: bool = data.get("unplayable", false)
	unplayable = unplayable_flag
	var ctype: String = str(data.get("type", ""))
	var rarity: String = str(data.get("rarity", "starter"))
	var tint: Color = TYPE_TINT.get(ctype, GlassStyle.GLASS)
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	size = custom_minimum_size
	pivot_offset = custom_minimum_size * 0.5

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	# Benchmark stock is a 168deg gradient, not flat: the type tint bleeds in at
	# 15% from the top-left and dies out by 58%. StyleBoxFlat has no gradient, so
	# the tint is folded into the flat fill and the gradient itself is a child
	# below everything else.
	sb.bg_color = INK
	sb.set_corner_radius_all(RADIUS)
	# Rare cards cast a slightly warmer shadow — light through gilded glass.
	sb.shadow_color = SHADOW_COLOR.lerp(Color(GOLD_DIM, 0.55), 0.18) \
		if rarity == "rare" else SHADOW_COLOR
	sb.shadow_size = SHADOW_SIZE
	sb.shadow_offset = SHADOW_OFFSET

	# The face: card stock, border and drop shadow. It draws; it clips nothing.
	var face: Panel = Panel.new()
	face.add_theme_stylebox_override("panel", sb)
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(face)

	# The silhouette, as a pure mask — see THE CARD SHAPE above. Under
	# CLIP_CHILDREN_ONLY this node is never drawn, so it costs no pixels and
	# leaves no second antialiased edge over the face's; it exists only so its
	# shape bounds the subtree. The cost gem overhangs the corner on purpose and
	# so hangs off CardView as a sibling, outside the mask.
	var layer: Panel = Panel.new()
	var mask_sb: StyleBoxFlat = StyleBoxFlat.new()
	mask_sb.bg_color = Color(1, 1, 1, 1)
	mask_sb.set_corner_radius_all(RADIUS)
	layer.add_theme_stylebox_override("panel", mask_sb)
	layer.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)

	# Stock gradient, under the art and everything else. Keyed on the type, which
	# is the only thing it reads — five textures serve the whole 61-card sheet.
	var stock: TextureRect = _grad(
		PackedColorArray([
			Color(tint, 1.0).lerp(Color(0.063, 0.078, 0.141), 0.85),
			Color(0.035, 0.043, 0.078)]),
		PackedFloat32Array([0.0, 0.58]), false,
		Vector2(0.12, 0.0), Vector2(0.88, 1.0), "stock:" + ctype)
	stock.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(stock)

	var art: Texture2D = _load_art(inst.id)
	if art != null:
		var art_rect: TextureRect = TextureRect.new()
		art_rect.texture = art
		art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Source art is 3:2 landscape, the window is 148x91 — cover, don't fit.
		art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		layer.add_child(_band(art_rect, ART_Y, ART_H))
		# Two overlays from the benchmark's .card-art: a wide radial wash in the
		# type tint, and a 1px light line along the top edge from its inset
		# shadow. The dark line *under* the window is `rule`, below.
		layer.add_child(_band(_grad(
			PackedColorArray([Color(tint, 0.14), Color(tint, 0.0)]),
			PackedFloat32Array([0.0, 0.75]), true,
			Vector2(0.5, 0.45), Vector2(1.0, 0.45), "wash:" + ctype), ART_Y, ART_H))
		var lip: ColorRect = ColorRect.new()
		lip.color = Color(1, 1, 1, 0.09)
		layer.add_child(_band(lip, ART_Y, 1.0))

	var rule: ColorRect = ColorRect.new()
	rule.color = RULE
	layer.add_child(_band(rule, RULE_Y, 1.0))

	var name_label: Label = Label.new()
	name_label.text = str(data.get("name", String(inst.id)))
	if inst.up:
		name_label.text += "+"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", _font(GlassStyle.CINZEL_700, 0))
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", PARCHMENT)
	layer.add_child(_band(name_label, NAME_Y, NAME_H))

	# The name plate is ruled top and bottom with a 1px gold line that fades out
	# at both ends (styles.css .card-name carries them as background gradients).
	# The lower one is the divider between the name and the type rubric.
	_add_name_rule(layer, NAME_Y, 0.22)
	_add_name_rule(layer, TYPE_Y - 1.0, 0.14)

	var type_label: Label = Label.new()
	type_label.text = ctype.to_upper()
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 2.8px of tracking is most of this row's identity — without it the label
	# reads as a caption instead of a rubric.
	type_label.add_theme_font_override("font", _font(GlassStyle.ALEGREYA_400, 3))
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", tint)
	layer.add_child(_band(type_label, TYPE_Y, TYPE_H))

	# Drawn, not laid out by a Label — RichTextLabel cannot do the benchmark's
	# dotted keyword rule and exposes no per-run rects to patch one in. See
	# rules_text.gd. Benchmark leading is 16.9 on a 12.8 font.
	var body: RulesText = RulesText.new(
		str(data.get("text", "")), tint,
		_font(GlassStyle.ALEGREYA_400, 0), _font(GlassStyle.ALEGREYA_700, 0),
		13, 16.9)
	body.plain_color = BODY_TEXT
	body.value_color = PARCHMENT
	# Benchmark text box is 148x84.9 with 4/10/10 padding — 10 rather than EDGE on
	# the sides, since neither node type has padding. RulesText centres its own
	# paragraph vertically, so short rules do not hang off the rubric. The rarity
	# pill floats over the tail of this box rather than reserving space.
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 10.0
	body.offset_right = -10.0
	body.offset_top = BODY_Y
	body.offset_bottom = -8.0
	layer.add_child(body)

	layer.add_child(_build_rarity_pill(rarity))

	# Cursor glare: the benchmark's .card-inner::before — a soft radial highlight
	# that tracks the pointer and fades in over 0.25s. Lives above the art but
	# below nothing else, and inside the clipped subtree so it respects the radius.
	_glare = _grad(
		PackedColorArray([Color(1, 1, 1, 0.17), Color(1, 1, 1, 0.0)]),
		PackedFloat32Array([0.0, 0.55]), true,
		Vector2(0.5, 0.5), Vector2(1.0, 0.5), "glare")
	_glare.size = Vector2(GLARE_D, GLARE_D)
	_glare.modulate = Color(1, 1, 1, 0)
	layer.add_child(_glare)

	# The edge, last in the layer: the frame holds — glare passes under it, and
	# the mask's silhouette is its outer cut (the shader fills past d = 0 and
	# lets the mask do the antialiasing, so there is only ever one outer edge).
	var edge: ColorRect = ColorRect.new()
	_edge_mat = ShaderMaterial.new()
	_edge_mat.shader = EDGE_SHADER
	_edge_mat.set_shader_parameter("card_size", Vector2(CARD_W, CARD_H))
	_edge_mat.set_shader_parameter("radius", float(RADIUS))
	_edge_mat.set_shader_parameter("edge_w", EDGE)
	var fin: int = FINISH.get(rarity, 0)
	_edge_mat.set_shader_parameter("finish",
		FINISH_LEADEN if ctype == "curse" else fin)
	_edge_mat.set_shader_parameter("tint", tint)
	_edge_mat.set_shader_parameter("rule_col", RULE)
	_edge_mat.set_shader_parameter("gold_lit", GOLD_LIT)
	_edge_mat.set_shader_parameter("gold", GOLD)
	_edge_mat.set_shader_parameter("gold_dim", GOLD_DIM)
	edge.material = _edge_mat
	edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(edge)

	# The gem overhangs the corner, so it sits outside the clipped subtree.
	_build_cost_gem(cost)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


## Place a node as a horizontal band on the face, inset from both sides.
##
## Under TOP_WIDE the right anchor sits at 1.0, so offset_right insets from the
## RIGHT edge and must be negative. Doing that by hand at each of the eight band
## sites is how the rarity pill once came out 140px wide: one positive number
## pushed it clean past the card. Every band goes through here instead — which
## is why the inset is a parameter rather than something callers patch after.
static func _band(node: Control, y: float, h: float, inset: float = EDGE) -> Control:
	node.set_anchors_preset(Control.PRESET_TOP_WIDE)
	node.offset_left = inset
	node.offset_right = -inset
	node.offset_top = y
	node.offset_bottom = y + h
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## A gradient as a TextureRect, sized by whoever places it.
##
## EXPAND_IGNORE_SIZE is not optional: grad_tex hands back a 256x256 texture and
## TextureRect's default EXPAND_KEEP_SIZE makes that the node's *minimum* size,
## so a 1px rule asked for in offsets still comes out 256px tall.
##
## `cache_key` names what the gradient varies on, and is the caller's assertion
## that nothing else feeds it. The node is always fresh — a Node has one parent —
## but the texture behind it is a shared resource.
static func _grad(colors: PackedColorArray, offsets: PackedFloat32Array,
		radial: bool, from: Vector2, to: Vector2,
		cache_key: String = "") -> TextureRect:
	var tr: TextureRect = TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if cache_key == "":
		tr.texture = GlassStyle.grad_tex(colors, offsets, radial, from, to)
		return tr
	if not _tex_cache.has(cache_key):
		_tex_cache[cache_key] = GlassStyle.grad_tex(colors, offsets, radial, from, to)
	var hit: Texture2D = _tex_cache[cache_key]
	tr.texture = hit
	return tr


static func _load_art(id: StringName) -> Texture2D:
	var path: String = ART_DIR + String(id) + ".jpg"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## One of the name plate's two hairlines: gold, brightest mid-span, transparent
## at both ends. A four-stop horizontal gradient stands in for the CSS one.
static func _add_name_rule(parent: Control, y: float, mid_a: float) -> void:
	parent.add_child(_band(_grad(
		PackedColorArray([Color(GOLD, 0.0), Color(GOLD, mid_a),
			Color(GOLD, mid_a), Color(GOLD, 0.0)]),
		PackedFloat32Array([0.04, 0.18, 0.82, 0.96]), false,
		Vector2(0.0, 0.5), Vector2(1.0, 0.5), "name_rule:%.2f" % mid_a), y, 1.0))


## 24x5 tier bar, centred, 5px off the bottom.
static func _build_rarity_pill(rarity: String) -> Panel:
	var pill: Panel = Panel.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = RARITY_PILL.get(rarity, RARITY_PILL["starter"])
	sb.set_corner_radius_all(3)
	# Uncommon and rare pills carry a glow in the benchmark; the lower tiers
	# don't. Benchmark: 0 0 6px on uncommon, 0 0 8px on rare. Godot's shadow_size
	# is a radius, so it reads heavier at the same number — halved.
	if rarity == "uncommon" or rarity == "rare":
		sb.shadow_color = Color(sb.bg_color, 0.55)
		sb.shadow_size = 4 if rarity == "rare" else 3
	pill.add_theme_stylebox_override("panel", sb)
	_band(pill, CARD_H - 10.0, 5.0, (CARD_W - PILL_W) * 0.5)
	return pill


## A pointy-top hexagon in gold leaf, hung off the top-left corner at (-8, -8).
func _build_cost_gem(cost: int) -> void:
	var holder: Control = Control.new()
	holder.position = Vector2(-8.0, -8.0)
	holder.size = Vector2(GEM, GEM)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var mid: Color = GREEN if free else GOLD
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
	edge_line.default_color = Color(dim, 0.85)
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


static func _font(path: String, tracking: int) -> Font:
	var key: String = path + "#" + str(tracking)
	if _font_cache.has(key):
		var hit: Font = _font_cache[key]
		return hit
	var fv: FontVariation = FontVariation.new()
	fv.base_font = load(path) as FontFile
	if tracking != 0:
		fv.spacing_glyph = tracking
	_font_cache[key] = fv
	return fv


func _on_mouse_entered() -> void:
	_fade_glare(1.0)
	hover_changed.emit(uid, true)


func _on_mouse_exited() -> void:
	_fade_glare(0.0)
	hover_changed.emit(uid, false)


## One light source, two surfaces: the glare is the light ON the face, the
## edge glint is the same light caught IN the glass. They fade and track
## together so the card reads as one object under one lamp.
func _fade_glare(to: float) -> void:
	if _glare == null:
		return
	if _glare_tw != null and _glare_tw.is_valid():
		_glare_tw.kill()
	_glare_tw = create_tween()
	_glare_tw.tween_property(_glare, "modulate:a", to, GLARE_FADE)
	_glare_tw.parallel().tween_property(
		_edge_mat, "shader_parameter/hover", to, GLARE_FADE)


## Centre the glare on the pointer. Called from _gui_input, so it only runs while
## the card is actually under the cursor.
func _track_glare(local_pos: Vector2) -> void:
	if _glare != null:
		_glare.position = local_pos - Vector2(GLARE_D, GLARE_D) * 0.5
	_edge_mat.set_shader_parameter("mouse_px", local_pos)


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
