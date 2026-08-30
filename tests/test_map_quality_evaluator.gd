extends RefCounted
@warning_ignore_start("unsafe_call_argument")
const Contract = preload("res://tests/test_map_layout_contract.gd")
const Binding = preload("res://domain/map_layout/map_layout_input_binding.gd")
const Grade = preload("res://presentation/map/map_grade_separation.gd")
static func _ok(fails: Array[String], value: bool, text: String) -> void:
	if not value: fails.append("test_map_quality_evaluator: " + text)
static func run(fails: Array[String]) -> void:
	var quality: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/map-quality-v2.json"))
	var assets: Dictionary = _assets()
	_test_registry(fails, quality)
	_test_focused_camera_binding(fails, quality, assets)
	_test_selection_screen_feasibility(fails, quality, assets)
	_test_nodes_and_phone(fails, quality, assets)
	_test_routes(fails, quality, assets)
	_test_grade_separation(fails, quality, assets)
	_test_fanout(fails, quality, assets)
	_test_seed_717(fails, quality, assets)
static func _test_registry(fails: Array[String], quality: Dictionary) -> void:
	var nodes: Array = [_node("A", 2, 3), _node("B", 9, 3)]
	var a: Dictionary = MapQualityEvaluator.camera_registry(nodes, quality)
	var reversed: Array = nodes.duplicate(true); reversed.reverse()
	var b: Dictionary = MapQualityEvaluator.camera_registry(reversed, quality)
	_ok(fails, str(a["digest"]) == str(b["digest"]) and a["profiles"].size() == 132 and str(a["profiles"][0]["digest"]).length() == 64 and is_equal_approx(float(a["profiles"][0]["flex_cap"]), StageShape.FLEX_CAP),
		"three shapes, four zooms, opening, occupied rows and eight pan poses are stable under reordered input")
	var inset: float = MapQualityEvaluator.focused_touch_inset_px(quality)
	for profile: Dictionary in a["profiles"]:
		if str(profile["kind"]) != "focus": continue
		var focus: Dictionary = nodes[0] if str(profile["focus"]) == "A" else nodes[1]
		var world: Vector3 = _seat(focus)
		_ok(fails, _v2(profile["pose"]).is_equal_approx(_old_focus_pose(
			world, _v2(profile["stage"]), _f(profile["zoom"]))),
			"centre-lane profile %s retains the preferred 0.7 pose" % profile["id"])
	var rig: MapCameraRig = MapCameraRig.new(); rig.set_zoom_stop(0)
	var live_world: Vector3 = _seat(nodes[0])
	var live_stage: Vector2 = Vector2(StageShape.REFERENCES[StageShape.IDENTITY])
	var live_envelope: Rect2 = MapQualityEvaluator.focused_anchor_envelope(
		"A", MapQualityEvaluator.node_candidate_bounds(nodes, [], quality))
	var live_pose: Vector2 = rig.pose_leading(live_world, live_stage, inset, live_envelope)
	var evaluator_profile: Dictionary = _camera_profile(a, "pad-landscape/z0/row-02")
	_ok(fails, live_pose.is_equal_approx(_v2(evaluator_profile["pose"])),
		"live and evaluator calls produce the same pose from the same explicit inputs")
	var impossible: Dictionary = MapCameraRig.resolve_leading(live_world, live_stage,
		MapCameraRig.ZOOM_STOPS[0], live_stage.y * 0.5, live_envelope)
	_ok(fails, impossible.get("ok", true) == false
		and impossible.get("failure", {}).has("stage")
		and impossible.get("failure", {}).has("zoom"),
		"an impossible inset fails closed with exact stage and zoom geometry")
	rig.free()


static func _test_focused_camera_binding(fails: Array[String], quality: Dictionary,
		assets: Dictionary) -> void:
	var content: ContentDB = ContentDB.load_full()
	var required: float = _f(MapQualityEvaluator._index(quality["hard"])[
		"focused_node_safe_frame_margin_px"]["limit"])
	for fixture: Array in [[717, "6,0", -63.23927475, 9],
			[17634, "9,0", -74.61313034, 6]]:
		var seed: int = MapLayoutCanonical.int_value(fixture[0])
		var focus_id: String = str(fixture[1])
		var state: RunState = RunState.new_run(content, seed, "focus-binding-%d" % seed)
		var bound: Dictionary = Binding.bind(WorldMap.for_run(state, content), 0)
		var nodes: Array = bound["nodes"]
		var input: MapLayoutInput = MapLayoutInput.from_dict({
			"schema_version": MapLayoutInput.SCHEMA_VERSION,
			"generator_schema": "map-compiler-v2",
			"generator_version": "map-camera-focus-test-v1",
			"nodes": nodes, "edges": bound["edges"], "act": 0,
			"run_seed": seed, "scenery_seed": seed + 97,
			"asset_profile_digest": assets["digest"],
			"camera_profile_digest": MapQualityEvaluator.camera_registry(
				nodes, quality, bound["edges"])["digest"],
			"quality_registry_digest": MapLayoutCanonical.digest(quality),
			"hero_anchor_contract": _hero(),
		})
		var node_sets: Dictionary = MapNodeCandidateGenerator.generate(
			input, quality, 0)["node_sets"]
		var node_set: Dictionary = node_sets[focus_id]
		var registry: Dictionary = MapQualityEvaluator.camera_registry(
			nodes, quality, bound["edges"])
		var reversed_nodes: Array = nodes.duplicate(true); reversed_nodes.reverse()
		var reversed_edges: Array = bound["edges"].duplicate(true); reversed_edges.reverse()
		var reordered_registry: Dictionary = MapQualityEvaluator.camera_registry(
			reversed_nodes, quality, reversed_edges)
		_ok(fails, registry["profiles"] == reordered_registry["profiles"]
			and str(registry["digest"]) == str(reordered_registry["digest"]),
			"seed %d edge-aware camera profiles survive equivalent input reorder" % seed)
		var focus_envelopes: Dictionary = MapQualityEvaluator.node_candidate_bounds(
			nodes, bound["edges"], quality)
		var profile_id: String = "pad-landscape/z0/row-%02d" % int(focus_id.split(",")[0])
		var governed: Dictionary = _camera_profile(registry, profile_id)
		var world: Vector3 = _v3(node_set["authored_anchor"])
		var old: Dictionary = governed.duplicate(true)
		old["pose"] = _a2(_old_focus_pose(world, _v2(old["stage"]), _f(old["zoom"])))
		var old_best: float = -INF
		var governed_worst: float = INF
		for candidate: Dictionary in node_set["candidates"]:
			var anchor: Vector3 = _v3(candidate["anchor"])
			old_best = maxf(old_best, _focus_margin(anchor, old, quality))
			governed_worst = minf(governed_worst, _focus_margin(anchor, governed, quality))
		_ok(fails, node_set["candidates"].size() == MapLayoutCanonical.int_value(fixture[3])
			and absf(old_best - _f(fixture[2])) <= 0.001
			and old_best < required,
			"old unconditional 0.7 reproduces seed %d %s at %s" % [seed, focus_id, profile_id])
		_ok(fails, governed_worst >= required,
			"every legal seed %d %s candidate clears the unchanged 8 px floor" % [seed, focus_id])
		var unchanged: bool = true
		var unchanged_count: int = 0
		for profile: Dictionary in registry["profiles"]:
			if str(profile["kind"]) != "focus":
				continue
			var profile_focus: String = str(profile["focus"])
			var profile_set: Dictionary = node_sets[profile_focus]
			var profile_world: Vector3 = _v3(profile_set["authored_anchor"])
			var old_profile: Dictionary = profile.duplicate(true)
			old_profile["pose"] = _a2(_old_focus_pose(profile_world,
				_v2(profile["stage"]), _f(profile["zoom"])))
			var profile_envelope: Rect2 = MapQualityEvaluator.focused_anchor_envelope(
				profile_focus, focus_envelopes)
			var resolved: Dictionary = MapCameraRig.resolve_leading(profile_world,
				_v2(profile["stage"]), _f(profile["zoom"]),
				MapQualityEvaluator.focused_touch_inset_px(quality), profile_envelope)
			if not is_equal_approx(_f(resolved.get("effective_pull", -1.0)),
					MapCameraRig.LANE_PULL):
				continue
			unchanged_count += 1
			unchanged = unchanged and _v2(profile["pose"]).is_equal_approx(
				_v2(old_profile["pose"]))
		_ok(fails, unchanged and unchanged_count > 0,
			"every non-binding seed %d stage and zoom keeps the exact 0.7 pose" % seed)
		var rig: MapCameraRig = MapCameraRig.new(); rig.set_zoom_stop(0)
		var stage: Vector2 = _v2(governed["stage"])
		var envelope: Rect2 = MapQualityEvaluator.focused_anchor_envelope(
			focus_id, focus_envelopes)
		_ok(fails, rig.pose_leading(world, stage,
			MapQualityEvaluator.focused_touch_inset_px(quality), envelope).is_equal_approx(
				_v2(governed["pose"])),
			"seed %d live and evaluator focused poses share one resolver" % seed)
		rig.free()
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


static func _test_selection_screen_feasibility(fails: Array[String],
		quality: Dictionary, assets: Dictionary) -> void:
	var nodes: Array = [_node("A", 4, 3), _node("B", 4, 3)]
	var seat: Vector3 = _seat(nodes[0])
	var heroes: Dictionary = {
		"vigil": _placement("hero", "hero", Vector3(100.0, 0.0, 100.0)),
	}
	var failing_anchors: Dictionary = {"A": _a3(seat), "B": _a3(seat)}
	var failing: Dictionary = MapQualityEvaluator.selection_screen_feasibility(
		nodes, [], failing_anchors, heroes, assets, quality, ["A", "B"]
	)
	var shared: Dictionary = MapQualityEvaluator.selection_screen_context(
		nodes, [], heroes, assets, quality)
	var failing_cached: Dictionary = MapQualityEvaluator.selection_screen_feasibility(
		nodes, [], failing_anchors, heroes, assets, quality, ["A", "B"], shared
	)
	var terminus: Dictionary = {
		"terminus": _placement("hero", "hero", seat),
	}
	var terminus_context: Dictionary = MapQualityEvaluator.selection_screen_context(
		nodes, [], terminus, assets, quality)
	var terminus_overlap: Dictionary = MapQualityEvaluator.selection_screen_feasibility(
		nodes, [], {"A": _a3(seat)}, terminus, assets, quality, ["A"],
		terminus_context)
	_ok(fails, terminus_overlap.get("hard_pass", true) == false
			and _has(terminus_overlap, "node_hero_silhouette_overlap_area_px2",
				"A", "hero_placements:terminus"),
		"cached screen preflight reports a close terminus with its world evidence")
	var failing_direct: Dictionary = _case(
		nodes, failing_anchors, [], {}, quality, assets
	)
	var passing_anchors: Dictionary = {
		"A": _a3(seat + Vector3(-2.0, 0.0, -2.3)),
		"B": _a3(seat + Vector3(2.0, 0.0, 2.3)),
	}
	var passing: Dictionary = MapQualityEvaluator.selection_screen_feasibility(
		nodes, [], passing_anchors, heroes, assets, quality, ["A", "B"]
	)
	var passing_cached: Dictionary = MapQualityEvaluator.selection_screen_feasibility(
		nodes, [], passing_anchors, heroes, assets, quality, ["A", "B"], shared
	)
	var near_hero: Dictionary = {
		"vigil": _placement("hero", "hero", seat + Vector3(4.0, 0.0, 0.0)),
	}
	var far_hero: Dictionary = {
		"vigil": _placement("hero", "hero", seat + Vector3(20.0, 0.0, 0.0)),
	}
	var near_context: Dictionary = MapQualityEvaluator.selection_screen_context(
		nodes, [], near_hero, assets, quality)
	var far_context: Dictionary = MapQualityEvaluator.selection_screen_context(
		nodes, [], far_hero, assets, quality)
	var near_clear: Dictionary = MapQualityEvaluator.selection_screen_feasibility(
		nodes, [], {"A": _a3(seat)}, near_hero, assets, quality, ["A"],
		near_context)
	var far_clear: Dictionary = MapQualityEvaluator.selection_screen_feasibility(
		nodes, [], {"A": _a3(seat)}, far_hero, assets, quality, ["A"],
		far_context)
	var passing_direct: Dictionary = _case(
		nodes, passing_anchors, [], {}, quality, assets
	)
	_ok(fails, failing.get("hard_pass", true) == false
			and failing.get("hard_values", {}).get("node_ink_clearance_px", INF)
				== failing_direct.get("hard_values", {}).get(
					"node_ink_clearance_px", -INF)
			and failing.get("rejection_reason", {}).get("metric_id", "") \
				== "node_ink_clearance_px",
		"selection precheck reuses the direct #466 failure and exact margin")
	_ok(fails, passing.get("hard_pass", false) == true
			and passing.get("hard_values", {}).get("node_ink_clearance_px", -INF)
				== passing_direct.get("hard_values", {}).get(
					"node_ink_clearance_px", INF)
			and MapLayoutCanonical.float_value(
				passing.get("weakest_signed_hard_margin", -INF)) >= 0.0,
		"selection precheck accepts the same screen-legal local anchors as #466")
	_ok(fails, near_clear.get("hard_pass", false) == true
			and far_clear.get("hard_pass", false) == true
			and not is_equal_approx(_f(near_clear["hard_values"][
				"node_ink_clearance_px"]), _f(far_clear["hard_values"][
				"node_ink_clearance_px"]))
			and is_equal_approx(_f(near_clear["weakest_signed_hard_margin"]),
				_f(far_clear["weakest_signed_hard_margin"])),
		"passed hero clearance remains hard evidence without reordering priority")
	var exact_fields: Array[String] = ["hard_pass", "local_node_ids", "hard_values",
		"hard_margins", "priority_metric_ids", "weakest_signed_hard_margin",
		"rejection_reason"]
	var cached_exact: bool = true
	for field: String in exact_fields:
		cached_exact = cached_exact and failing.get(field) == failing_cached.get(field) \
			and passing.get(field) == passing_cached.get(field)
	_ok(fails, cached_exact,
		"shared-context unary/pair summaries are byte-exact with direct #466 fields")


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


static func _test_grade_separation(fails: Array[String], quality: Dictionary,
		assets: Dictionary) -> void:
	var nodes: Array = [
		_node("A", 2, 1), _node("B", 2, 5),
		_node("C", 10, 5), _node("D", 10, 1),
	]
	var anchors: Dictionary = {}
	for node: Dictionary in nodes:
		anchors[str(node["id"])] = _a3(_seat(node))
	var first_id: String = MapLayoutInput.edge_id("A", "C")
	var second_id: String = MapLayoutInput.edge_id("B", "D")
	var routes: Dictionary = {
		first_id: {"from": "A", "to": "C",
			"centerline": [anchors["A"], anchors["C"]],
			"corridor_width": 0.72},
		second_id: {"from": "B", "to": "D",
			"centerline": [anchors["B"], anchors["D"]],
			"corridor_width": 0.72},
	}
	var graded: Dictionary = Grade.apply(routes, quality)
	var graded_routes: Dictionary = graded.get("routes", {})
	_ok(fails, graded.get("ok", false) == true,
		"governed grade solver finds an orientation: %s" \
			% str(graded.get("binding", {})))
	if graded.get("ok", false) != true:
		return
	var paths: Array = []
	for edge_id: String in MapLayoutCanonical.sorted_keys(graded_routes):
		var edge: Dictionary = graded_routes[edge_id]
		paths.append([edge["from"], edge["to"], edge["centerline"]])
	var report: Dictionary = _case(nodes, anchors, paths, {}, quality, assets)
	_ok(fails, graded.get("ok", false) == true
			and graded.get("receipt", {}).get("bridge_span_count", 0) == 1
			and report.get("hard_pass", false) == true
			and MapLayoutCanonical.float_value(
				report.get("hard_values", {}).get("minimum_vertical_clearance_m", 0.0)
			) >= Grade.MINIMUM_VERTICAL_CLEARANCE_M
			and MapLayoutCanonical.float_value(
				report.get("hard_values", {}).get("maximum_ramp_grade", INF)
			) <= Grade.MAXIMUM_RAMP_GRADE + MapLayoutCanonical.float_value(
				quality["epsilon"]["world_m"]),
		"one governed local bridge makes a proper crossing physically valid: %s" \
			% str({"error": report.get("case_error", []),
				"hard_pass": report.get("hard_pass", false),
				"hard_values": report.get("hard_values", {}),
				"violations": report.get("violations", []),
				"grade": graded.get("receipt", {})}))
	var flattened_paths: Array = []
	for edge_id: String in MapLayoutCanonical.sorted_keys(graded_routes):
		var edge: Dictionary = graded_routes[edge_id]
		var flattened: Array = []
		for point_v: Variant in edge["centerline"]:
			var point: Vector3 = _v3(point_v)
			flattened.append([point.x, 0.0, point.z])
		flattened_paths.append([edge["from"], edge["to"], flattened])
	var flattened: Dictionary = _case(
		nodes, anchors, flattened_paths, {}, quality, assets
	)
	_ok(fails, flattened.get("hard_pass", true) == false
			and MapLayoutCanonical.int_value(flattened.get(
				"hard_values", {}).get("unrelated_edge_intersection_count", 0)) == 1,
		"flattening the selected bridge restores the same-level crossing failure: %s" \
			% str(flattened.get("case_error", flattened.get("violations", []))))
	var touching: Dictionary = Grade.apply({
		"touch-a": {"from": "A", "to": "B", "corridor_width": 0.72,
			"centerline": [[-2.0, 0.0, 0.0], [2.0, 0.0, 0.0]]},
		"touch-b": {"from": "C", "to": "D", "corridor_width": 0.72,
			"centerline": [[0.0, 0.0, 0.0], [0.0, 0.0, 2.0]]},
	}, quality)
	_ok(fails, touching.get("ok", true) == false
			and touching.get("binding", {}).get("id", "") \
				== "ambiguous_xz_overlap",
		"a tangential endpoint touch is not reclassified as a proper crossing")
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
		"camera_profile_digest": MapQualityEvaluator.camera_registry(
			nodes, quality, topology)["digest"],
		"quality_registry_digest": MapLayoutCanonical.digest(quality), "hero_anchor_contract": _hero()}
	var input: MapLayoutInput = MapLayoutInput.from_dict(input_raw)
	var identity: Dictionary = {"schema_version": 1, "generator_version": "2.0.0-test",
		"node_anchors": anchors, "edges": routed, "hero_placements": {
			"vigil": _placement("hero", "hero", Vector3(100, 0, 100))},
		"scenery_instances": scenery, "hard_measurements": {}, "soft_scores": {},
		"selected_restart_id": 0, "selected_candidate_id": "test", "input_digest": input.digest()}
	var result: MapLayoutResult = MapLayoutResult.create(identity)
	if result == null:
		return {"case_error": MapLayoutResult.validate_identity(identity)}
	return MapQualityEvaluator.evaluate(input, result, assets, quality)
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
static func _a2(value: Vector2) -> Array[float]:
	return [value.x, value.y]
static func _v2(value: Variant) -> Vector2:
	var row: Array = value
	return Vector2(_f(row[0]), _f(row[1]))
static func _v3(value: Variant) -> Vector3:
	var row: Array = value
	return Vector3(_f(row[0]), _f(row[1]), _f(row[2]))
static func _f(value: Variant) -> float:
	return MapLayoutCanonical.float_value(value)
static func _camera_profile(registry: Dictionary, id: String) -> Dictionary:
	for profile: Dictionary in registry["profiles"]:
		if str(profile["id"]) == id: return profile
	return {}
static func _old_focus_pose(world: Vector3, stage: Vector2, zoom: float) -> Vector2:
	var bounds: Rect2 = MapCameraRig.bounds_from_lattice()
	var pose: Vector2 = Vector2(world.x + (0.5 - MapCameraRig.LEAD_X)
		* zoom * stage.x / stage.y,
		lerpf(world.z, 0.0, MapCameraRig.LANE_PULL) + MapCameraRig.look_dz())
	return Vector2(clampf(pose.x, bounds.position.x, bounds.end.x),
		clampf(pose.y, bounds.position.y, bounds.end.y))
static func _focus_margin(world: Vector3, profile: Dictionary,
		quality: Dictionary) -> float:
	var projected: Vector2 = MapQualityEvaluator._project(world, profile)
	var stage: Vector2 = _v2(profile["stage"])
	var required: float = _f(MapQualityEvaluator._index(quality["hard"])[
		"focused_node_safe_frame_margin_px"]["limit"])
	var touch_half: float = MapQualityEvaluator.focused_touch_inset_px(quality) - required
	return minf(minf(projected.x, stage.x - projected.x),
		minf(projected.y, stage.y - projected.y)) - touch_half
static func _has(report: Dictionary, metric: String, a: String, b: String) -> bool:
	for row: Dictionary in report["violations"]:
		if str(row["metric_id"]) == metric and str(row["entities"]).contains(a) \
				and (b.is_empty() or str(row["entities"]).contains(b)): return true
	return false
static func _has_profile(report: Dictionary, metric: String, profile: String) -> bool:
	for row: Dictionary in report["violations"]:
		if str(row["metric_id"]) == metric and str(row["profile_id"]).contains(profile): return true
	return false
