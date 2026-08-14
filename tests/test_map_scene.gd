extends RefCounted
## #234 slice 2–4: MapScene shaders, tex_stop bind, freeze switch, act palettes.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_scene: %s" % what)


static func run(fails: Array[String]) -> void:
	_rig(fails)
	_scene(fails)
	_input(fails)
	_materials(fails)
	_palette(fails)


static func _rig(fails: Array[String]) -> void:
	var rig: MapCameraRig = MapCameraRig.new()
	var cam: Camera3D = rig.get_camera()
	_check(fails, cam.projection == Camera3D.PROJECTION_ORTHOGONAL,
			"camera is orthographic")
	_check(fails, cam.rotation_degrees.x >= -60.0
			and cam.rotation_degrees.x <= -50.0,
			"pitch sits in the signed 50–60° band")
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
	_check(fails, MapRegions.BAND_SHADE[0].h > 0.88,
			"act 0 shade hue is crimson (~328°, the web act1 stage)")
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
				_grade_recipe(fails, tex)
	var ground_end: ShaderMaterial = _override(scene, "TerrainPlaceholder")
	_check(fails, ground_end != null
			and is_equal_approx(g_val, MapMaterials.GROUND_VALUE)
			and is_same(surface, ground_end.get_shader_parameter("surface_tex"))
			and ground_end.get_shader_parameter("albedo") == null,
			"act switch does not retint albedo / surface_tex / surface_value")
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
