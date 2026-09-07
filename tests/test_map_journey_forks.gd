extends RefCounted
const Registry = preload("res://presentation/map/map_journey_camera_registry.gd")
const Routes = preload("res://presentation/map/map_layout_compiler_routes.gd")
static func run(fails: Array[String]) -> void:
	_test_lateral_exit(fails)
	_test_three_way_phone(fails)
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/map-quality-v2.json"))
	var quality: Dictionary = Registry.quality(base)
	var rows: Array = []
	for i: int in range(15): rows.append({"station_m":i*5.0,"height_m":0.0,"centre_z_m":0.0,"lane_spacing_m":6.0,"region":"woodland"})
	quality["spatial_profile"] = {"schema_version":1,"id":"short-readable-fork","act":0,"bounds_xz_m":[-10.0,-30.0,85.0,30.0],"rows":rows}
	var nodes: Array = [
		{"id":"A","type":"monster","row":0,"col":3,"jitter":[0.0,0.0]},
		{"id":"B","type":"monster","row":1,"col":2,"jitter":[0.0,0.0]},
		{"id":"C","type":"monster","row":1,"col":4,"jitter":[0.0,0.0]}]
	var edges: Array = [{"id":MapLayoutInput.edge_id("A","B"),"from":"A","to":"B"},
		{"id":MapLayoutInput.edge_id("A","C"),"from":"A","to":"C"}]
	var anchors: Dictionary = {"A":[0.0,0.0,0.0],"B":[5.0,0.0,-6.0],"C":[5.0,0.0,6.0]}
	var plan: Dictionary = Routes.route_plan(nodes,edges,anchors,quality)
	if plan.get("ok")!=true:
		fails.append("journey forks: readable fork could not be planned")
		return
	for edge: Dictionary in edges:
		if plan["ports"][edge["id"]]["branch_egress"] is Vector2:
			fails.append("journey forks: imposed a four-metre decorative guide on an already readable short fork")

	# A blocked required guide must name its blocker. An empty diagnosis makes
	# the bounded solver retry the wrong node positions indefinitely.
	var chosen: Dictionary = edges[0]
	var port: Dictionary = plan["ports"][chosen["id"]]
	port["target"] = Vector2(10,0)
	port["branch_egress"] = Vector2(4,4)
	var obstacles: Array[Dictionary] = [{"id":"node:C","polygon":PackedVector2Array([
		Vector2(3.8,3.8),Vector2(3.8,4.2),Vector2(4.2,4.2),Vector2(4.2,3.8)])}]
	var routed: Dictionary = Routes.route_planned(chosen,plan,obstacles,.2,.1,quality,
		PackedVector2Array([Vector2(-1,-10),Vector2(-1,10),Vector2(11,10),Vector2(11,-10)]),{})
	var diagnostic: Dictionary = routed.get("plan_diagnostics",{})
	var blocker: Dictionary = diagnostic.get("first_blocker",{})
	if routed.get("status")!=MapSingleEdgeRouter.NO_ROUTE or blocker.get("obstacle_id")!="node:C":
		fails.append("journey forks: rejected guide did not identify the actual obstructing node")

static func _test_lateral_exit(fails: Array[String]) -> void:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/map-quality-v2.json"))
	var q: Dictionary = Registry.quality(base)
	var rows: Array = []
	for i: int in range(15): rows.append({"station_m":i*15.0,"height_m":0.0,"centre_z_m":35.0 if i>0 else 0.0,"lane_spacing_m":5.0,"region":"woodland"})
	q["spatial_profile"] = {"schema_version":1,"id":"lateral-fork","act":0,"bounds_xz_m":[-10.0,-30.0,225.0,65.0],"rows":rows}
	var nodes: Array = [{"id":"A","type":"monster","row":0,"col":3,"jitter":[0.0,0.0]},{"id":"B","type":"monster","row":1,"col":2,"jitter":[0.0,0.0]},{"id":"C","type":"monster","row":1,"col":4,"jitter":[0.0,0.0]}]
	var edges: Array = [{"id":"AB","from":"A","to":"B"},{"id":"AC","from":"A","to":"C"}]
	var a: Dictionary = {"A":[0.0,0.0,0.0],"B":[15.0,0.0,30.0],"C":[15.0,0.0,40.0]}
	var plan: Dictionary = Routes.route_plan(nodes,edges,a,q)
	var p: Dictionary = plan["ports"]["AB"]
	var r: Dictionary = plan["ports"]["AC"]
	if not p["branch_egress"] is Vector2 or not r["branch_egress"] is Vector2:
		fails.append("lateral fork not repaired")
	else:
		var first: Vector2 = p["branch_egress"]-p["source"]
		var second: Vector2 = r["branch_egress"]-r["source"]
		if first.normalized().dot(second.normalized())>.75: fails.append("same-side destinations still produce parallel fork exits")

static func _test_three_way_phone(fails: Array[String]) -> void:
	# Preserved seed 17634 failure: 70-degree guides yielded only 29.847px.
	var fixture: GDScript = preload("res://tests/test_map_layout_compiler.gd")
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/map-quality-v2.json"))
	var quality: Dictionary = Registry.quality(base)
	var hard_rows: Array = quality["hard"]
	var hard: Dictionary = MapQualityEvaluator._index(hard_rows)
	var nodes: Array = [fixture._node("0,5",0,5),fixture._node("1,4",1,4),fixture._node("1,5",1,5),fixture._node("1,6",1,6)]
	var edges: Array = [fixture._edge("0,5","1,4"),fixture._edge("0,5","1,5"),fixture._edge("0,5","1,6")]
	var anchors: Dictionary = {"0,5":[-35.5456466674805,0.0,20.2646484375],
		"1,4":[-25.5432872772217,0.0,9.80974197387695],"1,5":[-24.723560333252,0.0,21.0255908966064],
		"1,6":[-25.7525196075439,0.0,31.3053207397461]}
	var plan: Dictionary = Routes.route_plan(nodes,edges,anchors,quality)
	var routes: Dictionary = {}
	for edge: Dictionary in edges:
		var port: Dictionary = plan["ports"][edge["id"]]
		if not port["branch_egress"] is Vector2:
			fails.append("journey forks: dense three-way branch has no measured guide")
			return
		var line: Array = [anchors[edge["from"]]]
		for point: Vector2 in [port["source"],port["branch_egress"],port["target"]]: line.append([point.x,0.0,point.y])
		line.append(anchors[edge["to"]])
		routes[edge["id"]]={"from":edge["from"],"to":edge["to"],"centerline":line}
	var registry: Dictionary = MapQualityEvaluator.camera_registry(nodes,quality,edges)
	for raw: Dictionary in registry["profiles"]:
		var profile: Dictionary = Registry.resolve(raw,anchors)
		var result: Dictionary = MapQualityEvaluator._fanout(profile,edges,routes,quality,hard)
		if not result["violations"].is_empty(): fails.append("journey forks: preserved three-way branch is unreadable at "+str(profile["id"]))
