extends RefCounted
@warning_ignore_start("unsafe_call_argument")
## Spatial policy must preserve legacy coordinates and reject invalid new domains.
const Fixtures = preload("res://tests/test_map_node_candidate_generator.gd")
const Routes = preload("res://presentation/map/map_layout_compiler_routes.gd")
const Profile = preload("res://presentation/map/map_spatial_profile.gd")

static func run(fails: Array[String]) -> void:
	var quality: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://docs/map/map-quality-v2.json"))
	var calibration: Dictionary = quality["calibration"]["stage_zoom_geometry"]
	for row: int in range(15):
		for col: int in range(7):
			for jitter: Array in [[0.0, 0.0], [-0.12, 0.18], [0.17, -0.1]]:
				var node: Dictionary = {"row": row, "col": col, "jitter": jitter}
				var cell: Vector2 = Vector2(float(calibration["cell_m"][0]), float(calibration["cell_m"][1]))
				var origin: Vector2 = Vector2(float(calibration["origin_xz_m"][0]), float(calibration["origin_xz_m"][1]))
				var offset: Vector2 = Vector2(float(jitter[0]), float(jitter[1]))
				var old: Vector3 = Vector3(origin.x + (float(row) + offset.y) * cell.x,
					0.0, origin.y + (float(col) + offset.x) * cell.y)
				_check(fails, Profile.anchor(node, quality) == old, "legacy exact anchor")
	_check(fails, Profile.footprint(quality) == MapPinProjection.lattice_footprint(),
		"legacy exact footprint")
	_check(fails, Profile.validate(quality, 0).is_empty(), "legacy validates")
	var custom: Dictionary = quality.duplicate(true)
	custom["spatial_profile"] = JSON.parse_string(JSON.stringify(fixture()))
	_check(fails, Profile.validate(custom, 2).is_empty(), "custom validates")
	_check(fails, not Profile.validate(custom, 1).is_empty(), "act mismatch rejects")
	var far_nodes: Array = [Fixtures._node("first", 0, 0), Fixtures._node("last", 14, 6)]
	var far_camera: Dictionary = MapQualityEvaluator.camera_registry(far_nodes, custom)
	_check(fails, far_camera["errors"].is_empty(), "camera resolves beyond legacy lattice")
	var node: Dictionary = {"row": 4, "col": 5, "jitter": [0.0, 0.0]}
	_check(fails, Profile.anchor(node, custom) == Vector3(-20, 1, 16), "custom anchor")
	_check(fails, Profile.anchor(node, custom) == Profile.anchor(node, custom), "determinism")
	_check(fails, MapLayoutCanonical.digest(custom) != MapLayoutCanonical.digest(quality),
		"profile participates in quality identity")
	for defect: String in ["version", "station", "finite", "lanes", "missing", "bounds", "jitter", "passage"]:
		var broken: Dictionary = custom.duplicate(true)
		match defect:
			"version": broken["spatial_profile"]["schema_version"] = 99
			"station": broken["spatial_profile"]["rows"][4]["station_m"] = -100.0
			"finite": broken["spatial_profile"]["rows"][4]["height_m"] = NAN
			"lanes": broken["spatial_profile"]["rows"][4]["lane_spacing_m"] = 0.0
			"missing": broken["spatial_profile"]["rows"].pop_back()
			"passage": broken["spatial_profile"]["passage"] = {"headroom_m": 2.0, "deck_depth_m": .65, "maximum_grade": .55}
			"jitter": broken["spatial_profile"]["jitter_scale"] = -0.1
			"bounds": broken["spatial_profile"]["bounds_xz_m"] = [0, 0, 1, 1]
		_check(fails, not Profile.validate(broken, 2).is_empty(), "reject " + defect)

	var restrained: Dictionary = custom.duplicate(true)
	restrained["spatial_profile"]["jitter_scale"] = .4
	var jitter_node: Dictionary = {"row": 4, "col": 5, "jitter": [.2, .2]}
	_check(fails, Profile.anchor(jitter_node, restrained).is_equal_approx(Vector3(-19.2, 1, 16.64)),
		"profile scales only presentation jitter")
	var reassigned: Dictionary = custom.duplicate(true)
	reassigned["spatial_profile"]["lane_assignments"] = {"shifted": 1}
	var original: Dictionary = {"id": "shifted", "row": 4, "col": 5, "jitter": [0.0, 0.0]}
	_check(fails, Profile.anchor(original, reassigned) == Vector3(-20, 1, -16),
		"generated lane assignment changes presentation only")
	_check(fails, original["col"] == 5, "game column remains unchanged")
	_check(fails, not Profile.validate_nodes(reassigned, [Fixtures._node("missing", 4, 2)]).is_empty(),
		"incomplete assignments reject")
	var positioned: Dictionary = custom.duplicate(true)
	positioned["spatial_profile"]["rows"][4]["lane_positions_m"] = [-24,-16,-8,0,8,24,32]
	_check(fails, Profile.validate(positioned,2).is_empty(), "local gap profile validates")
	_check(fails, Profile.anchor(node,positioned) == Vector3(-20,1,24), "anchor consumes local gap")
	for offsets: Array in [[-24,-16,-8,0,8,8,32],[-24,-16,-8,0,8,24,500],[-24,-16]]:
		positioned["spatial_profile"]["rows"][4]["lane_positions_m"] = offsets
		_check(fails, not Profile.validate(positioned,2).is_empty(), "invalid local lane positions reject")
	_test_generation(fails, custom)
	test_fork_preview(fails, custom)

static func _test_generation(fails: Array[String], quality: Dictionary) -> void:
	var nodes: Array = [Fixtures._node("a", 4, 2), Fixtures._node("b", 5, 3)]
	var edges: Array = [Fixtures._edge("a", "b")]
	var old_input: MapLayoutInput = Fixtures._input(nodes, edges, 717, quality,
		Fixtures._far_zones())
	var raw: Dictionary = old_input.to_dict()
	raw["act"] = 2
	var input: MapLayoutInput = MapLayoutInput.from_dict(raw)
	var report: Dictionary = MapNodeCandidateGenerator.generate(input, quality, 0)
	_check(fails, report["errors"].is_empty(), "custom candidate generation")
	_check(fails, report["impossibilities"].is_empty(), "custom legal domains")
	var authored: Array = report["node_sets"]["a"]["authored_anchor"]
	_check(fails, authored == [-20.0, 1.0, -8.0], "generator uses spatial anchor")
	var domains: Dictionary = MapQualityEvaluator.node_candidate_bounds(nodes, edges, quality)
	_check(fails, domains["a"]["base"] == Vector3(-20, 1, -8), "evaluator agrees")
	var camera: Dictionary = MapQualityEvaluator.camera_registry(nodes, quality, edges)
	_check(fails, camera["errors"].is_empty(), "custom camera profiles")
	var anchors: Dictionary = {"a": [-20.0, 1.0, -8.0], "b": [-10.0, 1.0, 0.0]}
	var plan: Dictionary = Routes.route_plan(nodes, edges, anchors, quality)
	_check(fails, plan["ok"] == true, "custom route plan")
	var channel: PackedVector2Array = Routes.route_channel(edges[0], plan, 1.0)
	_check(fails, channel[0].y == -41.0 and channel[1].y == 41.0,
		"routing uses custom spatial footprint")
	var repeated: Dictionary = MapNodeCandidateGenerator.generate(input, quality, 0)
	_check(fails, MapLayoutCanonical.digest(report) == MapLayoutCanonical.digest(repeated),
		"custom generator deterministic")
	_check(fails, input.node_records() == nodes and input.edge_records() == edges,
		"spatial generation preserves game graph")
	var rejected: Dictionary = MapNodeCandidateGenerator.generate(old_input, quality, 0)
	_check(fails, not rejected["errors"].is_empty(), "generation rejects act mismatch")

static func fixture() -> Dictionary:
	var rows: Array = []
	for row: int in range(15):
		rows.append({"station_m": -60.0 + row * 10.0, "height_m": 1.0,
			"centre_z_m": 0.0, "lane_spacing_m": 8.0,
			"region": "outer" if row < 4 else "court"})
	return {"schema_version": 1, "id": "spatial-test-v1", "act": 2,
		"bounds_xz_m": [-70.0, -40.0, 90.0, 40.0], "rows": rows}

static func _check(fails: Array[String], condition: bool, label: String) -> void:
	if not condition:
		fails.append("test_map_spatial_profile: " + label)

static func test_fork_preview(fails: Array[String], quality: Dictionary) -> void:
	var nodes: Array = [Fixtures._node("source", 4, 5), Fixtures._node("left", 5, 3),
		Fixtures._node("right", 5, 4)]
	var edges: Array = [Fixtures._edge("source", "left"), Fixtures._edge("source", "right")]
	var anchors: Dictionary = {"source": [-20.0, 0.0, 16.0], "left": [-10.0, 0.0, 0.0],
		"right": [-10.0, 0.0, 8.0]}
	var plan: Dictionary = Routes.route_plan(nodes, edges, anchors, quality)
	var a: Vector2 = plan["ports"][edges[0]["id"]]["branch_egress"]
	var b: Vector2 = plan["ports"][edges[1]["id"]]["branch_egress"]
	_check(fails, a.y < 16.0 and b.y > 16.0, "spatial fork departs on both sides")
