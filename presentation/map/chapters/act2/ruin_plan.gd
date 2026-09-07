extends RefCounted
## Presentation-only destinations. Every ruin has exactly one generated-node owner.
var sites: Array[Dictionary] = []
var failure: String = ""
var route_points: Array[Vector3] = []
var used: Dictionary = {}
var preferred_centres: PackedVector3Array = []

func build(sample: Dictionary, anchors: Dictionary, routes: Dictionary) -> void:
	for line: PackedVector3Array in routes.values():
		for i: int in range(0,line.size(),2):
			route_points.append(line[i])
	var boss: String = ""
	for node: Dictionary in sample["nodes"]:
		if node["type"]=="boss":
			boss = node["id"]
	if boss.is_empty():
		failure = "The ruin plan requires a generated boss node"
		return
	var kinds: Array[String] = ["library","ward","ward","ward","quarter","quarter","quarter","quarter"]
	var preferred: Array[Vector3] = [anchors[boss]+Vector3(18,0,0),Vector3(-11,0,-49),Vector3(32,0,-45),Vector3(47,0,0),Vector3(-40,0,15),Vector3(-15,0,10),Vector3(12,0,15),Vector3(38,0,20)]
	if preferred_centres.size()==kinds.size(): preferred.assign(preferred_centres)
	for ordinal: int in range(kinds.size()):
		var kind: String = kinds[ordinal]
		var half: Vector2 = Vector2(7.1,5.8) if kind=="library" else (Vector2(5.0,3.5) if kind=="ward" else Vector2(6.3,4.3))
		var door_z: float = 5.0 if kind=="library" else (3.1 if kind=="ward" else 3.9)
		var floor_y: float = 2.02 if kind=="library" else (1.0 if kind=="ward" else .7)
		var choices: Array[Dictionary] = []
		for id: String in anchors:
			if used.has(id) or (ordinal==0 and id!=boss) or (ordinal>0 and id==boss):
				continue
			var anchor: Vector3 = anchors[id]
			for step: int in range(16):
				var yaw: float = step*TAU/16
				var facing: Vector3 = Vector3(sin(yaw),0,cos(yaw))
				for gap: float in [5.0,8.0,11.0,14.0,17.0]:
					var centre: Vector3 = anchor-facing*(half.y+gap)
					centre.y = anchor.y-floor_y if kind=="library" else 0.0
					var door: Vector3 = centre+facing*door_z+Vector3.UP*floor_y
					if absf(door.y-anchor.y)/maxf(1.0,Vector2(door.x-anchor.x,door.z-anchor.z).length()-3.6)>.42:
						continue
					choices.append({"kind":kind,"ordinal":ordinal,"node":id,"centre":centre,"yaw":yaw,"half":half,"door":door,"anchor":anchor,"score":Vector2(centre.x-preferred[ordinal].x,centre.z-preferred[ordinal].z).length()+gap*.3})
		choices.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a["score"]<b["score"])
		var found: bool = false
		for candidate: Dictionary in choices:
			if _clear(candidate):
				sites.append(candidate)
				used[candidate["node"]] = true
				found = true
				break
		if not found:
			failure = "No single-node entrance corridor for ruin "+str(ordinal)
			return

func _clear(site: Dictionary) -> bool:
	var centre: Vector3 = site["centre"]
	var yaw: float = site["yaw"]
	var half: Vector2 = site["half"]
	var a: Vector3 = site["anchor"]
	var b: Vector3 = site["door"]
	for p: Vector3 in route_points:
		var local: Vector3 = (p-centre).rotated(Vector3.UP,-yaw)
		if absf(local.x)<half.x+2.0 and absf(local.z)<half.y+2.0:
			return false
		if Vector2(p.x-a.x,p.z-a.z).length()>4.0 and _distance(p,a,b)<2.9:
			return false
	for other: Dictionary in sites:
		var other_centre: Vector3 = other["centre"]
		var other_half: Vector2 = other["half"]
		var other_a: Vector3 = other["anchor"]
		var other_b: Vector3 = other["door"]
		if Vector2(centre.x-other_centre.x,centre.z-other_centre.z).length()<half.length()+other_half.length()+2.0:
			return false
		if _distance(other_centre,a,b)<other_half.length()+2.0 or _distance(centre,other_a,other_b)<half.length()+2.0:
			return false
		for t: int in range(21):
			if _distance(a.lerp(b,t/20.0),other_a,other_b)<2.9:
				return false
	return true

func _distance(p: Vector3,a: Vector3,b: Vector3) -> float:
	var start: Vector2 = Vector2(a.x,a.z)
	var delta: Vector2 = Vector2(b.x-a.x,b.z-a.z)
	var point: Vector2 = Vector2(p.x,p.z)
	return point.distance_to(start+delta*clampf((point-start).dot(delta)/maxf(delta.length_squared(),.001),0,1))
