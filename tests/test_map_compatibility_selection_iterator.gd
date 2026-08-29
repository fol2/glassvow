extends RefCounted
## Focused boundedness proof for #469 compatibility selection.

const Iterator = preload(
	"res://presentation/map/map_compatibility_selection_iterator.gd")
const Preflight = preload(
	"res://presentation/map/map_selection_screen_preflight.gd")

@warning_ignore_start("unsafe_call_argument")


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_compatibility_selection_iterator: %s" % what)


static func run(fails: Array[String]) -> void:
	_test_components_nogoods_and_replay(fails)
	_test_exact_priority_order(fails)
	_test_lookup_exhaustion(fails)
	_test_materialisation_exhaustion(fails)
	_test_no_compatible_assignment(fails)


static func _test_components_nogoods_and_replay(fails: Array[String]) -> void:
	var fixture: Dictionary = _component_fixture(false)
	var iterator: RefCounted = Iterator.new(
		fixture["node_sets"], fixture["constraints"], {"network": "synthetic"})
	var first: Dictionary = iterator.next_assignment()
	var first_ids: Dictionary = first.get("candidate_ids", {})
	_check(fails, first.get("status", "") == Iterator.ASSIGNMENT
			and first_ids == {"A": "a0", "B": "b0", "C": "c0", "D": "d0"}
			and _assignment_is_compatible(first_ids, fixture["constraints"]),
		"the first lazy assignment solves both components directly")
	var cross_nogood: Dictionary = iterator.add_nogood(
		["A", "C"], first_ids)
	var second: Dictionary = iterator.next_assignment()
	var second_ids: Dictionary = second.get("candidate_ids", {})
	_check(fails, cross_nogood.get("ok", false) == true
			and second.get("status", "") == Iterator.ASSIGNMENT
			and second_ids.get("A", "") == "a0"
			and second_ids.get("C", "") == "c1"
			and _assignment_is_compatible(second_ids, fixture["constraints"]),
		"an exact cross-component nogood advances only a governed component")
	iterator.add_nogood(["A"], second_ids)
	var third: Dictionary = iterator.next_assignment()
	var third_ids: Dictionary = third.get("candidate_ids", {})
	_check(fails, third.get("status", "") == Iterator.ASSIGNMENT
			and third_ids.get("A", "") == "a1"
			and third_ids.get("C", "") == "c1",
		"a governed component advances without enumerating unrelated components")
	var projection: RefCounted = Iterator.new(
		fixture["node_sets"], fixture["constraints"], {"network": "synthetic"})
	var projection_first: Dictionary = projection.next_assignment()
	projection.add_nogood(["A", "C"], projection_first["candidate_ids"])
	var projection_second: Dictionary = projection.next_assignment()
	projection.add_nogood(["A", "C"], projection_second["candidate_ids"])
	var projection_ids: Dictionary = projection.next_assignment()["candidate_ids"]
	_check(fails, projection_ids.get("A", "") == "a1"
			and projection_ids.get("C", "") == "c0",
		"the cross-component nogood remains exact rather than banning a projection")
	var receipt: Dictionary = iterator.receipt()
	var storage: Dictionary = receipt.get("storage", {})
	var counters: Dictionary = receipt.get("counters", {})
	var limits: Dictionary = receipt.get("limits", {})
	_check(fails, receipt.get("component_order", []) == [["A", "B"], ["C", "D"]]
			and MapLayoutCanonical.int_value(storage.get(
				"complete_selection_queue", -1)) == 0
			and MapLayoutCanonical.int_value(storage.get(
				"complete_selection_seen", -1)) == 0
			and MapLayoutCanonical.int_value(receipt.get(
				"max_retained_search_depth", 99)) <= 2
			and _within_limits(counters, limits),
		"component-local state remains bounded without complete-selection storage")

	var reordered: Dictionary = _component_fixture(true)
	var replay: RefCounted = Iterator.new(
		reordered["node_sets"], reordered["constraints"], {"network": "synthetic"})
	var replay_first: Dictionary = replay.next_assignment()
	replay.add_nogood(["A", "C"], replay_first.get("candidate_ids", {}))
	var replay_second: Dictionary = replay.next_assignment()
	replay.add_nogood(["A"], replay_second.get("candidate_ids", {}))
	var replay_third: Dictionary = replay.next_assignment()
	_check(fails, replay_first == first and replay_second == second
			and replay_third == third and replay.receipt() == receipt,
		"reordered equivalent dictionaries reproduce decisions, counters and output")


static func _test_lookup_exhaustion(fails: Array[String]) -> void:
	var ids_x: Array[String] = []
	var ids_y: Array[String] = []
	for index: int in range(9):
		ids_x.append("x%d" % index)
		ids_y.append("y%d" % index)
	var node_sets: Dictionary = {
		"X": _node_set(ids_x), "Y": _node_set(ids_y),
	}
	var constraints: Dictionary = {
		"1/X": _unary("X", ids_x),
		"1/Y": _unary("Y", ids_y),
		"2/X+Y": _pair("X", "Y", [["x8", "y8"]]),
	}
	var iterator: RefCounted = Iterator.new(
		node_sets, constraints, {"network": "lookup-bound"})
	var result: Dictionary = iterator.next_assignment()
	var receipt: Dictionary = result.get("receipt", {})
	var counters: Dictionary = receipt.get("counters", {})
	var limits: Dictionary = receipt.get("limits", {})
	_check(fails, result.get("status", "") == Iterator.SELECTION_WORK_EXHAUSTED
			and MapLayoutCanonical.int_value(counters.get(
				"compatibility_lookups", -1)) == 64
			and MapLayoutCanonical.int_value(limits.get(
				"compatibility_lookups", -2)) == 64
			and not receipt.get("current_component", "").is_empty()
			and not receipt.get("current_decision", {}).is_empty()
			and _within_limits(counters, limits),
		"a rejected-branch network stops exactly at its compatibility-work authority")


static func _test_exact_priority_order(fails: Array[String]) -> void:
	var expected: Array[String] = [
		"z-margin", "a-margin", "z-cheap", "a-expensive",
	]
	var rows: Array[Dictionary] = _priority_rows()
	var reversed_rows: Array[Dictionary] = _priority_rows()
	reversed_rows.reverse()
	rows.sort_custom(Preflight._stronger)
	reversed_rows.sort_custom(Preflight._stronger)
	_check(fails, _priority_ids(rows) == expected
			and _priority_ids(reversed_rows) == expected
			and _priority_emissions(false) == expected
			and _priority_emissions(true) == expected,
		"near-equal binary64 margins and costs retain one exact order under replay")


static func _test_materialisation_exhaustion(fails: Array[String]) -> void:
	var ids: Array[String] = []
	for index: int in range(66):
		ids.append("n%02d" % index)
	var node_sets: Dictionary = {"N": _node_set(ids)}
	var constraints: Dictionary = {"1/N": _unary("N", ids)}
	var iterator: RefCounted = Iterator.new(
		node_sets, constraints, {"network": "materialisation-bound"})
	var result: Dictionary = {}
	for attempt: int in range(65):
		result = iterator.next_assignment()
		if result.get("status", "") != Iterator.ASSIGNMENT:
			break
		iterator.add_nogood(["N"], result.get("candidate_ids", {}))
	result = iterator.next_assignment()
	var receipt: Dictionary = result.get("receipt", {})
	_check(fails, result.get("status", "") == Iterator.SELECTION_WORK_EXHAUSTED
			and MapLayoutCanonical.int_value(receipt.get(
				"counters", {}).get("complete_selection_materialisations", -1)) == 65
			and _within_limits(receipt.get("counters", {}),
				receipt.get("limits", {})),
		"the sixty-sixth complete selection is refused after sixty-five emissions")


static func _test_no_compatible_assignment(fails: Array[String]) -> void:
	var node_sets: Dictionary = {
		"A": _node_set(["a0"]), "B": _node_set(["b0"]),
	}
	var constraints: Dictionary = {
		"1/A": _unary("A", ["a0"]),
		"1/B": _unary("B", ["b0"]),
		"2/A+B": _pair("A", "B", []),
	}
	var iterator: RefCounted = Iterator.new(
		node_sets, constraints, {"network": "empty"})
	var result: Dictionary = iterator.next_assignment()
	_check(fails, result.get("status", "") == Iterator.NO_COMPATIBLE_ASSIGNMENT
			and _within_limits(result.get("receipt", {}).get("counters", {}),
				result.get("receipt", {}).get("limits", {})),
		"an impossible component returns a bounded deterministic terminal receipt")


static func _component_fixture(reordered: bool) -> Dictionary:
	var node_sets: Dictionary = {}
	var constraints: Dictionary = {}
	var node_order: Array[String] = []
	node_order.assign(["D", "C", "B", "A"] if reordered \
		else ["A", "B", "C", "D"])
	for node_id: String in node_order:
		var lower: String = node_id.to_lower()
		node_sets[node_id] = _node_set(["%s0" % lower, "%s1" % lower])
		constraints["1/%s" % node_id] = _unary(
			node_id, ["%s0" % lower, "%s1" % lower])
	var pairs: Array = [
		["C", "D", [["c0", "d0"], ["c0", "d1"],
			["c1", "d0"], ["c1", "d1"]]],
		["A", "B", [["a0", "b0"], ["a1", "b1"]]],
	]
	if not reordered:
		pairs.reverse()
	for row_v: Variant in pairs:
		var row: Array = row_v
		constraints["2/%s+%s" % [row[0], row[1]]] = _pair(
			str(row[0]), str(row[1]), row[2])
	return {"node_sets": node_sets, "constraints": constraints}


static func _priority_rows() -> Array[Dictionary]:
	return [
		{"candidate_ids": ["a-margin"],
			"weakest_signed_hard_margin": 1.0,
			"candidate_cost_m2": 0.0},
		{"candidate_ids": ["z-margin"],
			"weakest_signed_hard_margin": 1.000000001,
			"candidate_cost_m2": 100.0},
		{"candidate_ids": ["a-expensive"],
			"weakest_signed_hard_margin": 0.5,
			"candidate_cost_m2": 1.000000001},
		{"candidate_ids": ["z-cheap"],
			"weakest_signed_hard_margin": 0.5,
			"candidate_cost_m2": 1.0},
	]


static func _priority_ids(rows: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in rows:
		out.append(str(row["candidate_ids"][0]))
	return out


static func _priority_emissions(reordered: bool) -> Array[String]:
	var rows: Array[Dictionary] = _priority_rows()
	if reordered:
		rows.reverse()
	var candidates: Array[Dictionary] = []
	var allowed: Dictionary = {}
	var ranked: Dictionary = {}
	var order: Array = []
	for row: Dictionary in rows:
		var candidate_id: String = str(row["candidate_ids"][0])
		candidates.append({"id": candidate_id,
			"displacement_cost_m2": row["candidate_cost_m2"]})
		var key: String = MapLayoutCanonical.canonical_text([candidate_id])
		allowed[key] = true
		ranked[key] = row
		order.append([candidate_id])
	var iterator: RefCounted = Iterator.new({"N": {"candidates": candidates}}, {
		"1/N": {"id": "1/N", "node_ids": ["N"],
			"allowed_candidate_ids": allowed, "ranked_combinations": ranked,
			"surviving_order": order},
	}, {"network": "exact-priority"})
	var out: Array[String] = []
	for ignored: int in range(rows.size()):
		var result: Dictionary = iterator.next_assignment()
		var candidate_ids: Dictionary = result.get("candidate_ids", {})
		out.append(str(candidate_ids.get("N", "")))
		iterator.add_nogood(["N"], candidate_ids)
	return out


static func _node_set(candidate_ids: Array[String]) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for index: int in range(candidate_ids.size()):
		candidates.append({"id": candidate_ids[index],
			"displacement_cost_m2": float(index)})
	return {"candidates": candidates}


static func _unary(node_id: String, candidate_ids: Array[String]) -> Dictionary:
	var allowed: Dictionary = {}
	var ranked: Dictionary = {}
	var order: Array = []
	for index: int in range(candidate_ids.size()):
		var ids: Array[String] = [candidate_ids[index]]
		var key: String = MapLayoutCanonical.canonical_text(ids)
		allowed[key] = true
		ranked[key] = {
			"candidate_ids": ids,
			"weakest_signed_hard_margin": float(candidate_ids.size() - index),
			"candidate_cost_m2": float(index),
		}
		order.append(ids)
	return {"id": "1/%s" % node_id, "node_ids": [node_id],
		"allowed_candidate_ids": allowed, "ranked_combinations": ranked,
		"surviving_order": order}


static func _pair(first: String, second: String, rows: Array) -> Dictionary:
	var allowed: Dictionary = {}
	var ranked: Dictionary = {}
	for row_v: Variant in rows:
		var row: Array = row_v
		var ids: Array[String] = [str(row[0]), str(row[1])]
		var key: String = MapLayoutCanonical.canonical_text(ids)
		allowed[key] = true
		ranked[key] = {"candidate_ids": ids,
			"weakest_signed_hard_margin": 1.0, "candidate_cost_m2": 0.0}
	return {"id": "2/%s+%s" % [first, second],
		"node_ids": [first, second], "allowed_candidate_ids": allowed,
		"ranked_combinations": ranked, "surviving_order": rows}


static func _within_limits(counters: Dictionary, limits: Dictionary) -> bool:
	for key: String in ["assignment_decisions", "compatibility_lookups",
			"domain_value_removals", "complete_selection_materialisations",
			"route_attempts"]:
		if not counters.has(key) or not limits.has(key) \
				or MapLayoutCanonical.int_value(counters[key]) \
					> MapLayoutCanonical.int_value(limits[key]):
			return false
	return true


static func _assignment_is_compatible(candidate_ids: Dictionary,
		constraints: Dictionary) -> bool:
	for constraint_id: String in MapLayoutCanonical.sorted_keys(constraints):
		var constraint: Dictionary = constraints[constraint_id]
		var ids: Array[String] = []
		for node_id_v: Variant in constraint.get("node_ids", []):
			ids.append(str(candidate_ids.get(str(node_id_v), "")))
		if not constraint.get("allowed_candidate_ids", {}).has(
				MapLayoutCanonical.canonical_text(ids)):
			return false
	return true
