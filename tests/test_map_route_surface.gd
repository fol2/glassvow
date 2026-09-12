extends RefCounted
const Surface = preload("res://presentation/map/chapters/common/resolved_route_surface.gd")
static func run(fails: Array[String]) -> void:
	var good: Dictionary = Surface.resolve(PackedVector3Array([Vector3(0,0,0),
		Vector3(2,0,0),Vector3(8,3,0),Vector3(10,3,0),Vector3(10,3,4)]),2.5,-1,.65)
	if good.get("ok") != true:
		fails.append("test_map_route_surface: separated landing and flight rejected")
	var bad: Dictionary = Surface.resolve(PackedVector3Array([Vector3(0,0,0),
		Vector3(6,3,0),Vector3(6,3,4)]),2.5,-1,.65)
	if bad.get("ok") == true:
		fails.append("test_map_route_surface: stair turn without landing accepted")
	# A tiny angular change on a long road is still a real full-width boundary.
	var raw: Array = [[17.710531,1.8,-22.329464],[18.340530,1.8,-22.329464],
		[62.815369,1.8,-22.309168],[63.445366,1.8,-22.309168]]
	var line: PackedVector3Array = []
	for point: Array in raw:
		line.append(Vector3(MapLayoutCanonical.float_value(point[0]),MapLayoutCanonical.float_value(point[1]),MapLayoutCanonical.float_value(point[2])))
	var plan: Dictionary = Surface.resolve(line,2.5,-1,.65)
	var mesh: ArrayMesh = preload("res://presentation/map/chapters/common/flight_mesh.gd").build(plan)
	var faces: PackedVector3Array = mesh.get_faces()
	var floors: Array[Dictionary] = []
	for index: int in range(0,faces.size(),3):
		var a: Vector3 = faces[index]
		var b: Vector3 = faces[index+1]
		var c: Vector3 = faces[index+2]
		var box: Rect2 = Rect2(Vector2(a.x,a.z),Vector2.ZERO).expand(Vector2(b.x,b.z)).expand(Vector2(c.x,c.z))
		floors.append({"a":a,"b":b,"c":c,"bounds":box.grow(.00001)})
	var empty: Array[Dictionary] = []
	var audit: Dictionary = preload("res://tools/map_workshop/common/threshold_mesh_audit.gd").sample(empty,floors,{"edge":{"centerline":raw,"corridor_width":2.5}},false)
	if audit["ok"] != true:
		fails.append("route surface: simplification removed governed corridor width")
