extends RefCounted
## #467 deterministic bounded node-candidate kernel.
@warning_ignore_start("unsafe_call_argument")
const _SHA: String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

static func _ok(fails: Array[String], value: bool, text: String) -> void:
	if not value: fails.append("test_map_node_candidate_generator: " + text)
static func run(fails: Array[String]) -> void:
	var quality: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://docs/map/map-quality-v2.json"))
	_test_identity_axes_and_contracts(fails, quality)
	_test_no_go_filtering(fails, quality)
	_test_generated_seeds(fails, quality)

static func _test_identity_axes_and_contracts(fails: Array[String], quality: Dictionary) -> void:
	var nodes: Array = [_node("entrance", 0, 3, "act4"), _node("outer", 6, 0),
		_node("middle", 7, 3), _node("boss", 14, 3, "boss")]
	var edges: Array = [_edge("entrance", "outer"), _edge("outer", "middle"),
		_edge("middle", "boss")]
	var input: MapLayoutInput = _input(nodes, edges, 717, quality, _far_zones())
	var first: Dictionary = MapNodeCandidateGenerator.generate(input, quality, 0)
	var replay: Dictionary = MapNodeCandidateGenerator.generate(input, quality, 0)
	var restart: Dictionary = MapNodeCandidateGenerator.generate(input, quality, 1)
	_ok(fails, MapLayoutCanonical.canonical_bytes(first) == MapLayoutCanonical.canonical_bytes(replay)
		and first["candidate_digest"] == replay["candidate_digest"],
		"same input, seed and restart preserve candidate bytes and order")
	var middle: Dictionary = first["node_sets"]["middle"]
	var authored: Dictionary = _proposal(middle, 0)
	_ok(fails, not authored.is_empty() and authored["anchor"] == middle["authored_anchor"],
		"legal candidate zero preserves the authored lattice/jitter anchor")
	_ok(fails, _has_axis(middle, true) and _has_axis(middle, false),
		"an interior node has controlled X-only and Z-only alternatives")
	_ok(fails, middle["stream_digest"] != restart["node_sets"]["middle"]["stream_digest"]
		and _proposal(middle, 1)["anchor"] != _proposal(restart["node_sets"]["middle"], 1)["anchor"],
		"restart changes optional candidates")
	for id: String in ["entrance", "boss"]:
		var a: Dictionary = first["node_sets"][id]
		var b: Dictionary = restart["node_sets"][id]
		_ok(fails, a["candidates"].size() == 1 and a["candidates"] == b["candidates"]
			and not str(a["fixed_contract"]).is_empty() and _has_reason(a, 1, "immutable_anchor"),
			id + " stays on its immutable anchor")
	_ok(fails, not first["node_sets"]["outer"]["candidates"].is_empty(),
		"an outer-lane node retains legal candidates")
	_ok(fails, _all_legal(first, edges, quality),
		"all candidates stay finite, bounded, enveloped and monotonic")
	var expanded: Array = nodes.duplicate(true); expanded.append(_node("unrelated", 10, 6))
	var extra: Dictionary = MapNodeCandidateGenerator.generate(
		_input(expanded, edges, 717, quality, _far_zones()), quality, 0)
	_ok(fails, first["graph_digest"] != extra["graph_digest"]
		and first["node_sets"]["middle"] == extra["node_sets"]["middle"],
		"an unrelated node changes graph identity without reshuffling prior candidates")
	var identity: Dictionary = first.duplicate(true); var digest: String = identity["candidate_digest"]
	identity.erase("candidate_digest")
	_ok(fails, digest == MapLayoutCanonical.digest(identity), "candidate digest binds the complete report")

static func _test_no_go_filtering(fails: Array[String], quality: Dictionary) -> void:
	var nodes: Array = [_node("N", 7, 3)]
	var baseline: Dictionary = MapNodeCandidateGenerator.generate(
		_input(nodes, [], 17634, quality, _far_zones()), quality, 0)
	var zones: Dictionary = _far_zones()
	zones["x-barrier"] = {"role": "no-go", "padding_m": 0.0,
		"polygon": [[-3.0, -0.1], [-3.0, 0.1], [3.0, 0.1], [3.0, -0.1]]}
	var blocked: Dictionary = MapNodeCandidateGenerator.generate(
		_input(nodes, [], 17634, quality, zones), quality, 0)
	var blocked_set: Dictionary = blocked["node_sets"]["N"]
	_ok(fails, _has_reason(blocked_set, 0, "hero_no_go_region")
		and _has_reason(blocked_set, 1, "hero_no_go_region")
		and _has_reason(blocked_set, 2, "hero_no_go_region")
		and (not _proposal(blocked_set, 3).is_empty() or not _proposal(blocked_set, 4).is_empty())
		and blocked_set["rejections"][0].has("displacement_cost_m2"),
		"Z movement clears a barrier that authored and X-only candidates cannot")
	var target: Vector3 = _v3(_proposal(baseline["node_sets"]["N"], 3)["anchor"])
	var center: Vector2 = Vector2(target.x, target.z + 2.4)
	var hero_zones: Dictionary = _far_zones()
	hero_zones["hero-cut"] = {"role": "vigil", "polygon": _box(center, 0.05)}
	var filtered: Dictionary = MapNodeCandidateGenerator.generate(
		_input(nodes, [], 17634, quality, hero_zones), quality, 0)
	var base_set: Dictionary = baseline["node_sets"]["N"]
	var filtered_set: Dictionary = filtered["node_sets"]["N"]
	_ok(fails, base_set["stream_digest"] == filtered_set["stream_digest"]
		and _has_reason(filtered_set, 3, "hero_no_go_region")
		and not _proposal(filtered_set, 0).is_empty()
		and _filter_is_exact(base_set, filtered_set),
		"a synthetic governed hero zone removes only intersecting proposals and records why")

static func _test_generated_seeds(fails: Array[String], quality: Dictionary) -> void:
	for seed: int in [717, 17634]:
		var content: ContentDB = ContentDB.load_slice()
		var run_state: RunState = RunState.new_run(content, seed, "node-candidates-%d" % seed)
		var world: WorldMap = WorldMap.benchmark(run_state)
		var before: Dictionary = world.to_dict().duplicate(true)
		var nodes: Array = []; var edges: Array = []
		for node: MapNode in world.nodes:
			nodes.append(_node(node.id, node.row, node.col, node.type, [node.jx, node.jy]))
			for to_id: String in node.next: edges.append(_edge(node.id, to_id))
		var report: Dictionary = MapNodeCandidateGenerator.generate(
			_input(nodes, edges, seed, quality, _far_zones()), quality, 0)
		var covered: bool = report["errors"].is_empty() and world.to_dict() == before
		for node: Dictionary in nodes:
			var row: Dictionary = report["node_sets"].get(str(node["id"]), {})
			covered = covered and (not row.is_empty()) and (
				not row["candidates"].is_empty() or _impossible(report, str(node["id"])))
		_ok(fails, covered and _all_legal(report, edges, quality),
			"seed %d covers every node or emits an explicit node impossibility without mutation" % seed)

static func _all_legal(report: Dictionary, edges: Array, quality: Dictionary) -> bool:
	var stage: Rect2 = MapPinProjection.lattice_footprint()
	var epsilon: float = float(quality["epsilon"]["world_m"])
	for id: String in MapLayoutCanonical.sorted_keys(report["node_sets"]):
		var row: Dictionary = report["node_sets"][id]
		if row["candidates"].size() > MapNodeCandidateGenerator.MAX_CANDIDATES_PER_NODE \
				or row["candidates"].size() + row["rejections"].size() != 9: return false
		var envelope: Dictionary = row["envelope"]
		for candidate: Dictionary in row["candidates"]:
			var point: Vector3 = _v3(candidate["anchor"])
			if not is_finite(point.x) or not stage.grow(epsilon).has_point(Vector2(point.x, point.z)) \
					or point.x < float(envelope["legal_x_m"][0]) - epsilon \
					or point.x > float(envelope["legal_x_m"][1]) + epsilon \
					or point.z < float(envelope["legal_z_m"][0]) - epsilon \
					or point.z > float(envelope["legal_z_m"][1]) + epsilon: return false
	var progress: float = float(quality["geometry"]["row_lane_envelope"]["minimum_forward_progress_m"])
	for edge: Dictionary in edges:
		for a: Dictionary in report["node_sets"][edge["from"]]["candidates"]:
			for b: Dictionary in report["node_sets"][edge["to"]]["candidates"]:
				if _v3(b["anchor"]).x - _v3(a["anchor"]).x < progress - epsilon: return false
	return true

static func _filter_is_exact(base: Dictionary, filtered: Dictionary) -> bool:
	for candidate: Dictionary in base["candidates"]:
		var kept: Dictionary = _candidate_id(filtered["candidates"], str(candidate["id"]))
		if not kept.is_empty() and kept != candidate: return false
		if kept.is_empty() and not _rejected_id(filtered, str(candidate["id"]), "hero_no_go_region"): return false
	return true
static func _proposal(row: Dictionary, slot: int) -> Dictionary:
	for candidate: Dictionary in row["candidates"]:
		if int(candidate["proposal_index"]) == slot: return candidate
	return {}
static func _has_reason(row: Dictionary, slot: int, reason_id: String) -> bool:
	for rejection: Dictionary in row["rejections"]:
		if int(rejection["proposal_index"]) == slot:
			for reason: Dictionary in rejection["reasons"]:
				if str(reason["id"]) == reason_id: return true
	return false
static func _rejected_id(row: Dictionary, id: String, reason_id: String) -> bool:
	for rejection: Dictionary in row["rejections"]:
		if str(rejection["id"]) == id:
			for reason: Dictionary in rejection["reasons"]:
				if str(reason["id"]) == reason_id: return true
	return false
static func _candidate_id(rows: Array, id: String) -> Dictionary:
	for row: Dictionary in rows:
		if str(row["id"]) == id: return row
	return {}
static func _has_axis(row: Dictionary, x_axis: bool) -> bool:
	for candidate: Dictionary in row["candidates"]:
		var delta: Array = candidate["delta_xz_m"]
		var dx: float = absf(float(delta[0])); var dz: float = absf(float(delta[1]))
		if (x_axis and dx > 0.001 and dz <= 0.001) \
				or (not x_axis and dz > 0.001 and dx <= 0.001): return true
	return false
static func _impossible(report: Dictionary, id: String) -> bool:
	for row: Dictionary in report["impossibilities"]:
		if str(row["node_id"]) == id and not row["reason_ids"].is_empty(): return true
	return false

static func _input(nodes: Array, edges: Array, seed: int, quality: Dictionary,
		zones: Dictionary) -> MapLayoutInput:
	return MapLayoutInput.from_dict({"schema_version": 1, "generator_schema": "map-compiler-v2",
		"generator_version": "2.0.0-candidates.1", "nodes": nodes, "edges": edges,
		"act": 0, "run_seed": seed, "scenery_seed": seed + 97,
		"asset_profile_digest": _SHA,
		"camera_profile_digest": MapQualityEvaluator.camera_registry(nodes, quality)["digest"],
		"hero_anchor_contract": {"schema_version": 1,
			"anchors": {"vigil": {"profile_id": "vigil"}, "terminus": {"profile_id": "terminus"}},
			"protected_zones": zones}, "quality_registry_digest": MapLayoutCanonical.digest(quality)})
static func _node(id: String, row: int, col: int, type: String = "monster",
		jitter: Array = [0.0, 0.0]) -> Dictionary:
	return {"id": id, "row": row, "col": col, "type": type, "jitter": jitter}
static func _edge(from_id: String, to_id: String) -> Dictionary:
	return {"id": MapLayoutInput.edge_id(from_id, to_id), "from": from_id, "to": to_id}
static func _far_zones() -> Dictionary:
	return {"vigil-far": {"role": "vigil", "polygon": _box(Vector2(1000, 1000), 1.0)},
		"terminus-far": {"role": "terminus", "polygon": _box(Vector2(-1000, -1000), 1.0)}}
static func _box(center: Vector2, half: float) -> Array:
	return [[center.x - half, center.y - half], [center.x - half, center.y + half],
		[center.x + half, center.y + half], [center.x + half, center.y - half]]
static func _v3(value: Variant) -> Vector3:
	var row: Array = value
	return Vector3(float(row[0]), float(row[1]), float(row[2]))
