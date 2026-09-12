extends RefCounted
## Known route conflicts must prune a remaining domain before unrelated choices.
const Fixtures = preload("res://tests/test_map_compatibility_selection_iterator.gd")

static func run(fails: Array[String]) -> void:
	var sets: Dictionary = {}
	var constraints: Dictionary = {}
	var nodes: Array[String] = ["A","B","C","D","Z"]
	for id: String in nodes:
		var values: Array[String] = [id+"0",id+"1"]
		sets[id] = Fixtures._node_set(values)
		constraints["1/"+id] = Fixtures._unary(id,values)
		if id!="A":
			constraints["2/A+"+id] = Fixtures._pair("A",id,[["A0",id+"0"],["A0",id+"1"],["A1",id+"0"],["A1",id+"1"]])
	var iterator: MapCompatibilitySelectionIterator = MapCompatibilitySelectionIterator.new(sets,constraints)
	iterator.add_nogood(["A","Z"],{"A":"A0","Z":"Z0"})
	iterator.add_nogood(["A","Z"],{"A":"A0","Z":"Z1"})
	var first: Dictionary = iterator.next_assignment()
	if first.get("candidate_ids",{}).get("A")!="A1":
		fails.append("nogood propagation: failed to retain the feasible A1 branch")
	var receipt: Dictionary = iterator.receipt()
	if MapLayoutCanonical.int_value(receipt["counters"]["assignment_decisions"])>nodes.size()+2:
		fails.append("nogood propagation: enumerated unrelated nodes after a known domain contradiction")
	# Every remaining leaf combination is feasible. Enumerating them proves that
	# pruning the A0 branch did not turn an exact nogood into a broader ban.
	var seen: Dictionary = {}
	var item: Dictionary = first
	while item.get("status")==MapCompatibilitySelectionIterator.ASSIGNMENT:
		var ids: Dictionary = item["candidate_ids"]
		var key: String = MapLayoutCanonical.canonical_text(ids)
		if seen.has(key) or ids["A"]!="A1": fails.append("nogood propagation: invalid or duplicate assignment")
		seen[key] = true
		item = iterator.next_assignment()
	if seen.size()!=16 or item.get("status")!=MapCompatibilitySelectionIterator.NO_COMPATIBLE_ASSIGNMENT:
		fails.append("nogood propagation: lost a feasible assignment or exhausted work")
