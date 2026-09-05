extends SceneTree
## Verify the tapered reserve against actual imported vertices at eight yaws.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var kind: String = "conifer-spire" if "--spire" in OS.get_cmdline_user_args() else "conifer"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):
			kind = arg.trim_prefix("--kind=")
	var scene: PackedScene = load("res://assets/art/map-journey/%s.glb" % kind) as PackedScene
	var tree: Node3D = scene.instantiate() as Node3D
	root.add_child(tree)
	var hull: PackedVector2Array = preload("res://tools/map_workshop/foliage_envelope.gd").load_conifer(kind)
	if hull.is_empty():
		quit(1)
		return
	var count: int = 0
	var outside: int = 0
	for child: Node in tree.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = child as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var vertices: PackedVector3Array = instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for yaw: int in range(8):
				for vertex: Vector3 in vertices:
					var p: Vector3 = (instance.global_transform * vertex).rotated(Vector3.UP, yaw * TAU / 8)
					var q: Vector2 = Vector2(p.x, p.z - p.y / tan(deg_to_rad(55)))
					count += 1
					if not Geometry2D.is_point_in_polygon(q, hull):
						outside += 1
	print("CONIFER_ENVELOPE ", JSON.stringify({"vertex_projections": count, "outside": outside}))
	quit(0 if outside == 0 else 1)
