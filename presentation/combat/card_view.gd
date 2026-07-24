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
##   rarity    a 24 x 5 pill, bottom centre — deliberately dropped. A real card
##             does not label its own tier; you read it off the stock and the
##             coating instead. See card_surface.gd.
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
##
## The card is not flat: the 2D face above renders offscreen and rides a glass
## slab in a real 3D stage — see THE SLAB below. Callers never see any of it;
## the node's rect, signals and input behave exactly as a flat Control.

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
## The benchmark's `box-shadow: 0 8px 22px rgba(0,0,0,.55)`. A CSS blur of 22
## reaches ~11px each side of the edge, which is what Godot's shadow_size means;
## the 8px drop is what keeps the shadow UNDER the card rather than around it.
## Undersized and barely dropped, it rings the silhouette evenly and reads as a
## halo — the shape has to be lopsided for the eye to accept it as a shadow.
const SHADOW_COLOR: Color = Color(0, 0, 0, 0.55)
const SHADOW_SIZE: int = 11
const SHADOW_OFFSET: Vector2 = Vector2(0, 8)
const ART_H: float = 91.0
const NAME_H: float = 23.0
const TYPE_H: float = 13.0
const GEM: float = 36.0
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

## THE SLAB. A pane of glass is not a picture — it has thickness, and it sits
## in space. The 2D face renders into an offscreen viewport at OVERSAMPLE
## resolution; a rounded-rect prism carries that texture in a tiny 3D stage
## with a long-lens camera. Head-on, the render is the flat card. On hover the
## slab tilts toward the cursor and lifts a breath, and the face takes real
## perspective — the near corner genuinely larger, which is the whole payoff.
##
## The thickness is modelled and, at these numbers, deliberately invisible.
## The front face occludes the side band until the tilt passes the half-angle
## the card subtends at the lens, atan(CARD_W/2 / camera distance) ~= 5.8deg
## sideways, and past that the band is at most thick * sin(tilt) — under a
## pixel at every stock in the catalogue. Measured: renders at 0.5 and 20 come
## out pixel-identical, and a 30px slab only slides the card sideways. That is
## also what a real glass card does at 7deg, so it stays. Thickness therefore
## reaches the eye through the SHADOW and the EDGE CUT, not through a visible
## band; showing the band would need the tilt to grow with it (16px at a 12deg
## throw puts ~2px of glass along the leaning side; 26 at 18deg reads as a tile).
##
## The shadow does not ride the slab: it is the card's shadow ON THE TABLE, a
## separate flat panel behind the stage that stays put (and eases away) while
## the pane above it moves.
const OVERSAMPLE: float = 2.0    # inner render scale — crisp through the 3D pass
const PAD_IN: float = 8.0        # inner texture margin: exactly the gem overhang
const PAD_3D: float = 24.0       # stage margin: room for the tilted silhouette
const FOV_DEG: float = 20.0      # long lens — perspective present, never cartoon
const MAX_TILT: float = 7.0      # degrees at full cursor throw
const MAX_LIFT: float = 10.0     # px toward the camera while held
const ARC_SEGS: int = 8          # prism corner-arc resolution
## Tilt spring (omega, zeta) while HELD: critically damped, because the card is
## pinned under the cursor. The RELEASE spring is not a constant — it is the
## stock's rigidity, and it is the one property of the material you feel
## instead of see: thin stock rings back loose and long, a rigid plastic card
## stops dead. See CardSurface.STOCK.
const SPR_HELD: Vector2 = Vector2(18.0, 1.0)

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
## The edge system: type is the colour of the glass, the STOCK is the cut. One
## shader owns border, rim, corner gold and hover glint — the cut tiers are
## documented at the top of card_edge.gdshader, and which cut a card gets is
## the stock layer's call (CardSurface.STOCK.cut), not the rarity's.
const EDGE_SHADER: Shader = preload("res://presentation/combat/card_edge.gdshader")
## The face's material, over the same texture the flat card used. Everything
## it adds is angle-driven, so at rest it costs the card almost nothing.
const SURFACE_SHADER: Shader = preload("res://presentation/combat/card_surface.gdshader")

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

var _inner: SubViewport = null    # the 2D face, rendered offscreen
var _stage: SubViewport = null    # the 3D room the slab sits in
var _slab: MeshInstance3D = null
var _shadow: Panel = null         # the table shadow — never tilts
var _shadow_sb: StyleBoxFlat = null
var _hovered: bool = false
var _tilt: Vector2 = Vector2.ZERO         # (rot_x, rot_y) degrees
var _tilt_v: Vector2 = Vector2.ZERO
var _tilt_target: Vector2 = Vector2.ZERO
var _lift: float = 0.0
var _lift_v: float = 0.0

## The card's material, resolved once in _init: which recipe it wears, the
## flattened four-layer parameter set, and the two stock properties the slab
## reads every frame.
var surface: String = ""
var _spr_free: Vector2 = Vector2(11.0, 0.55)
var _shadow_size: int = SHADOW_SIZE

## Geometry depends only on the card constants and the stock's thickness, so
## one prism serves every card of a given stock — six meshes for the catalogue.
## Materials differ per card and live on the MeshInstance3D as overrides.
static var _prism_cache: Dictionary = {}


func _init(inst: CardInst, data: Dictionary, cost: int) -> void:
	uid = inst.uid
	card_id = inst.id
	target_kind = str(data.get("target", ""))
	var unplayable_flag: bool = data.get("unplayable", false)
	unplayable = unplayable_flag
	var ctype: String = str(data.get("type", ""))
	var tint: Color = TYPE_TINT.get(ctype, GlassStyle.GLASS)
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	size = custom_minimum_size
	pivot_offset = custom_minimum_size * 0.5

	# What this card is made of, before anything is built: the stock decides
	# the slab's thickness, the cut of its edge, the weight of its shadow and
	# how it springs back, so it has to be known first.
	surface = CardSurface.recipe_of(inst.id, data)
	var mat: Dictionary = CardSurface.params(surface)
	_spr_free = mat["spring"]
	var weight: float = mat["shadow"]
	_shadow_size = int(roundf(float(SHADOW_SIZE) * weight))

	# The table shadow, first and flat: a real object's shadow falls on the
	# surface beneath it, so it lives OUTSIDE the slab and holds still (easing
	# away slightly) while the card above it tilts and lifts.
	_shadow_sb = StyleBoxFlat.new()
	# draw_center stays true over a transparent fill. Turn it off and Godot
	# punches the shadow's core out along the OFFSET rect, leaving a ring
	# hanging a dozen px clear of the card — measured as an unshadowed gap
	# below the bottom edge. The card covers the core anyway; when it tilts
	# off, what shows through is exactly what should: its shadow.
	_shadow_sb.bg_color = Color(0, 0, 0, 0)
	_shadow_sb.set_corner_radius_all(RADIUS)
	# A shadow carries a breath of whatever the light had to get past, so a
	# reflective material warms its own. Off the material rather than the tier:
	# change what a rare is made of and its shadow follows without being told.
	var ink: Color = mat["ink"]
	var gives_back: float = mat["sheen"]
	_shadow_sb.shadow_color = SHADOW_COLOR.lerp(
		Color(ink.darkened(0.45), 0.55), 0.20 * gives_back)
	_shadow_sb.shadow_size = _shadow_size
	_shadow_sb.shadow_offset = SHADOW_OFFSET
	_shadow = Panel.new()
	_shadow.add_theme_stylebox_override("panel", _shadow_sb)
	_shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shadow)

	# Everything visual from here down builds under `content`, which renders
	# offscreen into _inner rather than into this Control — see THE SLAB.
	var content: Control = Control.new()
	content.position = Vector2(PAD_IN, PAD_IN) * OVERSAMPLE
	content.scale = Vector2.ONE * OVERSAMPLE
	content.size = Vector2(CARD_W, CARD_H)

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	# Benchmark stock is a 168deg gradient, not flat: the type tint bleeds in at
	# 15% from the top-left and dies out by 58%. StyleBoxFlat has no gradient, so
	# the tint is folded into the flat fill and the gradient itself is a child
	# below everything else.
	sb.bg_color = INK
	sb.set_corner_radius_all(RADIUS)

	# The face: card stock and border. It draws; it clips nothing.
	var face: Panel = Panel.new()
	face.add_theme_stylebox_override("panel", sb)
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(face)

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
	content.add_child(layer)

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
	var cut: int = mat["cut"]
	_edge_mat.set_shader_parameter("finish", cut)
	_edge_mat.set_shader_parameter("tint", tint)
	_edge_mat.set_shader_parameter("rule_col", RULE)
	_edge_mat.set_shader_parameter("gold_lit", GOLD_LIT)
	_edge_mat.set_shader_parameter("gold", GOLD)
	_edge_mat.set_shader_parameter("gold_dim", GOLD_DIM)
	edge.material = _edge_mat
	edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(edge)

	# The gem overhangs the corner, so it sits outside the clipped subtree —
	# inside `content` still, because it is part of the pane and must tilt
	# with it (PAD_IN exists exactly so its overhang lands on the texture).
	_build_cost_gem(content, cost)

	_build_stage(content, mat, tint)

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


## A pointy-top hexagon in gold leaf, hung off the top-left corner at (-8, -8).
func _build_cost_gem(parent: Control, cost: int) -> void:
	var holder: Control = Control.new()
	holder.position = Vector2(-8.0, -8.0)
	holder.size = Vector2(GEM, GEM)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)

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


## ── THE SLAB ─────────────────────────────────────────────────────────────
## Offscreen face → glass prism → long-lens camera → back onto this Control.


func _build_stage(content: Control, mat: Dictionary, tint: Color) -> void:
	var thick: float = mat["thick"]
	_inner = SubViewport.new()
	_inner.size = Vector2i(
		int((CARD_W + 2.0 * PAD_IN) * OVERSAMPLE),
		int((CARD_H + 2.0 * PAD_IN) * OVERSAMPLE))
	_inner.transparent_bg = true
	_inner.disable_3d = true
	# Fonts rasterise per-viewport: without this the 2x canvas scale draws 1x
	# glyph bitmaps stretched — the exact blur content_scale_factor avoids on
	# the window. This is the same mechanism, told the same factor.
	_inner.oversampling_override = OVERSAMPLE
	_inner.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_inner.add_child(content)
	add_child(_inner)

	_stage = SubViewport.new()
	_stage.size = Vector2i(
		int((CARD_W + 2.0 * PAD_3D) * OVERSAMPLE),
		int((CARD_H + 2.0 * PAD_3D) * OVERSAMPLE))
	_stage.own_world_3d = true
	_stage.transparent_bg = true
	_stage.msaa_3d = Viewport.MSAA_4X
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_stage)

	if not _prism_cache.has(thick):
		_prism_cache[thick] = _prism_mesh(thick)
	_slab = MeshInstance3D.new()
	_slab.mesh = _prism_cache[thick]

	# The side band is a cross-section of the material, not a lit surface —
	# unshaded, one flat colour, the only place you see the stock itself.
	var side_mat: StandardMaterial3D = StandardMaterial3D.new()
	side_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	side_mat.albedo_color = CardSurface.body_color(mat, tint)
	side_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_slab.set_surface_override_material(0, side_mat)

	# The face carries the material. Everything the 2D pass painted comes
	# through untouched; what this adds is the light the surface gives back,
	# and every channel of it is angle-driven — see card_surface.gdshader.
	var face_mat: ShaderMaterial = ShaderMaterial.new()
	face_mat.shader = SURFACE_SHADER
	face_mat.set_shader_parameter("face_tex", _inner.get_texture())
	face_mat.set_shader_parameter("face_size",
		Vector2(CARD_W, CARD_H) + Vector2(PAD_IN, PAD_IN) * 2.0)
	face_mat.set_shader_parameter("face_pad", Vector2(PAD_IN, PAD_IN))
	face_mat.set_shader_parameter("card_size", Vector2(CARD_W, CARD_H))
	face_mat.set_shader_parameter("radius", float(RADIUS))
	face_mat.set_shader_parameter("art_rect",
		Vector4(EDGE, ART_Y, CARD_W - 2.0 * EDGE, ART_H))
	CardSurface.apply(face_mat, mat, tint)
	_slab.set_surface_override_material(1, face_mat)
	# The gem plate does NOT take the finish. It is a struck badge applied over
	# the stock, not part of it — leaf on leaf would read as a smear, and the
	# gem already carries its own metal in the 2D pass.
	var gem_mat: StandardMaterial3D = StandardMaterial3D.new()
	gem_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gem_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gem_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	gem_mat.albedo_texture = _inner.get_texture()
	_slab.set_surface_override_material(2, gem_mat)
	_stage.add_child(_slab)

	# Head-on long lens, at the distance where the stage rect maps 1:1 onto
	# logical pixels at z = 0 — so at rest this render IS the flat card.
	var cam: Camera3D = Camera3D.new()
	cam.fov = FOV_DEG
	# ...measured to the FRONT face, not the slab's mid-plane. Frame the mid-
	# plane instead and the face — nearer the lens by half the thickness —
	# comes out half a percent oversize, overhanging its own shadow.
	var dist: float = (CARD_H + 2.0 * PAD_3D) * 0.5 \
		/ tan(deg_to_rad(FOV_DEG * 0.5))
	cam.position = Vector3(0.0, 0.0, dist + thick * 0.5)
	cam.near = dist * 0.5
	cam.far = dist * 1.5
	_stage.add_child(cam)

	var display: TextureRect = TextureRect.new()
	display.texture = _stage.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.position = Vector2(-PAD_3D, -PAD_3D)
	display.size = Vector2(CARD_W + 2.0 * PAD_3D, CARD_H + 2.0 * PAD_3D)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)


## The pane outline in stage coordinates (x right, y up, origin at centre),
## counterclockwise as seen from the camera. Shared by the face fan and the
## side band.
static func _outline() -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var cx: float = CARD_W * 0.5 - float(RADIUS)
	var cy: float = CARD_H * 0.5 - float(RADIUS)
	var centers: Array = [
		Vector2(cx, cy), Vector2(-cx, cy), Vector2(-cx, -cy), Vector2(cx, -cy),
	]
	for c: int in range(4):
		var base: float = float(c) * PI * 0.5
		for s: int in range(ARC_SEGS + 1):
			var a: float = base + (float(s) / float(ARC_SEGS)) * PI * 0.5
			var centre: Vector2 = centers[c]
			pts.append(centre + Vector2(cos(a), sin(a)) * float(RADIUS))
	return pts


## Stage point → texture UV. The inner texture spans the card rect plus
## PAD_IN on every side (the gem's overhang), so both map through here.
static func _uv(x: float, y: float) -> Vector2:
	return Vector2(
		(x + CARD_W * 0.5 + PAD_IN) / (CARD_W + 2.0 * PAD_IN),
		(CARD_H * 0.5 - y + PAD_IN) / (CARD_H + 2.0 * PAD_IN))


## Surface 0: the side band — the glass's cross-section, visible only when
## the pane leans. Surface 1: the front face, a fan over the outline; its
## rounded silhouette is geometry, so the tilted card's edge stays clean
## under MSAA rather than relying on texture alpha. Surface 2: the gem
## plate — the cost gem overhangs the silhouette, so its corner square rides
## just proud of the face sampling the same texture (where it re-covers the
## face the texels are identical and opaque, so the overlap cannot show).
static func _prism_mesh(thick: float) -> ArrayMesh:
	var pts: PackedVector2Array = _outline()
	var n: int = pts.size()
	var hz: float = thick * 0.5
	var mesh: ArrayMesh = ArrayMesh.new()

	var side: SurfaceTool = SurfaceTool.new()
	side.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(n):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var fa: Vector3 = Vector3(a.x, a.y, hz)
		var fb: Vector3 = Vector3(b.x, b.y, hz)
		var ba: Vector3 = Vector3(a.x, a.y, -hz)
		var bb: Vector3 = Vector3(b.x, b.y, -hz)
		side.add_vertex(fa)
		side.add_vertex(fb)
		side.add_vertex(bb)
		side.add_vertex(fa)
		side.add_vertex(bb)
		side.add_vertex(ba)
	side.commit(mesh)

	# Godot's front faces wind CLOCKWISE seen from outside — the outline is
	# counterclockwise from the camera, so each fan triangle goes centre → b → a.
	var face: SurfaceTool = SurfaceTool.new()
	face.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(n):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		face.set_uv(_uv(0.0, 0.0))
		face.add_vertex(Vector3(0.0, 0.0, hz))
		face.set_uv(_uv(b.x, b.y))
		face.add_vertex(Vector3(b.x, b.y, hz))
		face.set_uv(_uv(a.x, a.y))
		face.add_vertex(Vector3(a.x, a.y, hz))
	face.commit(mesh)

	var gem: SurfaceTool = SurfaceTool.new()
	gem.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gx0: float = -CARD_W * 0.5 - PAD_IN
	var gx1: float = -CARD_W * 0.5 + GEM - PAD_IN
	var gy0: float = CARD_H * 0.5 + PAD_IN
	var gy1: float = CARD_H * 0.5 - GEM + PAD_IN
	var gz: float = hz + 0.4
	var quad: Array = [
		Vector3(gx0, gy0, gz), Vector3(gx0, gy1, gz),
		Vector3(gx1, gy1, gz), Vector3(gx1, gy0, gz),
	]
	for idx: int in [0, 2, 1, 0, 3, 2]:  # clockwise from the camera — see above
		var p: Vector3 = quad[idx]
		gem.set_uv(_uv(p.x, p.y))
		gem.add_vertex(p)
	gem.commit(mesh)
	return mesh


## Freeze both offscreen passes when nothing moves; UPDATE_ONCE paints one
## last frame and sleeps. A 61-card lab must idle at zero render cost.
func _set_live(on: bool) -> void:
	var mode: SubViewport.UpdateMode = SubViewport.UPDATE_ALWAYS if on \
		else SubViewport.UPDATE_ONCE
	_inner.render_target_update_mode = mode
	_stage.render_target_update_mode = mode


func _ready() -> void:
	set_process(false)
	# GLASSVOW_TILT="nx,ny" (each -1..1): hold a static pose for screenshots —
	# the tilt is cursor-driven and cannot otherwise exist in a scripted shot.
	var dump: String = OS.get_environment("GLASSVOW_DUMP")
	if dump != "":
		for _i: int in range(10):
			await get_tree().process_frame
		_inner.get_texture().get_image().save_png("%s_inner_%d.png" % [dump, uid])
		_stage.get_texture().get_image().save_png("%s_stage_%d.png" % [dump, uid])
	var forced: String = OS.get_environment("GLASSVOW_TILT")
	if forced != "":
		var p: PackedStringArray = forced.split(",")
		if p.size() == 2:
			_tilt = Vector2(-float(p[1]), -float(p[0])) * MAX_TILT
			_slab.rotation_degrees = Vector3(_tilt.x, _tilt.y, 0.0)
		return  # stay live so the pose reaches the shot
	await get_tree().process_frame
	await get_tree().process_frame
	if not _hovered:
		_set_live(false)


## The spring integrator. Runs only while the card is held or still
## settling; the moment everything is at rest the viewports freeze again.
func _process(delta: float) -> void:
	var dt: float = minf(delta, 1.0 / 30.0)  # keep the spring stable on hitches
	var spr: Vector2 = SPR_HELD if _hovered else _spr_free
	var w2: float = spr.x * spr.x
	var dampen: float = 2.0 * spr.y * spr.x
	_tilt_v += ((_tilt_target - _tilt) * w2 - _tilt_v * dampen) * dt
	_tilt += _tilt_v * dt
	var lift_target: float = MAX_LIFT if _hovered else 0.0
	_lift_v += ((lift_target - _lift) * w2 - _lift_v * dampen) * dt
	_lift += _lift_v * dt

	_slab.rotation_degrees = Vector3(_tilt.x, _tilt.y, 0.0)
	_slab.position.z = _lift
	# The shadow stays on the table, but it is not inert: as the pane rises its
	# shadow slides down, spreads and thins, and it slips out from under
	# whichever side has lifted — the reading that ties the two together. It
	# never rotates, because a shadow on a flat table cannot.
	var h: float = _lift / MAX_LIFT
	_shadow.position = Vector2(_tilt.y, _tilt.x) * 0.28 + Vector2(0.0, 4.0 * h)
	_shadow.modulate.a = 1.0 - 0.22 * h
	_shadow_sb.shadow_size = _shadow_size + roundi(4.0 * h)

	if not _hovered and _tilt.length() < 0.02 and _tilt_v.length() < 0.05 \
			and _lift < 0.05 and absf(_lift_v) < 0.1:
		_tilt = Vector2.ZERO
		_tilt_v = Vector2.ZERO
		_lift = 0.0
		_lift_v = 0.0
		_slab.rotation_degrees = Vector3.ZERO
		_slab.position.z = 0.0
		_shadow.position = Vector2.ZERO
		_shadow.modulate.a = 1.0
		_shadow_sb.shadow_size = _shadow_size
		_set_live(false)
		set_process(false)


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
	_hovered = true
	_set_live(true)
	set_process(true)
	_fade_glare(1.0)
	hover_changed.emit(uid, true)


func _on_mouse_exited() -> void:
	_hovered = false
	_tilt_target = Vector2.ZERO
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
	# The corner under the cursor comes toward the viewer — the pane presents
	# itself to be read, the way you angle glass to catch the light. In stage
	# coordinates (y up, camera on +Z) that works out to rot = -n * MAX_TILT
	# on both axes for a cursor at normalised n.
	var n: Vector2 = (local_pos / Vector2(CARD_W, CARD_H)) * 2.0 - Vector2.ONE
	n = n.clamp(-Vector2.ONE, Vector2.ONE)
	_tilt_target = Vector2(-n.y, -n.x) * MAX_TILT


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
