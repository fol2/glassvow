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
