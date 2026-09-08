extends SceneTree
## Isolated native Step 3 study; the campaign and source fixture remain untouched.
const Palette = preload("res://tools/map_workshop/act3/materials.gd")
var output: String = ""
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var whole: bool = false
	var phone: bool = false
	var inspection: bool = false
	var exercise: bool = false
	var journey: bool = false
	var clean: bool = false
	var pad: bool = false
	var scenery_view: bool = false
	var passage_view: bool = false
	var frames_directory: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		if arg.begins_with("--frames="):
			frames_directory = arg.trim_prefix("--frames=")
		pad = pad or arg=="--pad"
		scenery_view = scenery_view or arg=="--scenery"
		passage_view = passage_view or arg=="--passage"
		whole = whole or arg=="--whole"
		phone = phone or arg=="--phone"
		inspection = inspection or arg=="--inspect"
		exercise = exercise or arg=="--exercise"
		journey = journey or arg=="--journey"
		clean = clean or arg=="--clean"
	root.size = Vector2i(844,390) if phone else Vector2i(1458,820)
	if pad:
		root.size = Vector2i(1180,820)
	DisplayServer.window_set_size(root.size)
	root.content_scale_size = root.size
	root.msaa_3d = Viewport.MSAA_4X
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--debug-wireframe":
			RenderingServer.set_debug_generate_wireframes(true)
			root.debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
		elif arg == "--debug-unshaded":
			root.debug_draw = Viewport.DEBUG_DRAW_UNSHADED

	var world: Node3D = Node3D.new()
	root.add_child(world)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("100d18")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a99dbd")
	env.ambient_light_energy = .85
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = env
	world.add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	world.add_child(sun)
	sun.rotation_degrees = Vector3(-48,-35,0)
	sun.light_color = Color("cdc2e0")
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160
	var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/studies/camera-composition/act3-seed717.json"))
	var routes: Node3D = preload("res://tools/map_workshop/act3/routes.gd").new()
	routes.levels = preload("res://presentation/map/chapters/common/terrace_levels.gd").new()
	routes.ruin_plan = preload("res://tools/map_workshop/act3/destination.gd").new()
	routes.bridge_style = preload("res://presentation/map/chapters/stone_bridge/presets.gd").drowned_city()
	routes.bridge_style["water_level"] = -10.0
	routes.bridge_style["foundation_level"] = -1.8
	routes.material_factory = func(settings: Dictionary) -> Dictionary: return Palette.bridge(settings)
	world.add_child(routes)
	routes.build(sample)
	if not routes.failure.is_empty():
		push_error(routes.failure)
		quit(1)
		return
	var ground: Node3D = preload("res://tools/map_workshop/act3/ground.gd").new()
	world.add_child(ground)
	ground.build(routes)
	var scenery: Node3D = preload("res://tools/map_workshop/act3/scenery.gd").new()
	world.add_child(scenery)
	scenery.build(routes,ground)
	var enclosure: Node3D = preload("res://tools/map_workshop/act3/enclosure.gd").new()
	scenery.add_child(enclosure)
	enclosure.build(ground)
	var palace: Node3D = preload("res://tools/map_workshop/act3/precinct.gd").new()
	world.add_child(palace)
	palace.build()
	palace.manual_time = not frames_directory.is_empty()
	var site: Dictionary = routes.ruin_plan.sites[0]
	palace.position = site["centre"]
	palace.rotation.y = site["yaw"]
	if "--debug-depth" in OS.get_cmdline_user_args():
		var depth: ShaderMaterial = ShaderMaterial.new()
		depth.shader = Shader.new()
		depth.shader.code = "shader_type spatial; render_mode unshaded; void fragment(){ ALBEDO = vec3(1.0-clamp((-VERTEX.z-5.0)/80.0,0.0,1.0)); }"
		_apply_depth_material(world, depth)
	var camera: Camera3D = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 400
	camera.size = 43 if not whole else 110
	var target: Vector3 = palace.position+Vector3(0,5,0) if not whole else Vector3(12,2,0)
	camera.position = target+Vector3(-42, 60.0,45)
	camera.look_at(target)
	camera.current = true
	var inspector: CanvasLayer
	if inspection:
		inspector = preload("res://tools/map_workshop/act3/inspect.gd").new()
		inspector.chapter_heading = "  III  /  THE OBSIDIAN COURT"
		inspector.landmark_label = "Court"
		inspector.camera = camera
		inspector.world = world
		inspector.data = sample
		inspector.anchors = routes.anchors
		inspector.library_at = palace.position
		inspector.landmark = palace
		inspector.ruin_owners[site["node"]] = "Sovereign court"
		root.add_child(inspector)
		if whole:
			inspector.focus_whole()
		elif journey:
			inspector.focus_journey()
		else:
			inspector.focus_library()
	if scenery_view and not scenery.placed.is_empty():
		var place: Vector2 = scenery.placed[0]["at"]
		var at: Vector3 = ground._point(place.x,place.y)+Vector3.UP*3
		camera.position = at+Vector3(16,24,22)
		camera.look_at(at)
		camera.size = 27
	if passage_view:
		var cut: Dictionary = routes.levels.cuts[1]
		var at: Vector2 = cut["at"]
		var direction: Vector2 = cut["direction"]
		var side: Vector2 = Vector2(-direction.y,direction.x)
		var focus: Vector3 = Vector3(at.x,3.4,at.y)
		camera.position = focus+Vector3(-direction.x*20+side.x*13,19,-direction.y*20+side.y*13)
		camera.look_at(focus)
		camera.size = 25
	if clean and is_instance_valid(inspector):
		inspector.visible = false
		camera.size *= .80
	for warm_frame: int in range(40):
		await process_frame
	if exercise:
		var audit: Dictionary = preload("res://tools/map_workshop/act3/audit.gd").measure(routes,sample)
		audit["clearance"] = preload("res://tools/map_workshop/act3/clearance.gd").new().measure(ground,palace,routes,scenery)
		print("ACT_III_ROUTE_AUDIT ",JSON.stringify(audit))
		var receipt: FileAccess = FileAccess.open(output.get_basename()+"-geometry.json",FileAccess.WRITE)
		receipt.store_string(JSON.stringify(audit,"  ")+"\n")
		if is_instance_valid(inspector):
			var inputs: Dictionary = await inspector.exercise()
			var input_file: FileAccess = FileAccess.open(output.get_basename()+"-input.json",FileAccess.WRITE)
			input_file.store_string(JSON.stringify(inputs,"  ")+"\n")
	var started: int = Time.get_ticks_usec()
	for frame: int in range(120):
		await process_frame
	print("ACT_III_RENDER_SAMPLE ",JSON.stringify({"frames":120,"seconds":(Time.get_ticks_usec()-started)/1000000.0,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"scope":"Native host, warmed steady scene; not target-device qualification"}))
	if not frames_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(frames_directory)
		for frame: int in range(180):
			palace.set_capture_time(frame/30.0)
			await process_frame
			await RenderingServer.frame_post_draw
			var frame_error: Error = root.get_texture().get_image().save_png(frames_directory.path_join("%04d.png" % frame))
			if frame_error!=OK:
				push_error("Could not save halo frame")
				quit(1)
				return
	await RenderingServer.frame_post_draw
	if not output.is_empty():
		var result: Error = root.get_texture().get_image().save_png(output)
		print("ACT_III_TRIAL_CAPTURE ",result," ",output)
		quit(0 if result==OK else 1)


func _apply_depth_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh: MeshInstance3D = node
		mesh.material_override = material
	for child: Node in node.get_children():
		_apply_depth_material(child, material)
