class_name MapPinProjection
extends RefCounted
## 15×7 world-XZ control lattice and pin projection (#234 slice 3 / 7b).
##
## Integer (row, col) are lattice vertices. A node's authored wander is the
## same pairing the 2D screen already uses: `jy` along the journey (row → −Z),
## `jx` across the lanes (col → X). Bilinear sample of the four surrounding
## vertices is the world anchor; 2D pins seat at the orthogonal projection of
## that point. Hit-test is the inverse ray ∩ Y=0, so a tap on a pin recovers
## the same screen point (the #207 agreement). Camera3D.unproject is not used:
## it returns the origin unless the camera's Viewport has entered the tree.

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
