class_name Motion
extends RefCounted
## The benchmark's two motion curves, sampled exactly.
##
## Both the CSS animations and the Pixi `tween()` runner drive progress through
## a cubic-bezier over the WHOLE iteration; Godot's `Tween` transitions are a
## different family and none of them lands on these curves. Rather than pick the
## nearest TRANS_*, the curve is sampled here and fed to `tween_method`, so a
## 640ms spring in this port overshoots by the same amount and at the same
## moment as the one on screen at localhost:5190.
##
## `EASING` (tokens.js:52). `keyframe` is the other half of the contract: a
## WAAPI keyframe list interpolates LINEARLY between offsets, with the easing
## applied once to the iteration — so the offsets are read at an already-eased t.

const OUT_SOFT: Array[float] = [0.22, 1.0, 0.36, 1.0]
const SPRING: Array[float] = [0.34, 1.56, 0.64, 1.0]
## The entrance curve — `heroIn` / `enemyIn` / `chromeIn` all share it
## (styles.css:739). Softer out than OUT_SOFT, and no overshoot: a fight opens
## by arriving, not by bouncing.
const ENTER: Array[float] = [0.2, 0.75, 0.3, 1.0]
## CSS `ease-in-out`, spelled out. The stage plates drift on it
## (styles.css:684) and so does the HP preview pulse.
const EASE_IN_OUT: Array[float] = [0.42, 0.0, 0.58, 1.0]
## CSS `ease`, spelled out — the stylesheet's default transition curve; the
## ghost rail falls on it (styles.css:835).
const CSS_EASE: Array[float] = [0.25, 0.1, 0.25, 1.0]
## CSS `ease-out`, spelled out — chipPop, blockPulse and the refusal shakes
## all declare it (styles.css:891, :859, :611).
const CSS_EASE_OUT: Array[float] = [0.0, 0.0, 0.58, 1.0]
## The HP fill glide, shared by the actor rail and the run chrome rail
## (styles.css:834, :182).
const HP_FILL: Array[float] = [0.3, 1.0, 0.4, 1.0]
## The screen-transition family — iris, bloom, crack and the act plate all
## run on this one curve (navigation.js:45-59).
const TRANSIT: Array[float] = [0.4, 0.0, 0.2, 1.0]
## Every screen root's entrance (`screenIn`, styles.css:141-142).
const SCREEN_IN: Array[float] = [0.2, 0.7, 0.25, 1.0]
## The band-of-light wipe sweep (`wipeSweep`, styles.css:1530-1531).
const WIPE: Array[float] = [0.55, 0.0, 0.35, 1.0]
## The `nope` refusal shake (styles.css:610-611) — the one rule serves
## to both `.card.nope` and `.lantern-btn.nope`: 0.32s on the stylesheet's own
## `ease`, thrown −7px/−1.5° at 25% and +7px/+1.5° at 65%. Shared here for the
## same reason the stylesheet declares it once.
const NOPE_TIME: float = 0.32
const NOPE_AT: Array[float] = [0.0, 0.25, 0.65, 1.0]
const NOPE_X: Array[float] = [0.0, -7.0, 7.0, 0.0]
const NOPE_ROT: Array[float] = [0.0, -1.5, 1.5, 0.0]

## Bisection depth for the x→t solve. 18 halvings resolve a 640ms curve to
## well under a frame, and the loop is bounded rather than convergence-tested.
const SOLVE_STEPS: int = 18


static func _bezier(t: float, p1: float, p2: float) -> float:
	var c: float = 3.0 * p1
	var b: float = 3.0 * (p2 - p1) - c
	var a: float = 1.0 - c - b
	return ((a * t + b) * t + c) * t


## Progress through `curve` at linear time `x`. The curve is a CSS-style
## cubic-bezier: x is time, y is the value, and only the two control points move.
static func ease(curve: Array[float], x: float) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	var lo: float = 0.0
	var hi: float = 1.0
	var t: float = x
	for i: int in range(SOLVE_STEPS):
		var at: float = _bezier(t, curve[0], curve[2])
		if at < x:
			lo = t
		else:
			hi = t
		t = (lo + hi) * 0.5
	return _bezier(t, curve[1], curve[3])


## Drive `setter` with eased progress 0→1 over `dur` seconds. The Tween's own
## transition is pinned linear so the curve does all the shaping — any CSS
## cubic-bezier lands exactly rather than on the nearest TRANS_*. Returns the
## Tween so callers can kill or await it.
static func bez(host: Node, setter: Callable, dur: float, curve: Array[float]) -> Tween:
	var tw: Tween = host.create_tween()
	tw.tween_method(func(x: float) -> void: setter.call(Motion.ease(curve, x)), 0.0, 1.0, dur) \
		.set_trans(Tween.TRANS_LINEAR)
	return tw


## Read a keyframe track at eased progress `t`. `at` are the WAAPI offsets and
## `v` the values at them; between two offsets the value moves linearly, because
## that is what a keyframe list without per-keyframe easing does.
static func keyframe(t: float, at: Array[float], v: Array[float]) -> float:
	for i: int in range(1, at.size()):
		if t <= at[i]:
			var span: float = at[i] - at[i - 1]
			var f: float = 0.0 if span <= 0.0 else (t - at[i - 1]) / span
			return lerpf(v[i - 1], v[i], f)
	return v[v.size() - 1]


## The other keyframe contract, and the one the CSS `@keyframes` idles want. A
## WAAPI list eases once across the iteration (`keyframe` above); a CSS
## `animation-timing-function` eases EVERY interval, so `idleSlime`'s 0/33/66/100
## is three eased segments and reading a linear ramp at an eased t would move the
## stops in time. Same arguments, different contract — pick by which side the
## animation came from. `curve` is that declared timing function — `ease-in-out`
## for the idles, but `blockPulse` declares `ease-out` and gets CSS_EASE_OUT.
static func css_keyframe(u: float, at: Array[float], v: Array[float],
		curve: Array[float] = EASE_IN_OUT) -> float:
	for i: int in range(1, at.size()):
		if u <= at[i] or i == at.size() - 1:
			var span: float = at[i] - at[i - 1]
			var f: float = 0.0 if span <= 0.0 else clampf((u - at[i - 1]) / span, 0.0, 1.0)
			return lerpf(v[i - 1], v[i], Motion.ease(curve, f))
	return v[v.size() - 1]


## The two-stop case — `0%, 100% { a } 50% { b }` — which is most of them. Written
## out rather than routed through `css_keyframe` because `EASE_IN_OUT` is
## symmetric, and that makes easing the whole triangle identical to easing the
## rise and the fall apart: one `ease` call instead of a search plus a solve,
## sixty times a second per actor.
static func css_pulse(u: float, a: float, b: float) -> float:
	return lerpf(a, b, Motion.ease(EASE_IN_OUT, 1.0 - absf(u * 2.0 - 1.0)))


## Quadratic bezier — the shape both the aim arc and the mote flights travel on.
static func quad(p0: Vector2, c: Vector2, p1: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return u * u * p0 + 2.0 * u * t * c + t * t * p1
