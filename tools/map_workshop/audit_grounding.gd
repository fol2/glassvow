extends SceneTree
## Compare contact heights with independent physics rays against rendered land.
const Terrain = preload("res://tools/map_workshop/terrain.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var terrain: Terrain = Terrain.new()
	world.add_child(terrain)
	var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/studies/camera-composition/act1-seed717.json"))
	terrain.build(sample, true)
	var land: MeshInstance3D = terrain.get_node("Quiet sculpted ground") as MeshInstance3D
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(land.mesh.get_faces())
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	var body: StaticBody3D = StaticBody3D.new()
	body.add_child(collision)
	world.add_child(body)
	await physics_frame
	await physics_frame
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7512
	var failures: Array[String] = []
	var old_error: float = 0
	var new_error: float = 0
	for index: int in range(200):
		var x: float = rng.randf_range(-46, 46)
		var z: float = rng.randf_range(-28, 28)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, 5, z), Vector3(x, -5, z))
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			failures.append("No land hit at sample %d" % index)
			continue
		var at: Vector3 = hit["position"]
		old_error = maxf(old_error, absf(at.y - terrain.height_at(x, z)))
		var error: float = absf(at.y - terrain.surface_height(x, z))
		new_error = maxf(new_error, error)
		if error > 0.001:
			failures.append("Contact mismatch at sample %d: %f" % [index, error])
	print("GROUND_CONTACT_AUDIT ", JSON.stringify({"samples": 200, "old_max_error": old_error, "new_max_error": new_error, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
