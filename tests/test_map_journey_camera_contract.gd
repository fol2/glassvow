extends RefCounted
const Contract = preload("res://presentation/map/map_journey_camera_contract.gd")
static func run(fails: Array[String]) -> void:
	var points: PackedVector3Array = [Vector3(-8,0,0),Vector3(0,2,-5),Vector3(0,4,5)]
	for stage: Vector2 in [Vector2(1458,820),Vector2(1180,820),Vector2(844,390)]:
		var pose: Dictionary = Contract.resolve(points,stage)
		if not pose.get("ok",false):
			fails.append("journey camera: separated terraced choices could not be framed")
			continue
		for point: Vector3 in points:
			var pixel: Vector2 = Contract.screen_point(point,pose,stage)
			if not Rect2(Vector2(42,88),stage-Vector2(84,176)).grow(.001).has_point(pixel):
				fails.append("journey camera: elevated choice falls outside safe frame")
			var ink: Rect2 = Rect2(pixel-Vector2.ONE*38,Vector2.ONE*76)
			if ink.position.y<64 or ink.end.y>stage.y-88:
				fails.append("journey camera: complete target overlaps campaign chrome")
		# A coincident screen projection has no valid distinct touch targets;
		# accepting an overview must never make that group selectable.
		var overlapping: PackedVector3Array = [Vector3.ZERO,Vector3.ZERO]
		if Contract.resolve(overlapping,stage).get("ok",false):
			fails.append("journey camera: overlapping choices accepted")
		if not Contract.resolve(overlapping,stage,true).get("ok",false):
			fails.append("journey camera: non-interactive overview rejected")
		if Contract.touch_size(stage) < 60.0*stage.y/820.0:
			fails.append("journey camera: target below commercial design size")
	if Contract.resolve([],Vector2(844,390)).get("ok",false):
		fails.append("journey camera: empty graph accepted")

	var rig: MapCameraRig = MapCameraRig.new()
	var stage: Vector2 = Vector2(844,390)
	var pose: Dictionary = Contract.resolve([Vector3.ZERO],stage)
	pose["pan_bounds"] = Rect2(-100,-100,200,200)
	rig.apply_journey_pose(pose)
	var before: Vector2 = Contract.screen_point(Vector3.ZERO,pose,stage)
	var drag: Vector2 = Vector2(12,17)
	rig.pan_screen(drag,stage.y)
	pose["position"] = rig.get_camera().position
	var after: Vector2 = Contract.screen_point(Vector3.ZERO,pose,stage)
	if not (after-before).is_equal_approx(drag):
		fails.append("journey camera: drag does not track the finger at the live pitch")
	rig.free()
