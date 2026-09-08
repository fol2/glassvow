extends RefCounted
static func run(fails: Array[String]) -> void:
	var stage: Vector2 = Vector2(1180,820)
	var world: Vector3 = Vector3(113.5,3,-16.6)
	var envelope: Rect2 = Rect2(world.x-.35,world.z-.35,.7,.7)
	var bounds: Rect2 = Rect2(-100,-50,300,150)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees.x = MapCameraRig.TILT_DEGREES
	for height: float in [0.0,3.0,-2.0]:
		world.y = height
		var resolved: Dictionary = MapCameraRig.resolve_leading(world,stage,18,44,envelope,bounds)
		if resolved.get("ok") != true:
			fails.append("elevated focus: feasible focus rejected")
			continue
		var pose: Vector2 = resolved["pose"]
		camera.position = Vector3(pose.x,MapCameraRig.CAM_HEIGHT,pose.y)
		camera.size = 18
		var projector: MapPinProjection = MapPinProjection.new(camera,stage,stage)
		for z: float in [envelope.position.y,envelope.end.y]:
			var pixel: Vector2 = projector.to_screen(Vector3(world.x,height,z))
			if pixel.y < 44-.001 or pixel.y > stage.y-44+.001:
				fails.append("elevated focus: platform focus envelope leaves safe frame at height "+str(height))
	camera.free()
