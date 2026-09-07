extends RefCounted
## Exact shared cross-sections for level landings; straight inclines become flights.
const Flight = preload("res://tools/map_workshop/common/resolved_flight.gd")

static func resolve(source: PackedVector3Array, width: float,
		foundation: float, deck_depth: float) -> Dictionary:
	var line: PackedVector3Array = _simplified(source)
	if line.size() < 2 or width <= 0.0 or deck_depth <= 0.0:
		return {"ok": false, "reason": "invalid route surface dimensions"}
	var sides: PackedVector3Array = []
	for index: int in range(line.size()):
		var incoming: Vector3 = _flat(line[index] - line[maxi(0, index-1)]).normalized()
		var outgoing: Vector3 = _flat(line[mini(line.size()-1, index+1)] - line[index]).normalized()
		if index == 0:
			incoming = outgoing
		if index == line.size()-1:
			outgoing = incoming
		var side: Vector3 = (incoming + outgoing).normalized().cross(Vector3.UP)
		var denominator: float = side.dot(outgoing.cross(Vector3.UP))
		if denominator < .2:
			return {"ok": false, "reason": "reversing corner needs a designed platform", "index": index}
		sides.append(side * width * .5 / denominator)
	var tops: Array[PackedVector3Array] = []
	var walls: Array[PackedVector3Array] = []
	var risers: Array[PackedVector3Array] = []
	var flights: Array[Dictionary] = []
	for index: int in range(line.size()-1):
		var a: Vector3 = line[index]
		var b: Vector3 = line[index+1]
		if absf(a.y-b.y) > .0001:
			var perpendicular: Vector3 = _flat(b-a).normalized().cross(Vector3.UP)*width*.5
			if sides[index].distance_to(perpendicular) > .001 or sides[index+1].distance_to(perpendicular) > .001:
				return {"ok": false, "reason": "incline meets a corner without a level landing", "index": index}
			var flight: Dictionary = Flight.between_landings(a,b,width,foundation)
			if flight.get("ok") != true:
				return flight
			var flight_tops: Array = flight["tops"]
			var flight_walls: Array = flight["walls"]
			var flight_risers: Array = flight["risers"]
			tops.append_array(flight_tops)
			walls.append_array(flight_walls)
			risers.append_array(flight_risers)
			flights.append(flight)
			continue
		# One buffered polygon owns each connected level run, including its corners.
		if index > 0 and absf(line[index-1].y-a.y) <= .0001:
			continue
		var level_line: PackedVector2Array = [Vector2(a.x,a.z)]
		var end_index: int = index+1
		while end_index < line.size() and absf(line[end_index].y-a.y) <= .0001:
			level_line.append(Vector2(line[end_index].x,line[end_index].z))
			end_index += 1
		var polygons: Array[PackedVector2Array] = Geometry2D.offset_polyline(
			level_line,width*.5,Geometry2D.JOIN_ROUND,Geometry2D.END_BUTT)
		for polygon: PackedVector2Array in polygons:
			if Geometry2D.is_polygon_clockwise(polygon):
				return {"ok": false, "reason": "level route encloses a hole requiring an explicit courtyard"}
			var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
			if indices.is_empty():
				return {"ok": false, "reason": "level footprint did not triangulate"}
			var bottom: float = maxf(foundation,a.y-deck_depth)
			for triangle: int in range(0,indices.size(),3):
				var face: PackedVector3Array = []
				var underside: PackedVector3Array = []
				for offset: int in range(3):
					var point: Vector2 = polygon[indices[triangle+offset]]
					face.append(Vector3(point.x,a.y,point.y))
					underside.append(Vector3(point.x,bottom,point.y))
				tops.append(face)
				underside.reverse()
				walls.append(underside)
			for boundary: int in range(polygon.size()):
				var start: Vector2 = polygon[boundary]
				var end: Vector2 = polygon[(boundary+1)%polygon.size()]
				walls.append(PackedVector3Array([Vector3(start.x,a.y,start.y),
					Vector3(start.x,bottom,start.y),Vector3(end.x,bottom,end.y),Vector3(end.x,a.y,end.y)]))

	return {"ok": true, "tops":tops,"walls":walls,"risers":risers,"flights":flights,"line":line}

static func _flat(value: Vector3) -> Vector3:
	return Vector3(value.x,0,value.z)

static func _simplified(source: PackedVector3Array) -> PackedVector3Array:
	var out: PackedVector3Array = []
	for point: Vector3 in source:
		if not out.is_empty() and point.distance_to(out[-1]) < .00001:
			continue
		while out.size() > 1:
			var a: Vector3 = out[-1]-out[-2]
			var b: Vector3 = point-out[-1]
			# An angular threshold alone trims measurable corridor width on long runs.
			var deviation: float = a.cross(b).length()/maxf((a+b).length(),.00001)
			if a.normalized().dot(b.normalized()) < .999999 or deviation > .00001:
				break
			out.remove_at(out.size()-1)
		out.append(point)
	return out
