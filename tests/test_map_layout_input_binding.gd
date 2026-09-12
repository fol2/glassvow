extends RefCounted
## #469 reusable domain-graph to MapLayoutInput node binding.

const Binding = preload("res://domain/map_layout/map_layout_input_binding.gd")

@warning_ignore_start("unsafe_call_argument")


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_layout_input_binding: %s" % what)


static func run(fails: Array[String]) -> void:
	_test_authored_act4(fails)
	_test_generated_identity(fails)
	_test_act4_mismatches(fails)


static func _test_authored_act4(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var run_state: RunState = RunState.new_run(content, 717, "layout-binding-act4")
	run_state.act = 3
	var world: WorldMap = WorldMap.for_run(run_state, content)
	var before: Dictionary = world.to_dict().duplicate(true)
	var bound: Dictionary = Binding.bind(world, 3)
	_check(fails, bound.get("ok", false) == true and bound.get("nodes", []) == [
		{"id": "n0", "row": 0, "col": 3, "type": "monster", "jitter": [0.0, 0.0]},
		{"id": "n1", "row": 4, "col": 3, "type": "monster", "jitter": [0.0, 0.0]},
		{"id": "n2", "row": 7, "col": 3, "type": "elite", "jitter": [0.0, 0.0]},
		{"id": "n3", "row": 10, "col": 3, "type": "rest", "jitter": [0.0, 0.0]},
		{"id": "n4", "row": 14, "col": 3, "type": "boss", "jitter": [0.0, 0.0]},
	], "the exact authored Act IV graph binds to the governed five-node pilgrimage")
	_check(fails, bound.get("edges", []) == [
		_edge("n0", "n1"), _edge("n1", "n2"), _edge("n2", "n3"), _edge("n3", "n4"),
	], "Act IV binding preserves the exact authored topology")
	var restored: WorldMap = WorldMap.from_dict(before)
	_check(fails, world.to_dict() == before
			and restored != null and restored.to_dict() == before,
		"binding leaves the live graph and its save projection unchanged")


static func _test_generated_identity(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	for act: int in range(3):
		var run_state: RunState = RunState.new_run(
			content, 717, "layout-binding-act-%d" % act
		)
		run_state.act = act
		var world: WorldMap = WorldMap.for_run(run_state, content)
		var before: Dictionary = world.to_dict().duplicate(true)
		var legacy: Array[Dictionary] = []
		for node: MapNode in world.nodes:
			legacy.append({
				"id": node.id,
				"row": node.row,
				"col": node.col,
				"type": node.type,
				"jitter": [node.jx, node.jy],
			})
		legacy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a["id"]) < str(b["id"])
		)
		var bound: Dictionary = Binding.bind(world, act)
		_check(fails, bound.get("ok", false) == true
				and MapLayoutCanonical.digest(bound.get("nodes", [])) \
				== MapLayoutCanonical.digest(legacy),
			"generated Act %d retains the prior canonical node-record digest" % (act + 1))
		_check(fails, world.to_dict() == before,
			"generated Act %d binding does not mutate the domain graph" % (act + 1))


static func _test_act4_mismatches(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var run_state: RunState = RunState.new_run(content, 717, "layout-binding-invalid")
	run_state.act = 3
	var source: WorldMap = WorldMap.for_run(run_state, content)
	var wrong_type: WorldMap = WorldMap.from_dict(source.to_dict())
	wrong_type.nodes[2].type = "rest"
	var type_result: Dictionary = Binding.bind(wrong_type, 3)
	_check(fails, type_result.get("ok", true) == false
			and type_result.get("error", {}).get("id", "") == "nodes.n2.type",
		"a malformed Act IV node fails at the first named type mismatch")
	var extra_edge: WorldMap = WorldMap.from_dict(source.to_dict())
	extra_edge.nodes[0].next.append("n2")
	var edge_result: Dictionary = Binding.bind(extra_edge, 3)
	_check(fails, edge_result.get("ok", true) == false
			and str(edge_result.get("error", {}).get("id", "")) \
			== "edges.%s" % MapLayoutInput.edge_id("n0", "n2"),
		"an Act IV topology mutation fails at the first named extra edge")


static func _edge(from_id: String, to_id: String) -> Dictionary:
	return {
		"id": MapLayoutInput.edge_id(from_id, to_id),
		"from": from_id,
		"to": to_id,
	}
