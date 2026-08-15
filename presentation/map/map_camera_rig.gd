class_name MapCameraRig
extends Node3D
## Tilted orthographic camera for one act of the 3D map (#234 slice 1).
##
## Pitch, height and default pose are the #255 proxy's measured numbers
## (`tools/map_scene_proxy.gd`), which already sit inside #207's 50–60° band.
## Zoom is a stop index, not a float scale: the same contract as shader
## `tex_stop` (`map_ground.gdshader`). `zoom_stop_changed` carries that int so
## MapScene can push it into both materials. This file only owns camera size.
## Pan is world XZ; Y and tilt never move.

const TILT_DEGREES: float = -55.0
const CAM_HEIGHT: float = 18.0
const DEFAULT_XZ: Vector2 = Vector2(-7.0, 16.0)
const ZOOM_STOPS: Array[float] = [12.0, 16.0, 20.0, 28.0]
const DEFAULT_STOP: int = 2
## Camera XZ. Derived from the 15×7 lattice footprint, shifted by the look-at
## offset so DEFAULT_XZ stays a legal pose. Rect is (min_x, min_z, size_x, size_z).
const CAM_FAR: float = 80.0

signal zoom_stop_changed(index: int)

var zoom_stop: int = DEFAULT_STOP
var pan_bounds: Rect2

var _camera: Camera3D


func _init() -> void:
	name = "MapCameraRig"
	_camera = Camera3D.new()
	_camera.name = "MapCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.rotation_degrees = Vector3(TILT_DEGREES, 0.0, 0.0)
	_camera.far = CAM_FAR
	_camera.current = true
	add_child(_camera)
	pan_bounds = bounds_from_lattice()
	_apply_pose(DEFAULT_XZ)


func _enter_tree() -> void:
	_camera.current = true


func get_camera() -> Camera3D:
	return _camera


func camera_xz() -> Vector2:
	var pos: Vector3 = _camera.position
	return Vector2(pos.x, pos.z)


func set_zoom_stop(index: int) -> void:
	zoom_stop = clampi(index, 0, ZOOM_STOPS.size() - 1)
	_camera.size = ZOOM_STOPS[zoom_stop]
	zoom_stop_changed.emit(zoom_stop)


func nudge_zoom(steps: int) -> void:
	set_zoom_stop(zoom_stop + steps)


func pan_world(delta_xz: Vector2) -> void:
	_apply_pose(camera_xz() + delta_xz)


func set_camera_xz(xz: Vector2) -> void:
	_apply_pose(xz)


## Camera XZ that frames a ground point: look-at sits `look_dz` toward −Z.
static func pose_for_world(world: Vector3) -> Vector2:
	return Vector2(world.x, world.z + look_dz())


static func look_dz() -> float:
	return CAM_HEIGHT / tan(deg_to_rad(absf(TILT_DEGREES)))


## Screen-space drag → world XZ. Orthographic lateral pan is an image translate
## (#207). Vertical pan is foreshortened by the tilt: ground coverage along Z
## is `size / sin(|tilt|)`, the same identity the #255 bench asserts.
func pan_screen(delta_px: Vector2, view_height: float) -> void:
	var k: float = _camera.size / maxf(view_height, 1.0)
	var tilt: float = deg_to_rad(absf(TILT_DEGREES))
	pan_world(Vector2(-delta_px.x * k, -delta_px.y * k / sin(tilt)))


## Lattice XZ → camera XZ: the look-at sits `height / tan(|tilt|)` toward −Z
## of the camera, so clamping camera position to the raw footprint would
## eject DEFAULT_XZ (z=16) off a ground AABB that ends at z=14.
static func bounds_from_lattice() -> Rect2:
	var foot: Rect2 = MapPinProjection.lattice_footprint()
	var dz: float = look_dz()
	return Rect2(foot.position.x, foot.position.y + dz, foot.size.x, foot.size.y)


func _apply_pose(xz: Vector2) -> void:
	var lo: Vector2 = pan_bounds.position
	var hi: Vector2 = pan_bounds.end
	var pos: Vector3 = _camera.position
	pos.x = clampf(xz.x, lo.x, hi.x)
	pos.y = CAM_HEIGHT
	pos.z = clampf(xz.y, lo.y, hi.y)
	_camera.position = pos
	_camera.size = ZOOM_STOPS[zoom_stop]
