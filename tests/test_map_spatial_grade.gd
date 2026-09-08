extends RefCounted
@warning_ignore_start("unsafe_call_argument")
const Grade = preload("res://presentation/map/map_grade_separation.gd")
const SpatialFixtures = preload("res://tests/test_map_spatial_profile.gd")

static func run(fails: Array[String]) -> void:
	var quality: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/map-quality-v2.json"))
	var routes: Dictionary = {
		"a": {"from": "a0", "to": "a1", "corridor_width": 2.5,
			"centerline": [[-15.0,0.0,0.0],[15.0,0.0,0.0]]},
		"b": {"from": "b0", "to": "b1", "corridor_width": 2.5,
			"centerline": [[0.0,0.0,-15.0],[0.0,0.0,15.0]]}}
	var legacy: Dictionary = Grade.apply(routes, quality)
	_check(fails, legacy.get("ok") == true, "legacy crossing")
	_check(fails, legacy["receipt"]["profile"]["minimum_vertical_clearance_m"] == .384,
		"legacy physical clearance unchanged")
	quality["spatial_profile"] = SpatialFixtures.fixture()
	quality["spatial_profile"]["passage"] = {"headroom_m": 2.45,
		"deck_depth_m": .65, "maximum_grade": .55, "landing_m": 1.0}
	var graded: Dictionary = Grade.apply(routes, quality)
	_check(fails, graded.get("ok") == true, "architectural crossing fits")
	if graded.get("ok") != true:
		return
	var report: Dictionary = Grade.evaluate(graded["routes"], quality)
	_check(fails, report["hard_pass"] == true, "architectural grading validates")
	_check(fails, report["hard_values"]["minimum_vertical_clearance_m"] >= 3.099,
		"deck depth reserved above finished headroom")
	_check(fails, Grade.evaluate(legacy["routes"], quality)["hard_pass"] == false,
		"legacy low crossing cannot pass architectural headroom")


	var raised: Dictionary = routes.duplicate(true)
	for edge: Dictionary in raised.values():
		for point: Array in edge["centerline"]:
			point[1] = .9
	var raised_result: Dictionary = Grade.apply(raised, quality)
	_check(fails, raised_result.get("ok") == true, "crossing fits on raised terrace")
	if raised_result.get("ok") == true:
		var raised_report: Dictionary = Grade.evaluate(raised_result["routes"], quality)
		_check(fails, raised_report["hard_pass"] == true, "raised passage clearance validates")
		for edge: Dictionary in raised_result["routes"].values():
			for point: Array in edge["centerline"]:
				_check(fails, MapLayoutCanonical.float_value(point[1]) >= .8999,
					"graded passage never drops below terrace")

static func _check(fails: Array[String], condition: bool, label: String) -> void:
	if not condition:
		fails.append("test_map_spatial_grade: " + label)
