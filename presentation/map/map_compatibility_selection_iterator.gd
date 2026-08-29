class_name MapCompatibilitySelectionIterator
extends RefCounted
## Lazy, component-local assignment over exact #466 unary/pair receipts.
const VERSION: String = "map-compatibility-selection-iterator-v1"
const ASSIGNMENT: String = "ASSIGNMENT"
const SELECTION_WORK_EXHAUSTED: String = "SELECTION_WORK_EXHAUSTED"
const NO_COMPATIBLE_ASSIGNMENT: String = "NO_COMPATIBLE_ASSIGNMENT"
const _Network = preload(
	"res://presentation/map/map_compatibility_selection_network.gd")

var _constraints: Dictionary
var _identities: Dictionary
var _node_order: Array[String] = []
var _candidate_ids: Dictionary = {}
var _candidate_indices: Dictionary = {}
var _initial_domains: Dictionary = {}
var _pair_constraints: Dictionary = {}
var _incident: Dictionary = {}
var _components: Array[Array] = []
var _node_components: Dictionary = {}
var _cursors: Array[Dictionary] = []
var _nogoods: Array[Dictionary] = []
var _decision_trace: Array[Dictionary] = []
var _counters: Dictionary = {
	"assignment_decisions": 0,
	"compatibility_lookups": 0,
	"domain_value_removals": 0,
	"complete_selection_materialisations": 0,
	"route_attempts": 0,
}
var _limits: Dictionary = {}
var _totals: Dictionary = {}
var _current_component: String = ""
var _current_decision: Dictionary = {}
var _max_retained_search_depth: int = 0
var _emission_index: int = 0
var _started: bool = false
var _advance_component_indices: Array[int] = []
var _terminal_status: String = ""
var _terminal_reason: String = ""
var _invalid_reason: String = ""
@warning_ignore_start("unsafe_call_argument")

func _init(node_sets: Dictionary, constraints: Dictionary,
		identities: Dictionary = {}) -> void:
	_constraints = constraints
	_identities = MapLayoutCanonical.ordered_dictionary(identities)
	var network: Dictionary = _Network.build(node_sets, constraints)
	if network.get("ok", false) != true:
		_invalid_reason = str(network.get("reason", "invalid compatibility network"))
		return
	_node_order.assign(network["node_order"])
	_candidate_ids = network["candidate_ids"]
	_candidate_indices = network["candidate_indices"]
	_initial_domains = network["initial_domains"]
	_pair_constraints = network["pair_constraints"]
	_incident = network["incident"]
	_components.assign(network["components"])
	_node_components = network["node_components"]
	_totals = network["totals"]
	_limits = network["limits"]

func next_assignment() -> Dictionary:
	if not _terminal_status.is_empty():
		return _terminal_result()
	if not _invalid_reason.is_empty():
		return _finish(NO_COMPATIBLE_ASSIGNMENT, _invalid_reason)
	if not _started:
		_started = true
		if not _initialise_components():
			return _terminal_result()
	else:
		var targets: Array[int] = _advance_component_indices.duplicate()
		if targets.is_empty():
			targets.append(_components.size() - 1)
		_advance_component_indices = []
		if not _advance_governed_components(targets):
			return _terminal_result()
	while true:
		if not _take("complete_selection_materialisations", {
			"operation": "complete_selection_materialisation",
			"materialisation_index": MapLayoutCanonical.int_value(_counters[
				"complete_selection_materialisations"]) + 1,
		}):
			return _finish(SELECTION_WORK_EXHAUSTED,
				"complete_selection_materialisations")
		var candidate_ids: Dictionary = _assembled_candidate_ids()
		var matched: Dictionary = _matching_nogood(candidate_ids)
		if not matched.is_empty():
			var matched_components: Array = matched["component_indices"]
			var target_component: int = MapLayoutCanonical.int_value(
				matched_components[-1])
			_prepare_nogood_backjump(matched, target_component)
			if not _advance_governed_components(matched_components):
				return _terminal_result()
			continue
		var direct: Dictionary = _direct_compatible(candidate_ids, true)
		if direct.get("exhausted", false) == true:
			return _finish(SELECTION_WORK_EXHAUSTED,
				str(direct.get("reason", "compatibility_lookups")))
		if direct.get("compatible", false) != true:
			return _finish(NO_COMPATIBLE_ASSIGNMENT,
				"component assignment failed exact direct #466 compatibility")
		if not _take("route_attempts", {
			"operation": "route_attempt",
			"emission_index": _emission_index + 1,
		}):
			return _finish(SELECTION_WORK_EXHAUSTED,
				"route_attempts")
		_emission_index += 1
		var selection: Dictionary = {}
		for node_id: String in _node_order:
			selection[node_id] = _candidate_index(
				node_id, str(candidate_ids[node_id]))
		var result: Dictionary = MapLayoutCanonical.ordered_dictionary({
			"status": ASSIGNMENT,
			"emission_index": _emission_index,
			"selection": selection,
			"candidate_ids": candidate_ids,
			"receipt": receipt(),
		})
		return result
	return {}

func add_nogood(node_ids_v: Array, selected_candidate_ids: Dictionary) -> Dictionary:
	if not _terminal_status.is_empty():
		return {"ok": false, "reason": "iterator is terminal"}
	var unique: Dictionary = {}
	for node_id_v: Variant in node_ids_v:
		var node_id: String = str(node_id_v)
		if _node_components.has(node_id) \
				and selected_candidate_ids.has(node_id):
			unique[node_id] = true
	var node_ids: Array[String] = MapLayoutCanonical.sorted_keys(unique)
	if node_ids.is_empty():
		return {"ok": false, "reason": "nogood has no active governed node"}
	var ids: Array[String] = []
	var component_set: Dictionary = {}
	for node_id: String in node_ids:
		ids.append(str(selected_candidate_ids[node_id]))
		component_set[str(_node_components[node_id])] = true
	var component_indices: Array[int] = []
	for component_text: String in MapLayoutCanonical.sorted_keys(component_set):
		component_indices.append(component_text.to_int())
	component_indices.sort()
	var body: Dictionary = MapLayoutCanonical.ordered_dictionary({
		"node_ids": node_ids,
		"candidate_ids": ids,
		"component_indices": component_indices,
	})
	var digest: String = MapLayoutCanonical.digest(body)
	for existing: Dictionary in _nogoods:
		if str(existing["nogood_digest"]) == digest:
			_advance_component_indices = component_indices.duplicate()
			_prepare_nogood_backjump(existing, component_indices[-1])
			return {"ok": true, "deduplicated": true,
				"nogood_digest": digest}
	body["nogood_digest"] = digest
	var nogood: Dictionary = MapLayoutCanonical.ordered_dictionary(body)
	_nogoods.append(nogood)
	_advance_component_indices = component_indices.duplicate()
	_prepare_nogood_backjump(nogood, component_indices[-1])
	return {"ok": true, "deduplicated": false, "nogood_digest": digest}

func receipt() -> Dictionary:
	var body: Dictionary = MapLayoutCanonical.ordered_dictionary({
		"version": VERSION,
		"network_identities": _identities,
		"component_order": _components,
		"totals": _totals,
		"limits": _limits,
		"counters": _counters,
		"max_retained_search_depth": _max_retained_search_depth,
		"current_component": _current_component,
		"current_decision": _current_decision,
		"decision_trace": _decision_trace,
		"nogoods": _nogoods,
		"storage": {
			"complete_selection_queue": 0,
			"complete_selection_seen": 0,
			"component_cursors": _cursors.size(),
		},
		"terminal_status": _terminal_status,
		"terminal_reason": _terminal_reason,
	})
	body["receipt_digest"] = MapLayoutCanonical.digest(body)
	return MapLayoutCanonical.ordered_dictionary(body)

func _initialise_components() -> bool:
	for component_index: int in range(_components.size()):
		_cursors.append(_new_cursor(_components[component_index]))
		var found: String = _component_next(component_index)
		if found == "exhausted":
			_finish(SELECTION_WORK_EXHAUSTED, _terminal_reason)
			return false
		if found != "solution":
			_finish(NO_COMPATIBLE_ASSIGNMENT,
				"active compatibility component has no assignment")
			return false
	return true

func _new_cursor(node_ids: Array) -> Dictionary:
	var domains: Dictionary = {}
	for node_id_v: Variant in node_ids:
		var node_id: String = str(node_id_v)
		domains[node_id] = _initial_domains[node_id].duplicate()
	return {"node_ids": node_ids.duplicate(), "domains": domains,
		"assigned": {}, "frames": [], "solution": {},
		"yielded": false, "finished": false}

func _component_next(component_index: int) -> String:
	var cursor: Dictionary = _cursors[component_index]
	if cursor.get("finished", false) == true:
		return "done"
	_current_component = _component_id(component_index)
	if cursor.get("yielded", false) == true:
		cursor["yielded"] = false
		var resumed: String = _advance_frames(cursor, component_index)
		if resumed == "exhausted":
			_cursors[component_index] = cursor
			return resumed
		if resumed == "done":
			cursor["finished"] = true
			_cursors[component_index] = cursor
			return resumed
	while true:
		var assigned: Dictionary = cursor["assigned"]
		var node_ids: Array = cursor["node_ids"]
		if assigned.size() == node_ids.size():
			cursor["solution"] = assigned.duplicate()
			cursor["yielded"] = true
			_cursors[component_index] = cursor
			return "solution"
		var node_id: String = _next_node(cursor)
		var domains: Dictionary = cursor["domains"]
		var domain: Array = domains[node_id]
		var frames: Array = cursor["frames"]
		frames.append({"node_id": node_id, "candidates": domain.duplicate(),
			"next_index": 0, "active": false, "changes": []})
		cursor["frames"] = frames
		_max_retained_search_depth = maxi(
			_max_retained_search_depth, frames.size())
		var tried: String = _try_frame(cursor, frames.size() - 1,
			component_index)
		if tried == "exhausted":
			_cursors[component_index] = cursor
			return tried
		if tried == "assigned":
			continue
		frames = cursor["frames"]
		frames.pop_back()
		cursor["frames"] = frames
		var advanced: String = _advance_frames(cursor, component_index)
		if advanced == "exhausted":
			_cursors[component_index] = cursor
			return advanced
		if advanced == "done":
			cursor["finished"] = true
			_cursors[component_index] = cursor
			return advanced
	return "done"

func _advance_frames(cursor: Dictionary, component_index: int) -> String:
	var frames: Array = cursor["frames"]
	while not frames.is_empty():
		var tried: String = _try_frame(cursor, frames.size() - 1,
			component_index)
		if tried == "assigned" or tried == "exhausted":
			return tried
		frames = cursor["frames"]
		frames.pop_back()
		cursor["frames"] = frames
	return "done"


func _try_frame(cursor: Dictionary, frame_index: int,
		component_index: int) -> String:
	var frames: Array = cursor["frames"]
	var frame: Dictionary = frames[frame_index]
	var assigned: Dictionary = cursor["assigned"]
	if frame.get("active", false) == true:
		_restore_changes(cursor, frame.get("changes", []))
		assigned.erase(str(frame["node_id"]))
		frame["active"] = false
		frame["changes"] = []
	var candidates: Array = frame["candidates"]
	while MapLayoutCanonical.int_value(frame["next_index"]) < candidates.size():
		var candidate_position: int = MapLayoutCanonical.int_value(
			frame["next_index"])
		frame["next_index"] = candidate_position + 1
		var candidate_index: int = MapLayoutCanonical.int_value(
			candidates[candidate_position])
		var node_id: String = str(frame["node_id"])
		var candidate_id: String = _candidate_id(node_id, candidate_index)
		_current_decision = {"operation": "assignment_decision",
			"component": _component_id(component_index),
			"depth": frame_index + 1, "node_id": node_id,
			"candidate_id": candidate_id}
		if not _take("assignment_decisions", _current_decision):
			frames[frame_index] = frame
			cursor["frames"] = frames
			return "exhausted"
		var trace: Dictionary = _current_decision.duplicate()
		trace["index"] = _counters["assignment_decisions"]
		trace["outcome"] = "pending"
		_decision_trace.append(trace)
		assigned[node_id] = candidate_index
		var changes: Array[Dictionary] = []
		var checked: String = _forward_check(cursor, component_index,
			node_id, candidate_index, changes)
		if checked == "exhausted":
			_decision_trace[-1]["outcome"] = "work_exhausted"
			frame["active"] = true
			frame["changes"] = changes
			frames[frame_index] = frame
			cursor["frames"] = frames
			return checked
		if checked == "compatible" \
				and _assigned_violates_nogood(component_index, assigned):
			checked = "nogood"
		if checked == "compatible":
			_decision_trace[-1]["outcome"] = "assigned"
			frame["active"] = true
			frame["changes"] = changes
			frames[frame_index] = frame
			cursor["frames"] = frames
			return "assigned"
		_decision_trace[-1]["outcome"] = checked
		_restore_changes(cursor, changes)
		assigned.erase(node_id)
	frames[frame_index] = frame
	cursor["frames"] = frames
	return "done"


func _forward_check(cursor: Dictionary, component_index: int,
		node_id: String, candidate_index: int,
		changes: Array[Dictionary]) -> String:
	var assigned: Dictionary = cursor["assigned"]
	var domains: Dictionary = cursor["domains"]
	var incident: Array = _incident[node_id]
	for constraint_id_v: Variant in incident:
		var constraint_id: String = str(constraint_id_v)
		var constraint: Dictionary = _pair_constraints[constraint_id]
		var node_ids: Array = constraint["node_ids"]
		var other_id: String = str(node_ids[1]) \
			if str(node_ids[0]) == node_id else str(node_ids[0])
		if assigned.has(other_id):
			continue
		var other_domain: Array = domains[other_id]
		for position: int in range(other_domain.size() - 1, -1, -1):
			var other_index: int = MapLayoutCanonical.int_value(
				other_domain[position])
			var lookup: Dictionary = {"operation": "compatibility_lookup",
				"component": _component_id(component_index),
				"constraint_id": constraint_id, "node_id": node_id,
				"candidate_id": _candidate_id(node_id, candidate_index),
				"other_node_id": other_id,
				"other_candidate_id": _candidate_id(other_id, other_index)}
			if not _take("compatibility_lookups", lookup):
				return "exhausted"
			if _pair_allows(constraint, node_id, candidate_index,
					other_id, other_index):
				continue
			var removal: Dictionary = lookup.duplicate()
			removal["operation"] = "domain_value_removal"
			if not _take("domain_value_removals", removal):
				return "exhausted"
			changes.append({"node_id": other_id, "position": position,
				"candidate_index": other_index})
			other_domain.remove_at(position)
		if other_domain.is_empty():
			return "incompatible"
	return "compatible"


func _restore_changes(cursor: Dictionary, changes: Array) -> void:
	var domains: Dictionary = cursor["domains"]
	for change_index: int in range(changes.size() - 1, -1, -1):
		var change: Dictionary = changes[change_index]
		var node_id: String = str(change["node_id"])
		var domain: Array = domains[node_id]
		domain.insert(MapLayoutCanonical.int_value(change["position"]),
			MapLayoutCanonical.int_value(change["candidate_index"]))


func _next_node(cursor: Dictionary) -> String:
	var assigned: Dictionary = cursor["assigned"]
	var domains: Dictionary = cursor["domains"]
	var best: String = ""
	var best_domain: int = 0
	var best_degree: int = 0
	for node_id_v: Variant in cursor["node_ids"]:
		var node_id: String = str(node_id_v)
		if assigned.has(node_id):
			continue
		var domain: Array = domains[node_id]
		var degree: int = 0
		for constraint_id_v: Variant in _incident[node_id]:
			var constraint: Dictionary = _pair_constraints[str(constraint_id_v)]
			var pair_nodes: Array = constraint["node_ids"]
			var other: String = str(pair_nodes[1]) \
				if str(pair_nodes[0]) == node_id else str(pair_nodes[0])
			if not assigned.has(other):
				degree += 1
		if best.is_empty() or domain.size() < best_domain \
				or (domain.size() == best_domain and degree > best_degree) \
				or (domain.size() == best_domain and degree == best_degree \
					and node_id < best):
			best = node_id
			best_domain = domain.size()
			best_degree = degree
	return best


func _advance_governed_components(component_indices: Array) -> bool:
	for position: int in range(component_indices.size() - 1, -1, -1):
		var component_index: int = MapLayoutCanonical.int_value(
			component_indices[position])
		var advanced: String = _component_next(component_index)
		if advanced == "exhausted":
			_finish(SELECTION_WORK_EXHAUSTED, _terminal_reason)
			return false
		if advanced != "solution":
			continue
		for following_position: int in range(
				position + 1, component_indices.size()):
			var following: int = MapLayoutCanonical.int_value(
				component_indices[following_position])
			_cursors[following] = _new_cursor(_components[following])
			var first: String = _component_next(following)
			if first == "exhausted":
				_finish(SELECTION_WORK_EXHAUSTED, _terminal_reason)
				return false
			if first != "solution":
				_finish(NO_COMPATIBLE_ASSIGNMENT,
					"active compatibility component has no assignment")
				return false
		return true
	_finish(NO_COMPATIBLE_ASSIGNMENT,
		"compatibility-selection iterator has no further assignment")
	return false


func _assembled_candidate_ids() -> Dictionary:
	var out: Dictionary = {}
	for cursor: Dictionary in _cursors:
		var solution: Dictionary = cursor.get("solution", {})
		for node_id: String in MapLayoutCanonical.sorted_keys(solution):
			out[node_id] = _candidate_id(node_id,
				MapLayoutCanonical.int_value(solution[node_id]))
	return MapLayoutCanonical.ordered_dictionary(out)


func _matching_nogood(candidate_ids: Dictionary) -> Dictionary:
	for nogood: Dictionary in _nogoods:
		var node_ids: Array = nogood["node_ids"]
		var ids: Array = nogood["candidate_ids"]
		var matches: bool = true
		for index: int in range(node_ids.size()):
			matches = matches and str(candidate_ids.get(
				str(node_ids[index]), "")) == str(ids[index])
		if matches:
			return nogood
	return {}


func _assigned_violates_nogood(component_index: int,
		assigned: Dictionary) -> bool:
	for nogood: Dictionary in _nogoods:
		var node_ids: Array = nogood["node_ids"]
		var ids: Array = nogood["candidate_ids"]
		var matches: bool = true
		for index: int in range(node_ids.size()):
			var node_id: String = str(node_ids[index])
			var owner: int = MapLayoutCanonical.int_value(
				_node_components[node_id])
			var candidate_id: String = ""
			if owner == component_index:
				if not assigned.has(node_id):
					matches = false
					break
				candidate_id = _candidate_id(node_id,
					MapLayoutCanonical.int_value(assigned[node_id]))
			elif owner < _cursors.size():
				var solution: Dictionary = _cursors[owner].get("solution", {})
				if not solution.has(node_id):
					matches = false
					break
				candidate_id = _candidate_id(node_id,
					MapLayoutCanonical.int_value(solution[node_id]))
			else:
				matches = false
				break
			if candidate_id != str(ids[index]):
				matches = false
				break
		if matches:
			return true
	return false


func _prepare_nogood_backjump(nogood: Dictionary,
		component_index: int) -> void:
	if component_index < 0 or component_index >= _cursors.size():
		return
	var governed: Dictionary = {}
	for node_id_v: Variant in nogood["node_ids"]:
		var node_id: String = str(node_id_v)
		if MapLayoutCanonical.int_value(
				_node_components[node_id]) == component_index:
			governed[node_id] = true
	var cursor: Dictionary = _cursors[component_index]
	var frames: Array = cursor["frames"]
	var target: int = -1
	for frame_index: int in range(frames.size()):
		if governed.has(str(frames[frame_index]["node_id"])):
			target = frame_index
	if target < 0:
		return
	var assigned: Dictionary = cursor["assigned"]
	for frame_index: int in range(frames.size() - 1, target, -1):
		var frame: Dictionary = frames[frame_index]
		if frame.get("active", false) == true:
			_restore_changes(cursor, frame.get("changes", []))
			assigned.erase(str(frame["node_id"]))
		frames.pop_back()
	cursor["frames"] = frames
	cursor["solution"] = {}
	cursor["yielded"] = true
	_cursors[component_index] = cursor


func _direct_compatible(candidate_ids: Dictionary,
		count_work: bool) -> Dictionary:
	for constraint_id: String in MapLayoutCanonical.sorted_keys(_constraints):
		var constraint: Dictionary = _constraints[constraint_id]
		var node_ids: Array = constraint["node_ids"]
		var ids: Array[String] = []
		for node_id_v: Variant in node_ids:
			ids.append(str(candidate_ids.get(str(node_id_v), "")))
		if node_ids.size() == 2 and count_work:
			var operation: Dictionary = {"operation": "direct_compatibility_lookup",
				"constraint_id": constraint_id, "candidate_ids": ids}
			if not _take("compatibility_lookups", operation):
				return {"compatible": false, "exhausted": true,
					"reason": "compatibility_lookups"}
		var allowed: Dictionary = constraint.get("allowed_candidate_ids", {})
		if not allowed.has(MapLayoutCanonical.canonical_text(ids)):
			return {"compatible": false, "exhausted": false}
	return {"compatible": true, "exhausted": false}


func _pair_allows(constraint: Dictionary, node_id: String,
		candidate_index: int, other_id: String, other_index: int) -> bool:
	var node_ids: Array = constraint["node_ids"]
	var ids: Array[String] = []
	if str(node_ids[0]) == node_id:
		ids = [_candidate_id(node_id, candidate_index),
			_candidate_id(other_id, other_index)]
	else:
		ids = [_candidate_id(other_id, other_index),
			_candidate_id(node_id, candidate_index)]
	var allowed: Dictionary = constraint.get("allowed_candidate_ids", {})
	return allowed.has(MapLayoutCanonical.canonical_text(ids))


func _take(counter_id: String, operation: Dictionary) -> bool:
	var current: int = MapLayoutCanonical.int_value(_counters[counter_id])
	var limit: int = MapLayoutCanonical.int_value(_limits[counter_id])
	_current_decision = MapLayoutCanonical.ordered_dictionary(operation)
	if current >= limit:
		_terminal_reason = counter_id
		return false
	_counters[counter_id] = current + 1
	return true


func _finish(status: String, reason: String) -> Dictionary:
	_terminal_status = status
	_terminal_reason = reason
	return _terminal_result()


func _terminal_result() -> Dictionary:
	return MapLayoutCanonical.ordered_dictionary({
		"status": _terminal_status,
		"receipt": receipt(),
	})


func _component_id(component_index: int) -> String:
	return "component/%s" % "+".join(_components[component_index])


func _candidate_id(node_id: String, candidate_index: int) -> String:
	var ids: Array = _candidate_ids[node_id]
	return str(ids[candidate_index])


func _candidate_index(node_id: String, candidate_id: String) -> int:
	return MapLayoutCanonical.int_value(_candidate_indices[node_id][candidate_id])
