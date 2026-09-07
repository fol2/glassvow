extends SceneTree
## Geometry contract for the shared scenery library, without rendering the map.
func _initialize() -> void:
	var kit: RefCounted = preload("res://presentation/map/chapters/act2/scenery_assets.gd").new()
	kit.build()
	assert(kit.meshes.size()==18)
	assert(kit.material.vertex_color_use_as_albedo and kit.material.vertex_color_is_srgb)
	var triangles: int = 0
	for kind: String in kit.KINDS:
		var shapes: Dictionary = {}
		for variant: int in range(3):
			var mesh: ArrayMesh = kit.meshes[kind+str(variant)]
			var faces: PackedVector3Array = mesh.get_faces()
			assert(not faces.is_empty())
			for point: Vector3 in faces:
				assert(point.is_finite())
			shapes[hash(faces)] = true
			triangles += faces.size()/3
			if kind=="floating_leaves":
				assert(mesh.get_aabb().position.y>1.18 and mesh.get_aabb().end.y<1.25)
		assert(shapes.size()==3,"Each scenery family must have three distinct shapes: "+kind)
	assert(triangles<10000)
	print("PASS: 18 finite, non-empty, distinct variant meshes; leaf rafts above the waterline; library triangles=",triangles)
	quit()
