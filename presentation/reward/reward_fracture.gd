class_name RewardFracture
extends RefCounted
## The reward lane's own copy of the enemy lane's fracture kit — `_clip`,
## `_voronoi` and `_prism` out of `presentation/combat/enemy_view.gd:3321-3459`,
## carried here because `docs/reward-embers-3d-plan.md` § cross-lane rules the
## duplication DELIBERATE: this lane may read that file and may not edit it,
## and a reward shard wants its own thickness and its own tags. If the two
## copies should ever converge, that is a shared-surface decision for the
## organiser, not a quiet import. The bug history travels with the code: the
## authored cap normals and the centroid origin are both paid-for lessons
## (domed caps read as plywood; body-space vertices made shards sweep arcs
## and land upright like headstones).


static func clip(poly: PackedVector2Array, a: Vector2, b: Vector2,
		big: float) -> PackedVector2Array:
	var mid: Vector2 = (a + b) * 0.5
	var n: Vector2 = (a - b).normalized()
	var t: Vector2 = Vector2(-n.y, n.x)
	var half: PackedVector2Array = PackedVector2Array([
		mid + t * big, mid - t * big, mid - t * big + n * big, mid + t * big + n * big,
	])
	var hit: Array[PackedVector2Array] = Geometry2D.intersect_polygons(poly, half)
	return hit[0] if not hit.is_empty() else PackedVector2Array()


## Voronoi cells for `sites` over a `box`-sized rect centred on the origin —
## the death-rite path only: the WHOLE body cut into panes, no reach disc.
static func voronoi(sites: PackedVector2Array, box: Vector2) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var hw: float = box.x * 0.5
	var hh: float = box.y * 0.5
	var big: float = box.y * 8.0
	var rect: PackedVector2Array = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	for i: int in range(sites.size()):
		var cell: PackedVector2Array = rect
		for j: int in range(sites.size()):
			if i == j:
				continue
			cell = clip(cell, sites[i], sites[j], big)
			if cell.is_empty():
				break
		if cell.size() >= 3:
			out.append(cell)
	return out


## The burst's sites: a ring of jittered points around where the blow landed,
## plus a few flung wide — the 12-18 band the concept argues for: enough to
## read as shattered, few enough that every piece is still a shape.
static func burst_sites(burst: Vector2, box: Vector2, rng: Rng) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var reach: float = minf(box.x, box.y)
	for ring: int in range(2):
		var count: int = 6 if ring == 0 else 5
		var r: float = reach * (0.16 + 0.30 * float(ring))
		for i: int in range(count):
			var a: float = TAU * float(i) / float(count) + rng.next() * 0.9
			out.append(burst + Vector2(cos(a), sin(a)) * (r * (0.7 + 0.6 * rng.next())))
	for i: int in range(4):
		out.append(Vector2(
			(rng.next() - 0.5) * box.x * 0.9,
			(rng.next() - 0.5) * box.y * 0.9))
	return out


## Extrude a cell into a real plate with thickness. Verbatim from the enemy
## lane save for the name: caps BLACK, side band RED in vertex colour, so a
## shard shader can pour the molten term only where COLOR.r says fracture.
## Normals are AUTHORED, never generated — generate_normals() domes every cap
## whose vertices all sit on the outline, which is every carved cap there is.
static func prism(cell: PackedVector2Array, thick: float, box: Vector2,
		origin: Vector2 = Vector2.ZERO) -> ArrayMesh:
	var tri: PackedInt32Array = Geometry2D.triangulate_polygon(cell)
	if tri.is_empty():
		return null
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z: float = thick * 0.5
	var mid: Vector2 = Vector2.ZERO
	for p: Vector2 in cell:
		mid += p
	mid /= float(cell.size())

	st.set_color(Color(0, 0, 0))
	for face: int in range(2):
		var zz: float = z if face == 0 else -z
		st.set_normal(Vector3(0.0, 0.0, 1.0 if face == 0 else -1.0))
		var i: int = 0
		while i < tri.size():
			for k: int in range(3):
				var at: int = tri[i + k] if face == 0 else tri[i + (2 - k)]
				var p: Vector2 = cell[at]
				st.set_uv(Vector2(p.x / box.x + 0.5, 0.5 - p.y / box.y))
				st.add_vertex(Vector3(p.x - origin.x, p.y - origin.y, zz))
			i += 3
	st.set_color(Color(1, 0, 0))
	for i: int in range(cell.size()):
		var a: Vector2 = cell[i]
		var b: Vector2 = cell[(i + 1) % cell.size()]
		var edge: Vector2 = b - a
		if edge.length() <= 0.0:
			continue
		var out: Vector2 = Vector2(edge.y, -edge.x).normalized()
		if out.dot((a + b) * 0.5 - mid) < 0.0:
			out = -out
		st.set_normal(Vector3(out.x, out.y, 0.0))
		var quad: Array[Vector3] = [
			Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), Vector3(b.x, b.y, -z),
			Vector3(a.x, a.y, z), Vector3(b.x, b.y, -z), Vector3(a.x, a.y, -z),
		]
		for v: Vector3 in quad:
			st.set_uv(Vector2(v.x / box.x + 0.5, 0.5 - v.y / box.y))
			st.add_vertex(v - Vector3(origin.x, origin.y, 0.0))
	return st.commit()
