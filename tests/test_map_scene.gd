extends RefCounted
## #234 slice 1: MapScene camera rig and freeze switch, standalone of the 2D map.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_scene: %s" % what)


static func run(fails: Array[String]) -> void:
	_rig(fails)
	_scene(fails)
	_input(fails)


static func _rig(fails: Array[String]) -> void:
	var rig: MapCameraRig = MapCameraRig.new()
	var cam: Camera3D = rig.get_camera()
	_check(fails, cam.projection == Camera3D.PROJECTION_ORTHOGONAL,
			"camera is orthographic")
	_check(fails, cam.rotation_degrees.x >= -60.0
			and cam.rotation_degrees.x <= -50.0,
			"pitch sits in the signed 50–60° band")
	_check(fails, is_equal_approx(cam.rotation_degrees.x, MapCameraRig.TILT_DEGREES),
			"default pitch is the #255 −55° stop")
	_check(fails, rig.zoom_stop == MapCameraRig.DEFAULT_STOP
			and is_equal_approx(cam.size, MapCameraRig.ZOOM_STOPS[MapCameraRig.DEFAULT_STOP]),
			"default zoom stop matches proxy CAM_SIZE 20")
	_check(fails, MapCameraRig.ZOOM_STOPS.size() == 4,
			"four discrete zoom stops, same count as shader TEX_STOPS")
	var height: float = cam.position.y
	rig.set_zoom_stop(0)
	_check(fails, rig.zoom_stop == 0
			and is_equal_approx(cam.size, MapCameraRig.ZOOM_STOPS[0]),
			"stop 0 is the tight ortho size")
	rig.set_zoom_stop(99)
	_check(fails, rig.zoom_stop == 3
			and is_equal_approx(cam.size, MapCameraRig.ZOOM_STOPS[3]),
			"zoom stop clamps; it is not a continuous scale")
	rig.nudge_zoom(-1)
	_check(fails, rig.zoom_stop == 2, "nudge_zoom steps the int index")
	rig.set_zoom_stop(MapCameraRig.DEFAULT_STOP)
	rig.pan_world(Vector2(1.5, -2.0))
	var xz: Vector2 = rig.camera_xz()
	_check(fails, is_equal_approx(xz.x, MapCameraRig.DEFAULT_XZ.x + 1.5)
			and is_equal_approx(xz.y, MapCameraRig.DEFAULT_XZ.y - 2.0),
			"pan moves world XZ")
	_check(fails, is_equal_approx(cam.position.y, height),
			"pan does not change camera height")
	rig.pan_world(Vector2(-1000.0, 1000.0))
	xz = rig.camera_xz()
	var lo: Vector2 = rig.pan_bounds.position
	var hi: Vector2 = rig.pan_bounds.end
	_check(fails, is_equal_approx(xz.x, lo.x) and is_equal_approx(xz.y, hi.y),
			"pan clamps to bounds")
	rig.free()


static func _scene(fails: Array[String]) -> void:
	var scene: MapScene = MapScene.new()
	_check(fails, scene.get_stage().own_world_3d,
			"stage owns its World3D")
	_check(fails, not scene.is_live()
			and scene.get_stage().render_target_update_mode
				== SubViewport.UPDATE_ONCE,
			"rest is frozen via UPDATE_ONCE, not a disabled viewport")
	scene.set_live(true)
	_check(fails, scene.is_live()
			and scene.get_stage().render_target_update_mode
				== SubViewport.UPDATE_ALWAYS,
			"set_live(true) is UPDATE_ALWAYS")
	scene.set_live(false)
	_check(fails, not scene.is_live()
			and scene.get_stage().render_target_update_mode
				== SubViewport.UPDATE_ONCE,
			"set_live(false) re-arms UPDATE_ONCE")
	_check(fails, scene.get_key().shadow_enabled == false,
			"key light casts no shadow")
	var ground: Node = scene.find_child("TerrainPlaceholder", true, false)
	_check(fails, ground is MeshInstance3D, "placeholder ground is a MeshInstance3D")
	if ground is MeshInstance3D:
		var mesh_i: MeshInstance3D = ground as MeshInstance3D
		_check(fails, mesh_i.material_override is StandardMaterial3D,
				"slice 1 ground is an unshaded placeholder, not the cel shader")
	_check(fails, scene.get_rig().get_camera().current,
			"act camera is current inside the stage")
	scene.free()


static func _input(fails: Array[String]) -> void:
	var scene: MapScene = MapScene.new()
	var rig: MapCameraRig = scene.get_rig()
	var start: int = rig.zoom_stop
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	scene._gui_input(wheel)
	_check(fails, rig.zoom_stop == start + 1, "wheel down steps zoom out")
	_check(fails, not scene.is_live(), "zoom re-arms a single frozen frame")
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	scene._gui_input(press)
	_check(fails, scene.is_live(), "drag starts live")
	var before: Vector2 = rig.camera_xz()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(40.0, 0.0)
	scene._gui_input(motion)
	_check(fails, rig.camera_xz().x < before.x, "content follows the finger")
	press.pressed = false
	scene._gui_input(press)
	_check(fails, not scene.is_live(), "drag end freezes")
	scene.free()
