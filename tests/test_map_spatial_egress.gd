extends RefCounted
const Routes = preload("res://presentation/map/map_layout_compiler_routes.gd")
static func run(fails: Array[String]) -> void:
	var edge: Dictionary = {"id":"e","from":"a","to":"b"}
	var plan: Dictionary = {"ports":{"e":{"source":Vector2.ZERO,"target":Vector2(10,0),
		"branch_egress":Vector2(3,3),"stub_m":0.0}},"anchors":{"a":[0,0,0],"b":[10,0,0]}}
	var obstacles: Array[Dictionary] = [{"id":"blocked-guide","polygon":PackedVector2Array([
		Vector2(2,2),Vector2(4,2),Vector2(4,4),Vector2(2,4)])}]
	var channel: PackedVector2Array = [Vector2(-5,-5),Vector2(15,-5),Vector2(15,10),Vector2(-5,10)]
	var strict: Dictionary = Routes.route_planned(edge,plan,obstacles,.5,.1,{"spatial_profile":{}},channel,{})
	if strict.get("status") == MapSingleEdgeRouter.ROUTED:
		fails.append("spatial egress: silently discarded blocked required guide")
	var legacy: Dictionary = Routes.route_planned(edge,plan,obstacles,.5,.1,{},channel,{})
	if legacy.get("status") != MapSingleEdgeRouter.ROUTED:
		fails.append("spatial egress: changed legacy direct-route fallback")
