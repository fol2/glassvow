extends RefCounted
@warning_ignore_start("unsafe_call_argument")

const FlightMesh = preload("res://presentation/map/chapters/common/flight_mesh.gd")
const Flight = preload("res://presentation/map/chapters/common/resolved_flight.gd")

static func run(fails: Array[String]) -> void:
	var plan: Dictionary = Flight.resolve(Vector3(0, 0, 0), Vector3(10, 1.02, 0), 2.5, -2.0, 1.0)
	_check(fails, plan.get("ok") == true, "valid flight")
	if plan.get("ok") != true:
		return
	var strips: Array = plan["walking"]
	_check(fails, strips.size() == 8, "six treads and two landings")
	var previous: float = 0.0
	for strip: Dictionary in strips:
		var a: Vector3 = strip["start"]
		var b: Vector3 = strip["end"]
		_check(fails, a.y == b.y, "every walking strip is horizontal")
		_check(fails, absf(a.x - previous) < .00001, "shared station without overlap")
		_check(fails, b.x > a.x, "positive tread length")
		previous = b.x
	_check(fails, is_equal_approx(previous, 10), "complete horizontal coverage")
	_check(fails, is_equal_approx(plan["riser_m"], .17), "maximum riser")
	_check(fails, is_equal_approx(strips[-1]["end"].y, 1.02), "finished landing meets endpoint")
	var mesh: ArrayMesh = FlightMesh.build(plan)
	var arrays: Array = mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for index: int in range(strips.size() * 6):
		_check(fails, normals[index].y > .999, "rendered walking normal faces up")
	var riser_offset: int = strips.size() * 6
	for index: int in range(plan["risers"].size() * 6):
		_check(fails, normals[riser_offset + index].x < -.999, "riser faces downhill")
	_check(fails, normals[-1].x > .999, "upper end cap faces outwards")
	var reverse: Dictionary = Flight.resolve(Vector3(10, 1.02, 0), Vector3.ZERO, 2.5, -2.0, 1.0)
	_check(fails, reverse == plan, "ascending and descending share one geometry")
	_check(fails, Flight.resolve(Vector3.ZERO, Vector3(1, 2, 0), 2.5, -2, .4).get("ok") == false,
		"short run rejects instead of false stairs")
	_check(fails, Flight.resolve(Vector3.ZERO, Vector3(10, 1, 0), 0, -2, 1).get("ok") == false,
		"zero width rejects")
	_check(fails, Flight.resolve(Vector3.ZERO, Vector3(10, 1, 0), 2.5, 2, 1).get("ok") == false,
		"foundation above walking surface rejects")

static func _check(fails: Array[String], condition: bool, label: String) -> void:
	if not condition:
		fails.append("test_map_resolved_flight: " + label)
