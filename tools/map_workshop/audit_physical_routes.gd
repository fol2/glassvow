extends SceneTree
## Rendered collision probes prove continuity, slope and adult-sized openings.
const Terrain = preload("res://tools/map_workshop/terrain.gd")
var failures: Array = []
var terrain: Terrain
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	terrain = Terrain.new()
	root.add_child(terrain)
	var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/studies/camera-composition/act1-seed717.json"))
	terrain.build(sample,false)
	for name: String in ["Quiet sculpted ground","Continuous bridge decks","Joined bridge masonry"]:
		var item: MeshInstance3D = terrain.get_node(name) as MeshInstance3D
		var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		shape.set_faces(item.mesh.get_faces())
		shape.backface_collision = true
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = 2 if name=="Joined bridge masonry" else 1
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		terrain.add_child(body)
	await physics_frame
	await physics_frame
	var probes: int = 0
	var maximum_step: float = 0
	var maximum_grade: float = 0
	for source_line: PackedVector3Array in terrain.lines:
		var line: PackedVector3Array = preload("res://tools/map_workshop/road_paths.gd").sample(source_line,.1)
		var previous: Dictionary = {}
		var upper: bool = false
		for p: Vector3 in line:
			upper = upper or p.y>.015
		for i: int in range(line.size()-1):
			var a: Vector3 = line[i]
			var b: Vector3 = line[i+1]
			var side: Vector3 = (b-a).cross(Vector3.UP).normalized()
			var steps: int = maxi(1,ceili(a.distance_to(b)/.1))
			for step: int in range(steps):
				var source: Vector3 = a.lerp(b,float(step)/steps)
				var expected: Vector3 = terrain.present(source,upper)
				for offset: float in [-.42,0,.42]:
					var at: Vector3 = expected+side*offset
					var hit: Dictionary = _ray(at+Vector3.UP*.35,at-Vector3.UP*.7,1)
					probes += 1
					if hit.is_empty():
						failures.append({"missing":str(at)})
						continue
					var contact: Vector3 = hit["position"]
					if previous.has(offset):
						var before: Vector3 = previous[offset]
						var jump: float = absf(contact.y-before.y)
						maximum_step = maxf(maximum_step,jump)
						var distance: float = Vector2(contact.x-before.x,contact.z-before.z).length()
						if jump>maxf(.15,distance*.65):
							failures.append({"step":jump,"at":str(contact),"before":str(before)})
						if offset==0 and distance>.03:
							maximum_grade = maxf(maximum_grade,jump/distance)
					previous[offset] = contact
	var headrooms: Array = []
	var body_probes: int = 0
	var adult: CapsuleShape3D = CapsuleShape3D.new()
	adult.radius = .25
	adult.height = 1.75
	for cut: Dictionary in terrain.landform.cuts:
		var at: Vector2 = cut["at"]
		var direction: Vector2 = cut["direction"]
		var minimum: float = INF
		for step: int in range(51):
			var xz: Vector2 = at+direction*lerpf(-2.5,2.5,step/50.0)
			var ground: float = terrain.surface_height(xz.x,xz.y)
			var body: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			body.shape = adult
			body.collision_mask = 2
			body.transform.origin = Vector3(xz.x,ground+.90,xz.y)
			body_probes += 1
			if not terrain.get_world_3d().direct_space_state.intersect_shape(body).is_empty():
				failures.append({"adult_collision":str(xz)})
		for along: float in [-.5,0,.5]:
			for across: float in [-.3,0,.3]:
				var xz: Vector2 = at+direction*along+direction.orthogonal()*across
				var ground: Vector3 = Vector3(xz.x,terrain.surface_height(xz.x,xz.y),xz.y)
				var hit: Dictionary = _ray(ground+Vector3.UP*.03,ground+Vector3.UP*6,2)
				if hit.is_empty():
					failures.append({"missing_soffit":str(ground)})
					continue
				var roof: Vector3 = hit["position"]
				minimum = minf(minimum,roof.y-ground.y)
		if minimum<2.2:
			failures.append({"headroom":minimum,"at":str(at)})
		headrooms.append({"at":str(at),"minimum":minimum})
	print("PHYSICAL_ROUTES_AUDIT ",JSON.stringify({"probes":probes,"maximum_step":maximum_step,"maximum_grade":maximum_grade,"headrooms":headrooms,"adult_body_probes":body_probes,"failure_count":failures.size(),"failures":failures.slice(0,40)}))
	quit(0 if failures.is_empty() else 1)
func _ray(a: Vector3,b: Vector3,mask: int) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a,b,mask)
	return terrain.get_world_3d().direct_space_state.intersect_ray(query)
