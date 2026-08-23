class_name MapPinProjection
extends RefCounted
## 15×7 world-XZ control lattice and pin projection (#234 slice 3 / 7b).
##
## Integer (row, col) are lattice vertices. A node's authored wander is the
## same pairing the 2D screen already uses: `jy` along the journey (row → +X),
## `jx` across the lanes (col → +Z). Bilinear sample of the four surrounding
## vertices is the world anchor; 2D pins seat at the orthogonal projection of
## that point. Hit-test is the inverse ray ∩ Y=0, so a tap on a pin recovers
## the same screen point (the #207 agreement). Camera3D.unproject is not used:
## it returns the origin unless the camera's Viewport has entered the tree.
##
## THE JOURNEY RUNS ALONG X (#156 direction B). It used to run along −Z, and
## the entire dress layer disagreed with it: `MapMaterials.grade_rect` is
## 48×24 with a 512×256 grade, which is 15 rows at 3.43 units by 7 lanes at
## 4.00; `MapScene`'s scenery scatter spans x −22..21 and hugs |z| 4..8, which
## flanks a corridor along X; `AssetTerminus` sat at (22, 0, 0), which is the
## boss end of an X journey and nowhere on a Z one; and `map_asset_checks.py`
## samples the grade's left and right fifths to measure the journey's hue arc,
## which only means anything if the journey is the image's horizontal axis.
## Four independent artefacts describe an X journey. The lattice was the piece
## out of step, so the lattice is what moved.

## Row 0 / col 0 at the far-left, near lane. Rows walk the journey along +X in
## 3.43-unit steps (15 rows spanning 48); cols spread the lanes along +Z in
## 6-unit steps (7 cols spanning 36). Both match `MapMaterials.GRADE_SIZE`, so
## one painted grade covers the run exactly. Footprint sits inside
## MapScene.GROUND_SIZE with room for the pan frustum on every side.
const CELL: Vector2 = Vector2(72.0 / 14.0, 6.0)
const ORIGIN_XZ: Vector2 = Vector2(-36.0, -18.0)


var _camera: Camera3D
var _control: Vector2
var _view_size: Vector2


func _init(camera: Camera3D, control_size: Vector2, view_size: Vector2) -> void:
	_camera = camera
	_control = control_size
	_view_size = view_size


static func lattice_point(row: int, col: int) -> Vector3:
	return Vector3(
			ORIGIN_XZ.x + float(row) * CELL.x,
			0.0,
			ORIGIN_XZ.y + float(col) * CELL.y)


## Sample the lattice at a (possibly fractional) row/col. Out-of-range
## fractions extrapolate from the nearest cell so edge jitter is not clipped.
static func sample(row_u: float, col_v: float) -> Vector3:
	var i0: int = clampi(floori(row_u), 0, WorldMap.ROWS - 2)
	var j0: int = clampi(floori(col_v), 0, WorldMap.COLS - 2)
	var fu: float = row_u - float(i0)
	var fv: float = col_v - float(j0)
	var p00: Vector3 = lattice_point(i0, j0)
	var p10: Vector3 = lattice_point(i0 + 1, j0)
	var p01: Vector3 = lattice_point(i0, j0 + 1)
	var p11: Vector3 = lattice_point(i0 + 1, j0 + 1)
	return p00.lerp(p01, fv).lerp(p10.lerp(p11, fv), fu)


## Half the ground a waystone medallion covers, at the zoom the map is played
## at. The pane is UNLIT_RADIUS = 28 px, not WIDTH / 2.
##
## This was 1.2, taken at the WIDEST zoom stop, and that was a mistake worth
## recording: it made the scenery test fire for nodes that were not really
## occluded, and shoved each one `piece radius + 1.2` sideways. Measured on
## seed 717, the raw lattice has 2 barely-touching node pairs; clearance at 1.2
## turned that into 4 much worse ones. The avoidance was manufacturing the
## crowding it was then asked to fix.
const NODE_HALF_X: float = 0.82
## The furthest a node will slide to get out from behind something. Roughly
## three quarters of a cell: enough to clear any kit the map ships, not enough
## for a node to swap places with its neighbour.
const STEP_ASIDE_MAX: float = 3.4

## Scenery the nodes step aside for: (world x, world z, footprint radius, how
## far behind itself the piece can hide something). Published by MapScene when
## it binds an act's geometry, and empty until then -- with nothing registered
## `world_anchor` is exactly the bilinear sample it always was.
static var _scenery: Array[Vector4] = []


static func set_scenery(pieces: Array[Vector4]) -> void:
	_scenery = pieces


## Half the ground a medallion covers for the purpose of not overlapping ANOTHER
## medallion. Deliberately smaller than NODE_HALF_X, which is taken at the widest
## zoom stop: two nodes only have to be legible at the zoom the map is played at,
## and demanding they never touch at stop 28 asks for 98 px of separation between
## discs 52 px across -- more than the lattice can give without shoving nodes into
## the wrong cell. Scenery clearance keeps the strict figure; pairs use this one.
## = UNLIT_RADIUS 28 px * the 0.92 layout scale, over the 20-unit view height:
## two medallions clear each other at 51.6 px between centres, which is 1.26
## world units, so each contributes 0.63. Demanding more than the discs actually
## occupy just shoves nodes around for nothing.
const NODE_PAIR_X: float = 0.63
## The same radius in z, foreshortened by the 40 degree tilt.
const NODE_PAIR_Z: float = 0.98

## Anchors resolved as a set, by node id. Empty until the screen resolves them.
static var _resolved: Dictionary[String, Vector3] = {}


## Settle every node against the scenery AND against each other.
##
## Solved together because they fight: stepping out from behind a rock can put a
## node on top of its neighbour, and separating from the neighbour can put it
## back behind the rock. Three passes, alternating, then whatever it has
## converged to -- a node that cannot satisfy both keeps the better position
## rather than oscillating between two bad ones.
static func resolve(nodes: Array[MapNode]) -> void:
	_resolved.clear()
	if nodes.is_empty():
		return
	var base: PackedVector3Array = PackedVector3Array()
	var out: PackedVector3Array = PackedVector3Array()
	for node: MapNode in nodes:
		var seat: Vector3 = sample(
				float(node.row) + node.jy, float(node.col) + node.jx)
		base.append(seat)
		out.append(seat)
	for _pass: int in range(20):
		for i: int in range(out.size()):
			out[i] = _off_scenery(out[i])
		out = _spread(out)
		# Never let the accumulated shove carry a node further than one step from
		# where its own jitter put it: past that it stops reading as the same node
		# nudged and starts reading as a different lattice cell.
		for i: int in range(out.size()):
			out[i] = Vector3(base[i].x + clampf(
					out[i].x - base[i].x, -STEP_ASIDE_MAX, STEP_ASIDE_MAX),
					base[i].y, base[i].z)
	# Spacing gets the last word. Where the two constraints genuinely cannot both
	# hold, a node slightly clipped by scenery is a smaller sin than two
	# medallions overlapping: the player can still see and press both.
	out = _spread(out)
	for i: int in range(nodes.size()):
		_resolved[nodes[i].id] = Vector3(base[i].x + clampf(
				out[i].x - base[i].x, -STEP_ASIDE_MAX, STEP_ASIDE_MAX),
				out[i].y, out[i].z)


## Push overlapping medallions apart along X, sharing the correction between
## them so neither is treated as the one in the wrong place.
##
## Returns the array rather than mutating the argument: PackedVector3Array is
## a VALUE type with copy-on-write, so the first write inside a function forks
## it and the caller never sees the change. This read as an in-place mutation
## for one commit and silently did nothing.
static func _spread(seats: PackedVector3Array) -> PackedVector3Array:
	var out: PackedVector3Array = seats
	for i: int in range(out.size()):
		for j: int in range(i + 1, out.size()):
			var dz: float = absf(out[i].z - out[j].z)
			if dz >= NODE_PAIR_Z * 2.0:
				continue
			# The x separation that clears the ellipse at this z separation.
			var zt: float = dz / (NODE_PAIR_Z * 2.0)
			var want: float = NODE_PAIR_X * 2.0 * sqrt(maxf(1.0 - zt * zt, 0.0))
			var dx: float = out[i].x - out[j].x
			if absf(dx) >= want:
				continue
			# Two seats at the same x have no side to be pushed to; break the tie
			# by index so the result is the same on every boot.
			var dir: float = 1.0 if dx > 0.0 or (dx == 0.0 and i < j) else -1.0
			# Slightly over-relaxed: exact halves stall where three nodes crowd one
			# gap, each satisfied pairwise and none of them actually clear.
			var push: float = (want - absf(dx)) * 0.58
			out[i] = Vector3(out[i].x + push * dir, out[i].y, out[i].z)
			out[j] = Vector3(out[j].x - push * dir, out[j].y, out[j].z)
	return out


static func world_anchor(node: MapNode) -> Vector3:
	if _resolved.has(node.id):
		return _resolved[node.id]
	return step_aside(sample(float(node.row) + node.jy, float(node.col) + node.jx))


## Slide one seat clear of the scenery, with no regard for other nodes.
##
static func _off_scenery(seat: Vector3) -> Vector3:
	if _scenery.is_empty():
		return seat
	var out: Vector3 = seat
	for piece: Vector4 in _scenery:
		var ahead: float = piece.y - out.z
		if ahead <= 0.0 or ahead > piece.w:
			continue
		var gap: float = piece.z + NODE_HALF_X
		var dx: float = out.x - piece.x
		if absf(dx) >= gap:
			continue
		# Clearly to one side already? Keep that side -- the shorter move. Only a
		# seat near the piece's centre line takes the bias.
		out.x = piece.x + (gap if dx >= 0.0 else -gap)
	return out


## Slide a seat along X until nothing stands in front of it.
##
## "In front of" is the whole rule and it is directional: the camera looks from
## +z toward -z, so a piece hides only what is further from the camera than
## itself, and only for as long as its own height reaches. A node behind nothing
## does not move at all.
static func step_aside(seat: Vector3) -> Vector3:
	var out: Vector3 = _off_scenery(_off_scenery(seat))
	var moved: float = clampf(out.x - seat.x, -STEP_ASIDE_MAX, STEP_ASIDE_MAX)
	return Vector3(seat.x + moved, seat.y, seat.z)


## Ground XZ AABB of the 15×7 vertices, grown by the authored jitter so a
## pan that frames an edge vertex still frames its wander.
static func lattice_footprint() -> Rect2:
	var lo: Vector3 = lattice_point(WorldMap.ROWS - 1, 0)
	var hi: Vector3 = lattice_point(0, WorldMap.COLS - 1)
	# `jy` wanders the ROW and rows now run along X; `jx` wanders the COL and
	# cols run along Z. The two spreads swapped sides with the axes (#156 B).
	var mx: float = absf(CELL.x) * WorldMap.JITTER_SPREAD.y * 0.5
	var mz: float = absf(CELL.y) * WorldMap.JITTER_SPREAD.x * 0.5
	var x0: float = minf(lo.x, hi.x) - mx
	var z0: float = minf(lo.z, hi.z) - mz
	return Rect2(x0, z0,
			absf(hi.x - lo.x) + mx * 2.0,
			absf(hi.z - lo.z) + mz * 2.0)


func to_screen(world: Vector3) -> Vector2:
	var eye: Vector3 = _xform().affine_inverse() * world
	var half: Vector2 = _half_extents()
	var view: Vector2 = Vector2(
			(eye.x / maxf(half.x, 0.0001) * 0.5 + 0.5) * _view_size.x,
			(-eye.y / maxf(half.y, 0.0001) * 0.5 + 0.5) * _view_size.y)
	return view * _scale()


func hit_world(screen: Vector2) -> Vector3:
	var px: Vector2 = screen / _scale()
	var half: Vector2 = _half_extents()
	var pos: Vector2 = Vector2(
			px.x / maxf(_view_size.x, 1.0),
			px.y / maxf(_view_size.y, 1.0))
	var local: Vector3 = Vector3(
			pos.x * half.x * 2.0 - half.x,
			(1.0 - pos.y) * half.y * 2.0 - half.y,
			-_camera.near)
	var xform: Transform3D = _xform()
	var origin: Vector3 = xform * local
	var dir: Vector3 = -xform.basis.z.normalized()
	if absf(dir.y) < 0.0001:
		return Vector3.ZERO
	return origin + dir * (-origin.y / dir.y)


func hit_screen(screen: Vector2) -> Vector2:
	return to_screen(hit_world(screen))


func seats(nodes: Array[MapNode]) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(nodes.size())
	for i: int in range(nodes.size()):
		out[i] = to_screen(world_anchor(nodes[i]))
	return out


func _scale() -> Vector2:
	if _view_size.x < 1.0 or _view_size.y < 1.0 \
			or _control.x < 1.0 or _control.y < 1.0:
		return Vector2.ONE
	return _control / _view_size


## Camera3D.unproject / project_ray need is_inside_tree() so they can read
## the Viewport. SceneTree._initialize never finishes enter-tree, and a
## nested SubViewport is the same: both return the origin. The orthogonal
## identity is the engine's (camera_3d.cpp), using `_view_size` for aspect.
func _xform() -> Transform3D:
	if _camera.is_inside_tree():
		return _camera.global_transform
	return _camera.transform


func _half_extents() -> Vector2:
	var aspect: float = _view_size.x / maxf(_view_size.y, 1.0)
	var span: float = _camera.size
	if _camera.keep_aspect == Camera3D.KEEP_WIDTH:
		return Vector2(span * 0.5, span * 0.5 / maxf(aspect, 0.0001))
	return Vector2(span * 0.5 * aspect, span * 0.5)
