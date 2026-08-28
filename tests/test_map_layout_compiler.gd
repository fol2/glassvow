extends RefCounted
## #469 pure complete node-and-route compiler.

const Binding = preload("res://domain/map_layout/map_layout_input_binding.gd")
const Routes = preload("res://presentation/map/map_layout_compiler_routes.gd")

@warning_ignore_start("unsafe_call_argument")


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_layout_compiler: %s" % what)


static func run(fails: Array[String]) -> void:
	var quality: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://docs/map/map-quality-v2.json"
	))
	_test_portal_geometry(fails, quality)
	_test_causal_binding_closure(fails, quality)
	_test_inflation_safe_corridor_culling(fails, quality)
	_test_complete_chain(fails, quality)
	_test_layered_route_plan(fails, quality)
	_test_atomic_component_failure(fails, quality)
	_test_crossing_detour(fails, quality)
	_test_three_way_fanout_merge(fails, quality)
	_test_bounded_local_substitution(fails, quality)
	_test_production_graphs(fails, quality)


static func _test_causal_binding_closure(fails: Array[String],
		quality: Dictionary) -> void:
	var nodes: Array = [
		_node("11,5", 11, 5), _node("12,5", 12, 5), _node("12,6", 12, 6),
		_node("12,1", 12, 1), _node("13,1", 13, 1), _node("13,2", 13, 2),
		_node("S", 2, 3), _node("A", 3, 2), _node("B", 3, 4),
		_node("U", 4, 1), _node("V", 5, 1),
		_node("X", 4, 5), _node("Y", 5, 5),
		_node("C1", 6, 2), _node("C2", 6, 4),
		_node("D1", 7, 2), _node("D2", 7, 4),
	]
	var first_edge: Dictionary = _edge("11,5", "12,5")
	var second_edge: Dictionary = _edge("12,1", "13,1")
	var fanout_a: Dictionary = _edge("S", "A")
	var fanout_b: Dictionary = _edge("S", "B")
	var unrelated_a: Dictionary = _edge("U", "V")
	var unrelated_b: Dictionary = _edge("X", "Y")
	var component_a: Dictionary = _edge("C1", "D2")
	var component_b: Dictionary = _edge("C2", "D1")
	var edges: Array = [
		first_edge, second_edge, fanout_a, fanout_b,
		unrelated_a, unrelated_b, component_a, component_b,
	]
	var assets: Dictionary = _assets()
	var input: MapLayoutInput = _input(
		nodes, edges, 717, 0, _hero(), quality, assets
	)
	var first_binding: Dictionary = {
		"node_id": "12,6",
		"edge_id": first_edge["id"],
		"details": {
			"local_node_ids": ["12,5", "missing", "11,5", ""],
			"entities": [first_edge["id"], "12,6", "missing"],
		},
	}
	var second_binding: Dictionary = {
		"node_id": "13,2",
		"edge_id": second_edge["id"],
		"details": {
			"local_node_ids": ["13,1", "12,1"],
			"entities": ["13,2", second_edge["id"]],
		},
	}
	_check(fails, _binding_nodes_with_early_return(first_binding, input) \
			== ["11,5", "12,5"]
			and MapLayoutCompiler._binding_nodes(first_binding, input) \
				== ["11,5", "12,5", "12,6"]
			and _binding_nodes_with_early_return(second_binding, input) \
				== ["12,1", "13,1"]
			and MapLayoutCompiler._binding_nodes(second_binding, input) \
				== ["12,1", "13,1", "13,2"],
		"causal closure includes failed edge endpoints and named non-endpoint blockers")
	var fanout_binding: Dictionary = {
		"node_id": "S",
		"edge_id": fanout_a["id"],
		"details": {
			"local_node_ids": ["S"],
			"entities": ["S", fanout_a["id"], fanout_b["id"]],
		},
	}
	_check(fails, _binding_nodes_with_early_return(fanout_binding, input) == ["S"]
			and MapLayoutCompiler._binding_nodes(fanout_binding, input) \
				== ["A", "B", "S"],
		"causal closure includes the source and both governed fan-out targets")
	var unrelated_binding: Dictionary = {
		"node_id": "",
		"edge_id": unrelated_a["id"],
		"details": {"local_node_ids": [],
			"entities": [unrelated_b["id"], unrelated_a["id"]]},
	}
	_check(fails, MapLayoutCompiler._binding_nodes(unrelated_binding, input) \
			== ["U", "V", "X", "Y"],
		"unrelated-edge closure includes both offending edges' endpoints")
	var component_nodes: Array = ["C1", "C2", "D1", "D2"]
	var component_binding: Dictionary = {
		"node_id": "",
		"edge_id": "",
		"details": {
			"local_node_ids": component_nodes.duplicate(),
			"entities": [component_b["id"], "D2", component_a["id"], "C1"],
		},
	}
	_check(fails, MapLayoutCompiler._binding_nodes(component_binding, input) \
			== component_nodes,
		"two-edge inversion-component closure remains exactly governed")
	var nested_binding: Dictionary = {
		"node_id": "", "edge_id": "",
		"details": {
			"edge_ids": [component_a["id"], component_b["id"]],
			"entities": [
				component_a["id"], component_b["id"], "C1", "C2", "D1", "D2",
			],
			"causal_obstacle_ids": [
				"edge:%s/s00" % unrelated_a["id"], "node:U", "node:X",
			],
			"supported_causal_obstacle_ids": [
				"edge:%s/s00" % unrelated_a["id"], "node:U", "node:X",
			],
		},
	}
	MapLayoutCompiler._promote_atomic_causal_binding(
		nested_binding, {"route_order": edges}
	)
	var nested_nodes: Array[String] = MapLayoutCompiler._binding_nodes(
		nested_binding, input
	)
	var nested_sets: Dictionary = MapNodeCandidateGenerator.generate(
		input, quality, 0
	).get("node_sets", {})
	var nested_selection: Dictionary = {}
	for node_id: String in MapLayoutCanonical.sorted_keys(nested_sets):
		nested_selection[node_id] = 0
	var nested_priorities: Dictionary = {}
	for child: Dictionary in MapLayoutCompiler._substitution_children(
			nested_binding, input, nested_sets, nested_selection):
		var substitution: Dictionary = child["substitution"]
		var child_nodes: Array = substitution["node_ids"]
		if child_nodes.size() == 1:
			nested_priorities[str(child_nodes[0])] = child["priority"]
	var nested_details: Dictionary = nested_binding["details"]
	_check(fails, nested_details.get("priority_obstacle_ids", []) == ["node:X"]
			and nested_nodes == ["C1", "C2", "D1", "D2", "U", "V", "X"]
			and MapLayoutCanonical.float_value(nested_priorities.get("X", 0.0)) == 1.0
			and MapLayoutCanonical.float_value(nested_priorities.get("U", 1.0)) == 0.0
			and MapLayoutCanonical.float_value(nested_priorities.get("V", 1.0)) == 0.0,
		"nested component attribution prioritises only the independent node blocker while preserving full causal closure")
	var reordered_nodes: Array = nodes.duplicate(true)
	var reordered_edges: Array = edges.duplicate(true)
	reordered_nodes.reverse()
	reordered_edges.reverse()
	var reordered_input: MapLayoutInput = _input(
		reordered_nodes, reordered_edges, 717, 0, _hero(), quality, assets
	)
	var reordered_binding: Dictionary = fanout_binding.duplicate(true)
	reordered_binding["details"]["local_node_ids"].reverse()
	reordered_binding["details"]["entities"].reverse()
	_check(fails, MapLayoutCompiler._binding_nodes(
			reordered_binding, reordered_input
		) == ["A", "B", "S"],
		"causal closure ordering is canonical under reordered equivalent input")


static func _binding_nodes_with_early_return(binding: Dictionary,
		input: MapLayoutInput) -> Array[String]:
	var nodes: Dictionary = {}
	for node: Dictionary in input.node_records():
		nodes[str(node["id"])] = true
	var edges: Dictionary = {}
	for edge: Dictionary in input.edge_records():
		edges[str(edge["id"])] = edge
	var affected: Dictionary = {}
	var local_nodes: Array = binding.get("details", {}).get("local_node_ids", [])
	if not local_nodes.is_empty():
		for node_id_v: Variant in local_nodes:
			var node_id: String = str(node_id_v)
			if nodes.has(node_id):
				affected[node_id] = true
		return MapLayoutCanonical.sorted_keys(affected)
	var entities: Array = binding.get("details", {}).get("entities", []).duplicate()
	entities.append(binding.get("node_id", ""))
	entities.append(binding.get("edge_id", ""))
	for entity_v: Variant in entities:
		var entity: String = str(entity_v)
		if nodes.has(entity):
			affected[entity] = true
		if edges.has(entity):
			var edge: Dictionary = edges[entity]
			affected[str(edge["from"])] = true
			affected[str(edge["to"])] = true
	return MapLayoutCanonical.sorted_keys(affected)


static func _attempted_candidate_ids(diagnostics: Dictionary) -> Dictionary:
	var by_node: Dictionary = {}
	for substitution_v: Variant in diagnostics.get("substitutions", []):
		var substitution: Dictionary = substitution_v
		var node_ids: Array = substitution.get("node_ids", [])
		var candidate_ids: Array = substitution.get("to_candidate_ids", [])
		for i: int in range(mini(node_ids.size(), candidate_ids.size())):
			var node_id: String = str(node_ids[i])
			var candidate_id: String = str(candidate_ids[i])
			var attempted: Array = by_node.get(node_id, []).duplicate()
			if not candidate_id.is_empty() and candidate_id not in attempted:
				attempted.append(candidate_id)
				attempted.sort()
			by_node[node_id] = attempted
	return MapLayoutCanonical.ordered_dictionary(by_node)


static func _last_route_attempt(diagnostics: Dictionary) -> Dictionary:
	var attempts: Array = diagnostics.get("attempts", [])
	if attempts.is_empty():
		return {}
	var last: Dictionary = attempts[-1]
	var routes: Array[Dictionary] = []
	for route_v: Variant in last.get("routes", []):
		var route: Dictionary = route_v
		var plan: Dictionary = route.get("plan", {})
		routes.append({
			"edge_id": route.get("edge_id", ""),
			"route_digest": route.get("route_digest", ""),
			"status": route.get("status", ""),
			"obstacle_ids": route.get("obstacle_ids", []),
			"router_calls": plan.get("router_calls", {}),
			"first_blocker": plan.get("first_blocker", {}),
		})
	return {
		"chosen_candidate_ids": last.get("chosen_candidate_ids", {}),
		"routes": routes,
	}


static func _test_inflation_safe_corridor_culling(fails: Array[String],
		quality: Dictionary) -> void:
	var current: Dictionary = _edge("A", "B")
	var accepted_edge: Dictionary = _edge("C", "D")
	var accepted_id: String = str(accepted_edge["id"])
	var half_width: float = MapLayoutCanonical.float_value(
		quality["geometry"]["road_corridor"]["physical_half_width_m"]
	)
	var pending_radius: float = half_width + MapLayoutCanonical.float_value(
		quality["geometry"]["road_corridor"]["world_clearance_m"]
	)
	var channel: PackedVector2Array = Routes._rectangle(0.0, 10.0, -1.0, 1.0)
	var physical: PackedVector2Array = Routes._segment_envelope(
		Vector2(0.0, 3.0), Vector2(10.0, 3.0), half_width, false, false
	)
	var channel_bounds: Rect2 = Routes._bounds(channel)
	var physical_bounds: Rect2 = Routes._bounds(physical)
	var grown_bounds: Rect2 = physical_bounds.grow(pending_radius)
	var accepted_routes: Dictionary = {
		accepted_id: {
			"from": accepted_edge["from"],
			"to": accepted_edge["to"],
			"centerline": [[0.0, 0.0, 3.0], [10.0, 0.0, 3.0]],
			"corridor_width": half_width * 2.0,
		},
	}
	var obstacles: Dictionary = Routes.route_obstacles(
		current,
		{"portal_reservations": {},
			"ports": {accepted_id: {"stub_m": 0.0}}},
		{}, accepted_routes,
		{"hero_anchor_contract": {"protected_zones": {}}},
		{"profiles": {}}, channel, pending_radius
	)
	_check(fails, not physical_bounds.intersects(channel_bounds, true)
			and grown_bounds.intersects(channel_bounds, true)
			and obstacles.get("obstacle_ids", []) \
				== ["edge:%s/s00" % accepted_id],
		"pending-radius culling retains an accepted segment whose inflated bounds reach the channel")


static func _test_portal_geometry(fails: Array[String], quality: Dictionary) -> void:
	var terminal_nodes: Array = [
		_node("11,5", 11, 5), _node("11,6", 11, 6),
		_node("12,5", 12, 5), _node("12,6", 12, 6),
	]
	var terminal_edges: Array = [
		_edge("11,5", "12,6"), _edge("11,6", "12,5"),
	]
	var terminal_anchors: Dictionary = {
		"11,5": [19.2904853820801, 0.0, 10.53537940979],
		"11,6": [19.7616653442383, 0.0, 19.3748016357422],
		"12,5": [25.0210494995117, 0.0, 14.6966638565063],
		"12,6": [24.1751823425293, 0.0, 19.4752044677734],
	}
	var first_id: String = MapLayoutInput.edge_id("11,5", "12,6")
	var second_id: String = MapLayoutInput.edge_id("11,6", "12,5")
	var common: float = MapLayoutCanonical.float_value(
		quality["geometry"]["branch_fanout"]["common_departure_max_m"]
	)
	var old_first_target: Vector2 = _xz(terminal_anchors["12,6"]) \
		- Vector2.RIGHT * common
	var old_second_source: Vector2 = _xz(terminal_anchors["11,6"]) \
		+ Vector2.RIGHT * common
	var old_distance: float = old_first_target.distance_to(old_second_source)
	var half_width: float = MapLayoutCanonical.float_value(
		quality["geometry"]["road_corridor"]["physical_half_width_m"]
	)
	_check(fails, is_equal_approx(old_distance, 2.415604485)
			and old_distance < half_width * 2.0,
		"restoring the old 1.0 m ports reproduces infeasible physical spacing")

	var terminal_plan: Dictionary = Routes.route_plan(
		terminal_nodes, terminal_edges, terminal_anchors, quality
	)
	var terminal_ports: Dictionary = terminal_plan.get("ports", {})
	var first_port: Dictionary = terminal_ports.get(first_id, {})
	var second_port: Dictionary = terminal_ports.get(second_id, {})
	var governed_distance: float = INF
	var first_target_v: Variant = first_port.get("target", null)
	var second_source_v: Variant = second_port.get("source", null)
	if first_target_v is Vector2 and second_source_v is Vector2:
		var first_target: Vector2 = first_target_v
		var second_source: Vector2 = second_source_v
		governed_distance = first_target.distance_to(second_source)
	_check(fails, is_equal_approx(governed_distance, 3.155114925)
			and governed_distance >= half_width * 2.0 \
				+ MapLayoutCanonical.float_value(
					quality["geometry"]["road_corridor"]["world_clearance_m"]),
		"#466 boundary ports make the recorded terminal pair feasible")
	var safety: float = MapLayoutCanonical.float_value(
		quality["geometry"]["road_corridor"]["world_clearance_m"]
	)
	var greedy_routes: Dictionary = {}
	var greedy_usage: Dictionary = {"total": 0, "components": {}}
	var greedy_rows: Array[Dictionary] = []
	for edge: Dictionary in terminal_plan["route_order"]:
		var channel: PackedVector2Array = Routes.route_channel(
			edge, terminal_plan, (half_width + safety) * 2.0
		)
		var obstacle_report: Dictionary = Routes.route_obstacles(
			edge, terminal_plan, {}, greedy_routes,
			{"hero_anchor_contract": {"protected_zones": {}}},
			{"profiles": {}}, channel, half_width + safety
		)
		var routed: Dictionary = Routes.route_planned(
			edge, terminal_plan, obstacle_report.get("obstacles", []),
			half_width, safety, quality, channel, greedy_usage
		)
		greedy_rows.append({"edge_id": edge["id"],
			"status": routed.get("status", ""),
			"reason": routed.get("reason", ""),
			"plan": routed.get("plan_diagnostics", {})})
		if str(routed.get("status", "")) != MapSingleEdgeRouter.ROUTED:
			break
		greedy_routes[str(edge["id"])] = {"from": edge["from"], "to": edge["to"],
			"centerline": routed["centerline"],
			"corridor_width": routed["corridor_width"]}
	var greedy_blocker: String = ""
	if greedy_rows.size() == 2:
		greedy_blocker = str(greedy_rows[1]["plan"].get(
			"first_blocker", {}).get("obstacle_id", ""))
	_check(fails, greedy_rows.size() == 2
			and str(greedy_rows[0]["status"]) == MapSingleEdgeRouter.ROUTED
			and str(greedy_rows[1]["status"]) == MapSingleEdgeRouter.NO_ROUTE
			and greedy_blocker.begins_with("edge:%s/" % first_id),
		"reducing the atomic slate to the old greedy plan reproduces the partner failure: %s"
			% str(greedy_rows))
	var terminal_edges_by_id: Dictionary = {}
	for edge: Dictionary in terminal_edges:
		terminal_edges_by_id[str(edge["id"])] = edge
	var terminal_component: Dictionary = terminal_plan["components"][0]
	var atomic: Dictionary = MapLayoutCompiler._route_atomic_component(
		terminal_component, MapLayoutCompiler._component_plan_specs(
			terminal_component, terminal_plan, half_width + safety, quality
		), terminal_edges_by_id, terminal_plan, {}, {},
		{"hero_anchor_contract": {"protected_zones": {}}},
		{"profiles": {}}, quality, half_width, safety,
		{"total": 0, "components": {}}
	)
	var atomic_diagnostics: Dictionary = atomic.get("component_diagnostics", {})
	_check(fails, atomic.get("ok", false) == true
			and atomic.get("routes", {}).size() == 2
			and str(atomic_diagnostics.get("selected_plan_id", "")) \
				== "reversed/current"
			and str(atomic_diagnostics.get("selected_bypass_owner", "")) == ""
			and atomic.get("usage", {}).get("total", -1) == 0
			and atomic_diagnostics.get("accepted_route_digests", {}).size() == 2,
		"the atomic slate selects both seed-717 routes and records that no bypass owner was consumed: %s"
			% str(atomic_diagnostics))
	var changed_quality: Dictionary = quality.duplicate(true)
	changed_quality["calibration"]["shipping_touch_waystone"][
		"node_pair_half_extent_m"] = [0.57, 0.98]
	var changed_plan: Dictionary = Routes.route_plan(
		terminal_nodes, terminal_edges, terminal_anchors, changed_quality
	)
	_check(fails, is_equal_approx(MapLayoutCanonical.float_value(
		changed_plan.get("ports", {}).get(first_id, {}).get("stub_m", INF)), 0.57),
		"port length follows the current #466 polygon instead of a hardcoded 0.63 m")

	var chain_nodes: Array = [_node("L", 2, 3), _node("N", 7, 3), _node("R", 12, 3)]
	var chain_edges: Array = [_edge("L", "N"), _edge("N", "R")]
	var chain_anchors: Dictionary = {
		"L": [0.0, 0.0, 0.0], "N": [6.0, 0.0, 0.0], "R": [12.0, 0.0, 0.0],
	}
	var chain_plan: Dictionary = Routes.route_plan(
		chain_nodes, chain_edges, chain_anchors, quality
	)
	var reservations: Dictionary = chain_plan.get("portal_reservations", {})
	_check(fails, reservations.size() == chain_nodes.size(),
		"one canonical swept portal reservation is emitted per node")
	if not reservations.has("N"):
		return
	var anchor: Vector2 = _xz(chain_anchors["N"])
	var access: Dictionary = chain_plan.get("diagnostics", {}).get(
		"access_lengths", {}).get("N", {})
	var incoming: float = MapLayoutCanonical.float_value(access.get("incoming_m", 0.0))
	var outgoing: float = MapLayoutCanonical.float_value(access.get("outgoing_m", 0.0))
	var reservation: PackedVector2Array = reservations["N"]
	var required: PackedVector2Array = MapQualityEvaluator._node_world(
		Vector3(anchor.x, 0.0, anchor.y), quality
	)
	required.append_array(Routes._segment_envelope(
		anchor - Vector2.RIGHT * incoming, anchor, half_width, true, false
	))
	required.append_array(Routes._segment_envelope(
		anchor, anchor + Vector2.RIGHT * outgoing, half_width, false, true
	))
	var contains_portal: bool = true
	for point: Vector2 in required:
		contains_portal = contains_portal \
			and MapQualityEvaluator._signed_gap(point, reservation) \
				<= MapSingleEdgeRouter.WORLD_EPSILON_M
	var bounds: Rect2 = Routes._bounds(reservation)
	_check(fails, contains_portal,
		"the reservation contains the node polygon and complete physical access sweeps")
	_check(fails, is_equal_approx(bounds.size.y * 0.5, maxf(0.98, half_width))
			and not is_equal_approx(bounds.size.y * 0.5, 0.98 + half_width),
		"portal Z uses max(node half Z, road half-width), not their sum")
	var obstacles: Dictionary = Routes.route_obstacles(
		chain_edges[0], chain_plan, {}, {},
		{"hero_anchor_contract": {"protected_zones": {}}}, {"profiles": {}},
		Routes.route_channel(chain_edges[0], chain_plan, 4.0), half_width + safety
	)
	_check(fails, obstacles.get("obstacle_ids", []) == ["node:R"],
		"an edge omits only its own endpoint reservations and sees one obstacle per other node")

	var base: PackedVector2Array = MapQualityEvaluator._node_world(
		Vector3(anchor.x, 0.0, anchor.y), quality
	)
	var base_bounds: Rect2 = Routes._bounds(base)
	var bare: PackedVector2Array = Routes._rectangle(
		base_bounds.position.x - incoming, base_bounds.end.x + outgoing,
		base_bounds.position.y, base_bounds.end.y
	)
	var route_radius: float = half_width + MapLayoutCanonical.float_value(
		quality["geometry"]["road_corridor"]["world_clearance_m"]
	)
	var bare_bounds: Rect2 = Routes._bounds(bare)
	var unrelated_x: float = bare_bounds.end.x + route_radius \
		+ MapSingleEdgeRouter.WORLD_EPSILON_M * 2.0
	var unrelated: Vector2 = Vector2(unrelated_x, anchor.y)
	var bare_inflated: Array = MapSingleEdgeRouter.inflate_obstacles(
		[{"id": "node:N", "polygon": bare}], route_radius
	)
	var swept_inflated: Array = MapSingleEdgeRouter.inflate_obstacles(
		[{"id": "node:N", "polygon": reservation}], route_radius
	)
	var accepted: PackedVector2Array = Routes._segment_envelope(
		unrelated + Vector2.UP, unrelated + Vector2.DOWN,
		half_width, false, false
	)
	var accepted_inflated: Array = MapSingleEdgeRouter.inflate_obstacles(
		[{"id": "edge:unrelated/s00", "polygon": accepted}], route_radius
	)
	var source_port: Vector2 = anchor + Vector2.RIGHT * outgoing
	_check(fails, MapSingleEdgeRouter.segment_is_clear(
			unrelated, unrelated, bare_inflated)
			and not MapSingleEdgeRouter.segment_is_clear(
				unrelated, unrelated, swept_inflated)
			and not MapSingleEdgeRouter.segment_is_clear(
				source_port, source_port, accepted_inflated),
		"disabling the swept reservation admits an unrelated route that closes the endpoint")


static func _test_complete_chain(fails: Array[String], quality: Dictionary) -> void:
	var nodes: Array = [
		_node("A", 2, 3),
		_node("B", 7, 3),
		_node("C", 12, 3),
	]
	var edges: Array = [_edge("A", "B"), _edge("B", "C")]
	var assets: Dictionary = _assets()
	var hero: Dictionary = _hero()
	var input: MapLayoutInput = _input(nodes, edges, 717, 0, hero, quality, assets)
	var compiled: Dictionary = MapLayoutCompiler.compile(input, quality, assets)
	var result_v: Variant = compiled.get("result", null)
	var report: Dictionary = compiled.get("report", {})
	_check(fails, str(compiled.get("status", "")) == MapLayoutCompiler.COMPILED
			and result_v is MapLayoutResult,
		"a legal chain returns one complete MapLayoutResult")
	if not (result_v is MapLayoutResult):
		return
	var result: MapLayoutResult = result_v
	var serial: Dictionary = result.to_dict()
	var placement: Dictionary = serial["hero_placements"].get("vigil", {})
	_check(fails, serial["node_anchors"].size() == nodes.size()
			and serial["edges"].size() == edges.size()
			and serial["scenery_instances"].is_empty(),
		"the authoritative result contains every node and edge with empty scenery")
	_check(fails, placement == {
		"asset_id": "hero/vigil",
		"profile_id": "hero",
		"transform": {
			"origin": [100.0, 0.0, 100.0],
			"yaw_radians": 0.25,
			"scale": [1.0, 1.0, 1.0],
		},
	}, "hero anchors are copied canonically without movement")
	_check(fails, report.get("hard_pass", false) == true
			and str(report.get("layout_digest", "")) == result.digest()
			and serial["hard_measurements"] == report.get("hard_values", {})
			and serial["soft_scores"] == report.get("soft_raw", {}),
		"the second evaluator pass binds the final digest and stored vectors")
	var copy: MapLayoutResult = MapLayoutResult.from_dict(serial)
	_check(fails, copy != null and copy.canonical_bytes() == result.canonical_bytes(),
		"the compiled result round-trips through the immutable contract")


static func _test_layered_route_plan(fails: Array[String], quality: Dictionary) -> void:
	var nodes: Array = [
		_node("A", 3, 2),
		_node("B", 3, 3),
		_node("C", 4, 3),
		_node("D", 4, 2),
	]
	var edges: Array = [_edge("A", "C"), _edge("B", "D")]
	var assets: Dictionary = _assets()
	var input: MapLayoutInput = _input(
		nodes, edges, 717, 0, _hero(), quality, assets
	)
	var compiled: Dictionary = MapLayoutCompiler.compile(input, quality, assets)
	var diagnostics: Dictionary = compiled.get("diagnostics", {})
	var components: Array = diagnostics.get("inversion_components", [])
	var access: Dictionary = diagnostics.get("access_lengths", {})
	var calls: Dictionary = diagnostics.get("route_calls", {})
	var sides: Dictionary = diagnostics.get("chosen_bypass_sides", {})
	var component_plans: Array = diagnostics.get("component_route_plans", [])
	_check(fails, str(compiled.get("status", "")) == MapLayoutCompiler.COMPILED,
		"an adjacent-row inversion pair uses the bounded layered route plan: %s" \
		% str(compiled.get("failure", {})))
	_check(fails, diagnostics.get("route_order", []) == [
		MapLayoutInput.edge_id("A", "C"), MapLayoutInput.edge_id("B", "D"),
	] and components.size() == 1
			and components[0].get("source_row", -1) == 3
			and components[0].get("target_row", -1) == 4
			and components[0].get("edge_ids", []) == [
				MapLayoutInput.edge_id("A", "C"), MapLayoutInput.edge_id("B", "D"),
			],
		"route order and strict inversion components are canonical")
	var plan_ids: Array = []
	if component_plans.size() == 1:
		for row: Dictionary in component_plans[0].get("plans", []):
			plan_ids.append(str(row.get("plan_id", "")))
	_check(fails, plan_ids == [
		"canonical/current", "canonical/reversed",
		"reversed/current", "reversed/reversed",
	], "a two-edge inversion enumerates exactly four canonical component plans")
	var expected_edges: Array = [
		MapLayoutInput.edge_id("A", "C"), MapLayoutInput.edge_id("B", "D"),
	]
	var reversed_edges: Array = expected_edges.duplicate()
	reversed_edges.reverse()
	var plans: Array = [] if component_plans.is_empty() else component_plans[0].get(
		"plans", [])
	var plan_shape_ok: bool = plans.size() == 4
	var entry_usage_ok: bool = true
	var committed_count: int = 0
	for i: int in range(plans.size()):
		var row: Dictionary = plans[i]
		var expected_order: Array = expected_edges if i < 2 else reversed_edges
		var expected_sides: Array = ["near", "far"] if i % 2 == 0 \
			else ["far", "near"]
		plan_shape_ok = plan_shape_ok and row.get("edge_order", []) == expected_order \
			and row.get("side_order", []) == expected_sides
		entry_usage_ok = entry_usage_ok and row.get("entry_bypass_usage", {}) \
			== {"total": 0, "components": {}}
		if row.get("committed", false) == true:
			committed_count += 1
	_check(fails, plan_shape_ok and entry_usage_ok and committed_count == 1
			and component_plans[0].get("selected_plan_id", "") == "canonical/current"
			and component_plans[0].get("selected_bypass_owner", "") == ""
			and component_plans[0].get("accepted_route_digests", {}).size() == 2
			and diagnostics.get("selected_bypass_owners", {}).is_empty(),
		"component plans isolate route and bypass state and commit only the first success")
	_check(fails, is_equal_approx(float(access.get("A", {}).get("outgoing_m", 0.0)), 0.63)
			and is_equal_approx(float(access.get("C", {}).get("incoming_m", 0.0)), 0.63)
			and MapLayoutCanonical.int_value(calls.get("normal", 0)) == 8
			and MapLayoutCanonical.int_value(calls.get("bypass", 0)) == 6
			and sides.is_empty(),
		"boundary-derived access lengths and bounded route calls are reported: %s" \
			% str({"access": access, "calls": calls, "sides": sides}))
	if compiled.get("result", null) is MapLayoutResult:
		var result: MapLayoutResult = compiled["result"]
		var serial: Dictionary = result.to_dict()
		var first: Dictionary = serial["edges"][MapLayoutInput.edge_id("A", "C")]
		var line: Array = first["centerline"]
		var selected_anchor: Vector3 = _v3(serial["node_anchors"]["A"])
		_check(fails, line.size() >= 4
				and _v3(line[0]).is_equal_approx(selected_anchor)
				and is_equal_approx(_v3(line[1]).x - _v3(line[0]).x, 0.63),
			"the result prepends the straight governed source access stub")
	var reordered_nodes: Array = nodes.duplicate(true)
	var reordered_edges: Array = edges.duplicate(true)
	reordered_nodes.reverse()
	reordered_edges.reverse()
	var reordered: MapLayoutInput = _input(
		reordered_nodes, reordered_edges,
		717, 0, _hero(), quality, assets
	)
	var replay: Dictionary = MapLayoutCompiler.compile(reordered, quality, assets)
	var replay_result_v: Variant = replay.get("result", null)
	var compiled_result_v: Variant = compiled.get("result", null)
	var same_result: bool = false
	if replay_result_v is MapLayoutResult and compiled_result_v is MapLayoutResult:
		var replay_result: MapLayoutResult = replay_result_v
		var compiled_result: MapLayoutResult = compiled_result_v
		same_result = replay_result.canonical_bytes() == compiled_result.canonical_bytes()
	_check(fails, same_result
			and replay.get("diagnostics", {}).get("component_route_plans", []) \
				== component_plans
			and replay.get("diagnostics", {}).get(
				"diagnostics_digest", "") == diagnostics.get("diagnostics_digest", ""),
		"equivalent reordered input preserves result and diagnostic identity")


static func _test_atomic_component_failure(fails: Array[String],
		quality: Dictionary) -> void:
	var nodes: Array = [
		_node("A", 3, 2), _node("B", 3, 3),
		_node("C", 4, 3), _node("D", 4, 2),
	]
	var edges: Array = [_edge("A", "C"), _edge("B", "D")]
	var anchors: Dictionary = {
		"A": [0.0, 0.0, 0.0], "B": [0.0, 0.0, 0.5],
		"C": [6.0, 0.0, 0.5], "D": [6.0, 0.0, 0.0],
	}
	var plan: Dictionary = Routes.route_plan(nodes, edges, anchors, quality)
	var component: Dictionary = plan.get("components", [{}])[0]
	var half_width: float = MapLayoutCanonical.float_value(
		quality["geometry"]["road_corridor"]["physical_half_width_m"]
	)
	var safety: float = MapLayoutCanonical.float_value(
		quality["geometry"]["road_corridor"]["world_clearance_m"]
	)
	var edges_by_id: Dictionary = {}
	for edge: Dictionary in edges:
		edges_by_id[str(edge["id"])] = edge
	var atomic: Dictionary = MapLayoutCompiler._route_atomic_component(
		component, MapLayoutCompiler._component_plan_specs(
			component, plan, half_width + safety, quality
		), edges_by_id, plan, {}, {},
		{"hero_anchor_contract": {"protected_zones": {}}},
		{"profiles": {}}, quality, half_width, safety,
		{"total": 0, "components": {}}
	)
	var binding: Dictionary = atomic.get("binding", {})
	var details: Dictionary = binding.get("details", {})
	var plan_rows: Array = details.get("plans", [])
	var calls_ok: bool = plan_rows.size() == 4
	for row: Dictionary in plan_rows:
		var calls: Dictionary = row.get("route_calls", {})
		calls_ok = calls_ok and MapLayoutCanonical.int_value(calls.get("ordinary", 0)) == 1 \
			and MapLayoutCanonical.int_value(calls.get("near", 0)) == 1 \
			and MapLayoutCanonical.int_value(calls.get("far", 0)) == 1 \
			and row.get("committed", false) == false
	_check(fails, atomic.get("ok", true) == false
			and str(binding.get("kind", "")) == "inversion_component_route"
			and details.get("edge_ids", []) == component["edge_ids"]
			and details.get("local_node_ids", []) == component["node_ids"]
			and details.get("plan_ids", []).size() == 4
			and calls_ok and not atomic.has("routes") and not atomic.has("usage"),
		"an all-plan failure binds both edges and all component nodes without provisional leakage: %s"
			% str(binding))


static func _test_crossing_detour(fails: Array[String], quality: Dictionary) -> void:
	var nodes: Array = [
		_node("A", 3, 2),
		_node("B", 3, 4),
		_node("C", 9, 4),
		_node("D", 9, 2),
	]
	var edges: Array = [_edge("A", "C"), _edge("B", "D")]
	var assets: Dictionary = _assets()
	var compiled: Dictionary = MapLayoutCompiler.compile(
		_input(nodes, edges, 17634, 0, _hero(), quality, assets), quality, assets
	)
	var diagnostics: Dictionary = compiled.get("diagnostics", {})
	var result_v: Variant = compiled.get("result", null)
	_check(fails, str(compiled.get("status", "")) == MapLayoutCompiler.COMPILED
			and result_v is MapLayoutResult,
		"crossing shortest paths compile by routing one legal deterministic detour: %s" \
			% str({"failure": compiled.get("failure", {}),
				"attempted_candidate_ids": _attempted_candidate_ids(diagnostics),
				"last_attempt": _last_route_attempt(diagnostics)}))
	if not (result_v is MapLayoutResult):
		return
	var result: MapLayoutResult = result_v
	var serial: Dictionary = result.to_dict()
	var detoured: bool = false
	for edge_id: String in MapLayoutCanonical.sorted_keys(serial["edges"]):
		var edge: Dictionary = serial["edges"][edge_id]
		detoured = detoured or edge["centerline"].size() > 2
	_check(fails, detoured
			and MapLayoutCanonical.int_value(
				compiled["report"]["hard_values"]["unrelated_edge_intersection_count"]
			) == 0,
		"accepted unrelated corridors remain route obstacles instead of crossing")


static func _test_three_way_fanout_merge(fails: Array[String],
		quality: Dictionary) -> void:
	var nodes: Array = [
		_node("S", 2, 4),
		_node("A", 6, 2),
		_node("B", 6, 4),
		_node("C", 6, 6),
		_node("M", 10, 4),
		_node("T", 13, 4),
	]
	var edges: Array = [
		_edge("S", "A"), _edge("S", "B"), _edge("S", "C"),
		_edge("A", "M"), _edge("B", "M"), _edge("C", "M"),
		_edge("M", "T"),
	]
	var assets: Dictionary = _assets()
	var compiled: Dictionary = MapLayoutCompiler.compile(
		_input(nodes, edges, 717, 0, _hero(), quality, assets), quality, assets
	)
	var attempted: Dictionary = _attempted_candidate_ids(
		compiled.get("diagnostics", {})
	)
	_check(fails, not attempted.get("S", []).is_empty()
			and not attempted.get("A", []).is_empty()
			and not attempted.get("B", []).is_empty(),
		"fan-out repair actually attempts source and branch-target candidates: %s" \
			% str(attempted))
	var result_v: Variant = compiled.get("result", null)
	_check(fails, str(compiled.get("status", "")) == MapLayoutCompiler.COMPILED
			and result_v is MapLayoutResult,
		"three-way fan-out followed by merge compiles: %s" \
			% str({"failure": compiled.get("failure", {}),
				"attempted_candidate_ids": {
					"A": attempted.get("A", []), "B": attempted.get("B", []),
					"S": attempted.get("S", []),
				}}))
	if not (result_v is MapLayoutResult):
		return
	var result: MapLayoutResult = result_v
	var serial: Dictionary = result.to_dict()
	var distinct_departures: Dictionary = {}
	for to_id: String in ["A", "B", "C"]:
		var edge_id: String = MapLayoutInput.edge_id("S", to_id)
		var centreline: Array = serial["edges"][edge_id]["centerline"]
		if centreline.size() > 1:
			distinct_departures[MapLayoutCanonical.canonical_text(centreline[1])] = true
	_check(fails, distinct_departures.size() == 3
			and MapLayoutCanonical.float_value(
				compiled["report"]["hard_values"]["branch_fanout_separation_px"]
			) >= 32.0,
		"alternatives diverge within the governed departure and pass the hard rule")


static func _test_bounded_local_substitution(fails: Array[String],
		quality: Dictionary) -> void:
	var nodes: Array = [
		_node("P", 2, 3),
		_node("A", 7, 5),
		_node("B", 7, 5),
		_node("Q", 12, 3),
	]
	var assets: Dictionary = _assets()
	var compiled: Dictionary = MapLayoutCompiler.compile(
		_input(nodes, [_edge("P", "Q")], 717, 0, _hero(), quality, assets),
		quality, assets
	)
	var diagnostics: Dictionary = compiled.get("diagnostics", {})
	var substitutions: Array = diagnostics.get("substitutions", [])
	var attempts: Array = diagnostics.get("attempts", [])
	var complete_attempts: bool = not attempts.is_empty()
	for attempt: Dictionary in attempts:
		complete_attempts = complete_attempts \
			and attempt.get("chosen_candidate_ids", {}).size() == nodes.size() \
			and attempt.get("routes", []).size() == 1
	_check(fails, str(compiled.get("status", "")) == MapLayoutCompiler.COMPILED
			and not substitutions.is_empty()
			and substitutions.size() <= MapLayoutCompiler.MAX_LOCAL_SUBSTITUTIONS,
		"a named binding drives at most 64 canonical local substitutions: %s" \
		% str({"failure": compiled.get("failure", {}),
			"substitutions": substitutions}))
	_check(fails, complete_attempts and attempts.size() == substitutions.size() + 1,
		"every evaluated substitution attempt remains a complete graph result")


static func _test_production_graphs(fails: Array[String], quality: Dictionary) -> void:
	var content: ContentDB = ContentDB.load_full()
	var assets: Dictionary = _assets()
	for fixture: Array in [[717, 0], [17634, 0], [717, 1], [717, 2], [717, 3]]:
		var seed: int = fixture[0]
		var act: int = fixture[1]
		var run_state: RunState = RunState.new_run(
			content, seed, "map-compiler-%d-%d" % [seed, act]
		)
		run_state.act = act
		var world: WorldMap = WorldMap.for_run(run_state, content)
		var bound: Dictionary = Binding.bind(world, act)
		var label: String = "seed %d Act %d" % [seed, act + 1]
		_check(fails, bound.get("ok", false) == true,
			"%s graph binds to MapLayoutInput records: %s" \
			% [label, bound.get("error", {})])
		if bound.get("ok", false) != true:
			continue
		var input: MapLayoutInput = _input(
			bound["nodes"], bound["edges"], seed, act, _hero(), quality, assets
		)
		var compiled: Dictionary = MapLayoutCompiler.compile(input, quality, assets)
		var attempted: Dictionary = _attempted_candidate_ids(
			compiled.get("diagnostics", {})
		)
		if seed == 717 and act == 0:
			_check(fails, not attempted.get("12,6", []).is_empty(),
				"seed 717 actually attempts candidates for blocker 12,6: %s" \
					% str(attempted))
		if seed == 17634 and act == 0:
			_check(fails, not attempted.get("13,2", []).is_empty(),
				"seed 17634 actually attempts candidates for blocker 13,2: %s" \
					% str(attempted))
		var result_v: Variant = compiled.get("result", null)
		_check(fails, str(compiled.get("status", "")) == MapLayoutCompiler.COMPILED
				and result_v is MapLayoutResult,
			"%s production graph compiles: %s" % [label, {
				"failure": compiled.get("failure", {}),
				"blocker_candidate_ids": attempted.get(
					"12,6" if seed == 717 else "13,2", []
				) if act == 0 and seed in [717, 17634] else [],
			}])
		if result_v is MapLayoutResult:
			var result: MapLayoutResult = result_v
			var serial: Dictionary = result.to_dict()
			_check(fails, serial["node_anchors"].size() == world.nodes.size()
					and serial["edges"].size() == _world_edge_count(world)
					and compiled["report"].get("violations", []).is_empty(),
				"%s result contains the complete graph with zero hard violations" % label)
			if act == 3:
				_check(fails, serial["node_anchors"].get("n4", []) \
						== _a3(MapPinProjection.lattice_point(14, 3)),
					"Act IV boss binds to lattice row 14 / centre lane 3")
				_check(fails, _profile_margin(compiled["report"],
						"pad-landscape/z0/row-00") >= _hard_limit(
							quality, "focused_node_safe_frame_margin_px"),
					"the original Act IV camera profile clears its unchanged hard floor")


static func _input(nodes: Array, edges: Array, seed: int, act: int,
		hero: Dictionary, quality: Dictionary, assets: Dictionary) -> MapLayoutInput:
	return MapLayoutInput.from_dict({
		"schema_version": MapLayoutInput.SCHEMA_VERSION,
		"generator_schema": "map-compiler-v2",
		"generator_version": "map-layout-compiler-v1",
		"nodes": nodes,
		"edges": edges,
		"act": act,
		"run_seed": seed,
		"scenery_seed": seed + 97,
		"asset_profile_digest": assets["digest"],
		"camera_profile_digest": MapQualityEvaluator.camera_registry(
			nodes, quality, edges)["digest"],
		"hero_anchor_contract": hero,
		"quality_registry_digest": MapLayoutCanonical.digest(quality),
	})


static func _world_edge_count(world: WorldMap) -> int:
	var count: int = 0
	for node: MapNode in world.nodes:
		count += node.next.size()
	return count


static func _profile_margin(report: Dictionary, profile_id: String) -> float:
	for row: Dictionary in report.get("raw_measurements", []):
		if str(row.get("metric_id", "")) == "focused_node_safe_frame_margin_px" \
				and str(row.get("profile_id", "")) == profile_id:
			return MapLayoutCanonical.float_value(row.get("value", -INF))
	return -INF


static func _hard_limit(quality: Dictionary, metric_id: String) -> float:
	for row: Dictionary in quality.get("hard", []):
		if str(row.get("id", "")) == metric_id:
			return MapLayoutCanonical.float_value(row.get("limit", INF))
	return INF


static func _assets() -> Dictionary:
	var profile: Dictionary = _profile("hero", Vector3(2.0, 3.0, 2.0))
	return {
		"profiles": {"hero": profile},
		"digest": MapAssetProfiles.new(MapQualityEvaluator.EMPTY_MANIFEST).digest([profile]),
	}


static func _hero() -> Dictionary:
	return {
		"schema_version": MapLayoutInput.HERO_ANCHOR_SCHEMA_VERSION,
		"anchors": {
			"vigil": {
				"asset_id": "hero/vigil",
				"profile_id": "hero",
				"position": [100.0, 0.0, 100.0],
				"yaw_radians": 0.25,
				"scale": [1.0, 1.0, 1.0],
			},
		},
		"protected_zones": {
			"vigil-zone": {
				"role": "vigil",
				"polygon": _box(Vector2(100.0, 100.0), 2.0),
			},
		},
	}


static func _profile(id: String, size: Vector3) -> Dictionary:
	var aabb: AABB = AABB(-size * 0.5, size)
	return {
		"profile_schema_version": MapAssetProfiles.PROFILE_SCHEMA_VERSION,
		"asset_id": id,
		"source_path": "synthetic/%s" % id,
		"source_mesh_identity": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		"local_aabb": aabb,
		"grounded_height": size.y,
		"local_footprint": PackedVector2Array([
			Vector2(aabb.position.x, aabb.position.z),
			Vector2(aabb.position.x, aabb.end.z),
			Vector2(aabb.end.x, aabb.end.z),
			Vector2(aabb.end.x, aabb.position.z),
		]),
		"default_scale": 1.0,
		"yaw_mode": MapAssetProfiles.YAW_FREE,
		"yaw_degrees": 0.0,
		"semantic_class": MapAssetProfiles.SEMANTIC_HERO,
		"footprint_source": "synthetic",
		"override_reason": "",
		"occlusion_model": "synthetic",
	}


static func _node(id: String, row: int, col: int,
		type: String = "monster", jitter: Array = [0.0, 0.0]) -> Dictionary:
	return {"id": id, "row": row, "col": col, "type": type, "jitter": jitter}


static func _edge(from_id: String, to_id: String) -> Dictionary:
	return {
		"id": MapLayoutInput.edge_id(from_id, to_id),
		"from": from_id,
		"to": to_id,
	}


static func _box(center: Vector2, half: float) -> Array:
	return [
		[center.x - half, center.y - half],
		[center.x - half, center.y + half],
		[center.x + half, center.y + half],
		[center.x + half, center.y - half],
	]


static func _a3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


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
