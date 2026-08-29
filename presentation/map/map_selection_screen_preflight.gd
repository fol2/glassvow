class_name MapSelectionScreenPreflight
extends RefCounted
## Bounded unary/pair #466 compatibility index for #469 deferred routing.

const VERSION: String = "map-selection-screen-preflight-v1"
const REFINEMENT_VERSION: String = "map-selection-screen-refinement-preflight-v1"
const DELETION_CERTIFICATE_VERSION: String = \
	"map-selection-screen-deletion-certificate-v1"


static func build(input: MapLayoutInput, node_sets: Dictionary,
		heroes: Dictionary, assets: Dictionary, quality: Dictionary,
		candidate_digest: String) -> Dictionary:
	var nodes: Array = input.node_records()
	var edges: Array = input.edge_records()
	var context: Dictionary = MapQualityEvaluator.selection_screen_context(
		nodes, edges, heroes, assets, quality)
	var receipts: Array[Dictionary] = []
	for node_id: String in MapLayoutCanonical.sorted_keys(node_sets):
		receipts.append(_receipt([node_id], nodes, edges, node_sets, heroes,
			assets, quality, context))
	for pair: Array in MapQualityEvaluator.selection_screen_local_pairs(
			node_sets, quality, context):
		var node_ids: Array[String] = []
		node_ids.assign(pair)
		receipts.append(_receipt(node_ids, nodes, edges, node_sets, heroes,
			assets, quality, context))
	receipts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["id"]) < str(b["id"]))
	var domains: Dictionary = _unary_domains(node_sets, receipts)
	var fixed: Dictionary = _fixed_point(domains, receipts)
	var fixed_domains: Dictionary = fixed["domains"]
	var receipt: Dictionary = MapLayoutCanonical.ordered_dictionary({
		"version": VERSION,
		"candidate_digest": candidate_digest,
		"receipts": receipts,
		"fixed_point_domains": _domain_rows(node_sets, fixed_domains),
		"fixed_point_iterations": fixed["iterations"],
	})
	receipt["receipt_digest"] = MapLayoutCanonical.digest(receipt)
	var empty_nodes: Array[String] = []
	for node_id: String in MapLayoutCanonical.sorted_keys(fixed_domains):
		var fixed_domain: Dictionary = fixed_domains[node_id]
		if fixed_domain.is_empty():
			empty_nodes.append(node_id)
	if not empty_nodes.is_empty():
		var deletion_certificate: Dictionary = fixed["deletion_certificate"]
		return {"ok": false, "receipt": receipt, "constraints": {},
			"deletion_certificate": deletion_certificate,
			"binding": _failure("domain_empty", empty_nodes, receipt,
				deletion_certificate)}
	return {"ok": true, "receipt": receipt,
		"constraints": _constraints(receipts, fixed_domains),
		"deletion_certificate": {}, "binding": {}}


static func build_refined(input: MapLayoutInput, node_sets: Dictionary,
		heroes: Dictionary, assets: Dictionary, quality: Dictionary,
		base_receipt: Dictionary, candidate_refinement: Dictionary) -> Dictionary:
	var refined_ids: Array[String] = []
	var refined_ids_v: Array = candidate_refinement.get("refinement_node_ids", [])
	refined_ids.assign(refined_ids_v)
	var base_rows: Dictionary = {}
	for receipt_v: Variant in base_receipt.get("receipts", []):
		var receipt: Dictionary = receipt_v
		base_rows[str(receipt["id"])] = receipt
	var nodes: Array = input.node_records()
	var edges: Array = input.edge_records()
	var context: Dictionary = MapQualityEvaluator.selection_screen_context(
		nodes, edges, heroes, assets, quality)
	var receipts: Array[Dictionary] = []
	var recomputed: Array[String] = []
	var reused: Array[String] = []
	for node_id: String in MapLayoutCanonical.sorted_keys(node_sets):
		var receipt_id: String = "1/%s" % node_id
		if node_id in refined_ids:
			receipts.append(_receipt([node_id], nodes, edges, node_sets,
				heroes, assets, quality, context))
			recomputed.append(receipt_id)
		elif base_rows.has(receipt_id):
			receipts.append(base_rows[receipt_id])
			reused.append(receipt_id)
		else:
			return _refinement_failure("base_receipt_missing", receipt_id)
	for pair: Array in MapQualityEvaluator.selection_screen_local_pairs(
			node_sets, quality, context):
		var node_ids: Array[String] = []
		node_ids.assign(pair)
		var receipt_id: String = "2/%s" % "+".join(node_ids)
		if node_ids[0] in refined_ids or node_ids[1] in refined_ids:
			receipts.append(_receipt(node_ids, nodes, edges, node_sets,
				heroes, assets, quality, context))
			recomputed.append(receipt_id)
		elif base_rows.has(receipt_id):
			receipts.append(base_rows[receipt_id])
			reused.append(receipt_id)
		else:
			return _refinement_failure("base_receipt_missing", receipt_id)
	receipts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["id"]) < str(b["id"]))
	var domains: Dictionary = _unary_domains(node_sets, receipts)
	var fixed: Dictionary = _fixed_point(domains, receipts)
	var fixed_domains: Dictionary = fixed["domains"]
	var receipt: Dictionary = MapLayoutCanonical.ordered_dictionary({
		"version": REFINEMENT_VERSION,
		"base_preflight_receipt_digest": base_receipt.get("receipt_digest", ""),
		"candidate_refinement_digest": candidate_refinement.get(
			"refinement_digest", ""),
		"refinement_node_ids": refined_ids,
		"recomputed_receipt_ids": recomputed,
		"reused_receipt_ids": reused,
		"receipts": receipts,
		"fixed_point_domains": _domain_rows(node_sets, fixed_domains),
		"fixed_point_iterations": fixed["iterations"],
	})
	receipt["receipt_digest"] = MapLayoutCanonical.digest(receipt)
	var empty_nodes: Array[String] = []
	for node_id: String in MapLayoutCanonical.sorted_keys(fixed_domains):
		var fixed_domain: Dictionary = fixed_domains[node_id]
		if fixed_domain.is_empty():
			empty_nodes.append(node_id)
	if not empty_nodes.is_empty():
		var deletion_certificate: Dictionary = fixed["deletion_certificate"]
		return {"ok": false, "receipt": receipt, "constraints": {},
			"deletion_certificate": deletion_certificate,
			"binding": _failure("domain_empty", empty_nodes, receipt,
				deletion_certificate)}
	return {"ok": true, "receipt": receipt,
		"constraints": _constraints(receipts, fixed_domains),
		"deletion_certificate": {}, "binding": {}}


static func _receipt(node_ids: Array[String], nodes: Array, edges: Array,
		node_sets: Dictionary, heroes: Dictionary, assets: Dictionary,
		quality: Dictionary, context: Dictionary) -> Dictionary:
	var index_rows: Array[Array] = []
	var first: Array = node_sets[node_ids[0]]["candidates"]
	if node_ids.size() == 1:
		for first_index: int in range(first.size()):
			index_rows.append([first_index])
	else:
		var second: Array = node_sets[node_ids[1]]["candidates"]
		for first_index: int in range(first.size()):
			for second_index: int in range(second.size()):
				index_rows.append([first_index, second_index])
	var combinations: Array[Dictionary] = []
	for indices: Array in index_rows:
		var candidate_ids: Array[String] = []
		var anchors: Dictionary = {}
		var candidate_cost: float = 0.0
		for local_index: int in range(node_ids.size()):
			var node_id: String = node_ids[local_index]
			var candidate: Dictionary = node_sets[node_id]["candidates"][
				MapLayoutCanonical.int_value(indices[local_index])]
			candidate_ids.append(str(candidate["id"]))
			anchors[node_id] = candidate["anchor"]
			candidate_cost += MapLayoutCanonical.float_value(
				candidate["displacement_cost_m2"])
		var checked: Dictionary = MapQualityEvaluator.selection_screen_feasibility(
			nodes, edges, anchors, heroes, assets, quality, node_ids, context)
		combinations.append(MapLayoutCanonical.ordered_dictionary({
			"candidate_ids": candidate_ids,
			"hard_pass": checked.get("hard_pass", false),
			"hard_values": checked.get("hard_values", {}),
			"hard_margins": checked.get("hard_margins", {}),
			"priority_metric_ids": checked.get("priority_metric_ids", []),
			"weakest_signed_hard_margin": checked.get(
				"weakest_signed_hard_margin", -INF),
			"candidate_cost_m2": candidate_cost,
			"rejection_reason": checked.get("rejection_reason", {}),
		}))
	var survivors: Array[Dictionary] = []
	for combination: Dictionary in combinations:
		if combination.get("hard_pass", false) == true:
			survivors.append(combination)
	survivors.sort_custom(_stronger)
	var order: Array = []
	for survivor: Dictionary in survivors:
		order.append(survivor["candidate_ids"])
	var id: String = "%d/%s" % [node_ids.size(), "+".join(node_ids)]
	var receipt: Dictionary = MapLayoutCanonical.ordered_dictionary({
		"id": id,
		"binding": {
			"kind": "selection_screen_preflight",
			"id": id,
			"details": {"local_node_ids": node_ids},
		},
		"local_node_ids": node_ids,
		"combinations": combinations,
		"surviving_order": order,
	})
	receipt["receipt_digest"] = MapLayoutCanonical.digest(receipt)
	return MapLayoutCanonical.ordered_dictionary(receipt)


static func _stronger(a: Dictionary, b: Dictionary) -> bool:
	var a_margin: float = MapLayoutCanonical.float_value(
		a["weakest_signed_hard_margin"])
	var b_margin: float = MapLayoutCanonical.float_value(
		b["weakest_signed_hard_margin"])
	if a_margin != b_margin:
		return a_margin > b_margin
	var a_cost: float = MapLayoutCanonical.float_value(a["candidate_cost_m2"])
	var b_cost: float = MapLayoutCanonical.float_value(b["candidate_cost_m2"])
	if a_cost != b_cost:
		return a_cost < b_cost
	return MapLayoutCanonical.canonical_text(a["candidate_ids"]) \
		< MapLayoutCanonical.canonical_text(b["candidate_ids"])


static func _unary_domains(node_sets: Dictionary,
		receipts: Array[Dictionary]) -> Dictionary:
	var by_id: Dictionary = {}
	for receipt: Dictionary in receipts:
		if receipt["local_node_ids"].size() == 1:
			by_id[str(receipt["local_node_ids"][0])] = receipt
	var domains: Dictionary = {}
	for node_id: String in MapLayoutCanonical.sorted_keys(node_sets):
		var allowed: Dictionary = {}
		for combination: Dictionary in by_id[node_id]["combinations"]:
			if combination.get("hard_pass", false) == true:
				allowed[str(combination["candidate_ids"][0])] = true
		domains[node_id] = allowed
	return domains


static func _fixed_point(domains: Dictionary,
		receipts: Array[Dictionary]) -> Dictionary:
	var current: Dictionary = domains.duplicate(true)
	var iterations: int = 0
	var deletion_causes: Dictionary = {}
	var deletion_certificate: Dictionary = {}
	while true:
		var remove: Dictionary = {}
		var causes: Dictionary = {}
		for receipt: Dictionary in receipts:
			var node_ids: Array = receipt["local_node_ids"]
			if node_ids.size() != 2:
				continue
			for side: int in range(2):
				var node_id: String = str(node_ids[side])
				var other_id: String = str(node_ids[1 - side])
				var node_domain: Dictionary = current[node_id]
				var other_domain: Dictionary = current[other_id]
				for candidate_id: String in MapLayoutCanonical.sorted_keys(
						node_domain):
					var supported: bool = false
					for combination: Dictionary in receipt["combinations"]:
						var ids: Array = combination["candidate_ids"]
						if combination.get("hard_pass", false) == true \
								and str(ids[side]) == candidate_id \
								and other_domain.has(str(ids[1 - side])):
							supported = true
							break
					if not supported:
						if not remove.has(node_id):
							remove[node_id] = {}
						remove[node_id][candidate_id] = true
						var node_causes: Dictionary = causes.get(node_id, {})
						var candidate_causes: Dictionary = node_causes.get(
							candidate_id, {})
						candidate_causes[str(receipt["id"])] = true
						node_causes[candidate_id] = candidate_causes
						causes[node_id] = node_causes
		if remove.is_empty():
			break
		iterations += 1
		var newly_empty: Array[String] = []
		for node_id: String in MapLayoutCanonical.sorted_keys(remove):
			var node_remove: Dictionary = remove[node_id]
			var node_domain: Dictionary = current[node_id]
			var node_history: Dictionary = deletion_causes.get(node_id, {})
			for candidate_id: String in MapLayoutCanonical.sorted_keys(
					node_remove):
				node_history[candidate_id] = causes[node_id][candidate_id]
				node_domain.erase(candidate_id)
			deletion_causes[node_id] = node_history
			if node_domain.is_empty():
				newly_empty.append(node_id)
		if deletion_certificate.is_empty() and not newly_empty.is_empty():
			deletion_certificate = _deletion_certificate(
				newly_empty, deletion_causes, receipts, iterations)
	return {"domains": current, "iterations": iterations,
		"deletion_certificate": deletion_certificate}


static func _deletion_certificate(first_empty: Array[String],
		deletion_causes: Dictionary, receipts: Array[Dictionary],
		iteration: int) -> Dictionary:
	var receipt_ids: Dictionary = {}
	var deletions: Array[Dictionary] = []
	for node_id: String in first_empty:
		var node_causes: Dictionary = deletion_causes[node_id]
		var candidate_rows: Array[Dictionary] = []
		for candidate_id: String in MapLayoutCanonical.sorted_keys(node_causes):
			var candidate_causes: Dictionary = node_causes[candidate_id]
			var cause_ids: Array[String] = MapLayoutCanonical.sorted_keys(
				candidate_causes)
			candidate_rows.append({"candidate_id": candidate_id,
				"receipt_ids": cause_ids})
			for receipt_id: String in cause_ids:
				receipt_ids[receipt_id] = true
		deletions.append({"node_id": node_id,
			"candidate_deletions": candidate_rows})
	var receipt_rows: Array[Dictionary] = []
	var refinement_nodes: Dictionary = {}
	for node_id: String in first_empty:
		refinement_nodes[node_id] = true
	for receipt_id: String in MapLayoutCanonical.sorted_keys(receipt_ids):
		for receipt: Dictionary in receipts:
			if str(receipt["id"]) != receipt_id:
				continue
			var local_node_ids: Array = receipt["local_node_ids"]
			receipt_rows.append({"id": receipt_id,
				"local_node_ids": local_node_ids,
				"receipt_digest": receipt["receipt_digest"]})
			for node_id_v: Variant in local_node_ids:
				refinement_nodes[str(node_id_v)] = true
			break
	var certificate: Dictionary = MapLayoutCanonical.ordered_dictionary({
		"version": DELETION_CERTIFICATE_VERSION,
		"first_empty_iteration": iteration,
		"first_empty_node_ids": first_empty,
		"candidate_deletions": deletions,
		"pair_receipts": receipt_rows,
		"refinement_node_ids": MapLayoutCanonical.sorted_keys(refinement_nodes),
	})
	certificate["certificate_digest"] = MapLayoutCanonical.digest(certificate)
	return MapLayoutCanonical.ordered_dictionary(certificate)


static func _domain_rows(node_sets: Dictionary, domains: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for node_id: String in MapLayoutCanonical.sorted_keys(node_sets):
		var ids: Array[String] = []
		for candidate_v: Variant in node_sets[node_id]["candidates"]:
			var candidate: Dictionary = candidate_v
			if domains[node_id].has(str(candidate["id"])):
				ids.append(str(candidate["id"]))
		out[node_id] = ids
	return MapLayoutCanonical.ordered_dictionary(out)


static func _constraints(receipts: Array[Dictionary],
		domains: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for receipt: Dictionary in receipts:
		var node_ids: Array = receipt["local_node_ids"]
		var allowed: Dictionary = {}
		var ranked: Dictionary = {}
		for combination: Dictionary in receipt["combinations"]:
			var ids: Array = combination["candidate_ids"]
			var key: String = MapLayoutCanonical.canonical_text(ids)
			ranked[key] = combination
			var retained: bool = combination.get("hard_pass", false) == true
			for index: int in range(node_ids.size()):
				retained = retained and domains[str(node_ids[index])].has(str(ids[index]))
			if retained:
				allowed[key] = true
		var order: Array = []
		for ids_v: Variant in receipt["surviving_order"]:
			var ids: Array = ids_v
			if allowed.has(MapLayoutCanonical.canonical_text(ids)):
				order.append(ids)
		out[receipt["id"]] = {
			"id": receipt["id"],
			"binding": receipt["binding"],
			"node_ids": node_ids,
			"allowed_candidate_ids": allowed,
			"ranked_combinations": ranked,
			"surviving_order": order,
		}
	return MapLayoutCanonical.ordered_dictionary(out)


static func _failure(id: String, node_ids: Array[String], receipt: Dictionary,
		deletion_certificate: Dictionary = {}) -> Dictionary:
	var details: Dictionary = {"local_node_ids": node_ids,
		"preflight_receipt": receipt, "terminal": true}
	if not deletion_certificate.is_empty():
		details["deletion_certificate"] = deletion_certificate
	return {
		"kind": "selection_screen_preflight",
		"id": id,
		"node_id": node_ids[0] if not node_ids.is_empty() else "",
		"edge_id": "",
		"profile_id": "selection",
		"reason": "selection-only screen compatibility has an empty candidate domain",
		"details": details,
	}


static func _refinement_failure(id: String, receipt_id: String) -> Dictionary:
	return {"ok": false, "receipt": {}, "constraints": {},
		"deletion_certificate": {}, "binding": {
			"kind": "selection_screen_preflight", "id": id,
			"node_id": "", "edge_id": "", "profile_id": "selection",
			"reason": "refined preflight cannot reuse an unaffected base receipt",
			"details": {"receipt_id": receipt_id, "terminal": true},
		}}
