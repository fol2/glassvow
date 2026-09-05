class_name MapScene
extends Control
## Compiled 3D landscape, projected waystones and camera input for one act.
## The generator owns every node, route and landmark transform. Rest allows
## three render warm-up frames, then freezes until input or content changes.

const OVERSAMPLE: float = 1.0
const VP_MAX: int = 2048
const THRESHOLD_XZ: Vector2 = Vector2(-41.3, 6.5)
## Clears the fixed boss with the new landmark silhouettes at every zoom.
const TERMINUS_XZ: Vector2 = Vector2(43.0, 0.0)
var _scatter_salt: int = 0
var _salt_dirty: bool = false
const TAP_SLOP: float = 12.0
const FLING_DAMP: float = 0.06
const FLING_MAX: float = 48.0

signal surface_tapped(screen: Vector2)

var _stage: SubViewport
var _display: TextureRect
var _rig: MapCameraRig
var _key: DirectionalLight3D
var _world: Node3D
var _landscape_assets: MapLandscapeAssets
var _landscape: MapLandscape
var _live: bool = false
var _settle_frames: int = 0
var _selection_half: Vector2 = Vector2.ZERO
var _asset_profiles: MapAssetProfiles
var _active_profile_digest: String = ""
var _active_profiles: Dictionary = {}
var _terminus_id: String = ""
var _threshold_id: String = ""
## Flat list of segment endpoints (a, b, a, b, ...) in world XZ, handed down by
## the screen that owns the graph. MapScene stays instantiable without one.
var _road_segments: PackedVector3Array = PackedVector3Array()
var _waylights: Dictionary[String, MapWaylightTracer] = {}
var _layout_result: MapLayoutResult = null
var _layout_diagnostics: Dictionary = {}
var _layout_failure: Dictionary = {}
var _act: int = -1
var _dragging: bool = false
var _lock_input: bool = false
var _dragged: float = 0.0
var _fling: Vector2 = Vector2.ZERO
var _last_velocity: Vector2 = Vector2.ZERO


func _init() -> void:
	name = "MapScene"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_stage = SubViewport.new()
	_stage.name = "MapStage"
	_stage.own_world_3d = true
	_stage.transparent_bg = false
	_stage.size = Vector2i(64, 64)
	_stage.msaa_3d = Viewport.MSAA_4X
	_stage.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_stage)
	_world = Node3D.new()
	_world.name = "MapWorld"
	_stage.add_child(_world)
	_rig = MapCameraRig.new()
	_world.add_child(_rig)
	_add_key(_world)
	_add_environment(_world)
	_display = TextureRect.new()
	_display.name = "MapDisplay"
	_display.texture = _stage.get_texture()
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	# SubViewport child controls resolve full-rect anchors in backing pixels at a
	# HiDPI content scale. Keep the display in this Control's canvas and size it
	# from the resolved rect in `_fit` instead.
	_display.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_display)
	process_priority = -1
	set_process(true)
	set_act(0)


func _ready() -> void:
	_rig.get_camera().current = true
	_fit()
	resized.connect(_fit)


func get_rig() -> MapCameraRig:
	return _rig


func get_stage() -> SubViewport:
	return _stage


func get_key() -> DirectionalLight3D:
	return _key


func get_act() -> int:
	return _act


## Cosmetic seed; the next bind rebuilds scenery without advancing game RNG.
func set_scatter_salt(salt: int) -> void:
	if salt == _scatter_salt:
		return
	_scatter_salt = salt
	_salt_dirty = true


func active_asset_paths() -> PackedStringArray:
	return _landscape_assets.paths.duplicate() if _landscape_assets != null else PackedStringArray()


func active_asset_resources() -> Array[Resource]:
	return _landscape_assets.resources.duplicate() if _landscape_assets != null else []


func asset_profile_digest() -> String:
	return _active_profile_digest


func layout_asset_bundle() -> Dictionary:
	if _active_profile_digest.is_empty() or _active_profiles.is_empty():
		return {}
	return {
		"profiles": _active_profiles.duplicate(true),
		"digest": _active_profile_digest,
	}


func layout_hero_contract() -> Dictionary:
	if _terminus_id.is_empty() or not _active_profiles.has(_terminus_id):
		return {}
	var anchors: Dictionary = {}
	var zones: Dictionary = {}
	_add_hero_contract(anchors, zones, "terminus", _terminus_id,
		Vector3(TERMINUS_XZ.x, 0.0, TERMINUS_XZ.y))
	if not _threshold_id.is_empty() and _active_profiles.has(_threshold_id):
		_add_hero_contract(anchors, zones, "vigil", _threshold_id,
			Vector3(THRESHOLD_XZ.x, 0.0, THRESHOLD_XZ.y))
	return {
		"schema_version": MapLayoutInput.HERO_ANCHOR_SCHEMA_VERSION,
		"anchors": MapLayoutCanonical.ordered_dictionary(anchors),
		"protected_zones": MapLayoutCanonical.ordered_dictionary(zones),
	}


func layout_digest() -> String:
	return "" if _layout_result == null else _layout_result.digest()


func layout_input_digest() -> String:
	return "" if _layout_result == null else str(
		_layout_result.to_dict().get("input_digest", ""))


func layout_diagnostics() -> Dictionary:
	return _layout_diagnostics.duplicate(true)


func layout_failure() -> Dictionary:
	return _layout_failure.duplicate(true)


func road_segments() -> PackedVector3Array:
	return _road_segments.duplicate()


func set_waylight_states(states: Dictionary) -> bool:
	var ids: Array[String] = MapLayoutCanonical.sorted_keys(_waylights)
	if MapLayoutCanonical.sorted_keys(states) != ids:
		return false
	for edge_id: String in ids:
		var tracer: MapWaylightTracer = _waylights[edge_id]
		var state: StringName = StringName(str(states[edge_id]))
		if not tracer.can_set_route_state(state):
			return false
	var changed: bool = false
	for edge_id: String in ids:
		var tracer: MapWaylightTracer = _waylights[edge_id]
		var state: StringName = StringName(str(states[edge_id]))
		changed = changed or tracer.route_state() != state
		if not tracer.set_route_state(state):
			return false
	if changed:
		_repaint()
	return true


func _add_hero_contract(anchors: Dictionary, zones: Dictionary, role: String,
		profile_id: String, position: Vector3) -> void:
	var profile: Dictionary = _active_profiles[profile_id]
	var yaw_degrees: float = _asset_profiles.fixed_yaw(profile)
	var scale: Vector3 = Vector3.ONE * _asset_profiles.default_scale(profile)
	var polygon: PackedVector2Array = _asset_profiles.transformed_footprint(
		profile, position, yaw_degrees, scale)
	if polygon.is_empty():
		return
	var plain: Array = []
	for point: Vector2 in polygon:
		plain.append([point.x, point.y])
	anchors[role] = {
		"asset_id": profile_id, "profile_id": profile_id,
		"position": _a3(position), "yaw_radians": deg_to_rad(yaw_degrees),
		"scale": _a3(scale),
	}
	zones["%s-zone" % role] = {"role": role, "polygon": plain}


## Bind this act's grade + ramp bands. `MapRegions.for_act` is the only
## palette source; content theme is not consulted. Re-arms freeze so the
## new look paints once.
func set_act(act_i: int) -> void:
	var region: MapRegions = MapRegions.for_act(act_i)
	if region.act == _act and not _salt_dirty:
		return
	_act = region.act
	_deal_act(region)


## Bind an act's materials and geometry from the CURRENT salt.
##
## Split out of `set_act` because the salt changes without the act changing,
## and that is the ordinary case rather than an odd one: a second run also
## starts in Act I. `set_act` no-ops on an unchanged act, so on its own it
## would leave the new run standing in the previous run's wood.
func _deal_act(_region: MapRegions) -> void:
	_salt_dirty = false
	_bind_asset_geometry()
	_repaint()


func project_pins(nodes: Array[MapNode]) -> PackedVector2Array:
	return _projection().seats(nodes)


func project_anchors(anchors: PackedVector3Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var projection: MapPinProjection = _projection()
	for anchor: Vector3 in anchors:
		out.append(projection.to_screen(anchor))
	return out


func hit_test(screen: Vector2) -> Vector3:
	return _projection().hit_world(screen)


## Among pins whose projected seat is within `radius` px of `screen`, pick the
## one whose world-anchor is nearest the ground hit. Empty / miss → −1.
func pin_at(screen: Vector2, nodes: Array[MapNode], radius: float) -> int:
	var seats: PackedVector2Array = project_pins(nodes)
	var world: Vector3 = hit_test(screen)
	var best: int = -1
	var best_d: float = INF
	for i: int in range(nodes.size()):
		if i >= seats.size() or seats[i].distance_to(screen) > radius:
			continue
		var d: float = MapPinProjection.world_anchor(nodes[i]).distance_to(world)
		if d < best_d:
			best = i
			best_d = d
	return best


func anchor_at(screen: Vector2, anchors: PackedVector3Array, radius: float) -> int:
	var seats: PackedVector2Array = project_anchors(anchors)
	var world: Vector3 = hit_test(screen)
	var best: int = -1
	var best_d: float = INF
	for i: int in range(anchors.size()):
		if i >= seats.size() or seats[i].distance_to(screen) > radius:
			continue
		var distance: float = anchors[i].distance_to(world)
		if distance < best_d:
			best = i
			best_d = distance
	return best


func set_lock_input(on: bool) -> void:
	_lock_input = on
	if on:
		_dragging = false
		_fling = Vector2.ZERO


func is_moving() -> bool:
	return _dragging or _fling.length() > 0.02


func _projection() -> MapPinProjection:
	var view: Vector2i = _stage.size
	return MapPinProjection.new(_rig.get_camera(), size, Vector2(view))


func is_live() -> bool:
	return _live


func set_live(on: bool) -> void:
	_live = on
	_settle_frames = 0 if on else 3
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _repaint() -> void:
	if not _live:
		set_live(false)


func _gui_input(event: InputEvent) -> void:
	if _lock_input:
		accept_event()
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		if button.pressed and button.button_index in [
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var inward: int = -1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			_rig.nudge_zoom(inward)
			set_live(false)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			_on_press(button.pressed, button.position)
			accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _dragging:
		_on_drag(motion.relative, motion.velocity)
		accept_event()
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		_on_press(touch.pressed, touch.position)
		accept_event()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and _dragging:
		_on_drag(drag.relative, drag.velocity)
		accept_event()


func _on_press(pressed: bool, screen: Vector2) -> void:
	if pressed:
		_dragging = true
		_dragged = 0.0
		_fling = Vector2.ZERO
		_last_velocity = Vector2.ZERO
		set_live(true)
		return
	var tap: bool = _dragged <= TAP_SLOP
	_dragging = false
	if tap:
		_fling = Vector2.ZERO
		set_live(false)
		surface_tapped.emit(screen)
		return
	_fling = _screen_to_world(_last_velocity).limit_length(FLING_MAX)
	if _fling.length() <= 0.02:
		_fling = Vector2.ZERO
		set_live(false)


func _on_drag(relative: Vector2, velocity: Vector2) -> void:
	_dragged += relative.length()
	_last_velocity = velocity
	_rig.pan_screen(relative, _view_height())


func _screen_to_world(delta_px: Vector2) -> Vector2:
	var k: float = _rig.get_camera().size / maxf(_view_height(), 1.0)
	var tilt: float = deg_to_rad(absf(MapCameraRig.TILT_DEGREES))
	return Vector2(-delta_px.x * k, -delta_px.y * k / sin(tilt))


func _process(delta: float) -> void:
	if not _live and _settle_frames > 0:
		_settle_frames -= 1
		if _settle_frames == 0:
			_stage.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _dragging or _lock_input:
		return
	if _fling.length() > 0.02:
		_rig.pan_world(_fling * delta)
		_fling *= pow(FLING_DAMP, delta)
		if not is_live():
			set_live(true)
		return
	if _fling != Vector2.ZERO:
		_fling = Vector2.ZERO
		set_live(false)


func _fit() -> void:
	_rig.get_camera().current = true
	if size.x <= 1.0 or size.y <= 1.0:
		return
	_display.position = Vector2.ZERO
	_display.size = size
	var next: Vector2i = Vector2i(
			mini(maxi(int(size.x * OVERSAMPLE), 1), VP_MAX),
			mini(maxi(int(size.y * OVERSAMPLE), 1), VP_MAX))
	if _stage.size == next:
		return
	_stage.size = next
	if not is_live():
		set_live(false)


func _view_height() -> float:
	return float(_stage.size.y) if _stage.size.y > 0 else maxf(size.y, 1.0)


func _add_key(world: Node3D) -> void:
	_key = DirectionalLight3D.new()
	_key.name = "MapKey"
	_key.rotation_degrees = Vector3(-47, -34, 0)
	_key.light_color = Color("f2e7cd")
	_key.light_energy = 1.1
	_key.shadow_enabled = true
	_key.directional_shadow_max_distance = 110
	_key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	world.add_child(_key)


func _add_environment(world: Node3D) -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("11242c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("98b1c2")
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("304852")
	environment.fog_light_energy = 0.45
	environment.fog_density = 0.0015
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "MapEnvironment"
	world_environment.environment = environment
	world.add_child(world_environment)


func _placement_footprint(candidate: Dictionary) -> PackedVector2Array:
	var placement: Dictionary = candidate["placement"]
	var transform: Dictionary = placement["transform"]
	var profile_id: String = str(placement["profile_id"])
	if not _active_profiles.has(profile_id):
		return PackedVector2Array()
	var profile: Dictionary = _active_profiles[profile_id]
	return _asset_profiles.transformed_footprint(
		profile, _v3(transform["origin"]),
		rad_to_deg(MapLayoutCanonical.float_value(transform["yaw_radians"])),
		_v3(transform["scale"]))


func _bind_asset_geometry() -> void:
	if _landscape != null:
		_landscape.free()
		_landscape = null
	_clear_waylights()
	_layout_result = null
	_layout_diagnostics.clear()
	_layout_failure.clear()
	_road_segments.clear()
	_active_profiles.clear()
	_active_profile_digest = ""
	_terminus_id = ""
	_threshold_id = ""
	MapPinProjection.set_scenery([])
	_landscape_assets = MapLandscapeAssets.new(_act)
	if not _landscape_assets.failure.is_empty():
		_fail_layout(_landscape_assets.failure)
		return
	_asset_profiles = _landscape_assets.registry
	_active_profiles = _landscape_assets.profiles
	_active_profile_digest = _landscape_assets.digest
	_terminus_id = MapLandscapeAssets.GATES[_act]
	_threshold_id = "vigil" if _act == 0 else ""
	_repaint()


func bind_layout(compiled: MapLayoutResult, quality: Dictionary) -> MapLayoutResult:
	if compiled == null:
		return _fail_layout("compiled result is null")
	if _active_profiles.is_empty() or layout_hero_contract().is_empty():
		return _fail_layout("active map asset profiles are incomplete")
	var data: Dictionary = compiled.identity_dict()
	if _landscape != null:
		_landscape.free()
	_landscape = MapLandscape.new()
	_world.add_child(_landscape)
	_landscape.prepare(data, _landscape_assets, _scatter_salt)
	_selection_half = _selection_reserve(quality)
	var candidates: Dictionary = _landscape.candidates()
	var accepted: Dictionary = {}
	var accepted_footprints: Array[PackedVector2Array] = []
	var rejections: Array[Dictionary] = []
	var contract: Dictionary = layout_hero_contract()
	for candidate_id: String in MapLayoutCanonical.sorted_keys(candidates):
		var candidate: Dictionary = candidates[candidate_id]
		var footprint: PackedVector2Array = _placement_footprint(candidate)
		if not _landscape.supports(footprint):
			rejections.append({"candidate_id": candidate_id, "reason": "land edge", "blocker_id": "terrain"})
			continue
		var selection: PackedVector2Array = _selection_footprint(candidate, footprint)
		var rejection: Dictionary = _scenery_rejection(
			selection, footprint, accepted_footprints, data, contract, quality)
		if not rejection.is_empty():
			rejection["candidate_id"] = candidate_id
			rejections.append(rejection)
			continue
		accepted[candidate_id] = candidate["placement"]
		accepted_footprints.append(footprint)
	data["scenery_instances"] = MapLayoutCanonical.ordered_dictionary(accepted)
	var final_result: MapLayoutResult = MapLayoutResult.create(data)
	if final_result == null:
		return _fail_layout("filtered result is invalid")
	var edges: Dictionary = data["edges"]
	if not _bind_waylights(edges):
		return _fail_layout("compiled edge cannot configure a bounded waylight")
	_layout_result = final_result
	_layout_failure.clear()
	_road_segments = _flatten_edges(edges)
	_layout_diagnostics = {
		"status": "BOUND",
		"input_digest": str(data["input_digest"]),
		"layout_digest": final_result.digest(),
		"candidate_count": candidates.size(),
		"accepted_count": accepted.size(),
		"rejected_count": rejections.size(),
		"scenery_instances": data["scenery_instances"],
		"rejections": rejections,
	}
	_landscape.build(data)
	_repaint()
	return final_result


func _fail_layout(reason: String) -> MapLayoutResult:
	_layout_result = null
	_layout_failure = {
		"kind": "compiled_layout", "id": "live_map", "reason": reason,
	}
	_layout_diagnostics = {"status": "FAILED", "failure": _layout_failure.duplicate(true)}
	_road_segments = PackedVector3Array()
	_clear_waylights()
	if _landscape != null:
		_landscape.free()
		_landscape = null
	_repaint()
	return null


func _flatten_edges(edges: Dictionary) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for edge_id: String in MapLayoutCanonical.sorted_keys(edges):
		var edge: Dictionary = edges[edge_id]
		var points: Array = edge["centerline"]
		for i: int in range(points.size() - 1):
			out.append(_v3(points[i]))
			out.append(_v3(points[i + 1]))
	return out


func _bind_waylights(edges: Dictionary) -> bool:
	_clear_waylights()
	var index: int = 0
	for edge_id: String in MapLayoutCanonical.sorted_keys(edges):
		var edge: Dictionary = edges[edge_id]
		var tracer: MapWaylightTracer = MapWaylightTracer.new()
		tracer.name = "Waylight%03d" % index
		if not tracer.configure_route(edge, MapWaylightTracer.STATE_COLD):
			tracer.free()
			_clear_waylights()
			return false
		_world.add_child(tracer)
		_waylights[edge_id] = tracer
		index += 1
	return true


func _clear_waylights() -> void:
	for tracer: MapWaylightTracer in _waylights.values():
		tracer.free()
	_waylights.clear()


func _scenery_rejection(footprint: PackedVector2Array, physical: PackedVector2Array,
		accepted: Array[PackedVector2Array], data: Dictionary,
		contract: Dictionary, quality: Dictionary) -> Dictionary:
	if footprint.is_empty():
		return {"reason": "invalid transformed footprint", "blocker_id": "profile"}
	var epsilon: float = MapLayoutCanonical.float_value(quality["epsilon"]["world_m"])
	var anchors: Dictionary = data["node_anchors"]
	for node_id: String in MapLayoutCanonical.sorted_keys(anchors):
		if MapQualityEvaluator._polygon_distance(footprint,
				MapQualityEvaluator._rect(_xz(anchors[node_id]), _selection_half)) <= epsilon:
			return {"reason": "node reserve", "blocker_id": node_id}
	var road_clearance: float = MapLayoutCanonical.float_value(
		quality["geometry"]["road_corridor"]["world_clearance_m"])
	var edges: Dictionary = data["edges"]
	for edge_id: String in MapLayoutCanonical.sorted_keys(edges):
		var edge: Dictionary = edges[edge_id]
		var reserve: float = MapLayoutCanonical.float_value(edge["corridor_width"]) \
			* 0.5 + road_clearance
		var points: Array = edge["centerline"]
		for i: int in range(points.size() - 1):
			if MapQualityEvaluator._segment_polygon(_xz(points[i]), _xz(points[i + 1]),
					footprint) < reserve - epsilon:
				return {"reason": "road and waylight corridor", "blocker_id": edge_id}
	var zones: Dictionary = contract["protected_zones"]
	for zone_id: String in MapLayoutCanonical.sorted_keys(zones):
		var zone: Dictionary = zones[zone_id]
		var geometry_id: String = "%s_protected_zone" % str(zone["role"])
		var geometry: Dictionary = quality["geometry"]
		if not geometry.has(geometry_id):
			return {"reason": "unknown hero protected zone", "blocker_id": zone_id}
		var rule: Dictionary = geometry[geometry_id]
		var padding: float = MapLayoutCanonical.float_value(rule["padding_m"])
		if MapQualityEvaluator._polygon_distance(footprint,
				MapQualityEvaluator._poly(zone["polygon"])) < padding - epsilon:
			return {"reason": "hero protected zone", "blocker_id": zone_id}
	# Canopies may overlap one another, as in a grove. Physical footprints
	# remain disjoint; the full projected reserve above protects all gameplay.
	for prior: PackedVector2Array in accepted:
		if MapQualityEvaluator._polygon_distance(physical, prior) <= epsilon:
			return {"reason": "accepted scenery footprint", "blocker_id": "scenery"}
	return {}


func _a3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _v3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	var row: Array = value
	return Vector3(
		MapLayoutCanonical.float_value(row[0]),
		MapLayoutCanonical.float_value(row[1]),
		MapLayoutCanonical.float_value(row[2]))


func _xz(value: Variant) -> Vector2:
	var point: Vector3 = _v3(value)
	return Vector2(point.x, point.z)


func set_node_states(states: Dictionary) -> void:
	if _landscape != null:
		_landscape.set_node_states(states)
		_repaint()


func _selection_footprint(candidate: Dictionary, footprint: PackedVector2Array) -> PackedVector2Array:
	var placement: Dictionary = candidate["placement"]
	var profile: Dictionary = _active_profiles[str(placement["profile_id"])]
	var transform: Dictionary = placement["transform"]
	var height: float = MapLayoutCanonical.float_value(profile["grounded_height"]) * _v3(transform["scale"]).y
	# AABB extrusion is the evaluator's conservative silhouette. Project it back
	# onto Y=0: all camera poses differ only by translation and uniform scale.
	var offset: Vector2 = Vector2(0, -height / tan(deg_to_rad(absf(MapCameraRig.TILT_DEGREES))))
	var points: PackedVector2Array = footprint.duplicate()
	for point: Vector2 in footprint:
		points.append(point + offset)
	var hull: PackedVector2Array = Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[-1]):
		hull.remove_at(hull.size() - 1)
	return hull


static func _selection_reserve(quality: Dictionary) -> Vector2:
	var calibration: Dictionary = quality["calibration"]["shipping_touch_waystone"]
	var radius: float = MapLayoutCanonical.float_value(calibration["ink_radius_px"]) * MapLayoutCanonical.float_value(calibration["default_layout_scale"])
	for rule: Dictionary in quality["hard"]:
		if str(rule["id"]) == "node_ink_clearance_px":
			radius += MapLayoutCanonical.float_value(rule["limit"])
	radius = maxf(radius, MapQualityEvaluator._touch_size_px(quality) * 0.5)
	var pixels_per_metre: float = INF
	var shapes: Dictionary = quality["profiles"]["shapes"]
	for shape: Array in shapes.values():
		for zoom: float in quality["profiles"]["zoom_stops_m"]:
			pixels_per_metre = minf(pixels_per_metre, MapLayoutCanonical.float_value(shape[1]) / zoom)
	var half: float = radius / pixels_per_metre
	return Vector2(half, half / sin(deg_to_rad(absf(MapCameraRig.TILT_DEGREES))))
