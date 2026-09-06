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
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		whole = whole or arg=="--whole"
		phone = phone or arg=="--phone"
		inspection = inspection or arg=="--inspect"
		exercise = exercise or arg=="--exercise"
		journey = journey or arg=="--journey"
		clean = clean or arg=="--clean"
	root.size = Vector2i(844,390) if phone else Vector2i(1458,820)
	DisplayServer.window_set_size(root.size)
	root.content_scale_size = root.size
	root.msaa_3d = Viewport.MSAA_4X
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
	var routes: Node3D = preload("res://tools/map_workshop/common/fitted_routes.gd").new()
	routes.levels = preload("res://tools/map_workshop/common/terrace_levels.gd").new()
	routes.ruin_plan = preload("res://tools/map_workshop/act3/destination.gd").new()
	routes.bridge_style = preload("res://tools/map_workshop/stone_bridge/presets.gd").drowned_city()
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
	var site: Dictionary = routes.ruin_plan.sites[0]
	palace.position = site["centre"]
	palace.rotation.y = site["yaw"]
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
	for frame: int in range(40):
		await process_frame
	await RenderingServer.frame_post_draw
	if not output.is_empty():
		var result: Error = root.get_texture().get_image().save_png(output)
		print("ACT_III_TRIAL_CAPTURE ",result," ",output)
		quit(0 if result==OK else 1)

