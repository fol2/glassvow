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

const TILT_DEGREES: float = -40.0
const CAM_HEIGHT: float = 18.0
## Opening pose, re-derived for the X journey (#156 direction B). z sits one
## `look_dz` behind the lane centre so the look-at lands on z=0 and the seven
## lanes fill the frame -- the old (-7, 16) framed z -8.8..15.6, which was
## off-centre against lanes that only reach +/-12 and left a dead band along
## the bottom. x puts the row-0 entrances (x ~= -24) on the left third rather
## than off-frame, which is the lead the concept brief asks for and which
## `trail/lead` (0.333) already names for the 2D chrome.
## The z half is not a free number: it IS `look_dz()`, so the default pose
## looks at ground z = 0 rather than off to one side. It tracks the tilt --
## 12.6 while the camera sat at 55°, 21.45 now it sits at 40° -- and
## `test_map_pins` asserts the equality so the two cannot drift apart.
const DEFAULT_XZ: Vector2 = Vector2(-29.7, 21.45)
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


## The journey fraction the focused node sits at, and how hard the look-at is
## pulled back to the lane centre.
const LEAD_X: float = 0.333
const LANE_PULL: float = 0.7


## Frame a ground point with the road AHEAD of it visible. `pose_for_world`
## centres the point, which on an X journey spends half the frame on land the
## pilgrim has already crossed, and — when the node sits in an outer lane —
## puts a third of the frame past the edge of the lattice entirely. This seats
## the point on `LEAD_X` of the width and pulls the look-at back toward z=0 so
## all seven lanes stay in frame instead of one lane being centred.
func pose_leading(world: Vector3, stage: Vector2, focus_inset_px: float,
		focus_envelope_xz: Rect2) -> Vector2:
	var resolved: Dictionary = resolve_leading(
		world, stage, _camera.size, focus_inset_px, focus_envelope_xz)
	var pose_v: Variant = resolved.get("pose", null)
	if resolved.get("ok", false) == true and pose_v is Vector2:
		return pose_v
	push_error("MapCameraRig refused an unsafe focused pose: %s" % JSON.stringify(
		resolved.get("failure", {})))
	return camera_xz()


## Greatest lane-centre pull whose complete governed focus envelope remains in
## the stage after the normal pan clamp. The inset already includes the touch
## half-size and its safe-frame floor; this resolver does not duplicate either.
static func resolve_leading(world: Vector3, stage: Vector2, zoom: float,
		focus_inset_px: float, focus_envelope_xz: Rect2) -> Dictionary:
	var bounds: Rect2 = bounds_from_lattice()
	var geometry: Dictionary = {
		"stage": _a2(stage),
		"zoom": zoom,
		"focus_inset_px": focus_inset_px,
		"focus_world": [world.x, world.y, world.z],
		"focus_envelope_xz": [focus_envelope_xz.position.x,
			focus_envelope_xz.position.y, focus_envelope_xz.end.x,
			focus_envelope_xz.end.y],
		"pan_bounds_xz": [bounds.position.x, bounds.position.y,
			bounds.end.x, bounds.end.y],
	}
	if not is_finite(world.x) or not is_finite(world.y) or not is_finite(world.z) \
			or not is_finite(focus_envelope_xz.position.x) \
			or not is_finite(focus_envelope_xz.position.y) \
			or not is_finite(focus_envelope_xz.end.x) \
			or not is_finite(focus_envelope_xz.end.y) \
			or not is_finite(stage.x) or not is_finite(stage.y) or stage.x <= 0.0 \
			or stage.y <= 0.0 or not is_finite(zoom) or zoom <= 0.0 \
			or not is_finite(focus_inset_px) or focus_inset_px < 0.0 \
			or focus_envelope_xz.size.x < 0.0 or focus_envelope_xz.size.y < 0.0:
		return _focus_failure(geometry, "invalid_geometry")
	var lead: float = (0.5 - LEAD_X) * zoom * stage.x / stage.y
	var pose_x: float = clampf(world.x + lead, bounds.position.x, bounds.end.x)
	var horizontal: float = (stage.x * 0.5 - focus_inset_px) * zoom / stage.y
	var safe_x: Vector2 = Vector2(focus_envelope_xz.end.x - horizontal,
		focus_envelope_xz.position.x + horizontal)
	geometry["legal_camera_x"] = _a2(safe_x)
	if horizontal < 0.0 or safe_x.x > safe_x.y \
			or pose_x < safe_x.x or pose_x > safe_x.y:
		return _focus_failure(geometry, "horizontal_focus_envelope")
	var sine: float = sin(deg_to_rad(absf(TILT_DEGREES)))
	var vertical: float = zoom * (0.5 - focus_inset_px / stage.y) / sine
	var safe_z: Vector2 = Vector2(maxf(
		focus_envelope_xz.end.y + look_dz() - vertical, bounds.position.y), minf(
		focus_envelope_xz.position.y + look_dz() + vertical, bounds.end.y))
	geometry["legal_camera_z"] = _a2(safe_z)
	if vertical < 0.0 or safe_z.x > safe_z.y:
		return _focus_failure(geometry, "vertical_focus_envelope")
	var raw_start: float = world.z + look_dz()
	var raw_end: float = lerpf(world.z, 0.0, LANE_PULL) + look_dz()
	var pose_z: float = clampf(raw_end, bounds.position.y, bounds.end.y)
	var pull: float = LANE_PULL
	if pose_z < safe_z.x or pose_z > safe_z.y:
		if is_zero_approx(world.z):
			return _focus_failure(geometry, "fixed_focus_outside_vertical_envelope")
		var target_z: float = clampf(pose_z, safe_z.x, safe_z.y)
		pull = (raw_start - target_z) / world.z
		if pull < 0.0 or pull > LANE_PULL:
			geometry["required_pull"] = pull
			return _focus_failure(geometry, "no_legal_lane_pull")
		pose_z = clampf(lerpf(world.z, 0.0, pull) + look_dz(),
			bounds.position.y, bounds.end.y)
	return {"ok": true, "pose": Vector2(pose_x, pose_z), "effective_pull": pull}


static func _focus_failure(geometry: Dictionary, reason: String) -> Dictionary:
	var failure: Dictionary = geometry.duplicate(true)
	failure["reason"] = reason
	return {"ok": false, "failure": failure}


static func _a2(value: Vector2) -> Array[float]:
	return [value.x, value.y]


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
