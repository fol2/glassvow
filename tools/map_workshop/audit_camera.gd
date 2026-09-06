extends SceneTree
## Native projection audit of every seed-717 journey context, without game mutation.
const Terrain = preload("res://tools/map_workshop/terrain.gd")
const Rig = preload("res://tools/map_workshop/camera.gd")
const Meshes = preload("res://tools/map_workshop/mesh_tools.gd")
const SHAPES: Array[Vector2i] = [Vector2i(844,390), Vector2i(1180,820), Vector2i(1458,820)]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var sample: Dictionary = preload("res://tools/map_workshop/sample.gd").read()
	if sample.is_empty():
		quit(2)
		return
	var terrain: Terrain = Terrain.new()
	root.add_child(terrain)
	terrain.build(sample,false)
	var stage: SubViewport = SubViewport.new()
	root.add_child(stage)
	var rig: Rig = Rig.new()
	stage.add_child(rig)
	rig.set_process(false)
	var failures: Array[String] = []
	var contexts: int = 0
	var seats: Dictionary = {}
	for raw: Array in sample["anchors"].values():
		var source: Vector3 = Meshes.v3(raw)
		seats[terrain.present(source)] = preload("res://tools/map_workshop/journey.gd").seat(terrain,source)
	for shape: Vector2i in SHAPES:
		stage.size = shape
		await process_frame
		for id: String in sample["anchors"]:
			var anchor: Array = sample["anchors"][id]
			var points: PackedVector3Array = [terrain.present(Meshes.v3(anchor))]
			for edge: Dictionary in sample["edges"].values():
				if edge["from"] == id:
					var target: Array = sample["anchors"][edge["to"]]
					points.append(terrain.present(Meshes.v3(target)))
			rig.frame(points, Vector2(shape), false, true)
			var rects: Array[Rect2] = []
			var safe: Rect2 = Rect2(0,60,shape.x,shape.y-132)
			for p: Vector3 in points:
				var seat: Vector3 = seats[p]
				var rect: Rect2 = Rect2(rig.unproject_position(seat+Vector3(0,.48,.14))-Vector2(24,24),Vector2(48,48))
				if not safe.encloses(rect):
					failures.append("Clipped target at %s, %s: %s" % [id,shape,rect])
				for other: Rect2 in rects:
					if rect.intersects(other):
						failures.append("Overlapping targets at %s, %s" % [id,shape])
				rects.append(rect)
			contexts += 1
		var all_points: PackedVector3Array = []
		for raw: Array in sample["anchors"].values():
			all_points.append(terrain.present(Meshes.v3(raw)))
		for edge: Dictionary in sample["edges"].values():
			for raw: Array in edge["centerline"]:
				all_points.append(terrain.present(Meshes.v3(raw)))
		rig.frame(all_points, Vector2(shape), true, true)
		for p: Vector3 in all_points:
			if not Rect2(12,72,shape.x-24,shape.y-156).has_point(rig.unproject_position(p)):
				failures.append("Clipped survey geometry at %s" % shape)
	print("WORKSHOP_CAMERA_AUDIT ", JSON.stringify({"contexts":contexts,"survey_shapes":SHAPES.size(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
