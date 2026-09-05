class_name MapScene
extends Control
## Standalone 3D map surface for one act (#234 slice 7b).
##
## Instantiable without a WorldMap. `project_pins` takes a node list when the
## caller has one; construction does not. Owns pan / fling / wheel for the
## world surface; pin pick is `pin_at` (screen rect ∩ hit-test). Ground and
## manifest assets replace the placeholder MultiMesh modules only when a full
## active-act geometry set is available; otherwise wedge / slab / dab carry the #255
## cel/triplanar pair. Freeze is a switch, not a scene-graph assumption
## (#207 decision 10). Rest is `UPDATE_ONCE` (one paint, then sleep). Call
## `set_live(true)` while the camera moves; `set_live(false)` re-arms a
## single frame at the new pose — same contract as `card_view.gd` `_set_live`.

const OVERSAMPLE: float = 1.0
const VP_MAX: int = 2048
## The plane must outsize what the camera can EVER see, not the lattice: a
## legal seat at the pan bounds' corner (the seed-717 start node puts the
## camera at z≈26.6) looks past a 48×34 plane into void — measured on the
## live screen as the world filling only ~71%×63% of the frame. Widest case:
## bounds extent (39×28.8) plus the max zoom stop's frustum on every side
## (ortho 28 × wide-phone aspect, /sin 55° along Z). One quad, world-XZ
## triplanar — oversizing is free.
const GROUND_SIZE: Vector2 = Vector2(128.0, 96.0)
const SUN_TO: Vector3 = Vector3(-0.35, 0.78, 0.52)
const SKY: Color = Color(0.018, 0.022, 0.045)
## Mesh scale, yaw policy, semantic class, footprint and occlusion facts
## are owned by MapAssetProfiles and keyed by manifest asset ID.
## Where the Vigil stands: short of the entrance row, mirroring the terminus
## past the boss. The screen reads this too, to run the road out from its door
## to the first waystones.
##
## x is pinned by the opening frame, and the budget is tight enough to write
## down. The camera seats the focused node at `MapCameraRig.LEAD_X` = 1/3 of
## the frame width, so at the played zoom stop (20) and the narrowest shipping
## aspect (pad-landscape, 1180x820) there are 28.8 / 3 = 9.59 units of ground
## west of row 0 before the frame ends. The hall's rotated footprint is 8.50 of
## them. Everything left over — 1.09 units — is the whole available gap between
## the Vigil and the first wave of nodes.
##
## -41.3 spends it: the west wall lands just inside the frame edge at -45.6 and
## the east wall at -37.1, a clear 1.1 short of row 0's x = -36. It was -38.4,
## which put the hall 1.85 units PAST row 0 — the first wave stood on its roof.
## An earlier note here claimed x = -41 cut the hall in half; that was measured
## against the parametric hall before the Tripo one halved its footprint.
##
## More separation than this cannot come from moving the building. It needs the
## opening zoom stop, `LEAD_X`, or the `act1-vigil` profile scale to give.
const THRESHOLD_XZ: Vector2 = Vector2(-41.3, 6.5)
## Smallest one-decimal road-axis calibration whose real transformed silhouette
## clears the fixed boss across every governed screen profile (#474).
const TERMINUS_XZ: Vector2 = Vector2(43.0, 0.0)
## Turned so the gable is seen in three-quarter rather than edge-on. The hall
## is authored with its gable facing +X, down the road; the camera looks along
## -Z, so unturned the player sees the length of the flank and the end of the
## building disappears into the frame edge. Turned, the doorway in the gable
## faces the road, which is the whole point of putting it at the start of one.
# Fixed yaw comes from the act1-vigil profile.
## Metres, like KIT_SCALE: the Tripo hall arrives unit-scale (0.979 x 0.933 x
## 0.743) where the parametric one it replaced was authored at 10.9 m long and
## shrunk by 0.78. Matching that one's world height wanted 9.7, and at 9.7 the
## opening frame cuts the hall off at its left edge — the same failure
## THRESHOLD_XZ was moved to fix. 6.9 keeps it whole: 6.8 m long, a 5.3 m ridge
## and 6.4 m to the top of the smoke, so it stands among the 6.2 m ash trunks
## rather than over them, and the doorway is legible at the played zoom.
# World scale comes from the act1-vigil profile.
## Metres between paving slabs along a road segment. Generated Acts I/II use
## fewer, narrower, less regularly aligned slabs so their dense graph does not
## read as one continuous woven lattice. The compiled centreline is unchanged.
const ROAD_STEP: float = 0.95
const EARLY_ROAD_STEP: float = 1.45
const ROAD_WOBBLE: float = 0.045
const EARLY_ROAD_WOBBLE: float = 0.11
const EARLY_ROAD_WIDTH: float = 0.78
# Road slab scale comes from the shared-road profiles.
# The current camera-directional hide envelope is owned by MapAssetProfiles.

## The run's own number, dealt into the landscape. 0 is a legal value and is
## what every construction that never sees a run gets, so a bare `MapScene.new()`
## is still deterministic.
var _scatter_salt: int = 0
## Set when the salt moves, cleared by the next bind. `set_act` no-ops on an
## unchanged act, and a second run also starts in Act I, so without this the
## new run stands in the old run's wood.
var _salt_dirty: bool = false
## The dealt seats, and the salt they were dealt from. `_dealt_seats` is asked
## five times per bind -- once by `_all_prop_positions` and once by each of the
## three slice functions, twice over -- and re-running six relaxation passes over
## 25 seats each time is waste. Cached rather than merely deterministic: while
## the two agree today, nothing structural made them agree, and a grade painted
## from one deal over geometry placed from another is a bug with no symptom
## until someone looks at a contact shadow.
var _seats_cache: PackedVector3Array = PackedVector3Array()
var _seats_cache_salt: int = -1
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


## Deal this run's landscape. Call BEFORE `set_act`, which is what rebinds the
## geometry that reads it.
##
## The placeholders are rebuilt here rather than left alone. They are what shows
## if an act's real assets fail to load, and the grade's contact shadows are
## painted from these same seats -- a fallback standing somewhere the shadows
## are not is worse than a fallback that is merely grey.
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


func seat_kit(j: int, kinds: int) -> int:
	return 2 + posmod(j + _scatter_salt, kinds)


func _dress_salt() -> int:
	return posmod(_scatter_salt, 997)


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
			selection, accepted_footprints, data, contract, quality)
		if not rejection.is_empty():
			rejection["candidate_id"] = candidate_id
			rejections.append(rejection)
			continue
		accepted[candidate_id] = candidate["placement"]
		accepted_footprints.append(selection)
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


func _scenery_rejection(footprint: PackedVector2Array,
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
	# `_dealt_seats` already preserves the existing SEAT_GAP centre floor. The
	# polygon check removes the residual real-footprint overlaps without inventing
	# a second placement or clearance threshold.
	for prior: PackedVector2Array in accepted:
		if MapQualityEvaluator._polygon_distance(footprint, prior) <= epsilon:
			return {"reason": "accepted scenery footprint", "blocker_id": "scenery"}
	return {}


## The ground the scenery may stand on, along the journey. Clears the Vigil to
## the west and the terminus at x = 40.4 to the east; it is the span the authored
## set this replaced already used, so nothing downstream sees a wider field.
const SCATTER_X: Vector2 = Vector2(-33.0, 31.5)
## How far off the centre line each family sits, as |z|. The lanes run
## z = -18..18 in 6-unit steps, so these bands put scenery INSIDE the node
## field rather than on its banks -- nodes step around it, which is
## `MapPinProjection.resolve`'s job, and the corridor down z = 0 stays open.
const WEDGE_Z: Vector2 = Vector2(8.5, 11.7)
const SLAB_Z: Vector2 = Vector2(5.6, 6.9)
const DAB_Z: Vector2 = Vector2(7.4, 11.8)
## How much of its own band a piece may wander in. At 1.0 two neighbours could
## meet on the shared edge and the stratification would buy nothing.
const BAND_INSET: float = 0.7
## How many pieces each family seats. `_add_props` slices the dealt list by
## these, so they are the one statement of the bill.
const WEDGE_N: int = 9
const SLAB_N: int = 4
const DAB_N: int = 8
## Metres two seats must keep between them once every family is on the ground.
##
## Stratification only spaces a family against ITSELF -- three independent
## streams cannot see each other, and `WEDGE_Z` and `DAB_Z` overlap outright. A
## person placing 25 pieces sees all 25 at once, and it showed: measured over
## 200 seeds, the hand-authored set had ZERO pairs closer than half their
## combined footprint radius and the first dealt version had 1.30 per seed.
## 3.4 is the widest kit pair on this map (two 6.2-scaled ash trunks) at about
## half their combined reach, and it is a BALANCE POINT rather than an optimum.
## The trade is monotone, measured over 200 seeds with
## `tools/probe_map_seeds.gd` -- a wider gap buys less clumping and fewer
## overlapping medallions, and pays for both by pushing more nodes behind
## scenery, because spreading the pieces along X covers more lanes:
##
##   gap   pairs <0.75 reach   overlapping nodes   nodes behind
##   2.8         1.88            27 / 24 seeds        4.8%
##   3.4         0.28            19 / 17 seeds        5.3%
##   4.0         0.06            18 / 18 seeds        5.7%
##   (authored)  1.00            51 / 50 seeds        3.9%
##
## Move this one number to re-weigh it; do not re-derive the mechanism.
const SEAT_GAP: float = 3.4


## One RNG per family, so adding a piece to one does not reshuffle the others.
##
## Deliberately NOT `RunState.rng`. That stream belongs to the domain, and
## drawing from it here would advance it and change what the map generator
## rolls next -- the scenery would silently move the graph.
func _scatter_rng(stream: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _scatter_salt ^ (stream * 0x9E3779B9)
	return rng


## Seats for one family: stratified along the journey, alternating sides.
##
## Stratified rather than free, and that is what makes a dealt landscape read
## like the authored one it replaces. Each family cuts the journey into as many
## bands as it has pieces and draws one piece inside each, so neighbour spacing
## stays in a narrow range. Nine uniform draws over the same 64 units put
## neighbours anywhere from touching to twenty apart, which reads as three
## thickets and a desert rather than as a wood.
##
## The side flips every piece, from a start the run picks. That is what keeps
## the middle open without anything having to test for it.
func _band_seats(count: int, z_band: Vector2, height: float,
		stream: int) -> PackedVector3Array:
	var rng: RandomNumberGenerator = _scatter_rng(stream)
	var out: PackedVector3Array = PackedVector3Array()
	var span: float = (SCATTER_X.y - SCATTER_X.x) / float(count)
	var side: float = 1.0 if rng.randf() < 0.5 else -1.0
	for i: int in range(count):
		var centre: float = SCATTER_X.x + (float(i) + 0.5) * span
		out.append(Vector3(
				centre + rng.randf_range(-0.5, 0.5) * span * BAND_INSET,
				height,
				side * rng.randf_range(z_band.x, z_band.y)))
		side = -side
	return out


## Every seat this run, in one list, spaced against each other.
##
## The separation has to happen HERE and cannot move into `_band_seats`: a
## family drawing on its own stream has no idea where the other two families
## went. This is the only point where all 25 exist at once.
func _dealt_seats() -> PackedVector3Array:
	if _seats_cache_salt == _scatter_salt:
		return _seats_cache
	var seats: PackedVector3Array = _band_seats(WEDGE_N, WEDGE_Z, 1.7, 1)
	seats.append_array(_slab_seats())
	seats.append_array(_band_seats(DAB_N, DAB_Z, 0.0, 3))
	_seats_cache = _separate(seats)
	_seats_cache_salt = _scatter_salt
	return _seats_cache


## Push crowded seats apart ALONG X ONLY.
##
## X because the z bands carry the design: which side of the road a piece sits
## on, how far off the centre line, and the open corridor down the middle are
## all statements `_band_seats` makes in z, and a relaxation free to move in z
## would quietly undo them. X has room -- a wedge band is 7.2 m wide and the gap
## wanted is 3.4.
##
## Coincident seats are skipped rather than separated: the slab family seats two
## kits at one point on purpose, and that stack is the family's whole point.
func _separate(seats: PackedVector3Array) -> PackedVector3Array:
	var out: PackedVector3Array = seats
	for _pass: int in range(6):
		for a: int in range(out.size()):
			for b: int in range(a + 1, out.size()):
				var dx: float = out[b].x - out[a].x
				var dz: float = out[b].z - out[a].z
				# Coincident seats are left alone: the slab family stacks two
				# kits on one point deliberately.
				#
				# A reviewer flagged that testing by DISTANCE rather than by
				# identity could also exempt two pieces from different families
				# that happened to collide exactly -- the one case this pass
				# exists to fix, excusing itself by being bad enough. Measured
				# over 200 seeds: that fires ZERO times. Every skip is a slab
				# stack, which is what the continuous draws in `_band_seats`
				# predict, since two independent floats matching to a
				# millimetre in BOTH axes is not something a uniform
				# distribution does.
				#
				# It was tried the other way -- skip by index, `b == a + 1`
				# inside the slab range -- and that is NOT equivalent: it welds
				# each stack against its own halves permanently, and pairs
				# closer than half their combined footprint went from 0.00 per
				# seed to 0.95. Distance stays.
				if absf(dx) < 0.001 and absf(dz) < 0.001:
					continue
				var gap: float = Vector2(dx, dz).length()
				if gap >= SEAT_GAP:
					continue
				# Along X, away from each other, half the shortfall each. A pair
				# that happens to share an x takes an arbitrary but stable side
				# so the pass cannot stall on a division by zero.
				var push: float = (SEAT_GAP - gap) * 0.5
				var dir: float = signf(dx) if absf(dx) > 0.001 else 1.0
				out[a] = Vector3(clampf(out[a].x - dir * push,
						SCATTER_X.x, SCATTER_X.y), out[a].y, out[a].z)
				out[b] = Vector3(clampf(out[b].x + dir * push,
						SCATTER_X.x, SCATTER_X.y), out[b].y, out[b].z)
	return out


func _wedge_positions() -> PackedVector3Array:
	return _dealt_seats().slice(0, WEDGE_N)


## Two entries per seat, at the two heights the placeholder prism stacks at.
## The real kits flatten y to 0 in `_all_prop_positions`, so a pair becomes two
## kits sharing one footprint -- which is the stack this family is named for.
func _slab_seats() -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for base: Vector3 in _band_seats(SLAB_N, SLAB_Z, 0.0, 2):
		out.append(Vector3(base.x, 0.31, base.z))
		out.append(Vector3(base.x, 0.86, base.z))
	return out


func _slab_positions() -> PackedVector3Array:
	return _dealt_seats().slice(WEDGE_N, WEDGE_N + SLAB_N * 2)


func _dab_positions() -> PackedVector3Array:
	return _dealt_seats().slice(WEDGE_N + SLAB_N * 2)


## Ground level, for the real kits and for the grade's contact shadows.
##
## Every kit GLB is authored grounded -- measured, all six AABBs start at
## y = 0 -- while the seat lists carry the centre offset their PLACEHOLDER
## primitive needs, and the prism's half-height is exactly 1.7. Passing those
## through unchanged floated the whole scenery set 1.7 m, with the grade's
## contact shadows still painted on the ground beneath it.
## The dealt seats, for anything that has to measure them without standing up
## a viewport -- `tools/probe_map_seeds.gd` is the caller this exists for.
func prop_positions() -> PackedVector3Array:
	return _all_prop_positions()


func _all_prop_positions() -> PackedVector3Array:
	var seats: PackedVector3Array = _dealt_seats()
	var grounded: PackedVector3Array = PackedVector3Array()
	for seat: Vector3 in seats:
		grounded.append(Vector3(seat.x, 0.0, seat.z))
	return grounded


func _dab_mesh() -> ArrayMesh:
	var top: Vector3 = Vector3(0.05, 1.45, -0.08)
	var bottom: Vector3 = Vector3(-0.08, 0.0, 0.05)
	var east: Vector3 = Vector3(0.95, 0.56, 0.02)
	var north: Vector3 = Vector3(0.02, 0.62, -0.78)
	var west: Vector3 = Vector3(-0.82, 0.48, -0.04)
	var south: Vector3 = Vector3(-0.03, 0.58, 0.86)
	var triangles: PackedVector3Array = PackedVector3Array([
		top, east, north, top, south, east,
		top, west, south, top, north, west,
		bottom, north, east, bottom, east, south,
		bottom, south, west, bottom, west, north,
	])
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(0, triangles.size(), 3):
		var a: Vector3 = triangles[i]
		var b: Vector3 = triangles[i + 1]
		var c: Vector3 = triangles[i + 2]
		var normal: Vector3 = (b - a).cross(c - a).normalized()
		for vertex: Vector3 in [a, b, c]:
			surface.set_normal(normal)
			surface.add_vertex(vertex)
	return surface.commit()


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
