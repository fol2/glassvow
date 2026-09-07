extends RefCounted
const Registry = preload("res://presentation/map/map_journey_camera_registry.gd")
const Routes = preload("res://presentation/map/map_layout_compiler_routes.gd")
static func run(fails: Array[String]) -> void:
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
