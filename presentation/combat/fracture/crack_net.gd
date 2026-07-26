class_name CrackNet
extends RefCounted
## Every crack a Vessel carries, and the only place they live. Append-only:
## `commit()` is the sole mutator, and nothing already committed can be reshaped.
##
## That is not tidiness. `enemy_view.gd`'s Voronoi web re-partitioned the whole
## plane on every hit, so landing blow N moved the shards of blows 1..N-1 — and a
## fracture cannot relocate. Making the net append-only turns that defect from
## *fixed* into **unrepresentable**, which is the difference between a bug that was
## corrected and a bug that cannot recur (`docs/glass-crack-rendering.md` §3.2).
##
## Coordinates are body UV, y down, 0..1. Lengths are body-relative.
##
## The renderer sees only the read accessors — no width, no colour, no depth, no
## Node. Those are optical properties and they are the renderer's to derive, so
## that its taste cannot leak into the model (`docs/fracture-model.md` §5.4).


## How a strand ended. The distinction is load-bearing for the renderer: a `T`
## groove must not overshoot the crack it met, an `S` is hidden by the silhouette,
## and an `F` must taper to literally nothing or it reads as a *cut* rather than as
## a fracture that ran out of stress.
const T_CRACK: StringName = &"T"
const T_SILHOUETTE: StringName = &"S"
const T_FREE: StringName = &"F"
const TERMINI: Array[StringName] = [T_CRACK, T_SILHOUETTE, T_FREE]

## Packed arrays have value semantics in GDScript, so handing one out is handing
## out a copy and a caller cannot reach back in. That is what makes the read
## accessors safe without defensive duplication on every call.
var _points: Array[PackedVector2Array] = []
var _arcs: Array[PackedFloat32Array] = []
var _termini: Array[StringName] = []
var _origins: Array[Vector2] = []


# ------------------------------------------------------------------ the mutator

## Add finished strands. Each is `{"points": PackedVector2Array,
## "terminus": StringName, "origin": Vector2}`; `origin` defaults to the first
## point when a caller has nothing better, which is the common case for a radial.
##
## Arc length is DERIVED here rather than accepted from the caller. The propagator
## already knows it, but a net that recomputes cannot be handed a strand whose
## stated length disagrees with its geometry — and the renderer's taper and reveal
## timing both read that number.
func commit(strands: Array) -> void:
	for s: Variant in strands:
		if typeof(s) != TYPE_DICTIONARY:
			push_error("CrackNet.commit: strand is not a Dictionary")
			continue
		var d: Dictionary = s
		var pts: PackedVector2Array = d.get("points", PackedVector2Array())
		if pts.size() < 2:
			push_error("CrackNet.commit: a strand needs at least two points")
			continue
		var term: StringName = d.get("terminus", T_FREE)
		if not TERMINI.has(term):
			push_error("CrackNet.commit: unknown terminus %s" % term)
			continue
		var arc: PackedFloat32Array = PackedFloat32Array()
		arc.resize(pts.size())
		arc[0] = 0.0
		for i: int in range(1, pts.size()):
			arc[i] = arc[i - 1] + pts[i - 1].distance_to(pts[i])
		_points.append(pts)
		_arcs.append(arc)
		_termini.append(term)
		_origins.append(d.get("origin", pts[0]))


# ------------------------------------------------------------- the renderer view

func strand_count() -> int:
	return _points.size()


func is_empty() -> bool:
	return _points.is_empty()


## Ordered origin → tip. The ordering is what lets a renderer reveal a crack
## growing without the model needing a clock.
func strand(i: int) -> PackedVector2Array:
	return _points[i]


## Cumulative length per vertex; `arc[0]` is always 0.
func arc(i: int) -> PackedFloat32Array:
	return _arcs[i]


func length(i: int) -> float:
	var a: PackedFloat32Array = _arcs[i]
	return a[a.size() - 1]


func terminus(i: int) -> StringName:
	return _termini[i]


## The blow this strand grew from — where `crackSvg` puts its glint.
func origin(i: int) -> Vector2:
	return _origins[i]


# ---------------------------------------------------------------- the model view

## Distance to the nearest crack, or INF when nothing has broken yet. The
## propagator's arrest test reads this, and INF rather than a large number so a
## caller cannot accidentally arrest a first crack against an empty net.
func nearest(p: Vector2) -> float:
	return dist_to_strands(_points, p)


## Is a strand already growing out of this point?
##
## `relieve()` needs this and could not work without it. The net is append-only, so a
## tip that has been carried the rest of the way out KEEPS its `T_FREE` terminus — the
## continuation is a new strand starting on it, and nothing rewrites the old one. That
## means "terminus is free" and "still an open tip" are different questions, and asking
## the first when you meant the second makes `relieve()` non-idempotent: called twice,
## it grows a second continuation from every tip it already continued.
##
## Worth guarding rather than documenting away — this codebase has already had a death
## beat fire twice (`c77b56b`).
func starts_at(p: Vector2, tol: float) -> bool:
	for pts: PackedVector2Array in _points:
		if pts[0].distance_to(p) <= tol:
			return true
	return false


## Every tip that is still open: free terminus, and nothing continuing from it. This is
## what the rite consumes and what a renderer must taper to nothing.
func open_tips() -> Array[int]:
	var out: Array[int] = []
	for i: int in range(_points.size()):
		if _termini[i] != T_FREE:
			continue
		var pts: PackedVector2Array = _points[i]
		if not starts_at(pts[pts.size() - 1], 1e-5):
			out.append(i)
	return out


## Where the segment `a`→`b` first crosses an existing crack, or `null`.
##
## This is the arrest test, and it is an INTERSECTION test rather than a proximity one
## because those are different questions and conflating them broke the model. Proximity
## cannot tell a crack that has run head-on into another from one running *alongside* it a
## few thousandths away — so near a cluster of blows, where the radials from each impact
## necessarily run close and roughly parallel, every new arm died on its second step
## against a neighbour it never touched. Six blows into a tight cluster and the sixth
## scored nothing.
##
## Proximity is already modelled, and better, by the propagator's capture term: a tip
## whose driving tension has been relieved to nothing by a nearby crack joins it. Two
## mechanisms, two distinct jobs, neither doing the other's.
##
## Static so the propagator can ask the same question of its own in-flight buffer — a
## crack arrests on any free surface regardless of when it was made.
static func crossing(strands: Array[PackedVector2Array], a: Vector2, b: Vector2) -> Variant:
	for pts: PackedVector2Array in strands:
		for i: int in range(pts.size() - 1):
			var hit: Variant = Geometry2D.segment_intersects_segment(
				a, b, pts[i], pts[i + 1])
			if hit != null:
				return hit
	return null


func first_crossing(a: Vector2, b: Vector2) -> Variant:
	return crossing(_points, a, b)


## WHERE the nearest crack is, not just how far. The propagator needs this on exactly
## one step — the one where a tip is captured by an existing crack and has to be given
## a final vertex ON that crack rather than three steps short of it.
##
## Undefined on an empty net, and deliberately not given a sentinel: every caller
## already holds a finite `nearest()` before it asks, and a `Vector2` sentinel would be
## a value that arithmetic silently accepts.
func nearest_point(p: Vector2) -> Vector2:
	var best: Vector2 = p
	var best_d: float = INF
	for pts: PackedVector2Array in _points:
		for i: int in range(pts.size() - 1):
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
			var d: float = q.distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = q
	return best


## Static so the propagator can ask the same question of its own in-flight buffer.
## A radial must be able to arrest on a sibling from the same blow — a crack
## arrests on any free surface regardless of when it was made — and the buffer is
## not in the net yet (`docs/fracture-model.md` §2.2).
static func dist_to_strands(strands: Array[PackedVector2Array], p: Vector2) -> float:
	var best: float = INF
	for pts: PackedVector2Array in strands:
		var d: float = dist_to_polyline(pts, p)
		if d < best:
			best = d
	return best


## Total run of a polyline. `commit` keeps its own cumulative loop because it needs
## the per-vertex array; this answers the other question — how long is it — which the
## propagator asks before it decides a strand is worth emitting.
static func arc_length(pts: PackedVector2Array) -> float:
	var run: float = 0.0
	for i: int in range(pts.size() - 1):
		run += pts[i].distance_to(pts[i + 1])
	return run


static func dist_to_polyline(pts: PackedVector2Array, p: Vector2) -> float:
	var best: float = INF
	for i: int in range(pts.size() - 1):
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
		var d: float = q.distance_to(p)
		if d < best:
			best = d
	return best


## Junction census, for the invariant that impact fracture is T-junctioned where
## Voronoi is Y-junctioned (`docs/glass-crack-rendering.md` §3.1).
##
## **Only TIPS count.** A strand's first point is where it was born — an impact
## point, or a bifurcation off its parent — and a birth is not a meeting. Counting
## starts as well reads a seven-armed star as seven Y-junctions, which inverts the
## very thing the census is for: a star radiating from one impact is the signature
## of impact fracture, and it is the opposite of the shrinkage pattern a Y means
## here. That mistake was in the first version of this function and
## `tools/check_fracture.gd` caught it by reporting 21 Y against 1 T on a set of
## perfectly well-formed strikes.
##
## So: `T` is a strand that arrested ON another crack. `Y` is three or more strands
## that all *ended* at the same place, which is what a simultaneous isotropic
## process makes and sequential arrest structurally cannot.
func junctions(tol: float) -> Dictionary:
	var t: int = 0
	for i: int in range(_points.size()):
		if _termini[i] == T_CRACK:
			t += 1
	var tips: Array[Vector2] = []
	for pts: PackedVector2Array in _points:
		tips.append(pts[pts.size() - 1])
	var y: int = 0
	for i: int in range(tips.size()):
		var near: int = 0
		for j: int in range(tips.size()):
			if i != j and tips[i].distance_to(tips[j]) <= tol:
				near += 1
		if near >= 2:
			y += 1
	# Counted once per participating tip, so three coincident tips read as three.
	# Divided so the number means "junctions" rather than "ends".
	return {"T": t, "Y": y / 3}
