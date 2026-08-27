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
		"rejected_route_plans": [],
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
			"route_calls", "chosen_bypass_sides", "rejected_route_plans",
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
		MapQualityEvaluator.camera_registry(input.node_records(), quality)["digest"]
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
	var half_width: float = MapLayoutCanonical.float_value(
		quality["geometry"]["road_corridor"]["physical_half_width_m"]
	)
	var safety: float = MapLayoutCanonical.float_value(
		quality["geometry"]["road_corridor"]["world_clearance_m"]
	)
	for edge: Dictionary in route_order:
		var edge_id: String = str(edge["id"])
		var channel: PackedVector2Array = _Routes.route_channel(
			edge, plan, (half_width + safety) * 2.0
		)
		var obstacles_report: Dictionary = _Routes.route_obstacles(
			edge, plan, heroes, routes, source, assets, channel
		)
		if obstacles_report.get("ok", false) != true:
			return _attempt_failure(chosen_ids, route_rows,
				obstacles_report.get("binding", {}), plan_diagnostics)
		var routed: Dictionary = _Routes.route_planned(
			edge, plan, obstacles_report["obstacles"], half_width, safety,
			quality, channel, bypass_usage
		)
		var route_plan_diagnostics: Dictionary = routed.get("plan_diagnostics", {})
		plan_diagnostics["route_calls"]["normal"] += MapLayoutCanonical.int_value(
			route_plan_diagnostics.get("normal_calls", 0)
		)
		plan_diagnostics["route_calls"]["bypass"] += MapLayoutCanonical.int_value(
			route_plan_diagnostics.get("bypass_calls", 0)
		)
		var side: String = str(route_plan_diagnostics.get("chosen_bypass_side", ""))
		if not side.is_empty():
			plan_diagnostics["chosen_bypass_sides"][edge_id] = side
		plan_diagnostics["rejected_route_plans"].append_array(
			route_plan_diagnostics.get("rejected_plans", [])
		)
		route_rows.append({
			"edge_id": edge_id,
			"route_digest": routed.get("digest", ""),
			"status": routed.get("status", ""),
			"obstacle_ids": obstacles_report["obstacle_ids"],
			"plan": route_plan_diagnostics,
		})
		if str(routed.get("status", "")) != MapSingleEdgeRouter.ROUTED:
			var blocked: Dictionary = route_plan_diagnostics.get("first_blocker", {})
			var blocker: String = str(blocked.get("obstacle_id", ""))
			var blocker_node: String = blocker.trim_prefix("node:") \
				if blocker.begins_with("node:") else ""
			var route_details: Dictionary = routed.get("diagnostics", {}).duplicate(true)
			route_details["blocking_obstacle_id"] = blocker
			route_details["local_node_ids"] = blocked.get("local_node_ids", [])
			route_details["route_plan"] = route_plan_diagnostics
			route_details["terminal"] = route_plan_diagnostics.get("terminal", false)
			var entities: Array = [edge_id]
			var blocker_entity: String = _Routes.obstacle_entity(blocker)
			if not blocker_entity.is_empty():
				entities.append(blocker_entity)
			route_details["entities"] = entities
			return _attempt_failure(chosen_ids, route_rows, {
				"kind": "edge_route",
				"id": edge_id,
				"node_id": blocker_node,
				"edge_id": edge_id,
				"profile_id": "world",
				"reason": str(routed.get("reason", "route failed")),
				"details": route_details,
			}, plan_diagnostics)
		routes[edge_id] = {
			"from": edge["from"],
			"to": edge["to"],
			"centerline": routed["centerline"],
			"corridor_width": routed["corridor_width"],
		}
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
					"priority": 0.0,
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
	violations.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
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
