extends SceneTree
## Rendered collision probes prove continuity, slope and adult-sized openings.
const Kit = preload("res://presentation/map/landscape/kit.gd")
const Terrain = preload("res://presentation/map/landscape/terrain.gd")
var failures: Array = []
var terrain: Terrain
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	terrain = Terrain.new()
	root.add_child(terrain)
	var sample: Dictionary = preload("res://tools/map_workshop/sample.gd").read()
	if sample.is_empty():
		quit(2)
		return
	var bounds: Rect2 = Rect2(-48,-30,96,60)
	if sample.has("spatial_profile"):
		bounds = preload("res://presentation/map/map_spatial_profile.gd").footprint({"spatial_profile":sample["spatial_profile"]})
	var cached: Resource
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--derived-cache-key="):
			cached = preload("res://presentation/map/map_journey_cache.gd").read(argument.trim_prefix("--derived-cache-key="))
			if cached == null:
				push_error("Declared derived cache is missing or invalid")
				quit(2)
				return
			var source: Dictionary = cached.get("source_result")
			if source.get("input_digest") != sample["input_digest"] or source.get("layout_digest") != sample["layout_digest"] or not _same_json_geometry(source["node_anchors"],sample["anchors"]) or not _same_json_geometry(source["edges"],sample["edges"]):
				push_error("Derived cache and declared sample describe different geometry")
				quit(2)
				return
	var spatial_profile: Dictionary = sample.get("spatial_profile",{})
	terrain.adaptive_river = str(spatial_profile.get("id","")).begins_with("woodland-journey-")
	terrain.build(sample,false,bounds,cached)
	if not terrain.failure.is_empty():
		push_error(terrain.failure)
		quit(2)
		return
	for name: String in ["Quiet sculpted ground","Continuous bridge decks","Joined bridge masonry"]:
		var item: MeshInstance3D = terrain.get_node(name) as MeshInstance3D
		var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		shape.set_faces(item.mesh.get_faces())
		shape.backface_collision = true
		var body: StaticBody3D = StaticBody3D.new()
		body.transform = item.transform
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
	var steep: Array[Dictionary] = []
	for source_line: PackedVector3Array in terrain.lines:
		var line: PackedVector3Array = preload("res://presentation/map/landscape/road_paths.gd").sample(source_line,.1)
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
							if jump/distance>.5:
								steep.append({"grade":jump/distance,"at":str(contact),"before":str(before),"upper":upper})
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
	if not steep.is_empty():
		steep.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			var first: float = a["grade"]
			var second: float = b["grade"]
			return first>second)
		failures.append({"steep_sections":steep.size(),"limit":.5,"worst":steep.slice(0,12)})
	var scenery: Dictionary = {}
	if "--scenery-contacts" in OS.get_cmdline_user_args():
		if cached==null:
			push_error("Scenery contacts require the matching actual derived placements")
			quit(2)
			return
		scenery = await _scenery_contacts(cached)
	print("SCENERY_CONTACTS_AUDIT ",JSON.stringify(scenery))
	print("PHYSICAL_ROUTES_AUDIT ",JSON.stringify({"derived_cache":terrain.restored,"probes":probes,"maximum_step":maximum_step,"maximum_grade":maximum_grade,"headrooms":headrooms,"adult_body_probes":body_probes,"failure_count":failures.size(),"failures":failures.slice(0,40)}))
	quit(0 if failures.is_empty() else 1)
func _ray(a: Vector3,b: Vector3,mask: int) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a,b,mask)
	return terrain.get_world_3d().direct_space_state.intersect_ray(query)

# The declared JSON sample rounds binary64 values; allow only sub-nanometre loss.
func _same_json_geometry(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(str(a))-float(str(b)))<0.000000001
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i: int in range(a.size()):
			if not _same_json_geometry(a[i],b[i]): return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _same_json_geometry(a[key],b[key]): return false
		return true
	return a==b

func _scenery_contacts(cached: Resource) -> Dictionary:
	var kit: Kit = Kit.new()
	kit.use_static_batches=true
	terrain.add_child(kit)
	kit.build(terrain,PackedVector3Array(),false,{},cached)
	if not kit.build_complete or not kit.failure.is_empty():
		failures.append({"scenery_build":kit.failure})
		return {"ok":false}
	for item: MeshInstance3D in kit.contacts.find_children("*","MeshInstance3D",true,false):
		var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		shape.set_faces(item.mesh.get_faces())
		var body: StaticBody3D = StaticBody3D.new()
		body.transform=terrain.global_transform.affine_inverse()*item.global_transform
		body.collision_layer=1
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape=shape
		body.add_child(collision)
		terrain.add_child(body)
	await physics_frame
	await physics_frame
	var feet: Dictionary = {}
	var count: int = 0
	var maximum_gap: float = -INF
	for i: int in range(kit.placed.size()):
		var kind: String = kit.placed[i]["kind"]
		if not feet.has(kind):
			var scene: PackedScene = load("res://assets/art/map-journey/"+kind+".glb") as PackedScene
			var source: Node3D = scene.instantiate() as Node3D
			var vertices: PackedVector3Array = []
			preload("res://presentation/map/map_journey_assets.gd")._collect(source,source.transform.affine_inverse(),vertices)
			source.free()
			var minimum: float = INF
			for point: Vector3 in vertices: minimum=minf(minimum,point.y)
			var unique: Dictionary = {}
			for point: Vector3 in vertices:
				if point.y<=minimum+.025: unique[point]=true
			feet[kind]=unique.keys()
		var anchor: Node3D = kit.placed_nodes[i]
		var closest: float = INF
		for foot: Vector3 in feet[kind]:
			var point: Vector3 = anchor.global_transform*foot
			var hit: Dictionary = _ray(point+Vector3.UP*2,point-Vector3.UP*4,1)
			if not hit.is_empty():
				var contact: Vector3 = hit["position"]
				closest=minf(closest,point.y-contact.y)
		maximum_gap=maxf(maximum_gap,closest)
		if closest>.05: failures.append({"floating_scenery":kind,"placement":i,"gap_m":closest,"at":str(anchor.position)})
		count+=1
	return {"placements":count,"maximum_lowest_contact_gap_m":maximum_gap,"limit_m":.05}
