extends RefCounted
## #469 pure complete node-and-route compiler.

const Binding = preload("res://domain/map_layout/map_layout_input_binding.gd")

@warning_ignore_start("unsafe_call_argument")


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_layout_compiler: %s" % what)


static func run(fails: Array[String]) -> void:
	var quality: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://docs/map/map-quality-v2.json"
	))
	_test_complete_chain(fails, quality)
	_test_layered_route_plan(fails, quality)
	_test_crossing_detour(fails, quality)
	_test_three_way_fanout_merge(fails, quality)
	_test_bounded_local_substitution(fails, quality)
	_test_production_graphs(fails, quality)


static func _test_complete_chain(fails: Array[String], quality: Dictionary) -> void:
	var nodes: Array = [
		_node("A", 2, 3),
		_node("B", 7, 3),
		_node("C", 12, 3),
	]
	var edges: Array = [_edge("A", "B"), _edge("B", "C")]
	var assets: Dictionary = _assets()
	var hero: Dictionary = _hero()
	var input: MapLayoutInput = _input(nodes, edges, 717, 0, hero, quality, assets)
	var compiled: Dictionary = MapLayoutCompiler.compile(input, quality, assets)
	var result_v: Variant = compiled.get("result", null)
	var report: Dictionary = compiled.get("report", {})
	_check(fails, str(compiled.get("status", "")) == MapLayoutCompiler.COMPILED
			and result_v is MapLayoutResult,
		"a legal chain returns one complete MapLayoutResult")
	if not (result_v is MapLayoutResult):
		return
	var result: MapLayoutResult = result_v
	var serial: Dictionary = result.to_dict()
	var placement: Dictionary = serial["hero_placements"].get("vigil", {})
	_check(fails, serial["node_anchors"].size() == nodes.size()
			and serial["edges"].size() == edges.size()
			and serial["scenery_instances"].is_empty(),
		"the authoritative result contains every node and edge with empty scenery")
	_check(fails, placement == {
		"asset_id": "hero/vigil",
		"profile_id": "hero",
		"transform": {
			"origin": [100.0, 0.0, 100.0],
			"yaw_radians": 0.25,
			"scale": [1.0, 1.0, 1.0],
		},
	}, "hero anchors are copied canonically without movement")
	_check(fails, report.get("hard_pass", false) == true
			and str(report.get("layout_digest", "")) == result.digest()
			and serial["hard_measurements"] == report.get("hard_values", {})
			and serial["soft_scores"] == report.get("soft_raw", {}),
		"the second evaluator pass binds the final digest and stored vectors")
	var copy: MapLayoutResult = MapLayoutResult.from_dict(serial)
	_check(fails, copy != null and copy.canonical_bytes() == result.canonical_bytes(),
		"the compiled result round-trips through the immutable contract")


static func _test_layered_route_plan(fails: Array[String], quality: Dictionary) -> void:
	var nodes: Array = [
		_node("A", 3, 2),
		_node("B", 3, 3),
		_node("C", 4, 3),
		_node("D", 4, 2),
	]
	var edges: Array = [_edge("A", "C"), _edge("B", "D")]
	var assets: Dictionary = _assets()
	var input: MapLayoutInput = _input(
		nodes, edges, 717, 0, _hero(), quality, assets
	)
	var compiled: Dictionary = MapLayoutCompiler.compile(input, quality, assets)
	var diagnostics: Dictionary = compiled.get("diagnostics", {})
	var components: Array = diagnostics.get("inversion_components", [])
	var access: Dictionary = diagnostics.get("access_lengths", {})
	var calls: Dictionary = diagnostics.get("route_calls", {})
	var sides: Dictionary = diagnostics.get("chosen_bypass_sides", {})
	_check(fails, str(compiled.get("status", "")) == MapLayoutCompiler.COMPILED,
		"an adjacent-row inversion pair uses the bounded layered route plan: %s" \
		% str(compiled.get("failure", {})))
	_check(fails, diagnostics.get("route_order", []) == [
		MapLayoutInput.edge_id("A", "C"), MapLayoutInput.edge_id("B", "D"),
	] and components.size() == 1
			and components[0].get("source_row", -1) == 3
			and components[0].get("target_row", -1) == 4
			and components[0].get("edge_ids", []) == [
				MapLayoutInput.edge_id("A", "C"), MapLayoutInput.edge_id("B", "D"),
			],
		"route order and strict inversion components are canonical")
	_check(fails, is_equal_approx(float(access.get("A", {}).get("outgoing_m", 0.0)), 1.0)
			and is_equal_approx(float(access.get("C", {}).get("incoming_m", 0.0)), 1.0)
			and MapLayoutCanonical.int_value(calls.get("normal", 0)) == edges.size()
			and MapLayoutCanonical.int_value(calls.get("bypass", 0)) > 0
			and sides.size() == 1,
		"governed access lengths and one bounded pair bypass are reported: %s" \
			% str({"access": access, "calls": calls, "sides": sides}))
	if compiled.get("result", null) is MapLayoutResult:
		var result: MapLayoutResult = compiled["result"]
		var serial: Dictionary = result.to_dict()
		var first: Dictionary = serial["edges"][MapLayoutInput.edge_id("A", "C")]
		var line: Array = first["centerline"]
		_check(fails, line.size() >= 4
				and _v3(line[0]).is_equal_approx(MapPinProjection.lattice_point(3, 2))
				and is_equal_approx(_v3(line[1]).x - _v3(line[0]).x, 1.0),
			"the result prepends the straight governed source access stub")
	var reordered_nodes: Array = nodes.duplicate(true)
	var reordered_edges: Array = edges.duplicate(true)
	reordered_nodes.reverse()
	reordered_edges.reverse()
	var reordered: MapLayoutInput = _input(
		reordered_nodes, reordered_edges,
		717, 0, _hero(), quality, assets
	)
	var replay: Dictionary = MapLayoutCompiler.compile(reordered, quality, assets)
	var replay_result_v: Variant = replay.get("result", null)
	var compiled_result_v: Variant = compiled.get("result", null)
	var same_result: bool = false
	if replay_result_v is MapLayoutResult and compiled_result_v is MapLayoutResult:
		var replay_result: MapLayoutResult = replay_result_v
		var compiled_result: MapLayoutResult = compiled_result_v
		same_result = replay_result.canonical_bytes() == compiled_result.canonical_bytes()
	_check(fails, same_result and replay.get("diagnostics", {}).get(
			"diagnostics_digest", "") == diagnostics.get("diagnostics_digest", ""),
		"equivalent reordered input preserves result and diagnostic identity")


static func _test_crossing_detour(fails: Array[String], quality: Dictionary) -> void:
	var nodes: Array = [
		_node("A", 3, 2),
		_node("B", 3, 4),
		_node("C", 9, 4),
		_node("D", 9, 2),
	]
	var edges: Array = [_edge("A", "C"), _edge("B", "D")]
	var assets: Dictionary = _assets()
	var compiled: Dictionary = MapLayoutCompiler.compile(
		_input(nodes, edges, 17634, 0, _hero(), quality, assets), quality, assets
	)
	var result_v: Variant = compiled.get("result", null)
	_check(fails, str(compiled.get("status", "")) == MapLayoutCompiler.COMPILED
			and result_v is MapLayoutResult,
		"crossing shortest paths compile by routing one legal deterministic detour: %s" \
			% str(compiled.get("failure", {})))
	if not (result_v is MapLayoutResult):
		return
	var result: MapLayoutResult = result_v
	var serial: Dictionary = result.to_dict()
	var detoured: bool = false
	for edge_id: String in MapLayoutCanonical.sorted_keys(serial["edges"]):
		var edge: Dictionary = serial["edges"][edge_id]
		detoured = detoured or edge["centerline"].size() > 2
	_check(fails, detoured
			and MapLayoutCanonical.int_value(
				compiled["report"]["hard_values"]["unrelated_edge_intersection_count"]
			) == 0,
		"accepted unrelated corridors remain route obstacles instead of crossing")


static func _test_three_way_fanout_merge(fails: Array[String],
		quality: Dictionary) -> void:
	var nodes: Array = [
		_node("S", 2, 4),
		_node("A", 6, 2),
		_node("B", 6, 4),
		_node("C", 6, 6),
		_node("M", 10, 4),
		_node("T", 13, 4),
	]
	var edges: Array = [
		_edge("S", "A"), _edge("S", "B"), _edge("S", "C"),
		_edge("A", "M"), _edge("B", "M"), _edge("C", "M"),
		_edge("M", "T"),
	]
	var assets: Dictionary = _assets()
	var compiled: Dictionary = MapLayoutCompiler.compile(
		_input(nodes, edges, 717, 0, _hero(), quality, assets), quality, assets
	)
	var result_v: Variant = compiled.get("result", null)
	_check(fails, str(compiled.get("status", "")) == MapLayoutCompiler.COMPILED
			and result_v is MapLayoutResult,
		"three-way fan-out followed by merge compiles: %s" \
			% str(compiled.get("failure", {})))
	if not (result_v is MapLayoutResult):
		return
	var result: MapLayoutResult = result_v
	var serial: Dictionary = result.to_dict()
	var distinct_departures: Dictionary = {}
	for to_id: String in ["A", "B", "C"]:
		var edge_id: String = MapLayoutInput.edge_id("S", to_id)
		var centreline: Array = serial["edges"][edge_id]["centerline"]
		if centreline.size() > 1:
			distinct_departures[MapLayoutCanonical.canonical_text(centreline[1])] = true
	_check(fails, distinct_departures.size() == 3
			and MapLayoutCanonical.float_value(
				compiled["report"]["hard_values"]["branch_fanout_separation_px"]
			) >= 32.0,
		"alternatives diverge within the governed departure and pass the hard rule")


static func _test_bounded_local_substitution(fails: Array[String],
		quality: Dictionary) -> void:
	var nodes: Array = [
		_node("P", 2, 3),
		_node("A", 7, 5),
		_node("B", 7, 5),
		_node("Q", 12, 3),
	]
	var assets: Dictionary = _assets()
	var compiled: Dictionary = MapLayoutCompiler.compile(
		_input(nodes, [_edge("P", "Q")], 717, 0, _hero(), quality, assets),
		quality, assets
	)
	var diagnostics: Dictionary = compiled.get("diagnostics", {})
	var substitutions: Array = diagnostics.get("substitutions", [])
	var attempts: Array = diagnostics.get("attempts", [])
	var complete_attempts: bool = not attempts.is_empty()
	for attempt: Dictionary in attempts:
		complete_attempts = complete_attempts \
			and attempt.get("chosen_candidate_ids", {}).size() == nodes.size() \
			and attempt.get("routes", []).size() == 1
	_check(fails, str(compiled.get("status", "")) == MapLayoutCompiler.COMPILED
			and not substitutions.is_empty()
			and substitutions.size() <= MapLayoutCompiler.MAX_LOCAL_SUBSTITUTIONS,
		"a named binding drives at most 64 canonical local substitutions: %s" \
		% str({"failure": compiled.get("failure", {}),
			"substitutions": substitutions}))
	_check(fails, complete_attempts and attempts.size() == substitutions.size() + 1,
		"every evaluated substitution attempt remains a complete graph result")


static func _test_production_graphs(fails: Array[String], quality: Dictionary) -> void:
	var content: ContentDB = ContentDB.load_full()
	var assets: Dictionary = _assets()
	for fixture: Array in [[717, 0], [17634, 0], [717, 1], [717, 2], [717, 3]]:
		var seed: int = fixture[0]
		var act: int = fixture[1]
		var run_state: RunState = RunState.new_run(
			content, seed, "map-compiler-%d-%d" % [seed, act]
		)
		run_state.act = act
		var world: WorldMap = WorldMap.for_run(run_state, content)
		var bound: Dictionary = Binding.bind(world, act)
		var label: String = "seed %d Act %d" % [seed, act + 1]
		_check(fails, bound.get("ok", false) == true,
			"%s graph binds to MapLayoutInput records: %s" \
			% [label, bound.get("error", {})])
		if bound.get("ok", false) != true:
			continue
		var input: MapLayoutInput = _input(
			bound["nodes"], bound["edges"], seed, act, _hero(), quality, assets
		)
		var compiled: Dictionary = MapLayoutCompiler.compile(input, quality, assets)
		var result_v: Variant = compiled.get("result", null)
		_check(fails, str(compiled.get("status", "")) == MapLayoutCompiler.COMPILED
				and result_v is MapLayoutResult,
			"%s production graph compiles: %s" % [label, compiled.get("failure", {})])
		if result_v is MapLayoutResult:
			var result: MapLayoutResult = result_v
			var serial: Dictionary = result.to_dict()
			_check(fails, serial["node_anchors"].size() == world.nodes.size()
					and serial["edges"].size() == _world_edge_count(world)
					and compiled["report"].get("violations", []).is_empty(),
				"%s result contains the complete graph with zero hard violations" % label)
			if act == 3:
				_check(fails, serial["node_anchors"].get("n4", []) \
						== _a3(MapPinProjection.lattice_point(14, 3)),
					"Act IV boss binds to lattice row 14 / centre lane 3")
				_check(fails, _profile_margin(compiled["report"],
						"pad-landscape/z0/row-00") >= _hard_limit(
							quality, "focused_node_safe_frame_margin_px"),
					"the original Act IV camera profile clears its unchanged hard floor")


static func _input(nodes: Array, edges: Array, seed: int, act: int,
		hero: Dictionary, quality: Dictionary, assets: Dictionary) -> MapLayoutInput:
	return MapLayoutInput.from_dict({
		"schema_version": MapLayoutInput.SCHEMA_VERSION,
		"generator_schema": "map-compiler-v2",
		"generator_version": "map-layout-compiler-v1",
		"nodes": nodes,
		"edges": edges,
		"act": act,
		"run_seed": seed,
		"scenery_seed": seed + 97,
		"asset_profile_digest": assets["digest"],
		"camera_profile_digest": MapQualityEvaluator.camera_registry(nodes, quality)["digest"],
		"hero_anchor_contract": hero,
		"quality_registry_digest": MapLayoutCanonical.digest(quality),
	})


static func _world_edge_count(world: WorldMap) -> int:
	var count: int = 0
	for node: MapNode in world.nodes:
		count += node.next.size()
	return count


static func _profile_margin(report: Dictionary, profile_id: String) -> float:
	for row: Dictionary in report.get("raw_measurements", []):
		if str(row.get("metric_id", "")) == "focused_node_safe_frame_margin_px" \
				and str(row.get("profile_id", "")) == profile_id:
			return MapLayoutCanonical.float_value(row.get("value", -INF))
	return -INF


static func _hard_limit(quality: Dictionary, metric_id: String) -> float:
	for row: Dictionary in quality.get("hard", []):
		if str(row.get("id", "")) == metric_id:
			return MapLayoutCanonical.float_value(row.get("limit", INF))
	return INF


static func _assets() -> Dictionary:
	var profile: Dictionary = _profile("hero", Vector3(2.0, 3.0, 2.0))
	return {
		"profiles": {"hero": profile},
		"digest": MapAssetProfiles.new(MapQualityEvaluator.EMPTY_MANIFEST).digest([profile]),
	}


static func _hero() -> Dictionary:
	return {
		"schema_version": MapLayoutInput.HERO_ANCHOR_SCHEMA_VERSION,
		"anchors": {
			"vigil": {
				"asset_id": "hero/vigil",
				"profile_id": "hero",
				"position": [100.0, 0.0, 100.0],
				"yaw_radians": 0.25,
				"scale": [1.0, 1.0, 1.0],
			},
		},
		"protected_zones": {
			"vigil-zone": {
				"role": "vigil",
				"polygon": _box(Vector2(100.0, 100.0), 2.0),
			},
		},
	}


static func _profile(id: String, size: Vector3) -> Dictionary:
	var aabb: AABB = AABB(-size * 0.5, size)
	return {
		"profile_schema_version": MapAssetProfiles.PROFILE_SCHEMA_VERSION,
		"asset_id": id,
		"source_path": "synthetic/%s" % id,
		"source_mesh_identity": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		"local_aabb": aabb,
		"grounded_height": size.y,
		"local_footprint": PackedVector2Array([
			Vector2(aabb.position.x, aabb.position.z),
			Vector2(aabb.position.x, aabb.end.z),
			Vector2(aabb.end.x, aabb.end.z),
			Vector2(aabb.end.x, aabb.position.z),
		]),
		"default_scale": 1.0,
		"yaw_mode": MapAssetProfiles.YAW_FREE,
		"yaw_degrees": 0.0,
		"semantic_class": MapAssetProfiles.SEMANTIC_HERO,
		"footprint_source": "synthetic",
		"override_reason": "",
		"occlusion_model": "synthetic",
	}


static func _node(id: String, row: int, col: int,
		type: String = "monster", jitter: Array = [0.0, 0.0]) -> Dictionary:
	return {"id": id, "row": row, "col": col, "type": type, "jitter": jitter}


static func _edge(from_id: String, to_id: String) -> Dictionary:
	return {
		"id": MapLayoutInput.edge_id(from_id, to_id),
		"from": from_id,
		"to": to_id,
	}


static func _box(center: Vector2, half: float) -> Array:
	return [
		[center.x - half, center.y - half],
		[center.x - half, center.y + half],
		[center.x + half, center.y + half],
		[center.x + half, center.y - half],
	]


static func _a3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func _v3(value: Variant) -> Vector3:
	var row: Array = value
	return Vector3(
		MapLayoutCanonical.float_value(row[0]),
		MapLayoutCanonical.float_value(row[1]),
		MapLayoutCanonical.float_value(row[2])
	)
