class_name SkyField
extends Control
## What is behind the stage plates.
##
## The benchmark puts a whole three.js scene there (`src/scene3d.js`, 451 lines:
## a spire, monoliths, cloud sea, a pulsing beacon, bloom) and the act's plate
## art has a transparent sky, so that scene is what you actually see above the
## treeline. This port drew pure black there, which is why a still frame of the
## fight read as flat next to the same frame at localhost:5190.
##
## This is not that scene. It is the part of it the battlefield shows: the sky
## and fog colours, and the two drifting mote fields — `ptsMain` in the theme's
## `particles` colour and `ptsAccent` in its `glow`, the second at 0.55 of the
## first's rise and breathing its opacity. The spire, the beacon and the clouds
## are all below the treeline at this camera and the plates cover them.
##
## Declared a mock on purpose. If the 3D scene is ever ported, this comes out.

## `themes.js` act 1 — `scene.sky`, `scene.fog`, `scene.particles`, `scene.glow`.
## The slice exporter carries no theme record, so act 1's is inlined; the day it
## does, these become arguments.
const SKY: Color = Color(0.043137256, 0.05490196, 0.101960786)   # #0b0e1a
const FOG: Color = Color(0.078431375, 0.101960786, 0.18039216)   # #141a2e
const PARTICLES: Color = Color(1.0, 0.627451, 0.3019608)         # #ffa04d
const GLOW: Color = Color(0.4, 1.0, 0.61960787)                  # #66ff9e

## `ptsMain` / `ptsAccent`. The 3D fields are volumetric and thin out with
## distance; flattened to two dozen each, which is what reads at this camera.
const MAIN_COUNT: int = 26
const ACCENT_COUNT: int = 18
## `y += dt * rate * (0.35 + seed * 0.5)` in world units. The field spans 28
## units over a viewport that is 820px tall, so a unit is about 29px.
const UNIT: float = 29.0
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
var _t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _field: Control


class Field:
	extends Control
	var src: SkyField

	func _draw() -> void:
		if src != null:
			src.paint_motes(self)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	if what == NOTIFICATION_RESIZED and _main.is_empty() and size.x > 0.0:
		_seed_field()


func _seed_field() -> void:
	_main.clear()
	_accent.clear()
	for i: int in range(MAIN_COUNT):
		_main.append(_mote())
	for i: int in range(ACCENT_COUNT):
		_accent.append(_mote())


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
	_drift(_main, dt, 1.0)
	_drift(_accent, dt, ACCENT_RATE)
	_field.queue_redraw()


func _drift(motes: Array[Mote], dt: float, rate: float) -> void:
	for m: Mote in motes:
		m.at.y -= dt * rate * m.rise * UNIT
		m.at.x += sin(_t * WOBBLE_RATE + m.seed) * dt * WOBBLE_AMP * UNIT
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
static var _haze: GradientTexture2D = null


static func haze() -> GradientTexture2D:
	if _haze == null:
		_haze = GlassStyle.grad_tex(
			PackedColorArray([Color(FOG.r, FOG.g, FOG.b, 0.0),
				Color(FOG.r, FOG.g, FOG.b, 0.85)]),
			PackedFloat32Array([0.0, 1.0]), false,
			Vector2(0.5, 0.0), Vector2(0.5, 1.0))
	return _haze


func _draw() -> void:
	# The sky, then the fog it hazes into. Below FOG_BOTTOM the plates cover
	# everything, so the band stops where it stops being visible.
	draw_rect(Rect2(Vector2.ZERO, size), SKY, true)
	var top: float = size.y * FOG_TOP
	var span: float = size.y * (FOG_BOTTOM - FOG_TOP)
	draw_texture_rect(haze(), Rect2(Vector2(0.0, top), Vector2(size.x, span)), false)


func paint_motes(host: CanvasItem) -> void:
	var tex: GradientTexture2D = disc()
	var accent_a: float = ACCENT_ALPHA + sin(_t * 0.9) * ACCENT_BREATH
	_stamp(host, tex, _main, PARTICLES, MAIN_ALPHA)
	_stamp(host, tex, _accent, GLOW, accent_a)


func _stamp(host: CanvasItem, tex: GradientTexture2D, motes: Array[Mote],
		tint: Color, alpha: float) -> void:
	var col: Color = tint
	col.a = alpha
	for m: Mote in motes:
		var r: float = m.radius
		host.draw_texture_rect(tex,
			Rect2(m.at - Vector2(r, r) * 2.0, Vector2(r, r) * 4.0), false, col)
