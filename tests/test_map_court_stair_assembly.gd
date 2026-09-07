extends RefCounted
const Assembly = preload("res://presentation/map/chapters/common/court_stair_assembly.gd")
const Surface = preload("res://presentation/map/chapters/common/resolved_route_surface.gd")
static func run(fails: Array[String]) -> void:
	for descending: bool in [false,true]:
		var plans: Array[Dictionary] = []
		for z: float in [-4.0,4.0]:
			var a: float = 1.8 if descending else 0.0
			var b: float = 0.0 if descending else 1.8
			plans.append(Surface.resolve(PackedVector3Array([Vector3(-10,a,z),Vector3(-2.25,a,z),Vector3(2.25,b,z),Vector3(10,b,z)]),2.5,-1,.65))
		var result: Dictionary = Assembly.resolve(plans,[0.0])
		if result.get("ok") != true or result["groups"].size()!=1:
			fails.append("court assembly: adjacent parallel flights did not combine")
			continue
		var group: Dictionary = result["groups"][0]
		if group["near"] != -6.0 or group["far"] != 6.0:
			fails.append("court assembly: shared stair does not enclose both routes")
		for i: int in range(2):
			if not result["plans"][i]["risers"].is_empty():
				fails.append("court assembly: retained old overlapping risers")
		var groups: Array[Dictionary] = result["groups"]
		var layout: Dictionary = Assembly.threshold(groups,0.0,-12,12)
		if layout.get("ok") != true or layout["openings"].size()!=1:
			fails.append("court assembly: retaining wall splits the shared stair")
		if plans[0]["risers"].is_empty():
			fails.append("court assembly: mutated input plans")
