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


## Quadratic bezier — the shape both the aim arc and the mote flights travel on.
static func quad(p0: Vector2, c: Vector2, p1: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return u * u * p0 + 2.0 * u * t * c + t * t * p1
