extends RefCounted
const Routes = preload("res://presentation/map/map_layout_compiler_routes.gd")
static func run(fails: Array[String]) -> void:
	var edge: Dictionary = {"id":"e"}
	var plan: Dictionary = {"keep_forward_bounds":true,"ports":{"e":{
		"source":Vector2(0,0),"target":Vector2(20,0)}},"spatial_footprint":Rect2(-10,-10,40,20)}
	var result: Dictionary = Routes._route_bypass(edge,plan,[],.5,.1,
		{"id":"near","z":-5.0,"west_x":-5.0,"east_x":25.0},.6)
	if result.get("ok") != true:
		fails.append("forward bypass: unobstructed forward reservation rejected")
	else:
		for point: Array in result["route"]["centerline"]:
			var x: float = MapLayoutCanonical.float_value(point[0])
			if x < -.001 or x > 20.001:
				fails.append("forward bypass: invaded adjacent row interval")

	var invalid: Dictionary = Routes._route_through(Vector2.ZERO,Vector2(-1,2),
		Vector2(20,0),[],.5,.1,.6,true)
	if invalid.get("status") != MapSingleEdgeRouter.NO_ROUTE:
		fails.append("forward route: accepted a guide behind its source")
	var guided: Dictionary = Routes._route_through(Vector2.ZERO,Vector2(3,2),
		Vector2(20,0),[],.5,.1,.6,true)
	if guided.get("status") != MapSingleEdgeRouter.ROUTED:
		fails.append("forward route: rejected an unobstructed guide")
