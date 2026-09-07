extends RefCounted
## Select one heading for a complete sampled route, rather than flipping per point.
static func choose(points: Array[Vector3], headings: Array[float], visible: Callable) -> Dictionary:
	var best: float = 0
	var minimum: int = 2147483647
	for heading: float in headings:
		var blocked: int = 0
		for point: Vector3 in points:
			if visible.call(point,heading) != true:
				blocked += 1
		if blocked < minimum:
			minimum = blocked
			best = heading
		if blocked == 0:
			break
	return {"ok":not points.is_empty() and not headings.is_empty() and minimum==0,
		"heading":best,"blocked_samples":minimum,"samples":points.size()}

## Bounded dynamic programme: turn gradually before an obstruction, rather than
## waiting until the current direction is blocked and jumping to another side.
static func path(points: Array[Vector3], headings: Array[float], visible: Callable,
		degrees_per_metre: float = 12.0, forbidden: Dictionary = {}) -> Dictionary:
	if points.is_empty() or headings.is_empty():
		return {"ok":false,"reason":"empty camera route"}
	var costs: Array[float] = []
	var parents: Array[PackedInt32Array] = []
	for index: int in range(points.size()):
		var visible_count: int = 0
		var next: Array[float] = []
		var predecessors: PackedInt32Array = []
		for current: int in range(headings.size()):
			var best: float = INF
			var parent: int = -1
			if visible.call(points[index],headings[current]) == true:
				visible_count += 1
				if index==0:
					best = absf(headings[current])*0.0001
				else:
					var distance: float = points[index].distance_to(points[index-1])
					for previous: int in range(headings.size()):
						var turn: float = absf(headings[current]-headings[previous])
						var score: float = costs[previous]+turn*turn/maxf(distance,.001)
						if turn <= degrees_per_metre*distance+.0001 and score < best and not forbidden.has(_key(index,headings[previous],headings[current])):
							best = score
							parent = previous
			next.append(best)
			predecessors.append(parent)
		var minimum: float = next.min()
		if not is_finite(minimum):
			return {"ok":false,"reason":"no visible heading path within turn bound","sample":index,"visible_headings":visible_count,"position":[points[index].x,points[index].y,points[index].z]}
		costs = next
		parents.append(predecessors)
	var cursor: int = costs.find(costs.min())
	var selected: Array[float] = []
	selected.resize(points.size())
	for index: int in range(points.size()-1,-1,-1):
		selected[index] = headings[cursor]
		cursor = parents[index][cursor]
	return {"ok":true,"headings":selected,"samples":points.size(),"degrees_per_metre":degrees_per_metre}

static func _key(index: int, start: float, end: float) -> String:
	return "%d:%s:%s" % [index,str(start),str(end)]

## Reject interpolation that crosses an occluder even when both endpoints pass.
## Cache visibility and ban only failed transitions; never relax visibility.
static func visible_path(points: Array[Vector3], headings: Array[float], visible: Callable) -> Dictionary:
	var cache: Dictionary = {}
	var checked: Callable = func(point: Vector3, heading: float) -> bool:
		var key: Vector4 = Vector4(point.x,point.y,point.z,heading)
		if not cache.has(key):
			cache[key] = visible.call(point,heading) == true
		return cache[key] == true
	var forbidden: Dictionary = {}
	var last_failure: Dictionary = {}
	for attempt: int in range(8):
		var plan: Dictionary = path(points,headings,checked,90.0,forbidden)
		if plan["ok"] != true:
			return plan
		var angles: Array[float] = plan["headings"]
		var rejected: int = 0
		for index: int in range(1,points.size()):
			var steps: int = maxi(1,maxi(ceili(points[index].distance_to(points[index-1])/.05),ceili(absf(angles[index]-angles[index-1]))))
			for step: int in range(1,steps):
				var weight: float = float(step)/steps
				if checked.call(points[index-1].lerp(points[index],weight),lerpf(angles[index-1],angles[index],weight)) != true:
					var blocked_point: Vector3 = points[index-1].lerp(points[index],weight)
					last_failure = {"position":[blocked_point.x,blocked_point.y,blocked_point.z],"heading":lerpf(angles[index-1],angles[index],weight)}
					forbidden[_key(index,angles[index-1],angles[index])] = true
					rejected += 1
					break
		if rejected==0:
			plan["interpolation_checks"] = cache.size()
			return plan
	return {"ok":false,"reason":"interpolated camera visibility search exhausted","last_failure":last_failure}
