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
## Metres each unit-scale kit is grown to, indexed as the manifest orders them:
## road-slab-a, road-slab-b, standing-monument, ash-trunk-fork, root-wedge,
## charred-stump, fallen-bough-arch, ash-cairn-mass.
const KIT_SCALE: Array[float] = [3.0, 3.0, 3.4, 6.2, 2.8, 2.2, 4.6, 3.2]
const TERMINUS_SCALE: float = 3.6
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
## opening zoom stop, `LEAD_X`, or `THRESHOLD_SCALE` to give.
const THRESHOLD_XZ: Vector2 = Vector2(-41.3, 6.5)
## Turned so the gable is seen in three-quarter rather than edge-on. The hall
## is authored with its gable facing +X, down the road; the camera looks along
## -Z, so unturned the player sees the length of the flank and the end of the
## building disappears into the frame edge. Turned, the doorway in the gable
## faces the road, which is the whole point of putting it at the start of one.
const THRESHOLD_YAW: float = -46.0
## Metres, like KIT_SCALE: the Tripo hall arrives unit-scale (0.979 x 0.933 x
## 0.743) where the parametric one it replaced was authored at 10.9 m long and
## shrunk by 0.78. Matching that one's world height wanted 9.7, and at 9.7 the
## opening frame cuts the hall off at its left edge — the same failure
## THRESHOLD_XZ was moved to fix. 7.0 keeps it whole: 6.9 m long, a 5.4 m ridge
## and 6.5 m to the top of the smoke, so it stands among the 6.2 m ash trunks
## rather than over them, and the doorway is legible at the played zoom.
const THRESHOLD_SCALE: float = 7.0
## Metres between paving slabs along a road segment.
## Denser and wider than the first pass. The paving is the map's main statement
## of where the graph runs; the 2D dots over it are a route marker, not a road.
const ROAD_STEP: float = 0.95
const ROAD_SCALE: float = 2.15
## Metres of ground a piece of scenery hides per metre of its own height, at
## the camera's tilt: 1 / tan(40°).
const HIDE_PER_HEIGHT: float = 1.19
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
var _road_meshes: Array[Mesh] = []
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


func active_asset_paths() -> PackedStringArray:
	return _materials.active_asset_paths()


func active_asset_resources() -> Array[Resource]:
	return _materials.active_asset_resources()


## Bind this act's grade + ramp bands. `MapRegions.for_act` is the only
## palette source; content theme is not consulted. Re-arms freeze so the
## new look paints once.
func set_act(act_i: int) -> void:
	var region: MapRegions = MapRegions.for_act(act_i)
	if region.act == _act:
		return
	_act = region.act
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
	# Nothing is standing yet, so nothing is worth stepping aside for. An act
	# whose geometry fails to resolve must not leave the previous act's
	# footprints pushing this act's nodes around.
	MapPinProjection.set_scenery([])
	_set_placeholders_visible(true)
	var raw_kits: Variant = assets.get("kits", [])
	var raw_terminus: Variant = assets.get("terminus", null)
	if not (raw_kits is Array) or not (raw_terminus is Resource):
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
	var meshes: Array[Mesh] = []
	for raw: Variant in kit_resources:
		if not (raw is Resource):
			return
		var resource: Resource = raw
		var mesh: Mesh = _mesh_from(resource)
		if mesh == null:
			return
		meshes.append(mesh)
	var terminus_resource: Resource = raw_terminus
	var terminus_mesh: Mesh = _mesh_from(terminus_resource)
	if terminus_mesh == null:
		return
	_asset_geometry = Node3D.new()
	_asset_geometry.name = "MapAssetGeometry"
	_world.add_child(_asset_geometry)
	# Kits 0 and 1 are shared-road-slab-a/b. They ARE the road. Handing them to
	# the scenery scatter is what left a pilgrimage map with no road on it, and
	# left the graph to be carried by a 2 px dashed line drawn over the top.
	_road_meshes = [meshes[0], meshes[1]]
	var positions: PackedVector3Array = _all_prop_positions()
	var kinds: int = meshes.size() - 2
	for i: int in range(2, meshes.size()):
		var placements: PackedVector3Array = PackedVector3Array()
		for j: int in range(positions.size()):
			if j % kinds == i - 2:
				placements.append(positions[j])
		_add_multimesh(_asset_geometry, "AssetKit%02d" % i, meshes[i], placements,
				i * 7, KIT_SCALE[i])
	# Tell the projection what now stands where, so the nodes can step out
	# from behind it. Radius takes the wider of x and z because yaw can swing
	# one into the other; depth is how much ground the piece's own height
	# hides at the camera's tilt.
	var pieces: Array[Vector4] = []
	for j: int in range(positions.size()):
		var kit: int = 2 + (j % kinds)
		var box: AABB = meshes[kit].get_aabb()
		var unit: float = KIT_SCALE[kit]
		pieces.append(Vector4(positions[j].x, positions[j].z,
				maxf(box.size.x, box.size.z) * 0.5 * unit,
				box.size.y * unit * HIDE_PER_HEIGHT))
	MapPinProjection.set_scenery(pieces)
	var terminus: MeshInstance3D = MeshInstance3D.new()
	terminus.name = "AssetTerminus"
	terminus.mesh = terminus_mesh
	# Just past the boss, which is lattice row 14 col 3 = world (36, 0, 0).
	terminus.position = Vector3(40.0, 0.0, 0.0)
	terminus.scale = Vector3.ONE * TERMINUS_SCALE
	terminus.material_override = _materials.prop
	terminus.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_asset_geometry.add_child(terminus)
	# The Vigil, at the west end of the road, seen from outside: a gabled hall
	# end-on with its chimney. The rose window is on the far side, turned in at
	# the fire, and stays there — it is the L3 reveal (docs/story/01-world.md).
	# Only Act I has one, so a null here seats nothing rather than failing the
	# bind -- the other three acts are not missing an asset, they never had one.
	var raw_threshold: Variant = assets.get("threshold", null)
	if raw_threshold is Resource:
		var gate_res: Resource = raw_threshold
		var gate_mesh: Mesh = _mesh_from(gate_res)
		if gate_mesh != null:
			var gate: MeshInstance3D = MeshInstance3D.new()
			gate.name = "AssetVigil"
			gate.mesh = gate_mesh
			# Just short of the entrance, which is lattice row 0 = world x -36,
			# mirroring the terminus four metres past the boss at the far end.
			gate.position = Vector3(THRESHOLD_XZ.x, 0.0, THRESHOLD_XZ.y)
			gate.rotation_degrees = Vector3(0.0, THRESHOLD_YAW, 0.0)
			gate.scale = Vector3.ONE * THRESHOLD_SCALE
			# Its own material once its baked albedo is in hand; the prop shader
			# otherwise, so a mesh that arrives without one degrades to projected
			# stone rather than to a building painted with nothing.
			var dressed: bool = _materials.bind_vigil_albedo(_baked_albedo(gate_mesh))
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
	if _asset_geometry == null or _road_meshes.size() < 2:
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
				_road_meshes[m], laid[m], yaws[m], m)
		node.name = "AssetRoad%d" % m
		_asset_geometry.add_child(node)


func _road_multimesh(mesh: Mesh, positions: PackedVector3Array,
		yaws: PackedFloat32Array, seed_index: int) -> MultiMeshInstance3D:
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
		var scale: Vector3 = Vector3(
				ROAD_SCALE * (1.0 + wobble),
				ROAD_SCALE * 0.6,
				ROAD_SCALE * (1.0 - wobble))
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


func _wedge_positions() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-31.5, 1.7, -9.75), Vector3(-25.5, 1.7, 8.55),
		Vector3(-18.0, 1.7, -11.55), Vector3(-9.75, 1.7, 9.6),
		Vector3(-1.5, 1.7, -8.7), Vector3(7.5, 1.7, 10.8),
		Vector3(15.75, 1.7, -10.05), Vector3(24.0, 1.7, 8.85),
		Vector3(31.5, 1.7, -11.25),
	])


func _slab_positions() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-27.75, 0.31, 5.85), Vector3(-27.75, 0.86, 5.85),
		Vector3(-12.0, 0.31, -6.75), Vector3(-12.0, 0.86, -6.75),
		Vector3(6.0, 0.31, 6.3), Vector3(6.0, 0.86, 6.3),
		Vector3(23.25, 0.31, -6.0), Vector3(23.25, 0.86, -6.0),
	])


func _dab_positions() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-33.0, 0.0, 11.7), Vector3(-21.0, 0.0, -7.8),
		Vector3(-15.75, 0.0, 11.4), Vector3(-5.25, 0.0, 7.5),
		Vector3(3.0, 0.0, -11.55), Vector3(12.75, 0.0, 7.8),
		Vector3(19.5, 0.0, -11.7), Vector3(30.75, 0.0, 10.35),
	])


## Ground level, for the real kits and for the grade's contact shadows.
##
## Every kit GLB is authored grounded -- measured, all six AABBs start at
## y = 0 -- while the seat lists carry the centre offset their PLACEHOLDER
## primitive needs, and the prism's half-height is exactly 1.7. Passing those
## through unchanged floated the whole scenery set 1.7 m, with the grade's
## contact shadows still painted on the ground beneath it.
func _all_prop_positions() -> PackedVector3Array:
	var seats: PackedVector3Array = _wedge_positions()
	seats.append_array(_slab_positions())
	seats.append_array(_dab_positions())
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


