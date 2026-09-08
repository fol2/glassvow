extends RefCounted
## Architecture follows occupied route envelopes, not the unused seven-lane lattice.
const F = preload("res://domain/map_layout/map_layout_canonical.gd")
static func regions(edges: Dictionary, stations: Array[float], margin: float = 9.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index: int in range(stations.size()-1):
		var west: float = stations[index]
		var east: float = stations[index+1]
		var low: float = INF
		var high: float = -INF
		for edge: Dictionary in edges.values():
			var line: Array = edge["centerline"]
			var radius: float = F.float_value(edge["corridor_width"])*.5
			for i: int in range(line.size()-1):
				var a: Vector2 = Vector2(F.float_value(line[i][0]),F.float_value(line[i][2]))
				var b: Vector2 = Vector2(F.float_value(line[i+1][0]),F.float_value(line[i+1][2]))
				if maxf(a.x,b.x) < west or minf(a.x,b.x) > east:
					continue
				var first: float = 0.0
				var last: float = 1.0
				if absf(b.x-a.x) > .00001:
					first = clampf((west-a.x)/(b.x-a.x),0,1)
					last = clampf((east-a.x)/(b.x-a.x),0,1)
				var near_z: float = minf(a.lerp(b,first).y,a.lerp(b,last).y)
				var far_z: float = maxf(a.lerp(b,first).y,a.lerp(b,last).y)
				low = minf(low,near_z-radius-margin)
				high = maxf(high,far_z+radius+margin)
		assert(is_finite(low) and is_finite(high),"Precinct region has no route envelope")
		out.append({"west":west,"east":east,"near":low,"far":high})
	return out

static func at_x(regions: Array[Dictionary], x: float) -> Vector2:
	for region: Dictionary in regions:
		if x <= F.float_value(region["east"])+.00001:
			return Vector2(F.float_value(region["near"]),F.float_value(region["far"]))
	var last: Dictionary = regions[-1]
	return Vector2(F.float_value(last["near"]),F.float_value(last["far"]))

static func supports(box: AABB, regions: Array[Dictionary], openings: Array[Rect2] = []) -> bool:
	var footprint: Rect2 = Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
	for opening: Rect2 in openings:
		if footprint.intersects(opening):
			return false
	var covered: float = 0.0
	for region: Dictionary in regions:
		var west: float = maxf(box.position.x,F.float_value(region["west"]))
		var east: float = minf(box.end.x,F.float_value(region["east"]))
		if east <= west:
			continue
		if box.position.z < F.float_value(region["near"])-.001 or box.end.z > F.float_value(region["far"])+.001:
			return false
		covered += east-west
	return covered >= box.size.x-.001
