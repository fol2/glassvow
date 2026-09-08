extends SceneTree
## Geometric regressions: joined branches, a closed loop and a sloping bend.
const Surfaces = preload("res://presentation/map/landscape/bridge_surfaces.gd")
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var cases: Array[Dictionary] = [
		{"name":"joined branches","lines":[PackedVector3Array([Vector3(-3,0,0),Vector3(3,0,0)]),PackedVector3Array([Vector3(0,0,0),Vector3(0,0,3)])]},
		{"name":"closed loop","lines":[PackedVector3Array([Vector3(-3,0,-3),Vector3(3,0,-3),Vector3(3,0,3),Vector3(-3,0,3),Vector3(-3,0,-3)])]},
		{"name":"sloping bend","lines":[PackedVector3Array([Vector3(-3,0,0),Vector3(0,.3,0),Vector3(0,.3,3)])]}
	]
	var probes: int = 0
	var triangles: int = 0
	var failures: Array = []
	for example: Dictionary in cases:
		var spans: Array[Dictionary] = []
		for line: PackedVector3Array in example["lines"]:
			for i: int in range(line.size()-1):
				spans.append({"a":line[i],"b":line[i+1],"wa":1.0,"wb":1.0,"s":0.0})
		var field: Surfaces = Surfaces.new()
		field.setup(spans,func(_x:float,_z:float)->float:return -.1)
		var top: SurfaceTool = SurfaceTool.new()
		top.begin(Mesh.PRIMITIVE_TRIANGLES)
		var sides: SurfaceTool = SurfaceTool.new()
		sides.begin(Mesh.PRIMITIVE_TRIANGLES)
		field.append(top,sides)
		var mesh: ArrayMesh = Meshes.finish(top)
		var faces: PackedVector3Array = mesh.get_faces()
		var seen: Dictionary = {}
		for i: int in range(0,faces.size(),3):
			triangles += 1
			var a: Vector3 = faces[i]
			var b: Vector3 = faces[i+1]
			var c: Vector3 = faces[i+2]
			if not a.is_finite() or not b.is_finite() or not c.is_finite() or (b-a).cross(c-a).length_squared()<.00000000000001:
				failures.append(str(example["name"])+": invalid triangle")
			var keys: Array[String] = [str(a),str(b),str(c)]
			keys.sort()
			var key: String = "|".join(keys)
			if seen.has(key):
				failures.append(str(example["name"])+": duplicate triangle")
			seen[key] = true
		var body: StaticBody3D = StaticBody3D.new()
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		collision.shape = shape
		body.add_child(collision)
		root.add_child(body)
		await physics_frame
		await physics_frame
		for span: Dictionary in spans:
			var a: Vector3 = span["a"]
			var b: Vector3 = span["b"]
			var side: Vector3 = (b-a).cross(Vector3.UP).normalized()
			for i: int in range(61):
				for offset: float in [-.5,0,.5]:
					var at: Vector3 = a.lerp(b,i/60.0)+side*offset
					var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at+Vector3.UP*.1,at-Vector3.UP*.1)
					probes += 1
					if body.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
						failures.append(str(example["name"])+": missing walking surface "+str(at))
		if example["name"]=="closed loop":
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(0,1,0),Vector3(0,-1,0))
			probes += 1
			if not body.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				failures.append("Closed-loop interior was incorrectly filled")
		body.queue_free()
		await physics_frame
	print("BRIDGE_SURFACE_CASES ",JSON.stringify({"cases":cases.size(),"probes":probes,"triangles":triangles,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
