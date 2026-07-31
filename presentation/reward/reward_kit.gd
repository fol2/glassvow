class_name RewardKit
extends RefCounted
## The drawing kit the reward candidates share: leaded panes, parallax plates,
## pools of light, embers, mipped art, outlined text.
##
## It exists because three screens need the same eight helpers and none of them
## needs a base class — they disagree about what a reward screen IS, which is
## the whole point of having three, so the thing they share had better be the
## paint and not the structure. Hold one of these per screen, pointed at the
## Control everything should land in.
##
## Everything is added to `stage` with mouse input OFF. Scenery does not take
## clicks; whatever is actually interactive (the offering) is added by the
## screen itself, outside this kit.

const GLASS: Shader = preload("res://presentation/reward/leaded_glass.gdshader")
const ART: String = "res://assets/art/"

## The canvas the kit's screens are composed on.
##
## `RewardWindow`, `RewardEmbers`, `RewardReliquary` and `RewardRose` are design
## studies, not shipping screens — `main.gd` builds `RewardScreen` and nothing
## else, and `reward_lab.gd` is the only thing that reaches them. Every figure in
## them is an absolute coordinate on the identity shape: a chest at x=590, a
## button at (495, 692), a caption box at (190, 650). That is a legitimate way to
## author a study and a terrible one to pretend is portable.
##
## So the canvas is named once, here, rather than the five places a bare `1180.0`
## stood in for "clean across the screen". It is not a shape seam and does not
## pretend to be one: it makes the fixed canvas legible, and it means a study
## that IS ported later has one constant to chase instead of a literal to grep
## for. It reads from `StageShape` so the two cannot drift apart — a `static var`
## rather than a `const` only because GDScript will not index a Dictionary in a
## constant expression.
static var CANVAS: Vector2 = Vector2(StageShape.REFERENCES[StageShape.IDENTITY])

## One lamp direction for every bead of came on the screen, or the lead stops
## agreeing with itself — the single thing separating leaded glass from a drawn
## border.
const LAMP: Vector2 = Vector2(-0.48, -0.88)

const LEAD: Color = Color(0.020, 0.027, 0.055)
const GOLD: Color = Color(0.949, 0.757, 0.306)
const GOLD_DIM: Color = Color(0.612, 0.486, 0.204)
const PARCHMENT: Color = Color(0.910, 0.875, 0.784)
const TEXT: Color = Color(0.843, 0.863, 0.918)
const TEXT_DIM: Color = Color(0.545, 0.576, 0.678)
const BTN_INK: Color = Color(0.102, 0.071, 0.024)
const NIGHT: Color = Color(0.020, 0.027, 0.063)
const CARD_BLUE: Color = Color(0.42, 0.63, 0.86)

static var _fonts: Dictionary = {}
static var _mips: Dictionary = {}

var stage: Control


func _init(target: Control) -> void:
	stage = target


func put(node: Control, r: Rect2) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = r.position
	node.size = r.size
	node.custom_minimum_size = r.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(node)


## A pane of coloured glass held in lead. `came` is the bead width in px; the
## rest of the shader's set-out arrives through `shade`.
func glass(size: Vector2, tint: Color, came: float) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.custom_minimum_size = size
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = GLASS
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("lead", LEAD)
	m.set_shader_parameter("came", came)
	m.set_shader_parameter("lamp", LAMP)
	r.material = m
	return r


## Everything else the shader takes, by name, so a design reads as its own spec
## rather than eleven set_shader_parameter lines.
static func shade(node: ColorRect, opts: Dictionary) -> void:
	var m: ShaderMaterial = node.material as ShaderMaterial
	for key: String in opts:
		m.set_shader_parameter(key, opts[key])


## A parallax plate, dimmed to sit behind a light source rather than in front
## of one — the plates are authored for a LIT combat stage.
func plate(path: String, r: Rect2, dim: Color) -> void:
	var t: Texture2D = mip(path)
	if t == null:
		return
	var tr: TextureRect = TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.modulate = dim
	put(tr, r)


## A pool of light: additive, so it lifts what is under it instead of veiling
## it. The cheap half of a Light2D and all a candidate needs — the expensive
## half (plates going properly dark away from it) wants a CanvasModulate, and
## that belongs to the shipping screen.
func pool(at: Vector2, size: float, tone: Color, strength: float) -> void:
	put(radial_rect(tone, strength),
		Rect2(at.x - size * 0.5, at.y - size * 0.5, size, size))


static func radial_rect(tone: Color, strength: float) -> TextureRect:
	var tr: TextureRect = TextureRect.new()
	tr.texture = radial(tone)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.modulate = Color(1, 1, 1, strength)
	var cm: CanvasItemMaterial = CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	tr.material = cm
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## A soft horizontal band of night, to lose a seam in. A plate laid on a plate
## meets it as a dead straight line clean across the screen; light alone will
## not lose that, but a shadow along the back edge of a floor explains it.
func veil(at_y: float, h: float, w: float) -> void:
	var tr: TextureRect = TextureRect.new()
	tr.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(NIGHT, 0.0), Color(NIGHT, 0.92), Color(NIGHT, 0.0)]),
		PackedFloat32Array([0.0, 0.46, 1.0]), false,
		Vector2(0.5, 0.0), Vector2(0.5, 1.0))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	put(tr, Rect2(0.0, at_y - h * 0.5, w, h))


## A mote leaves the fire yellow-hot and reddens as it cools, so the ramp is not
## one hue but a short walk down from the fire's own — which is why these take a
## hue and not a colour. The offsets are what the hand-picked warm ramp already
## was, measured off it: at the default they reproduce it exactly, and at a cold
## hue the embers go cold with the fire instead of raining orange onto blue.
const MOTE_YOUNG: float = 16.0
const MOTE_PEAK: float = 19.0
const MOTE_OLD: float = -1.0
## Lantern-fire — Duskfang's own, and the hue the warm ramp was picked at.
const LANTERN_HUE: float = 22.0


static func _mote(hue: float, offset: float, sat: float, alpha: float) -> Color:
	return Color(Color.from_hsv(fmod(hue + offset, 360.0) / 360.0, sat, 1.0), alpha)


func embers(at: Vector2, spread: float, hue: float = LANTERN_HUE) -> void:
	var p: GPUParticles2D = GPUParticles2D.new()
	p.amount = 70
	p.lifetime = 3.4
	p.preprocess = 3.4          # already burning when the screen opens
	p.texture = radial(_mote(hue, 15.0, 0.58, 1.0))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(spread, 6.0, 1.0)
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 26.0
	pm.initial_velocity_min = 18.0
	pm.initial_velocity_max = 54.0
	pm.gravity = Vector3(0.0, -22.0, 0.0)
	pm.scale_min = 0.012
	pm.scale_max = 0.045
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, _mote(hue, MOTE_YOUNG, 0.55, 0.0))
	ramp.set_color(1, _mote(hue, MOTE_OLD, 0.84, 0.0))
	ramp.add_point(0.18, _mote(hue, MOTE_PEAK, 0.45, 0.95))
	var ramp_t: GradientTexture1D = GradientTexture1D.new()
	ramp_t.gradient = ramp
	pm.color_ramp = ramp_t
	p.process_material = pm
	var cm: CanvasItemMaterial = CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = cm
	p.position = at
	stage.add_child(p)


static func art(path: String, w: float) -> TextureRect:
	var t: Texture2D = mip(path)
	if t == null:
		return null
	var tr: TextureRect = TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.custom_minimum_size = Vector2(w, w)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## Every candidate stands its text on something painted, so every glyph carries
## its own ground. Without the outline the sub lines die into the forest.
static func text(s: String, path: String, sz: int, col: Color,
		track: int) -> Label:
	var l: Label = Label.new()
	l.text = s
	l.add_theme_font_override("font", font(path, track))
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func font(path: String, tracking: int) -> Font:
	var key: String = path + "#" + str(tracking)
	if _fonts.has(key):
		var hit: Font = _fonts[key]
		return hit
	var fv: FontVariation = FontVariation.new()
	fv.base_font = load(path) as FontFile
	if tracking != 0:
		fv.spacing_glyph = tracking
	_fonts[key] = fv
	return fv


## Art is authored at 512 and drawn here at 42-300. Without a mip chain that is
## a shimmering mess; SKILL §4 forbids hand-editing .import sidecars, so the
## chain is built at load and the sampler asked for it.
static func mip(path: String) -> Texture2D:
	if _mips.has(path):
		var hit: Texture2D = _mips[path]
		return hit
	if not ResourceLoader.exists(path):
		push_warning("reward kit: missing art %s" % path)
		return null
	var src: Texture2D = load(path) as Texture2D
	if src == null:
		return null
	var img: Image = src.get_image()
	img.generate_mipmaps()
	var out: Texture2D = ImageTexture.create_from_image(img)
	_mips[path] = out
	return out


static func radial(tone: Color) -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([tone, Color(tone.r, tone.g, tone.b, 0.0)])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


## A gold seal — the one filled control the painted candidates allow themselves,
## because on a lit stage a flat word does not read as pressable.
func seal(label: String, w: float) -> Control:
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pane: ColorRect = glass(Vector2(w, 46.0), GOLD, 5.0)
	shade(pane, {"radius": 9.0, "lit": 1.7, "ripple": 0.4,
		"glow_at": Vector2(0.5, 0.34), "reach": 0.66, "seed": 21.0})
	pane.position = Vector2.ZERO
	pane.size = Vector2(w, 46.0)
	holder.add_child(pane)
	var l: Label = text(label, GlassStyle.CINZEL_700, 17, BTN_INK, 3)
	l.position = Vector2(0.0, 12.0)
	l.size = Vector2(w, 24.0)
	holder.add_child(l)
	return holder
