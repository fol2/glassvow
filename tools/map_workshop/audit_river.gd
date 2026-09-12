extends SceneTree
## Cover the whole channel, compare the bed field and guard dry route heights.
const Terrain = preload("res://presentation/map/landscape/terrain.gd")
const River = preload("res://presentation/map/landscape/river.gd")
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
	var river: River = terrain.get_node("Stream") as River
	var failures: Array = []
	var wet: int = 0
	var bed_samples: int = 0
	var minimum_width: float = INF
	var maximum_error: float = 0
	var faces: PackedVector3Array = river.mesh.get_faces()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	collision.shape = shape
	var body: StaticBody3D = StaticBody3D.new()
	body.add_child(collision)
	terrain.add_child(body)
	await physics_frame
	await physics_frame
	for row: int in range(301):
		var z: float = lerpf(-30,30,row/300.0)
		var width: float = 0
		for column: int in range(81):
			var x: float = River.centre(z)+lerpf(-4,4,column/80.0)
			var depth: float = River.LEVEL-terrain.surface_height(x,z)
			var uv: Vector2 = Vector2((x-River.centre(z))/8.0+.5,z/70.0+.5)
			var field: float = _filtered(river.field_image,uv)
			bed_samples += 1
			maximum_error = maxf(maximum_error,absf(field-depth))
			if absf(field-depth)>.03:
				failures.append({"bed_field_error":absf(field-depth),"at":str(Vector2(x,z))})
			if depth<.08:
				continue
			width += .1
			var at: Vector3 = Vector3(x,River.LEVEL,z)
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at+Vector3.UP*.1,at-Vector3.UP*.1)
			wet += 1
			if body.get_world_3d().direct_space_state.intersect_ray(query).is_empty() or field<=0:
				failures.append({"unfilled_channel":str(at)})
		minimum_width = minf(minimum_width,width)
	if minimum_width<4:
		failures.append({"narrow_or_empty_channel":minimum_width})
	var routes: int = 0
	var lowest: float = INF
	for source: PackedVector3Array in terrain.lines:
		var upper: bool = false
		for p: Vector3 in source:
			upper = upper or p.y>.015
		for p: Vector3 in preload("res://presentation/map/landscape/road_paths.gd").sample(source,.15):
			if not River.contains(p.x,p.z):
				continue
			var at: Vector3 = terrain.present(p,upper)
			routes += 1
			lowest = minf(lowest,at.y-River.LEVEL)
			if at.y<River.LEVEL+.25:
				failures.append({"flooded_route":str(at)})
	for cut: Dictionary in terrain.landform.cuts:
		var at: Vector2 = cut["at"]
		if River.contains(at.x,at.y):
			failures.append({"river_in_dry_pass":str(at)})
	print("RIVER_AUDIT ",JSON.stringify({"wet_surface_probes":wet,"bed_samples":bed_samples,"filtered_field_error":maximum_error,"minimum_wet_width":minimum_width,"route_probes":routes,"minimum_route_clearance":lowest,"failures":failures.slice(0,30),"failure_count":failures.size()}))
	quit(0 if wet>0 and routes>0 and failures.is_empty() else 1)

func _filtered(image: Image,uv: Vector2) -> float:
	var p: Vector2 = uv*Vector2(image.get_size())-Vector2.ONE*.5
	var base: Vector2i = Vector2i(floori(p.x),floori(p.y))
	var values: PackedFloat32Array = []
	for offset: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
		var at: Vector2i = (base+offset).clamp(Vector2i.ZERO,image.get_size()-Vector2i.ONE)
		values.append(image.get_pixel(at.x,at.y).r)
	return lerpf(lerpf(values[0],values[1],p.x-floorf(p.x)),lerpf(values[2],values[3],p.x-floorf(p.x)),p.y-floorf(p.y))
