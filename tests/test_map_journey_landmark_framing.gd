extends RefCounted
const Framing = preload("res://presentation/map/map_journey_framing.gd")
static func run(fails: Array[String]) -> void:
	var pose: Dictionary = {"origin":[0,0,0],"scale":[1,1,1],"yaw_radians":0.0}
	var data: Dictionary = {"node_anchors":{"entry":[0,0,0],"middle":[10,0,0],"end":[20,0,0]},
		"edges":{"a":{"from":"entry","to":"middle"},"b":{"from":"middle","to":"end"}},
		"hero_placements":{"vigil":{"profile_id":"window","transform":pose},"terminus":{"profile_id":"hearth","transform":pose}}}
	var assets: Dictionary = {"profiles":{"window":{"local_aabb":AABB(Vector3(-10,0,-5),Vector3(20,29,5))},
		"hearth":{"local_aabb":AABB(Vector3.ZERO,Vector3(6,4,2))}}}
	var result: Dictionary = Framing.terminals(data,assets)
	if not result.has("entry") or not result.has("end") or result.has("middle"):
		fails.append("landmark framing: entry/end geometry was assigned to the wrong route context")
		return
	var corners: PackedVector3Array = result["entry"]
	var high: float = -INF
	for p: Vector3 in corners: high=maxf(high,p.y)
	if corners.size()!=8 or high!=29:
		fails.append("landmark framing: the monumental window top was omitted")
