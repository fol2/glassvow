class_name MapJourneyLandscape
extends MapLandscape
## Approved woodland assembly consuming the canonical generated graph. Heights
## resolve onto rendered land/decks; source node IDs and routes stay unchanged.
const Terrain = preload("res://presentation/map/landscape/terrain.gd")
const Kit = preload("res://presentation/map/landscape/kit.gd")
const Journey = preload("res://presentation/map/landscape/journey.gd")
const Details = preload("res://presentation/map/landscape/road_details.gd")
var terrain: Terrain
var kit: Kit
var journey: Journey
var failure: String = ""
var timings_ms: Dictionary = {}
var _walking_routes: Dictionary = {}
var _travel_curves: Dictionary = {}
var _travel_distance: float = 0.0
var _was_moving: bool = false

func build(data: Dictionary) -> void:
	var started: int = Time.get_ticks_msec()
	terrain = Terrain.new()
	add_child(terrain)
	terrain.build({"anchors": data["node_anchors"], "edges": data["edges"]}, false)
	timings_ms["terrain"] = Time.get_ticks_msec()-started
	timings_ms["terrain_parts"] = terrain.build_timings_ms
	started = Time.get_ticks_msec()
	var resolved: PackedVector3Array = []
	for point: Vector3 in anchors:
		resolved.append(terrain.present(point))
	kit = Kit.new()
	add_child(kit)
	kit.build(terrain, resolved, false)
	if not kit.build_complete or not kit.failure.is_empty():
		failure = kit.failure if not kit.failure.is_empty() else "Woodland assembly incomplete"
		return
	timings_ms["scenery"] = Time.get_ticks_msec()-started
	started = Time.get_ticks_msec()
	Details.build(terrain)
	timings_ms["road_details"] = Time.get_ticks_msec()-started
	started = Time.get_ticks_msec()
	journey = Journey.new()
	add_child(journey)
	journey.build(terrain, resolved, anchors)
	# Campaign owns travel timing and legal commands. The shared figure receives
	# sampled positions below instead of running the isolated preview clock.
	journey.set_process(false)
	journey.walker.visible = false
	timings_ms["waystones"] = Time.get_ticks_msec()-started

func resolved_anchor(source: Vector3) -> Vector3:
	return Journey.seat(terrain, source) if terrain != null else source

func walking_route(from_id: String, to_id: String) -> PackedVector3Array:
	var key: String = MapLayoutInput.edge_id(from_id, to_id)
	if not _walking_routes.has(key):
		_walking_routes[key] = journey.path(from_id, to_id) if journey != null else PackedVector3Array()
	return _walking_routes[key]

func set_node_states(states: Dictionary) -> void:
	if journey == null:
		return
	for i: int in range(node_ids.size()):
		var state: String = str(states.get(node_ids[i], "cold"))
		var lit: bool = state in ["current", "open"]
		journey.glasses[i].albedo_color = Color("b38d57") if lit else Color("49424f")
		journey.glasses[i].emission = Color("aa7841") if lit else Color.BLACK

func set_traveller(at: Vector3, ahead: Vector3, moving: bool) -> void:
	if journey == null:
		return
	journey.walker.visible = at.is_finite()
	if not at.is_finite():
		return
	if moving and _was_moving:
		_travel_distance += journey.walker.position.distance_to(at)
	else:
		_travel_distance = 0.0
	_was_moving = moving
	journey.walker.position = at
	if moving and at.distance_to(ahead) > .001:
		journey.walker.rotation.y = atan2(ahead.x-at.x, ahead.z-at.z)
	journey.walker.pose(_travel_distance, moving)

func _travel_curve(from_id: String, to_id: String) -> Curve3D:
	var key: String = MapLayoutInput.edge_id(from_id, to_id)
	if not _travel_curves.has(key):
		var curve: Curve3D = Curve3D.new()
		curve.bake_interval = .06
		for point: Vector3 in walking_route(from_id, to_id):
			curve.add_point(point)
		_travel_curves[key] = curve
	return _travel_curves[key]

func travel_position(from_id: String, to_id: String, progress: float) -> Vector3:
	var curve: Curve3D = _travel_curve(from_id, to_id)
	return curve.sample_baked(clampf(progress, 0.0, 1.0)*curve.get_baked_length()) if curve.point_count > 0 else Vector3.INF

func travel_duration(from_id: String, to_id: String) -> float:
	return clampf(_travel_curve(from_id, to_id).get_baked_length()/3.5, .7, 4.5)

func select_route(from_id: String, to_id: String) -> void:
	if journey == null:
		return
	if not terrain.anchors.has(from_id) or not terrain.anchors.has(to_id) or from_id == to_id:
		journey.clear_route()
		return
	journey.show_route(from_id,to_id,resolved_anchor(v3(terrain.anchors[from_id])),resolved_anchor(v3(terrain.anchors[to_id])))
