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


static func dist_to_polyline(pts: PackedVector2Array, p: Vector2) -> float:
	var best: float = INF
	for i: int in range(pts.size() - 1):
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
		var d: float = q.distance_to(p)
		if d < best:
			best = d
	return best


## Junction census, for the invariant that impact fracture is T-junctioned where
## Voronoi is Y-junctioned. A `T` is one strand ending ON another; a `Y` is three
## ends meeting at a point, which is what a simultaneous isotropic process makes
## and an impact does not (`docs/glass-crack-rendering.md` §3.1).
func junctions(tol: float) -> Dictionary:
	var t: int = 0
	for i: int in range(_points.size()):
		if _termini[i] == T_CRACK:
			t += 1
	var y: int = 0
	var ends: Array[Vector2] = []
	for pts: PackedVector2Array in _points:
		ends.append(pts[0])
		ends.append(pts[pts.size() - 1])
	for i: int in range(ends.size()):
		var near: int = 0
		for j: int in range(ends.size()):
			if i != j and ends[i].distance_to(ends[j]) <= tol:
				near += 1
		if near >= 2:
			y += 1
	# Each Y is counted once per participating end, so three coincident ends read
	# as three. Divided here so the number means "junctions", not "ends".
	return {"T": t, "Y": y / 3}
