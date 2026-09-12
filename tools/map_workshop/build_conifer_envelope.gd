extends SceneTree
## Generate a yaw-independent projected envelope from the imported mesh.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var kind: String = "conifer-spire" if "--spire" in OS.get_cmdline_user_args() else "conifer"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):
			kind = arg.trim_prefix("--kind=")
	var path: String = "res://assets/art/map-journey/%s.glb" % kind
	var scene: PackedScene = load(path) as PackedScene
	var tree: Node3D = scene.instantiate() as Node3D
	root.add_child(tree)
	var samples: PackedVector2Array = []
	for child: Node in tree.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = child as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var vertices: PackedVector3Array = instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var p: Vector3 = instance.global_transform * vertex
				var radius: float = Vector2(p.x,p.z).length() / cos(PI / 16)
				for i: int in range(16):
					var angle: float = i * TAU / 16
					samples.append(Vector2(cos(angle)*radius, sin(angle)*radius-p.y/tan(deg_to_rad(55))))
	var hull: PackedVector2Array = Geometry2D.convex_hull(samples)
	var points: Array = []
	for point: Vector2 in hull:
		points.append([point.x,point.y])
	var file: FileAccess = FileAccess.open("res://assets/art/map-journey/%s-envelope.json" % kind, FileAccess.WRITE)
	file.store_string(JSON.stringify({"source_sha256": FileAccess.get_sha256(path), "pitch":55, "points":points}, "\t") + "\n")
	print("CONIFER_ENVELOPE_BUILT ", hull.size())
	quit()
