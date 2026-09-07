extends RefCounted
## Combine parallel court flights into one physical stair per nearby route group.
## Input routes are already generated and evaluated. No route or node is removed.
const Flight = preload("res://tools/map_workshop/common/resolved_flight.gd")
const M = preload("res://tools/map_workshop/mesh_tools.gd")
static func resolve(plans: Array[Dictionary], boundaries: Array[float], gap: float = 8.0, minimum_width: float = 4.0) -> Dictionary:
	if not is_finite(gap) or gap < 0 or not is_finite(minimum_width) or minimum_width <= 0:
		return {"ok":false,"reason":"invalid court stair assembly dimensions"}
	var selected: Array[Dictionary] = []
	var groups: Array[Dictionary] = []
	for plan: Dictionary in plans:
		for flight: Dictionary in plan["flights"]:
			var first: PackedVector3Array = flight["risers"][0]
			var start: Vector3 = (first[0]+first[1])*.5
			var end: Vector3 = flight["walking"][-1]["end"]
			if absf(start.z-end.z) > .0001:
				continue
			var boundary: float = (start.x+end.x)*.5
			var match_boundary: bool = false
			for x: float in boundaries:
				match_boundary = match_boundary or absf(boundary-x)<.001
			if not match_boundary:
				continue
			selected.append(flight)
			var radius: float = maxf(minimum_width,MapLayoutCanonical.float_value(flight["width_m"]))*.5
			groups.append({"start":start,"end":end,"near":start.z-radius,"far":start.z+radius,"foundation":flight["foundation_m"]})
	groups.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return a["start"].x < b["start"].x if absf(MapLayoutCanonical.float_value(a["start"].x-b["start"].x))>.001 else a["near"]<b["near"])
	var merged: Array[Dictionary] = []
	for group: Dictionary in groups:
		if not merged.is_empty() and _same_axis(merged[-1],group) and group["near"]-merged[-1]["far"] <= gap:
			merged[-1]["far"] = maxf(MapLayoutCanonical.float_value(merged[-1]["far"]),MapLayoutCanonical.float_value(group["far"]))
		else:
			merged.append(group.duplicate())
	var result: Array[Dictionary] = []
	for plan: Dictionary in plans:
		var kept: Dictionary = plan.duplicate()
		var kept_flights: Array[Dictionary] = []
		for flight: Dictionary in plan["flights"]:
			if not selected.has(flight):
				kept_flights.append(flight)
		kept["flights"] = kept_flights
		for kind: String in ["tops","walls","risers"]:
			var removed: Array = []
			for flight: Dictionary in plan["flights"]:
				if selected.has(flight):
					var flight_faces: Array = flight[kind]
					removed.append_array(flight_faces)
			var faces: Array[PackedVector3Array] = []
			for face: PackedVector3Array in plan[kind]:
				if not removed.has(face):
					faces.append(face)
			kept[kind] = faces
		result.append(kept)
	var reserves: Dictionary = {}
	for index: int in range(merged.size()):
		var group: Dictionary = merged[index]
		var start: Vector3 = group["start"]
		var end: Vector3 = group["end"]
		start.z = (group["near"]+group["far"])*.5
		end.z = start.z
		var width: float = group["far"]-group["near"]
		var flight: Dictionary = Flight.between_landings(start,end,width,MapLayoutCanonical.float_value(group["foundation"]))
		if flight.get("ok") != true:
			return flight
		result.append(flight)
		reserves["court-stair-%d" % index] = {"centerline":[[start.x,start.y,start.z],[end.x,end.y,end.z]],"corridor_width":width}
	return {"ok":true,"plans":result,"groups":merged,"reserves":reserves}
static func _same_axis(a: Dictionary,b: Dictionary) -> bool:
	var first: Vector3 = a["start"]
	var second: Vector3 = b["start"]
	var first_end: Vector3 = a["end"]
	var second_end: Vector3 = b["end"]
	return a["foundation"] == b["foundation"] and absf(first.x-second.x)<.001 and absf(first.y-second.y)<.001 and absf(first_end.x-second_end.x)<.001 and absf(first_end.y-second_end.y)<.001

static func threshold(groups: Array[Dictionary], x: float, near_z: float, far_z: float) -> Dictionary:
	var openings: Array[Dictionary] = []
	var height: float = -INF
	for group: Dictionary in groups:
		var start: Vector3 = group["start"]
		var end: Vector3 = group["end"]
		if absf((start.x+end.x)*.5-x)>.001:
			continue
		height = maxf(height,maxf(start.y,end.y))
		openings.append({"near":group["near"]-.15,"far":group["far"]+.15})
	if openings.is_empty():
		return {"ok":false,"reason":"court threshold has no generated stair"}
	openings.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a["near"]<b["near"])
	if openings[0]["near"] < near_z or openings[-1]["far"] > far_z:
		return {"ok":false,"reason":"shared stairs exceed court support envelope"}
	return {"ok":true,"x":x,"near":near_z,"far":far_z,"height":height,"openings":openings}
static func build_retaining(parent: Node3D, layout: Dictionary, stone: Material, trim: Material, foundation: float = -1.0) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "OpenCourtRetaining"
	parent.add_child(root)
	var cursor: float = layout["near"]
	var intervals: Array[Vector2] = []
	for opening: Dictionary in layout["openings"]:
		if opening["near"]>cursor:
			intervals.append(Vector2(cursor,MapLayoutCanonical.float_value(opening["near"])))
		cursor = opening["far"]
	if cursor < layout["far"]:
		intervals.append(Vector2(cursor,MapLayoutCanonical.float_value(layout["far"])))
	var top: float = layout["height"]+.45
	for interval: Vector2 in intervals:
		var centre: float = (interval.x+interval.y)*.5
		M.box(root,Vector3(MapLayoutCanonical.float_value(layout["x"]),(top+foundation)*.5,centre),Vector3(1.2,top-foundation,interval.y-interval.x),stone,"RetainingWall")
		M.box(root,Vector3(MapLayoutCanonical.float_value(layout["x"]),top+.08,centre),Vector3(1.35,.16,interval.y-interval.x),trim,"RetainingCoping")
	return root
