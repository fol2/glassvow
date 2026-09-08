extends SceneTree
## Discriminating camera experiment: native projection and generated choice sets.
const C = preload("res://presentation/map/map_journey_camera_contract.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var view: SubViewport = SubViewport.new()
	view.own_world_3d = true
	root.add_child(view)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	view.add_child(camera)
	camera.current = true
	Locale.active = Locale.new(&"en")
	var content: ContentDB = ContentDB.load_full()
	Locale.active.hydrate_content(content)
	var rejected: Array = []
	var groups: int = 0
	var maximum_error: float = 0.0
	for seed_value: int in [4,717,17634]:
		var run: RunState = RunState.new_run(content,seed_value)
		var world: WorldMap = WorldMap.for_run(run,content)
		var by_id: Dictionary = {}
		for index: int in range(world.nodes.size()):
			by_id[world.nodes[index].id] = index
		for from: int in range(-1,world.nodes.size()):
			var ids: Array[int] = []
			if from < 0:
				ids.assign(world.reachable())
			if from >= 0:
				for id: String in world.nodes[from].next:
					ids.append(by_id[id])
			if ids.is_empty():
				continue
			var points: PackedVector3Array = []
			if from >= 0:
				points.append(MapPinProjection.world_anchor(world.nodes[from]))
			for index: int in ids:
				points.append(MapPinProjection.world_anchor(world.nodes[index]))
			for shape: StringName in StageShape.SHIPPING:
				var stage: Vector2 = Vector2(StageShape.REFERENCES[shape])
				var pose: Dictionary = C.resolve(points,stage)
				groups += 1
				if not pose.get("ok",false):
					rejected.append({"seed":seed_value,"from":from,"shape":shape,"reason":pose})
					continue
				view.size = Vector2i(stage)
				camera.size = pose["zoom"]
				camera.position = pose["position"]
				camera.rotation_degrees.x = -C.PITCH
				await process_frame
				for point: Vector3 in points:
					maximum_error = maxf(maximum_error,camera.unproject_position(point).distance_to(C.screen_point(point,pose,stage)))
	var report: Dictionary = {"groups":groups,"rejected_count":rejected.size(),"maximum_native_projection_error_px":maximum_error,"rejected":rejected,
		"scope":"authored generated anchors before route compilation; not a compiled seed pass"}
	var file: FileAccess = FileAccess.open("/tmp/glassvow-steps4-8/camera-groups.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("CAMERA_GROUPS ",groups," rejected=",rejected.size()," native_error_px=",maximum_error)
	quit(0 if maximum_error < .01 else 1)
