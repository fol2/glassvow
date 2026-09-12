class_name MapLayoutInputBinding
extends RefCounted
## Pure WorldMap graph to MapLayoutInput node/topology binding (#469).

const _ACT4_IDS: PackedStringArray = ["n0", "n1", "n2", "n3", "n4"]
const _ACT4_TYPES: PackedStringArray = ["monster", "monster", "elite", "rest", "boss"]
const _ACT4_ROWS: PackedInt32Array = [0, 4, 7, 10, 14]


static func bind(world: WorldMap, act: int) -> Dictionary:
	if world == null:
		return _failure("world", "WorldMap is null")
	if act < 0 or act > 3:
		return _failure("act", "act must be between 0 and 3")
	var records: Array[Dictionary] = []
	var edges: Array[Dictionary] = []
	for node: MapNode in world.nodes:
		records.append({
			"id": node.id,
			"row": node.row,
			"col": node.col,
			"type": node.type,
			"jitter": [node.jx, node.jy],
		})
		for to_id: String in node.next:
			edges.append({
				"id": MapLayoutInput.edge_id(node.id, to_id),
				"from": node.id,
				"to": to_id,
			})
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["id"]) < str(b["id"])
	)
	edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["id"]) < str(b["id"])
	)
	if act < 3:
		return _success(records, edges)
	var mismatch: Dictionary = _act4_mismatch(records, edges)
	if not mismatch.is_empty():
		return mismatch
	var bound: Array[Dictionary] = []
	for i: int in range(_ACT4_IDS.size()):
		bound.append({
			"id": _ACT4_IDS[i],
			"row": _ACT4_ROWS[i],
			"col": 3,
			"type": _ACT4_TYPES[i],
			"jitter": [0.0, 0.0],
		})
	return _success(bound, edges)


static func _act4_mismatch(nodes: Array[Dictionary],
		edges: Array[Dictionary]) -> Dictionary:
	var by_id: Dictionary = {}
	for node: Dictionary in nodes:
		var node_id: String = str(node["id"])
		if by_id.has(node_id):
			return _failure("nodes.%s.id" % node_id, "duplicate Act IV node ID")
		by_id[node_id] = node
	for i: int in range(_ACT4_IDS.size()):
		var expected_id: String = _ACT4_IDS[i]
		if not by_id.has(expected_id):
			return _failure("nodes.%s.id" % expected_id, "required Act IV node is missing")
		var node: Dictionary = by_id[expected_id]
		if str(node["type"]) != _ACT4_TYPES[i]:
			return _failure("nodes.%s.type" % expected_id,
				"expected %s, got %s" % [_ACT4_TYPES[i], node["type"]])
	for node_id: String in MapLayoutCanonical.sorted_keys(by_id):
		if node_id not in _ACT4_IDS:
			return _failure("nodes.%s.id" % node_id, "unexpected Act IV node")
	var edge_counts: Dictionary = {}
	for edge: Dictionary in edges:
		var edge_id: String = str(edge["id"])
		edge_counts[edge_id] = MapLayoutCanonical.int_value(edge_counts.get(edge_id, 0)) + 1
	var expected_edges: Dictionary = {}
	for i: int in range(_ACT4_IDS.size() - 1):
		var edge_id: String = MapLayoutInput.edge_id(_ACT4_IDS[i], _ACT4_IDS[i + 1])
		expected_edges[edge_id] = true
		if not edge_counts.has(edge_id):
			return _failure("edges.%s" % edge_id, "required Act IV edge is missing")
	for edge_id: String in MapLayoutCanonical.sorted_keys(edge_counts):
		if not expected_edges.has(edge_id):
			return _failure("edges.%s" % edge_id, "unexpected Act IV edge")
		if MapLayoutCanonical.int_value(edge_counts[edge_id]) != 1:
			return _failure("edges.%s" % edge_id, "duplicate Act IV edge")
	return {}


static func _success(nodes: Array[Dictionary], edges: Array[Dictionary]) -> Dictionary:
	return MapLayoutCanonical.ordered_dictionary({
		"ok": true,
		"nodes": nodes,
		"edges": edges,
		"error": {},
	})


static func _failure(id: String, reason: String) -> Dictionary:
	return MapLayoutCanonical.ordered_dictionary({
		"ok": false,
		"nodes": [],
		"edges": [],
		"error": {
			"kind": "act4_layout_binding",
			"id": id,
			"reason": reason,
		},
	})
