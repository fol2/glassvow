class_name SkyField
extends Control
## What is behind the stage plates.
##
## The benchmark puts a whole three.js scene there (`src/scene3d.js`, 451 lines:
## a lathed centre mass, monoliths, cloud sea, a pulsing beacon, bloom) and the
## act's plate
## art has a transparent sky, so that scene is what you actually see above the
## treeline. This port drew pure black there, which is why a still frame of the
## fight read as flat next to the same frame at localhost:5190.
##
## This is not that scene. It is the part of it the battlefield shows: the sky
## and fog colours, and the two drifting mote fields — `ptsMain` in the theme's
## `particles` colour and `ptsAccent` in its `glow`, the second at 0.55 of the
## first's rise and breathing its opacity. The 3D scene's centre mass, the
## beacon and the clouds are all below the treeline at this camera and the plates
## cover them.
##
## Declared a mock on purpose. If the 3D scene is ever ported, this comes out.

## `themes.js` — `scene.sky`, `scene.fog`, `scene.particles`, `scene.glow`.
## Row 3 is Glassvow's original Act IV dawn arc, shared with MapRegions.
const ACT_SKIES: Array[Color] = [
	Color("#0c1410"), Color("#081420"), Color("#120a1e"), Color("#16120c")]
const ACT_FOGS: Array[Color] = [
	Color("#13241a"), Color("#0d2233"), Color("#1e1230"), Color("#241e14")]
const ACT_PARTICLES: Array[Color] = [
	Color("#ffa04d"), Color("#53e8ff"), Color("#c27bff"), Color("#ffc08a")]
const ACT_GLOWS: Array[Color] = [
	Color("#66ff9e"), Color("#2fb8ff"), Color("#ff4fd8"), Color("#f0a878")]

## `ptsMain` / `ptsAccent`. The 3D fields are volumetric and thin out with
## distance; flattened to two dozen each, which is what reads at this camera.
const MAIN_COUNT: int = 26
const ACCENT_COUNT: int = 18
## `y += dt * rate * (0.35 + seed * 0.5)` in world units. The field spans this
## many units over the stage's HEIGHT, whatever that is — the constant used to be
## 29px, which is 820/28 and therefore silently the pad-landscape answer written
## out as though it were a property of the field. A phone stage is 844 tall and a
## pad in portrait 1180, and a fixed 29 would have drifted the motes at the wrong
## rate on both.
const SPAN_UNITS: float = 28.0
const ACCENT_RATE: float = 0.55
## `x += sin(time * 0.5 + seed) * dt * 0.18` — a slow lateral wander, not wind.
const WOBBLE_RATE: float = 0.5
const WOBBLE_AMP: float = 0.18
## `ptsAccent.material.opacity = 0.42 + sin(time * 0.9) * 0.12`
const ACCENT_ALPHA: float = 0.42
const ACCENT_BREATH: float = 0.12
const MAIN_ALPHA: float = 0.55
## Radius in px. The 3D points are camera-scaled, so near ones bloom wide.
const R_MIN: float = 2.5
const R_MAX: float = 13.0
## How far up the viewport the fog band reaches. Below it the plates cover
## everything, so the gradient has nothing left to say.
const FOG_TOP: float = 0.28
const FOG_BOTTOM: float = 0.72

## `kick(power)` (scene3d.js:314) — the world takes the blow. Two numbers rise
## together and then decay apart: `kickV` pulls the camera in and rattles its
## roll, `speedMul` drives the mote field faster. Both are capped, so a chain of
## hits builds to a ceiling rather than to the moon.
const KICK_MAX: float = 2.2
const KICK_SPEED: float = 2.4
const SPEED_MAX: float = 7.0
## `kickV *= 0.02^dt` — a 177ms half-life, so one blow is spent inside a third of
## a second and a second blow inside that window still stacks onto it.
const KICK_DECAY: float = 0.02
## `speedMul += (1 - speedMul) * min(1, dt * 2.5)` — the field slows back down on
## its own curve, much lazier than the camera's.
const SPEED_RETURN: float = 2.5
## `_posT.z = 10 + ... - kickV * 0.9` against a base of 10. A perspective
## camera's scale goes as 1/distance, so a flat field says the same thing by
## zooming 10 / (10 - 0.9·kickV) — 1.25x at the ceiling.
const CAM_Z: float = 10.0
const KICK_DOLLY: float = 0.9
## `camera.position.lerp(_posT, min(1, dt * 2.2))` — the dolly is CHASED, never
## snapped, and that lag is most of why a kick reads as a lurch and not a cut.
const CAM_CHASE: float = 2.2
## `camera.rotation.z += kickV * (Math.random() - 0.5) * 0.012` — a fresh roll
## every frame, so the world rattles rather than tilting.
const KICK_ROLL: float = 0.012
## `bloom.strength = bloomBase + kickV * 0.55`, `bloomBase = 0.85`. There is no
## bloom pass behind this field; the motes are the only thing in it bright enough
## for one to have shown on, so they carry the flare as a colour gain.
const BLOOM_BASE: float = 0.85
const KICK_BLOOM: float = 0.55
## The roll is applied about the field's centre, which uncovers up to
## `(width / 2) · sin(θ)` at the top edge — about 8px at the ceiling. The zoom
## covers far more than that once it has caught up, but it is chased and the roll
## is not, so for a frame or two after a big hit it has not. Overhanging the
## field is the fix; the benchmark never needs one because its camera lives in a
## world with no edges.
const OVERHANG: float = 26.0

## The ambient camera: `_posT.x = mouse.x * 0.9, _posT.y = 3.1 - mouse.y * 0.55`
## (scene3d.js:417) against roughly 28 world units of visible field — ±0.9 of a
## unit is a couple of dozen px here. Applied per mote, scaled by radius, so a
## near (big) point leans further than a far one and the field gains depth the
## moment the hand moves. The haze band leans a third of it.
const PARALLAX_PX: Vector2 = Vector2(26.0, 16.0)
## `camera.rotation.z += Math.sin(time * 0.13) * 0.012` (scene3d.js:429) — the
## world breathes its roll even at rest.
const BREATH_RATE: float = 0.13
const BREATH_ROLL: float = 0.012

## The weather field (scene3d.js:377-399): 300 points in the volume. The three
## benchmark behaviours stay byte-shaped — ash, mire, astral — and Act IV adds
## Glassvow's reversed hearth-light: rose-gold cinders rise toward dawn. Flattened
## to what reads at this camera, denser than the motes because weather is a veil,
## not points of light. Rates are world units/s through the same SPAN_UNITS ruler
## the motes use; the source's world-Y points up, so its `y -=` is screen rise.
const WEATHER_COUNT: int = 110
const WEATHER_ALPHA: Array[float] = [0.5, 0.42, 0.62, 0.50]
const ASH_FALL: Vector2 = Vector2(0.45, 0.55)      # base, seed spread
const MIRE_FALL: Vector2 = Vector2(0.14, 0.2)
const MIRE_WOBBLE: float = 0.9
const MIRE_WOBBLE_RATE: float = 0.35
const ASTRAL_RUN: Vector2 = Vector2(3.4, 2.8)
const ASTRAL_FALL: Vector2 = Vector2(0.5, 0.5)
const ASTRAL_LEN: float = 4.2                       # streak length, in radii
const DAWN_RISE: Vector2 = Vector2(0.42, 0.52)
const DAWN_WOBBLE: float = 0.48
const DAWN_WOBBLE_RATE: float = 0.22
const DAWN_LEN: float = 2.8                         # upward ember tail, in radii
const WEATHER_R_MIN: float = 1.1
const WEATHER_R_MAX: float = 2.6

## Act-3 heat lightning (scene3d.js:337-340, :448): silent flashes light the
## whole world for a beat — sky and fog lerp toward a pale blue-white, the
## additive field flares — then decay at `0.008^dt`. Scheduled from the clock
## rather than rolled per frame, so two captures of one build still match:
## one flash per SLOT seconds, intensity hashed from the slot index.
const LIGHTNING_TONE: Color = Color("#bfd4ff")
const LIGHTNING_SLOT: float = 8.5
const LIGHTNING_DECAY: float = 0.008
const LIGHTNING_SKY: float = 0.5
const LIGHTNING_SKY_MAX: float = 0.6
const LIGHTNING_FOG: float = 0.3
const LIGHTNING_FOG_MAX: float = 0.4
const LIGHTNING_FLARE: float = 0.45


class Mote:
	extends RefCounted
	var at: Vector2 = Vector2.ZERO
	var seed: float = 0.0
	var radius: float = 4.0
	var rise: float = 1.0


## One soft disc, built once and stamped per mote. `draw_circle` gives a hard
## edge; these are bloomed points, and a radial gradient is the same picture for
## the same number of draw calls.
static var _disc: GradientTexture2D = null

var _main: Array[Mote] = []
var _accent: Array[Mote] = []
var _weather: Array[Mote] = []
var _weather_mode: int = 0
var _sky: Color
var _fog: Color
var _particles: Color
var _glow: Color
var _haze_tex: GradientTexture2D
var _t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _field: Control
var _kick_v: float = 0.0
var _speed: float = 1.0
var _cam_z: float = CAM_Z
var _drift: PointerDrift = PointerDrift.new()
var _lightning: float = 0.0
var _lit_slot: int = -1


class Field:
	extends Control
	var src: SkyField

	func _draw() -> void:
		if src != null:
			src.paint_motes(self)


func _init(stage_act: int = 0) -> void:
	var index: int = clampi(stage_act, 0, ACT_SKIES.size() - 1)
	_sky = ACT_SKIES[index]
	_fog = ACT_FOGS[index]
	_particles = ACT_PARTICLES[index]
	_glow = ACT_GLOWS[index]
	_weather_mode = index
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = -OVERHANG
	offset_top = -OVERHANG
	offset_right = OVERHANG
	offset_bottom = OVERHANG
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 0x5CA1E  # a fixed sky: two captures of the same frame match
	_field = Field.new()
	_field.src = self
	_field.set_anchors_preset(Control.PRESET_FULL_RECT)
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_field.material = mat
	add_child(_field)


static func disc() -> GradientTexture2D:
	if _disc == null:
		_disc = GlassStyle.grad_tex(
			PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)]),
			PackedFloat32Array([0.0, 0.35, 1.0]), true,
			Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	return _disc


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		# The dolly and the roll are both about the middle of the world, not its
		# corner, and the world is re-edged whenever the window is.
		pivot_offset = size * 0.5
		if _main.is_empty() and size.x > 0.0:
			_seed_field()


func _seed_field() -> void:
	_main.clear()
	_accent.clear()
	_weather.clear()
	for i: int in range(MAIN_COUNT):
		_main.append(_mote())
	for i: int in range(ACCENT_COUNT):
		_accent.append(_mote())
	for i: int in range(WEATHER_COUNT):
		var w: Mote = _mote()
		w.radius = WEATHER_R_MIN + _rng.randf() * (WEATHER_R_MAX - WEATHER_R_MIN)
		_weather.append(w)


func _mote() -> Mote:
	var m: Mote = Mote.new()
	m.at = Vector2(_rng.randf() * maxf(1.0, size.x), _rng.randf() * maxf(1.0, size.y))
	m.seed = _rng.randf() * TAU
	m.radius = R_MIN + _rng.randf() * (R_MAX - R_MIN)
	m.rise = 0.35 + fmod(m.seed, 1.0) * 0.5
	return m


func _process(delta: float) -> void:
	if _main.is_empty():
		if size.x <= 0.0:
			return
		_seed_field()
	var dt: float = minf(0.05, delta)
	_t += dt
	_drift.step(self, dt)
	_step_kick(dt)
	_step_lightning(dt)
	_drift_motes(_main, dt, 1.0)
	_drift_motes(_accent, dt, ACCENT_RATE)
	_step_weather(dt)
	_field.queue_redraw()
	# The sky rect and haze band answer the lightning and the pointer, so the
	# base coat redraws too — two rects and a texture blit, nothing measured.
	queue_redraw()


## The world takes a blow: `kickV` and `speedMul` both jump, and the ceiling is
## on the value rather than on the rate, so ten hits in a second do not add up to
## ten kicks. Called by the drain wherever `V.shake` is — they are two halves of
## the same beat, one on the fight and one on the world behind it.
func kick(power: float = 1.0) -> void:
	_kick_v = minf(KICK_MAX, _kick_v + power)
	_speed = minf(SPEED_MAX, _speed + power * KICK_SPEED)


func _step_kick(dt: float) -> void:
	_kick_v *= pow(KICK_DECAY, dt)
	_speed += (1.0 - _speed) * minf(1.0, dt * SPEED_RETURN)
	# The camera chases the pushed-in target; the roll does not chase anything,
	# which is why the rattle arrives on the first frame and the dolly does not.
	_cam_z += (CAM_Z - KICK_DOLLY * _kick_v - _cam_z) * minf(1.0, dt * CAM_CHASE)
	scale = Vector2.ONE * (CAM_Z / maxf(0.001, _cam_z))
	# The rattle rides ON the breath: a fresh roll per frame while kicked, a
	# slow sine always (scene3d.js:429 adds both to the same axis).
	rotation = sin(_t * BREATH_RATE) * BREATH_ROLL \
		+ _kick_v * (_rng.randf() - 0.5) * KICK_ROLL


## One flash per slot, intensity hashed from the slot index — deterministic
## against the clock, so the noise floor of a settled capture stays a floor.
func _step_lightning(dt: float) -> void:
	if _weather_mode != 2:
		return
	var slot: int = int(_t / LIGHTNING_SLOT)
	if slot != _lit_slot:
		_lit_slot = slot
		_lightning = 0.7 + 0.5 * absf(sin(float(slot) * 127.1))
	_lightning *= pow(LIGHTNING_DECAY, dt)


func _step_weather(dt: float) -> void:
	var unit: float = maxf(1.0, size.y) / SPAN_UNITS
	for m: Mote in _weather:
		var s: float = fmod(m.seed, 1.0)
		match _weather_mode:
			0:  # ash sifts down
				m.at.y += dt * (ASH_FALL.x + s * ASH_FALL.y) * unit * _speed
				m.at.x += sin(_t * WOBBLE_RATE + m.seed) * dt * WOBBLE_AMP * unit
			1:  # mire sinks slow, wobbles hard
				m.at.y += dt * (MIRE_FALL.x + s * MIRE_FALL.y) * unit * _speed
				m.at.x += sin(_t * MIRE_WOBBLE_RATE + m.seed) * dt * MIRE_WOBBLE * unit
			2:  # astral streaks sideways, drifting down a little
				m.at.x -= dt * (ASTRAL_RUN.x + s * ASTRAL_RUN.y) * unit * _speed
				m.at.y += dt * (ASTRAL_FALL.x + s * ASTRAL_FALL.y) * unit * _speed
			3:  # reversed hearth-light rises into the Act IV dawn
				m.at.y -= dt * (DAWN_RISE.x + s * DAWN_RISE.y) * unit * _speed
				m.at.x += sin(_t * DAWN_WOBBLE_RATE + m.seed) \
					* dt * DAWN_WOBBLE * unit
			_:  # future rows fail soft as ash rather than inheriting Act III
				m.at.y += dt * (ASH_FALL.x + s * ASH_FALL.y) * unit * _speed
		if _weather_mode == 3:
			if m.at.y < -m.radius * DAWN_LEN:
				m.at.y = size.y + m.radius
				m.at.x = _rng.randf() * size.x
		elif m.at.y > size.y + m.radius * 2.0:
			m.at.y = -m.radius
			m.at.x = _rng.randf() * size.x
		if _weather_mode == 2:
			if m.at.x < -m.radius * ASTRAL_LEN:
				m.at.x = size.x + m.radius
				m.at.y = _rng.randf() * size.y
			elif m.at.x > size.x + m.radius * ASTRAL_LEN:
				m.at.x = -m.radius
		elif m.at.x < -m.radius * 2.0:
			m.at.x = size.x + m.radius
		elif m.at.x > size.x + m.radius * 2.0:
			m.at.x = -m.radius


func _drift_motes(motes: Array[Mote], dt: float, rate: float) -> void:
	for m: Mote in motes:
		var unit: float = maxf(1.0, size.y) / SPAN_UNITS
		m.at.y -= dt * rate * _speed * m.rise * unit
		m.at.x += sin(_t * WOBBLE_RATE + m.seed) * dt * WOBBLE_AMP * unit
		# `if (y > cy + 14) { y = cy - 14; x = random }` — the field wraps, and a
		# recycled point is thrown somewhere new rather than tracking a column.
		if m.at.y < -m.radius * 2.0:
			m.at.y = size.y + m.radius
			m.at.x = _rng.randf() * size.x
		elif m.at.x < -m.radius * 2.0:
			m.at.x = size.x + m.radius
		elif m.at.x > size.x + m.radius * 2.0:
			m.at.x = -m.radius


## The fog band, as one texture. Drawn as stacked rects first, which stepped
## visibly — a twelve-stop staircase across 360px of near-black is exactly where
## banding shows worst.
func haze() -> GradientTexture2D:
	if _haze_tex == null:
		_haze_tex = GlassStyle.grad_tex(
			PackedColorArray([Color(_fog.r, _fog.g, _fog.b, 0.0),
				Color(_fog.r, _fog.g, _fog.b, 0.85)]),
			PackedFloat32Array([0.0, 1.0]), false,
			Vector2(0.5, 0.0), Vector2(0.5, 1.0))
	return _haze_tex


func _draw() -> void:
	# The sky, then the fog it hazes into. Below FOG_BOTTOM the plates cover
	# everything, so the band stops where it stops being visible. Lightning
	# lifts the sky coat toward its pale tone and lays a veil over the fog —
	# the whole world lit for a beat (scene3d.js:337-340).
	var lit: float = minf(LIGHTNING_SKY_MAX, _lightning * LIGHTNING_SKY)
	draw_rect(Rect2(Vector2.ZERO, size), _sky.lerp(LIGHTNING_TONE, lit), true)
	var top: float = size.y * FOG_TOP
	var span: float = size.y * (FOG_BOTTOM - FOG_TOP)
	# The haze leans a third of the field's parallax — a far band, not a near one.
	var lean: Vector2 = -_drift.n * PARALLAX_PX / 3.0
	draw_texture_rect(haze(), Rect2(Vector2(0.0, top) + lean,
		Vector2(size.x, span)), false)
	var fog_lit: float = minf(LIGHTNING_FOG_MAX, _lightning * LIGHTNING_FOG)
	if fog_lit > 0.004:
		var veil: Color = LIGHTNING_TONE
		veil.a = fog_lit
		draw_rect(Rect2(Vector2(0.0, top) + lean, Vector2(size.x, span)), veil, true)


func paint_motes(host: CanvasItem) -> void:
	var tex: GradientTexture2D = disc()
	var accent_a: float = ACCENT_ALPHA + sin(_t * 0.9) * ACCENT_BREATH
	# The bloom gain, as a ratio of its own base — the field is drawn additively,
	# so a colour over 1.0 is light being added rather than a clipped white.
	# Lightning raises it the way the benchmark raises bloom.strength.
	var flare: float = 1.0 + (_kick_v * KICK_BLOOM + _lightning * LIGHTNING_FLARE) \
		/ BLOOM_BASE
	_paint_weather(host, tex, flare)
	_stamp(host, tex, _main, _particles * flare, MAIN_ALPHA)
	_stamp(host, tex, _accent, _glow * flare, accent_a)


## The veil under the light points: discs for ash and mire, a hard crosswind for
## the astral run, and short upward ember tails for the Act IV dawn.
func _paint_weather(host: CanvasItem, tex: GradientTexture2D, flare: float) -> void:
	var col: Color = _particles * flare
	col.a = WEATHER_ALPHA[clampi(_weather_mode, 0, WEATHER_ALPHA.size() - 1)]
	for m: Mote in _weather:
		var at: Vector2 = m.at + _lean_of(m)
		if _weather_mode == 2:
			host.draw_line(at, at + Vector2(m.radius * ASTRAL_LEN, m.radius * 0.6),
				col, maxf(1.0, m.radius * 0.55))
		elif _weather_mode == 3:
			host.draw_line(at, at + Vector2(m.radius * 0.4, -m.radius * DAWN_LEN),
				col, maxf(1.0, m.radius * 0.48))
		else:
			var r: float = m.radius
			host.draw_texture_rect(tex,
				Rect2(at - Vector2(r, r) * 2.0, Vector2(r, r) * 4.0), false, col)


## A near (big) point leans further after the pointer than a far one — the
## flat field's stand-in for the volume the benchmark's camera moves through.
func _lean_of(m: Mote) -> Vector2:
	return -_drift.n * PARALLAX_PX * (m.radius / R_MAX)


func _stamp(host: CanvasItem, tex: GradientTexture2D, motes: Array[Mote],
		tint: Color, alpha: float) -> void:
	var col: Color = tint
	col.a = alpha
	for m: Mote in motes:
		var r: float = m.radius
		var at: Vector2 = m.at + _lean_of(m)
		host.draw_texture_rect(tex,
			Rect2(at - Vector2(r, r) * 2.0, Vector2(r, r) * 4.0), false, col)
