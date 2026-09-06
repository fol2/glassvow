extends SceneTree
## Independent ray probes of every elevated centreline and its walking width.
const Terrain = preload("res://tools/map_workshop/terrain.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var terrain: Terrain = Terrain.new()
	root.add_child(terrain)
	var sample: Dictionary = preload("res://tools/map_workshop/sample.gd").read()
	if sample.is_empty():
		quit(2)
		return
	terrain.build(sample,false)
	var deck: MeshInstance3D = terrain.get_node("Continuous bridge decks") as MeshInstance3D
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(deck.mesh.get_faces())
	shape.backface_collision = true
	var body: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	terrain.add_child(body)
	await physics_frame
	await physics_frame
	var failures: Array = []
	var probes: int = 0
	for line: PackedVector3Array in terrain.lines:
		for index: int in range(line.size()-1):
			var a: Vector3 = line[index]
			var b: Vector3 = line[index+1]
			var side: Vector3 = (b-a).cross(Vector3.UP).normalized()
			var steps: int = maxi(1,ceili(a.distance_to(b)/.15))
			for step: int in range(steps+1):
				var p: Vector3 = a.lerp(b,float(step)/steps)
				if not terrain.is_elevated(p):
					continue
				for offset: float in [-.5,0,.5]:
					var at: Vector3 = p+side*offset
					var field: RefCounted = terrain.get_meta("bridge_field")
					var expected: Dictionary = field.field(Vector2(at.x,at.z))
					at.y = expected["height"]
					var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at+Vector3.UP*.04,at-Vector3.UP*.04)
					probes += 1
					if terrain.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
						failures.append(str(at))
	print("BRIDGE_CONTINUITY ",JSON.stringify({"probes":probes,"failures":failures}))
	quit(0 if probes>0 and failures.is_empty() else 1)
