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
## THRESHOLD_XZ was moved to fix. 7.0 keeps it whole: 6.9 m long, a 5.4 m ridge
## and 6.5 m to the top of the smoke, so it stands among the 6.2 m ash trunks
## rather than over them, and the doorway is legible at the played zoom.
# World scale comes from the act1-vigil profile.
## Metres between paving slabs along a road segment.
## Denser and wider than the first pass. The paving is the map's main statement
## of where the graph runs; the 2D dots over it are a route marker, not a road.
const ROAD_STEP: float = 0.95
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
var _materials: MapMaterials
var _world: Node3D
var _asset_geometry: Node3D
var _asset_profiles: MapAssetProfiles
var _active_profile_digest: String = ""
var _road_meshes: Array[Mesh] = []
var _road_profiles: Array[Dictionary] = []
## Flat list of segment endpoints (a, b, a, b, ...) in world XZ, handed down by
## the screen that owns the graph. MapScene stays instantiable without one.
var _road_segments: PackedVector3Array = PackedVector3Array()
var _act: int = -1
var _dragging: bool = false
var _lock_input: bool = false
var _dragged: float = 0.0
var _fling: Vector2 = Vector2.ZERO
var _last_velocity: Vector2 = Vector2.ZERO


func _init(manifest: Dictionary = {}, resource_loader: Callable = Callable()) -> void:
	name = "MapScene"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_stage = SubViewport.new()
	_stage.name = "MapStage"
	_stage.own_world_3d = true
	_stage.transparent_bg = false
	_stage.size = Vector2i(64, 64)
	_stage.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_stage)
	_world = Node3D.new()
	_world.name = "MapWorld"
	_stage.add_child(_world)
	_rig = MapCameraRig.new()
	_world.add_child(_rig)
	_add_key(_world)
	_add_environment(_world)
	_asset_profiles = MapAssetProfiles.new(manifest)
	_materials = MapMaterials.new(_key.basis.z, _rig.zoom_stop, manifest, resource_loader)
	_rig.zoom_stop_changed.connect(_materials.set_tex_stop)
	_add_ground(_world)
	_add_props(_world)
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
	# `_add_props` builds them visible, which is right at boot and wrong here:
	# a rebuild that forgets they were down paints the placeholder prisms
	# straight over the real kits, and they are dark enough to read as flat
	# black plates lying on the ground. Measured, not guessed -- three of six
	# review seeds showed them before this line existed.
	var showing: bool = _placeholders_visible()
	for node_name: String in ["FlatWedges", "StackedSlabs", "DabMasses"]:
		var stale: Node = _world.find_child(node_name, false, false)
		if stale != null:
			_world.remove_child(stale)
			stale.queue_free()
	_add_props(_world)
	_set_placeholders_visible(showing)
	# Anything already standing was dealt from the old salt, but do NOT re-deal
	# here: `_init` ends on Act I, so a save resumed in Act III would bind Act I
	# in full -- eight kits, a terminus, the Vigil and a grade repaint -- purely
	# to throw it away when the real act arrives a moment later. Flag it instead
	# and let the next `set_act` do exactly one bind, of the right act.
	_salt_dirty = _asset_geometry != null


func active_asset_paths() -> PackedStringArray:
	return _materials.active_asset_paths()


func active_asset_resources() -> Array[Resource]:
	return _materials.active_asset_resources()


func asset_profile_digest() -> String:
	return _active_profile_digest


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
func _deal_act(region: MapRegions) -> void:
	_salt_dirty = false
	var assets: Dictionary = _materials.bind_act(region, _all_prop_positions())
	_bind_asset_geometry(assets)
	if not is_live():
		set_live(false)


## Screen seats for 2D pins, in this Control's pixel space. Empty list is
## legal — MapScene does not own a WorldMap.
func project_pins(nodes: Array[MapNode]) -> PackedVector2Array:
	return _projection().seats(nodes)


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
	return _stage.render_target_update_mode == SubViewport.UPDATE_ALWAYS


func set_live(on: bool) -> void:
	_stage.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_ONCE)


## Re-arm one paint after the 3D content changes.
##
## The stage sleeps after its single frame, so ANY change to the world made
## after that paint is invisible: Godot flips `UPDATE_ONCE` to
## `UPDATE_DISABLED` once it has rendered. Ground and placeholders survive only
## because they are built in the constructor, before the first paint. The act's
## real geometry is not — it binds when the manifest resolves, several frames
## later — so without this the map showed placeholder wedges and slabs forever
## and no kit, terminus or road ever reached the screen.
##
## Never downgrade a live stage: while the camera moves the screen holds
## `UPDATE_ALWAYS`, and re-arming a single frame there would freeze the pan.
func _repaint() -> void:
	if _stage.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		_stage.render_target_update_mode = SubViewport.UPDATE_ONCE


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
	_key.shadow_enabled = false
	_key.basis = Basis.looking_at(-SUN_TO.normalized(), Vector3.UP)
	world.add_child(_key)


func _add_environment(world: Node3D) -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "MapEnvironment"
	world_environment.environment = environment
	world.add_child(world_environment)


func _add_ground(world: Node3D) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = GROUND_SIZE
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "TerrainPlaceholder"
	ground.mesh = plane
	ground.material_override = _materials.ground
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(ground)


func _add_props(world: Node3D) -> void:
	var wedge: PrismMesh = PrismMesh.new()
	wedge.size = Vector3(2.3, 3.4, 1.25)
	_add_multimesh(world, "FlatWedges", wedge, _wedge_positions(), 0)
	var slab: BoxMesh = BoxMesh.new()
	slab.size = Vector3(2.5, 0.62, 1.7)
	_add_multimesh(world, "StackedSlabs", slab, _slab_positions(), 9)
	_add_multimesh(world, "DabMasses", _dab_mesh(), _dab_positions(), 17)


## The salt, folded small, for the instance index `_add_multimesh` dresses from.
##
## That index becomes a yaw by `index * 1.117` radians and a scale by
## `index % 4` and `% 3`. A raw run seed near 2^31 still yields a yaw, but it
## leaves the fractional part of the product carrying it only a handful of
## digits. 997 is prime and larger than any period in the dressing, so folding
## here still reaches every yaw phase and every scale combination.
## Which kit stands at seat `j` this run. THE ONE PLACE THAT DECIDES IT.
##
## Public because `tools/probe_map_seeds.gd` has to reach the same answer, and
## it previously reached it by repeating the arithmetic -- which is how the two
## drifted apart in the first place.
##
## Two loops need the answer -- the one that places the mesh and the one that
## publishes its footprint to `MapPinProjection` -- and they must not disagree.
## They did: the salt landed on the placement loop alone, and a footprint list
## built from the other rotation is worse than no list at all, because the node
## solver believes it.
func seat_kit(j: int, kinds: int) -> int:
	return 2 + posmod(j + _scatter_salt, kinds)


func _dress_salt() -> int:
	return posmod(_scatter_salt, 997)


## INSTANCE_CUSTOM.xyz phase copied from MapSceneProxy._add_multimesh
## (#207 repair 4). Do not parent or subclass the proxy.
func _add_multimesh(world: Node3D, node_name: String, mesh: Mesh,
		positions: PackedVector3Array, first_index: int,
		unit_scale: float = 1.0) -> void:
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = positions.size()
	for i: int in range(positions.size()):
		var index: int = first_index + i
		var angle: float = float(index) * 1.117
		var scale: Vector3 = Vector3(
				0.82 + 0.09 * float(index % 4),
				0.86 + 0.08 * float((index + 2) % 3),
				0.84 + 0.07 * float((index + 1) % 4))
		if node_name == "StackedSlabs" and i % 2 == 1:
			scale *= 0.76
		# POC: every kit GLB is authored at unit scale -- an ash-trunk-fork is
		# 0.9 x 1.0 x 0.48 metres. Placed raw into a frame the camera covers at
		# ortho size 20, a tree is 5% of the frame height, which is the whole
		# reason the map reads as empty ground with specks on it.
		scale *= unit_scale
		var basis: Basis = Basis(Vector3.UP, angle).scaled(scale)
		multimesh.set_instance_transform(i, Transform3D(basis, positions[i]))
		multimesh.set_instance_custom_data(i, Color(
				fposmod(float(index) * 0.173, 1.0),
				fposmod(float(index) * 0.317, 1.0),
				fposmod(float(index) * 0.619, 1.0), 1.0))
	var instances: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instances.name = node_name
	instances.multimesh = multimesh
	instances.material_override = _materials.prop
	instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(instances)


## Swap placeholder geometry only after all eight kits and the terminus resolve.
## Partial asset deliveries may exercise checker/runtime loading without creating
## a half-authored frame. Removing the prior root synchronously releases its mesh
## references before the next act is attached.
func _bind_asset_geometry(assets: Dictionary) -> void:
	if _asset_geometry != null:
		_world.remove_child(_asset_geometry)
		_asset_geometry.free()
		_asset_geometry = null
	_road_meshes.clear()
	_road_profiles.clear()
	_active_profile_digest = ""
	# Nothing is standing yet, so nothing is worth stepping aside for. An act
	# whose geometry fails to resolve must not leave the previous act's
	# footprints pushing this act's nodes around.
	MapPinProjection.set_scenery([])
	_set_placeholders_visible(true)
	var raw_kits: Variant = assets.get("kits", [])
	var raw_kit_ids: Variant = assets.get("kit_ids", PackedStringArray())
	var raw_terminus: Variant = assets.get("terminus", null)
	var terminus_id: String = str(assets.get("terminus_id", ""))
	if not (raw_kits is Array) or not (raw_kit_ids is PackedStringArray) \
			or not (raw_terminus is Resource):
		return
	var kit_resources: Array = raw_kits
	if kit_resources.size() != 8:
		# Keeping the placeholders on a partial set is deliberate (see above).
		# Doing it silently is not: the previous act's geometry has ALREADY been
		# freed and the placeholders re-shown by the time we get here, so the
		# frame is indistinguishable from a broken renderer. Act N's kits live
		# under manifest `act: N-1` — an off-by-one in the caller lands here.
		push_warning("map: act %d resolved %d of 8 kits; keeping placeholders"
				% [_act, kit_resources.size()])
		return
	var kit_ids: PackedStringArray = raw_kit_ids
	if kit_ids.size() != 8:
		return
	var meshes: Array[Mesh] = []
	var profiles: Array[Dictionary] = []
	for i: int in range(kit_resources.size()):
		var raw: Variant = kit_resources[i]
		if not (raw is Resource):
			return
		var resource: Resource = raw
		var mesh: Mesh = _mesh_from(resource)
		if mesh == null:
			return
		var value: Dictionary = _asset_profiles.profile(kit_ids[i], mesh)
		if value.is_empty():
			return
		meshes.append(mesh)
		profiles.append(value)
	var terminus_resource: Resource = raw_terminus
	var terminus_mesh: Mesh = _mesh_from(terminus_resource)
	if terminus_mesh == null:
		return
	var terminus_profile: Dictionary = _asset_profiles.profile(
			terminus_id, terminus_mesh)
	if terminus_profile.is_empty():
		return
	var active_profiles: Array[Dictionary] = []
	active_profiles.assign(profiles)
	active_profiles.append(terminus_profile)
	var raw_threshold: Variant = assets.get("threshold", null)
	var threshold_mesh: Mesh = null
	var threshold_profile: Dictionary = {}
	if raw_threshold is Resource:
		var threshold_resource: Resource = raw_threshold
		threshold_mesh = _mesh_from(threshold_resource)
		if threshold_mesh == null:
			return
		threshold_profile = _asset_profiles.profile(
				str(assets.get("threshold_id", "")), threshold_mesh)
		if threshold_profile.is_empty():
			return
		active_profiles.append(threshold_profile)
	_active_profile_digest = _asset_profiles.digest(active_profiles)
	if _active_profile_digest.is_empty():
		return
	_asset_geometry = Node3D.new()
	_asset_geometry.name = "MapAssetGeometry"
	_world.add_child(_asset_geometry)
	# Kits 0 and 1 are shared-road-slab-a/b. They ARE the road. Handing them to
	# the scenery scatter is what left a pilgrimage map with no road on it, and
	# left the graph to be carried by a 2 px dashed line drawn over the top.
	_road_meshes = [meshes[0], meshes[1]]
	_road_profiles = [profiles[0], profiles[1]]
	var positions: PackedVector3Array = _all_prop_positions()
	var kinds: int = meshes.size() - 2
	for i: int in range(2, meshes.size()):
		var placements: PackedVector3Array = PackedVector3Array()
		for j: int in range(positions.size()):
			if seat_kit(j, kinds) == i:
				placements.append(positions[j])
		_add_multimesh(_asset_geometry, "AssetKit%02d" % i, meshes[i], placements,
				i * 7 + _dress_salt(), _asset_profiles.default_scale(profiles[i]))
	# Publish the build-4-compatible directional envelope from the same
	# profiles whose polygons the compiler will consume. No second formula lives here.
	var pieces: Array[Vector4] = []
	for j: int in range(positions.size()):
		var kit: int = seat_kit(j, kinds)
		pieces.append(_asset_profiles.directional_envelope(
				profiles[kit], positions[j]))
	MapPinProjection.set_scenery(pieces)
	var terminus: MeshInstance3D = MeshInstance3D.new()
	terminus.name = "AssetTerminus"
	terminus.mesh = terminus_mesh
	# Just past the boss, which is lattice row 14 col 3 = world (36, 0, 0).
	terminus.position = Vector3(40.0, 0.0, 0.0)
	terminus.scale = Vector3.ONE * _asset_profiles.default_scale(terminus_profile)
	terminus.material_override = _materials.prop
	terminus.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_asset_geometry.add_child(terminus)
	# The Vigil, at the west end of the road, seen from outside: a gabled hall
	# end-on with its chimney. The rose window is on the far side, turned in at
	# the fire, and stays there — it is the L3 reveal (docs/story/01-world.md).
	# Only Act I has one, so a null here seats nothing rather than failing the
	# bind -- the other three acts are not missing an asset, they never had one.
	if threshold_mesh != null and not threshold_profile.is_empty():
		var gate_mesh: Mesh = threshold_mesh
		var gate: MeshInstance3D = MeshInstance3D.new()
		gate.name = "AssetVigil"
		gate.mesh = gate_mesh
		# Just short of the entrance, which is lattice row 0 = world x -36,
		# mirroring the terminus four metres past the boss at the far end.
		gate.position = Vector3(THRESHOLD_XZ.x, 0.0, THRESHOLD_XZ.y)
		gate.rotation_degrees = Vector3(
			0.0, _asset_profiles.fixed_yaw(threshold_profile), 0.0)
		gate.scale = Vector3.ONE * _asset_profiles.default_scale(threshold_profile)
		# Its own material once its baked albedo is in hand; the prop shader
		# otherwise, so a mesh that arrives without one degrades to projected
		# stone rather than to a building painted with nothing.
		var dressed: bool = _materials.bind_vigil_albedo(_baked_albedo(gate_mesh))
		if not dressed:
			# The whole point of this asset is that it is textured. Falling
			# back to projected stone is survivable; doing it silently is
			# not, because the building still renders and nothing looks
			# broken enough to investigate.
			push_warning("Vigil has no baked albedo; falling back to the prop shader")
		gate.material_override = _materials.vigil if dressed else _materials.prop
		gate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_asset_geometry.add_child(gate)
	# Seat the road pair now, empty, so anything resolving them by name finds
	# them before the screen has a graph to hand down. `lay_road` rebuilds
	# them in place once it does.
	_build_road()
	_set_placeholders_visible(false)
	_repaint()


## The graph, as road. Segments are world-space endpoint pairs; the screen that
## owns the WorldMap supplies them, so MapScene never learns the graph type.
func lay_road(segments: PackedVector3Array) -> void:
	_road_segments = segments
	_build_road()
	_repaint()


func _build_road() -> void:
	if _asset_geometry == null or _road_meshes.size() < 2 \
			or _road_profiles.size() < 2:
		return
	# This runs twice on a normal boot: once from `_bind_asset_geometry` while
	# `_road_segments` is still empty, and again when the screen hands the graph
	# down through `lay_road`. Without this the second pass ADDS a second pair
	# and Godot renames it, leaving the empty pair holding the AssetRoad names —
	# so the road would draw correctly while anything looking the nodes up by
	# name found nothing on them.
	for m: int in range(2):
		var stale: Node = _asset_geometry.find_child("AssetRoad%d" % m, false, false)
		if stale != null:
			_asset_geometry.remove_child(stale)
			stale.free()
	var laid: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array()]
	var yaws: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
	var pairs: int = _road_segments.size() / 2
	var slab: int = 0
	for i: int in range(pairs):
		var a: Vector3 = _road_segments[i * 2]
		var b: Vector3 = _road_segments[i * 2 + 1]
		var span: float = a.distance_to(b)
		var steps: int = maxi(1, int(span / ROAD_STEP))
		var yaw: float = atan2(b.x - a.x, b.z - a.z)
		for k: int in range(steps + 1):
			var t: float = float(k) / float(steps)
			laid[slab & 1].append(a.lerp(b, t))
			yaws[slab & 1].append(yaw)
			slab += 1
	for m: int in range(2):
		var node: MultiMeshInstance3D = _road_multimesh(
				_road_meshes[m], laid[m], yaws[m], m, _road_profiles[m])
		node.name = "AssetRoad%d" % m
		_asset_geometry.add_child(node)


func _road_multimesh(mesh: Mesh, positions: PackedVector3Array,
		yaws: PackedFloat32Array, seed_index: int,
		profile: Dictionary) -> MultiMeshInstance3D:
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = positions.size()
	for i: int in range(positions.size()):
		var index: int = seed_index * 131 + i
		# Small: enough that the paving is not a stamped ribbon, little enough
		# that consecutive slabs still read as one road rather than as rubble.
		var wobble: float = 0.045 * sin(float(index) * 1.71)
		var unit: float = _asset_profiles.default_scale(profile)
		var scale: Vector3 = Vector3(
				unit * (1.0 + wobble),
				unit * 0.6,
				unit * (1.0 - wobble))
		var basis: Basis = Basis(Vector3.UP, yaws[i] + wobble).scaled(scale)
		multimesh.set_instance_transform(i, Transform3D(basis, positions[i]))
		multimesh.set_instance_custom_data(i, Color(
				fposmod(float(index) * 0.173, 1.0),
				fposmod(float(index) * 0.317, 1.0),
				fposmod(float(index) * 0.619, 1.0), 1.0))
	var instances: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instances.multimesh = multimesh
	instances.material_override = _materials.road
	instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instances


func _placeholders_visible() -> bool:
	var node: Node = _world.find_child("FlatWedges", false, false)
	return node is GeometryInstance3D and (node as GeometryInstance3D).visible


func _set_placeholders_visible(on: bool) -> void:
	for node_name: String in ["FlatWedges", "StackedSlabs", "DabMasses"]:
		var node: Node = _world.find_child(node_name, false, false)
		if node is GeometryInstance3D:
			var geometry: GeometryInstance3D = node
			geometry.visible = on


func _mesh_from(resource: Resource) -> Mesh:
	if resource is Mesh:
		return resource as Mesh
	if not (resource is PackedScene):
		return null
	var instance: Node = (resource as PackedScene).instantiate()
	var mesh_node: MeshInstance3D = _first_mesh(instance)
	var mesh: Mesh = null
	if mesh_node != null:
		mesh = mesh_node.mesh
	instance.free()
	return mesh


## The Vigil is the one asset whose texture ships inside its GLB rather than as
## a manifest row of its own, so it is read back off the imported surface
## material. Everything else on the map is surfaced by projection and has no
## material of its own to read.
func _baked_albedo(mesh: Mesh) -> Texture2D:
	if mesh == null or mesh.get_surface_count() < 1:
		return null
	var material: Material = mesh.surface_get_material(0)
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).albedo_texture
	return null


func _first_mesh(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root as MeshInstance3D
	for child: Node in root.get_children():
		var found: MeshInstance3D = _first_mesh(child)
		if found != null:
			return found
	return null


## The ground the scenery may stand on, along the journey. Clears the Vigil to
## the west and the terminus at x = 40 to the east; it is the span the authored
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


