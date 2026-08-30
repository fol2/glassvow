extends RefCounted

class FakeAssetLoader:
	extends RefCounted

	var calls: PackedStringArray = []

	func load_resource(path: String) -> Resource:
		calls.append(path)
		if path.ends_with(".png"):
			var image: Image = Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
			image.set_pixel(0, 0, Color(0.5, 0.5, 0.5, 0.5))
			return ImageTexture.create_from_image(image)
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(1.0, 1.0, 1.0)
		return mesh


## #234 slice 2–4: MapScene shaders, tex_stop bind, freeze switch, act palettes.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_scene: %s" % what)


static func run(fails: Array[String]) -> void:
	_rig(fails)
	_scene(fails)
	_input(fails)
	_materials(fails)
	_asset_binding(fails)
	_road_presentation(fails)
	_compiled_layout(fails)
	_palette(fails)


static func _rig(fails: Array[String]) -> void:
	var rig: MapCameraRig = MapCameraRig.new()
	var cam: Camera3D = rig.get_camera()
	_check(fails, cam.projection == Camera3D.PROJECTION_ORTHOGONAL,
			"camera is orthographic")
	# Moved off the 50–60 band in #156 round 2: at 55° the frame read flat and
	# panning up or down showed almost none of the 3D it was paying for. The
	# band is still a band, not a point, because the exact degree is a taste
	# call — what must not happen is a silent drift back toward top-down.
	_check(fails, cam.rotation_degrees.x >= -45.0
			and cam.rotation_degrees.x <= -35.0,
			"pitch sits in the signed 35–45° band")
	_check(fails, is_equal_approx(cam.rotation_degrees.x, MapCameraRig.TILT_DEGREES),
			"default pitch is the #255 −55° stop")
	_check(fails, rig.zoom_stop == MapCameraRig.DEFAULT_STOP
			and is_equal_approx(cam.size, 20.0),
			"default zoom stop matches proxy CAM_SIZE 20")
	_check(fails, MapCameraRig.ZOOM_STOPS.size() == 4,
			"four discrete zoom stops, same count as shader TEX_STOPS")
	var height: float = cam.position.y
	rig.set_zoom_stop(0)
	_check(fails, rig.zoom_stop == 0
			and is_equal_approx(cam.size, MapCameraRig.ZOOM_STOPS[0]),
			"stop 0 is the tight ortho size")
	rig.set_zoom_stop(99)
	_check(fails, rig.zoom_stop == 3
			and is_equal_approx(cam.size, MapCameraRig.ZOOM_STOPS[3]),
			"zoom stop clamps; it is not a continuous scale")
	rig.nudge_zoom(-1)
	_check(fails, rig.zoom_stop == 2, "nudge_zoom steps the int index")
	rig.set_zoom_stop(MapCameraRig.DEFAULT_STOP)
	rig.pan_world(Vector2(1.5, -2.0))
	var xz: Vector2 = rig.camera_xz()
	_check(fails, is_equal_approx(xz.x, MapCameraRig.DEFAULT_XZ.x + 1.5)
			and is_equal_approx(xz.y, MapCameraRig.DEFAULT_XZ.y - 2.0),
			"pan moves world XZ")
	_check(fails, is_equal_approx(cam.position.y, height),
			"pan does not change camera height")
	rig.pan_world(Vector2(-1000.0, 1000.0))
	xz = rig.camera_xz()
	var lo: Vector2 = rig.pan_bounds.position
	var hi: Vector2 = rig.pan_bounds.end
	_check(fails, is_equal_approx(xz.x, lo.x) and is_equal_approx(xz.y, hi.y),
			"pan clamps to bounds")
	rig.free()


static func _scene(fails: Array[String]) -> void:
	var scene: MapScene = MapScene.new()
	_check(fails, scene.get_stage().own_world_3d,
			"stage owns its World3D")
	_check(fails, not scene.is_live()
			and scene.get_stage().render_target_update_mode
				== SubViewport.UPDATE_ONCE,
			"rest is frozen via UPDATE_ONCE, not a disabled viewport")
	scene.set_live(true)
	_check(fails, scene.is_live()
			and scene.get_stage().render_target_update_mode
				== SubViewport.UPDATE_ALWAYS,
			"set_live(true) is UPDATE_ALWAYS")
	scene.set_live(false)
	_check(fails, not scene.is_live()
			and scene.get_stage().render_target_update_mode
				== SubViewport.UPDATE_ONCE,
			"set_live(false) re-arms UPDATE_ONCE")
	_check(fails, scene.get_key().shadow_enabled == false,
			"key light casts no shadow")
	var ground: Node = scene.find_child("TerrainPlaceholder", true, false)
	_check(fails, ground is MeshInstance3D, "placeholder ground is a MeshInstance3D")
	if ground is MeshInstance3D:
		var mesh_i: MeshInstance3D = ground as MeshInstance3D
		_check(fails, mesh_i.material_override is ShaderMaterial,
				"ground carries map_ground ShaderMaterial")
		_check(fails, mesh_i.cast_shadow
				== GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				"ground does not cast shadows")
	_check(fails, scene.get_rig().get_camera().current,
			"act camera is current inside the stage")
	var slab: String = "res://assets/art/map/geometry/shared/road-slab-a.glb"
	var terminus_path: String = "res://assets/art/map/geometry/act1/terminus-amber-window-tower.glb"
	var paths: PackedStringArray = scene.active_asset_paths()
	var complete: bool = ResourceLoader.exists(slab) and ResourceLoader.exists(terminus_path)
	if complete:
		_check(fails, scene.find_child("MapAssetGeometry", true, false) is Node3D,
				"complete eight-kit + terminus set replaces placeholder geometry")
		_check(fails, scene.find_child("AssetTerminus", true, false) is MeshInstance3D,
				"active terminus is attached")
		_check(fails, paths.has(slab) and paths.has(terminus_path),
				"present shared-road-slab-a and terminus bind through MapMaterials")
	else:
		_check(fails, scene.find_child("MapAssetGeometry", true, false) == null,
				"partial or absent payload keeps placeholder geometry")
		if ResourceLoader.exists(slab):
			_check(fails, paths.has(slab) and paths.size() < 12,
					"present shared-road-slab-a binds through MapMaterials, not a second loader")
		else:
			_check(fails, paths.is_empty(),
					"declared-but-absent assets keep the current placeholder geometry")
	for node_name: String in ["FlatWedges", "StackedSlabs", "DabMasses"]:
		var placeholder: Node = scene.find_child(node_name, true, false)
		_check(fails, placeholder is GeometryInstance3D
				and (placeholder as GeometryInstance3D).visible == not complete,
				"%s visibility follows whether the full eight-kit act set resolved" % node_name)
	scene.free()


static func _input(fails: Array[String]) -> void:
	var scene: MapScene = MapScene.new()
	var rig: MapCameraRig = scene.get_rig()
	var start: int = rig.zoom_stop
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	scene._gui_input(wheel)
	_check(fails, rig.zoom_stop == start + 1, "wheel down steps zoom out")
	_check(fails, not scene.is_live(), "zoom re-arms a single frozen frame")
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	scene._gui_input(press)
	_check(fails, scene.is_live(), "drag starts live")
	var before: Vector2 = rig.camera_xz()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(40.0, 0.0)
	scene._gui_input(motion)
	_check(fails, rig.camera_xz().x < before.x, "content follows the finger")
	press.pressed = false
	scene._gui_input(press)
	_check(fails, not scene.is_live(), "drag end freezes")
	var ground_mat: ShaderMaterial = _override(scene, "TerrainPlaceholder")
	if ground_mat != null:
		_check(fails, _as_int(ground_mat.get_shader_parameter("tex_stop")) == rig.zoom_stop,
				"wheel zoom pushes tex_stop")
	scene.free()


static func _materials(fails: Array[String]) -> void:
	var scene: MapScene = MapScene.new()
	var rig: MapCameraRig = scene.get_rig()
	var sun: Vector3 = scene.get_key().basis.z.normalized()
	var ground_mat: ShaderMaterial = _override(scene, "TerrainPlaceholder")
	_check(fails, ground_mat != null and ground_mat.shader != null
			and ground_mat.shader.resource_path.ends_with("map_ground.gdshader"),
			"ground is ShaderMaterial on map_ground.gdshader")
	if ground_mat != null:
		_check(fails, is_equal_approx(_as_float(ground_mat.get_shader_parameter(
				"surface_value")), MapMaterials.GROUND_VALUE),
				"ground surface_value is linearised 0.420")
		_sun_matches(fails, ground_mat, sun, "ground")
		_check(fails, ground_mat.get_shader_parameter("surface_tex") is Texture2D
				and ground_mat.get_shader_parameter("grade") is Texture2D,
				"ground surface_tex and grade are bound, not silently null")
		_check(fails, int(_as_float(ground_mat.get_shader_parameter("tex_stop")))
					== rig.zoom_stop,
				"ground tex_stop starts at the rig's zoom stop, not the shader default")
	var prop_names: PackedStringArray = ["FlatWedges", "StackedSlabs", "DabMasses"]
	for node_name: String in prop_names:
		var prop_mat: ShaderMaterial = _override(scene, node_name)
		_check(fails, prop_mat != null and prop_mat.shader != null
				and prop_mat.shader.resource_path.ends_with("map_prop.gdshader"),
				"%s is ShaderMaterial on map_prop.gdshader" % node_name)
		if prop_mat == null:
			continue
		_check(fails, is_equal_approx(_as_float(prop_mat.get_shader_parameter(
				"surface_value")), MapMaterials.PROP_VALUE),
				"%s surface_value is linearised 0.100" % node_name)
		_check(fails, not _as_bool(prop_mat.get_shader_parameter("second_octave")),
				"%s second_octave defaults off" % node_name)
		_sun_matches(fails, prop_mat, sun, node_name)
		var geom: Node = scene.find_child(node_name, true, false)
		if geom is GeometryInstance3D:
			var gi: GeometryInstance3D = geom as GeometryInstance3D
			_check(fails, gi.cast_shadow
					== GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
					"%s does not cast shadows" % node_name)
	var wedges: Node = scene.find_child("FlatWedges", true, false)
	if wedges is MultiMeshInstance3D:
		var mm: MultiMesh = (wedges as MultiMeshInstance3D).multimesh
		_check(fails, mm.use_custom_data and mm.instance_count > 0,
				"INSTANCE_CUSTOM phase channel is enabled")
	for stop: int in range(MapCameraRig.ZOOM_STOPS.size()):
		rig.set_zoom_stop(stop)
		_tex_stop_follows(fails, scene, stop)
	rig.set_zoom_stop(99)
	_tex_stop_follows(fails, scene, 3)
	scene.free()


static func _asset_binding(fails: Array[String]) -> void:
	var fake: FakeAssetLoader = FakeAssetLoader.new()
	var materials: MapMaterials = MapMaterials.new(
			Vector3(0.0, 1.0, 0.0), 1, {}, Callable(fake, "load_resource"))
	var act0: MapRegions = MapRegions.for_act(0)
	var first: Dictionary = materials.bind_act(act0, PackedVector3Array())
	var first_paths: PackedStringArray = materials.active_asset_paths()
	var first_resources: Array[Resource] = materials.active_asset_resources()
	var first_ground: Variant = materials.ground.get_shader_parameter("surface_tex")
	# 13 for Act I, 12 for the rest: only the first act has a threshold, because
	# the Vigil stands at the start of the road and nowhere else. The Vigil's
	# texture is not a fourteenth row — it is baked into that GLB. Asserted as a
	# count rather than a set so a silently DROPPED asset still fails here.
	_check(fails, first_paths.size() == 13 and first_resources.size() == 13,
			"act I loads 2 tiles + grade + 8 kits + terminus + vigil")
	var raw_first_kits: Variant = first.get("kits", [])
	var first_kit_count: int = 0
	if raw_first_kits is Array:
		var first_kits: Array = raw_first_kits
		first_kit_count = first_kits.size()
	_check(fails, first_kit_count == 8 and first.get("terminus", null) is Resource,
			"active set exposes eight kit resources and one terminus")
	for path: String in first_paths:
		_check(fails, path.contains("/shared/") or path.contains("/act1/")
				or path.get_file().begins_with("act1-"),
				"act 0 does not load another act: %s" % path)
	var act1: MapRegions = MapRegions.for_act(1)
	materials.bind_act(act1, PackedVector3Array())
	var second_paths: PackedStringArray = materials.active_asset_paths()
	var second_resources: Array[Resource] = materials.active_asset_resources()
	var retained: bool = false
	for current: Resource in second_resources:
		for prior: Resource in first_resources:
			retained = retained or is_same(current, prior)
	_check(fails, second_paths.size() == 12 and second_resources.size() == 12
			and not retained,
			"act switch replaces every active resource reference")
	_check(fails, not is_same(first_ground, materials.ground.get_shader_parameter("surface_tex")),
			"ground shader no longer retains the prior act tile")
	for path: String in second_paths:
		_check(fails, path.contains("/shared/") or path.contains("/act2/")
				or path.get_file().begins_with("act2-"),
				"act 1 does not retain act 0 paths: %s" % path)
	var bound_shade: Color = _as_color(materials.ground.get_shader_parameter("band_shade"))
	_check(fails, bound_shade.is_equal_approx(act1.band_shade),
			"MapRegions, not manifest metadata, remains palette authority")

	var scene_loader: FakeAssetLoader = FakeAssetLoader.new()
	var scene: MapScene = MapScene.new({}, Callable(scene_loader, "load_resource"))
	var first_root: Node = scene.find_child("MapAssetGeometry", true, false)
	_check(fails, first_root is Node3D and scene.active_asset_paths().size() == 13,
			"complete active set replaces placeholders through MapScene binding")
	# Kits 0 and 1 are shared-road-slab-a/b and are laid along the graph as the
	# ROAD (#156 direction B), not scattered as scenery, so they have no
	# AssetKit node at all. The remaining six share every scenery seat between
	# them. Counting the sum rather than each kit's share is the check that
	# matters: it fails if a seat is dropped or served twice, and it does not
	# re-break every time the seat list is retuned.
	for i: int in range(2):
		_check(fails, scene.find_child("AssetKit%02d" % i, true, false) == null,
				"road kit %d is not scattered as scenery" % i)
	var seated: int = 0
	for i: int in range(2, 8):
		var kit: Node = scene.find_child("AssetKit%02d" % i, true, false)
		_check(fails, kit is MultiMeshInstance3D,
				"asset kit %d is bound as a multimesh" % i)
		if kit is MultiMeshInstance3D:
			seated += (kit as MultiMeshInstance3D).multimesh.instance_count
	_check(fails, seated == scene._all_prop_positions().size(),
			"the six scenery kits between them fill every seat exactly once")
	for i: int in range(2):
		_check(fails, scene.find_child("AssetRoad%d" % i, true, false) is MultiMeshInstance3D,
				"road slab %d is laid along the graph" % i)
	_check(fails, scene.find_child("AssetTerminus", true, false) is MeshInstance3D,
			"active terminus is attached")
	_check(fails, scene.find_child("AssetVigil", true, false) is MeshInstance3D,
			"the Vigil is seated at the west end")
	for node_name: String in ["FlatWedges", "StackedSlabs", "DabMasses"]:
		var placeholder: Node = scene.find_child(node_name, true, false)
		_check(fails, placeholder is GeometryInstance3D
				and not (placeholder as GeometryInstance3D).visible,
				"%s hides only after the full real geometry set resolves" % node_name)
	scene.set_act(1)
	_check(fails, not is_instance_valid(first_root)
			and scene.find_child("MapAssetGeometry", true, false) is Node3D,
			"act switch frees the prior geometry root before replacing it")
	scene.free()


static func _road_presentation(fails: Array[String]) -> void:
	var fake: FakeAssetLoader = FakeAssetLoader.new()
	var scene: MapScene = MapScene.new({}, Callable(fake, "load_resource"))
	var segments: PackedVector3Array = PackedVector3Array([
		Vector3.ZERO, Vector3(0.0, 0.0, 9.5),
	])
	var counts: Array[int] = []
	for act: int in range(4):
		scene.set_act(act)
		scene.lay_road(segments)
		counts.append(_road_instance_count(scene))
	_check(fails, counts == [7, 7, 11, 11],
			"Acts I/II use sparse paving while Acts III/IV keep their presentation")
	var early_basis: Basis = MapScene._road_slab_basis(0.0, 1, 1.0,
			MapScene.EARLY_ROAD_WIDTH, MapScene.EARLY_ROAD_WOBBLE)
	var late_basis: Basis = MapScene._road_slab_basis(0.0, 1, 1.0,
			1.0, MapScene.ROAD_WOBBLE)
	var early_scale: Vector3 = early_basis.get_scale().abs()
	var late_scale: Vector3 = late_basis.get_scale().abs()
	var early_yaw: float = atan2(early_basis.z.x, early_basis.z.z)
	var late_yaw: float = atan2(late_basis.z.x, late_basis.z.z)
	_check(fails, early_scale.x < late_scale.x and early_scale.z < late_scale.z,
			"Acts I/II paving is narrower than the later-act presentation")
	_check(fails, absf(early_yaw) > absf(late_yaw),
			"Acts I/II paving keeps the larger bounded alignment variation")
	_check(fails, scene.road_segments() == segments,
			"presentation density preserves the exact supplied centreline")
	scene.free()


static func _road_instance_count(scene: MapScene) -> int:
	var out: int = 0
	for i: int in range(2):
		var node: MultiMeshInstance3D = scene.find_child(
				"AssetRoad%d" % i, true, false) as MultiMeshInstance3D
		if node != null and node.multimesh != null:
			out += node.multimesh.instance_count
	return out


static func _compiled_layout(fails: Array[String]) -> void:
	var fake: FakeAssetLoader = FakeAssetLoader.new()
	var scene: MapScene = MapScene.new({}, Callable(fake, "load_resource"))
	scene.set_scatter_salt(814)
	for method: StringName in [
		&"layout_asset_bundle", &"layout_hero_contract", &"bind_layout",
		&"layout_digest", &"layout_input_digest", &"road_segments",
		&"layout_diagnostics", &"layout_failure",
	]:
		if not scene.has_method(method):
			_check(fails, false, "MapScene supplies compiled-layout method %s" % method)
			scene.free()
			return
	var quality: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://docs/map/map-quality-v2.json"))
	var assets: Dictionary = scene.call(&"layout_asset_bundle")
	var contract: Dictionary = scene.call(&"layout_hero_contract")
	var terminus_anchor: Dictionary = contract.get("anchors", {}).get(
		"terminus", {})
	var vigil_anchor: Dictionary = contract.get("anchors", {}).get("vigil", {})
	_check(fails, _v3(terminus_anchor.get("position", Vector3.ZERO))
			.is_equal_approx(Vector3(40.4, 0.0, 0.0)),
		"terminus keeps the selected one-decimal screen-feasibility calibration")
	_check(fails, _v3(vigil_anchor.get("scale", Vector3.ZERO))
			.is_equal_approx(Vector3.ONE * 6.9),
		"Vigil keeps the shared two-seed screen-feasibility calibration")
	var candidates: PackedVector3Array = scene.prop_positions()
	_check(fails, not assets.is_empty() and not contract.is_empty()
			and candidates.size() > 2,
		"live MapScene exposes the active profile and hero authority")
	if assets.is_empty() or contract.is_empty() or candidates.size() <= 2:
		scene.free()
		return
	var a: Vector3 = candidates[0]
	var b: Vector3 = candidates[candidates.size() - 1]
	var bend_a: Vector3 = a.lerp(b, 0.35) + Vector3(0.0, 2.0, 4.0)
	var bend_b: Vector3 = a.lerp(b, 0.65) + Vector3(0.0, 2.0, 4.0)
	var edge_id: String = MapLayoutInput.edge_id("A", "B")
	var result: MapLayoutResult = MapLayoutResult.create({
		"schema_version": MapLayoutResult.SCHEMA_VERSION,
		"generator_version": MapLayoutCompiler.VERSION,
		"node_anchors": {"A": _a3(a), "B": _a3(b)},
		"edges": {edge_id: {
			"from": "A", "to": "B",
			"centerline": [_a3(a), _a3(bend_a), _a3(bend_b), _a3(b)],
			"corridor_width": 2.5,
		}},
		"hero_placements": _hero_placements(contract),
		"scenery_instances": {},
		"hard_measurements": {}, "soft_scores": {},
		"selected_restart_id": 0, "selected_candidate_id": "test/detour",
		"input_digest": "a".repeat(64),
	})
	var live_v: Variant = scene.call(&"bind_layout", result, quality)
	var live: MapLayoutResult = live_v if live_v is MapLayoutResult else null
	_check(fails, live != null and str(scene.call(&"layout_digest")) == live.digest()
			and str(scene.call(&"layout_input_digest")) == "a".repeat(64),
		"MapScene binds one final live result and exposes its exact digests")
	if live != null:
		var segments: PackedVector3Array = scene.call(&"road_segments")
		var has_grade: bool = false
		var has_chord: bool = false
		for i: int in range(0, segments.size(), 2):
			has_grade = has_grade or not is_zero_approx(segments[i].y) \
				or not is_zero_approx(segments[i + 1].y)
			has_chord = has_chord or (segments[i].is_equal_approx(a) \
				and segments[i + 1].is_equal_approx(b))
		_check(fails, segments.size() == 6 and has_grade and not has_chord,
			"road legs preserve canonical centreline Y and omit the forbidden chord")
		var data: Dictionary = live.to_dict()
		var accepted: Dictionary = data["scenery_instances"]
		_check(fails, not accepted.is_empty() and accepted.size() < candidates.size(),
			"existing deterministic seats are filtered rather than regenerated")
		_check(fails, _scenery_clears(accepted, data, contract, assets, quality),
			"every published scenery transform clears nodes, roads, heroes and peers")
		var diagnostics: Dictionary = scene.call(&"layout_diagnostics")
		var accepted_count: int = MapLayoutCanonical.int_value(
			diagnostics.get("accepted_count", -1))
		var candidate_count: int = MapLayoutCanonical.int_value(
			diagnostics.get("candidate_count", -1))
		var diagnostic_digest: String = str(diagnostics.get("layout_digest", ""))
		var diagnostic_scenery: Dictionary = diagnostics.get("scenery_instances", {})
		_check(fails, accepted_count == accepted.size()
				and candidate_count == candidates.size()
				and diagnostic_digest == live.digest()
				and diagnostic_scenery == accepted,
			"the live diagnostics publish the same accepted placement authority")
	var rejected_v: Variant = scene.call(&"bind_layout", null, quality)
	var cleared: PackedVector3Array = scene.call(&"road_segments")
	var failure: Dictionary = scene.call(&"layout_failure")
	_check(fails, rejected_v == null and cleared.is_empty() and not failure.is_empty(),
		"an invalid compiled result fails explicitly and clears the compiled road")
	scene.free()


static func _hero_placements(contract: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var anchors: Dictionary = contract["anchors"]
	for id: String in MapLayoutCanonical.sorted_keys(anchors):
		var anchor: Dictionary = anchors[id]
		out[id] = {
			"asset_id": anchor["asset_id"], "profile_id": anchor["profile_id"],
			"transform": {
				"origin": anchor["position"], "yaw_radians": anchor["yaw_radians"],
				"scale": anchor["scale"],
			},
		}
	return out


static func _scenery_clears(accepted: Dictionary, data: Dictionary,
		contract: Dictionary, assets: Dictionary, quality: Dictionary) -> bool:
	var footprints: Array[PackedVector2Array] = []
	var epsilon: float = MapLayoutCanonical.float_value(quality["epsilon"]["world_m"])
	var road_clearance: float = MapLayoutCanonical.float_value(
		quality["geometry"]["road_corridor"]["world_clearance_m"])
	var helper: MapAssetProfiles = MapAssetProfiles.new(MapQualityEvaluator.EMPTY_MANIFEST)
	var profiles: Dictionary = assets["profiles"]
	for id: String in MapLayoutCanonical.sorted_keys(accepted):
		var row: Dictionary = accepted[id]
		var transform: Dictionary = row["transform"]
		var profile: Dictionary = profiles[row["profile_id"]]
		var footprint: PackedVector2Array = helper.transformed_footprint(
			profile, _v3(transform["origin"]),
			rad_to_deg(MapLayoutCanonical.float_value(transform["yaw_radians"])),
			_v3(transform["scale"]))
		if footprint.is_empty():
			return false
		for anchor_v: Variant in data["node_anchors"].values():
			if MapQualityEvaluator._polygon_distance(footprint,
					MapQualityEvaluator._node_world(_v3(anchor_v), quality)) <= epsilon:
				return false
		for edge_v: Variant in data["edges"].values():
			var edge: Dictionary = edge_v
			var points: Array = edge["centerline"]
			var reserve: float = MapLayoutCanonical.float_value(edge["corridor_width"]) \
				* 0.5 + road_clearance
			for i: int in range(points.size() - 1):
				if MapQualityEvaluator._segment_polygon(_xz(points[i]), _xz(points[i + 1]),
						footprint) < reserve - epsilon:
					return false
		var zones: Dictionary = contract["protected_zones"]
		for zone_id: String in MapLayoutCanonical.sorted_keys(zones):
			var zone: Dictionary = zones[zone_id]
			var padding: float = MapLayoutCanonical.float_value(
				quality["geometry"]["%s_protected_zone" % zone["role"]]["padding_m"])
			if MapQualityEvaluator._polygon_distance(footprint,
					MapQualityEvaluator._poly(zone["polygon"])) < padding - epsilon:
				return false
		for prior: PackedVector2Array in footprints:
			if MapQualityEvaluator._polygon_distance(footprint, prior) <= epsilon:
				return false
		footprints.append(footprint)
	return true


static func _a3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func _v3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	var row: Array = value
	return Vector3(MapLayoutCanonical.float_value(row[0]),
		MapLayoutCanonical.float_value(row[1]), MapLayoutCanonical.float_value(row[2]))


static func _xz(value: Variant) -> Vector2:
	var point: Vector3 = _v3(value)
	return Vector2(point.x, point.z)


static func _override(scene: MapScene, node_name: String) -> ShaderMaterial:
	var node: Node = scene.find_child(node_name, true, false)
	if not (node is GeometryInstance3D):
		return null
	var geom: GeometryInstance3D = node as GeometryInstance3D
	var mat: Material = geom.material_override
	if mat is ShaderMaterial:
		return mat as ShaderMaterial
	return null


static func _tex_stop_follows(fails: Array[String], scene: MapScene, stop: int) -> void:
	var names: PackedStringArray = [
			"TerrainPlaceholder", "FlatWedges", "StackedSlabs", "DabMasses"]
	for node_name: String in names:
		var mat: ShaderMaterial = _override(scene, node_name)
		if mat == null:
			_check(fails, false, "%s missing for tex_stop check" % node_name)
			continue
		_check(fails, _as_int(mat.get_shader_parameter("tex_stop")) == stop
				and stop == scene.get_rig().zoom_stop,
				"%s tex_stop == zoom_stop %d" % [node_name, stop])


static func _sun_matches(fails: Array[String], mat: ShaderMaterial, sun: Vector3,
		who: String) -> void:
	var bound: Variant = mat.get_shader_parameter("sun")
	_check(fails, bound is Vector3, "%s sun is a vec3" % who)
	if bound is Vector3:
		var dir: Vector3 = bound
		_check(fails, dir.is_equal_approx(sun),
				"%s sun is the key light basis.z" % who)


static func _as_int(v: Variant) -> int:
	if v is int:
		var i: int = v
		return i
	if v is float:
		var f: float = v
		return int(f)
	return -1


static func _as_float(v: Variant) -> float:
	if v is float:
		var f: float = v
		return f
	if v is int:
		var i: int = v
		return float(i)
	return NAN


static func _as_bool(v: Variant) -> bool:
	if v is bool:
		var b: bool = v
		return b
	return true


static func _palette(fails: Array[String]) -> void:
	_check(fails, MapRegions.BAND_SHADE.size() == 4
			and MapRegions.BAND_KEY.size() == 4,
			"four light-arc palette rows (dusk night storm dawn)")
	_check(fails, MapRegions.FALLBACK_SKIES.size() == LayoutBook.ACTS
			and MapRegions.FALLBACK_FOGS.size() == LayoutBook.ACTS
			and MapRegions.FALLBACK_PARTICLES.size() == LayoutBook.ACTS
			and MapRegions.FALLBACK_GLOWS.size() == LayoutBook.ACTS
			and MapRegions.FALLBACK_ACCENTS.size() == LayoutBook.ACTS
			and MapRegions.WEATHER_BY_ACT.size() == LayoutBook.ACTS
			and MapRegions.BAND_SHADE.size() == LayoutBook.ACTS,
			"act count and palette count agree")
	# Act 0 was crimson because it was matched to the web act1 stage plate. The
	# port owns its look now and act 0 is night glass (#156 direction B), so
	# the hue this pins moved. What replaces it is the constraint that actually
	# protects the frame: a prop is the ground times PROP_VALUE / GROUND_VALUE,
	# so if the KEY loses luminance the props stop reading against the ground.
	# Hue is nearly free — the amber this replaced carried luma 0.505 and the
	# glass-blue carries 0.438 — but a genuinely dark key is not, and that is
	# the mistake this floor is here to catch. The darkness belongs in the
	# grade, which multiplies per position; see MapRegions.BAND_KEY.
	_check(fails, MapRegions.BAND_SHADE[0].h > 0.55 and MapRegions.BAND_SHADE[0].h < 0.72,
			"act 0 shade is night indigo, not the retired crimson stage plate")
	_check(fails, MapRegions.BAND_KEY[0].get_luminance() > 0.5,
			"act 0 key keeps the luminance the ground↔prop gap depends on")
	for i: int in range(4):
		var cfg: MapRegions = MapRegions.for_act(i)
		_check(fails, cfg.act == i
				and cfg.band_shade.is_equal_approx(MapRegions.BAND_SHADE[i])
				and cfg.band_key.is_equal_approx(MapRegions.BAND_KEY[i]),
				"for_act(%d) returns authored bands" % i)
		for j: int in range(i + 1, 4):
			_check(fails, not cfg.band_shade.is_equal_approx(MapRegions.BAND_SHADE[j])
					and not cfg.band_key.is_equal_approx(MapRegions.BAND_KEY[j])
					and not is_equal_approx(cfg.grade_hue_corridor,
					MapRegions.GRADE_HUE_CORRIDOR[j]),
					"act %d palette disagrees with act %d" % [i, j])
	var poisoned: ContentDB = ContentDB.new()
	poisoned.acts = [{"theme": {
		"sky": "#ffffff", "fog": "#ffffff", "particles": "#ffffff",
		"glow": "#ffffff", "accent": "#ffffff",
	}}]
	var baseline: MapRegions = MapRegions.for_act(0)
	var with_poison: MapRegions = MapRegions.for_act(0, poisoned)
	_check(fails, with_poison.sky.is_equal_approx(MapRegions.FALLBACK_SKIES[0])
			and with_poison.sky.is_equal_approx(baseline.sky)
			and with_poison.band_shade.is_equal_approx(baseline.band_shade),
			"for_act ignores the content pack theme dict")
	var act3: MapRegions = MapRegions.for_act(3, poisoned)
	_check(fails, act3.act == 3
			and act3.band_key.is_equal_approx(MapRegions.BAND_KEY[3])
			and act3.sky.is_equal_approx(MapRegions.FALLBACK_SKIES[3])
			and act3.weather == &"dawn"
			and not act3.sky.is_equal_approx(MapRegions.FALLBACK_SKIES[2]),
			"act 3 has its own ramp and 2D dawn row")
	var scene: MapScene = MapScene.new()
	_check(fails, scene.get_act() == 0, "MapScene starts on act 0")
	var seen: Array[Texture2D] = []
	var surface: Variant = null
	var g_val: float = NAN
	for act: int in range(4):
		scene.set_act(act)
		var ground: ShaderMaterial = _override(scene, "TerrainPlaceholder")
		var prop: ShaderMaterial = _override(scene, "FlatWedges")
		if ground == null or prop == null:
			_check(fails, false, "act %d materials missing" % act)
			continue
		if act == 0:
			surface = ground.get_shader_parameter("surface_tex")
			g_val = _as_float(ground.get_shader_parameter("surface_value"))
		_check(fails, scene.get_act() == act, "set_act(%d) sticks" % act)
		var grade: Variant = ground.get_shader_parameter("grade")
		var shade: Color = _as_color(ground.get_shader_parameter("band_shade"))
		_check(fails, grade is Texture2D and is_same(grade, prop.get_shader_parameter("grade")),
				"act %d ground and prop share one grade" % act)
		_check(fails, shade.is_equal_approx(_as_color(prop.get_shader_parameter("band_shade")))
				and not shade.is_equal_approx(_as_color(ground.get_shader_parameter("band_key"))),
				"act %d ground and prop ramps match and are distinct ends" % act)
		if grade is Texture2D:
			var tex: Texture2D = grade
			for prior: Texture2D in seen:
				_check(fails, not is_same(tex, prior),
						"act %d grade is not a previous act's texture" % act)
			seen.append(tex)
			if act == 0:
				if tex is ImageTexture:
					_grade_recipe(fails, tex)
				else:
					_check(fails, tex.get_width() == 512 and tex.get_height() == 256,
							"painted act 0 grade is the declared 512×256 row")
	var ground_end: ShaderMaterial = _override(scene, "TerrainPlaceholder")
	# `surface_tex` used to be asserted IDENTICAL across every act, which held
	# only while no act had a real tile and all four shared the one in-memory
	# fallback. Act I now binds `materials/act1-ground-ash-loam.png` while the
	# other three still fall back, so identity is the wrong invariant — and
	# keeping it would mean the gate fails the moment any act's tile lands.
	# What the check is really for is that an act switch never retints the
	# GROUND: the value lock holds and no albedo uniform appears. Hue lives in
	# the ramp ends and the grade, never in the surface.
	_check(fails, ground_end != null
			and is_equal_approx(g_val, MapMaterials.GROUND_VALUE)
			and is_equal_approx(_as_float(ground_end.get_shader_parameter("surface_value")),
				MapMaterials.GROUND_VALUE)
			and ground_end.get_shader_parameter("surface_tex") != null
			and ground_end.get_shader_parameter("albedo") == null,
			"act switch does not retint albedo / surface_value")
	_check(fails, surface != null,
			"act 0 binds a surface texture")
	scene.free()


static func _grade_recipe(fails: Array[String], tex: Texture2D) -> void:
	if not (tex is ImageTexture):
		_check(fails, false, "act 0 grade has a readable Image")
		return
	var grade_tex: ImageTexture = tex as ImageTexture
	var image: Image = grade_tex.get_image()
	if image == null:
		_check(fails, false, "act 0 grade has a readable Image")
		return
	_check(fails, image.get_width() == MapMaterials.GRADE_RESOLUTION.x
			and image.get_format() == Image.FORMAT_RGBA8,
			"grade is world-XZ RGBA8 at the proxy resolution")
	var under: Color = image.get_pixel(16, 29)
	var surround: Color = image.get_pixel(image.get_width() >> 1, 0)
	_check(fails, under.a < 0.5 and is_equal_approx(surround.a, 1.0),
			"contact lives in alpha (dark under props, 1.0 in the open)")
	_check(fails, surround.h > 0.85,
			"act 0 surround hue is crimson, aligned to the web act1 stage")


static func _as_color(v: Variant) -> Color:
	if v is Color:
		var c: Color = v
		return c
	if v is Vector3:
		var vec: Vector3 = v
		return Color(vec.x, vec.y, vec.z)
	return Color(0, 0, 0, 0)
