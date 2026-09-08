extends RefCounted
## Larger generated worlds retain metre-scale paint and continuous river coverage.
const Paint = preload("res://presentation/map/landscape/terrain_paint.gd")
const River = preload("res://presentation/map/landscape/river.gd")
const Terrain = preload("res://presentation/map/landscape/terrain.gd")

static func run(fails: Array[String]) -> void:
	var first: Rect2 = Rect2(-4,-3,8,6)
	var second: Rect2 = Rect2(124,61,8,6)
	# Straight ground routes have no asymmetric bend at this origin. Sampling
	# the distance field directly isolates world bounds from authored road wear.
	var a: PackedFloat32Array = []
	a.resize(128*96)
	a.fill(4.0)
	var b: PackedFloat32Array = a.duplicate()
	Paint._stamp(a,Vector2(-3,0),Vector2(3,0),first,128,96)
	Paint._stamp(b,Vector2(125,64),Vector2(131,64),second,128,96)
	if a.to_byte_array()!=b.to_byte_array():
		fails.append("journey bounds: translated routes changed their metre-scale distance field")
	var lines: Array[PackedVector3Array] = []
	var material: ShaderMaterial = Paint.create(lines,Callable(),second)
	var image: Image = material.get_meta("distance_image")
	if image.get_size()!=Vector2i(128,96):
		fails.append("journey bounds: larger world stretches the ground paint")
	var mapping: Vector4 = material.get_shader_parameter("world_bounds")
	if mapping!=Vector4(124,61,8,6):
		fails.append("journey bounds: shader samples a different world rectangle")
	if River.contains(River.centre(44),44) or not River.contains(River.centre(44),44,50):
		fails.append("journey bounds: extended river still stops at the old bank boundary")
	var terrain: Terrain = Terrain.new()
	terrain.bounds = second
	terrain._land()
	var ground: MeshInstance3D = terrain.get_node("Quiet sculpted ground") as MeshInstance3D
	var box: AABB = ground.mesh.get_aabb()
	if box.position.x!=124 or box.end.x!=132 or box.position.z!=61 or box.end.z!=67:
		fails.append("journey bounds: rendered terrain does not cover the generated extent")
	var arrays: Array = ground.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for vertex: Vector3 in vertices:
		if absf(terrain.surface_height(vertex.x,vertex.z)-vertex.y)>.00001:
			fails.append("journey bounds: asset contact and rendered ground disagree")
			break
	terrain.free()
