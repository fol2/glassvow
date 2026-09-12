extends RefCounted
## Necessary physical endpoint constraints for local-camera candidate selection.
## Invisible nodes still obstruct roads. Reject only when every possible access
## stub lies inside the other node's minimum inflated safety rectangle.
const F = preload("res://domain/map_layout/map_layout_canonical.gd")

static func context(nodes: Array, edges: Array, quality: Dictionary) -> Dictionary:
	var roles: Dictionary = {}
	for node: Dictionary in nodes: roles[str(node["id"])] = {"in":[],"out":[]}
	for edge: Dictionary in edges:
		roles[str(edge["from"])]["out"].append(str(edge["to"]))
		roles[str(edge["to"])]["in"].append(str(edge["from"]))
	var calibration: Dictionary = quality["calibration"]["shipping_touch_waystone"]
	var half: Array = calibration["node_pair_half_extent_m"]
	var roads: Dictionary = quality["geometry"]["road_corridor"]
	var radius: float = F.float_value(roads["physical_half_width_m"])+F.float_value(roads["world_clearance_m"])
	return {"roles":roles,"half":Vector2(F.float_value(half[0]),F.float_value(half[1]))+Vector2.ONE*radius,
		"node_half":Vector2(F.float_value(half[0]),F.float_value(half[1])),"radius":radius,"road_half":F.float_value(roads["physical_half_width_m"]),
		"maximum_stub":minf(F.float_value(half[0]),F.float_value(quality["geometry"]["branch_fanout"]["common_departure_max_m"])),
		"epsilon":F.float_value(quality["epsilon"]["world_m"])}

static func rejection(ids: Array[String], anchors: Dictionary, authority: Dictionary) -> Dictionary:
	if ids.size()!=2: return {}
	var half: Vector2 = authority["half"]
	var stub: float = authority["maximum_stub"]
	var epsilon: float = authority["epsilon"]
	for index: int in range(2):
		var id: String = ids[index]
		var other: String = ids[1-index]
		var a: Array = anchors[id]
		var b: Array = anchors[other]
		# Different levels require the full grade-aware route proof.
		if absf(F.float_value(a[1])-F.float_value(b[1]))>epsilon: continue
		var dx: float = F.float_value(a[0])-F.float_value(b[0])
		var dz: float = F.float_value(a[2])-F.float_value(b[2])
		var reserve: Rect2 = authority.get("minimum_reservations",{}).get(other,Rect2(-half,half*2.0))
		if dz<=reserve.position.y+epsilon or dz>=reserve.end.y-epsilon: continue
		for direction: String in ["in","out"]:
			var required: bool = false
			for neighbour: String in authority["roles"][id][direction]:
				required = required or neighbour!=other
			if not required: continue
			var low: float = dx-stub if direction=="in" else dx
			var high: float = dx if direction=="in" else dx+stub
			if low>reserve.position.x+epsilon and high<reserve.end.x-epsilon:
				return {"metric_id":"route_endpoint_reserve","profile_id":"world","entities":[id,other],
					"reason":"every possible "+direction+" access stub lies inside node:"+other,
					"anchors":{id:a,other:b},"inflated_half_extent_m":[half.x,half.y],"maximum_stub_m":stub}
	return {}

static func nearby_pairs(node_sets: Dictionary, authority: Dictionary) -> Array[Array]:
	var ids: Array[String] = F.sorted_keys(node_sets)
	var bounds: Dictionary = {}
	for id: String in ids:
		var low: Vector2 = Vector2(INF,INF)
		var high: Vector2 = Vector2(-INF,-INF)
		for candidate: Dictionary in node_sets[id]["candidates"]:
			var a: Array = candidate["anchor"]
			var at: Vector2 = Vector2(F.float_value(a[0]),F.float_value(a[2]))
			low = low.min(at)
			high = high.max(at)
		bounds[id] = Rect2(low,high-low)
	_minimum_reservations(bounds,authority)
	# Broadphase includes the larger swept portals, not just marker bodies.
	var half: Vector2 = authority["half"]+Vector2.ONE*(F.float_value(authority["maximum_stub"])+F.float_value(authority["road_half"]))
	var out: Array[Array] = []
	for i: int in range(ids.size()):
		var a: Rect2 = bounds[ids[i]]
		for j: int in range(i+1,ids.size()):
			var b: Rect2 = bounds[ids[j]]
			if a.end.x+half.x<b.position.x or b.end.x+half.x<a.position.x: continue
			if a.end.y+half.y<b.position.y or b.end.y+half.y<a.position.y: continue
			out.append([ids[i],ids[j]])
	return out

static func _minimum_reservations(bounds: Dictionary, authority: Dictionary) -> void:
	var result: Dictionary = {}
	var radius: float = authority["radius"]
	var road_half: float = authority["road_half"]
	var epsilon: float = authority["epsilon"]
	for id: String in bounds:
		var own: Rect2 = bounds[id]
		var minimum: Dictionary = {"in":0.0,"out":0.0}
		for direction: String in ["in","out"]:
			for peer: String in authority["roles"][id][direction]:
				var other: Rect2 = bounds[peer]
				var forward: float = own.position.x-other.end.x if direction=="in" else other.position.x-own.end.x
				var stub: float = minf(F.float_value(authority["maximum_stub"]),maxf(0.0,(forward-2.0*epsilon)*0.5))
				minimum[direction] = maxf(F.float_value(minimum[direction]),stub)
		# With both stubs guaranteed, the actual convex portal contains this
		# rectangle for every assignment. A one-sided hull remains deferred.
		if F.float_value(minimum["in"])<=epsilon or F.float_value(minimum["out"])<=epsilon: continue
		var left: float = -F.float_value(minimum["in"])-road_half-radius
		var right: float = F.float_value(minimum["out"])+road_half+radius
		var depth: float = road_half+radius
		result[id] = Rect2(left,-depth,right-left,depth*2.0)
	authority["minimum_reservations"] = result
