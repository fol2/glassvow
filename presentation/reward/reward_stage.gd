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
	# The SPLICED shader, not the raw const: BODY_SHADER's fragment calls
	# eaten() and variant_tint(), which live in the ERODE and TINT snippets its
	# markers stand for. The raw string does not compile, and a shader that
	# does not compile is a white unshaded plate — the husk rendered as a
	# glowing square, which is what "source existing is not rendering" looks
	# like in 3D.
	sh.code = EnemyView.with_tint(EnemyView.with_erode(EnemyView.BODY_SHADER))
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


## Stage 5's instrument seam: the bench reads the engine's own render clocks
## off this viewport, the same way the actor probe reads an actor's.
func get_viewport_rid_for_bench() -> RID:
	var rid: RID = _vp.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	return rid


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


# ---------------------------------------------------------------- the break
#
# Stage 2 of the plan: the body comes apart AT REAL SPEED, brakes HARD, and
# hangs. The deceleration is what reads as time slowing — things merely
# stopping reads as a bug — and nothing ever lands, so nothing can land badly.
# No physics (decision 1): velocities are integrated by hand, which is also
# what makes the same seed the same shot tomorrow.

## The beats (docs/reward-embers-3d-plan.md § timeline). SIT and BLAZE run
## before the burst; COOL belongs to stage 3's material and overlaps the brake.
const SIT: float = 0.18
const BLAZE: float = 0.10
const BURST: float = 0.30
const BRAKE: float = 0.35
## The hold's residual drift: a highlight should walk across a facet over
## SECONDS — about 2°/s of turn and under 2px/s of travel.
const DRIFT_SPIN: float = deg_to_rad(2.0)
const DRIFT_MOVE: float = 2.0 * UNIT
## How hard the body leaves itself. World units per second at the burst's
## edge; the brake eats almost all of it.
const THROW: float = 2.6
const SPIN: float = 4.2
## A reward piece is slightly thinner than a combat shard — it is meant to be
## looked THROUGH at rest, not thrown past the camera.
const PIECE_THICK: float = 0.032

const REST: int = 0
const PH_SIT: int = 1
const PH_BLAZE: int = 2
const PH_FLY: int = 3     # burst + brake + hang, one continuous integration

class Piece extends RefCounted:
	var node: MeshInstance3D
	var vel: Vector3
	var axis: Vector3
	var rate: float          # rad/s, braked toward DRIFT_SPIN
	var drift: Vector3       # the brake's convergence target
	var spoil: int = -1      # 0..2: one of the three chosen pieces
	var area: float = 0.0    # polygon area — mass, for the throw
	var paint: float = 0.0   # PAINTED area — what the player actually sees
	var paint_off: Vector2 = Vector2.ZERO  # alpha-weighted centre − centroid
	var settled: bool = false
	var home: Vector3 = Vector3.ZERO
	var base_q: Quaternion = Quaternion.IDENTITY
	var osc_phase: Vector3 = Vector3.ZERO
	var osc_rate: Vector3 = Vector3.ZERO

const COOL: float = 0.40
## The hang is a BOUNDED oscillation, not a heading. Decision 3 said "not a
## drift that keeps going somewhere", and a constant 2px/s heading violates
## that in the integral — 120px gone after a minute of the player reading
## cards. A slow lissajous about the hold pose keeps the same peak rates
## (amp × rate ≤ 2px/s, tilt × rate ≤ 2°/s) inside a fixed envelope, so a
## highlight still walks across a facet over seconds and nothing ever
## leaves.
const OSC_AMP: float = 5.0 * UNIT
const OSC_TILT: float = 0.10
const OSC_RATE: float = 0.35

## The three spoils are CHOSEN, not promoted: the three largest cells. As
## the brake bites they turn to face the camera — their art and their word
## must read flat — and their cut takes the ITEM'S colour, not the enemy's.
## Lab stand-ins until the screen hands real spoils over.
const SPOIL_TINTS: Array[Color] = [
	Color(0.949, 0.757, 0.306),   # gold — the purse
	Color(0.56, 0.82, 1.0),       # glass-blue — the card
	Color(1.0, 0.60, 0.30),       # ember — the relic
]
const SPOIL_WORDS: Array[String] = ["GOLD", "CARD", "RELIC"]

var _phase: int = REST
var _t: float = 0.0
var _pieces: Array[Piece] = []
var _words: Array[Label] = []
## Stage 3's own material — the cut cools INTO the item's colour.
const SHARD_SHADER_RES: Shader = preload("res://presentation/reward/reward_shard.gdshader")


## Begin the rite from the whole body. Replayable: the lab judges a break by
## watching it more than once, and the same seed breaks the same way.
func shatter() -> void:
	_clear_pieces()
	# The previous run's words go with its pieces — 0.28s of GOLD floating
	# over a visibly whole body was every replay's first frame.
	for word: Label in _words:
		if is_instance_valid(word):
			word.queue_free()
	_words.clear()
	if _husk != null:
		_husk.visible = true
	if _body != null:
		_body.set_shader_parameter("emission_gain", HUSK_EMISSION)
	set_heat(1.0)
	_phase = PH_SIT
	_t = 0.0
	set_process(true)


func _clear_pieces() -> void:
	for piece: Piece in _pieces:
		if is_instance_valid(piece.node):
			piece.node.queue_free()
	_pieces.clear()


func _process(delta: float) -> void:
	if _phase == REST:
		return
	_t += delta
	match _phase:
		PH_SIT:
			if _t >= SIT:
				_phase = PH_BLAZE
				_t = 0.0
		PH_BLAZE:
			# The cracks take light from inside while it is still one piece:
			# the dead lantern glows once more, from 0.06 up toward a living
			# body's neighbourhood.
			if _body != null:
				_body.set_shader_parameter("emission_gain",
					lerpf(HUSK_EMISSION, 0.85, clampf(_t / BLAZE, 0.0, 1.0)))
			if _t >= BLAZE:
				_burst()
				_phase = PH_FLY
				_t = 0.0
		PH_FLY:
			# One integration for burst, brake and hang. The damp is the
			# BRAKE: full speed until BURST ends, then a hard exponential
			# bite; once the bite has done its work each piece banks its hold
			# pose and the hang becomes a bounded sway about it.
			var braking: bool = _t > BURST
			var held: bool = _t > BURST + BRAKE
			var cool: float = clampf((_t - BURST) / COOL, 0.0, 1.0)
			for piece: Piece in _pieces:
				var mat: ShaderMaterial = \
					piece.node.get_surface_override_material(0) as ShaderMaterial
				if mat != null:
					mat.set_shader_parameter("cool", cool)
				if held and not piece.settled:
					piece.settled = true
					piece.home = piece.node.position
					piece.base_q = piece.node.quaternion
				if piece.settled:
					if piece.spoil >= 0:
						continue  # faced and parked: the announcements hold still
					piece.node.position = piece.home + Vector3(
						sin(_t * piece.osc_rate.x + piece.osc_phase.x),
						sin(_t * piece.osc_rate.y + piece.osc_phase.y),
						sin(_t * piece.osc_rate.z + piece.osc_phase.z) * 0.4) * OSC_AMP
					piece.node.quaternion = piece.base_q * Quaternion(
						piece.axis,
						OSC_TILT * sin(_t * piece.osc_rate.x * 0.7 + piece.osc_phase.y))
					continue
				if braking:
					var bite: float = pow(0.004, delta / BRAKE)
					piece.vel = piece.vel * bite + piece.drift * (1.0 - bite)
					piece.rate = maxf(piece.rate * bite, DRIFT_SPIN)
				piece.node.position += piece.vel * delta
				if piece.spoil >= 0 and braking:
					# A spoil turns to the room's REST-FACING as it brakes —
					# the camera's home axis; look_from() parallax may tilt
					# the whole room and the spoils ride with it, which keeps
					# them IN the room rather than pasted over it. And it
					# BRAKES INTO ITS SEAT: the three most-painted cells are
					# body-core cells, thrown from the same blow — left to
					# the damp alone they bunch over the fire, three words in
					# one spot. The seats hang mid-air (nothing lands), the
					# 2D concept's own arrangement carried into the room.
					var q_now: Quaternion = piece.node.quaternion
					piece.node.quaternion = q_now.slerp(
						Quaternion.IDENTITY, 1.0 - pow(0.002, delta / BRAKE))
					piece.node.position = piece.node.position.lerp(
						_spoil_seat(piece.spoil), 1.0 - pow(0.02, delta / BRAKE))
				else:
					piece.node.rotate(piece.axis, piece.rate * delta)
			_seat_words()


## The body comes apart: the husk hides in the same frame its pieces appear,
## each cell extruded about its own centroid and thrown out from the blow.
func _burst() -> void:
	if _husk == null:
		return
	var aspect: float = 1.0
	var quad: QuadMesh = _husk.mesh as QuadMesh
	if quad != null and quad.size.y > 0.0:
		aspect = quad.size.x / quad.size.y
	var box: Vector2 = Vector2(_box_u * aspect, _box_u)
	var rng: Rng = Rng.new(RewardFracture.stable_seed(enemy_id))
	# The blow lands OFF-centre — a perfectly central blow makes a perfectly
	# radial field, and B1's wreath comes back wearing 3D.
	var blow: Vector2 = Vector2(
		(rng.next() - 0.5) * box.x * 0.22, -_box_u * 0.10)
	var cells: Array[PackedVector2Array] = RewardFracture.voronoi(
		RewardFracture.burst_sites(blow, box, rng), box)
	var tex: Texture2D = _art()
	var img: Image = tex.get_image() if tex != null else null
	if img != null and img.is_compressed():
		img.decompress()
	var home: Vector3 = _husk.position
	for cell: PackedVector2Array in cells:
		var centre: Vector2 = Vector2.ZERO
		for p: Vector2 in cell:
			centre += p
		centre /= float(cell.size())
		var mesh: ArrayMesh = RewardFracture.prism(
			cell, _box_u * PIECE_THICK, box, centre)
		if mesh == null:
			continue
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = SHARD_SHADER_RES
		mat.set_shader_parameter("body_tex", tex)
		mat.set_shader_parameter("cool", 0.0)
		# The enemy's own hue until stage 4 seats the spoils — then the three
		# chosen pieces take their ITEM'S colour and the debris keeps this.
		var glass: Color = tone(0.72, 0.95)
		mat.set_shader_parameter("cool_tint", Vector3(glass.r, glass.g, glass.b))
		var node: MeshInstance3D = MeshInstance3D.new()
		node.mesh = mesh
		node.set_surface_override_material(0, mat)
		# Cells are husk-space (y down in canvas sense); the husk quad maps
		# art the same way, so a piece stands exactly over the pixels it
		# carries — flip y into world, as at() does.
		node.position = home + Vector3(centre.x, -centre.y, 0.0)
		_room.add_child(node)
		var piece: Piece = Piece.new()
		piece.node = node
		var out: Vector2 = (centre - blow)
		var radial: Vector2 = out.normalized() if out.length() > 0.001 \
			else Vector2(0.0, 1.0)
		# Not strictly radial: a tangent shove of up to ±0.9 lets fragments
		# CROSS the middle, so the hold has no hole where the creature was —
		# a strictly radial field is B1's wreath, structural this time.
		var tangent: Vector2 = Vector2(-radial.y, radial.x) \
			* (rng.next() - 0.5) * 1.8
		var swung: Vector2 = (radial + tangent).normalized()
		var dir: Vector3 = Vector3(swung.x, -swung.y, 0.0)
		# A shove toward the camera as well as outward — the spread must
		# read in depth, or it is a drawing again.
		dir = (dir + Vector3(0, 0, 0.55 + rng.next() * 0.5)).normalized()
		var area: float = 0.0
		for k: int in range(cell.size()):
			var p2: Vector2 = cell[k]
			var q2: Vector2 = cell[(k + 1) % cell.size()]
			area += p2.x * q2.y - q2.x * p2.y
		piece.area = absf(area) * 0.5
		# Mass matters: the heaviest fragments leave slower than the chips.
		var heft: float = clampf(
			1.18 - piece.area / (box.x * box.y) * 4.0, 0.6, 1.18)
		piece.vel = dir * THROW * (0.55 + 0.65 * rng.next()) * heft
		piece.axis = Vector3(
			rng.next() - 0.5, rng.next() - 0.5, rng.next() - 0.5).normalized()
		piece.rate = SPIN * (0.4 + 0.9 * rng.next())
		piece.drift = Vector3(
			rng.next() - 0.5, rng.next() - 0.5, (rng.next() - 0.5) * 0.4
		).normalized() * DRIFT_MOVE * (0.4 + 0.6 * rng.next())
		piece.osc_phase = Vector3(rng.next(), rng.next(), rng.next()) * TAU
		piece.osc_rate = Vector3(
			OSC_RATE * (0.7 + 0.6 * rng.next()),
			OSC_RATE * (0.7 + 0.6 * rng.next()),
			OSC_RATE * (0.7 + 0.6 * rng.next()))
		# What the player SEES of a cell is its painted subset — a huge cell
		# over an empty corner of the art box is debris, whatever its
		# polygon area says. Sampled against the art's alpha; the weighted
		# centre also seats the word on the paint, not on the geometry.
		_measure_paint(piece, cell, centre, box, img)
		_pieces.append(piece)
	_husk.visible = false
	_choose_spoils()


## Where a spoil hangs: an ARC over the wreckage — the middle seat higher
## and nearer, the flanks lower and deeper — spread wide enough that three
## words never touch. A straight, evenly spaced, constant-depth row is a
## shelf of tokens: retired complaint A2, back wearing 3D. Mid-air by
## construction — decision 3's "nothing lands" holds because there is
## nothing to land on.
func _spoil_seat(i: int) -> Vector3:
	var lift: float = 0.42 if i == 1 else 0.30
	var depth: float = 0.55 if i == 1 else 0.32
	var seat_px: Vector2 = HUSK_AT + Vector2(
		(float(i) - 1.0) * _box_px * 0.85, -_box_px * lift)
	return at(seat_px, _box_u * depth)


## Alpha coverage of a cell, and where that coverage sits. A 12×12 grid over
## the cell's bounds — fine enough to rank sixteen cells, cheap enough to
## run at the burst frame.
func _measure_paint(piece: Piece, cell: PackedVector2Array, centre: Vector2,
		box: Vector2, img: Image) -> void:
	if img == null:
		piece.paint = piece.area
		return
	var lo: Vector2 = cell[0]
	var hi: Vector2 = cell[0]
	for p: Vector2 in cell:
		lo = lo.min(p)
		hi = hi.max(p)
	var span: Vector2 = hi - lo
	var hits: int = 0
	var weighted: Vector2 = Vector2.ZERO
	var w: int = img.get_width()
	var h: int = img.get_height()
	for iy: int in range(12):
		for ix: int in range(12):
			var at: Vector2 = lo + Vector2(
				span.x * (float(ix) + 0.5) / 12.0,
				span.y * (float(iy) + 0.5) / 12.0)
			if not Geometry2D.is_point_in_polygon(at, cell):
				continue
			var u: float = at.x / box.x + 0.5
			var v: float = 0.5 - at.y / box.y
			if u < 0.0 or u >= 1.0 or v < 0.0 or v >= 1.0:
				continue
			var px: Color = img.get_pixel(int(u * float(w)), int(v * float(h)))
			if px.a > 0.3:
				hits += 1
				weighted += at
	var sample_area: float = span.x * span.y / 144.0
	piece.paint = float(hits) * sample_area
	if hits > 0:
		piece.paint_off = weighted / float(hits) - centre


## The three spoils are the three pieces carrying the most PAINT — chosen,
## not promoted, and chosen by what the player sees rather than by polygon
## area: the first cut promoted a sliver whose word was wider than the
## fragment it named. Their cut takes the item's colour, and louder than
## the debris keeps the enemy's — the tint gain is what separates a prize
## from a shard once the cream specular lands on both.
func _choose_spoils() -> void:
	var by_paint: Array[Piece] = _pieces.duplicate()
	by_paint.sort_custom(func(a: Piece, b: Piece) -> bool: return a.paint > b.paint)
	for i: int in range(mini(3, by_paint.size())):
		var piece: Piece = by_paint[i]
		piece.spoil = i
		var mat: ShaderMaterial = \
			piece.node.get_surface_override_material(0) as ShaderMaterial
		if mat != null:
			var tint: Color = SPOIL_TINTS[i]
			mat.set_shader_parameter("cool_tint", Vector3(tint.r, tint.g, tint.b))
			mat.set_shader_parameter("tint_gain", 2.4)
	for word: Label in _words:
		if is_instance_valid(word):
			word.queue_free()
	_words.clear()
	for i: int in range(mini(3, by_paint.size())):
		var word: Label = Label.new()
		word.text = SPOIL_WORDS[i]
		word.add_theme_font_size_override("font_size", 13)
		word.add_theme_color_override("font_color", SPOIL_TINTS[i])
		word.add_theme_font_override("font",
			GlassStyle.face(GlassStyle.CINZEL_700))
		word.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		word.add_theme_constant_override("shadow_offset_y", 2)
		word.modulate.a = 0.0
		word.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(word)
		_words.append(word)


## The words stand under their pieces, in screen pixels, faded in with the
## cool — announcements belong to the HOLD, not to the explosion.
func _seat_words() -> void:
	if _words.is_empty():
		return
	var fade: float = clampf((_t - BURST) / COOL, 0.0, 1.0)
	var view_scale: Vector2 = size / Vector2(_vp.size)
	for piece: Piece in _pieces:
		if piece.spoil < 0 or piece.spoil >= _words.size():
			continue
		var word: Label = _words[piece.spoil]
		if not is_instance_valid(word):
			continue
		# Anchored on the PAINT's centre, not the polygon's — the word names
		# the visible fragment. view_scale converts viewport px to control
		# px; the drop below the piece is already in canvas px and takes no
		# second scaling (that double-scale was a 0.667x error waiting for
		# the OVERSAMPLE knob to expose it).
		var at_screen: Vector2 = _cam.unproject_position(
			piece.node.global_position
			+ Vector3(piece.paint_off.x, -piece.paint_off.y, 0.0)) * view_scale
		# The drop clears the PIECE, not the husk box: selection guarantees
		# the labelled fragments are the largest painted ones, so a
		# husk-keyed drop parked GOLD's word inside its own piece.
		var piece_px: float = sqrt(maxf(piece.paint, 0.0001)) / UNIT
		word.position = at_screen + Vector2(
			-word.size.x * 0.5, piece_px * 0.55 + 10.0)
		word.modulate.a = fade


func rest() -> void:
	_turn = Vector2.ZERO
	if _room != null:
		_room.rotation_degrees = Vector3.ZERO
