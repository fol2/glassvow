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
## the boundary the silhouette PLUS an 8px shadow skirt, and whatever the face
## painted went straight into it. The mask carries the shape alone.
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
## THE CUT. The badge is a stone, not a decal, so it is cut like one — and what
## a small stone gets is a ROSE CUT: a flat base and a dome of triangular facets
## rising to a point. No table. Two bands of six, the inner one twisted half a
## step so the facets alternate steep and shallow and no two neighbours ever
## catch the light together, then six more closing on the apex. Eighteen mirrors
## in three slopes. See _prism_mesh and card_gem.gdshader.
##
## Having no table is not stylistic. A flat table is one mirror covering a
## quarter of the stone at zero degrees — which is exactly where the resting
## lamp's half-vector already sits — so it flashes as a single sheet straight
## over the numeral and the cost becomes unreadable whenever the cursor comes
## near. Six star facets at 7 degrees replace it, and only the one wedge facing
## the light blazes: the other five hold the engraving, and the blazing wedge
## walks round the stone as the cursor circles it. Legibility and the pinwheel
## are the same decision.
##
## The heights have the one right answer here, and the LAMP sets it. A facet
## flashes when the half-vector reaches its slope, and from this corner that
## vector only ever swings 4.5 degrees (lamp on the gem) to 34 (lamp at the far
## corner). These numbers put the three families at 7, 16 and 29 — spread across
## that window so something is always lit, and nothing is ever cut so steep that
## it can never be lit at all. A deeper stone is not a livelier one; it is a
## dead one.
const GEM_MID: float = 0.639     # the inner ring, as a fraction of the girdle's
const GEM_MID_H: float = 2.3     # its height in card px
const GEM_CROWN: float = 3.6     # the apex — the cut's full height
const GEM_SIT: float = 0.3       # clear of the face, so the base cannot z-fight
## Where the stone stands, in stage coordinates. Same arithmetic the 2D holder
## does in canvas space, and the reason PAD_IN is exactly the overhang.
const GEM_AT: Vector2 = Vector2(-CARD_W * 0.5 + GEM * 0.5 - PAD_IN,
	CARD_H * 0.5 - GEM * 0.5 + PAD_IN)
## The benchmark's clip-path as a centred outline in fractions of GEM, wound
## counterclockwise seen from the camera to match _outline(). It is a pointy-top
## hexagon 0.6 percent narrower than regular — the 7%/93% in the CSS is a
## rounded cos(30), and it stays rounded here so the silhouette is still the
## benchmark's to the pixel.
const HEX: Array = [
	Vector2(0.00, 0.50), Vector2(-0.43, 0.25), Vector2(-0.43, -0.25),
	Vector2(0.00, -0.50), Vector2(0.43, -0.25), Vector2(0.43, 0.25),
]
## Each row's top derived from the one above it, so changing a band's height
## carries the rest with it instead of leaving five hand-summed offsets behind.
const ART_Y: float = EDGE
const RULE_Y: float = ART_Y + ART_H              # 1px divider under the window
const NAME_Y: float = RULE_Y + 1.0
const TYPE_Y: float = NAME_Y + NAME_H
const BODY_Y: float = TYPE_Y + TYPE_H + 2.0
## THE LAMP. The card is lit by a real point light standing in the 3D stage, and
## the cursor is where you set it down. At rest it is the room's — 2000px up and
## a touch left, which is the directional key the shader used to hard-code, the
## same lamp moved to infinity. Point at the card and it comes DOWN to LAMP_H
## above whatever the cursor is over.
##
## The distance is the whole point. At 2000 the direction to the lamp swings 8
## degrees corner to corner: enough to matter, nowhere near enough to localise
## anything, so every fragment shares a half-vector and a finish can only ever
## be a wide band. At 150 that swing is 83 degrees, the half-vector 41 with it,
## and the same material resolves into a pool about 68px across that you can
## aim — which is what a lamp on a desk does to a foil card, and what no amount
## of shader work can fake from a light that is nowhere.
##
## It replaces the 2D cursor glare outright: a white radial gradient painted
## into the face texture, which could not tilt with the pane, could not fall
## off, and greyed the card stock wherever it landed. What stands in for it is
## the lamp's own diffuse term — see LAMP_WASH in card_surface.gdshader.
const ROOM_LAMP: Vector3 = Vector3(-190.0, 572.0, 1906.0)
const LAMP_H: float = 150.0      # how high the near lamp rides; sets the pool
const LAMP_EASE: float = 18.0    # e-folds/sec as the lamp travels
const LAMP_FADE: float = 0.25    # the edge glint's own crossfade

## THE SLAB. A pane of glass is not a picture — it has thickness, and it sits
## in space. The 2D face renders into an offscreen viewport at `oversample`
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

## Offscreen render scale. Not a const, because both offscreen passes are sized
## in LOGICAL pixels while the window may be drawing at a larger content scale:
## at 2 the card is rendered at 304px and displayed at 304 on a 2x window, but
## a 4x window stretches the same 304 across 608 and the material goes soft.
## Callers that scale the window (the lab, the studio) raise this to match, and
## the game leaves it alone. Read at build time, so set it before any CardView.
static var oversample: float = 2.0
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
## The gem's two glasses, each as the two ENDS of what used to be a three-stop
## ramp: leaf with nothing over it, and the same leaf a crown of body deeper.
## Their middle stop is not a constant any more — it is wherever half a crown of
## Beer-Lambert lands, which is most of the stone. GOLD survives only because
## the benchmark also writes var(--gold) outside the badge (the name rules, the
## edge); its green counterpart had no such job and went with the ramp.
const GOLD_LIT: Color = Color(1.000, 0.914, 0.675)    # #FFE9AC — highlight
const GOLD: Color = Color(0.949, 0.757, 0.306)        # #F2C14E
const GOLD_DIM: Color = Color(0.702, 0.514, 0.122)    # #B3831F — shadow
## Free cards are cut from green glass, not amber (.card-cost.free).
const GREEN_LIT: Color = Color(0.851, 0.984, 0.906)   # #D9FBE7
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
## The cost gem's, which is a different model entirely — that one shades a
## sheet, this one follows a ray through a solid. See card_gem.gdshader.
const GEM_SHADER: Shader = preload("res://presentation/combat/card_gem.gdshader")

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
var _light_tw: Tween = null
var _edge_mat: ShaderMaterial = null
var _lit: Array[ShaderMaterial] = []   # every plate the lamp has to reach

var _inner: SubViewport = null    # the 2D face, rendered offscreen
var _stage: SubViewport = null    # the 3D room the slab sits in
var _slab: MeshInstance3D = null
var _shadow: Panel = null         # the table shadow — never tilts
var _shadow_sb: StyleBoxFlat = null
var _hovered: bool = false
var _tilt: Vector2 = Vector2.ZERO         # (rot_x, rot_y) degrees
var _tilt_v: Vector2 = Vector2.ZERO
var _tilt_target: Vector2 = Vector2.ZERO
## Where the spring comes home to. Zero everywhere but the studio.
var _rest_tilt: Vector2 = Vector2.ZERO
var _lift: float = 0.0
var _lift_v: float = 0.0
## The lamp: where it is now, how far in it has been brought, and the card-space
## point it is standing over. `_rest_*` is where it goes home to — the studio's
## sliders, and zero everywhere else.
var _lamp: Vector3 = ROOM_LAMP
var _lamp_gain: float = 0.0
var _lamp_px: Vector2 = Vector2(CARD_W, CARD_H) * 0.5
var _rest_lamp: Vector2 = Vector2(CARD_W, CARD_H) * 0.5
var _rest_gain: float = 0.0

## The card's material, resolved once in _init: the four layer names it wears,
## and the two stock properties the slab reads every frame.
var surface: Array = []
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
	surface = CardSurface.stack_of(inst.id, data)
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
	content.position = Vector2(PAD_IN, PAD_IN) * oversample
	content.scale = Vector2.ONE * oversample
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

	# The edge, last in the layer: the frame holds, and the mask's silhouette is
	# its outer cut (the shader fills past d = 0 and lets the mask do the
	# antialiasing, so there is only ever one outer edge).
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
	# A ShaderMaterial only exposes `shader_parameter/<name>` as an animatable
	# property once that parameter has been ASSIGNED — a uniform with a default
	# in the shader is not enough. Without this line the hover tween in
	# _light_up fails every time with "does not exist" and the edge glint
	# silently never fades in, which is how it shipped in the edge commit.
	_edge_mat.set_shader_parameter("hover", 0.0)
	edge.material = _edge_mat
	edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(edge)

	# The gem overhangs the corner, so it sits outside the clipped subtree —
	# inside `content` still, because it is part of the pane and must tilt
	# with it (PAD_IN exists exactly so its overhang lands on the texture).
	# Cost 0 is cut from green glass, not amber (.card-cost.free). The floor and
	# the stone over it have to agree about that, so the rule is read once here
	# rather than twice from two places that could stop matching.
	var free: bool = cost == 0 and not unplayable
	_build_cost_gem(content, cost, free)

	_build_stage(content, mat, tint, free)

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


## THE STONE'S FLOOR — the leaf it is set over and the numeral struck into it,
## and nothing else. What used to live here was a conic ramp for the metal, an
## inset polygon for the bevel and a line for the girdle: three drawings of
## light falling on a shape that did not exist. The shape exists now (see
## _prism_mesh), so the drawings go, and what is left is the one part of a gem
## that is genuinely flat — the thing underneath it.
##
## The footprint still gets painted even though the stone covers it exactly,
## because the stone's rim is antialiased against whatever is behind it and the
## leaf is what should be behind it. It is also where the shader's refracted
## sample lands when the slide runs off the print near the girdle.
func _build_cost_gem(parent: Control, cost: int, free: bool) -> void:
	var holder: Control = Control.new()
	holder.position = Vector2(-8.0, -8.0)
	holder.size = Vector2(GEM, GEM)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)

	var hex: Polygon2D = Polygon2D.new()
	var half: Vector2 = Vector2(GEM, GEM) * 0.5
	var pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in HEX:
		pts.append(half + Vector2(p.x, -p.y) * GEM)   # HEX runs y-up; canvas is not
	hex.polygon = pts
	hex.color = GREEN_LIT if free else GOLD_LIT
	holder.add_child(hex)

	# The SEAT. A stone does not float on a card, it is set into one, and the
	# hairline where the two meet is most of what tells the eye there is a stone
	# there at all — the badge lost its whole silhouette when this went with the
	# painted bevel. It lives on the floor rather than in the cut: the girdle is
	# where the glass is thinnest, so it comes through undisplaced and reads as a
	# dark line right at the edge, which is exactly what a bezel is.
	var seat: Line2D = Line2D.new()
	var ring: PackedVector2Array = pts.duplicate()
	ring.append(pts[0])
	seat.points = ring
	seat.width = 1.0
	seat.default_color = Color(GREEN_DIM if free else GOLD_DIM, 0.85)
	holder.add_child(seat)

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


func _build_stage(content: Control, mat: Dictionary, tint: Color,
		free: bool) -> void:
	var thick: float = mat["thick"]
	_inner = SubViewport.new()
	_inner.size = Vector2i(
		int((CARD_W + 2.0 * PAD_IN) * oversample),
		int((CARD_H + 2.0 * PAD_IN) * oversample))
	_inner.transparent_bg = true
	_inner.disable_3d = true
	# Fonts rasterise per-viewport: without this the 2x canvas scale draws 1x
	# glyph bitmaps stretched — the exact blur content_scale_factor avoids on
	# the window. This is the same mechanism, told the same factor.
	_inner.oversampling_override = oversample
	_inner.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_inner.add_child(content)
	add_child(_inner)

	_stage = SubViewport.new()
	_stage.size = Vector2i(
		int((CARD_W + 2.0 * PAD_3D) * oversample),
		int((CARD_H + 2.0 * PAD_3D) * oversample))
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
	_slab.set_surface_override_material(1, _plate(mat, tint))
	# The stone does NOT take the card's finish, and never could: a coating is a
	# property of a sheet and there is no sheet here. It is set over the leaf,
	# cut, and lit by the same lamp — see card_gem.gdshader.
	_slab.set_surface_override_material(2, _gem_plate(free))
	_push_lamp()   # the room's lamp, before the card has ever been touched
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


## Anything on the slab that reads the face and takes the light. The two shaders
## share nothing else — one shades a sheet, the other follows a ray through a
## solid — but they agree on where the texture is and where the lamp is, and
## both land on _lit so _push_lamp reaches them through one loop instead of two
## formulas that can drift.
func _shaded(sh: Shader) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("face_tex", _inner.get_texture())
	m.set_shader_parameter("face_size",
		Vector2(CARD_W, CARD_H) + Vector2(PAD_IN, PAD_IN) * 2.0)
	_lit.append(m)
	return m


## The stone's material: two colours and a height, which is all a cut needs once
## the cut itself is real geometry.
##
## The two are the ENDS of the same three-stop ramp the benchmark painted across
## this badge — leaf at no depth, shadow at a full crown. Its middle stop is not
## passed at all and does not need to be: half a crown of glass is where the
## light lands after Beer-Lambert, and half a crown is most of the crown. The
## ramp is still there, it is just being computed by the thing that caused it.
func _gem_plate(free: bool) -> ShaderMaterial:
	var m: ShaderMaterial = _shaded(GEM_SHADER)
	m.set_shader_parameter("foil", GREEN_LIT if free else GOLD_LIT)
	m.set_shader_parameter("deep", GREEN_DIM if free else GOLD_DIM)
	m.set_shader_parameter("crown", GEM_CROWN)
	return m


## One face plate on the slab, wearing `p`.
func _plate(p: Dictionary, tint: Color) -> ShaderMaterial:
	var m: ShaderMaterial = _shaded(SURFACE_SHADER)
	m.set_shader_parameter("face_pad", Vector2(PAD_IN, PAD_IN))
	m.set_shader_parameter("card_size", Vector2(CARD_W, CARD_H))
	m.set_shader_parameter("radius", float(RADIUS))
	m.set_shader_parameter("art_rect",
		Vector4(EDGE, ART_Y, CARD_W - 2.0 * EDGE, ART_H))
	CardSurface.apply(m, p, tint)
	return m


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


## One ring of the cut, in stage coordinates: the badge outline scaled about the
## gem's own centre and turned by `twist`, at height `z` above the leaf.
static func _gem_ring(scale: float, twist: float, z: float) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for p: Vector2 in HEX:
		var q: Vector2 = GEM_AT + (p * GEM * scale).rotated(twist)
		out.append(Vector3(q.x, q.y, z))
	return out


## One facet. Points arrive counterclockwise as seen from the camera with z
## measured UP FROM THE LEAF, and leave wound clockwise (Godot's front face)
## and translated onto the slab.
##
## All three vertices take the facet's own flat normal, and that single line is
## the whole difference between a cut stone and a cabochon: smooth these and the
## eighteen mirrors become one dome, which is exactly what the painted badge was.
## z rides out to UV2 as well, because the shader needs to know how deep the
## glass is under each fragment and only the cut knows that.
static func _facet(st: SurfaceTool, base_z: float,
		a: Vector3, b: Vector3, c: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a).normalized()
	for p: Vector3 in [a, c, b]:
		st.set_normal(n)
		st.set_uv(_uv(p.x, p.y))
		st.set_uv2(Vector2(p.z, 0.0))
		st.add_vertex(Vector3(p.x, p.y, p.z + base_z))


## Surface 0: the side band — the glass's cross-section, visible only when
## the pane leans. Surface 1: the front face, a fan over the outline; its
## rounded silhouette is geometry, so the tilted card's edge stays clean
## under MSAA rather than relying on texture alpha. Surface 2: the cost gem,
## a rose cut standing proud of the corner — twelve facets and a table, over a
## girdle that is the benchmark's own hexagon so the silhouette never moved.
##
## Its base sits ON the face rather than over it, which is what keeps the
## painted footprint from peeking out from under the crown when the card leans:
## a raised table shifts about half a pixel at full tilt, a base at the same
## plane shifts none.
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
	var g: PackedVector3Array = _gem_ring(1.0, 0.0, 0.0)
	var m: PackedVector3Array = _gem_ring(GEM_MID, PI / 6.0, GEM_MID_H)
	var apex: Vector3 = Vector3(GEM_AT.x, GEM_AT.y, GEM_CROWN)
	var base_z: float = hz + GEM_SIT
	for i: int in range(6):
		var j: int = (i + 1) % 6
		# Three facets per sixth, and they are three different mirrors. The star
		# spans a girdle edge up to the ring point above it — the steep family,
		# 29 degrees. Its neighbour hangs off the girdle point they share, at 16.
		# The last closes on the apex at 7, and that one is what replaced the
		# table: six shallow wedges instead of one flat sheet.
		_facet(gem, base_z, g[i], g[j], m[i])
		_facet(gem, base_z, m[i], g[j], m[j])
		_facet(gem, base_z, m[i], m[j], apex)
	gem.commit(mesh)
	return mesh


## Move the card's REST pose, in the same normalised -1..1 the cursor gives.
## The material is angle-driven and the angle is normally cursor-driven, so
## without this there is no way to LOOK at a finish — the pose dies the moment
## you stop hovering to read the panel.
##
## It sets where the card comes back to, not where it is: the cursor still owns
## the pose while it is on the card, and the spring returns here afterwards
## rather than to flat. In the game nothing calls this, _rest_tilt stays zero,
## and "returns to rest" means what it always did.
func hold_pose(n: Vector2) -> void:
	_rest_tilt = Vector2(-n.y, -n.x) * MAX_TILT
	if _hovered or is_processing():
		_tilt_target = _rest_tilt   # let the spring carry it, mid-flight
		return
	_tilt = _rest_tilt
	_tilt_v = Vector2.ZERO
	_apply_transform()
	# One repaint at the new pose, then idle: UPDATE_ONCE re-arms each call, so
	# dragging a slider costs a frame per step instead of running forever.
	_set_live(false)


## Move the lamp's REST position, in the same normalised -1..1 the cursor gives,
## and how far in it has been carried: 0 is the room's lamp, 1 is standing right
## over the card. Same contract as hold_pose — it sets where the light comes
## home to, not where it is, so the cursor still owns the lamp while it is on
## the card. In the game nothing calls this and the lamp stays in the room.
func hold_lamp(n: Vector2, gain: float = 1.0) -> void:
	_rest_lamp = (n * 0.5 + Vector2(0.5, 0.5)) * Vector2(CARD_W, CARD_H)
	_rest_gain = clampf(gain, 0.0, 1.0)
	if _hovered or is_processing():
		return          # the ease is already running; let it carry the lamp
	_lamp = _lamp_goal()
	_lamp_gain = _rest_gain
	_push_lamp()
	_set_live(false)


## The lamp's world position for a cursor at `px` in card pixels: straight up
## from the point it is over. Stage coordinates run y-up from the card's centre.
static func _over(px: Vector2) -> Vector3:
	return Vector3(px.x - CARD_W * 0.5, CARD_H * 0.5 - px.y, LAMP_H)


## Where the lamp is heading. Gain zero means the room's light and nothing else,
## so the POSITION has to go back to the room with it — leave it parked over the
## last cursor point and the specular stays pooled there after the light is out.
func _lamp_goal() -> Vector3:
	if _hovered:
		return _over(_lamp_px)
	return _over(_rest_lamp) if _rest_gain > 0.0 else ROOM_LAMP


func _push_lamp() -> void:
	# Falloff normalised at the card's centre, so the inverse square reads as a
	# gradient across the face instead of an exposure change every time the lamp
	# moves. The centre travels with the lift, so it is measured, not assumed.
	var ref: float = _lamp.distance_squared_to(Vector3(0.0, 0.0, _lift))
	for m: ShaderMaterial in _lit:
		m.set_shader_parameter("lamp", _lamp)
		m.set_shader_parameter("lamp_gain", _lamp_gain)
		m.set_shader_parameter("lamp_ref", ref)


## Freeze both offscreen passes when nothing moves; UPDATE_ONCE paints one
## last frame and sleeps. A 61-card lab must idle at zero render cost.
func _set_live(on: bool) -> void:
	var mode: SubViewport.UpdateMode = SubViewport.UPDATE_ALWAYS if on \
		else SubViewport.UPDATE_ONCE
	_inner.render_target_update_mode = mode
	_stage.render_target_update_mode = mode


func _ready() -> void:
	set_process(false)
	# Both of these are cursor-driven and so cannot otherwise exist in a scripted
	# shot: GLASSVOW_TILT="nx,ny" holds a pose, GLASSVOW_LAMP="x,y[,gain]" stands
	# the lamp somewhere (all -1..1 but gain, which is 0..1). They are applied
	# BEFORE the dump, not after — the other way round saves the card at rest and
	# neither the pose nor the light ever reaches the file.
	var held: bool = false
	var lit: String = OS.get_environment("GLASSVOW_LAMP")
	if lit != "":
		var lp: PackedStringArray = lit.split(",")
		if lp.size() >= 2:
			hold_lamp(Vector2(float(lp[0]), float(lp[1])),
				float(lp[2]) if lp.size() > 2 else 1.0)
			held = true
	var forced: String = OS.get_environment("GLASSVOW_TILT")
	if forced != "":
		var p: PackedStringArray = forced.split(",")
		if p.size() == 2:
			hold_pose(Vector2(float(p[0]), float(p[1])))
			held = true
	var dump: String = OS.get_environment("GLASSVOW_DUMP")
	if dump != "":
		for _i: int in range(10):
			await get_tree().process_frame
		_inner.get_texture().get_image().save_png("%s_inner_%d.png" % [dump, uid])
		_stage.get_texture().get_image().save_png("%s_stage_%d.png" % [dump, uid])
	if held:
		return  # the hold armed the repaint; what it set reaches the shot
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

	# The lamp travels rather than cutting: exponentially, so it is under the
	# cursor within a frame or two and still takes a readable moment to walk
	# back out to the room. No spring — a lamp is carried, not sprung, and the
	# overshoot that gives the card its life would read as a wobbling bulb.
	var k: float = 1.0 - exp(-LAMP_EASE * dt)
	var goal: Vector3 = _lamp_goal()
	_lamp += (goal - _lamp) * k
	_lamp_gain += ((1.0 if _hovered else _rest_gain) - _lamp_gain) * k

	# Settled: snap the last thousandth away and stop paying for the card.
	# "Settled" is measured against _rest_tilt and _rest_gain, not against flat
	# and dark — a card the studio has parked at an angle under a held lamp is
	# at rest THERE, and comparing to zero would leave it spinning its viewports
	# forever a few degrees from home.
	var done: bool = not _hovered and _tilt.distance_to(_rest_tilt) < 0.02 \
		and _tilt_v.length() < 0.05 and _lift < 0.05 and absf(_lift_v) < 0.1 \
		and absf(_lamp_gain - _rest_gain) < 0.004 and _lamp.distance_to(goal) < 1.0
	if done:
		_tilt = _rest_tilt
		_tilt_v = Vector2.ZERO
		_lift = 0.0
		_lift_v = 0.0
		_lamp = goal
		_lamp_gain = _rest_gain
	_push_lamp()
	_apply_transform()
	if done:
		_set_live(false)
		set_process(false)


## Push the spring's state onto the slab and its shadow. The shadow stays on
## the table, but it is not inert: as the pane rises its shadow slides down,
## spreads and thins, and it slips out from under whichever side has lifted —
## the reading that ties the two together. It never rotates, because a shadow
## on a flat table cannot.
func _apply_transform() -> void:
	_slab.rotation_degrees = Vector3(_tilt.x, _tilt.y, 0.0)
	_slab.position.z = _lift
	var h: float = _lift / MAX_LIFT
	_shadow.position = Vector2(_tilt.y, _tilt.x) * 0.28 + Vector2(0.0, 4.0 * h)
	_shadow.modulate.a = 1.0 - 0.22 * h
	_shadow_sb.shadow_size = _shadow_size + roundi(4.0 * h)


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
	_light_up(1.0)
	hover_changed.emit(uid, true)


func _on_mouse_exited() -> void:
	_hovered = false
	_tilt_target = _rest_tilt
	_light_up(0.0)
	hover_changed.emit(uid, false)


## One lamp, two surfaces. The face's share is the point light itself, which
## eases in _process; this is the EDGE's — light caught IN the glass rather than
## on it. It stays a scalar because the edge is a canvas shader on the flat
## Control and has no way to see the 3D stage the lamp stands in; it crossfades
## on the same quarter-second so the two still read as one event.
func _light_up(to: float) -> void:
	if _light_tw != null and _light_tw.is_valid():
		_light_tw.kill()
	_light_tw = create_tween()
	_light_tw.tween_property(_edge_mat, "shader_parameter/hover", to, LAMP_FADE)


## Set the lamp down on the pointer. Called from _gui_input, so it only runs
## while the card is actually under the cursor.
func _track_lamp(local_pos: Vector2) -> void:
	_lamp_px = local_pos
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
		_track_lamp(mm.position)
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
