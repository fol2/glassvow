extends RefCounted
const Relief = preload("res://tools/map_workshop/common/landscape_relief.gd")
static func run(fails: Array[String]) -> void:
	var profile: Dictionary = {"base_height":-3.0,"contact_height":-.1,"shoulder_width":10.0,
		"landforms":[{"x":30.0,"z":0.0,"radius_x":20.0,"radius_z":20.0,"height":8.0}]}
	var reserves: Array[Rect2] = [Rect2(-5,-5,10,10)]
	var attached: Dictionary = {"landforms":[{"reserve_index":0,"along":.5,"side":"far","offset":12.0}]}
	var resolved: Dictionary = Relief.resolve_profile(attached,reserves)
	if resolved["landforms"][0]["x"] != 0.0 or resolved["landforms"][0]["z"] != 17.0:
		fails.append("relief: landform does not follow generated reserve edge")
	if attached["landforms"][0].has("x"):
		fails.append("relief: resolution mutated source profile")
	for point: Vector2 in [Vector2.ZERO,Vector2(5,5),Vector2(-5,0)]:
		if not is_equal_approx(Relief.height_at(point,profile,reserves),-.1):
			fails.append("relief: landform intrudes into architectural reserve")
	if Relief.height_at(Vector2(30,0),profile,reserves) < 4.9:
		fails.append("relief: broad rise missing outside reserve")
	if Relief.height_at(Vector2(-60,0),profile,reserves) > -2.9:
		fails.append("relief: low ground missing")
	if absf(Relief.height_at(Vector2(5.001,0),profile,reserves)+.1) > .001:
		fails.append("relief: discontinuity at court contact")
	# Faceted presentation must leave the deterministic contact geometry unchanged.
	var bounds: Rect2 = Rect2(0,-10,40,20)
	var smooth_mesh: MeshInstance3D = Relief.build(bounds,profile,reserves,null)
	var faceted_profile: Dictionary = profile.duplicate(true)
	faceted_profile["faceted"] = true
	var faceted_mesh: MeshInstance3D = Relief.build(bounds,faceted_profile,reserves,null)
	var smooth_arrays: Array = smooth_mesh.mesh.surface_get_arrays(0)
	var faceted_arrays: Array = faceted_mesh.mesh.surface_get_arrays(0)
	if smooth_arrays[Mesh.ARRAY_VERTEX] != faceted_arrays[Mesh.ARRAY_VERTEX]:
		fails.append("relief: faceting changed contact geometry")
	var normals: PackedVector3Array = faceted_arrays[Mesh.ARRAY_NORMAL]
	for index: int in range(0,normals.size(),3):
		if normals[index].y <= 0.0 or not normals[index].is_equal_approx(normals[index+1]) or not normals[index].is_equal_approx(normals[index+2]):
			fails.append("relief: inconsistent or inverted facet normal")
			break
	smooth_mesh.free()
	faceted_mesh.free()
