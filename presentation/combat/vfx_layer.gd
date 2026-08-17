class_name VfxLayer
extends Control
## The impact layer — sparks, rings, motes, screen flash, shake and hitstop.
## Ported from `src/vfx.js`, which is a single 2D canvas over the stage plus a
## shake transform on the world wrapper. Every coordinate here is stage px, the
## same as the benchmark's, because this project's viewport IS `pad-landscape`.
##
## Blending is the one thing a canvas does that a CanvasItem cannot: the
## benchmark flips `globalCompositeOperation` per particle. Godot fixes the mode
## per node, so the particles are split across two passes — additive and normal —
## and the flash rides a third on top, which is the paint order `tick()` uses.
##
## Not ported: `LITE`'s particle-count halving, a coarse-pointer budget this
## build does not have to meet.

## `ARCHETYPE_TONES` (vfx.js:354). What colour a landed blow throws.
const TONES: Dictionary = {
	"slash": Color(1.0, 1.0, 1.0),
	"pierce": Color(0.8117647, 0.9019608, 1.0),
	"blunt": Color(1.0, 0.84705883, 0.627451),
	"fire": Color(1.0, 0.6039216, 0.30196080),
	"poison": Color(0.827451, 0.6313726, 0.3529412),
	"void": Color(0.7882353, 0.6039216, 1.0),
	"ward": Color(0.62352943, 0.83137256, 1.0),
}

## `ENEMY_KIND_VFX` (drain.js:60) — which blow language a body speaks.
const KIND_ARCHETYPE: Dictionary = {
	"beast": "slash", "rogue": "slash", "knight": "slash", "sovereign": "slash",
	"humanoid": "slash",
	"golem": "blunt", "treeboss": "blunt", "crab": "blunt", "leviathan": "blunt",
	"zombie": "blunt",
	"serpent": "pierce", "crawler": "pierce", "maw": "pierce", "plant": "pierce",
	"wisp": "void", "shade": "void", "eye": "void", "siren": "void", "cultist": "void",
	"slime": "poison",
}

## Above this many live particles the oldest are dropped rather than the newest
## refused: a death throwing 56 sparks must not be starved by the burst before
## it. The benchmark has no cap — a browser canvas can afford one more draw call
## than we can, and 400 is roughly four simultaneous deaths.
const MAX_PARTS: int = 400
## `ring` AND `slash` NEVER REACH THE SCREEN ON THE BENCHMARK, and that is not a
## style call — it is a latent bug in `vfx.js` that this port accidentally
## repaired into a visible effect.
##
## The draw loop advances every particle unconditionally (vfx.js:83):
##
##     for (const p of parts) { p.x += p.vx * dt; p.y += p.vy * dt; ... }
##
## and `ring()` (:179), `slashArc()` (:183) and `implosion()`'s collapsing ring
## (:443) are the ONLY three pushes in the whole file that carry no `vx`/`vy`.
## On their first frame `undefined * dt` turns BOTH coordinates into NaN, and
## `ctx2.arc(NaN, NaN, r)` contributes nothing to the path. Every other kind sets
## a velocity, so every other kind draws.
##
## Measured on the running benchmark rather than argued from the source: each
## primitive fired on its own and the non-transparent pixels on `#vfx` counted —
## burst 3054, motes 2016, ring 0, slashArc 0, at both 80ms and 200ms.
##
## `Part` below declares `vel: Vector2 = Vector2.ZERO`, so the same arithmetic is
## a harmless add of nothing instead of a NaN. That one typed default is the
## whole reason this port grew two expanding hoops on every killing blow and a
## rainbow arc over every slash, neither of which the benchmark has ever drawn.
##
## THE CALL SITES STAY. All nineteen are faithful to `drain.js` and to
## `archetypeHit`, and deleting them would throw away the record of what the
## benchmark asks for. What changes is that the two kinds never enter the list.
## Turning this on renders the benchmark's INTENT — which is a different game
## from the benchmark, and so is a deliberate departure, not a fix.
const DEAD_KINDS_RENDER: bool = false
## The two kinds `vfx.js` NaNs out before they can draw.
const DEAD_KINDS: Array[String] = ["ring", "slash"]

## Shake decays by this factor per second (`shakeV *= 0.001^dt`).
const SHAKE_DECAY: float = 0.001
const SHAKE_FLOOR: float = 0.1

## `theme.weather` for act 1 (`packs/core/themes.js:21`) — ash. One fleck a
## second, falling slowly, and one in twenty is an ember drifting upward.
## Inlined because the slice exporter carries no theme record; the day it does,
## `set_weather` takes one.
const ASH_RATE: float = 1.0
const ASH_COLOURS: Array[Color] = [
	Color(0.72156864, 0.6901961, 0.627451),   # #b8b0a0
	Color(0.5411765, 0.5137255, 0.47058824),  # #8a8378
]
const ASH_EMBER: Color = Color(1.0, 0.81960785, 0.4)  # #ffd166
const ASH_VX: Vector2 = Vector2(-6.0, 6.0)
const ASH_VY: Vector2 = Vector2(10.0, 26.0)
const ASH_SIZE: Vector2 = Vector2(1.4, 2.6)
const ASH_DRIFT: float = 0.4
const ASH_EMBER_RATE: float = 0.5
## `life: 9, fade: 3` — a fleck crosses the stage rather than blinking out.
const ASH_LIFE: float = 9.0
const ASH_FADE: float = 3.0
## `weather.boss ? 1.4 : 1` — a boss's air is thicker.
const ASH_BOSS_MULT: float = 1.4


## A WAAPI flight riding on a particle: three control points, the keyframe
## offsets, what scale and alpha read at each, and the one easing the iteration
## runs through.
##
## `flyTo` (combat.js:1420) is the only thing in the benchmark's effect language
## that is NOT a `vfx.js` particle. It builds DOM elements and hands them to
## `Element.animate`, so nothing accelerates them — the browser interpolates a
## position and the mote goes exactly there. A particle carrying a Flight
## therefore skips the integrator entirely; `grav` and `drag` stay off.
##
## A quadratic Bézier and a projectile are the same parabola, so the physics
## version of this was not wrong in shape. It was wrong in where it went: with
## drag on and a fixed upward bias it under-lifted by roughly 5x and never
## landed on the target, which is the whole point of a mote flight.
class Flight:
	extends RefCounted
	var p0: Vector2 = Vector2.ZERO
	var p1: Vector2 = Vector2.ZERO
	var p2: Vector2 = Vector2.ZERO
	var at: Array[float] = []
	var scale: Array[float] = []
	var alpha: Array[float] = []
	var ease: Array[float] = []


## One live particle. A class rather than the benchmark's object literal because
## every field here is read once per frame per particle, and a Dictionary makes
## each of those a Variant unbox that the type gate then refuses to let through
## silently.
class Part:
	extends RefCounted
	var kind: String = "dot"
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var size: float = 3.0
	var colour: Color = Color.WHITE
	var grav: float = 0.0
	var drag: float = 0.0
	var life: float = 0.5
	var fade: float = 0.3
	var additive: bool = true
	var alpha: float = 1.0
	## What `life` started at. The fade tail is measured from the END of a life;
	## a keyframe list is read from the START of one, so a part on a Flight needs
	## both to know where in its own animation it is.
	var life0: float = 0.5
	## Held before the part exists at all — not drawn, not stepped, not aged.
	## `delay: i * 46` is what makes a mote flight read as a stream leaving the
	## body rather than a puff appearing at it.
	var delay: float = 0.0
	## Non-null on the mote flight only. Every other recipe wants the plain fade
	## tail, so a null Flight leaves the old behaviour exactly where it was.
	var flight: Flight = null
	## ring
	var r: float = 0.0
	var vr: float = 0.0
	## slash
	var prog: float = 0.0
	var dur: float = 0.14
	var a0: float = 0.0
	var arc: float = 0.0
	## An ambient fleck rather than an event's spark: cleared wholesale when the
	## weather changes, and never counted against a burst's budget.
	var weather: bool = false


## A full-stage colour wash.
class Wash:
	extends RefCounted
	var colour: Color = Color.WHITE
	var alpha: float = 0.18
	var dur: float = 0.25
	var life: float = 0.25


## One pass over the particle list. Two of these exist per layer, one additive
## and one not, because the blend mode is a property of the node.
class Pass:
	extends Control
	var src: VfxLayer
	var additive: bool = false

	func _draw() -> void:
		if src != null:
			src.paint_parts(self, additive)


## The full-stage colour washes, painted last and never additively.
class FlashPass:
	extends Control
	var src: VfxLayer

	func _draw() -> void:
		if src != null:
			src.paint_flashes(self)


var _parts: Array[Part] = []
var _flashes: Array[Wash] = []
var _norm: Pass
var _add: Pass
var _flash_pass: FlashPass
## The node the shake moves. The benchmark shakes `#shake`, which wraps the
## screen, the mesh, the lantern and the HUD — everything but the effect canvas
## itself, which is why sparks hang still while the world jolts under them.
var _shake_host: Control = null
var _shake_v: float = 0.0
var _shake_at: Vector2 = Vector2.ZERO
var _hitstop_left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## `weather` / `weatherAcc` — off until a fight turns it on, and the accumulator
## is what makes a fractional rate emit at all.
var _weather: bool = false
var _weather_mult: float = 1.0
var _weather_acc: float = 0.0


func _init(shake_host: Control = null) -> void:
	_shake_host = shake_host
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_norm = Pass.new()
	_norm.src = self
	_norm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_norm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_norm)
	_add = Pass.new()
	_add.src = self
	_add.additive = true
	_add.set_anchors_preset(Control.PRESET_FULL_RECT)
	_add.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add.material = mat
	add_child(_add)
	_flash_pass = FlashPass.new()
	_flash_pass.src = self
	_flash_pass.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_pass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_pass)


func _process(delta: float) -> void:
	var dt: float = minf(0.05, delta)
	# `if (t < hitstopUntil) return` — the sim holds and the canvas is not
	# cleared, so the frame the blow landed on hangs in the air.
	if _hitstop_left > 0.0:
		_hitstop_left -= dt
		return
	_step_weather(dt)
	_step_parts(dt)
	_step_flashes(dt)
	_step_shake(dt)
	_norm.queue_redraw()
	_add.queue_redraw()
	_flash_pass.queue_redraw()


## `setWeather(theme.weather, {boss})` — the air the fight happens in. Off
## clears the flecks already in it, which is what leaving combat does.
func set_weather(on: bool, boss: bool = false) -> void:
	_weather = on
	_weather_mult = ASH_BOSS_MULT if boss else 1.0
	_weather_acc = 0.0
	if not on:
		var kept: Array[Part] = []
		for p: Part in _parts:
			if not p.weather:
				kept.append(p)
		_parts = kept


func _step_weather(dt: float) -> void:
	if not _weather or size.x <= 0.0:
		return
	_weather_acc += dt * ASH_RATE * _weather_mult
	while _weather_acc >= 1.0:
		_weather_acc -= 1.0
		var ember: bool = _rng.randf() < ASH_EMBER_RATE * 0.1
		var p: Part = Part.new()
		p.kind = "dot"
		p.weather = true
		p.pos = Vector2(_rng.randf() * size.x, size.y + 6.0 if ember else -6.0)
		p.vel = Vector2(
			randfr(ASH_VX),
			-randfr(Vector2(14.0, 34.0)) if ember else randfr(ASH_VY))
		p.size = randfr(ASH_SIZE) * (1.3 if ember else 1.0)
		p.colour = ASH_EMBER if ember else ASH_COLOURS[_rng.randi() % ASH_COLOURS.size()]
		p.drag = ASH_DRIFT * 0.1
		p.life = ASH_LIFE
		p.fade = ASH_FADE
		p.additive = ember
		p.alpha = 0.9 if ember else 0.35
		_push(p)


func randfr(range_v: Vector2) -> float:
	return range_v.x + _rng.randf() * (range_v.y - range_v.x)


## How far through its own animation a part is, 0 at spawn and 1 at the end.
static func _age01(p: Part) -> float:
	return clampf(1.0 - p.life / maxf(0.001, p.life0), 0.0, 1.0)


func _step_parts(dt: float) -> void:
	var live: Array[Part] = []
	for p: Part in _parts:
		if p.delay > 0.0:
			p.delay -= dt
			live.append(p)
			continue
		p.life -= dt
		if p.life <= 0.0:
			continue
		if p.flight != null:
			var t: float = Motion.ease(p.flight.ease, _age01(p))
			var u: float = 1.0 - t
			p.pos = p.flight.p0 * (u * u) \
				+ p.flight.p1 * (2.0 * u * t) \
				+ p.flight.p2 * (t * t)
			live.append(p)
			continue
		p.pos += p.vel * dt
		p.vel.y += p.grav * dt
		p.vel *= 1.0 - p.drag * dt
		if p.kind == "ring":
			p.r += p.vr * dt
		elif p.kind == "slash":
			p.prog = minf(1.0, p.prog + dt / p.dur)
		live.append(p)
	_parts = live


func _step_flashes(dt: float) -> void:
	var live: Array[Wash] = []
	for f: Wash in _flashes:
		f.life -= dt
		if f.life > 0.0:
			live.append(f)
	_flashes = live


## The spring in `tick()`: a random offset each frame, shrinking geometrically.
func _step_shake(dt: float) -> void:
	if _shake_host == null:
		return
	if _shake_v > SHAKE_FLOOR or absf(_shake_at.x) > SHAKE_FLOOR:
		_shake_at = Vector2(
			(_rng.randf() - 0.5) * _shake_v,
			(_rng.randf() - 0.5) * _shake_v)
		_shake_v *= pow(SHAKE_DECAY, dt)
		_shake_host.position = _shake_at
	elif _shake_host.position != Vector2.ZERO:
		_shake_host.position = Vector2.ZERO
		_shake_at = Vector2.ZERO
		_shake_v = 0.0


func paint_parts(host: CanvasItem, additive: bool) -> void:
	for p: Part in _parts:
		if p.additive != additive or p.delay > 0.0:
			continue
		var a: float = minf(1.0, p.life / maxf(0.001, p.fade))
		# The size multiplier. Without a Flight it IS the fade, which is what
		# every particle here has always done: shrink as it goes out.
		var grow: float = a
		if p.flight != null:
			var t: float = Motion.ease(p.flight.ease, _age01(p))
			grow = Motion.keyframe(t, p.flight.at, p.flight.scale)
			a = Motion.keyframe(t, p.flight.at, p.flight.alpha)
		var col: Color = p.colour
		col.a = a * p.alpha
		match p.kind:
			"spark":
				# A streak drawn back along its own velocity — the faster it
				# flies the longer it reads.
				var length: float = p.vel.length() * 0.045 + 2.0
				var back: Vector2 = p.pos - p.vel.normalized() * length
				host.draw_line(p.pos, back, col, maxf(0.5, p.size * grow), true)
			"ring":
				host.draw_arc(p.pos, maxf(0.5, p.r), 0.0, TAU, 48, col,
					maxf(0.5, p.size * grow), true)
			"slash":
				var sweep: float = p.arc * p.prog
				for i: int in range(3):
					var band: Color = col
					band.a = a * (0.9 - float(i) * 0.3)
					var w: float = (p.size - float(i) * 3.0) * (1.0 - p.prog * 0.6)
					if w <= 0.0:
						continue
					host.draw_arc(p.pos, p.r + float(i) * 7.0, p.a0, p.a0 + sweep,
						28, band, w, true)
			_:
				host.draw_circle(p.pos, maxf(0.5, p.size * grow), col, true, -1.0, true)


func paint_flashes(host: CanvasItem) -> void:
	for f: Wash in _flashes:
		var col: Color = f.colour
		col.a = (f.life / maxf(0.001, f.dur)) * f.alpha
		host.draw_rect(Rect2(Vector2.ZERO, size), col)


func _push(p: Part) -> void:
	# See DEAD_KINDS_RENDER. Dropped here rather than at each of the nineteen
	# call sites, so `implosion`'s ring is caught by the same rule that catches
	# `ring()` — on the benchmark it is dead for exactly the same reason.
	if not DEAD_KINDS_RENDER and DEAD_KINDS.has(p.kind):
		return
	if _parts.size() >= MAX_PARTS:
		_parts.remove_at(0)
	_parts.append(p)


## Probe receipt only: the release-budget harness must prove that its requested
## peak load reached this real always-rendered layer and survived the sample.
func performance_particles() -> int:
	var count: int = 0
	for p: Part in _parts:
		if not p.weather:
			count += 1
	return count


func performance_burst(at: Vector2, count: int, life: float) -> int:
	for i: int in count:
		var a: float = TAU * float(i) / float(count)
		var p: Part = _spawn("spark", at, Vector2(cos(a), sin(a)) * 360.0,
			4.0, GlassStyle.GOLD, life, 0.25)
		p.grav = 220.0
		p.drag = 1.6
		p.additive = true
	return performance_particles()


func _spawn(kind: String, at: Vector2, vel: Vector2, sz: float, colour: Color,
		life: float, fade: float) -> Part:
	var p: Part = Part.new()
	p.kind = kind
	p.pos = at
	p.vel = vel
	p.size = sz
	p.colour = colour
	p.life = life
	p.life0 = life
	p.fade = fade
	_push(p)
	return p


# ---------------------------------------------------------------- primitives

func shake(power: float = 8.0) -> void:
	# The player's hand on the camera: SCREEN SHAKE off stills the room, and
	# REDUCE MOTION implies it — the hit's flash, floaters and numbers all
	# still land, so nothing informational rides on this early-out.
	if not Preferences.active.screen_shake or Preferences.active.reduce_motion:
		return
	_shake_v = maxf(_shake_v, power)


func hitstop(ms: float = 60.0) -> void:
	_hitstop_left = maxf(_hitstop_left, ms / 1000.0)


func flash(colour: Color, alpha: float = 0.18, dur: float = 0.25) -> void:
	var w: Wash = Wash.new()
	w.colour = colour
	w.alpha = alpha
	w.dur = dur
	w.life = dur
	_flashes.append(w)


## `burst` (vfx.js:171). `angle`/`spread` aim it; the default is a full circle.
func burst(at: Vector2, colour: Color, n: int = 18, speed: float = 260.0,
		spread: float = TAU, angle: float = 0.0, sz: float = 3.0,
		grav: float = 300.0, kind: String = "spark", add: bool = true,
		life: float = 0.5) -> void:
	for i: int in range(n):
		var a: float = angle + (_rng.randf() - 0.5) * spread
		var v: float = speed * (0.35 + _rng.randf() * 0.75)
		var p: Part = _spawn(kind, at, Vector2(cos(a), sin(a)) * v,
			sz * (0.6 + _rng.randf() * 0.8), colour,
			life * (0.6 + _rng.randf() * 0.8), 0.25)
		p.grav = grav
		p.drag = 1.6
		p.additive = add


func ring(at: Vector2, colour: Color, r0: float = 8.0, speed: float = 420.0,
		sz: float = 4.0) -> void:
	var p: Part = _spawn("ring", at, Vector2.ZERO, sz, colour, 0.45, 0.45)
	p.r = r0
	p.vr = speed


func slash_arc(at: Vector2, colour: Color) -> void:
	var p: Part = _spawn("slash", at, Vector2.ZERO, 13.0, colour, 0.3, 0.18)
	p.r = 46.0 + _rng.randf() * 18.0
	p.a0 = -PI * 0.85 + (_rng.randf() - 0.5) * 0.6
	p.arc = PI * 0.8
	p.dur = 0.14


func motes(at: Vector2, colour: Color, n: int = 10) -> void:
	for i: int in range(n):
		var from: Vector2 = at + Vector2(
			(_rng.randf() - 0.5) * 60.0, (_rng.randf() - 0.5) * 40.0)
		var p: Part = _spawn("dot", from,
			Vector2((_rng.randf() - 0.5) * 30.0, -40.0 - _rng.randf() * 60.0),
			2.5 + _rng.randf() * 2.5, colour, 0.9 + _rng.randf() * 0.5, 0.5)
		p.grav = -20.0
		p.alpha = 0.9


func ember_trail(from: Vector2, to: Vector2, colour: Color) -> void:
	var n: int = 14
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var at: Vector2 = from.lerp(to, t) + Vector2(
			(_rng.randf() - 0.5) * 26.0, (_rng.randf() - 0.5) * 26.0)
		var p: Part = _spawn("dot", at,
			Vector2((_rng.randf() - 0.5) * 40.0, -30.0 - _rng.randf() * 50.0),
			2.0 + _rng.randf() * 2.4, colour, 0.5 + t * 0.4, 0.3)
		p.grav = -30.0
		p.alpha = 0.9


func droplets(at: Vector2, colour: Color, n: int = 12) -> void:
	for i: int in range(n):
		var from: Vector2 = at + Vector2(
			(_rng.randf() - 0.5) * 54.0, -10.0 + (_rng.randf() - 0.5) * 30.0)
		var p: Part = _spawn("dot", from,
			Vector2((_rng.randf() - 0.5) * 26.0, 60.0 + _rng.randf() * 120.0),
			2.0 + _rng.randf() * 2.0, colour, 0.6 + _rng.randf() * 0.3, 0.35)
		p.grav = 420.0
		p.drag = 0.4


## The void hit: a ring collapsing inward while sparks fall into the centre.
func implosion(at: Vector2, colour: Color) -> void:
	var r: Part = _spawn("ring", at, Vector2.ZERO, 3.5, colour, 0.4, 0.4)
	r.r = 64.0
	r.vr = -160.0
	for i: int in range(16):
		var a: float = _rng.randf() * TAU
		var dir: Vector2 = Vector2(cos(a), sin(a))
		var v: float = 220.0 + _rng.randf() * 120.0
		var p: Part = _spawn("spark", at + dir * (46.0 + _rng.randf() * 30.0),
			-dir * v, 2.2, colour, 0.34, 0.2)
		p.drag = 2.4


## Ward chipping off: a fan of shards thrown upward.
func shard_spray(at: Vector2, colour: Color, n: int = 12) -> void:
	for i: int in range(n):
		var a: float = -PI / 2.0 + (_rng.randf() - 0.5) * 1.8
		var v: float = 200.0 + _rng.randf() * 260.0
		var p: Part = _spawn("spark", at, Vector2(cos(a), sin(a)) * v,
			2.6 + _rng.randf() * 1.6, colour, 0.5 + _rng.randf() * 0.3, 0.22)
		p.grav = 520.0
		p.drag = 0.6


## `delay: i * 46` — 46ms between motes (combat.js:1457). The single knob that
## decides whether this reads as a stream leaving a body or a puff appearing at
## one.
const FLY_STAGGER: float = 0.046
## The one easing, run over the whole iteration.
const FLY_EASE: Array[float] = [0.32, 0.05, 0.35, 1.0]
## The three keyframe stops. Opacity opens at 0 and never returns there: a mote
## arrives and is gone with the animation, it does not fade out on the stage.
const FLY_AT: Array[float] = [0.0, 0.45, 1.0]
const FLY_SCALE: Array[float] = [0.5, 1.05, 0.55]
const FLY_ALPHA: Array[float] = [0.0, 1.0, 0.95]
## The mid control point: `(x0 + x1) / 2 ± 70` across, and 50 to 130 above
## whichever end is higher. Every mote draws its own, which is the only reason
## a flight of them reads as more than one line.
const FLY_SPREAD: float = 140.0
const FLY_LIFT: float = 50.0
const FLY_LIFT_VARY: float = 80.0


## Embers travelling between two points — the spill toward the lantern, poison
## jumping foes, a power settling into the hero. `flyTo` (combat.js:1420).
##
## `sz` is the benchmark's `size` and stays in the benchmark's units so a call
## site can be read against `drain.js` — but there `size` sets a DOM element's
## width, so it is a DIAMETER. Every other size in this file is a radius,
## because `vfx.js` draws its particles with `arc(x, y, p.size * a)` (vfx.js:121)
## and that argument is one. The port carried 6 and 7 straight across and drew
## every mote at twice the benchmark's.
func fly_to(from: Vector2, to: Vector2, colour: Color, n: int = 6,
		sz: float = 6.0, dur: float = 0.5) -> void:
	for i: int in range(n):
		var f: Flight = Flight.new()
		f.p0 = from
		f.p1 = Vector2(
			(from.x + to.x) * 0.5 + (_rng.randf() - 0.5) * FLY_SPREAD,
			minf(from.y, to.y) - FLY_LIFT - _rng.randf() * FLY_LIFT_VARY)
		f.p2 = to
		f.at = FLY_AT
		f.scale = FLY_SCALE
		f.alpha = FLY_ALPHA
		f.ease = FLY_EASE
		var p: Part = _spawn("dot", from, Vector2.ZERO, sz * 0.5, colour,
			dur, dur)
		p.flight = f
		p.delay = float(i) * FLY_STAGGER


## `archetypeHit` (vfx.js:393) — the one entry point every landed blow goes
## through, so a slash and a blunt hit never have to be spelled out at the call
## site. `power` is the damage normalised against 24.
func archetype_hit(at: Vector2, archetype: String, power: float = 0.3) -> void:
	var tone: Color = TONES.get(archetype, Color.WHITE)
	var big: bool = power > 0.55
	match archetype:
		"slash":
			slash_arc(at, Color(1.0, 0.84705883, 0.627451) if big else Color.WHITE)
			burst(at, Color(1.0, 0.6039216, 0.41568628), 26 if big else 12,
				420.0 if big else 260.0)
		"pierce":
			var a0: float = -PI * 0.78
			var dir: Vector2 = Vector2(cos(a0), sin(a0))
			for i: int in range(3 if big else 2):
				var p: Part = _spawn("spark", at - dir * 70.0, dir * 900.0,
					3.4, tone, 0.16 + float(i) * 0.03, 0.1)
				p.grav = 0.0
			burst(at, tone, 18 if big else 9, 300.0, 1.4, a0 + PI)
		"blunt":
			ring(at, tone, 6.0, 720.0 if big else 520.0, 6.0)
			burst(at + Vector2(0.0, 6.0), Color(0.9098039, 0.84705883, 0.72156864),
				24 if big else 12, 380.0 if big else 240.0, PI, -PI / 2.0,
				3.0, 620.0, "dot")
			shake(14.0 if big else 8.0)
		"fire":
			burst(at, Color(1.0, 0.81960785, 0.4), 22 if big else 12, 240.0,
				TAU, 0.0, 3.0, -120.0, "spark", true, 0.7)
			burst(at, Color(1.0, 0.41568628, 0.22745098), 14 if big else 8, 160.0,
				TAU, 0.0, 3.6, -60.0, "dot", true, 0.8)
		"poison":
			droplets(at, Color(0.827451, 0.6313726, 0.3529412), 18 if big else 10)
			motes(at, Color(0.72156864, 0.6901961, 0.627451), 8)
		"void":
			implosion(at, tone)
			if big:
				flash(Color(0.7882353, 0.6039216, 1.0), 0.08, 0.25)
		"ward":
			motes(at, tone, 8 if big else 5)


## `impactFrame` (vfx.js:435) — the white blink the signature cards open with.
func impact_frame() -> void:
	flash(Color.WHITE, 0.28, 0.09)
	hitstop(90.0)


## `BESPOKE_VFX` (vfx.js:436) — the signature moments. Eighteen cards and arts
## that get their OWN effect on top of their archetype's, fired once at the
## first impact of the play rather than on every hit of a multi-hit card.
##
## This is the layer that makes a big card feel big, and without it every card
## in the game looked like its family and nothing more. `impact_frame` was built
## with it in mind and then had no caller for the whole of M5.
##
## Written as a `match` rather than a table of `Callable`s: the reference's
## object literal buys dispatch, which `match` already gives, and a dictionary of
## lambdas is the kind of thing the typed gate cannot check.
func bespoke(id: String, at: Vector2) -> bool:
	match id:
		"annihilate":
			impact_frame()
			flash(Color(1.0, 0.41568628, 0.22745098), 0.16, 0.5)
			for dx: float in [-140.0, 0.0, 140.0]:
				burst(at + Vector2(dx, 0.0), Color(1.0, 0.81960785, 0.4), 18, 300.0,
					TAU, 0.0, 3.0, -100.0, "spark", true, 0.8)
			shake(16.0)
		"oblivionStrike":
			impact_frame()
			hitstop(140.0)
			ring(at, Color(1.0, 0.84705883, 0.627451), 8.0, 900.0, 7.0)
			ring(at, Color.WHITE, 4.0, 1200.0, 4.0)
			shard_spray(at, Color(0.8745098, 0.91764706, 1.0), 22)
			shake(20.0)
		"tempest":
			_volley(3, 0.09, at + Vector2(0.0, -60.0), 160.0,
				Color(0.8117647, 0.9019608, 1.0), 12, &"shards")
		"executioner":
			impact_frame()
			slash_arc(at, Color.WHITE)
			ring(at, Color(1.0, 0.41960785, 0.41960785), 10.0, 700.0, 5.0)
			shake(14.0)
		"novaflare":
			impact_frame()
			flash(Color(1.0, 0.81960785, 0.4), 0.2, 0.45)
			ring(at, Color(1.0, 0.81960785, 0.4), 6.0, 1000.0, 6.0)
			burst(at, Color(1.0, 0.9529412, 0.8392157), 30, 520.0, TAU, 0.0,
				3.0, -40.0, "spark", true, 0.9)
		"shardstorm":
			_volley(4, 0.07, at + Vector2(0.0, -40.0), 200.0,
				Color(0.8745098, 0.91764706, 1.0), 10, &"shards")
		"risingLitany":
			ember_trail(at + Vector2(0.0, 120.0), at + Vector2(0.0, -120.0),
				Color(1.0, 0.81960785, 0.4))
			motes(at + Vector2(0.0, -40.0), Color(1.0, 0.9137255, 0.6745098), 16)
		"limitBreak":
			impact_frame()
			ring(at, Color(0.56078434, 0.8156863, 1.0), 10.0, 800.0, 6.0)
			shard_spray(at, Color(0.8117647, 0.9019608, 1.0), 18)
			shake(12.0)
		"phantomBlades":
			_volley(4, 0.07, at, 0.0, Color(0.7882353, 0.6901961, 1.0), 0, &"blades")
		"pyreheart":
			burst(at, Color(1.0, 0.34901962, 0.39215687), 14, 180.0, TAU, 0.0,
				3.0, -80.0, "dot", true, 0.9)
			motes(at, Color(1.0, 0.81960785, 0.4), 10)
		"emberdance":
			_volley(3, 0.1, at, 0.0, Color(1.0, 0.6039216, 0.30196080), 0, &"embers")
		"devour":
			implosion(at, Color(0.7882353, 0.6039216, 1.0))
			_after(0.18, _volley_step.bind(&"devour", at,
				Color(1.0, 0.6039216, 0.30196080), 16, 0))
		"art:flare":
			flash(Color(1.0, 0.6039216, 0.30196080), 0.18, 0.4)
			burst(at, Color(1.0, 0.81960785, 0.4), 26, 420.0, TAU, 0.0, 3.0, -60.0)
			shake(10.0)
		"art:mendglass":
			ring(at, Color(0.49019608, 0.85882354, 0.56078434), 14.0, 420.0, 4.0)
			motes(at, Color(0.8509804, 0.9843137, 0.90588236), 14)
		"art:beacon":
			flash(Color(1.0, 0.9137255, 0.6745098), 0.14, 0.5)
			ember_trail(at + Vector2(0.0, 100.0), at + Vector2(0.0, -140.0),
				Color(1.0, 0.9137255, 0.6745098))
		"art:emberveil":
			ring(at, Color(0.62352943, 0.83137256, 1.0), 10.0, 520.0, 5.0)
			ring(at, Color(1.0, 0.81960785, 0.4), 20.0, 380.0, 3.0)
		"art:stoke":
			burst(at, Color(1.0, 0.41568628, 0.22745098), 18, 220.0, TAU, 0.0,
				3.0, -140.0, "spark", true, 0.8)
		"art:ashfall":
			_volley(3, 0.12, at + Vector2(0.0, -80.0), 220.0,
				Color(0.72156864, 0.6901961, 0.627451), 12, &"drops")
		_:
			return false
	return true


## The staggered volleys — `setTimeout(..., i * ms)` in four of the entries. The
## scatter is `Math.random()` there, so it is drawn here rather than fixed: a
## shardstorm that lands in the same four places every time is a pattern.
func _volley(n: int, gap: float, at: Vector2, spread: float, tone: Color,
		count: int, kind: StringName) -> void:
	for i: int in range(n):
		# Drawn now, not inside the callback: the scatter belongs to the shot
		# that was scheduled, and the RNG will have moved on by the time it fires.
		var jitter: Vector2 = Vector2((_rng.randf() - 0.5) * spread,
			(_rng.randf() - 0.5) * 40.0 if kind == &"blades" else 0.0)
		_after(gap * float(i), _volley_step.bind(kind, at + jitter, tone, count, i))


## One shot of a volley. A bound method rather than a closure: a multi-line
## lambda holding a `match` does not parse, and binding is what the gate can see.
func _volley_step(kind: StringName, at: Vector2, tone: Color, count: int,
		step: int) -> void:
	match kind:
		&"shards":
			shard_spray(at, tone, count)
		&"blades":
			slash_arc(at, tone)
		&"drops":
			droplets(at, tone, count)
		&"devour":
			burst(at, tone, count, 260.0, TAU, 0.0, 3.0, -120.0)
		&"embers":
			var off: float = -80.0 + float(step) * 80.0
			ember_trail(at + Vector2(off, 60.0), at + Vector2(-off, -60.0), tone)


## `setTimeout` — fire and forget. A volley that is still owed when the fight
## ends simply does not land, which is what the browser does with a pending
## timeout on a torn-down screen.
func _after(seconds: float, what: Callable) -> void:
	if seconds <= 0.0 or not is_inside_tree():
		what.call()
		return
	get_tree().create_timer(seconds).timeout.connect(what, CONNECT_ONE_SHOT)
