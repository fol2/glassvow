class_name Carve
extends RefCounted
## The network becomes pieces. The last step of `docs/fracture-model.md`, and the one
## that makes `CONCEPTS.md` › Crack true: *the accumulated Cracks are the only thing the
## Death rite breaks along.*
##
## ### The whole idea
##
## A carve is a **boolean subtraction**, not a partition algorithm. Each strand is
## thickened into a ribbon exactly as wide as its groove, and the ribbon is subtracted
## from the body. Where a ribbon cuts the body in two, the subtraction *returns* two
## polygons — Clipper2, behind `Geometry2D`, already does the disconnection detection
## that a hand-rolled planar arrangement would need face traversal and angular sorting
## at every vertex to get right.
##
## It is also the physically apt statement: the material in the groove is **gone**. The
## kerf is the groove's own width, so the gap the shards leave between them is the gap
## the player was already looking at. §3 asks for exactly that — one physical quantity,
## two consumers, where the alternative is two numbers tuned apart until they agree.
##
## ### The ribbons MUST be unioned first, and that is not an optimisation
##
## Subtracting them one at a time does not work, and the way it fails is instructive.
## A ribbon that lies wholly inside a piece is a **hole**, so `clip_polygons` correctly
## returns the unchanged outer boundary plus a clockwise hole outline. Drop the hole — as
## anything must, since the API takes single polygons and cannot carry holes forward — and
## the cut is *thrown away*: the next subtraction operates on a piece that has forgotten
## every previous one. Six relieved blows carved a body into exactly one shard, sixty-six
## times in a row, each step dropping precisely one hole.
##
## Welded into connected knives first, the subtraction sees the whole corridor system at
## once and Clipper does the face extraction in a single pass: the same net that gave one
## shard gives seventeen. Two fold rounds suffice on a real network.
##
## ### What it deliberately does not do
##
## **Holes are still dropped, and now that is correct.** After welding, a hole can only
## come from a knife component that is entirely enclosed by a piece — an isolated slit
## that separates nothing. The enclosed region of a crack *loop* is a different thing and
## comes out as its own shard from the weld, not as a hole.
##
## **Shards are not convex, and the collider is a hull.** `ConvexPolygonShape3D` takes
## the convex hull of a concave shard. For debris that tumbles and crumbles to embers in
## two seconds, that is the standard trade and the mesh is still the true shape.
##
## Pure: `Geometry2D` and nothing else. Coordinates are body UV, y down, 0..1 — the
## caller converts to whatever space its meshes live in.


## How far past the silhouette a knife runs, in body fractions.
##
## A crack that ended on the creature's edge stops THERE, which is not the edge of the
## UV square — so its ribbon stops short too, and the two shards it should have separated
## stay joined by a bridge of empty box. That bridge renders as nothing (the shard shader
## samples the painting's alpha) and yet moves as one piece, which is the worst of both:
## invisible and wrong.
##
## Continuing the cut through empty space costs nothing and is what a real fracture does
## — the crack reached a free surface, so the separation is complete. Applied only to
## `S` termini; see `shards()` for why an `F` tip must not be extended.
const OVERSHOOT: float = 0.6

## Below this, in body², a piece is a speck rather than a shard.
##
## DERIVED, not inherited. The disc path's floor is 0.00003 of the quad, which was right
## for convex Voronoi cells and is far too permissive here: a carved network throws long
## thin offcuts along its junctions, and at 0.00003 the smallest shard measured on a
## duskfang was 0.0055 body across — one pixel at a 185 px actor, invisible, and still
## paying for a `RigidBody3D`, a mesh and a collider.
##
## A piece has to be a few groove-widths across before it reads as a piece rather than as
## grit. The groove is 0.0145 body wide, so at three times that a shard spans 0.0435 and
## a roughly square one covers 0.0019. Halved, because a shard is usually a sliver rather
## than a square and the long ones are legible at less area than a compact one.
const MIN_AREA: float = 0.0009


## Cut `net` out of the unit body square. Returns closed, counter-clockwise polygons in
## body UV.
##
## `kerf` is the groove's HALF-width — pass `CrackField.APERTURE`, which is the single
## source of that number. It is deliberately a parameter rather than a constant in here:
## the width is optical, it belongs to the renderer, and `docs/fracture-model.md` §5.4 is
## explicit that letting the model own a width lets the renderer's taste leak into it.
## The wiring layer owns both and hands one number to each.
static func shards(net: CrackNet, kerf: float,
		min_area: float = MIN_AREA) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = [PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])]
	if net.is_empty() or kerf <= 0.0:
		return pieces
	for knife: PackedVector2Array in _weld(_ribbons(net, kerf)):
		pieces = _subtract(pieces, knife)
	var out: Array[PackedVector2Array] = []
	for p: PackedVector2Array in pieces:
		if p.size() >= 3 and area(p) >= min_area:
			out.append(p)
	return out


## Every strand as a ribbon of its groove's width.
##
## `JOIN_ROUND` because a mitred join on a crack that turns sharply throws a spike far
## outside the groove and slices a piece the player never saw a crack in.
##
## `END_ROUND` and this one is load-bearing. With `END_BUTT`, two strands meeting at a
## point — every arm of one blow shares its origin, every `T` ends on another crack —
## produce ribbons that touch only AT that point, leaving the region pinched rather than
## cut. A round cap overlaps them by the groove's own half-width, which is also the truer
## shape: the groove at an impact point is a bowl, not two abutting slots.
static func _ribbons(net: CrackNet, kerf: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for i: int in range(net.strand_count()):
		var path: PackedVector2Array = _knife(net, i)
		if path.size() < 2:
			continue
		for r: PackedVector2Array in Geometry2D.offset_polyline(
				path, kerf, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
			out.append(r)
	return out


## Union overlapping ribbons into connected knives. See the docblock: without this the
## carve returns the body in one piece.
##
## To a fixpoint rather than in one pass, because ribbon A and ribbon C may only become
## mergeable after B has joined them. Two rounds is what a real network takes; the cap is
## a runaway guard and not a limit anyone is expected to reach.
##
## A merge is accepted only when it collapses two outlines into ONE. A result with two
## outlines means they never touched; a result with more means they joined around a hole,
## and taking that would put a clockwise hole outline into the knife set where the
## subtraction below would read it as a region to remove.
static func _weld(ribbons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var knives: Array[PackedVector2Array] = ribbons
	for _round: int in range(8):
		var joined: bool = false
		var out: Array[PackedVector2Array] = []
		for r: PackedVector2Array in knives:
			var cur: PackedVector2Array = r
			var cur_box: Rect2 = _bounds(cur)
			var rest: Array[PackedVector2Array] = []
			for k: PackedVector2Array in out:
				# Bounds first: a merge is a Clipper call and most pairs are nowhere near
				# each other, so this is the difference between n log n-ish and n².
				if not _bounds(k).intersects(cur_box):
					rest.append(k)
					continue
				var u: Array[PackedVector2Array] = Geometry2D.merge_polygons(cur, k)
				if u.size() == 1:
					cur = u[0]
					cur_box = _bounds(cur)
					joined = true
				else:
					rest.append(k)
			rest.append(cur)
			out = rest
		knives = out
		if not joined:
			break
	return knives


## One strand as a cutting path: its own points, with the tip continued past the
## silhouette when it reached one.
##
## An `F` tip is NOT extended. A strand that stopped for want of tension is a dangling
## edge inside solid glass, and running the knife on from it would cut the body along a
## line the player can see does not go there. `relieve()` is what converts those into
## silhouette-reaching cracks, and it must have run before this — a net with open tips
## carves into fewer, larger pieces, which is a legible symptom rather than a silent one.
static func _knife(net: CrackNet, i: int) -> PackedVector2Array:
	var pts: PackedVector2Array = net.strand(i)
	if net.terminus(i) != CrackNet.T_SILHOUETTE or pts.size() < 2:
		return pts
	var tip: Vector2 = pts[pts.size() - 1]
	var heading: Vector2 = (tip - pts[pts.size() - 2])
	if heading.length() <= 0.0:
		return pts
	var run: PackedVector2Array = pts.duplicate()
	run.append(tip + heading.normalized() * OVERSHOOT)
	return run


## Subtract one ribbon from every piece it can reach. The AABB reject is what keeps this
## affordable: a strand crosses two or three pieces out of twenty, and without the test
## every strand would pay a Clipper2 call against every piece.
static func _subtract(pieces: Array[PackedVector2Array],
		ribbon: PackedVector2Array) -> Array[PackedVector2Array]:
	var rb: Rect2 = _bounds(ribbon)
	var out: Array[PackedVector2Array] = []
	for piece: PackedVector2Array in pieces:
		if not _bounds(piece).intersects(rb):
			out.append(piece)
			continue
		for part: PackedVector2Array in Geometry2D.clip_polygons(piece, ribbon):
			# Clipper marks holes by winding them the other way. Dropped — see the
			# docblock: the enclosed region is emitted as its own shard regardless.
			if part.size() >= 3 and not Geometry2D.is_polygon_clockwise(part):
				out.append(part)
	return out


static func _bounds(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var r: Rect2 = Rect2(poly[0], Vector2.ZERO)
	for i: int in range(1, poly.size()):
		r = r.expand(poly[i])
	return r


## Shoelace, absolute. Public because the invariant that the pieces account for the body
## is the whole point of testing a carve, and it has to be computable from outside.
static func area(poly: PackedVector2Array) -> float:
	var a: float = 0.0
	for i: int in range(poly.size()):
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5
