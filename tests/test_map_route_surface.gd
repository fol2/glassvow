extends RefCounted
const Surface = preload("res://tools/map_workshop/common/resolved_route_surface.gd")
static func run(fails: Array[String]) -> void:
	var good: Dictionary = Surface.resolve(PackedVector3Array([Vector3(0,0,0),
		Vector3(2,0,0),Vector3(8,3,0),Vector3(10,3,0),Vector3(10,3,4)]),2.5,-1,.65)
	if good.get("ok") != true:
		fails.append("test_map_route_surface: separated landing and flight rejected")
	var bad: Dictionary = Surface.resolve(PackedVector3Array([Vector3(0,0,0),
		Vector3(6,3,0),Vector3(6,3,4)]),2.5,-1,.65)
	if bad.get("ok") == true:
		fails.append("test_map_route_surface: stair turn without landing accepted")
