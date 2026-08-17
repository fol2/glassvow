class_name TitleWorld
extends Control
## Title and run-screen backdrop: a horizontal pilgrimage road receding to
## the sealed door. Camera, fog, nebulae, cloud deck, forest, near shards
## and chains, ash weather and both point fields are the same projected
## volume they were; the lathed tower, its sister, and the 120 window lights
## are gone. Pointer parallax is still the camera moving through that volume.
##
## Not a Node3D scene on purpose: the title eye is fixed, every element reads
## as silhouette + additive sprite + fog, and `_draw` reproduces that without
## a SubViewport, an environment, or a second renderer to budget.
##
## Occlusion is by paint order, not depth buffer: sky → nebulae → clouds →
## ground disc → road and door ink → forest → near shards and chains, with the
## additive child (lantern flames, motes, weather) above. The door is the
## tower's subject, not its slot: the ground disc is a full-frame fill below
## the horizon, so a silhouette painted before it is eaten except for the
## arch that pokes into the sky (and then reads as a spire). Forest still
## closes the frame because trees paint after the door.
##
## One fixed resting composition (act-0 dusk: amber key, ash weather). Per-act
## tinting of this backdrop is a separate decision; the map's light arc stays
## on the map.

## Camera (scene3d.js:117, :417-418): FOV 58, ambient eye at the act-0 base
## altitude, looking at (0, alt, -6); pointer sways ±0.9 x / ±0.55 y; two slow
## sines breathe the height and the dolly.
const FOV_DEG: float = 58.0
const ALT: float = -6.0
const CAM_CHASE: float = 2.2
const SWAY: Vector2 = Vector2(0.9, 0.55)
const BREATH_Y: float = 0.25
const BREATH_Y_RATE: float = 0.22
const BREATH_Z: float = 0.3
const BREATH_Z_RATE: float = 0.1
const ROLL: float = 0.012
const ROLL_RATE: float = 0.13
## `FogExp2(fog, 0.055)` — factor `1 - exp(-(d·depth)²)`; the door stays ink.
const FOG_DENSITY: float = 0.055
## Theme at the title: the resting `cur` colours (scene3d.js:17). The mesh
## tints are the runtime writes in `frame()` (scene3d.js:345-348), not the
## constructor colours — the loop overwrites those every frame.
const SKY: Color = Color("#0b0e1a")
const FOG: Color = Color("#141a2e")
const MAIN: Color = Color("#ffa04d")
const ACCENT: Color = Color("#66ff9e")
const DOOR_INK: Color = Color("#04050b")
const DOOR_PANEL: Color = Color("#07080f")
const SHARD: Color = Color("#04090a")
const GROUND_Y: float = -9.6
## Vanishing axis: east along −Z, door on the look. Clouds re-anchor here.
const ROAD_X: float = 0.0
const DOOR_Z: float = -20.0
const ROAD_HALF: float = 2.8
const ROAD_NEAR_Z: float = 5.5
const DOOR_HALF: float = 7.2
const DOOR_H: float = 15.0
const DOOR_SPRING: float = 0.55
const DOOR_ARCH_SEGS: int = 16
const LANTERN_PAIRS: int = 8
## Nebulae (scene3d.js:127-139): 7 additive sprites, opacity .1-.2, tinted
## `fog.lerp(particles, 0.5)` every frame (scene3d.js:344) — warm dust, not
## white.
const NEBULA_COUNT: int = 7
## Trees (scene3d.js:194-208): 52 cones on the ground disc at -9.6.
const TREE_COUNT: int = 52
## One cloud deck (scene3d.js:211-215); re-seated on the door's vanishing
## axis so it reads as a horizon sea rather than an act-gap ring.
const CLOUD_DECK_Y: float = 2.4
const CLOUD_COUNT: int = 16
## The point fields (scene3d.js:120-121): `makePoints(900, 0.16, …, 0.75)`
## main embers and `makePoints(240, 0.32, …, 0.5)` accent glow, both
## size-attenuated world sprites in a ±23 × ±13 × ±20 box around the eye.
const MAIN_COUNT: int = 900
const MAIN_SIZE: float = 0.16
const MAIN_ALPHA: float = 0.75
const ACCENT_COUNT: int = 240
const ACCENT_SIZE: float = 0.32
const ACCENT_ALPHA: float = 0.42
## Ash weather at the title (`setWeather('ash')` on act-0 themes):
## `makePoints(300, 0.13, …, 0.5)`, pale ash `particles.lerp(white, .55)`
## (scene3d.js:371-373).
const WEATHER_COUNT: int = 300
const WEATHER_SIZE: float = 0.13
const WEATHER_ALPHA: float = 0.5
## Field box (`makePoints` W/H/D): x wraps at ±23, y at eye ±14, z spread ±20.
const FIELD_X: float = 23.0
const FIELD_Y: float = 14.0
const FIELD_Z: float = 20.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time: float = 0.0
var _drift: PointerDrift = PointerDrift.new()
var _cam: Vector3 = Vector3(0.0, ALT + 3.1, 10.0)
var _look: Vector3 = Vector3(0.0, ALT, -6.0)
var _fwd: Vector3 = Vector3.FORWARD
var _right: Vector3 = Vector3.RIGHT
var _up: Vector3 = Vector3.UP
var _roll: float = 0.0
var _focal: float = 1.0

var _nebulae: Array[Vector3] = []
var _nebula_scale: PackedFloat32Array = PackedFloat32Array()
var _nebula_alpha: PackedFloat32Array = PackedFloat32Array()
var _nebula_wob: PackedFloat32Array = PackedFloat32Array()
var _trees: Array[Vector3] = []      # x, z, height
var _tree_w: PackedFloat32Array = PackedFloat32Array()
var _clouds: Array[Vector3] = []
var _cloud_scale: PackedFloat32Array = PackedFloat32Array()
var _main: Array[Vector4] = []      # world x, y, z + seed
var _accent: Array[Vector4] = []
var _weather: Array[Vector4] = []
var _lanterns: Array[Vector3] = []  # flame world pos
var _door_world: Array[Vector3] = []
var _inner_world: Array[Vector3] = []
var _rose_world: Array[Vector3] = []
var _thresh_world: Array[Vector3] = []
var _road_world: Array[Vector3] = []
var _line_world: Array[Vector3] = []
var _door_scr: PackedVector2Array = PackedVector2Array()
var _inner_scr: PackedVector2Array = PackedVector2Array()
var _rose_scr: PackedVector2Array = PackedVector2Array()
var _thresh_scr: PackedVector2Array = PackedVector2Array()
var _road_scr: PackedVector2Array = PackedVector2Array()
var _line_scr: PackedVector2Array = PackedVector2Array()
var _road_col: PackedColorArray = PackedColorArray()
var _field: Control


class Field:
	extends Control
	var src: TitleWorld

	func _draw() -> void:
		if src != null:
			src.paint_field(self)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 0x51CE
	_seed_world()
	_field = Field.new()
	_field.src = self
	_field.set_anchors_preset(Control.PRESET_FULL_RECT)
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_field.material = mat
	add_child(_field)


func _ready() -> void:
	_step_camera(0.0)


## World geometry, seeded once in a fixed order so two boots agree.
func _seed_world() -> void:
	for i: int in range(NEBULA_COUNT):
		_nebulae.append(Vector3((_rng.randf() - 0.5) * 40.0,
			(_rng.randf() - 0.5) * 18.0 - 3.0, -12.0 - _rng.randf() * 22.0))
		_nebula_scale.append(14.0 + _rng.randf() * 22.0)
		_nebula_alpha.append(0.1 + _rng.randf() * 0.1)
		_nebula_wob.append(_rng.randf() * TAU)
	for i: int in range(TREE_COUNT):
		var a: float = 0.0
		var d: float = 0.0
		var z: float = 5.0
		# The source's rejection loop, draws and all — never behind the camera.
		while z > 4.0:
			a = _rng.randf() * TAU
			d = 7.0 + _rng.randf() * 28.0
			z = sin(a) * d - 8.0
		var h: float = 2.0 + _rng.randf() * 3.4
		var sx: float = 0.5 + _rng.randf() * 0.9
		_trees.append(Vector3(cos(a) * d, z, h))
		_tree_w.append(sx)
		_rng.randf()  # the unused z-scale draw, kept so the stream lines up
	# `sc = 10 + r*14`, ring `d = 5 + r*22`, and the rejection that keeps the
	# deck BEHIND the play space (`z <= -7`) — without it a near cloud fills
	# the sky and its soft rim reads as a pale wall (scene3d.js:216-227).
	for i: int in range(CLOUD_COUNT):
		var ca: float = 0.0
		var cd: float = 0.0
		var cz: float = 0.0
		while true:
			ca = _rng.randf() * TAU
			cd = 5.0 + _rng.randf() * 22.0
			cz = DOOR_Z + sin(ca) * cd
			if cz <= -7.0:
				break
		_clouds.append(Vector3(ROAD_X + cos(ca) * cd,
			CLOUD_DECK_Y + (_rng.randf() - 0.5) * 1.6, cz))
		_cloud_scale.append(10.0 + _rng.randf() * 14.0)
	_seed_road_and_door()
	for _i: int in range(MAIN_COUNT):
		_main.append(_field_mote())
	for _i: int in range(ACCENT_COUNT):
		_accent.append(_field_mote())
	for _i: int in range(WEATHER_COUNT):
		_weather.append(_field_mote())


func _seed_road_and_door() -> void:
	var spring_y: float = GROUND_Y + DOOR_H * DOOR_SPRING
	var apex_y: float = GROUND_Y + DOOR_H
	_door_world.append(Vector3(ROAD_X - DOOR_HALF, GROUND_Y, DOOR_Z))
	for i: int in range(DOOR_ARCH_SEGS + 1):
		var t: float = float(i) / float(DOOR_ARCH_SEGS)
		var x: float = ROAD_X + lerpf(-DOOR_HALF, DOOR_HALF, t)
		var arch: float = 1.0 - pow(absf(2.0 * t - 1.0), 1.55)
		_door_world.append(Vector3(x, lerpf(spring_y, apex_y, arch), DOOR_Z))
	_door_world.append(Vector3(ROAD_X + DOOR_HALF, GROUND_Y, DOOR_Z))
	_door_scr.resize(_door_world.size())
	var inset: float = 0.78
	var mid_y: float = GROUND_Y + DOOR_H * 0.48
	for p: Vector3 in _door_world:
		_inner_world.append(Vector3(
			ROAD_X + (p.x - ROAD_X) * inset,
			mid_y + (p.y - mid_y) * inset,
			DOOR_Z + 0.12))
	_inner_scr.resize(_inner_world.size())
	var rose_y: float = lerpf(spring_y, apex_y, 0.42)
	var rose_r: float = DOOR_HALF * 0.28
	for i: int in range(6):
		var ra: float = -PI * 0.5 + float(i) * TAU / 6.0
		_rose_world.append(Vector3(
			ROAD_X + cos(ra) * rose_r, rose_y + sin(ra) * rose_r * 0.85,
			DOOR_Z + 0.2))
	_rose_scr.resize(_rose_world.size())
	_thresh_world.append(Vector3(ROAD_X - DOOR_HALF * 1.22, GROUND_Y, DOOR_Z + 0.15))
	_thresh_world.append(Vector3(ROAD_X - DOOR_HALF * 1.38, GROUND_Y, DOOR_Z + 2.6))
	_thresh_world.append(Vector3(ROAD_X + DOOR_HALF * 1.38, GROUND_Y, DOOR_Z + 2.6))
	_thresh_world.append(Vector3(ROAD_X + DOOR_HALF * 1.22, GROUND_Y, DOOR_Z + 0.15))
	_thresh_scr.resize(4)
	_road_world.append(Vector3(ROAD_X - ROAD_HALF, GROUND_Y, ROAD_NEAR_Z))
	_road_world.append(Vector3(ROAD_X - ROAD_HALF, GROUND_Y, DOOR_Z + 0.4))
	_road_world.append(Vector3(ROAD_X + ROAD_HALF, GROUND_Y, DOOR_Z + 0.4))
	_road_world.append(Vector3(ROAD_X + ROAD_HALF, GROUND_Y, ROAD_NEAR_Z))
	_road_scr.resize(4)
	_road_col.resize(4)
	var line_h: float = 0.07
	_line_world.append(Vector3(ROAD_X - line_h, GROUND_Y, ROAD_NEAR_Z - 0.2))
	_line_world.append(Vector3(ROAD_X - line_h, GROUND_Y, DOOR_Z + 1.8))
	_line_world.append(Vector3(ROAD_X + line_h, GROUND_Y, DOOR_Z + 1.8))
	_line_world.append(Vector3(ROAD_X + line_h, GROUND_Y, ROAD_NEAR_Z - 0.2))
	_line_scr.resize(4)
	for i: int in range(LANTERN_PAIRS):
		var t: float = (float(i) + 0.55) / (float(LANTERN_PAIRS) + 0.15)
		var lz: float = lerpf(ROAD_NEAR_Z - 0.8, DOOR_Z + 3.2, t)
		var lh: float = 1.65 + _rng.randf() * 0.55
		var side: float = ROAD_HALF + 0.28
		_lanterns.append(Vector3(ROAD_X - side, GROUND_Y + lh, lz))
		_lanterns.append(Vector3(ROAD_X + side, GROUND_Y + lh, lz - 0.7))


func _field_mote() -> Vector4:
	return Vector4(
		(_rng.randf() - 0.5) * FIELD_X * 2.0,
		ALT + 3.1 + (_rng.randf() - 0.5) * FIELD_Y * 2.0,
		(_rng.randf() - 0.5) * FIELD_Z * 2.0,
		_rng.randf() * 100.0)


func _process(delta: float) -> void:
	var dt: float = minf(0.05, delta)
	# REDUCE MOTION stills the ambience — rising motes, falling weather, the
	# breathing folded into `_time` — while the pointer-chased eye keeps
	# answering the hand: the benchmark's five blocks kill keyframes, never
	# cursor response (styles.css:2036-2053).
	var still: bool = Preferences.active.reduce_motion
	if not still:
		_time += dt
	_drift.step(self, dt)
	_step_camera(dt)
	if not still:
		_rise_field(_main, dt, 1.0)
		_rise_field(_accent, dt, 0.55)
		_fall_weather(dt)
	queue_redraw()
	_field.queue_redraw()


## The ambient eye (scene3d.js:417-418, :427-430): a chased position with two
## slow sines, a chased look, and the breathing roll folded into projection.
func _step_camera(dt: float) -> void:
	var target: Vector3 = Vector3(
		_drift.n.x * SWAY.x,
		ALT + 3.1 - _drift.n.y * SWAY.y + sin(_time * BREATH_Y_RATE) * BREATH_Y,
		10.0 + sin(_time * BREATH_Z_RATE) * BREATH_Z)
	_cam = _cam.lerp(target, minf(1.0, dt * CAM_CHASE))
	_look = _look.lerp(Vector3(0.0, ALT, -6.0), minf(1.0, dt * CAM_CHASE))
	_fwd = (_look - _cam).normalized()
	_right = _fwd.cross(Vector3.UP).normalized()
	_up = _right.cross(_fwd)
	_roll = sin(_time * ROLL_RATE) * ROLL
	_focal = (maxf(1.0, size.y) * 0.5) / tan(deg_to_rad(FOV_DEG * 0.5))


## World → screen. Returns (x, y, depth); depth <= 0 means behind the eye.
func _project(world: Vector3) -> Vector3:
	var rel: Vector3 = world - _cam
	var zv: float = rel.dot(_fwd)
	if zv < 0.3:
		return Vector3(0.0, 0.0, -1.0)
	var xv: float = rel.dot(_right)
	var yv: float = rel.dot(_up)
	# The breathing roll, applied in view space so the whole world tips.
	var c: float = cos(_roll)
	var s: float = sin(_roll)
	var xr: float = xv * c - yv * s
	var yr: float = xv * s + yv * c
	return Vector3(size.x * 0.5 + xr / zv * _focal,
		size.y * 0.5 - yr / zv * _focal, zv)


func _fog_of(depth: float) -> float:
	var f: float = FOG_DENSITY * depth
	return 1.0 - exp(-f * f)


func _project_into(world: Array[Vector3], dest: PackedVector2Array) -> bool:
	for i: int in world.size():
		var p: Vector3 = _project(world[i])
		if p.z <= 0.0:
			return false
		dest[i] = Vector2(p.x, p.y)
	return true


## The particle drift (scene3d.js:355-366): a slow rise with per-seed rate and
## a sideways breathing sway, wrapping around the eye's altitude.
func _rise_field(motes: Array[Vector4], dt: float, rate: float) -> void:
	var cy: float = _cam.y
	for i: int in motes.size():
		var m: Vector4 = motes[i]
		m.y += dt * rate * (0.35 + fmod(m.w, 1.0) * 0.5)
		m.x += sin(_time * 0.5 + m.w) * dt * 0.18
		if m.y > cy + FIELD_Y:
			m.y = cy - FIELD_Y
			m.x = (_rng.randf() - 0.5) * FIELD_X * 2.0
		motes[i] = m


## Ash mode (scene3d.js:377): falls at 0.45+s*0.55 with a slow sway, wrapping
## the same box.
func _fall_weather(dt: float) -> void:
	var cy: float = _cam.y
	for i: int in _weather.size():
		var m: Vector4 = _weather[i]
		m.y -= dt * (0.45 + fmod(m.w, 1.0) * 0.55)
		m.x += sin(_time * 0.7 + m.w) * dt * 0.5
		if m.y < cy - FIELD_Y:
			m.y += FIELD_Y * 2.0
		if m.x < -FIELD_X:
			m.x += FIELD_X * 2.0
		if m.x > FIELD_X:
			m.x -= FIELD_X * 2.0
		_weather[i] = m


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SKY)
	_draw_nebulae()
	_draw_clouds()
	_draw_ground_and_trees()
	_draw_shards_and_chains()


## Soft translucent sprites behind the door. The benchmark blends these
## additively over near-black, which plain alpha over the same sky matches —
## and painting them BEFORE the silhouette keeps the door's occlusion.
## A three.js sprite's `scale` is its FULL world width; screen half-width is
## therefore `scale * focal / depth * 0.5` — the first cut of this file used
## it as the half and every sprite arrived doubled.
func _half_w(world_scale: float, depth: float) -> float:
	return world_scale * _focal / depth * 0.5


func _draw_nebulae() -> void:
	var tex: Texture2D = SkyField.disc()
	# `fog.lerp(particles, 0.5)` (scene3d.js:344) — warm dust, not white.
	var dust: Color = FOG.lerp(MAIN, 0.5)
	for i: int in _nebulae.size():
		var p: Vector3 = _project(_nebulae[i]
			+ Vector3(sin(_time * 0.08 + _nebula_wob[i]) * 1.2, 0.0, 0.0))
		if p.z <= 0.0:
			continue
		var w: float = _half_w(_nebula_scale[i], p.z)
		var col: Color = Color(dust, _nebula_alpha[i])
		draw_texture_rect(tex, Rect2(Vector2(p.x - w, p.y - w * 0.7),
			Vector2(w * 2.0, w * 1.4)), false, col)


func _draw_clouds() -> void:
	var tex: Texture2D = SkyField.disc()
	var deck: Color = FOG.lerp(Color.WHITE, 0.42)
	for i: int in _clouds.size():
		var p: Vector3 = _project(_clouds[i])
		if p.z <= 0.0:
			continue
		var w: float = _half_w(_cloud_scale[i], p.z)
		var col: Color = deck
		col = col.lerp(FOG, _fog_of(p.z))
		col.a = 0.34
		draw_texture_rect(tex, Rect2(Vector2(p.x - w, p.y - w * 0.32),
			Vector2(w * 2.0, w * 0.64)), false, col)


func _draw_door() -> void:
	var nimbus: Vector3 = _project(Vector3(ROAD_X, GROUND_Y + DOOR_H * 0.62, DOOR_Z - 5.0))
	if nimbus.z > 0.0:
		var nw: float = _half_w(22.0, nimbus.z)
		var nc: Color = FOG.lerp(Color.WHITE, 0.38)
		nc.a = 0.42
		draw_texture_rect(SkyField.disc(), Rect2(Vector2(nimbus.x - nw, nimbus.y - nw * 0.72),
			Vector2(nw * 2.0, nw * 1.44)), false, nc)
	if not _project_into(_door_world, _door_scr):
		return
	draw_colored_polygon(_door_scr, DOOR_INK)
	if _project_into(_inner_world, _inner_scr):
		draw_colored_polygon(_inner_scr, DOOR_PANEL)
	if _project_into(_rose_world, _rose_scr):
		draw_colored_polygon(_rose_scr, Color(MAIN, 0.22))
	draw_polyline(_door_scr, Color(MAIN, 0.38), 2.1, true)
	var apex: Vector3 = _project(Vector3(ROAD_X, GROUND_Y + DOOR_H, DOOR_Z))
	var foot: Vector3 = _project(Vector3(ROAD_X, GROUND_Y, DOOR_Z))
	if apex.z > 0.0 and foot.z > 0.0:
		draw_line(Vector2(apex.x, apex.y), Vector2(foot.x, foot.y),
			Color(0.012, 0.014, 0.024, 1.0), 1.6)


func _draw_ground_and_trees() -> void:
	# The ground disc reads as everything below its projected horizon. Every
	# visible ground pixel sits 15-60 units out, so FogExp2 has washed it 50-95%
	# toward the fog colour — a vertical gradient from almost-fog at the horizon
	# to half-fog at the frame's bottom edge (scene3d.js:346, :116).
	var horizon: Vector3 = _project(Vector3(0.0, GROUND_Y, -60.0))
	if horizon.z > 0.0:
		var top: float = clampf(horizon.y, 0.0, size.y)
		var ground_base: Color = Color(SKY.r * 0.3, SKY.g * 0.3, SKY.b * 0.3)
		var far_col: Color = ground_base.lerp(FOG, 0.9)
		var near_col: Color = ground_base.lerp(FOG, 0.5)
		draw_polygon(PackedVector2Array([
			Vector2(0.0, top), Vector2(size.x, top),
			Vector2(size.x, size.y), Vector2(0.0, size.y),
		]), PackedColorArray([far_col, far_col, near_col, near_col]))
	_draw_road()
	_draw_door()
	# `treeMat.color = sky * 0.38` (scene3d.js:348), then fogged at full
	# strength — the forest reads as fog-washed silhouettes, not black blobs.
	var tree_base: Color = Color(SKY.r * 0.38, SKY.g * 0.38, SKY.b * 0.38)
	for i: int in _trees.size():
		var t: Vector3 = _trees[i]
		var base: Vector3 = _project(Vector3(t.x, GROUND_Y, t.y))
		var tip: Vector3 = _project(Vector3(t.x, GROUND_Y + t.z, t.y))
		if base.z <= 0.0 or tip.z <= 0.0:
			continue
		var half_w: float = _tree_w[i] * 0.5 * _focal / base.z
		var col: Color = tree_base.lerp(FOG, _fog_of(base.z))
		draw_colored_polygon(PackedVector2Array([
			Vector2(tip.x, tip.y),
			Vector2(base.x + half_w, base.y),
			Vector2(base.x - half_w, base.y),
		]), col)


func _draw_road() -> void:
	if not _project_into(_road_world, _road_scr):
		return
	var near_p: Vector3 = _project(_road_world[0])
	var far_p: Vector3 = _project(_road_world[1])
	var umber: Color = Color(0.16, 0.10, 0.07)
	var near_col: Color = umber.lerp(FOG, _fog_of(near_p.z) * 0.40)
	var far_col: Color = umber.lerp(FOG, _fog_of(far_p.z) * 0.85)
	near_col.a = 1.0
	far_col.a = 1.0
	_road_col[0] = near_col
	_road_col[1] = far_col
	_road_col[2] = far_col
	_road_col[3] = near_col
	draw_polygon(_road_scr, _road_col)
	if _project_into(_thresh_world, _thresh_scr):
		draw_colored_polygon(_thresh_scr, DOOR_INK)
	if _project_into(_line_world, _line_scr):
		var line: Color = MAIN
		line.a = 0.18 * (1.0 - _fog_of(far_p.z))
		draw_colored_polygon(_line_scr, line)
	_draw_lantern_posts()


func _draw_lantern_posts() -> void:
	for flame: Vector3 in _lanterns:
		var base: Vector3 = _project(Vector3(flame.x, GROUND_Y, flame.z))
		var top: Vector3 = _project(flame)
		if base.z <= 0.0 or top.z <= 0.0:
			continue
		var fog: float = _fog_of(base.z)
		var ink: Color = DOOR_INK.lerp(FOG, fog * 0.65)
		draw_line(Vector2(base.x, base.y), Vector2(top.x, top.y), ink, 1.7)
		var arm: float = 3.2 * _focal / top.z
		draw_line(Vector2(top.x - arm, top.y), Vector2(top.x + arm, top.y), ink, 1.3)


## The near frame: the four clipped shard cones the old mock carried (they are
## `fgGroup` flattened, and they were right), plus the two hanging chains with
## the source's own swing (scene3d.js:425-426).
func _draw_shards_and_chains() -> void:
	var w: float = size.x
	var h: float = size.y
	var lean: Vector2 = -_drift.n * Vector2(34.0, 20.0)
	_poly([Vector2(-0.10, -0.05), Vector2(0.25, -0.05),
		Vector2(0.29, 0.52), Vector2(0.20, 0.58), Vector2(-0.03, 0.54)], w, h, SHARD, lean)
	_poly([Vector2(0.27, -0.05), Vector2(0.55, -0.05),
		Vector2(0.56, 0.53), Vector2(0.48, 0.59), Vector2(0.34, 0.54)], w, h, SHARD, lean)
	_poly([Vector2(0.54, -0.05), Vector2(0.77, -0.05),
		Vector2(0.76, 0.54), Vector2(0.68, 0.60), Vector2(0.57, 0.53)], w, h, SHARD, lean)
	_poly([Vector2(0.76, -0.05), Vector2(1.10, -0.05),
		Vector2(1.05, 0.55), Vector2(0.86, 0.59), Vector2(0.78, 0.52)], w, h, SHARD, lean)
	var swing_a: float = 0.05 + sin(_time * 0.5) * 0.028
	var swing_b: float = -0.07 + sin(_time * 0.42 + 2.0) * 0.024
	_chain(Vector2(w * 0.16, -4.0) + lean, swing_a, h * 0.30)
	_chain(Vector2(w * 0.86, -4.0) + lean, swing_b, h * 0.26)


func _chain(from: Vector2, angle: float, length: float) -> void:
	var to: Vector2 = from + Vector2(sin(angle), cos(angle)) * length
	draw_line(from, to, SHARD, 3.0)
	draw_circle(to, 4.5, SHARD)


func _poly(points: Array[Vector2], w: float, h: float, colour: Color,
		lean: Vector2 = Vector2.ZERO) -> void:
	var scaled: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		scaled.append(Vector2(point.x * w, point.y * h) + lean)
	draw_colored_polygon(scaled, colour)


## The additive pass: lantern flames along the road, the three point fields
## projected with size attenuation. The disc texture's radial falloff carries
## the bloom read once the sprites arrive at their true sizes.
func paint_field(host: CanvasItem) -> void:
	var tex: Texture2D = SkyField.disc()
	for flame: Vector3 in _lanterns:
		var p: Vector3 = _project(flame)
		if p.z <= 0.0:
			continue
		var w: float = _half_w(0.55, p.z)
		if w < 0.5:
			continue
		var col: Color = MAIN
		col.a = 0.72 * (1.0 - _fog_of(p.z))
		if col.a < 0.01:
			continue
		host.draw_texture_rect(tex, Rect2(Vector2(p.x - w, p.y - w),
			Vector2(w * 2.0, w * 2.0)), false, col)
		var halo: float = w * 2.4
		var wash: Color = MAIN
		wash.a = col.a * 0.35
		host.draw_texture_rect(tex, Rect2(Vector2(p.x - halo, p.y - halo),
			Vector2(halo * 2.0, halo * 2.0)), false, wash)
	var rose: Vector3 = _project(Vector3(ROAD_X, GROUND_Y + DOOR_H * 0.72, DOOR_Z))
	if rose.z > 0.0:
		var rw: float = _half_w(9.0, rose.z)
		var rc: Color = MAIN
		rc.a = 0.16 * (1.0 - _fog_of(rose.z))
		host.draw_texture_rect(tex, Rect2(Vector2(rose.x - rw, rose.y - rw),
			Vector2(rw * 2.0, rw * 2.0)), false, rc)
	_stamp(host, _main, MAIN_SIZE, MAIN, MAIN_ALPHA)
	_stamp(host, _accent, ACCENT_SIZE, ACCENT,
		ACCENT_ALPHA + sin(_time * 0.9) * 0.12)
	_stamp(host, _weather, WEATHER_SIZE, MAIN.lerp(Color.WHITE, 0.55),
		WEATHER_ALPHA)


## Size-attenuated points: world size × focal ÷ depth, like every sprite. The
## accent field's 0.32 world units arrive at 10-40 screen pixels up close —
## the big soft glow blobs that carry the night air.
func _stamp(host: CanvasItem, motes: Array[Vector4], world_size: float,
		tint: Color, alpha: float) -> void:
	var colour: Color = Color(tint, alpha)
	var texture: Texture2D = SkyField.disc()
	for mote: Vector4 in motes:
		var p: Vector3 = _project(Vector3(mote.x, mote.y, mote.z))
		if p.z <= 0.0:
			continue
		var w: float = _half_w(world_size, p.z)
		if w < 0.4:
			continue
		host.draw_texture_rect(texture, Rect2(
			Vector2(p.x - w, p.y - w), Vector2(w * 2.0, w * 2.0)), false, colour)
