extends RefCounted
const Route = preload("res://presentation/map/map_court_stair_route.gd")
static func run(fails: Array[String]) -> void:
	var edges: Dictionary = {"a":{"from":"0,0","to":"1,0","corridor_width":2.5,
		"centerline":[[-10,0,-3],[-9,0,-3],[9,1.8,4],[10,1.8,4]]},
		"b":{"from":"0,1","to":"1,1","corridor_width":2.5,
		"centerline":[[-10,0,8],[-9,0,8],[9,1.8,8],[10,1.8,8]]}}
	var anchors: Dictionary = {"0,0":[-10,0,-3],"1,0":[10,1.8,4],"0,1":[-10,0,8],"1,1":[10,1.8,8]}
	var rows: Array = [{"station_m":-10},{"station_m":10}]
	var result: Dictionary = Route.apply(edges,anchors,rows)
	if result.get("ok") != true:
		fails.append("court stair: feasible transverse approach rejected")
		return
	for id: String in edges:
		var line: Array = result["routes"][id]["centerline"]
		for endpoint: int in [0,-1]:
			for axis: int in range(3):
				if MapLayoutCanonical.float_value(line[endpoint][axis]) != MapLayoutCanonical.float_value(edges[id]["centerline"][endpoint][axis]):
					fails.append("court stair: changed graph endpoint coordinate")
		if not is_equal_approx(MapLayoutCanonical.float_value(line[3][0]),-2.25) or not is_equal_approx(MapLayoutCanonical.float_value(line[4][0]),2.25) or line[3][2] != line[4][2]:
			fails.append("court stair: flights do not share the recipe axis")
		if line[2][1] != line[3][1] or line[4][1] != line[5][1]:
			fails.append("court stair: turn lies on an incline")
	var compressed: Dictionary = edges.duplicate(true)
	compressed["a"]["centerline"][1][0] = -2
	if Route.apply(compressed,anchors,rows).get("ok") == true:
		fails.append("court stair: accepted missing approach landing")
	if edges["a"]["centerline"].size() != 4:
		fails.append("court stair: mutated source")

	var level_edges: Dictionary = {"level":{"from":"0,0","to":"1,0","centerline":[[-10,0,0],[-9,0,0],[9,0,0],[10,0,0]],"corridor_width":2.5}}
	var level_result: Dictionary = Route.apply(level_edges,{"0,0":[-10,1.8,0],"1,0":[10,1.8,0]},rows)
	for point: Array in level_result["routes"]["level"]["centerline"]:
		if point[1] != 1.8:
			fails.append("court stair: level route lost its anchor elevation")

	var raw_edges: Dictionary = edges.duplicate(true)
	for edge: Dictionary in raw_edges.values():
		for point: Array in edge["centerline"]:
			point[1] = 0.0
	var raw_result: Dictionary = Route.apply(raw_edges,anchors,rows)
	for edge: Dictionary in raw_result["routes"].values():
		if edge["centerline"][-1][1] != 1.8:
			fails.append("court stair: raw route endpoint lost anchor height")

	var fork: Dictionary = {"branch":{"from":"0,0","to":"1,0","corridor_width":2.5,
		"centerline":[[-15,0,0],[-14.37,0,0],[-11.54,0,2.83],[14.37,0,-8],[15,0,-8]]}}
	var fork_result: Dictionary = Route.apply(fork,{"0,0":[-15,0,0],"1,0":[15,2.4,-8]},[{"station_m":-15},{"station_m":15}])
	if fork_result.get("ok")!=true: fails.append("court stair: clear branch launch rejected")
	else:
		var fork_line: Array = fork_result["routes"]["branch"]["centerline"]
		if fork_line[2]!=[-11.54,0.0,2.83]: fails.append("court stair: erased the compiler's branch departure guide")
