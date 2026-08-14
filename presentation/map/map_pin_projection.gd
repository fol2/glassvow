class_name MapPinProjection
extends RefCounted
## 15×7 world-XZ control lattice and Camera3D pin projection (#234 slice 3).
##
## Integer (row, col) are lattice vertices. A node's authored wander is the
## same pairing the 2D screen already uses: `jy` along the journey (row → −Z),
## `jx` across the lanes (col → X). Bilinear sample of the four surrounding
## vertices is the world anchor; 2D pins seat at the camera's unprojection of
## that point. Hit-test is the inverse ray ∩ Y=0, so a tap on a pin recovers
## the same screen point (the #207 agreement).

## Col 0 / row 0 at the near-left; cell X matches the 6-unit lane, cell Z
## walks toward −Z (camera look). Footprint sits inside MapScene.GROUND_SIZE
## with a 3-unit Z margin and 6-unit X margin.
const CELL: Vector2 = Vector2(6.0, -2.0)
const ORIGIN_XZ: Vector2 = Vector2(-18.0, 14.0)


var _camera: Camera3D
var _control: Vector2
var _view_size: Vector2


func _init(camera: Camera3D, control_size: Vector2, view_size: Vector2) -> void:
	_camera = camera
	_control = control_size
	_view_size = view_size


static func lattice_point(row: int, col: int) -> Vector3:
	return Vector3(
			ORIGIN_XZ.x + float(col) * CELL.x,
			0.0,
			ORIGIN_XZ.y + float(row) * CELL.y)


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


static func world_anchor(node: MapNode) -> Vector3:
	return sample(float(node.row) + node.jy, float(node.col) + node.jx)


## Ground XZ AABB of the 15×7 vertices, grown by the authored jitter so a
## pan that frames an edge vertex still frames its wander.
static func lattice_footprint() -> Rect2:
	var lo: Vector3 = lattice_point(WorldMap.ROWS - 1, 0)
	var hi: Vector3 = lattice_point(0, WorldMap.COLS - 1)
	var mx: float = absf(CELL.x) * WorldMap.JITTER_SPREAD.x * 0.5
	var mz: float = absf(CELL.y) * WorldMap.JITTER_SPREAD.y * 0.5
	var x0: float = minf(lo.x, hi.x) - mx
	var z0: float = minf(lo.z, hi.z) - mz
	return Rect2(x0, z0,
			absf(hi.x - lo.x) + mx * 2.0,
			absf(hi.z - lo.z) + mz * 2.0)


func to_screen(world: Vector3) -> Vector2:
	return _camera.unproject_position(world) * _scale()


func hit_world(screen: Vector2) -> Vector3:
	var px: Vector2 = screen / _scale()
	var origin: Vector3 = _camera.project_ray_origin(px)
	var dir: Vector3 = _camera.project_ray_normal(px)
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
