class_name RewardStage
extends Control
## THE ROOM the reward happens in — one transparent 3D stage behind the whole
## screen, with the husk standing in it and the 2D chrome laid over the top.
##
## WHY A ROOM AND NOT A DRAWING. Every complaint left on the embers concept was
## the same complaint wearing different hats: fracture rims that read as fat
## lines, seat slabs that read as coloured tokens, twelve identical wedges that
## read as a decoration. A flat drawing cannot be a material — it has no view
## vector, so it can only ever describe light rather than take any. The card lane
## reached this conclusion first and the enemy lane second; this is the third
## time and the argument has not changed.
##
## ONE STAGE, NOT ONE PER PIECE. `docs/actor-stage-frame-budget.md` measured an
## actor's private stage at roughly 113 MB of video memory, which a four-actor
## fight pays four times. The wreckage here is a dozen-odd pieces and they all
## stand in the same room, so the screen pays once. The knobs that price it are
## OVERSAMPLE and MSAA, both here, both deliberately conservative until the
## measurement in stage 5 of `docs/reward-embers-3d-plan.md` says otherwise.
##
## THE SCREEN'S OWN COORDINATES STILL WORK. The layout language of this concept
## is pixels from the centre of the canvas — where the bed is, where a seat sits,
## where the rack stands. Rather than restate all of that in metres, the camera
## is placed so that the canvas height maps exactly onto the frame, and `at()`
## converts. A constant that was true in the 2D build is still true here.
##
## THE LAMP IS NOT OURS TO MOVE. Key light colour, energy and angle are quoted
## from `EnemyView` so the husk is lit by the same lamp the rest of the game is
## lit by — an object that disagrees with the room about where the light comes
## from is the one thing guaranteed to read as pasted on. The fire is an ADDED
## light, in the dead enemy's own hue, not a replacement for the lamp.
##
## WHAT IS BORROWED, AND KNOWINGLY. `EnemyView.BODY_SHADER` paints the husk. It
## is another lane's file and this lane may not edit it — but a public const is a
## dependency rather than an edit, and tracking it is the CORRECT behaviour here:
## the husk is supposed to be that creature, so when the creature's body changes,
## the husk should change with it. If it ever needs to diverge, copy it then and
## say why. Registered in the cross-lane queue of the plan.

## One px of art box is 0.01 world units, so the whole game measures distance the
## same way and a 327px creature stands 3.27 units tall.
const UNIT: float = EnemyView.UNIT
## A long lens. The same one the cards and the actors use: it keeps perspective
## honest without the wide-angle distortion that would make a piece near the edge
## of the screen look like a different material from one in the middle.
const FOV_DEG: float = EnemyView.FOV_DEG
const VP_MAX: int = EnemyView.VP_MAX
## Render above the canvas and let the sampler resolve it back down. 1.5 is the
## conservative end; the plan prices this against MSAA before either is raised.
const OVERSAMPLE: float = 1.5
const MSAA: Viewport.MSAA = Viewport.MSAA_2X

## The husk stands where it fell, which is also where the fire is. Kept in the
## screen's own pixels-from-centre, as everything in this concept is.
const HUSK_AT: Vector2 = Vector2(0.0, -46.0)
## The fire is TWO things and needs to be, because they do different jobs. The
## OmniLight3D models the wreckage — it is what makes a piece near the bed hot
## and a piece thrown clear nearly cold, and it cannot be faked. But a light that
## only models is invisible: it lights other things and is nowhere itself, which
## is how the first pass of this stage came out as a creature hanging in a void.
## So the same fire also gets a bloom, in 2D, additive, and UNDER the render —
## because a 2D layer knows nothing about occlusion, and laid over the top it
## painted its hot core straight through the creature's chest. Behind, the husk
## blocks it, which is the entire behaviour that makes a light read as being
## somewhere rather than everywhere.
##
## Sized off the husk rather than the canvas: a fire that is the same width for a
## 185px slime and a 280px boss belongs to the screen, not to the thing that fell
## in it.
const BED_W: float = 2.6      # × the husk's height
const BED_H: float = 0.58
## Where the fire is, below the husk's own centre — at its feet. Parked at the
## centre it lights the body frontally and flatly, and the bloom sits behind the
## torso where the silhouette is widest and least interesting.
const BED_DROP: float = 0.48
## The lantern is out. A living body in this world emits through its bright panes
## — that is what makes the creature read as a vessel with something burning in
## it — and the whole premise here is that the burning has stopped. Not zero: an
## utterly dead body is a silhouette, and the fire below still has to find
## something to catch.
const HUSK_EMISSION: float = 0.06

## How far the cursor may turn the husk, in degrees, when the lab asks for it.
## Judging whether a thing is solid means seeing it from more than one angle, and
## nothing else on this screen will move during stage 1.
const TURN: Vector2 = Vector2(26.0, 15.0)

const FIRE_ENERGY: float = 3.2

var hue: float = 22.0
var enemy_id: String = "duskfang"
## How hard the fire is burning, 0..1. One number for both halves of it, so the
## light and the bloom can never disagree about how big the fire is. Stage 1
## holds it at full; the break will drive it.
var heat: float = 1.0

var _vp: SubViewport = null
var _display: TextureRect = null
var _cam: Camera3D = null
var _key: DirectionalLight3D = null
var _rim: OmniLight3D = null
var _fire: OmniLight3D = null
var _room: Node3D = null          # everything that is not a light or the camera
var _husk: MeshInstance3D = null
var _body: ShaderMaterial = null
var _box_px: float = 185.0        # the husk's height, in canvas pixels
var _box_u: float = 0.0           # ...and in world units
var _turn: Vector2 = Vector2.ZERO
var _bloom: Control = null
var _bed_tex: Array[GradientTexture2D] = []


func _init(dead_id: String = "duskfang", enemy_hue: float = 22.0) -> void:
	enemy_id = dead_id
	hue = enemy_hue
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_vp = SubViewport.new()
	_vp.own_world_3d = true          # this room is nobody else's
	_vp.transparent_bg = true        # the night ground and the bloom show through
	_vp.msaa_3d = MSAA
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

	_build_room()
	_build_lights()

	_cam = Camera3D.new()
	_cam.fov = FOV_DEG
	_vp.add_child(_cam)

	# Behind the render. Three nested falloffs rather than one, so the fire has a
	# hot core and a long cool throw — a bank of embers, not a lamp. Built once:
	# rebuilt per redraw this would allocate three textures every frame of the
	# burst.
	_bed_tex = [
		RewardKit.radial(tone(0.80, 0.42)),
		RewardKit.radial(tone(0.62, 0.78)),
		RewardKit.radial(tone(0.34, 1.00)),
	]
	_bloom = Control.new()
	_bloom.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bloom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add: CanvasItemMaterial = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_bloom.material = add
	_bloom.draw.connect(_draw_bloom)
	add_child(_bloom)

	_display = TextureRect.new()
	_display.texture = _vp.get_texture()
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_display)


func _ready() -> void:
	_fit()
	resized.connect(_fit)


# ---------------------------------------------------------------- the room

## A real sky, used ONLY as light: the background stays CLEAR_COLOR so the
## viewport keeps its alpha, while ambient and reflections still come off the
## sky's radiance map — which is what gives glass something to mirror. Quoted
## from EnemyView, including the tonemap: LINEAR and never ACES, because the
## filmic curve lifts blacks and desaturates, and on art that is already mostly
## near-black that reads as fog laid over the whole screen.
##
## The ground half of the dome is the one thing here that follows the hue. It is
## the fire's bounce, and a cold fire that still bounces warm off the floor is
## the giveaway that the colour is a tint rather than a light.
func _build_room() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = 0.22
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.05, 0.07, 0.16)
	sky_mat.sky_horizon_color = Color(0.16, 0.18, 0.30)
	sky_mat.ground_bottom_color = tone(0.72, 0.16)
	sky_mat.ground_horizon_color = tone(0.62, 0.22)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	_vp.add_child(world_env)

	_room = Node3D.new()
	_vp.add_child(_room)
	_build_husk()


## Three lights, and only the last one belongs to this screen.
func _build_lights() -> void:
	# THE GENERIC LAMP. Colour, energy and angle are EnemyView's, unchanged and
	# not negotiable: every lit object in this game is lit from here.
	_key = DirectionalLight3D.new()
	_key.light_color = Color(1.0, 0.86, 0.68)
	_key.light_energy = 1.5
	_key.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	_vp.add_child(_key)
	# Cold from behind, so a dark body still has an edge against a dark screen.
	_rim = OmniLight3D.new()
	_rim.light_color = GlassStyle.GLASS
	_rim.light_energy = 1.6
	_vp.add_child(_rim)
	# THE FIRE. The concept's one float, doing its work as an actual light rather
	# than as a colour multiplied into a drawing. It is an ADDITION to the lamp,
	# not the only light in the scene — an earlier draft of this concept claimed
	# otherwise and was wrong.
	_fire = OmniLight3D.new()
	_fire.light_color = tone(0.62, 1.0)
	_fire.light_energy = FIRE_ENERGY
	_vp.add_child(_fire)


## The husk: the creature's own painting, standing at its own size, extinguished.
## Not a reproduction of its silhouette — the size formula, the art and the
## material are the ones the actor uses, so this IS the thing that just died.
func _build_husk() -> void:
	var tex: Texture2D = _art()
	if tex == null:
		return
	var box: float = EnemyView.art_box(StringName(enemy_id))
	if box > 0.0:          # no metadata: keep the benchmark's default normal tier
		_box_px = box
	_box_u = _box_px * UNIT
	var aspect: float = 1.0
	if tex.get_height() > 0:
		aspect = float(tex.get_width()) / float(tex.get_height())

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(_box_u * aspect, _box_u)
	_husk = MeshInstance3D.new()
	_husk.mesh = quad
	var sh: Shader = Shader.new()
	sh.code = EnemyView.BODY_SHADER
	_body = ShaderMaterial.new()
	_body.shader = sh
	_body.set_shader_parameter("body_tex", tex)
	_body.set_shader_parameter("emission_gain", HUSK_EMISSION)
	_husk.set_surface_override_material(0, _body)
	_room.add_child(_husk)


func _art() -> Texture2D:
	for pattern: String in EnemyView.ART_DIRS:
		var path: String = pattern % enemy_id
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	push_warning("reward stage: no art for %s" % enemy_id)
	return null


# ---------------------------------------------------------------- the fit

## Size the render target and place the camera so that the canvas maps onto the
## frame one for one. Everything downstream of this — the bed, the seats, the
## rack — can then keep speaking in pixels from the centre.
func _fit() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_vp.size = Vector2i(
		mini(int(size.x * OVERSAMPLE), VP_MAX),
		mini(int(size.y * OVERSAMPLE), VP_MAX))
	var dist: float = size.y * UNIT * 0.5 / tan(deg_to_rad(FOV_DEG * 0.5))
	_cam.position = Vector3(0.0, 0.0, dist)
	_cam.near = dist * 0.25
	_cam.far = dist * 3.0
	if _husk != null:
		_husk.position = at(HUSK_AT)
	var reach: float = maxf(_box_u, size.y * UNIT)
	_rim.omni_range = reach * 2.6
	_rim.position = at(HUSK_AT) + Vector3(_box_u * 0.7, _box_u * 0.5, -_box_u * 0.9)
	# Far enough to reach where the rack will stand. The cards themselves are 2D
	# Controls over the top of this stage and no 3D light can touch them, so the
	# warm wash the decision asked for is drawn in 2D by the screen — this range
	# is what the WRECKAGE down there will be lit by.
	_fire.omni_range = reach * 2.0
	# In front as well as below, so it rakes UP the body. A light dead level with
	# a flat plate lights it evenly, which is the one thing a fire never does.
	_fire.position = at(bed_px(), _box_u * 0.25)
	if _bloom != null:
		_bloom.queue_redraw()


## Both halves of the fire off one number.
func set_heat(v: float) -> void:
	heat = clampf(v, 0.0, 1.0)
	if _fire != null:
		_fire.light_energy = FIRE_ENERGY * heat
	if _bloom != null:
		_bloom.queue_redraw()


## Where the fire is, in canvas pixels from the centre. One answer, used by the
## light and by the bloom.
func bed_px() -> Vector2:
	return HUSK_AT + Vector2(0.0, _box_px * BED_DROP)


func _draw_bloom() -> void:
	var seat: Vector2 = size * 0.5 + bed_px()
	var w: float = _box_px * BED_W
	var h: float = _box_px * BED_H
	_bloom.draw_texture_rect(_bed_tex[0], _band(seat, w, h),
		false, Color(1, 1, 1, 0.78 * heat))
	_bloom.draw_texture_rect(_bed_tex[1], _band(seat, w * 0.46, h * 0.52),
		false, Color(1, 1, 1, 0.70 * heat))
	_bloom.draw_texture_rect(_bed_tex[2], _band(seat, w * 0.17, h * 0.20),
		false, Color(1, 1, 1, 0.88 * heat))


static func _band(at_px: Vector2, w: float, h: float) -> Rect2:
	return Rect2(at_px - Vector2(w, h) * 0.5, Vector2(w, h))


## Screen pixels from the centre of the canvas, into the room. `depth` pushes a
## thing toward the camera, which is positive z.
func at(px: Vector2, depth: float = 0.0) -> Vector3:
	return Vector3(px.x * UNIT, -px.y * UNIT, depth)


func tone(sat: float, val: float) -> Color:
	return Color.from_hsv(fmod(hue, 360.0) / 360.0, sat, val)


# ---------------------------------------------------------------- judging it

## Turn the husk under the cursor. Stage 1 only asks one question — does this
## read as a solid object standing in a lit room — and that question cannot be
## answered from a still, for exactly the reason the card lane's surfaces cannot:
## a material is a function of angle, so it says nothing until the angle moves.
func look_from(pointer: Vector2) -> void:
	if _room == null or size.x <= 0.0:
		return
	var u: Vector2 = (pointer / size - Vector2(0.5, 0.5)) * 2.0
	_turn = Vector2(clampf(u.x, -1.0, 1.0), clampf(u.y, -1.0, 1.0))
	_room.rotation_degrees = Vector3(_turn.y * TURN.y, _turn.x * TURN.x, 0.0)


func rest() -> void:
	_turn = Vector2.ZERO
	if _room != null:
		_room.rotation_degrees = Vector3.ZERO
