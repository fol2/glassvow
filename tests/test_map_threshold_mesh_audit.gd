extends RefCounted
const Audit = preload("res://tools/map_workshop/common/threshold_mesh_audit.gd")
static func run(fails: Array[String]) -> void:
	var floors: Array[Dictionary] = _plane(0.0)
	var empty: Array[Dictionary] = []
	var routes: Dictionary = {"road":{"corridor_width":2.5,"centerline":[[-4,0,0],[4,0,0]]}}
	var open: Dictionary = Audit.sample(empty,floors,routes,false)
	if open["ok"] != true or open["probe_count"] <= 0 or open["overhead_hits"] != 0:
		fails.append("threshold: supported open-air route rejected or unmeasured")
	if Audit.sample(empty,floors,routes)["ok"] == true:
		fails.append("threshold: covered passage accepted without ceiling evidence")
	if Audit.sample(empty,empty,routes,false)["ok"] == true:
		fails.append("threshold: unsupported open-air route accepted")
	for required: bool in [true,false]:
		if Audit.sample(_plane(1.8),floors,routes,required)["ok"] == true:
			fails.append("threshold: low obstruction escaped width probes")
		var covered: Dictionary = Audit.sample(_plane(3.0),floors,routes,required)
		var clearance: float = covered["minimum_headroom_m"]
		if covered["ok"] != true or not is_equal_approx(clearance,3.0):
			fails.append("threshold: clear roof not measured correctly")

static func _plane(y: float) -> Array[Dictionary]:
	var a: Vector3 = Vector3(-6,y,-3)
	var b: Vector3 = Vector3(6,y,-3)
	var c: Vector3 = Vector3(6,y,3)
	var d: Vector3 = Vector3(-6,y,3)
	return [{"a":a,"b":b,"c":c,"bounds":Rect2(-6,-3,12,6)},
		{"a":a,"b":c,"c":d,"bounds":Rect2(-6,-3,12,6)}]
