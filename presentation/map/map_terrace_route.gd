class_name MapTerraceRoute
extends RefCounted
## Resolve one terrace transition on a straight run, preserving the routed XZ path.
## Corners and node approaches stay level; infeasible routes fail explicitly.
static func resolve(source: PackedVector3Array, from_height: float, to_height: float,
		width: float, maximum_grade: float = .55, landing: float = 1.0) -> Dictionary:
	if source.size() < 2 or not is_finite(from_height) or not is_finite(to_height) \
			or not is_finite(width) or width <= 0 or maximum_grade <= 0 \
			or not is_finite(maximum_grade) or not is_finite(landing) \
			or maximum_grade > .17/.28 or landing < .28:
		return {"ok":false,"reason":"invalid terrace parameters"}
	var line: PackedVector3Array = []
	for p: Vector3 in source:
		if not p.is_finite():
			return {"ok":false,"reason":"non-finite route point"}
		var flat: Vector3 = Vector3(p.x,from_height,p.z)
		if not line.is_empty() and flat.distance_to(line[-1]) < .00001:
			continue
		while line.size() > 1 and (flat-line[-1]).normalized().dot((line[-1]-line[-2]).normalized()) > .999999:
			line.remove_at(line.size()-1)
		line.append(flat)
	if line.size() < 2:
		return {"ok":false,"reason":"zero-length terrace route"}
	var rise: float = absf(to_height-from_height)
	if rise < .00001:
		return {"ok":true,"line":line,"flight_index":-1}
	var reserve: float = landing+width*.5
	var run: float = maxf(rise/maximum_grade,ceili(rise/.17)*.28)+.001
	var best: int = -1
	var best_length: float = 0.0
	for i: int in range(line.size()-1):
		var length: float = line[i].distance_to(line[i+1])
		if length >= run+2*reserve and length > best_length:
			best = i
			best_length = length
	if best < 0:
		return _distributed(line,from_height,to_height,reserve,maximum_grade)
	var out: PackedVector3Array = []
	for i: int in range(line.size()):
		var p: Vector3 = line[i]
		p.y = from_height if i <= best else to_height
		out.append(p)
		if i == best:
			var direction: Vector3 = (line[i+1]-line[i]).normalized()
			var offset: float = (best_length-run)*.5
			var first: Vector3 = p+direction*offset
			var last: Vector3 = first+direction*run
			last.y = to_height
			out.append(first)
			out.append(last)
	return {"ok":true,"line":out,"flight_index":best+1,
		"landing_reserve_m":reserve,"grade":rise/run}

static func apply(routes: Dictionary, anchors: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id: String in MapLayoutCanonical.sorted_keys(routes):
		var edge: Dictionary = routes[id]
		var from_id: String = str(edge["from"])
		var to_id: String = str(edge["to"])
		if not anchors.has(from_id) or not anchors.has(to_id):
			return {"ok":false,"edge_id":id,"reason":"missing terrace anchor"}
		var a: Array = anchors[from_id]
		var b: Array = anchors[to_id]
		var line: PackedVector3Array = []
		for point: Array in edge["centerline"]:
			line.append(Vector3(MapLayoutCanonical.float_value(point[0]),0,
				MapLayoutCanonical.float_value(point[2])))
		var result: Dictionary = resolve(line,MapLayoutCanonical.float_value(a[1]),
			MapLayoutCanonical.float_value(b[1]),MapLayoutCanonical.float_value(edge["corridor_width"]))
		if result.get("ok") != true:
			result["edge_id"] = id
			return result
		var resolved: PackedVector3Array = result["line"]
		var points: Array = []
		for point: Vector3 in resolved:
			points.append([point.x,point.y,point.z])
		var updated: Dictionary = edge.duplicate(true)
		updated["centerline"] = points
		out[id] = updated
	return {"ok":true,"routes":out}

static func _distributed(line: PackedVector3Array,from_height: float,to_height: float,
		reserve: float,maximum_grade: float) -> Dictionary:
	var capacities: Array[float] = []
	var total: float = 0.0
	for i: int in range(line.size()-1):
		var available: float = maxf(0,line[i].distance_to(line[i+1])-2*reserve-.002)
		var capacity: float = minf(available*maximum_grade,floori(available/.28)*.17)
		capacities.append(capacity)
		total += capacity
	var rise: float = absf(to_height-from_height)
	if total < rise+.00001:
		return {"ok":false,"reason":"straight runs cannot fit terrace flights and level turns",
			"required_rise_m":rise,"available_rise_m":total}
	var out: PackedVector3Array = []
	var height: float = from_height
	var flights: int = 0
	for i: int in range(line.size()):
		var start: Vector3 = line[i]
		start.y = height
		out.append(start)
		if i == line.size()-1 or capacities[i] <= .00001:
			continue
		var part: float = rise*capacities[i]/total
		var run: float = maxf(part/maximum_grade,ceili(part/.17)*.28)+.001
		var segment: Vector3 = line[i+1]-line[i]
		var first: Vector3 = start+segment.normalized()*(segment.length()-run)*.5
		var last: Vector3 = first+segment.normalized()*run
		height += signf(to_height-from_height)*part
		last.y = height
		out.append(first)
		out.append(last)
		flights += 1
	out[-1].y = to_height
	return {"ok":true,"line":out,"flight_count":flights,"landing_reserve_m":reserve}
