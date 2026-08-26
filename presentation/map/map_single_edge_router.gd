class_name MapSingleEdgeRouter
extends RefCounted
## Deterministic one-edge visibility-graph router over #465 convex footprints.
const ROUTED: String = "ROUTED"
const NO_ROUTE: String = "NO_ROUTE"
const INVALID_INPUT: String = "INVALID_INPUT"
const WORLD_EPSILON_M: float = 0.001
const RATIO_EPSILON: float = 0.000001
const MAX_OBSTACLES: int = 15 * 7 + 2
const MAX_VERTICES: int = 8
const MAX_CHANNEL_VERTICES: int = 8
const MAX_CANDIDATES: int = 512
const MAX_VISIBILITY_EDGES: int = (MAX_CANDIDATES * (MAX_CANDIDATES - 1)) >> 1
const MAX_SEARCH_STATES: int = MAX_VISIBILITY_EDGES * 2 + 1
const LENGTH: int = 0
const BENDS: int = 1
const ANGLE: int = 2
const LANE: int = 3
const CLEARANCE: int = 4
static func route(source: Vector2, target: Vector2, obstacles: Array[Dictionary],
		half_width: float, safety: float,
		channel_raw: PackedVector2Array = PackedVector2Array()) -> Dictionary:
	if not _finite(source) or not _finite(target) or source.distance_to(target) <= WORLD_EPSILON_M \
			or not is_finite(half_width) or half_width <= 0.0 or not is_finite(safety) or safety < 0.0:
		return _result(INVALID_INPUT, [], half_width, {}, {}, "invalid input")
	var prepared: Dictionary = _prepare(obstacles, half_width + safety)
	if not bool(prepared.get("ok", false)):
		return _result(INVALID_INPUT, [], half_width, {}, {}, str(prepared.get("reason", "invalid obstacle")))
	var channel: PackedVector2Array = PackedVector2Array()
	if not channel_raw.is_empty():
		var channel_value: Dictionary = MapAssetProfiles.canonical_polygon(channel_raw)
		var channel_v: Variant = channel_value.get("points", PackedVector2Array())
		if not bool(channel_value.get("ok", false)) or not (channel_v is PackedVector2Array):
			return _result(INVALID_INPUT, [], half_width, {}, {}, "invalid channel")
		channel = channel_v
		if channel.size() > MAX_CHANNEL_VERTICES:
			return _result(INVALID_INPUT, [], half_width, {}, {}, "channel bound exceeded")
	var rows_v: Variant = prepared.get("rows", [])
	var inflated: Array = rows_v if rows_v is Array else []
	var diagnostics: Dictionary = _diagnostics(prepared, 0, 0, 0, 0)
	if (not channel.is_empty() and (not _inside(source, channel) or not _inside(target, channel))) \
			or not _clear(source, source, inflated) or not _clear(target, target, inflated):
		return _result(NO_ROUTE, [], half_width, {}, diagnostics, "endpoint infeasible")
	var points: Array = _candidates(source, target, inflated, channel)
	if points.size() > MAX_CANDIDATES:
		diagnostics = _diagnostics(prepared, points.size(), 0, 0, 0)
		return _result(INVALID_INPUT, [], half_width, {}, diagnostics, "candidate bound exceeded")
	var graph: Dictionary = _graph(points, inflated)
	var search: Dictionary = _search(points, graph, inflated, source, target)
	diagnostics = _diagnostics(prepared, points.size(), int(graph.get("edge_count", 0)),
			int(search.get("state_count", 0)), int(search.get("expansions", 0)))
	if not bool(search.get("ok", false)):
		return _result(NO_ROUTE, [], half_width, {}, diagnostics, "visibility graph disconnected")
	var path_v: Variant = search.get("path", [])
	var path: Array = _simplify(path_v if path_v is Array else [], inflated)
	var cost: Array = _path_cost(path, inflated, source, target)
	return _result(ROUTED, path, half_width, _cost_dict(cost, source.distance_to(target)), diagnostics, "")
static func inflate_obstacles(obstacles: Array[Dictionary], radius: float) -> Array:
	var prepared: Dictionary = _prepare(obstacles, radius)
	var rows_v: Variant = prepared.get("rows", [])
	return rows_v if bool(prepared.get("ok", false)) and rows_v is Array else []
static func segment_is_clear(a: Vector2, b: Vector2, inflated: Array) -> bool:
	return _clear(a, b, inflated)
static func _prepare(obstacles: Array[Dictionary], radius: float) -> Dictionary:
	if obstacles.size() > MAX_OBSTACLES or not is_finite(radius) or radius < 0.0:
		return {"ok": false, "reason": "obstacle bound or radius"}
	var by_id: Dictionary = {}
	for raw: Dictionary in obstacles:
		var id: String = str(raw.get("id", ""))
		var canonical: Dictionary = MapAssetProfiles.canonical_polygon(raw.get("polygon", null))
		var points_v: Variant = canonical.get("points", PackedVector2Array())
		if id.is_empty() or by_id.has(id) or not bool(canonical.get("ok", false)) or not (points_v is PackedVector2Array):
			return {"ok": false, "reason": "invalid obstacle"}
		var points: PackedVector2Array = points_v
		if points.size() > MAX_VERTICES:
			return {"ok": false, "reason": "obstacle vertex bound exceeded"}
		by_id[id] = points
	var rows: Array = []
	var vertices: int = 0
	for id: String in MapLayoutCanonical.sorted_keys(by_id):
		var polygon: PackedVector2Array = by_id[id]
		var inflated: PackedVector2Array = polygon.duplicate()
		if radius > 0.0:
			var offsets: Array[PackedVector2Array] = Geometry2D.offset_polygon(polygon, radius, Geometry2D.JOIN_MITER)
			if offsets.size() != 1:
				return {"ok": false, "reason": "inflation failed"}
			var canonical: Dictionary = MapAssetProfiles.canonical_polygon(offsets[0])
			var inflated_v: Variant = canonical.get("points", PackedVector2Array())
			if not bool(canonical.get("ok", false)) or not (inflated_v is PackedVector2Array):
				return {"ok": false, "reason": "inflation failed"}
			inflated = inflated_v
		rows.append({"id": id, "polygon": inflated})
		vertices += inflated.size()
	return {"ok": true, "rows": rows, "vertex_count": vertices}
static func _candidates(source: Vector2, target: Vector2, obstacles: Array,
		channel: PackedVector2Array) -> Array:
	var points: Array = [source, target]
	for row_v: Variant in obstacles:
		var row: Dictionary = row_v
		var polygon: PackedVector2Array = row["polygon"]
		for point: Vector2 in polygon:
			_add(points, point, obstacles, channel)
	for point: Vector2 in channel:
		_add(points, point, obstacles, channel)
	return points
static func _add(points: Array, point: Vector2, obstacles: Array, channel: PackedVector2Array) -> void:
	if (not channel.is_empty() and not _inside(point, channel)) or not _clear(point, point, obstacles):
		return
	for existing_v: Variant in points:
		var existing: Vector2 = existing_v
		if existing.distance_to(point) <= WORLD_EPSILON_M:
			return
	points.append(point)
static func _graph(points: Array, obstacles: Array) -> Dictionary:
	var adjacency: Array = []
	adjacency.resize(points.size())
	for i: int in range(points.size()):
		adjacency[i] = PackedInt32Array()
	var count: int = 0
	for i: int in range(points.size()):
		for j: int in range(i + 1, points.size()):
			if _clear(points[i], points[j], obstacles):
				(adjacency[i] as PackedInt32Array).append(j)
				(adjacency[j] as PackedInt32Array).append(i)
				count += 1
	return {"adjacency": adjacency, "edge_count": count}
static func _search(points: Array, graph: Dictionary, obstacles: Array,
		source: Vector2, target: Vector2) -> Dictionary:
	var open: Array = []
	var labels: Dictionary = {}
	var closed: Dictionary = {}
	var serial: int = 0
	var start: Dictionary = {"s": "-1>0", "p": -1, "n": 0, "parent": "",
		"c": [0.0, 0, 0.0, 0.0, 0.0], "k": "000", "v": serial}
	labels[start["s"]] = start
	open.append(start)
	var target_state: String = ""
	var expansions: int = 0
	while not open.is_empty():
		open.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _less(a["c"], str(a["k"]), b["c"], str(b["k"])))
		var current: Dictionary = open.pop_front()
		var state: String = str(current["s"])
		if closed.has(state) or int((labels[state] as Dictionary)["v"]) != int(current["v"]):
			continue
		closed[state] = true
		expansions += 1
		var at: int = int(current["n"])
		if at == 1:
			target_state = state
			break
		var neighbours: PackedInt32Array = (graph["adjacency"] as Array)[at]
		for next: int in neighbours:
			var previous: int = int(current["p"])
			if next == previous:
				continue
			var previous_point: Variant = points[previous] if previous >= 0 else null
			var cost: Array = _advance(current["c"], previous_point, points[at], points[next], obstacles, source, target)
			var next_state: String = "%d>%d" % [at, next]
			var key: String = "%s|%03d" % [str(current["k"]), next]
			if labels.has(next_state):
				var old: Dictionary = labels[next_state]
				if not _less(cost, key, old["c"], str(old["k"])):
					continue
			serial += 1
			var label: Dictionary = {"s": next_state, "p": at, "n": next,
				"parent": state, "c": cost, "k": key, "v": serial}
			labels[next_state] = label
			open.append(label)
	if target_state.is_empty():
		return {"ok": false, "state_count": labels.size(), "expansions": expansions}
	var path: Array = []
	while not target_state.is_empty():
		var label: Dictionary = labels[target_state]
		path.push_front(points[int(label["n"])])
		target_state = str(label["parent"])
	return {"ok": true, "path": path, "state_count": labels.size(), "expansions": expansions}
static func _advance(cost_v: Variant, previous_v: Variant, a: Vector2, b: Vector2,
		obstacles: Array, source: Vector2, target: Vector2) -> Array:
	var cost: Array = (cost_v as Array).duplicate()
	var leg: float = a.distance_to(b)
	cost[LENGTH] = float(cost[LENGTH]) + leg
	cost[LANE] = float(cost[LANE]) + leg * absf((target - source).cross((a + b) * 0.5 - source)) / source.distance_to(target)
	cost[CLEARANCE] = float(cost[CLEARANCE]) + _clearance(leg, a, b, obstacles)
	if previous_v is Vector2:
		var previous: Vector2 = previous_v
		var turn: float = absf(rad_to_deg((a - previous).angle_to(b - a)))
		if turn > RATIO_EPSILON:
			cost[BENDS] = int(cost[BENDS]) + 1
			cost[ANGLE] = float(cost[ANGLE]) + turn
	return cost
static func _less(a_v: Variant, a_key: String, b_v: Variant, b_key: String) -> bool:
	var a: Array = a_v
	var b: Array = b_v
	for i: int in range(a.size()):
		var epsilon: float = WORLD_EPSILON_M if i == LENGTH else RATIO_EPSILON
		if absf(float(a[i]) - float(b[i])) > epsilon:
			return float(a[i]) < float(b[i])
	return a_key < b_key
static func _simplify(path: Array, obstacles: Array) -> Array:
	var out: Array = path.duplicate()
	var i: int = 1
	while i + 1 < out.size():
		var a: Vector2 = out[i - 1]
		var b: Vector2 = out[i]
		var c: Vector2 = out[i + 1]
		if absf((b - a).cross(c - b)) <= WORLD_EPSILON_M * maxf(1.0, a.distance_to(c)) and _clear(a, c, obstacles):
			out.remove_at(i)
		else:
			i += 1
	return out
static func _path_cost(path: Array, obstacles: Array, source: Vector2, target: Vector2) -> Array:
	var cost: Array = [0.0, 0, 0.0, 0.0, 0.0]
	for i: int in range(path.size() - 1):
		cost = _advance(cost, path[i - 1] if i > 0 else null, path[i], path[i + 1], obstacles, source, target)
	return cost
static func _cost_dict(cost: Array, direct: float) -> Dictionary:
	return {"total_length_m": cost[LENGTH], "route_length_ratio": float(cost[LENGTH]) / direct,
		"bend_count": cost[BENDS], "bend_angle_deg_per_edge": cost[ANGLE],
		"lane_deviation_m2": cost[LANE], "obstacle_clearance_penalty": cost[CLEARANCE]}
static func _clear(a: Vector2, b: Vector2, obstacles: Array) -> bool:
	for row_v: Variant in obstacles:
		var row: Dictionary = row_v
		if _penetrates(a, b, row["polygon"]):
			return false
	return true
static func _penetrates(a: Vector2, b: Vector2, polygon: PackedVector2Array) -> bool:
	var low: float = 0.0
	var high: float = 1.0
	var delta: Vector2 = b - a
	for i: int in range(polygon.size()):
		var edge: Vector2 = polygon[(i + 1) % polygon.size()] - polygon[i]
		var f0: float = edge.cross(a - polygon[i]) / edge.length()
		var fd: float = edge.cross(delta) / edge.length()
		if absf(fd) <= RATIO_EPSILON:
			if f0 >= -WORLD_EPSILON_M:
				return false
			continue
		var t: float = (-WORLD_EPSILON_M - f0) / fd
		if fd > 0.0:
			high = minf(high, t)
		else:
			low = maxf(low, t)
		if low >= high - RATIO_EPSILON:
			return false
	return low < high - RATIO_EPSILON
static func _inside(point: Vector2, polygon: PackedVector2Array) -> bool:
	for i: int in range(polygon.size()):
		var edge: Vector2 = polygon[(i + 1) % polygon.size()] - polygon[i]
		if edge.cross(point - polygon[i]) / edge.length() > WORLD_EPSILON_M:
			return false
	return true
static func _clearance(length: float, a: Vector2, b: Vector2, obstacles: Array) -> float:
	var penalty: float = 0.0
	for row_v: Variant in obstacles:
		var row: Dictionary = row_v
		var polygon: PackedVector2Array = row["polygon"]
		var closest: float = INF
		for i: int in range(polygon.size()):
			var pair: PackedVector2Array = Geometry2D.get_closest_points_between_segments(
					a, b, polygon[i], polygon[(i + 1) % polygon.size()])
			closest = minf(closest, pair[0].distance_to(pair[1]))
		penalty += length / maxf(closest, WORLD_EPSILON_M)
	return penalty
static func _diagnostics(prepared: Dictionary, candidates: int, edges: int,
		states: int, expansions: int) -> Dictionary:
	var rows_v: Variant = prepared.get("rows", [])
	return {"obstacle_count": (rows_v as Array).size() if rows_v is Array else 0,
		"inflated_vertex_count": int(prepared.get("vertex_count", 0)), "candidate_count": candidates,
		"visibility_edge_count": edges, "search_state_count": states, "search_expansion_count": expansions,
		"max_obstacles": MAX_OBSTACLES, "max_candidates": MAX_CANDIDATES,
		"max_visibility_edges": MAX_VISIBILITY_EDGES, "max_search_states": MAX_SEARCH_STATES}
static func _result(status: String, path: Array, half_width: float, cost: Dictionary,
		diagnostics: Dictionary, reason: String) -> Dictionary:
	var centerline: Array = []
	for point_v: Variant in path:
		var point: Vector2 = point_v
		centerline.append([point.x, 0.0, point.y])
	var out: Dictionary = {"status": status, "centerline": centerline,
		"corridor_width": maxf(0.0, half_width * 2.0), "cost_vector": cost,
		"diagnostics": diagnostics, "reason": reason}
	out = MapLayoutCanonical.ordered_dictionary(out)
	out["digest"] = MapLayoutCanonical.digest(out)
	return MapLayoutCanonical.ordered_dictionary(out)
static func _finite(point: Vector2) -> bool:
	return is_finite(point.x) and is_finite(point.y)
