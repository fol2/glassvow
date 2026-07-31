class_name TitleWorld
extends Control
## The title's slice of benchmark `scene3d.js`, projected rather than mocked.
##
## The old file drew four polygons, a tree strip and two mote fields and
## declared itself a mock. This one carries the scene's own geometry through a
## fixed ambient camera: the Spire lathed from `radiusAt(y)` with its sister,
## the window lights scattered up its face, seven nebulae, the cloud deck in
## the first act gap, the forest at the tower's foot, the near shards and
## chains, ash weather, and the two point fields — every element placed in
## world units and projected per frame, so pointer parallax is not a set of
## authored offsets but the camera moving through the volume, which is what
## the benchmark does (`_posT.x = mouse.x * 0.9`, scene3d.js:417).
##
## Not a Node3D scene on purpose: the title eye is fixed, every element reads
## as silhouette + additive sprite + fog, and `_draw` reproduces that without
## a SubViewport, an environment, or a second renderer to budget. If the full
## 3D scene is ever ported this comes out, same as the sky field.
##
## Occlusion is by paint order, not depth buffer: sky → nebulae → clouds →
## spire ink → ground and forest → near shards and chains, with the additive
## child (window lights, motes, weather) above. The one lie in that order —
## additive lights over the near shards — does not show: the shard band and
## the tower face never overlap at this camera.
##
## The summit beacon is deliberately absent: at the title eye it projects far
## above the frame (the benchmark's own title crops the tower mid-face), so
## the sphere and its pulsing halo would be spent on pixels nobody sees. It
## returns if a map-mode camera ever lives here.

## `TOWER` (scene3d.js:23-33) and `radiusAt` (scene3d.js:35-42), verbatim.
const TOWER_X: float = 7.0
const TOWER_Z: float = -20.0
const TOWER_BOTTOM: float = -16.0
const TOWER_TOP: float = 54.0
const TOWER_AZ_BASE: float = 1.8006  # atan2(30, -7)
const SPIRE_SEGS: int = 56
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
## `FogExp2(fog, 0.055)` — factor `1 - exp(-(d·depth)²)`; the spire and beacon
## are `fog: false` and stay ink.
const FOG_DENSITY: float = 0.055
## Theme at the title: the resting `cur` colours (scene3d.js:17). The mesh
## tints are the runtime writes in `frame()` (scene3d.js:345-348), not the
## constructor colours — the loop overwrites those every frame.
const SKY: Color = Color("#0b0e1a")
const FOG: Color = Color("#141a2e")
const MAIN: Color = Color("#ffa04d")
const ACCENT: Color = Color("#66ff9e")
const SPIRE_INK: Color = Color("#04050b")
const SHARD: Color = Color("#04090a")
## Window lights (scene3d.js:160-176): 120 sprites up the face, scale .16-.42.
const LIGHT_COUNT: int = 120
## Nebulae (scene3d.js:127-139): 7 additive sprites, opacity .1-.2, tinted
## `fog.lerp(particles, 0.5)` every frame (scene3d.js:344) — warm dust, not
## white.
const NEBULA_COUNT: int = 7
## Trees (scene3d.js:194-208): 52 cones on the ground disc at -9.6.
const TREE_COUNT: int = 52
## One cloud deck rides the first act gap (scene3d.js:211-215); the second sits
## far above the title frame and is not spent here. `actBaseY(1) - 2.2`.
const CLOUD_DECK_Y: float = 10.84
const CLOUD_COUNT: int = 16
## The point fields (scene3d.js:264-266): `makePoints(900, 0.16, …, 0.75)`
## main embers and `makePoints(240, 0.32, …, 0.5)` accent glow, both
## size-attenuated world sprites in a ±23 × ±13 × ±20 box around the eye. The
## first cut of this file flattened them to ~150 screen-space dots — a tenth
## of the population at a fraction of the size, which is most of why the port
## read black where the benchmark reads alive. Projected now, like the rest.
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

var _spire_profile: PackedFloat32Array = PackedFloat32Array()  # radius per seg
var _lights: Array[Vector3] = []
var _light_scale: PackedFloat32Array = PackedFloat32Array()
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


## `radiusAt(y)` verbatim: tiered ledges and fine crag over a powered cone.
static func radius_at(y: float) -> float:
	var t: float = clampf((y - TOWER_BOTTOM) / (TOWER_TOP - TOWER_BOTTOM), 0.0, 1.0)
	var tier: float = 1.0 + sin(t * 21.0) * 0.07 + sin(t * 57.0) * 0.05 \
		+ sin(t * 9.0 + 1.7) * 0.06
	return pow(1.0 - t, 1.15) * 6.2 * tier + 0.85


## World geometry, seeded once in a fixed order so two boots agree.
func _seed_world() -> void:
	for i: int in range(SPIRE_SEGS + 1):
		var y: float = TOWER_BOTTOM + float(i) / float(SPIRE_SEGS) \
			* (TOWER_TOP - TOWER_BOTTOM)
		_spire_profile.append(radius_at(y))
	for i: int in range(NEBULA_COUNT):
		_nebulae.append(Vector3((_rng.randf() - 0.5) * 40.0,
			(_rng.randf() - 0.5) * 18.0 - 3.0, -12.0 - _rng.randf() * 22.0))
		_nebula_scale.append(14.0 + _rng.randf() * 22.0)
		_nebula_alpha.append(0.1 + _rng.randf() * 0.1)
		_nebula_wob.append(_rng.randf() * TAU)
	for i: int in range(LIGHT_COUNT):
		var y: float = TOWER_BOTTOM + 6.0 \
			+ _rng.randf() * (TOWER_TOP - TOWER_BOTTOM - 10.0)
		var a: float = TOWER_AZ_BASE + (_rng.randf() - 0.5) * 2.4
		var r: float = radius_at(y) + 0.12
		_lights.append(Vector3(TOWER_X + cos(a) * r, y, TOWER_Z + sin(a) * r))
		_light_scale.append(0.16 + _rng.randf() * 0.26)
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
		var a: float = 0.0
		var d: float = 0.0
		var z: float = 0.0
		while true:
			a = _rng.randf() * TAU
			d = 5.0 + _rng.randf() * 22.0
			z = TOWER_Z + sin(a) * d
			if z <= -7.0:
				break
		_clouds.append(Vector3(TOWER_X + cos(a) * d,
			CLOUD_DECK_Y + (_rng.randf() - 0.5) * 1.6, z))
		_cloud_scale.append(10.0 + _rng.randf() * 14.0)
	# The three point fields, seeded in the makePoints box around the eye.
	for _i: int in range(MAIN_COUNT):
		_main.append(_field_mote())
	for _i: int in range(ACCENT_COUNT):
		_accent.append(_field_mote())
	for _i: int in range(WEATHER_COUNT):
		_weather.append(_field_mote())


func _field_mote() -> Vector4:
	return Vector4(
		(_rng.randf() - 0.5) * FIELD_X * 2.0,
		ALT + 3.1 + (_rng.randf() - 0.5) * FIELD_Y * 2.0,
		(_rng.randf() - 0.5) * FIELD_Z * 2.0,
		_rng.randf() * 100.0)


func _process(delta: float) -> void:
	var dt: float = minf(0.05, delta)
	_time += dt
	_drift.step(self, dt)
	_step_camera(dt)
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
	_draw_spire(TOWER_X, TOWER_Z, 1.0, 0.0)
	# The distant sister: half profile, sunk ten units (scene3d.js:153-156).
	_draw_spire(-15.0, -30.0, 0.5, -10.0)
	_draw_ground_and_trees()
	_draw_shards_and_chains()


## Soft translucent sprites behind the tower. The benchmark blends these
## additively over near-black, which plain alpha over the same sky matches —
## and painting them BEFORE the spire keeps the silhouette's occlusion.
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


## The lathe's silhouette: per segment, project the axis point and convert the
## profile radius to screen width at that depth — right edge up, left edge
## down, one ink polygon. `fog: false` in the source, so no fade.
func _draw_spire(axis_x: float, axis_z: float, prof_scale: float,
		y_shift: float) -> void:
	var right_side: PackedVector2Array = PackedVector2Array()
	var left_side: PackedVector2Array = PackedVector2Array()
	for i: int in range(SPIRE_SEGS + 1):
		var y: float = (TOWER_BOTTOM + float(i) / float(SPIRE_SEGS) \
			* (TOWER_TOP - TOWER_BOTTOM)) * prof_scale + y_shift
		var p: Vector3 = _project(Vector3(axis_x, y, axis_z))
		if p.z <= 0.0:
			continue
		var half_w: float = _spire_profile[i] * prof_scale * _focal / p.z
		right_side.append(Vector2(p.x + half_w, p.y))
		left_side.append(Vector2(p.x - half_w, p.y))
	if right_side.size() < 2:
		return
	left_side.reverse()
	right_side.append_array(left_side)
	draw_colored_polygon(right_side, SPIRE_INK)


func _draw_ground_and_trees() -> void:
	# The ground disc reads as everything below its projected horizon. Every
	# visible ground pixel sits 15-60 units out, so FogExp2 has washed it 50-95%
	# toward the fog colour — a vertical gradient from almost-fog at the horizon
	# to half-fog at the frame's bottom edge (scene3d.js:346, :116).
	var horizon: Vector3 = _project(Vector3(0.0, -9.6, -60.0))
	if horizon.z > 0.0:
		var top: float = clampf(horizon.y, 0.0, size.y)
		var ground_base: Color = Color(SKY.r * 0.3, SKY.g * 0.3, SKY.b * 0.3)
		var far_col: Color = ground_base.lerp(FOG, 0.9)
		var near_col: Color = ground_base.lerp(FOG, 0.5)
		draw_polygon(PackedVector2Array([
			Vector2(0.0, top), Vector2(size.x, top),
			Vector2(size.x, size.y), Vector2(0.0, size.y),
		]), PackedColorArray([far_col, far_col, near_col, near_col]))
	# `treeMat.color = sky * 0.38` (scene3d.js:348), then fogged at full
	# strength — the forest reads as fog-washed silhouettes, not black blobs.
	var tree_base: Color = Color(SKY.r * 0.38, SKY.g * 0.38, SKY.b * 0.38)
	for i: int in _trees.size():
		var t: Vector3 = _trees[i]
		var base: Vector3 = _project(Vector3(t.x, -9.6, t.y))
		var tip: Vector3 = _project(Vector3(t.x, -9.6 + t.z, t.y))
		if base.z <= 0.0 or tip.z <= 0.0:
			continue
		var half_w: float = _tree_w[i] * 0.5 * _focal / base.z
		var col: Color = tree_base.lerp(FOG, _fog_of(base.z))
		draw_colored_polygon(PackedVector2Array([
			Vector2(tip.x, tip.y),
			Vector2(base.x + half_w, base.y),
			Vector2(base.x - half_w, base.y),
		]), col)


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


## The additive pass: window lights on the tower face, the three point fields
## projected with size attenuation. The benchmark then runs the whole frame
## through `UnrealBloomPass(0.85, 0.55, 0.16)` — a soft glow on everything
## bright. The disc texture's radial falloff carries most of that read once
## the sprites arrive at their true sizes; a halo pass is NOT layered on top,
## so if the field still reads thin against localhost:5190, bloom is the next
## knob, not density.
func paint_field(host: CanvasItem) -> void:
	var tex: Texture2D = SkyField.disc()
	for i: int in _lights.size():
		var p: Vector3 = _project(_lights[i])
		if p.z <= 0.0:
			continue
		var w: float = _half_w(_light_scale[i], p.z)
		if w < 0.5:
			continue
		# `windowMat` is fogged in the source — at thirty units that fades a
		# window to a few percent, and the 120 together read as embers in the
		# tower rather than as two bright bands where the cylinder's limbs
		# stack the projection.
		var col: Color = ACCENT
		col.a = 0.55 * (1.0 - _fog_of(p.z))
		if col.a < 0.01:
			continue
		host.draw_texture_rect(tex, Rect2(Vector2(p.x - w, p.y - w),
			Vector2(w * 2.0, w * 2.0)), false, col)
	_stamp(host, _main, MAIN_SIZE, MAIN, MAIN_ALPHA)
	_stamp(host, _accent, ACCENT_SIZE, ACCENT,
		ACCENT_ALPHA + sin(_time * 0.9) * 0.12)
	_stamp(host, _weather, WEATHER_SIZE, MAIN.lerp(Color.WHITE, 0.55),
		WEATHER_ALPHA)


## Size-attenuated points: world size × focal ÷ depth, like every sprite. The
## accent field's 0.32 world units arrive at 10-40 screen pixels up close —
## the big soft glow blobs that carry the benchmark's night air.
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
