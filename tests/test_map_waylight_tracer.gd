extends RefCounted

static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_waylight_tracer: %s" % what)
static func run(fails: Array[String]) -> void:
	var edge: Dictionary = {"from": "a", "to": "b", "corridor_width": 1.0,
		"centerline": [[-4.0, 0.0, -2.0], [0.0, 0.0, -2.0],
			[0.0, 0.0, 2.0], [4.0, 0.0, 2.0]]}
	var tracer: MapWaylightTracer = MapWaylightTracer.new()
	_check(fails, tracer.configure_route(edge, MapWaylightTracer.STATE_COLD),
		"canonical routed-edge record configures")
	var material: StandardMaterial3D = tracer.material_override as StandardMaterial3D
	var depth_ok: bool = false
	if material != null:
		depth_ok = not material.no_depth_test \
			and material.depth_draw_mode != BaseMaterial3D.DEPTH_DRAW_DISABLED
	_check(fails, depth_ok, "opaque material keeps normal depth testing and depth drawing")
	var cold_transforms: Array[Transform3D] = tracer.instance_transforms()
	var cold_data: Array[Color] = tracer.instance_custom_data()
	var cold_count: int = cold_transforms.size()
	var report: Dictionary = tracer.overhead()
	_check(fails, cold_count == 16 and tracer.multimesh.instance_count == cold_count
		and cold_count <= MapWaylightTracer.MAX_INSTANCES
		and MapLayoutCanonical.int_value(report.get("draw_calls", 0)) == 1
		and MapLayoutCanonical.int_value(report.get("mesh_resources", 0)) == 1
		and MapLayoutCanonical.int_value(report.get("material_resources", 0)) == 1,
		"representative edge is one bounded instanced draw")
	_check(fails, _covers_bent_legs(cold_transforms),
		"world-spacing samples cover all bent legs rather than the endpoint chord")
	var replay: MapWaylightTracer = MapWaylightTracer.new()
	_check(fails, replay.configure_route(edge, MapWaylightTracer.STATE_COLD)
		and replay.geometry_digest() == tracer.geometry_digest()
		and replay.instance_transforms() == cold_transforms
		and replay.instance_custom_data() == cold_data,
		"canonical route and state replay byte-stable instance data")
	var original_multimesh: MultiMesh = tracer.multimesh
	var original_builds: int = tracer.geometry_build_count()
	_check(fails, tracer.set_route_state(MapWaylightTracer.STATE_OPEN)
		and tracer.multimesh == original_multimesh
		and tracer.geometry_build_count() == original_builds
		and tracer.instance_transforms() == cold_transforms,
		"state-only update preserves the MultiMesh and every transform")
	var open_data: Color = tracer.instance_custom_data()[0]
	tracer.set_route_state(MapWaylightTracer.STATE_WALKED)
	var walked_data: Color = tracer.instance_custom_data()[0]
	_check(fails, cold_data[0] != open_data and open_data != walked_data
		and cold_data[0] != walked_data, "cold/open/walked state payloads stay distinct")
	_check(fails, MapWaylightTracer.route_state_color(MapWaylightTracer.STATE_COLD)
		.get_luminance() < MapMaterials.ROAD_VALUE * 0.25,
		"cold beads keep dark contrast against the nominal pale road surface")
	var before_rejected_state: Array[Color] = tracer.instance_custom_data()
	material.no_depth_test = true
	_check(fails, not tracer.set_route_state(MapWaylightTracer.STATE_COLD)
		and tracer.instance_custom_data() == before_rejected_state,
		"state mutation fails closed when depth testing is disabled")
	material.no_depth_test = false
	var obstacle: Array[Dictionary] = [{"id": "box", "polygon": PackedVector2Array([
		Vector2(-1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, -1.0)])}]
	var routed: Dictionary = MapSingleEdgeRouter.route(
		Vector2(-4.0, 0.0), Vector2(4.0, 0.0), obstacle, 0.2, 0.1)
	var routed_tracer: MapWaylightTracer = MapWaylightTracer.new()
	_check(fails, str(routed.get("status", "")) == MapSingleEdgeRouter.ROUTED
		and routed_tracer.configure_route(routed, MapWaylightTracer.STATE_COLD),
		"component directly consumes deterministic #468 output")
static func _covers_bent_legs(transforms: Array[Transform3D]) -> bool:
	var first: bool = false
	var turn: bool = false
	var last: bool = false
	for transform: Transform3D in transforms:
		var point: Vector3 = transform.origin
		first = first or (point.x < -1.0 and absf(point.z + 2.0) < 0.01)
		turn = turn or (absf(point.x) < 0.01 and point.z > -2.0 and point.z < 2.0)
		last = last or (point.x > 1.0 and absf(point.z - 2.0) < 0.01)
	return first and turn and last
