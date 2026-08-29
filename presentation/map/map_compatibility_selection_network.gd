class_name MapCompatibilitySelectionNetwork
extends RefCounted
## Canonical component/domain index for exact #466 unary/pair receipts.

const WORK_MULTIPLIER: int = 64
const MAX_MATERIALISATIONS: int = 65

@warning_ignore_start("unsafe_call_argument")


static func build(node_sets: Dictionary, constraints: Dictionary) -> Dictionary:
	var node_order: Array[String] = MapLayoutCanonical.sorted_keys(node_sets)
	var candidate_ids: Dictionary = {}
	var candidate_indices: Dictionary = {}
	var unary: Dictionary = {}
	var pairs: Dictionary = {}
	var incident: Dictionary = {}
	var adjacency: Dictionary = {}
	for node_id: String in node_order:
		candidate_ids[node_id] = []
		candidate_indices[node_id] = {}
		incident[node_id] = []
		adjacency[node_id] = {}
		var candidates: Array = node_sets[node_id].get("candidates", [])
		for index: int in range(candidates.size()):
			var candidate: Dictionary = candidates[index]
			var candidate_id: String = str(candidate.get("id", ""))
			if candidate_id.is_empty() or candidate_indices[node_id].has(candidate_id):
				return _failure("candidate IDs must be non-empty and unique")
			candidate_ids[node_id].append(candidate_id)
			candidate_indices[node_id][candidate_id] = index
	for constraint_id: String in MapLayoutCanonical.sorted_keys(constraints):
		var constraint: Dictionary = constraints[constraint_id]
		var local_nodes: Array = constraint.get("node_ids", [])
		if local_nodes.size() == 1:
			var node_id: String = str(local_nodes[0])
			if not node_sets.has(node_id) or unary.has(node_id):
				return _failure("each active node requires one unary constraint")
			unary[node_id] = constraint_id
		elif local_nodes.size() == 2:
			var first: String = str(local_nodes[0])
			var second: String = str(local_nodes[1])
			if first == second or not node_sets.has(first) or not node_sets.has(second):
				return _failure("pair constraint references invalid active nodes")
			pairs[constraint_id] = constraint
			incident[first].append(constraint_id)
			incident[second].append(constraint_id)
			adjacency[first][second] = true
			adjacency[second][first] = true
		else:
			return _failure("compatibility constraints must be unary or binary")
	var domains: Dictionary = {}
	for node_id: String in node_order:
		if not unary.has(node_id):
			return _failure("each active node requires one unary constraint")
		incident[node_id].sort()
		domains[node_id] = _domain(node_id, node_sets, constraints,
			unary, candidate_ids)
	var components: Array[Array] = _components(node_order, adjacency)
	var node_components: Dictionary = {}
	for component_index: int in range(components.size()):
		for node_id_v: Variant in components[component_index]:
			node_components[str(node_id_v)] = component_index
	var active_rows: int = 0
	for domain_v: Variant in domains.values():
		var domain: Array = domain_v
		active_rows += domain.size()
	var allowed_pair_rows: int = 0
	for pair: Dictionary in pairs.values():
		allowed_pair_rows += pair.get("allowed_candidate_ids", {}).size()
	if active_rows == 0 or components.is_empty():
		return _failure("compatibility network has an empty active domain")
	return {"ok": true, "reason": "", "node_order": node_order,
		"candidate_ids": candidate_ids, "candidate_indices": candidate_indices,
		"initial_domains": domains, "pair_constraints": pairs,
		"incident": incident,
		"components": components, "node_components": node_components,
		"totals": MapLayoutCanonical.ordered_dictionary({
			"active_nodes": node_order.size(),
			"active_components": components.size(),
			"total_active_candidate_rows": active_rows,
			"total_allowed_pair_rows": allowed_pair_rows}),
		"limits": MapLayoutCanonical.ordered_dictionary({
			"assignment_decisions": WORK_MULTIPLIER * active_rows,
			"compatibility_lookups": WORK_MULTIPLIER * maxi(
				1, allowed_pair_rows),
			"domain_value_removals": WORK_MULTIPLIER * active_rows,
			"complete_selection_materialisations": MAX_MATERIALISATIONS,
			"route_attempts": MAX_MATERIALISATIONS})}


static func _domain(node_id: String, node_sets: Dictionary,
		constraints: Dictionary, unary: Dictionary,
		candidate_ids: Dictionary) -> Array[int]:
	var constraint: Dictionary = constraints[str(unary[node_id])]
	var allowed: Dictionary = constraint.get("allowed_candidate_ids", {})
	var out: Array[int] = []
	var ids: Array = candidate_ids[node_id]
	for index: int in range(ids.size()):
		if allowed.has(MapLayoutCanonical.canonical_text([str(ids[index])])):
			out.append(index)
	out.sort_custom(func(a: int, b: int) -> bool:
		return _candidate_before(node_id, a, b, node_sets, constraint, ids))
	return out


static func _candidate_before(node_id: String, a: int, b: int,
		node_sets: Dictionary, constraint: Dictionary, ids: Array) -> bool:
	var ranked: Dictionary = constraint.get("ranked_combinations", {})
	var a_id: String = str(ids[a])
	var b_id: String = str(ids[b])
	var a_row: Dictionary = ranked.get(
		MapLayoutCanonical.canonical_text([a_id]), {})
	var b_row: Dictionary = ranked.get(
		MapLayoutCanonical.canonical_text([b_id]), {})
	var a_margin: float = MapLayoutCanonical.float_value(
		a_row.get("weakest_signed_hard_margin", -INF))
	var b_margin: float = MapLayoutCanonical.float_value(
		b_row.get("weakest_signed_hard_margin", -INF))
	if a_margin != b_margin:
		return a_margin > b_margin
	var candidates: Array = node_sets[node_id].get("candidates", [])
	var a_cost: float = MapLayoutCanonical.float_value(
		candidates[a].get("displacement_cost_m2", INF))
	var b_cost: float = MapLayoutCanonical.float_value(
		candidates[b].get("displacement_cost_m2", INF))
	if a_cost != b_cost:
		return a_cost < b_cost
	return a_id < b_id


static func _components(node_order: Array[String],
		adjacency: Dictionary) -> Array[Array]:
	var remaining: Dictionary = {}
	for node_id: String in node_order:
		remaining[node_id] = true
	var out: Array[Array] = []
	while not remaining.is_empty():
		var root: String = MapLayoutCanonical.sorted_keys(remaining)[0]
		var pending: Array[String] = [root]
		var component: Array[String] = []
		remaining.erase(root)
		while not pending.is_empty():
			var node_id: String = pending.pop_front()
			component.append(node_id)
			for neighbour: String in MapLayoutCanonical.sorted_keys(
					adjacency[node_id]):
				if remaining.has(neighbour):
					remaining.erase(neighbour)
					pending.append(neighbour)
			pending.sort()
		component.sort()
		out.append(component)
	out.sort_custom(func(a: Array, b: Array) -> bool:
		return MapLayoutCanonical.canonical_text(a) \
			< MapLayoutCanonical.canonical_text(b))
	return out


static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
