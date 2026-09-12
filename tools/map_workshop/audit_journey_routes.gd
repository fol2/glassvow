extends SceneTree
## Walk every legal edge: real support, stone clearance and adult body space.
const Terrain = preload("res://presentation/map/landscape/terrain.gd")
const Journey = preload("res://presentation/map/landscape/journey.gd")
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")

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
	for name: String in ["Quiet sculpted ground","Continuous bridge decks","Joined bridge masonry","Bridge parapet stones"]:
		var item: MeshInstance3D = terrain.get_node(name)
		var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		shape.set_faces(item.mesh.get_faces())
		shape.backface_collision = true
		var body: StaticBody3D = StaticBody3D.new()
		body.set_meta("surface_label",name)
		body.collision_layer = 2 if name in ["Joined bridge masonry","Bridge parapet stones"] else 1
		var collider: CollisionShape3D = CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		terrain.add_child(body)
	await physics_frame
	await physics_frame
	var journey: Journey = Journey.new()
	root.add_child(journey)
	journey.terrain = terrain
	var stones: PackedVector3Array = []
	for raw: Array in sample["anchors"].values():
		stones.append(Journey.seat(terrain,Meshes.v3(raw)))
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = .25
	capsule.height = 1.7
	var failures: Array = []
	var probes: int = 0
	var minimum_clearance: float = INF
	var maximum_support_error: float = 0
	for edge: Dictionary in sample["edges"].values():
		var route: PackedVector3Array = journey.path(str(edge["from"]),str(edge["to"]))
		if route.size()<2:
			failures.append({"edge":edge["from"]+"/"+edge["to"],"empty_route":true})
		for i: int in range(route.size()-1):
			var count: int = maxi(1,ceili(route[i].distance_to(route[i+1])/.06))
			for step: int in range(count+1):
				var p: Vector3 = route[i].lerp(route[i+1],float(step)/count)
				probes += 1
				var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p+Vector3.UP*.12,p-Vector3.UP*.18,1)
				var hit: Dictionary = terrain.get_world_3d().direct_space_state.intersect_ray(ray)
				if hit.is_empty():
					failures.append({"missing_support":str(p)})
				else:
					var contact: Vector3 = hit["position"]
					maximum_support_error = maxf(maximum_support_error,absf(contact.y-p.y))
					if absf(contact.y-p.y)>.08:
						failures.append({"support_error":contact.y-p.y,"at":str(p)})
				for stone: Vector3 in stones:
					if absf(p.y-stone.y)>1.8:
						continue
					var distance: float = Vector2(p.x-stone.x,p.z-stone.z).length()
					minimum_clearance = minf(minimum_clearance,distance)
					if distance<.78:
						failures.append({"stone_collision":str(p),"distance":distance})
				var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
				query.shape = capsule
				query.collision_mask = 2
				# Probe above the 12 cm boots, whose ground contact is measured by
				# the ray. A capsule at the sole would also hit ordinary sloped paving.
				query.transform.origin = p+Vector3.UP*.93
				var collisions: Array[Dictionary] = terrain.get_world_3d().direct_space_state.intersect_shape(query)
				if not collisions.is_empty():
					var collider: Node = collisions[0]["collider"]
					var rest: Dictionary = terrain.get_world_3d().direct_space_state.get_rest_info(query)
					failures.append({"body_collision":str(p),"object":collider.get_meta("surface_label"),"edge":str(edge["from"])+"/"+str(edge["to"]),"normal":str(rest.get("normal","")),"point":str(rest.get("point",""))})
	print("JOURNEY_ROUTES_AUDIT ",JSON.stringify({"edges":sample["edges"].size(),"probes":probes,"minimum_stone_distance":minimum_clearance,"maximum_support_error":maximum_support_error,"failure_count":failures.size(),"failures":failures.slice(0,30)}))
	quit(0 if failures.is_empty() else 1)
