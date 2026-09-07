extends RefCounted
const Passage = preload("res://presentation/map/map_passage_route.gd")
const Surface = preload("res://presentation/map/chapters/common/resolved_route_surface.gd")
static func run(fails: Array[String]) -> void:
	var edge: Dictionary = {"centerline":[[0,0,0],[3,0,3],[23,0,3],[43,0,3],[46,0,0]],"corridor_width":2.5}
	var result: Dictionary = Passage.resolve(edge,[{"deck_start_m":21.0,"deck_end_m":27.0}],3.1,.55,1.0)
	if result.get("ok") != true:
		fails.append("passage: rejected spacious approach with corners")
		return
	var line: PackedVector3Array = []
	for point: Array in result["line"]:
		line.append(Vector3(MapLayoutCanonical.float_value(point[0]),MapLayoutCanonical.float_value(point[1]),MapLayoutCanonical.float_value(point[2])))
	var mesh_plan: Dictionary = Surface.resolve(line,2.5,-1,.65)
	if mesh_plan.get("ok") != true:
		fails.append("passage: accepted route cannot produce real stairs: "+str(mesh_plan))
	var short: Dictionary = Passage.resolve(edge,[{"deck_start_m":4.0,"deck_end_m":27.0}],3.1,.55,1.0)
	if short.get("ok") == true:
		fails.append("passage: accepted insufficient approach before corner")
