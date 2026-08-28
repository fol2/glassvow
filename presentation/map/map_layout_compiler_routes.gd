extends RefCounted
## Private route composition for MapLayoutCompiler.

@warning_ignore_start("unsafe_call_argument")

const MAX_BYPASSED_EDGES: int = 8

static func route_plan(nodes: Array, edges: Array, anchors: Dictionary,
		quality: Dictionary) -> Dictionary:
	var nodes_by_id: Dictionary = {}
	var access: Dictionary = {}
	for node: Dictionary in nodes:
		var node_id: String = str(node["id"])
		nodes_by_id[node_id] = node
		access[node_id] = {"incoming_m": 0.0, "outgoing_m": 0.0}
	var order: Array = edges.duplicate(true)
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_row: int = MapLayoutCanonical.int_value(nodes_by_id[str(a["from"])]["row"])
		var b_row: int = MapLayoutCanonical.int_value(nodes_by_id[str(b["from"])]["row"])
		return a_row > b_row if a_row != b_row else str(a["id"]) < str(b["id"])
	)
	var common: float = MapLayoutCanonical.float_value(
		quality["geometry"]["branch_fanout"]["common_departure_max_m"]
	)
	var epsilon: float = MapLayoutCanonical.float_value(quality["epsilon"]["world_m"])
	if not is_finite(common) or common < 0.0 \
			or not is_finite(epsilon) or epsilon < 0.0:
		return _plan_failure("quality", "access limits must be finite and non-negative")
	var node_polygons: Dictionary = {}
	for node_id: String in MapLayoutCanonical.sorted_keys(nodes_by_id):
		var base: PackedVector2Array = MapQualityEvaluator._node_world(
			_v3(anchors[node_id]), quality
		)
		var canonical: Dictionary = MapAssetProfiles.canonical_polygon(base)
		var points_v: Variant = canonical.get("points", PackedVector2Array())
		if canonical.get("ok", false) != true or not (points_v is PackedVector2Array):
			return _plan_failure(node_id, "#466 node-safety polygon is invalid")
		node_polygons[node_id] = points_v
	var ports: Dictionary = {}
	for edge: Dictionary in order:
		var edge_id: String = str(edge["id"])
		var from_id: String = str(edge["from"])
		var to_id: String = str(edge["to"])
		var source: Vector2 = _xz(anchors[from_id])
		var target: Vector2 = _xz(anchors[to_id])
		var source_bounds: Rect2 = _bounds(node_polygons[from_id])
		var target_bounds: Rect2 = _bounds(node_polygons[to_id])
		var source_extent: float = source_bounds.end.x - source.x
		var target_extent: float = target.x - target_bounds.position.x
		var forward: float = target.x - source.x
		if not _finite_non_negative(source_extent) \
				or not _finite_non_negative(target_extent) \
				or not _finite_non_negative(forward):
			return _plan_failure(edge_id,
				"node-safety extents and forward distance must be finite and non-negative")
		var stub: float = minf(common, minf(source_extent, minf(
			target_extent, maxf(0.0, (forward - 2.0 * epsilon) * 0.5)
		)))
		if not _finite_non_negative(stub):
			return _plan_failure(edge_id, "access stub is invalid")
		ports[edge_id] = {
			"source": source + Vector2.RIGHT * stub,
			"target": target - Vector2.RIGHT * stub,
			"stub_m": stub,
			"branch_egress": null,
		}
		access[from_id]["outgoing_m"] = maxf(
			MapLayoutCanonical.float_value(access[from_id]["outgoing_m"]), stub
		)
		access[to_id]["incoming_m"] = maxf(
			MapLayoutCanonical.float_value(access[to_id]["incoming_m"]), stub
		)
	var inversion: Dictionary = _inversion_components(
		order, nodes_by_id, anchors, epsilon
	)
	var preview_edges: Dictionary = {}
	for edge: Dictionary in order:
		var edge_id: String = str(edge["id"])
		preview_edges[edge_id] = {
			"from": edge["from"], "to": edge["to"],
			"centerline": [anchors[str(edge["from"])],
				_a3(ports[edge_id]["source"]),
				_a3(ports[edge_id]["target"]), anchors[str(edge["to"])]],
		}
	var egress_sources: Dictionary = {}
	var camera_registry: Dictionary = MapQualityEvaluator.camera_registry(
		nodes, quality
	)
	var hard: Dictionary = MapQualityEvaluator._index(quality["hard"])
	for profile: Dictionary in camera_registry["profiles"]:
		var fanout: Dictionary = MapQualityEvaluator._fanout(
			profile, order, preview_edges, quality, hard
		)
		for violation: Dictionary in fanout["violations"]:
			egress_sources[str(violation["entities"][0])] = true
	var sample: float = MapLayoutCanonical.float_value(
		quality["geometry"]["branch_fanout"]["sample_distance_m"]
	)
	for edge: Dictionary in order:
		var from_id: String = str(edge["from"])
		var edge_id: String = str(edge["id"])
		if not egress_sources.has(from_id) \
				or inversion["edge_components"].has(edge_id):
			continue
		var source: Vector2 = _xz(anchors[from_id])
		var target: Vector2 = _xz(anchors[str(edge["to"])])
		var guide: Vector2 = Vector2(
			minf(source.x + sample, ports[edge_id]["target"].x), target.y
		)
		if guide.distance_to(ports[edge_id]["source"]) \
				> MapSingleEdgeRouter.WORLD_EPSILON_M \
				and guide.distance_to(ports[edge_id]["target"]) \
					> MapSingleEdgeRouter.WORLD_EPSILON_M:
			ports[edge_id]["branch_egress"] = guide
	var half_width: float = MapLayoutCanonical.float_value(
		quality["geometry"]["road_corridor"]["physical_half_width_m"]
	)
	if not is_finite(half_width) or half_width <= 0.0:
		return _plan_failure("quality", "physical road half-width must be finite and positive")
	var reservations: Dictionary = {}
	for node_id: String in MapLayoutCanonical.sorted_keys(nodes_by_id):
		var incoming: float = MapLayoutCanonical.float_value(access[node_id]["incoming_m"])
		var outgoing: float = MapLayoutCanonical.float_value(access[node_id]["outgoing_m"])
		var reservation: PackedVector2Array = _portal_reservation(
			node_polygons[node_id], _xz(anchors[node_id]), incoming, outgoing,
			half_width, epsilon
		)
		if reservation.is_empty():
			return _plan_failure(node_id, "swept portal reservation is invalid")
		reservations[node_id] = reservation
	var route_ids: Array[String] = []
	for edge: Dictionary in order:
		route_ids.append(str(edge["id"]))
	return {
		"ok": true,
		"route_order": order,
		"anchors": anchors,
		"ports": ports,
		"portal_reservations": reservations,
		"components": inversion["components"],
		"components_by_id": inversion["components_by_id"],
		"edge_components": inversion["edge_components"],
		"diagnostics": {
			"route_order": route_ids,
			"inversion_components": inversion["components"],
			"access_lengths": MapLayoutCanonical.ordered_dictionary(access),
			"route_calls": {"normal": 0, "bypass": 0},
			"chosen_bypass_sides": {},
			"selected_bypass_owners": {},
			"rejected_route_plans": [],
			"component_route_plans": [],
		},
	}


static func route_planned(edge: Dictionary, plan: Dictionary,
		obstacles: Array[Dictionary], half_width: float, safety: float,
		quality: Dictionary, channel: PackedVector2Array,
		usage: Dictionary, reverse_side_order: bool = false) -> Dictionary:
	var edge_id: String = str(edge["id"])
	var port: Dictionary = plan["ports"][edge_id]
	var source: Vector2 = port["source"]
	var target: Vector2 = port["target"]
	var radius: float = half_width + safety
	var diagnostics: Dictionary = {
		"normal_calls": 1,
		"bypass_calls": 0,
		"chosen_bypass_side": "",
		"first_blocker": {},
		"rejected_plans": [],
		"bypass_side_order": [],
		"bypass_blocking_obstacle_ids": [],
		"router_calls": {"ordinary": 1, "near": 0, "far": 0},
		"router_diagnostics": {"ordinary": {}, "near": [], "far": []},
		"terminal": false,
	}
	var ordinary: Dictionary
	if port["branch_egress"] is Vector2:
		ordinary = _route_through(
			source, port["branch_egress"], target,
			obstacles, half_width, safety, radius
		)
		diagnostics["normal_calls"] = 2
		diagnostics["router_calls"]["ordinary"] = 2
		if str(ordinary.get("status", "")) != MapSingleEdgeRouter.ROUTED:
			ordinary = MapSingleEdgeRouter.route(
				source, target, obstacles, half_width, safety, channel
			)
			diagnostics["normal_calls"] = 3
			diagnostics["router_calls"]["ordinary"] = 3
	else:
		ordinary = MapSingleEdgeRouter.route(
			source, target, obstacles, half_width, safety, channel
		)
	diagnostics["router_diagnostics"]["ordinary"] = _router_evidence(ordinary)
	if str(ordinary.get("status", "")) == MapSingleEdgeRouter.ROUTED:
		return _with_access_stubs(ordinary, edge, plan, diagnostics)
	var blocker: Dictionary = blocking_binding(edge, plan, obstacles, radius)
	diagnostics["first_blocker"] = blocker
	diagnostics["rejected_plans"].append(
		_rejected(edge_id, "ordinary", ordinary, blocker)
	)
	var component_id: String = str(plan["edge_components"].get(edge_id, ""))
	if component_id.is_empty() or not _local_inversion_blocker(
			component_id, blocker, ordinary, plan):
		return _attach_plan(ordinary, diagnostics)
	var component: Dictionary = plan["components_by_id"][component_id]
	diagnostics["component"] = component
	var used_components: Dictionary = usage["components"]
	var component_used: int = MapLayoutCanonical.int_value(
		used_components.get(component_id, 0)
	)
	if MapLayoutCanonical.int_value(usage["total"]) >= MAX_BYPASSED_EDGES \
			or component_used >= MapLayoutCanonical.int_value(component["max_bypassed_edges"]):
		diagnostics["terminal"] = true
		return _failed(ordinary, "bounded inversion bypass cap exceeded", diagnostics)
	var sides: Array[Dictionary] = _bypass_sides(
		component, plan, obstacles, radius, quality
	)
	if reverse_side_order:
		sides.reverse()
	for side: Dictionary in sides:
		diagnostics["bypass_side_order"].append(str(side["id"]))
	for side: Dictionary in sides:
		var bypass: Dictionary = _route_bypass(
			edge, plan, obstacles, half_width, safety, side, radius
		)
		var side_id: String = str(side["id"])
		var calls: int = MapLayoutCanonical.int_value(bypass["calls"])
		diagnostics["bypass_calls"] += calls
		diagnostics["router_calls"][side_id] = calls
		diagnostics["router_diagnostics"][side_id] = bypass["leg_diagnostics"]
		if bypass.get("ok", false) == true:
			usage["total"] = MapLayoutCanonical.int_value(usage["total"]) + 1
			used_components[component_id] = component_used + 1
			diagnostics["chosen_bypass_side"] = side["id"]
			return _with_access_stubs(
				bypass["route"], edge, plan, diagnostics
			)
		for obstacle_id_v: Variant in bypass.get("blocking_obstacle_ids", []):
			var obstacle_id: String = str(obstacle_id_v)
			if obstacle_id not in diagnostics["bypass_blocking_obstacle_ids"]:
				diagnostics["bypass_blocking_obstacle_ids"].append(obstacle_id)
		diagnostics["bypass_blocking_obstacle_ids"].sort()
		diagnostics["rejected_plans"].append({
			"edge_id": edge_id,
			"plan_id": "bypass:%s" % side["id"],
			"reason": bypass["reason"],
			"first_blocker": str(blocker.get("obstacle_id", "")),
		})
	return _failed(ordinary, "bounded inversion bypass disconnected", diagnostics)


static func route_obstacles(edge: Dictionary, plan: Dictionary,
		heroes: Dictionary, accepted_routes: Dictionary, source: Dictionary,
		assets: Dictionary, channel: PackedVector2Array,
		pending_radius_m: float) -> Dictionary:
	var obstacles: Array[Dictionary] = []
	var reservations: Dictionary = plan["portal_reservations"]
	for node_id: String in MapLayoutCanonical.sorted_keys(reservations):
		if node_id in [str(edge["from"]), str(edge["to"])]:
			continue
		obstacles.append({
			"id": "node:%s" % node_id,
			"polygon": reservations[node_id],
		})
	var profiles: Dictionary = assets["profiles"]
	var profile_helper: MapAssetProfiles = MapAssetProfiles.new(
		MapQualityEvaluator.EMPTY_MANIFEST
	)
	for hero_id: String in MapLayoutCanonical.sorted_keys(heroes):
		var placement: Dictionary = heroes[hero_id]
		var transform: Dictionary = placement["transform"]
		var polygon: PackedVector2Array = profile_helper.transformed_footprint(
			profiles[str(placement["profile_id"])],
			_v3(transform["origin"]),
			rad_to_deg(MapLayoutCanonical.float_value(transform["yaw_radians"])),
			_v3(transform["scale"])
		)
		if polygon.is_empty():
			return {"ok": false, "binding": _binding(
				"hero_anchor", "%s.profile_id" % hero_id,
				"hero_anchor_contract.anchors.%s.profile_id does not yield governed occupancy geometry" % hero_id
			)}
		obstacles.append({"id": "hero:%s" % hero_id, "polygon": polygon})
	var zones: Dictionary = source["hero_anchor_contract"]["protected_zones"]
	for zone_id: String in MapLayoutCanonical.sorted_keys(zones):
		var zone_v: Variant = zones[zone_id]
		if typeof(zone_v) != TYPE_DICTIONARY:
			return {"ok": false, "binding": _binding(
				"hero_geometry", zone_id, "protected zone must be a Dictionary"
			)}
		var zone: Dictionary = zone_v
		var canonical: Dictionary = MapAssetProfiles.canonical_polygon(
			zone.get("polygon", null)
		)
		if canonical.get("ok", false) != true:
			return {"ok": false, "binding": _binding(
				"hero_geometry", zone_id,
				"protected zone polygon is invalid: %s" % canonical.get("error", "")
			)}
		obstacles.append({
			"id": "hero-zone:%s" % zone_id,
			"polygon": canonical["points"],
		})
	for accepted_id: String in MapLayoutCanonical.sorted_keys(accepted_routes):
		var accepted: Dictionary = accepted_routes[accepted_id]
		if _shares_endpoint(edge, accepted):
			continue
		var points: Array = accepted["centerline"]
		var radius: float = MapLayoutCanonical.float_value(
			accepted["corridor_width"]
		) * 0.5
		var has_stubs: bool = MapLayoutCanonical.float_value(
			plan["ports"][accepted_id]["stub_m"]
		) > MapSingleEdgeRouter.WORLD_EPSILON_M
		var first_segment: int = 1 if has_stubs else 0
		var last_segment: int = points.size() - 1
		for segment: int in range(first_segment, last_segment):
			var polygon: PackedVector2Array = _segment_envelope(
				_xz(points[segment]), _xz(points[segment + 1]), radius,
				segment > first_segment, segment + 1 < last_segment or has_stubs
			)
			if polygon.is_empty():
				return {"ok": false, "binding": _binding(
					"edge_corridor", accepted_id,
					"accepted route contains a degenerate segment"
				)}
			if not _bounds(polygon).grow(pending_radius_m).intersects(
					_bounds(channel), true):
				continue
			obstacles.append({
				"id": "edge:%s/s%02d" % [accepted_id, segment],
				"polygon": polygon,
			})
	var ids: Array[String] = []
	for obstacle: Dictionary in obstacles:
		ids.append(str(obstacle["id"]))
	return {"ok": true, "obstacles": obstacles, "obstacle_ids": ids}


static func route_channel(edge: Dictionary, plan: Dictionary,
		padding: float) -> PackedVector2Array:
	var port: Dictionary = plan["ports"][str(edge["id"])]
	var source: Vector2 = port["source"]
	var target: Vector2 = port["target"]
	var stage: Rect2 = MapPinProjection.lattice_footprint().grow(padding)
	var left: float = maxf(stage.position.x, minf(source.x, target.x) - padding)
	var right: float = minf(stage.end.x, maxf(source.x, target.x) + padding)
	return PackedVector2Array([
		Vector2(left, stage.position.y),
		Vector2(left, stage.end.y),
		Vector2(right, stage.end.y),
		Vector2(right, stage.position.y),
	])


static func blocking_binding(edge: Dictionary, plan: Dictionary,
		obstacles: Array[Dictionary], radius: float) -> Dictionary:
	var endpoint_ids: Array[String] = [str(edge["from"]), str(edge["to"])]
	var port: Dictionary = plan["ports"][str(edge["id"])]
	var endpoints: Array[Vector2] = [
		port["source"],
		port["target"],
	]
	var ordered: Array[Dictionary] = obstacles.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_id: String = str(a["id"])
		var b_id: String = str(b["id"])
		var a_node: bool = a_id.begins_with("node:")
		var b_node: bool = b_id.begins_with("node:")
		return a_node if a_node != b_node else a_id < b_id
	)
	for obstacle: Dictionary in ordered:
		var inflated: Array = MapSingleEdgeRouter.inflate_obstacles([obstacle], radius)
		if inflated.size() != 1:
			continue
		for i: int in range(endpoints.size()):
			if not MapSingleEdgeRouter.segment_is_clear(endpoints[i], endpoints[i], inflated):
				return _blocked(str(obstacle["id"]), endpoint_ids)
	for obstacle: Dictionary in ordered:
		var inflated: Array = MapSingleEdgeRouter.inflate_obstacles([obstacle], radius)
		if inflated.size() == 1 and not MapSingleEdgeRouter.segment_is_clear(
				endpoints[0], endpoints[1], inflated):
			return _blocked(str(obstacle["id"]), endpoint_ids)
	return {"obstacle_id": "", "local_node_ids": endpoint_ids}


static func _inversion_components(order: Array, nodes: Dictionary,
		anchors: Dictionary, epsilon: float) -> Dictionary:
	var groups: Dictionary = {}
	var by_edge: Dictionary = {}
	for edge: Dictionary in order:
		var source_row: int = MapLayoutCanonical.int_value(nodes[str(edge["from"])]["row"])
		var target_row: int = MapLayoutCanonical.int_value(nodes[str(edge["to"])]["row"])
		if target_row != source_row + 1:
			continue
		var key: String = "%05d>%05d" % [source_row, target_row]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(edge)
		by_edge[str(edge["id"])] = edge
	var components: Array = []
	var components_by_id: Dictionary = {}
	var edge_components: Dictionary = {}
	for key: String in MapLayoutCanonical.sorted_keys(groups):
		var rows: Array = groups[key]
		var links: Dictionary = {}
		for edge: Dictionary in rows:
			links[str(edge["id"])] = {}
		for i: int in range(rows.size()):
			for j: int in range(i + 1, rows.size()):
				if _strict_inversion(rows[i], rows[j], anchors, epsilon):
					links[str(rows[i]["id"])][str(rows[j]["id"])] = true
					links[str(rows[j]["id"])][str(rows[i]["id"])] = true
		var visited: Dictionary = {}
		var component_index: int = 0
		for edge: Dictionary in rows:
			var root: String = str(edge["id"])
			if visited.has(root) or links[root].is_empty():
				continue
			var pending: Array[String] = [root]
			var members: Array[String] = []
			while not pending.is_empty():
				var current: String = pending.pop_front()
				if visited.has(current):
					continue
				visited[current] = true
				members.append(current)
				pending.append_array(MapLayoutCanonical.sorted_keys(links[current]))
			members.sort()
			var node_ids: Dictionary = {}
			for edge_id: String in members:
				node_ids[str(by_edge[edge_id]["from"])] = true
				node_ids[str(by_edge[edge_id]["to"])] = true
			var first: Dictionary = by_edge[members[0]]
			var source_row: int = MapLayoutCanonical.int_value(nodes[str(first["from"])]["row"])
			var target_row: int = MapLayoutCanonical.int_value(nodes[str(first["to"])]["row"])
			var id: String = "rows-%02d-%02d/c%02d" % [source_row, target_row, component_index]
			component_index += 1
			var component: Dictionary = {
				"id": id, "source_row": source_row, "target_row": target_row,
				"edge_ids": members, "node_ids": MapLayoutCanonical.sorted_keys(node_ids),
				"max_bypassed_edges": members.size() - 1,
			}
			components.append(component)
			components_by_id[id] = component
			for edge_id: String in members:
				edge_components[edge_id] = id
	return {"components": components, "components_by_id": components_by_id,
		"edge_components": edge_components}


static func _strict_inversion(a: Dictionary, b: Dictionary,
		anchors: Dictionary, epsilon: float) -> bool:
	if _shares_endpoint(a, b):
		return false
	var source_delta: float = _xz(anchors[str(a["from"])]).y \
		- _xz(anchors[str(b["from"])]).y
	var target_delta: float = _xz(anchors[str(a["to"])]).y \
		- _xz(anchors[str(b["to"])]).y
	return absf(source_delta) > epsilon and absf(target_delta) > epsilon \
		and source_delta * target_delta < 0.0


static func _local_inversion_blocker(component_id: String, blocker: Dictionary,
		route: Dictionary, plan: Dictionary) -> bool:
	var component: Dictionary = plan["components_by_id"][component_id]
	var entity: String = obstacle_entity(str(blocker.get("obstacle_id", "")))
	if entity.is_empty():
		return str(route.get("reason", "")) == "visibility graph disconnected"
	return str(plan["edge_components"].get(entity, "")) == component_id \
		or entity in component["node_ids"]


static func _bypass_sides(component: Dictionary, plan: Dictionary,
		obstacles: Array[Dictionary], radius: float, quality: Dictionary) -> Array[Dictionary]:
	var local: Array[Dictionary] = []
	for node_id_v: Variant in component["node_ids"]:
		var node_id: String = str(node_id_v)
		local.append({"id": "portal:%s" % node_id,
			"polygon": plan["portal_reservations"][node_id]})
	for obstacle: Dictionary in obstacles:
		var entity: String = obstacle_entity(str(obstacle["id"]))
		if str(plan["edge_components"].get(entity, "")) == str(component["id"]):
			local.append(obstacle)
	var inflated: Array = MapSingleEdgeRouter.inflate_obstacles(local, radius)
	if inflated.is_empty():
		return []
	var bounds: Rect2 = _bounds(inflated[0]["polygon"])
	for i: int in range(1, inflated.size()):
		bounds = bounds.merge(_bounds(inflated[i]["polygon"]))
	var epsilon: float = MapLayoutCanonical.float_value(quality["epsilon"]["world_m"])
	var sides: Array[Dictionary] = [
		{"id": "near", "z": bounds.position.y - epsilon,
			"west_x": bounds.position.x - epsilon, "east_x": bounds.end.x + epsilon},
		{"id": "far", "z": bounds.end.y + epsilon,
			"west_x": bounds.position.x - epsilon, "east_x": bounds.end.x + epsilon},
	]
	for side: Dictionary in sides:
		var z: float = MapLayoutCanonical.float_value(side["z"])
		var deviation: float = 0.0
		for edge_id_v: Variant in component["edge_ids"]:
			var port: Dictionary = plan["ports"][str(edge_id_v)]
			deviation += absf(port["source"].y - z) + absf(port["target"].y - z)
		side["added_lane_deviation_m"] = deviation
	sides.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var delta: float = MapLayoutCanonical.float_value(a["added_lane_deviation_m"]) \
			- MapLayoutCanonical.float_value(b["added_lane_deviation_m"])
		return delta < 0.0 if absf(delta) > epsilon else str(a["id"]) < str(b["id"])
	)
	return sides

static func _route_bypass(edge: Dictionary, plan: Dictionary,
		obstacles: Array[Dictionary], half_width: float, safety: float,
		side: Dictionary, radius: float) -> Dictionary:
	var port: Dictionary = plan["ports"][str(edge["id"])]
	var source: Vector2 = port["source"]
	var target: Vector2 = port["target"]
	var z: float = MapLayoutCanonical.float_value(side["z"])
	var points: Array[Vector2] = [source,
		Vector2(MapLayoutCanonical.float_value(side["west_x"]), z),
		Vector2(MapLayoutCanonical.float_value(side["east_x"]), z), target]
	var planned_blocking_ids: Dictionary = {}
	for i: int in range(points.size() - 1):
		for obstacle_id: String in _endpoint_blocking_obstacle_ids(
				points[i], points[i + 1], obstacles, radius):
			planned_blocking_ids[obstacle_id] = true
	var stage: Rect2 = MapPinProjection.lattice_footprint().grow(radius)
	var channel: PackedVector2Array = _rectangle(
		stage.position.x, stage.end.x,
		minf(z, minf(source.y, target.y)) - radius,
		maxf(z, maxf(source.y, target.y)) + radius
	)
	var centreline: Array = []
	var digests: Array[String] = []
	var leg_diagnostics: Array[Dictionary] = []
	var calls: int = 0
	for i: int in range(points.size() - 1):
		var routed: Dictionary = MapSingleEdgeRouter.route(
			points[i], points[i + 1], obstacles, half_width, safety,
			channel
		)
		calls += 1
		var evidence: Dictionary = _router_evidence(routed)
		evidence["leg"] = i
		leg_diagnostics.append(evidence)
		if str(routed.get("status", "")) != MapSingleEdgeRouter.ROUTED:
			var blocking_ids: Array[String] = _endpoint_blocking_obstacle_ids(
				points[i], points[i + 1], obstacles, radius
			)
			evidence["endpoint_blocking_obstacle_ids"] = blocking_ids
			leg_diagnostics[-1] = evidence
			return {"ok": false, "calls": calls, "reason": "%s leg %d: %s" % [
				side["id"], i, routed.get("reason", "route failed")], "route": routed,
				"leg_diagnostics": leg_diagnostics,
				"blocking_obstacle_ids": MapLayoutCanonical.sorted_keys(
					planned_blocking_ids
				)}
		digests.append(str(routed["digest"]))
		_append_path(centreline, routed["centerline"])
	var out: Dictionary = {"status": MapSingleEdgeRouter.ROUTED,
		"centerline": centreline, "corridor_width": half_width * 2.0,
		"cost_vector": {}, "diagnostics": {"leg_digests": digests}, "reason": ""}
	out["digest"] = MapLayoutCanonical.digest(out)
	return {"ok": true, "calls": calls, "reason": "", "route": out,
		"leg_diagnostics": leg_diagnostics}


static func _endpoint_blocking_obstacle_ids(a: Vector2, b: Vector2,
		obstacles: Array[Dictionary], radius: float) -> Array[String]:
	var ids: Dictionary = {}
	for obstacle: Dictionary in obstacles:
		var inflated: Array = MapSingleEdgeRouter.inflate_obstacles(
			[obstacle], radius
		)
		if inflated.size() != 1:
			continue
		if not MapSingleEdgeRouter.segment_is_clear(a, a, inflated) \
				or not MapSingleEdgeRouter.segment_is_clear(b, b, inflated):
			ids[str(obstacle["id"])] = true
	return MapLayoutCanonical.sorted_keys(ids)


static func _router_evidence(route: Dictionary) -> Dictionary:
	return {
		"status": route.get("status", ""),
		"reason": route.get("reason", ""),
		"digest": route.get("digest", ""),
		"diagnostics": route.get("diagnostics", {}),
	}


static func _route_through(source: Vector2, guide: Vector2, target: Vector2,
		obstacles: Array[Dictionary], half_width: float, safety: float,
		radius: float) -> Dictionary:
	var centreline: Array = []
	var digests: Array[String] = []
	var points: Array[Vector2] = [source, guide, target]
	for i: int in range(points.size() - 1):
		var routed: Dictionary = MapSingleEdgeRouter.route(
			points[i], points[i + 1], obstacles, half_width, safety,
			_leg_channel(points[i], points[i + 1], radius)
		)
		if str(routed.get("status", "")) != MapSingleEdgeRouter.ROUTED:
			return routed
		digests.append(str(routed["digest"]))
		_append_path(centreline, routed["centerline"])
	var out: Dictionary = {
		"status": MapSingleEdgeRouter.ROUTED,
		"centerline": centreline,
		"corridor_width": half_width * 2.0,
		"cost_vector": {},
		"diagnostics": {"leg_digests": digests},
		"reason": "",
	}
	out["digest"] = MapLayoutCanonical.digest(out)
	return out


static func _with_access_stubs(route: Dictionary, edge: Dictionary,
		plan: Dictionary, diagnostics: Dictionary) -> Dictionary:
	var line: Array = route["centerline"].duplicate(true)
	var anchors: Dictionary = plan["anchors"]
	var source: Vector2 = _xz(anchors[str(edge["from"])])
	var target: Vector2 = _xz(anchors[str(edge["to"])])
	var stub: float = MapLayoutCanonical.float_value(
		plan["ports"][str(edge["id"])]["stub_m"])
	if stub > MapSingleEdgeRouter.WORLD_EPSILON_M:
		line.push_front(_a3(source))
		line.append(_a3(target))
	var out: Dictionary = route.duplicate(true)
	out["centerline"] = line
	out["diagnostics"]["access_stub_m"] = stub
	out.erase("digest")
	out["digest"] = MapLayoutCanonical.digest(out)
	return _attach_plan(out, diagnostics)


static func _leg_channel(a: Vector2, b: Vector2,
		padding: float) -> PackedVector2Array:
	return _rectangle(minf(a.x, b.x) - padding, maxf(a.x, b.x) + padding,
		minf(a.y, b.y) - padding, maxf(a.y, b.y) + padding)


static func _append_path(target: Array, tail: Array) -> void:
	for value: Variant in tail:
		if target.is_empty() or _xz(target[-1]).distance_to(_xz(value)) \
				> MapSingleEdgeRouter.WORLD_EPSILON_M:
			target.append(value)


static func _attach_plan(route: Dictionary, diagnostics: Dictionary) -> Dictionary:
	var out: Dictionary = route.duplicate(true)
	out["plan_diagnostics"] = MapLayoutCanonical.ordered_dictionary(diagnostics)
	return MapLayoutCanonical.ordered_dictionary(out)


static func _failed(route: Dictionary, reason: String,
		diagnostics: Dictionary) -> Dictionary:
	var out: Dictionary = route.duplicate(true)
	out["status"] = MapSingleEdgeRouter.NO_ROUTE
	out["centerline"] = []
	out["reason"] = reason
	out.erase("digest")
	out.erase("plan_diagnostics")
	out["digest"] = MapLayoutCanonical.digest(out)
	return _attach_plan(out, diagnostics)


static func _rejected(edge_id: String, plan_id: String,
		route: Dictionary, blocker: Dictionary) -> Dictionary:
	return {"edge_id": edge_id, "plan_id": plan_id,
		"reason": route.get("reason", "route failed"),
		"first_blocker": str(blocker.get("obstacle_id", ""))}


static func obstacle_entity(obstacle_id: String) -> String:
	if obstacle_id.begins_with("node:"):
		return obstacle_id.trim_prefix("node:")
	if obstacle_id.begins_with("edge:"):
		return obstacle_id.trim_prefix("edge:").split("/s", false, 1)[0]
	return ""


static func _blocked(obstacle_id: String,
		endpoint_ids: Array[String]) -> Dictionary:
	return {"obstacle_id": obstacle_id, "local_node_ids": endpoint_ids}


static func _shares_endpoint(a: Dictionary, b: Dictionary) -> bool:
	return str(a["from"]) in [str(b["from"]), str(b["to"])] \
		or str(a["to"]) in [str(b["from"]), str(b["to"])]


static func _segment_envelope(a: Vector2, b: Vector2,
		half_width: float, extend_start: bool,
		extend_end: bool) -> PackedVector2Array:
	var delta: Vector2 = b - a
	if delta.length() <= MapSingleEdgeRouter.WORLD_EPSILON_M \
			or not is_finite(half_width) or half_width <= 0.0:
		return PackedVector2Array()
	var tangent: Vector2 = delta.normalized() * half_width
	var normal: Vector2 = Vector2(-delta.y, delta.x).normalized() * half_width
	var start: Vector2 = a - tangent if extend_start else a
	var end: Vector2 = b + tangent if extend_end else b
	var canonical: Dictionary = MapAssetProfiles.canonical_polygon(
		PackedVector2Array([
			start - normal,
			start + normal,
			end + normal,
			end - normal,
		])
	)
	var points_v: Variant = canonical.get("points", PackedVector2Array())
	if canonical.get("ok", false) != true or not (points_v is PackedVector2Array):
		return PackedVector2Array()
	return points_v


static func _portal_reservation(base: PackedVector2Array, anchor: Vector2,
		incoming: float, outgoing: float, half_width: float,
		epsilon: float) -> PackedVector2Array:
	if not is_finite(anchor.x) or not is_finite(anchor.y) \
			or not _finite_non_negative(incoming) \
			or not _finite_non_negative(outgoing) \
			or not is_finite(half_width) or half_width <= 0.0 \
			or not _finite_non_negative(epsilon):
		return PackedVector2Array()
	var vertices: PackedVector2Array = base.duplicate()
	if incoming > epsilon:
		vertices.append_array(_segment_envelope(
			anchor - Vector2.RIGHT * incoming, anchor,
			half_width, true, false
		))
	if outgoing > epsilon:
		vertices.append_array(_segment_envelope(
			anchor, anchor + Vector2.RIGHT * outgoing,
			half_width, false, true
		))
	var hull: PackedVector2Array = Geometry2D.convex_hull(vertices)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[-1]):
		hull.remove_at(hull.size() - 1)
	var canonical: Dictionary = MapAssetProfiles.canonical_polygon(hull)
	var points_v: Variant = canonical.get("points", PackedVector2Array())
	if canonical.get("ok", false) != true or not (points_v is PackedVector2Array):
		return PackedVector2Array()
	return points_v


static func _bounds(polygon: PackedVector2Array) -> Rect2:
	var out: Rect2 = Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon:
		out = out.expand(point)
	return out


static func _rectangle(left: float, right: float,
		near: float, far: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(left, near), Vector2(left, far),
		Vector2(right, far), Vector2(right, near),
	])


static func _finite_non_negative(value: float) -> bool:
	return is_finite(value) and value >= 0.0


static func _a3(point: Vector2) -> Array[float]:
	return [point.x, 0.0, point.y]


static func _binding(kind: String, id: String, reason: String) -> Dictionary:
	return {
		"kind": kind,
		"id": id,
		"node_id": "",
		"edge_id": "",
		"profile_id": "",
		"reason": reason,
		"details": {},
	}


static func _plan_failure(id: String, reason: String) -> Dictionary:
	return {"ok": false, "binding": _binding("access_geometry", id, reason)}


static func _v3(value: Variant) -> Vector3:
	var row: Array = value
	return Vector3(
		MapLayoutCanonical.float_value(row[0]),
		MapLayoutCanonical.float_value(row[1]),
		MapLayoutCanonical.float_value(row[2])
	)


static func _xz(value: Variant) -> Vector2:
	var point: Vector3 = _v3(value)
	return Vector2(point.x, point.z)
