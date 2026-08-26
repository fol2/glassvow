extends RefCounted
@warning_ignore_start("unsafe_call_argument")
const Contract = preload("res://tests/test_map_layout_contract.gd")
static func _ok(fails: Array[String], value: bool, text: String) -> void:
	if not value: fails.append("test_map_quality_evaluator: " + text)
static func run(fails: Array[String]) -> void:
	var quality: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/map-quality-v2.json"))
	var assets: Dictionary = _assets()
	_test_registry(fails, quality)
	_test_nodes_and_phone(fails, quality, assets)
	_test_routes(fails, quality, assets)
	_test_fanout(fails, quality, assets)
	_test_seed_717(fails, quality, assets)
static func _test_registry(fails: Array[String], quality: Dictionary) -> void:
	var nodes: Array = [_node("A", 2, 3), _node("B", 9, 3)]
	var a: Dictionary = MapQualityEvaluator.camera_registry(nodes, quality)
	var b: Dictionary = MapQualityEvaluator.camera_registry(nodes.duplicate(true), quality)
	_ok(fails, str(a["digest"]) == str(b["digest"]) and a["profiles"].size() == 132 and str(a["profiles"][0]["digest"]).length() == 64 and is_equal_approx(float(a["profiles"][0]["flex_cap"]), StageShape.FLEX_CAP),
		"three shapes, four zooms, opening, occupied rows and eight pan poses are stable")
static func _test_nodes_and_phone(fails: Array[String], quality: Dictionary, assets: Dictionary) -> void:
	var nodes: Array = [_node("A", 4, 3), _node("B", 4, 3)]
	var seat: Vector3 = _seat(nodes[0])
	var anchors: Dictionary = {"A": _a3(seat + Vector3(-2.0, 0.0, -2.3)),
		"B": _a3(seat + Vector3(2.0, 0.0, 2.3))}
	var clean: Dictionary = _case(nodes, anchors, [], {}, quality, assets)
	_ok(fails, clean["hard_pass"], "separated synthetic nodes pass all governed profiles")
	anchors["B"] = anchors["A"]
	var overlap: Dictionary = _case(nodes, anchors, [], {}, quality, assets)
	_ok(fails, not overlap["hard_pass"] and _has(overlap, "node_node_ink_overlap_area_px2", "A", "B"),
		"overlap mutation names both nodes")
	var one: Array = [_node("N", 4, 3)]
	var nseat: Vector3 = _seat(one[0])
	var scenery: Dictionary = {"wall": _placement("wall", "wall", nseat + Vector3(5.8, 0.0, 0.0))}
	var phone: Dictionary = _case(one, {"N": _a3(nseat)}, [], scenery, quality, assets)
	_ok(fails, _has_profile(phone, "node_scenery_silhouette_overlap_area_px2", "phone-landscape/z3/")
		and not _has_profile(phone, "node_scenery_silhouette_overlap_area_px2", "pad-landscape/z3/"),
		"elongated polygon fails only the widest phone profile, not pad")
static func _test_routes(fails: Array[String], quality: Dictionary, assets: Dictionary) -> void:
	var ab: Array = [_node("A", 2, 3), _node("B", 10, 3)]
	var aa: Vector3 = _seat(ab[0]); var bb: Vector3 = _seat(ab[1])
	var through: Dictionary = _case(ab, {"A": _a3(aa), "B": _a3(bb)},
		[["A", "B", [_a3(aa), _a3((aa + bb) * 0.5), _a3(bb)]]],
		{"wall": _placement("wall", "wall", (aa + bb) * 0.5)}, quality, assets)
	_ok(fails, _has(through, "edge_scenery_corridor_penetration_m", "A", "wall") and is_zero_approx(float(through["soft_raw"]["bend_angle_deg_per_edge"])),
		"edge-through-polygon names entities and straight three-point route has zero bend")
	var cross_nodes: Array = [_node("A", 2, 1), _node("B", 2, 5), _node("C", 10, 5), _node("D", 10, 1)]
	var ca: Vector3 = _seat(cross_nodes[0]); var cb: Vector3 = _seat(cross_nodes[1])
	var cc: Vector3 = _seat(cross_nodes[2]); var cd: Vector3 = _seat(cross_nodes[3])
	var cross: Dictionary = _case(cross_nodes, {"A": _a3(ca), "B": _a3(cb), "C": _a3(cc), "D": _a3(cd)},
		[["A", "C", [_a3(ca), _a3(cc)]], ["B", "D", [_a3(cb), _a3(cd)]]], {}, quality, assets)
	_ok(fails, int(cross["hard_values"]["unrelated_edge_intersection_count"]) == 1,
		"two unrelated crossing edges fail")
	var shared: Dictionary = _case(cross_nodes, {"A": _a3(ca), "B": _a3(cb), "C": _a3(cc), "D": _a3(cd)},
		[["A", "C", [_a3(ca), _a3(cc)]], ["A", "D", [_a3(ca), _a3(cd)]]], {}, quality, assets)
	_ok(fails, int(shared["hard_values"]["unrelated_edge_intersection_count"]) == 0,
		"shared graph endpoint is legal")
static func _test_fanout(fails: Array[String], quality: Dictionary, assets: Dictionary) -> void:
	var nodes: Array = [_node("S", 2, 3), _node("A", 10, 1), _node("B", 10, 5)]
	var s: Vector3 = _seat(nodes[0]); var a: Vector3 = _seat(nodes[1]); var b: Vector3 = _seat(nodes[2])
	var anchors: Dictionary = {"S": _a3(s), "A": _a3(a), "B": _a3(b)}
	var open: Array = [["S", "A", [_a3(s), _a3(s + Vector3(4, 0, -4)), _a3(a)]],
		["S", "B", [_a3(s), _a3(s + Vector3(4, 0, 4)), _a3(b)]]]
	var good: Dictionary = _case(nodes, anchors, open, {}, quality, assets)
	var epsilon_quality: Dictionary = quality.duplicate(true); var epsilon_hard: Dictionary = MapQualityEvaluator._index(epsilon_quality["hard"]); epsilon_hard["branch_fanout_separation_px"]["limit"] = float(good["hard_values"]["branch_fanout_separation_px"]) + 0.1; var epsilon_case: Dictionary = _case(nodes, anchors, open, {}, epsilon_quality, assets)
	_ok(fails, float(good["hard_values"]["branch_fanout_separation_px"]) >= 32.0 and float(epsilon_case["hard_values"]["branch_fanout_separation_px"]) + float(epsilon_quality["epsilon"]["screen_px"]) >= float(epsilon_hard["branch_fanout_separation_px"]["limit"]) and not _has(epsilon_case, "branch_fanout_separation_px", "S", ""), "acceptable and within-epsilon fan-out produce consistent outcomes")
	var closed: Array = [["S", "A", [_a3(s), _a3(s + Vector3(6, 0, 0)), _a3(a)]],
		["S", "B", [_a3(s), _a3(s + Vector3(6, 0, 0)), _a3(b)]]]
	var bad: Dictionary = _case(nodes, anchors, closed, {}, quality, assets)
	_ok(fails, _has(bad, "branch_fanout_separation_px", "S", ""),
		"collapsed branch mutation names its decision source")
static func _test_seed_717(fails: Array[String], quality: Dictionary, assets: Dictionary) -> void:
	var fixture: Dictionary = Contract._input_fixture()
	var raw: Dictionary = fixture["raw"]; var nodes: Array = raw["nodes"]
	var anchors: Dictionary = {}; var paths: Array = []
	for node: Dictionary in nodes: anchors[str(node["id"])] = _a3(_seat(node))
	for edge: Dictionary in raw["edges"]:
		paths.append([edge["from"], edge["to"], [anchors[edge["from"]], anchors[edge["to"]]]])
	var first: Dictionary = _case(nodes, anchors, paths, {}, quality, assets)
	var second: Dictionary = _case(nodes.duplicate(true), anchors.duplicate(true), paths.duplicate(true), {}, quality, assets)
	_ok(fails, str(first["report_digest"]) == str(second["report_digest"])
		and first["violations"] == second["violations"], "seed 717 report ordering and digest replay")
static func _case(nodes: Array, anchors: Dictionary, paths: Array, scenery: Dictionary,
		quality: Dictionary, assets: Dictionary) -> Dictionary:
	var topology: Array = []; var routed: Dictionary = {}
	for path: Array in paths:
		var id: String = MapLayoutInput.edge_id(str(path[0]), str(path[1]))
		topology.append({"id": id, "from": path[0], "to": path[1]})
		routed[id] = {"from": path[0], "to": path[1], "centerline": path[2], "corridor_width": 0.72}
	var input_raw: Dictionary = {"schema_version": 1, "generator_schema": "map-compiler-v2",
		"generator_version": "2.0.0-test", "nodes": nodes, "edges": topology, "act": 0,
		"run_seed": 717, "scenery_seed": 717, "asset_profile_digest": assets["digest"],
		"camera_profile_digest": MapQualityEvaluator.camera_registry(nodes, quality)["digest"],
		"quality_registry_digest": MapLayoutCanonical.digest(quality), "hero_anchor_contract": _hero()}
	var input: MapLayoutInput = MapLayoutInput.from_dict(input_raw)
	var identity: Dictionary = {"schema_version": 1, "generator_version": "2.0.0-test",
		"node_anchors": anchors, "edges": routed, "hero_placements": {
			"vigil": _placement("hero", "hero", Vector3(100, 0, 100))},
		"scenery_instances": scenery, "hard_measurements": {}, "soft_scores": {},
		"selected_restart_id": 0, "selected_candidate_id": "test", "input_digest": input.digest()}
	return MapQualityEvaluator.evaluate(input, MapLayoutResult.create(identity), assets, quality)
static func _assets() -> Dictionary:
	var profiles: Dictionary = {"hero": _profile("hero", Vector3(2, 3, 2)),
		"wall": _profile("wall", Vector3(8, 2, 1))}
	var list: Array[Dictionary] = [profiles["hero"], profiles["wall"]]
	return {"profiles": profiles, "digest": MapAssetProfiles.new({"assets": []}).digest(list)}
static func _profile(id: String, size: Vector3) -> Dictionary:
	var aabb: AABB = AABB(-size * 0.5, size)
	return {"asset_id": id, "source_path": "synthetic/" + id, "source_mesh_identity":
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		"local_aabb": aabb, "grounded_height": size.y, "local_footprint":
		PackedVector2Array([Vector2(aabb.position.x, aabb.position.z),
			Vector2(aabb.position.x, aabb.end.z), Vector2(aabb.end.x, aabb.end.z),
			Vector2(aabb.end.x, aabb.position.z)]), "default_scale": 1.0,
		"yaw_mode": "free", "yaw_degrees": 0.0, "semantic_class": "hero" if id == "hero" else "scenery",
		"footprint_source": "synthetic", "override_reason": "", "occlusion_model": "synthetic"}
static func _hero() -> Dictionary:
	return {"schema_version": 1, "anchors": {"vigil": {"protected_zone_id": "vigil-zone"}},
		"protected_zones": {"vigil-zone": {"role": "vigil",
			"polygon": [[98.0, 98.0], [98.0, 102.0], [102.0, 102.0], [102.0, 98.0]]}}}
static func _placement(asset: String, profile: String, origin: Vector3) -> Dictionary:
	var out: Dictionary = {"asset_id": asset, "profile_id": profile,
		"transform": {"origin": _a3(origin), "yaw_radians": 0.0, "scale": [1.0, 1.0, 1.0]}}
	if asset != "hero": out["semantic_zone"] = "midground"
	return out
static func _node(id: String, row: int, col: int) -> Dictionary:
	return {"id": id, "row": row, "col": col, "type": "monster", "jitter": [0.0, 0.0]}
static func _seat(node: Dictionary) -> Vector3:
	return MapPinProjection.sample(float(node["row"]), float(node["col"]))
static func _a3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
static func _has(report: Dictionary, metric: String, a: String, b: String) -> bool:
	for row: Dictionary in report["violations"]:
		if str(row["metric_id"]) == metric and str(row["entities"]).contains(a) \
				and (b.is_empty() or str(row["entities"]).contains(b)): return true
	return false
static func _has_profile(report: Dictionary, metric: String, profile: String) -> bool:
	for row: Dictionary in report["violations"]:
		if str(row["metric_id"]) == metric and str(row["profile_id"]).contains(profile): return true
	return false
