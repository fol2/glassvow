class_name MapLayoutCompiler
extends RefCounted
## Pure Map Compiler v2 node-and-route vertical slice (#469).

const COMPILED: String = "COMPILED"
const NO_FEASIBLE_NODE_ROUTE_LAYOUT: String = "NO_FEASIBLE_NODE_ROUTE_LAYOUT"
const VERSION: String = "map-layout-compiler-v1"
const MAX_LOCAL_SUBSTITUTIONS: int = 64
const _Routes = preload("res://presentation/map/map_layout_compiler_routes.gd")
const _REQUIRED_HERO_FIELDS: PackedStringArray = [
	"asset_id", "profile_id", "position", "yaw_radians", "scale",
]

@warning_ignore_start("unsafe_call_argument")


static func compile(input: MapLayoutInput, quality: Dictionary,
		assets: Dictionary) -> Dictionary:
	var diagnostics: Dictionary = {
		"schema_version": 1,
		"version": VERSION,
		"input_digest": "" if input == null else input.digest(),
		"candidate_digest": "",
		"route_order": [],
		"inversion_components": [],
		"access_lengths": {},
		"route_calls": {"normal": 0, "bypass": 0},
		"chosen_bypass_sides": {},
		"selected_bypass_owners": {},
		"rejected_route_plans": [],
		"component_route_plans": [],
		"chosen_candidate_ids": {},
		"substitutions": [],
		"attempts": [],
		"limits": {"max_local_substitutions": MAX_LOCAL_SUBSTITUTIONS},
	}
	if input == null:
		return _failure(diagnostics, _binding("input", "input", "validated input is null"))
	var source: Dictionary = input.to_dict()
	var authority: Dictionary = _validate_authorities(source, input, quality, assets)
	if not authority.is_empty():
		return _failure(diagnostics, authority)
	var hero_report: Dictionary = _hero_placements(source, assets)
	if hero_report.get("ok", false) != true:
		return _failure(diagnostics, hero_report.get("binding", {}))
	var heroes: Dictionary = hero_report["placements"]
	var candidate_report: Dictionary = MapNodeCandidateGenerator.generate(input, quality, 0)
	diagnostics["candidate_digest"] = candidate_report.get("candidate_digest", "")
	var candidate_errors: Array = candidate_report.get("errors", [])
	if not candidate_errors.is_empty():
		return _failure(diagnostics, _binding(
			"candidate_generation", "candidate_sets", str(candidate_errors[0])
		))
	var impossibilities: Array = candidate_report.get("impossibilities", [])
	if not impossibilities.is_empty():
		var impossible: Dictionary = impossibilities[0]
		return _failure(diagnostics, {
			"kind": "node_candidate",
			"id": str(impossible.get("node_id", "")),
			"node_id": str(impossible.get("node_id", "")),
			"edge_id": "",
			"profile_id": "world",
			"reason": "no legal #467 node candidate",
			"details": impossible,
		})
	var node_sets: Dictionary = candidate_report.get("node_sets", {})
	var selection: Dictionary = {}
	for node_id: String in MapLayoutCanonical.sorted_keys(node_sets):
		var node_set: Dictionary = node_sets[node_id]
		var candidates: Array = node_set.get("candidates", [])
		if candidates.is_empty():
			return _failure(diagnostics, _binding(
				"node_candidate", node_id, "candidate set is empty", node_id
			))
		selection[node_id] = 0
	var queue: Array = [{"selection": selection.duplicate(true), "substitution": {}}]
	var seen: Dictionary = {MapLayoutCanonical.digest(selection): true}
	var last_binding: Dictionary = {}
	while not queue.is_empty():
		var queued: Dictionary = queue.pop_back()
		selection = queued["selection"]
		var applied: Dictionary = queued["substitution"]
		if not applied.is_empty():
			if diagnostics["substitutions"].size() >= MAX_LOCAL_SUBSTITUTIONS:
				break
			applied["index"] = diagnostics["substitutions"].size() + 1
			diagnostics["substitutions"].append(applied)
		var attempt: Dictionary = _build_attempt(
			input, source, quality, assets, heroes, node_sets, selection
		)
		diagnostics["attempts"].append(attempt["diagnostics"])
		for key: String in [
			"route_order", "inversion_components", "access_lengths",
			"route_calls", "chosen_bypass_sides", "selected_bypass_owners",
			"rejected_route_plans",
			"component_route_plans",
		]:
			diagnostics[key] = attempt["diagnostics"].get(key, diagnostics[key])
		diagnostics["chosen_candidate_ids"] = attempt.get("chosen_candidate_ids", {})
		if attempt.get("ok", false) == true:
			return _success(diagnostics, attempt["result"], attempt["report"])
		var binding: Dictionary = attempt.get("binding", {})
		last_binding = binding
		if binding.get("details", {}).get("terminal", false) == true:
			return _failure(diagnostics, binding)
		for child: Dictionary in _substitution_children(
				binding, input, node_sets, selection):
			var child_selection: Dictionary = child["selection"]
			var key: String = MapLayoutCanonical.digest(child_selection)
			if seen.has(key):
				continue
			seen[key] = true
			queue.append(child)
	if diagnostics["substitutions"].size() >= MAX_LOCAL_SUBSTITUTIONS:
		return _failure(diagnostics, _bound_exhausted(last_binding))
	return _failure(diagnostics, _missing_mechanism(last_binding))


static func _validate_authorities(source: Dictionary, input: MapLayoutInput,
		quality: Dictionary, assets: Dictionary) -> Dictionary:
	var quality_digest: String = MapLayoutCanonical.digest(quality)
	if quality_digest != str(source["quality_registry_digest"]):
		return _digest_binding("quality_registry_digest",
			str(source["quality_registry_digest"]), quality_digest)
	var camera_digest: String = str(
		MapQualityEvaluator.camera_registry(
			input.node_records(), quality, input.edge_records())["digest"]
	)
	if camera_digest != str(source["camera_profile_digest"]):
		return _digest_binding("camera_profile_digest",
			str(source["camera_profile_digest"]), camera_digest)
	var profiles_v: Variant = assets.get("profiles", null)
	if typeof(profiles_v) != TYPE_DICTIONARY:
		return _binding("asset_profile_digest", "profiles",
			"asset bundle profiles must be a Dictionary")
	var profiles: Dictionary = profiles_v
	var profile_rows: Array[Dictionary] = []
	for profile_id: String in MapLayoutCanonical.sorted_keys(profiles):
		var profile_v: Variant = profiles[profile_id]
		if typeof(profile_v) != TYPE_DICTIONARY:
			return _binding("asset_profile_digest", profile_id,
				"asset profile must be a Dictionary")
		var profile: Dictionary = profile_v
		profile_rows.append(profile)
	var computed_asset_digest: String = MapAssetProfiles.new(
		MapQualityEvaluator.EMPTY_MANIFEST
	).digest(profile_rows)
	var bundle_digest: String = str(assets.get("digest", ""))
	if computed_asset_digest.is_empty() or computed_asset_digest != bundle_digest:
		return _digest_binding("asset_bundle_digest", bundle_digest,
			computed_asset_digest)
	if bundle_digest != str(source["asset_profile_digest"]):
		return _digest_binding("asset_profile_digest",
			str(source["asset_profile_digest"]), bundle_digest)
	return {}


static func _hero_placements(source: Dictionary, assets: Dictionary) -> Dictionary:
	var anchors: Dictionary = source["hero_anchor_contract"]["anchors"]
	var profiles: Dictionary = assets["profiles"]
	var placements: Dictionary = {}
	for anchor_id: String in MapLayoutCanonical.sorted_keys(anchors):
		var anchor_v: Variant = anchors[anchor_id]
		if typeof(anchor_v) != TYPE_DICTIONARY:
			return _hero_error(anchor_id, "anchor", "must be a Dictionary")
		var anchor: Dictionary = anchor_v
		for field: String in _REQUIRED_HERO_FIELDS:
			if not anchor.has(field):
				return _hero_error(anchor_id, field, "is missing")
		for field: String in ["asset_id", "profile_id"]:
			if not MapLayoutCanonical.nonempty(anchor[field]):
				return _hero_error(anchor_id, field, "must be non-empty")
		if not MapLayoutCanonical.vector(anchor["position"], 3):
			return _hero_error(anchor_id, "position", "must be a finite Array[3]")
		if not MapLayoutCanonical.number(anchor["yaw_radians"]):
			return _hero_error(anchor_id, "yaw_radians", "must be finite and numeric")
		if not MapLayoutCanonical.vector(anchor["scale"], 3, true):
			return _hero_error(anchor_id, "scale", "must be a positive finite Array[3]")
		var profile_id: String = str(anchor["profile_id"])
		if not profiles.has(profile_id):
			return _hero_error(anchor_id, "profile_id", "does not exist in the asset bundle")
		placements[anchor_id] = {
			"asset_id": anchor["asset_id"],
			"profile_id": profile_id,
			"transform": {
				"origin": anchor["position"],
				"yaw_radians": anchor["yaw_radians"],
				"scale": anchor["scale"],
			},
		}
	return {"ok": true, "placements": MapLayoutCanonical.ordered_dictionary(placements)}


static func _build_attempt(input: MapLayoutInput, source: Dictionary,
		quality: Dictionary, assets: Dictionary, heroes: Dictionary,
		node_sets: Dictionary, selection: Dictionary) -> Dictionary:
	var anchors: Dictionary = {}
	var chosen_ids: Dictionary = {}
	for node_id: String in MapLayoutCanonical.sorted_keys(node_sets):
		var candidates: Array = node_sets[node_id]["candidates"]
		var candidate: Dictionary = candidates[MapLayoutCanonical.int_value(selection[node_id])]
		anchors[node_id] = candidate["anchor"]
		chosen_ids[node_id] = candidate["id"]
	var plan: Dictionary = _Routes.route_plan(
		input.node_records(), input.edge_records(), anchors, quality
	)
	if plan.get("ok", false) != true:
		return _attempt_failure(chosen_ids, [], plan.get("binding", {}))
	var plan_diagnostics: Dictionary = plan["diagnostics"].duplicate(true)
	var route_order: Array = plan["route_order"]
	var routes: Dictionary = {}
	var route_rows: Array = []
	var bypass_usage: Dictionary = {"total": 0, "components": {}}
	var completed_components: Dictionary = {}
	var edges_by_id: Dictionary = {}
	for edge: Dictionary in route_order:
		edges_by_id[str(edge["id"])] = edge
	var half_width: float = MapLayoutCanonical.float_value(
		quality["geometry"]["road_corridor"]["physical_half_width_m"]
	)
	var safety: float = MapLayoutCanonical.float_value(
		quality["geometry"]["road_corridor"]["world_clearance_m"]
	)
	for edge: Dictionary in route_order:
		var edge_id: String = str(edge["id"])
		var component_id: String = str(plan["edge_components"].get(edge_id, ""))
		if completed_components.has(component_id):
			continue
		if not component_id.is_empty():
			var component: Dictionary = plan["components_by_id"][component_id]
			if component["edge_ids"].size() == 2:
				var atomic: Dictionary = _route_atomic_component(
					component, _component_plan_specs(
						component, plan, half_width + safety, quality
					), edges_by_id, plan, heroes, routes, source, assets,
					quality, half_width, safety, bypass_usage
				)
				_record_atomic_diagnostics(plan_diagnostics, atomic)
				plan_diagnostics["component_route_plans"].append(
					atomic["component_diagnostics"]
				)
				if atomic.get("ok", false) != true:
					var atomic_binding: Dictionary = atomic["binding"]
					var blocking_atomic_id: String = _blocking_completed_component(
						atomic_binding, plan, completed_components
					)
					var repaired_atomic: Dictionary = _repair_blocking_atomic_component(
						component, blocking_atomic_id, edges_by_id, plan, heroes, routes,
						source, assets, quality, half_width, safety, bypass_usage
					)
					if repaired_atomic.get("ok", false) == true:
						var blocking_component: Dictionary = repaired_atomic[
							"blocking_component"
						]
						var blocking_edges: Array = blocking_component["edge_ids"]
						var kept_rows: Array = []
						for row: Dictionary in route_rows:
							if str(row.get("edge_id", "")) not in blocking_edges:
								kept_rows.append(row)
						route_rows = kept_rows
						var blocking_id: String = str(blocking_component["id"])
						plan_diagnostics["selected_bypass_owners"].erase(blocking_id)
						for member_id_v: Variant in blocking_edges:
							plan_diagnostics["chosen_bypass_sides"].erase(
								str(member_id_v)
							)
						var current: Dictionary = repaired_atomic["current"]
						var replay: Dictionary = repaired_atomic["replay"]
						for repaired: Dictionary in [current, replay]:
							_record_atomic_diagnostics(plan_diagnostics, repaired)
							plan_diagnostics["component_route_plans"].append(
								repaired["component_diagnostics"]
							)
							route_rows.append_array(repaired["route_rows"])
						routes = replay["routes"]
						bypass_usage = replay["usage"]
						completed_components[component_id] = true
						continue
					if not blocking_atomic_id.is_empty():
						_promote_atomic_causal_binding(atomic_binding, plan)
					return _attempt_failure(chosen_ids, route_rows,
						atomic_binding, plan_diagnostics)
				routes = atomic["routes"]
				bypass_usage = atomic["usage"]
				route_rows.append_array(atomic["route_rows"])
				completed_components[component_id] = true
				continue
		var routed_edge: Dictionary = _route_edge(
			edge, plan, heroes, routes, source, assets, quality,
			half_width, safety, bypass_usage
		)
		var route_plan_diagnostics: Dictionary = routed_edge.get("plan", {})
		_record_route_diagnostics(
			plan_diagnostics, edge_id, route_plan_diagnostics, true
		)
		if routed_edge.get("ok", false) != true:
			var repaired: Dictionary = _repair_blocking_component(
				edge, routed_edge, edges_by_id, plan, heroes, routes,
				source, assets, quality, half_width, safety, bypass_usage,
				completed_components
			)
			if repaired.get("ok", false) == true:
				var component: Dictionary = repaired["component"]
				var member_ids: Array = component["edge_ids"]
				var kept_rows: Array = []
				for row: Dictionary in route_rows:
					if str(row.get("edge_id", "")) not in member_ids:
						kept_rows.append(row)
				route_rows = kept_rows
				var current: Dictionary = repaired["current"]
				_record_route_diagnostics(
					plan_diagnostics, edge_id, current["plan"], true
				)
				var replay: Dictionary = repaired["replay"]
				_record_atomic_diagnostics(plan_diagnostics, replay)
				plan_diagnostics["component_route_plans"].append(
					replay["component_diagnostics"]
				)
				route_rows.append(current["row"])
				route_rows.append_array(replay["route_rows"])
				routes = replay["routes"]
				bypass_usage = replay["usage"]
				continue
			if not routed_edge.get("row", {}).is_empty():
				route_rows.append(routed_edge["row"])
			return _attempt_failure(chosen_ids, route_rows,
				routed_edge["binding"], plan_diagnostics)
		if not routed_edge.get("row", {}).is_empty():
			route_rows.append(routed_edge["row"])
		routes[edge_id] = routed_edge["route"]
	var selected_id: String = "selection/%s" % MapLayoutCanonical.digest(chosen_ids)
	var provisional: MapLayoutResult = _result(
		source, input, anchors, routes, heroes, {}, {}, selected_id
	)
	if provisional == null:
		return _attempt_failure(chosen_ids, route_rows,
			_binding("result_contract", "provisional", "provisional result is invalid"),
			plan_diagnostics)
	var first: Dictionary = MapQualityEvaluator.evaluate(
		input, provisional, assets, quality
	)
	var final_result: MapLayoutResult = _result(
		source, input, anchors, routes, heroes,
		first.get("hard_values", {}), first.get("soft_raw", {}), selected_id
	)
	if final_result == null:
		return _attempt_failure(chosen_ids, route_rows,
			_binding("result_contract", "final", "final result is invalid"),
			plan_diagnostics)
	var second: Dictionary = MapQualityEvaluator.evaluate(
		input, final_result, assets, quality
	)
	if str(second.get("layout_digest", "")) != final_result.digest() \
			or first.get("hard_values", {}) != second.get("hard_values", {}) \
			or first.get("soft_raw", {}) != second.get("soft_raw", {}):
		return _attempt_failure(chosen_ids, route_rows, _binding(
			"evaluator_binding", "final_result",
			"second evaluator pass does not reproduce the final result vectors"
		), plan_diagnostics)
	var attempt_diagnostics: Dictionary = _attempt_diagnostics(
		chosen_ids, route_rows, plan_diagnostics
	)
	if second.get("hard_pass", false) != true:
		var binding: Dictionary = _quality_binding(second, input)
		attempt_diagnostics["first_binding_violation"] = binding
		return {
			"ok": false,
			"binding": binding,
			"chosen_candidate_ids": chosen_ids,
			"diagnostics": attempt_diagnostics,
		}
	return {
		"ok": true,
		"result": final_result,
		"report": second,
		"chosen_candidate_ids": chosen_ids,
		"diagnostics": attempt_diagnostics,
	}


static func _route_edge(edge: Dictionary, plan: Dictionary,
		heroes: Dictionary, accepted_routes: Dictionary, source: Dictionary,
		assets: Dictionary, quality: Dictionary, half_width: float,
		safety: float, usage: Dictionary,
		reverse_side_order: bool = false) -> Dictionary:
	var edge_id: String = str(edge["id"])
	var channel: PackedVector2Array = _Routes.route_channel(
		edge, plan, (half_width + safety) * 2.0
	)
	var obstacles_report: Dictionary = _Routes.route_obstacles(
		edge, plan, heroes, accepted_routes, source, assets, channel,
		half_width + safety
	)
	if obstacles_report.get("ok", false) != true:
		return {"ok": false, "binding": obstacles_report.get("binding", {}),
			"row": {}, "plan": {}}
	var routed: Dictionary = _Routes.route_planned(
		edge, plan, obstacles_report["obstacles"], half_width, safety,
		quality, channel, usage, reverse_side_order
	)
	var route_diagnostics: Dictionary = routed.get("plan_diagnostics", {})
	var row: Dictionary = {
		"edge_id": edge_id,
		"route_digest": routed.get("digest", ""),
		"status": routed.get("status", ""),
		"obstacle_ids": obstacles_report["obstacle_ids"],
		"plan": route_diagnostics,
	}
	if str(routed.get("status", "")) != MapSingleEdgeRouter.ROUTED:
		return {"ok": false, "binding": _edge_route_binding(
			edge, routed, route_diagnostics
		), "row": row, "plan": route_diagnostics, "routed": routed}
	return {
		"ok": true,
		"binding": {},
		"row": row,
		"plan": route_diagnostics,
		"routed": routed,
		"route": {
			"from": edge["from"],
			"to": edge["to"],
			"centerline": routed["centerline"],
			"corridor_width": routed["corridor_width"],
		},
	}


static func _repair_blocking_component(edge: Dictionary, failed: Dictionary,
		edges_by_id: Dictionary, plan: Dictionary, heroes: Dictionary,
		accepted_routes: Dictionary, source: Dictionary, assets: Dictionary,
		quality: Dictionary, half_width: float, safety: float, usage: Dictionary,
		completed_components: Dictionary) -> Dictionary:
	var blocker_id: String = str(
		failed.get("binding", {}).get("details", {}).get("blocking_obstacle_id", "")
	)
	var blocker_entity: String = _Routes.obstacle_entity(blocker_id)
	var component_id: String = str(plan["edge_components"].get(blocker_entity, ""))
	if component_id.is_empty() and blocker_id.begins_with("node:"):
		var matches: Array[String] = []
		for completed_id: String in MapLayoutCanonical.sorted_keys(completed_components):
			if blocker_entity in plan["components_by_id"][completed_id]["node_ids"]:
				matches.append(completed_id)
		if matches.size() == 1:
			component_id = matches[0]
	if component_id.is_empty() or not completed_components.has(component_id):
		return {}
	var component: Dictionary = plan["components_by_id"][component_id]
	if component["edge_ids"].size() != 2:
		return {}
	var provisional_routes: Dictionary = accepted_routes.duplicate(true)
	for member_id_v: Variant in component["edge_ids"]:
		provisional_routes.erase(str(member_id_v))
	var provisional_usage: Dictionary = usage.duplicate(true)
	var component_usage: int = MapLayoutCanonical.int_value(
		provisional_usage["components"].get(component_id, 0)
	)
	provisional_usage["total"] = MapLayoutCanonical.int_value(
		provisional_usage["total"]
	) - component_usage
	provisional_usage["components"].erase(component_id)
	var current: Dictionary = _route_edge(
		edge, plan, heroes, provisional_routes, source, assets, quality,
		half_width, safety, provisional_usage
	)
	if current.get("ok", false) != true:
		return {}
	provisional_routes[str(edge["id"])] = current["route"]
	var replay: Dictionary = _route_atomic_component(
		component, _component_plan_specs(
			component, plan, half_width + safety, quality
		), edges_by_id, plan, heroes, provisional_routes, source, assets,
		quality, half_width, safety, provisional_usage
	)
	if replay.get("ok", false) != true:
		return {}
	return {"ok": true, "component": component, "current": current,
		"replay": replay}


static func _repair_blocking_atomic_component(component: Dictionary,
		blocking_id: String, edges_by_id: Dictionary, plan: Dictionary,
		heroes: Dictionary, accepted_routes: Dictionary, source: Dictionary,
		assets: Dictionary, quality: Dictionary, half_width: float,
		safety: float, usage: Dictionary) -> Dictionary:
	if blocking_id.is_empty() or component["edge_ids"].size() != 2:
		return {}
	var blocking: Dictionary = plan["components_by_id"][blocking_id]
	if blocking["edge_ids"].size() != 2:
		return {}
	var provisional_routes: Dictionary = accepted_routes.duplicate(true)
	for member_id_v: Variant in blocking["edge_ids"]:
		provisional_routes.erase(str(member_id_v))
	var provisional_usage: Dictionary = usage.duplicate(true)
	var removed_usage: int = MapLayoutCanonical.int_value(
		provisional_usage["components"].get(blocking_id, 0)
	)
	provisional_usage["total"] = MapLayoutCanonical.int_value(
		provisional_usage["total"]
	) - removed_usage
	provisional_usage["components"].erase(blocking_id)
	var current: Dictionary = _route_atomic_component(
		component, _component_plan_specs(
			component, plan, half_width + safety, quality
		), edges_by_id, plan, heroes, provisional_routes, source, assets,
		quality, half_width, safety, provisional_usage
	)
	if current.get("ok", false) != true:
		return {}
	var current_routes: Dictionary = current["routes"]
	var current_usage: Dictionary = current["usage"]
	var replay: Dictionary = _route_atomic_component(
		blocking, _component_plan_specs(
			blocking, plan, half_width + safety, quality
		), edges_by_id, plan, heroes, current_routes, source, assets,
		quality, half_width, safety, current_usage
	)
	if replay.get("ok", false) != true:
		return {}
	return {"ok": true, "blocking_component": blocking,
		"current": current, "replay": replay}


static func _blocking_completed_component(binding: Dictionary,
		plan: Dictionary, completed_components: Dictionary) -> String:
	var matches: Dictionary = {}
	for obstacle_id_v: Variant in binding.get(
			"details", {}
	).get("causal_obstacle_ids", []):
		var obstacle_id: String = str(obstacle_id_v)
		var entity: String = _Routes.obstacle_entity(obstacle_id)
		var component_id: String = str(plan["edge_components"].get(entity, ""))
		if completed_components.has(component_id):
			matches[component_id] = true
		if obstacle_id.begins_with("node:"):
			for completed_id: String in MapLayoutCanonical.sorted_keys(
					completed_components):
				if entity in plan["components_by_id"][completed_id]["node_ids"]:
					matches[completed_id] = true
	var ids: Array[String] = MapLayoutCanonical.sorted_keys(matches)
	return ids[0] if ids.size() == 1 else ""


static func _promote_atomic_causal_binding(binding: Dictionary,
		plan: Dictionary) -> void:
	var details: Dictionary = binding.get("details", {})
	var coupled_nodes: Dictionary = {}
	for obstacle_id_v: Variant in details.get(
			"supported_causal_obstacle_ids", []):
		var obstacle_id: String = str(obstacle_id_v)
		if not obstacle_id.begins_with("edge:"):
			continue
		var edge_id: String = _Routes.obstacle_entity(obstacle_id)
		for edge: Dictionary in plan["route_order"]:
			if str(edge["id"]) == edge_id:
				coupled_nodes[str(edge["from"])] = true
				coupled_nodes[str(edge["to"])] = true
				break
	var priority_obstacles: Array[String] = []
	for obstacle_id_v: Variant in details.get(
			"supported_causal_obstacle_ids", []):
		var obstacle_id: String = str(obstacle_id_v)
		if obstacle_id.begins_with("node:") \
				and not coupled_nodes.has(_Routes.obstacle_entity(obstacle_id)):
			priority_obstacles.append(obstacle_id)
	details["priority_obstacle_ids"] = priority_obstacles
	var entities: Array = details.get("entities", []).duplicate()
	for obstacle_id_v: Variant in details.get("causal_obstacle_ids", []):
		var entity: String = _Routes.obstacle_entity(str(obstacle_id_v))
		if not entity.is_empty() and entity not in entities:
			entities.append(entity)
	details["entities"] = entities
	binding["details"] = details


static func _edge_route_binding(edge: Dictionary, routed: Dictionary,
		route_diagnostics: Dictionary) -> Dictionary:
	var edge_id: String = str(edge["id"])
	var blocked: Dictionary = route_diagnostics.get("first_blocker", {})
	var blocker: String = str(blocked.get("obstacle_id", ""))
	var blocker_node: String = blocker.trim_prefix("node:") \
		if blocker.begins_with("node:") else ""
	var details: Dictionary = routed.get("diagnostics", {}).duplicate(true)
	details["blocking_obstacle_id"] = blocker
	details["local_node_ids"] = blocked.get("local_node_ids", [])
	details["route_plan"] = route_diagnostics
	details["terminal"] = route_diagnostics.get("terminal", false)
	var entities: Array = [edge_id]
	var blocker_entity: String = _Routes.obstacle_entity(blocker)
	if not blocker_entity.is_empty():
		entities.append(blocker_entity)
	details["entities"] = entities
	return {
		"kind": "edge_route",
		"id": edge_id,
		"node_id": blocker_node,
		"edge_id": edge_id,
		"profile_id": "world",
		"reason": str(routed.get("reason", "route failed")),
		"details": details,
	}


static func _record_route_diagnostics(plan_diagnostics: Dictionary,
		edge_id: String, route_diagnostics: Dictionary,
		selected_side: bool, component_plan_id: String = "") -> void:
	plan_diagnostics["route_calls"]["normal"] += MapLayoutCanonical.int_value(
		route_diagnostics.get("normal_calls", 0)
	)
	plan_diagnostics["route_calls"]["bypass"] += MapLayoutCanonical.int_value(
		route_diagnostics.get("bypass_calls", 0)
	)
	var side: String = str(route_diagnostics.get("chosen_bypass_side", ""))
	if selected_side and not side.is_empty():
		plan_diagnostics["chosen_bypass_sides"][edge_id] = side
	for rejected_v: Variant in route_diagnostics.get("rejected_plans", []):
		var rejected: Dictionary = rejected_v.duplicate(true)
		if not component_plan_id.is_empty():
			rejected["component_plan_id"] = component_plan_id
		plan_diagnostics["rejected_route_plans"].append(rejected)


static func _route_atomic_component(component: Dictionary,
		specs: Array[Dictionary], edges_by_id: Dictionary, plan: Dictionary,
		heroes: Dictionary, accepted_routes: Dictionary, source: Dictionary,
		assets: Dictionary, quality: Dictionary, half_width: float,
		safety: float, entry_usage: Dictionary) -> Dictionary:
	var component_id: String = str(component["id"])
	var prefix: Dictionary = _accepted_prefix(accepted_routes)
	var plan_records: Array[Dictionary] = []
	var rejected_routes: Array[Dictionary] = []
	var total_calls: Dictionary = {"normal": 0, "bypass": 0}
	var first_binding: Dictionary = {}
	var causal_obstacles: Dictionary = {}
	var selected: Dictionary = {}
	for plan_index: int in range(specs.size()):
		var spec: Dictionary = specs[plan_index]
		var plan_causal_obstacles: Dictionary = {}
		var provisional_routes: Dictionary = accepted_routes.duplicate(true)
		var provisional_usage: Dictionary = entry_usage.duplicate(true)
		var member_rows: Array = []
		var members: Array[Dictionary] = []
		var route_digests: Dictionary = {}
		var chosen_sides: Dictionary = {}
		var bypass_owner: String = ""
		var failure: Dictionary = {}
		var plan_calls: Dictionary = {"ordinary": 0, "near": 0, "far": 0}
		for edge_id_v: Variant in spec["edge_order"]:
			var edge_id: String = str(edge_id_v)
			var routed_edge: Dictionary = _route_edge(
				edges_by_id[edge_id], plan, heroes, provisional_routes,
				source, assets, quality, half_width, safety,
				provisional_usage, bool(spec["reverse_side_order"])
			)
			var route_diagnostics: Dictionary = routed_edge.get("plan", {})
			for obstacle_id_v: Variant in route_diagnostics.get(
					"bypass_blocking_obstacle_ids", []):
				var obstacle_id: String = str(obstacle_id_v)
				causal_obstacles[obstacle_id] = true
				plan_causal_obstacles[obstacle_id] = true
			var router_calls: Dictionary = route_diagnostics.get("router_calls", {})
			for call_id: String in ["ordinary", "near", "far"]:
				plan_calls[call_id] += MapLayoutCanonical.int_value(
					router_calls.get(call_id, 0)
				)
			total_calls["normal"] += MapLayoutCanonical.int_value(
				route_diagnostics.get("normal_calls", 0)
			)
			total_calls["bypass"] += MapLayoutCanonical.int_value(
				route_diagnostics.get("bypass_calls", 0)
			)
			for rejected_v: Variant in route_diagnostics.get("rejected_plans", []):
				var rejected: Dictionary = rejected_v.duplicate(true)
				rejected["component_id"] = component_id
				rejected["component_plan_id"] = spec["plan_id"]
				rejected_routes.append(rejected)
			var routed: Dictionary = routed_edge.get("routed", {})
			members.append({
				"edge_id": edge_id,
				"status": routed.get("status", "OBSTACLE_FAILURE"),
				"route_digest": routed.get("digest", ""),
				"chosen_bypass_side": route_diagnostics.get(
					"chosen_bypass_side", ""),
				"bypass_side_order": route_diagnostics.get(
					"bypass_side_order", []),
				"router_calls": router_calls,
				"router_diagnostics": route_diagnostics.get(
					"router_diagnostics", {}),
				"first_blocker": route_diagnostics.get("first_blocker", {}),
				"binding": routed_edge.get("binding", {}),
			})
			if routed_edge.get("ok", false) != true:
				failure = routed_edge.get("binding", {})
				if first_binding.is_empty():
					first_binding = failure
				break
			provisional_routes[edge_id] = routed_edge["route"]
			member_rows.append(routed_edge["row"])
			route_digests[edge_id] = routed.get("digest", "")
			var side: String = str(route_diagnostics.get("chosen_bypass_side", ""))
			if not side.is_empty():
				chosen_sides[edge_id] = side
				bypass_owner = edge_id
		var record: Dictionary = spec.duplicate(true)
		record["status"] = "succeeded" if failure.is_empty() else "rejected"
		record["committed"] = false
		record["members"] = members
		record["route_calls"] = plan_calls
		record["accepted_route_digests"] = route_digests
		record["bypass_owner"] = bypass_owner
		record["entry_bypass_usage"] = entry_usage.duplicate(true)
		record["provisional_bypass_usage"] = provisional_usage
		record["first_binding"] = failure
		record["causal_obstacle_ids"] = MapLayoutCanonical.sorted_keys(
			plan_causal_obstacles
		)
		plan_records.append(record)
		if failure.is_empty() and selected.is_empty():
			selected = {
				"index": plan_index,
				"routes": provisional_routes,
				"usage": provisional_usage,
				"route_rows": member_rows,
				"chosen_sides": chosen_sides,
				"bypass_owner": bypass_owner,
				"route_digests": route_digests,
			}
	if not selected.is_empty():
		var selected_index: int = MapLayoutCanonical.int_value(selected["index"])
		for plan_index: int in range(plan_records.size()):
			var record: Dictionary = plan_records[plan_index]
			if plan_index == selected_index:
				record["status"] = "selected"
				record["committed"] = true
			elif str(record["status"]) == "succeeded":
				record["status"] = "not_selected"
			plan_records[plan_index] = record
	var plan_ids: Array[String] = []
	for spec: Dictionary in specs:
		plan_ids.append(str(spec["plan_id"]))
	var supported_causal_obstacles: Dictionary = {}
	if plan_records.size() == 4:
		for obstacle_id_v: Variant in plan_records[0]["causal_obstacle_ids"]:
			var obstacle_id: String = str(obstacle_id_v)
			var supported: bool = true
			for plan_index: int in range(1, plan_records.size()):
				supported = supported and obstacle_id in plan_records[
					plan_index
				]["causal_obstacle_ids"]
			if supported:
				supported_causal_obstacles[obstacle_id] = true
	var component_diagnostics: Dictionary = {
		"component_id": component_id,
		"edge_ids": component["edge_ids"],
		"node_ids": component["node_ids"],
		"accepted_prefix": prefix,
		"plan_ids": plan_ids,
		"plans": plan_records,
		"selected_plan_id": "" if selected.is_empty() else \
			str(specs[MapLayoutCanonical.int_value(selected["index"])]["plan_id"]),
		"selected_bypass_owner": "" if selected.is_empty() else \
			str(selected["bypass_owner"]),
		"accepted_route_digests": {} if selected.is_empty() else \
			selected["route_digests"],
		"route_calls": total_calls,
		"causal_obstacle_ids": MapLayoutCanonical.sorted_keys(causal_obstacles),
		"supported_causal_obstacle_ids": MapLayoutCanonical.sorted_keys(
			supported_causal_obstacles
		),
	}
	var base: Dictionary = {
		"component_diagnostics": component_diagnostics,
		"route_calls": total_calls,
		"rejected_route_plans": rejected_routes,
		"chosen_sides": {} if selected.is_empty() else selected["chosen_sides"],
		"bypass_owner": "" if selected.is_empty() else selected["bypass_owner"],
	}
	if not selected.is_empty():
		base.merge({"ok": true, "routes": selected["routes"],
			"usage": selected["usage"], "route_rows": selected["route_rows"]})
		return base
	var entities: Array = component["edge_ids"].duplicate()
	entities.append_array(component["node_ids"])
	base.merge({"ok": false, "binding": {
		"kind": "inversion_component_route",
		"id": component_id,
		"node_id": "",
		"edge_id": "",
		"profile_id": "world",
		"reason": "all four bounded component plans rejected",
		"details": {
			"component_id": component_id,
			"edge_ids": component["edge_ids"],
			"local_node_ids": component["node_ids"],
			"entities": entities,
			"causal_obstacle_ids": MapLayoutCanonical.sorted_keys(causal_obstacles),
			"supported_causal_obstacle_ids": MapLayoutCanonical.sorted_keys(
				supported_causal_obstacles
			),
			"plan_ids": plan_ids,
			"plans": plan_records,
			"first_binding_blocker": first_binding,
			"accepted_prefix": prefix,
			"terminal": false,
		},
	}})
	return base


static func _record_atomic_diagnostics(plan_diagnostics: Dictionary,
		atomic: Dictionary) -> void:
	var calls: Dictionary = atomic["route_calls"]
	plan_diagnostics["route_calls"]["normal"] += MapLayoutCanonical.int_value(
		calls["normal"]
	)
	plan_diagnostics["route_calls"]["bypass"] += MapLayoutCanonical.int_value(
		calls["bypass"]
	)
	plan_diagnostics["rejected_route_plans"].append_array(
		atomic["rejected_route_plans"]
	)
	for edge_id: String in MapLayoutCanonical.sorted_keys(atomic["chosen_sides"]):
		plan_diagnostics["chosen_bypass_sides"][edge_id] = atomic["chosen_sides"][edge_id]
	var owner: String = str(atomic["bypass_owner"])
	if not owner.is_empty():
		var component_id: String = str(atomic["component_diagnostics"]["component_id"])
		plan_diagnostics["selected_bypass_owners"][component_id] = owner


static func _accepted_prefix(routes: Dictionary) -> Dictionary:
	var route_digests: Dictionary = {}
	for edge_id: String in MapLayoutCanonical.sorted_keys(routes):
		route_digests[edge_id] = MapLayoutCanonical.digest(routes[edge_id])
	return {
		"edge_ids": MapLayoutCanonical.sorted_keys(routes),
		"route_digests": MapLayoutCanonical.ordered_dictionary(route_digests),
		"digest": MapLayoutCanonical.digest(route_digests),
	}


static func _component_plan_specs(component: Dictionary, plan: Dictionary,
		radius: float, quality: Dictionary) -> Array[Dictionary]:
	var no_obstacles: Array[Dictionary] = []
	var sides: Array[Dictionary] = _Routes._bypass_sides(
		component, plan, no_obstacles, radius, quality
	)
	var canonical_sides: Array[String] = []
	for side: Dictionary in sides:
		canonical_sides.append(str(side["id"]))
	var reversed_sides: Array[String] = canonical_sides.duplicate()
	reversed_sides.reverse()
	var canonical_edges: Array = component["edge_ids"].duplicate()
	var reversed_edges: Array = canonical_edges.duplicate()
	reversed_edges.reverse()
	return [
		{"plan_id": "canonical/current", "edge_order": canonical_edges,
			"side_order": canonical_sides, "reverse_side_order": false},
		{"plan_id": "canonical/reversed", "edge_order": canonical_edges,
			"side_order": reversed_sides, "reverse_side_order": true},
		{"plan_id": "reversed/current", "edge_order": reversed_edges,
			"side_order": canonical_sides, "reverse_side_order": false},
		{"plan_id": "reversed/reversed", "edge_order": reversed_edges,
			"side_order": reversed_sides, "reverse_side_order": true},
	]


static func _result(source: Dictionary, input: MapLayoutInput,
		anchors: Dictionary, routes: Dictionary, heroes: Dictionary,
		hard: Dictionary, soft: Dictionary, selected_id: String) -> MapLayoutResult:
	return MapLayoutResult.create({
		"schema_version": MapLayoutResult.SCHEMA_VERSION,
		"generator_version": source["generator_version"],
		"node_anchors": anchors,
		"edges": routes,
		"hero_placements": heroes,
		"scenery_instances": {},
		"hard_measurements": hard,
		"soft_scores": soft,
		"selected_restart_id": 0,
		"selected_candidate_id": selected_id,
		"input_digest": input.digest(),
	})

static func _substitution_children(binding: Dictionary, input: MapLayoutInput,
		node_sets: Dictionary, selection: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var node_ids: Array[String] = _binding_nodes(binding, input)
	var blocker_id: String = str(binding.get("node_id", ""))
	var priority_nodes: Dictionary = {}
	if not blocker_id.is_empty():
		priority_nodes[blocker_id] = true
	var details: Dictionary = binding.get("details", {})
	var priority_obstacles: Array = details.get(
		"priority_obstacle_ids", []
	).duplicate()
	priority_obstacles.append(details.get("blocking_obstacle_id", ""))
	for obstacle_id_v: Variant in priority_obstacles:
		var obstacle_id: String = str(obstacle_id_v)
		var blocker_entity: String = _Routes.obstacle_entity(obstacle_id)
		if obstacle_id.begins_with("node:"):
			priority_nodes[blocker_entity] = true
			continue
		for edge: Dictionary in input.edge_records():
			if str(edge["id"]) == blocker_entity:
				priority_nodes[str(edge["from"])] = true
				priority_nodes[str(edge["to"])] = true
				break
	if node_ids.size() == 2:
		var a_id: String = node_ids[0]
		var b_id: String = node_ids[1]
		var a_candidates: Array = node_sets[a_id]["candidates"]
		var b_candidates: Array = node_sets[b_id]["candidates"]
		var a_current: int = MapLayoutCanonical.int_value(selection[a_id])
		var b_current: int = MapLayoutCanonical.int_value(selection[b_id])
		for a_index: int in range(a_candidates.size()):
			for b_index: int in range(b_candidates.size()):
				if a_index == a_current and b_index == b_current:
					continue
				var changed: Dictionary = selection.duplicate(true)
				changed[a_id] = a_index
				changed[b_id] = b_index
				out.append({
					"selection": changed,
					"priority": _selection_distance(changed, node_sets, node_ids),
					"substitution": {
						"node_ids": node_ids,
						"from_candidate_ids": [a_candidates[a_current]["id"], b_candidates[b_current]["id"]],
						"to_candidate_ids": [a_candidates[a_index]["id"], b_candidates[b_index]["id"]],
						"binding": binding,
					},
				})
	else:
		for node_id: String in node_ids:
			var candidates: Array = node_sets[node_id]["candidates"]
			var current: int = MapLayoutCanonical.int_value(selection[node_id])
			for candidate_index: int in range(candidates.size()):
				if candidate_index == current:
					continue
				var changed: Dictionary = selection.duplicate(true)
				changed[node_id] = candidate_index
				out.append({
					"selection": changed,
					"priority": 1.0 if priority_nodes.has(node_id) else 0.0,
					"substitution": {
						"node_ids": [node_id],
						"from_candidate_ids": [candidates[current]["id"]],
						"to_candidate_ids": [candidates[candidate_index]["id"]],
						"binding": binding,
					},
				})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_priority: float = MapLayoutCanonical.float_value(a["priority"])
		var b_priority: float = MapLayoutCanonical.float_value(b["priority"])
		if not is_equal_approx(a_priority, b_priority):
			return a_priority < b_priority
		return MapLayoutCanonical.canonical_text(a["substitution"]) \
			> MapLayoutCanonical.canonical_text(b["substitution"])
	)
	return out


static func _selection_distance(selection: Dictionary, node_sets: Dictionary,
		local_nodes: Array) -> float:
	if local_nodes.size() != 2:
		return 0.0
	var points: Array[Vector2] = []
	for node_id_v: Variant in local_nodes:
		var node_id: String = str(node_id_v)
		var candidates: Array = node_sets[node_id]["candidates"]
		var candidate: Dictionary = candidates[
			MapLayoutCanonical.int_value(selection[node_id])
		]
		var anchor: Array = candidate["anchor"]
		points.append(Vector2(
			MapLayoutCanonical.float_value(anchor[0]),
			MapLayoutCanonical.float_value(anchor[2])
		))
	return points[0].distance_to(points[1])


static func _binding_nodes(binding: Dictionary,
		input: MapLayoutInput) -> Array[String]:
	var nodes: Dictionary = {}
	for node: Dictionary in input.node_records():
		nodes[str(node["id"])] = true
	var edges: Dictionary = {}
	for edge: Dictionary in input.edge_records():
		edges[str(edge["id"])] = edge
	var affected: Dictionary = {}
	var entities: Array = binding.get(
		"details", {}
	).get("local_node_ids", []).duplicate()
	entities.append_array(binding.get("details", {}).get("entities", []))
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


static func _missing_mechanism(binding: Dictionary) -> Dictionary:
	var out: Dictionary = binding.duplicate(true)
	out["kind"] = "missing_mechanism"
	out["reason"] = "named binding has no remaining #467 local substitution"
	out["details"] = {
		"binding": binding,
		"required": "a governed candidate or routing mechanism",
	}
	return out


static func _bound_exhausted(binding: Dictionary) -> Dictionary:
	var out: Dictionary = binding.duplicate(true)
	out["kind"] = "search_bound"
	out["reason"] = "%d canonical local substitutions exhausted" \
		% MAX_LOCAL_SUBSTITUTIONS
	out["details"] = {
		"binding": binding,
		"max_local_substitutions": MAX_LOCAL_SUBSTITUTIONS,
	}
	return out


static func _quality_binding(report: Dictionary, input: MapLayoutInput) -> Dictionary:
	var violations: Array = report.get("violations", []).duplicate(true)
	var hard_values: Dictionary = report.get("hard_values", {})
	violations.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_metric: String = str(a.get("metric_id", ""))
		var b_metric: String = str(b.get("metric_id", ""))
		if a_metric != b_metric:
			return a_metric < b_metric
		var aggregate: float = MapLayoutCanonical.float_value(
			hard_values.get(a_metric, 0.0)
		)
		var a_delta: float = absf(
			MapLayoutCanonical.float_value(a.get("value", 0.0)) - aggregate
		)
		var b_delta: float = absf(
			MapLayoutCanonical.float_value(b.get("value", 0.0)) - aggregate
		)
		if not is_equal_approx(a_delta, b_delta):
			return a_delta < b_delta
		return MapLayoutCanonical.canonical_text(a) < MapLayoutCanonical.canonical_text(b)
	)
	if violations.is_empty():
		return _binding("quality_violation", "unknown",
			"hard evaluation failed without a named violation")
	var violation: Dictionary = violations[0].duplicate(true)
	var edge_ids: Dictionary = {}
	for edge: Dictionary in input.edge_records():
		edge_ids[str(edge["id"])] = true
	var node_ids: Dictionary = {}
	for node: Dictionary in input.node_records():
		node_ids[str(node["id"])] = true
	var node_id: String = ""
	var edge_id: String = ""
	var local_node_ids: Array[String] = []
	for entity_v: Variant in violation.get("entities", []):
		var entity: String = str(entity_v)
		if node_id.is_empty() and node_ids.has(entity):
			node_id = entity
		if node_ids.has(entity):
			local_node_ids.append(entity)
		if edge_id.is_empty() and edge_ids.has(entity):
			edge_id = entity
	if not local_node_ids.is_empty():
		local_node_ids.sort()
		violation["local_node_ids"] = local_node_ids
	return {
		"kind": "quality_violation",
		"id": str(violation.get("metric_id", "")),
		"node_id": node_id,
		"edge_id": edge_id,
		"profile_id": str(violation.get("profile_id", "")),
		"reason": "complete #466 evaluation failed",
		"details": violation,
	}


static func _attempt_failure(chosen: Dictionary, routes: Array,
		binding: Dictionary, plan: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"binding": binding,
		"chosen_candidate_ids": chosen,
		"diagnostics": _attempt_diagnostics(chosen, routes, plan, binding),
	}


static func _attempt_diagnostics(chosen: Dictionary, routes: Array,
		plan: Dictionary, binding: Dictionary = {}) -> Dictionary:
	var out: Dictionary = plan.duplicate(true)
	out["chosen_candidate_ids"] = chosen
	out["routes"] = routes
	out["first_binding_violation"] = binding
	return out


static func _hero_error(anchor_id: String, field: String,
		reason: String) -> Dictionary:
	return {"ok": false, "binding": {
		"kind": "hero_anchor",
		"id": "%s.%s" % [anchor_id, field],
		"node_id": "",
		"edge_id": "",
		"profile_id": "",
		"reason": "hero_anchor_contract.anchors.%s.%s %s" % [
			anchor_id, field, reason,
		],
		"details": {},
	}}


static func _digest_binding(id: String, expected: String,
		actual: String) -> Dictionary:
	return {
		"kind": "authority_digest",
		"id": id,
		"node_id": "",
		"edge_id": "",
		"profile_id": "",
		"reason": "%s mismatch" % id,
		"details": {"expected": expected, "actual": actual},
	}


static func _binding(kind: String, id: String, reason: String,
		node_id: String = "") -> Dictionary:
	return {
		"kind": kind,
		"id": id,
		"node_id": node_id,
		"edge_id": "",
		"profile_id": "",
		"reason": reason,
		"details": {},
	}


static func _success(diagnostics: Dictionary, result: MapLayoutResult,
		report: Dictionary) -> Dictionary:
	return {
		"status": COMPILED,
		"result": result,
		"report": report,
		"failure": {},
		"diagnostics": _finish_diagnostics(diagnostics),
	}


static func _failure(diagnostics: Dictionary, binding: Dictionary) -> Dictionary:
	return {
		"status": NO_FEASIBLE_NODE_ROUTE_LAYOUT,
		"result": null,
		"report": {},
		"failure": MapLayoutCanonical.ordered_dictionary(binding),
		"diagnostics": _finish_diagnostics(diagnostics),
	}


static func _finish_diagnostics(diagnostics: Dictionary) -> Dictionary:
	var out: Dictionary = MapLayoutCanonical.ordered_dictionary(diagnostics)
	out["diagnostics_digest"] = MapLayoutCanonical.digest(out)
	return MapLayoutCanonical.ordered_dictionary(out)
