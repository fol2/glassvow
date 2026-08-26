extends RefCounted
static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_single_edge_router: %s" % what)
static func run(fails: Array[String]) -> void:
	var source: Vector2 = Vector2(-4.0, 0.0)
	var target: Vector2 = Vector2(4.0, 0.0)
	var straight: Dictionary = MapSingleEdgeRouter.route(source, target, [], 0.5, 0.1)
	var straight_points: Array[Vector2] = _points(straight)
	var straight_cost: Dictionary = straight.get("cost_vector", {})
	_check(fails, str(straight.get("status", "")) == MapSingleEdgeRouter.ROUTED
			and straight_points.size() == 2 and is_equal_approx(float(straight_cost.get("route_length_ratio", 0.0)), 1.0)
			and int(straight_cost.get("bend_count", -1)) == 0, "unobstructed edge stays straight")
	var box: Array[Dictionary] = [{"id": "box", "polygon": _rect(-1.0, -1.0, 1.0, 1.0)}]
	var inflated: Array = MapSingleEdgeRouter.inflate_obstacles(box, 0.3)
	var detour: Dictionary = MapSingleEdgeRouter.route(source, target, box, 0.2, 0.1)
	var detour_points: Array[Vector2] = _points(detour)
	_check(fails, str(detour.get("status", "")) == MapSingleEdgeRouter.ROUTED
			and detour_points.size() == 4 and detour_points[1].y < 0.0
			and not MapSingleEdgeRouter.segment_is_clear(source, target, inflated)
			and _clear_and_simple(detour_points, inflated), "rectangle detours below by canonical tie-break; chord mutation fails")
	var detour_cost: Dictionary = detour.get("cost_vector", {})
	_check(fails, detour_cost.has("route_length_ratio") and detour_cost.has("bend_angle_deg_per_edge")
			and detour_cost.has("lane_deviation_m2") and detour_cost.has("obstacle_clearance_penalty")
			and str(detour.get("digest", "")).length() == 64, "named #463 costs and digest are present")
	var profile: Dictionary = {"local_footprint": _rect(-3.0, -0.4, 3.0, 0.4)}
	var rotated: PackedVector2Array = MapAssetProfiles.new().transformed_footprint(
			profile, Vector3.ZERO, 25.0, Vector3.ONE)
	var long_obstacle: Array[Dictionary] = [{"id": "long", "polygon": rotated}]
	var long_route: Dictionary = MapSingleEdgeRouter.route(Vector2(-5.0, 0.0), Vector2(5.0, 0.0), long_obstacle, 0.2, 0.1)
	_check(fails, _points(long_route).size() > 2 and _clear_and_simple(_points(long_route),
			MapSingleEdgeRouter.inflate_obstacles(long_obstacle, 0.3)), "rotated elongated #465 footprint routes as a polygon")
	var channel: PackedVector2Array = _rect(-5.0, -1.2, 5.0, 1.2)
	var barriers: Array[Dictionary] = [
		{"id": "top", "polygon": _rect(-1.0, 0.25, 1.0, 1.2)},
		{"id": "bottom", "polygon": _rect(-1.0, -1.2, 1.0, -0.25)},
	]
	var narrow: Dictionary = MapSingleEdgeRouter.route(source, target, barriers, 0.15, 0.05, channel)
	var wide: Dictionary = MapSingleEdgeRouter.route(source, target, barriers, 0.25, 0.05, channel)
	_check(fails, str(narrow.get("status", "")) == MapSingleEdgeRouter.ROUTED
			and str(wide.get("status", "")) == MapSingleEdgeRouter.NO_ROUTE, "narrow legal channel routes and wider corridor returns NO_ROUTE")
	var boundary_obstacle: Array[Dictionary] = [{"id": "near", "polygon": _rect(0.0, -1.0, 2.0, 1.0)}]
	var boundary: Dictionary = MapSingleEdgeRouter.route(Vector2(-0.5, 0.0), Vector2(-3.0, 0.0), boundary_obstacle, 0.4, 0.1)
	_check(fails, str(boundary.get("status", "")) == MapSingleEdgeRouter.ROUTED, "endpoint on inflated safety boundary may leave outward")
	var raw: Array = MapSingleEdgeRouter.inflate_obstacles(box, 0.0)
	_check(fails, MapSingleEdgeRouter.segment_is_clear(Vector2(-2.0, -1.0), Vector2(2.0, -1.0), raw)
			and MapSingleEdgeRouter.segment_is_clear(Vector2(-2.0, -0.9995), Vector2(2.0, -0.9995), raw)
			and not MapSingleEdgeRouter.segment_is_clear(Vector2(-2.0, -0.998), Vector2(2.0, -0.998), raw), "tangency and sub-epsilon contact are legal; penetration is not")
	var reordered: Array[Dictionary] = [barriers[1], barriers[0]]
	var replay: Dictionary = MapSingleEdgeRouter.route(source, target, reordered, 0.15, 0.05, channel)
	_check(fails, MapLayoutCanonical.canonical_bytes(narrow) == MapLayoutCanonical.canonical_bytes(replay), "obstacle reordering is byte-equivalent")
	var diagnostics: Dictionary = detour.get("diagnostics", {})
	_check(fails, int(diagnostics.get("candidate_count", 1)) <= int(diagnostics.get("max_candidates", 0))
			and int(diagnostics.get("visibility_edge_count", 1)) <= int(diagnostics.get("max_visibility_edges", 0))
			and int(diagnostics.get("search_state_count", 1)) <= int(diagnostics.get("max_search_states", 0))
			and int(diagnostics.get("max_obstacles", 0)) >= 15 * 7, "diagnostics report fixed 15x7-appropriate bounds")
static func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x0, y1), Vector2(x1, y1), Vector2(x1, y0)])
static func _points(result: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var rows_v: Variant = result.get("centerline", [])
	if not (rows_v is Array):
		return out
	var rows: Array = rows_v
	for row_v: Variant in rows:
		if row_v is Array and (row_v as Array).size() == 3:
			var row: Array = row_v
			out.append(Vector2(float(row[0]), float(row[2])))
	return out
static func _clear_and_simple(points: Array[Vector2], inflated: Array) -> bool:
	for i: int in range(points.size() - 1):
		if not MapSingleEdgeRouter.segment_is_clear(points[i], points[i + 1], inflated):
			return false
	for i: int in range(1, points.size() - 1):
		if absf((points[i] - points[i - 1]).cross(points[i + 1] - points[i])) <= MapSingleEdgeRouter.WORLD_EPSILON_M \
				and MapSingleEdgeRouter.segment_is_clear(points[i - 1], points[i + 1], inflated):
			return false
	return true
