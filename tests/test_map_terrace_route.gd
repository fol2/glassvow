extends RefCounted
const Terrace = preload("res://presentation/map/map_terrace_route.gd")
const Surface = preload("res://presentation/map/chapters/common/resolved_route_surface.gd")
static func run(fails: Array[String]) -> void:
	var straight: PackedVector3Array = [Vector3.ZERO,Vector3(30,0,0)]
	var centred: Dictionary = Terrace.resolve(straight,0,3.1,2.5)
	var compact_up: Dictionary = Terrace.resolve(straight,0,3.1,2.5,.55,1.0,1.0)
	var compact_down: Dictionary = Terrace.resolve(straight,3.1,0,2.5,.55,1.0,0.0)
	var centre_line: PackedVector3Array = centred["line"]
	var up_line: PackedVector3Array = compact_up["line"]
	var down_line: PackedVector3Array = compact_down["line"]
	if up_line[1].x<=centre_line[1].x or down_line[2].x>=centre_line[2].x:
		fails.append("terrace: compact approaches did not extend the level ground merge")
	if absf(30-up_line[2].x-2.25)>.0001 or absf(down_line[1].x-2.25)>.0001:
		fails.append("terrace: compact approaches lost their high landing reserve")
	if Surface.resolve(up_line,2.5,-1,.65).get("ok")!=true or Surface.resolve(down_line,2.5,-1,.65).get("ok")!=true:
		fails.append("terrace: compact approaches cannot produce actual stairs")
	var source: PackedVector3Array = [Vector3.ZERO,Vector3(2,0,0),Vector3(14,0,0),Vector3(14,0,5)]
	for heights: Vector2 in [Vector2(0,2),Vector2(2,0),Vector2(-2,-2),Vector2(0,.9),Vector2(.9,0)]:
		var result: Dictionary = Terrace.resolve(source,heights.x,heights.y,2.5)
		if result.get("ok") != true:
			fails.append("terrace: feasible ascent/descent rejected")
			continue
		var line: PackedVector3Array = result["line"]
		if line[0].y != heights.x or line[-1].y != heights.y:
			fails.append("terrace: changed endpoint heights")
		var mesh: Dictionary = Surface.resolve(line,2.5,-4,.65)
		if mesh.get("ok") != true:
			fails.append("terrace: actual flight/landing surface rejected")
		if line[-1].x != 14 or line[-1].z != 5:
			fails.append("terrace: moved routed endpoint")
	var short: Dictionary = Terrace.resolve(PackedVector3Array([Vector3.ZERO,Vector3(2,0,0),Vector3(2,0,2)]),0,3,2.5)
	if short.get("ok") == true:
		fails.append("terrace: accepted flight without turning clearance")

	var routes: Dictionary = {"edge":{"from":"a","to":"b","corridor_width":2.5,
		"centerline":[[0,0,0],[14,0,0]]}}
	var bound: Dictionary = Terrace.apply(routes,{"a":[0,.9,0],"b":[14,1.8,0]})
	if bound.get("ok") != true:
		fails.append("terrace: anchor-bound route resolution rejected")
	if Terrace.apply(routes,{}).get("ok") == true:
		fails.append("terrace: missing height authority accepted")

	var turning: PackedVector3Array = [Vector3.ZERO,Vector3(6,0,0),Vector3(6,0,6)]
	var split: Dictionary = Terrace.resolve(turning,0,.9,2.5)
	if split.get("ok") != true:
		fails.append("terrace: two legal flights around a level turn rejected")
	else:
		var split_line: PackedVector3Array = split["line"]
		if Surface.resolve(split_line,2.5,-1,.65).get("ok") != true:
			fails.append("terrace: distributed actual stair mesh invalid")
