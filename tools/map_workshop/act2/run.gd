extends SceneTree
## Headed, isolated native architecture study. No campaign or save mutation.
const Library = preload("res://presentation/map/chapters/act2/library.gd")
const M = preload("res://presentation/map/landscape/mesh_tools.gd")
const SharedWater = preload("res://presentation/map/chapters/water/surface.gd")
var output: String = ""
var chapter: bool = false
var clean: bool = false
var water_visible: bool = true
var detail_view: String = ""
var whole: bool = false
var audit_only: bool = false
var inspection: bool = false
var frames_directory: String = ""
var journey_view: bool = false
var exercise: bool = false
var inspector: CanvasLayer
var dimensions: Vector2i = Vector2i(1458,820)
var study_data: Dictionary = {}
var study_anchors: Dictionary = {}
var study_causeways: Node3D
var architecture: Array[Node3D] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1458,820)
	root.msaa_3d = Viewport.MSAA_4X
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg == "--no-water":
			water_visible = false
		elif arg == "--clean":
			clean = true
		elif arg.begins_with("--detail="):
			detail_view = arg.trim_prefix("--detail=")
		elif arg == "--chapter":
			chapter = true
		elif arg == "--audit-only":
			audit_only = true
			chapter = true
		elif arg == "--whole":
			whole = true
		elif arg.begins_with("--frames="):
			frames_directory = arg.trim_prefix("--frames=")
		elif arg == "--inspect":
			inspection = true
			chapter = true
		elif arg == "--exercise":
			exercise = true
		elif arg == "--journey":
			journey_view = true
		elif arg == "--phone":
			dimensions = Vector2i(844,390)
		elif arg == "--pad":
			dimensions = Vector2i(1180,820)
	DisplayServer.window_set_size(dimensions)
	root.size = dimensions
	root.content_scale_size = dimensions
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var settings: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("10252f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("85a9c4")
	environment.ambient_light_energy = .65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.environment = environment
	world.add_child(settings)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	world.add_child(sun)
	sun.rotation_degrees = Vector3(-48,-35,0)
	sun.light_color = Color("bacdda")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.shadow_opacity = .65
	sun.light_angular_distance = .8
	sun.shadow_bias = .2
	sun.shadow_normal_bias = 2.0
	sun.directional_shadow_max_distance = 55
	var library: Library = Library.new()
	world.add_child(library)
	architecture.append(library)
	if chapter:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/studies/camera-composition/act2-seed717.json"))
		var causeways: Node3D = preload("res://presentation/map/chapters/act2/causeways.gd").new()
		world.add_child(causeways)
		causeways.build(data)
		if not causeways.failure.is_empty():
			push_error(causeways.failure)
			quit(1)
			return
		study_data = data
		study_anchors = causeways.anchors
		study_causeways = causeways
		var audit: Dictionary = preload("res://tools/map_workshop/act2/audit.gd").measure(causeways,data)
		var connections: Array[Dictionary] = []
		for site: Dictionary in causeways.ruin_plan.sites:
			connections.append({"ruin":site["ordinal"],"kind":site["kind"],"node":site["node"],"entrance":str(site["door"]),"centre":str(site["centre"])})
		audit["ruin_connections"] = connections
		print("ACT_II_GEOMETRY_AUDIT ",JSON.stringify(audit))
		if not output.is_empty():
			var receipt: FileAccess = FileAccess.open(output.get_basename()+"-geometry.json",FileAccess.WRITE)
			receipt.store_string(JSON.stringify(audit,"  ")+"\n")
		if audit_only:
			quit()
			return
		for site: Dictionary in causeways.ruin_plan.sites:
			var building: Node3D
			var kind: String = site["kind"]
			var ordinal: int = site["ordinal"]
			if kind=="library":
				building = library
			elif kind=="ward":
				building = preload("res://presentation/map/chapters/act2/ward.gd").new()
				world.add_child(building)
				building.build_ward(6.6 if site["ordinal"]==1 else 5.4,ordinal%2==0)
				architecture.append(building)
			else:
				building = preload("res://presentation/map/chapters/act2/sunken_quarter.gd").new()
				world.add_child(building)
				building.build(ordinal-4)
				architecture.append(building)
			building.position = site["centre"]
			building.rotation.y = site["yaw"]
	library.connected_forecourt = chapter
	library.build(1.18-library.position.y)
	if chapter:
		var scenery: Node3D = preload("res://presentation/map/chapters/act2/scenery.gd").new()
		world.add_child(scenery)
		scenery.build(study_causeways)
		architecture.append(scenery)
		var placement: Dictionary = preload("res://tools/map_workshop/act2/placement_audit.gd").new().measure(architecture,study_causeways)
		placement["scenery"] = {"instances":scenery.placed.size(),"families":scenery.counts,"shared_meshes":scenery.assets.meshes.size()}
		print("ACT_II_PLACEMENT_AUDIT ",JSON.stringify(placement))
		if not output.is_empty():
			var receipt: FileAccess = FileAccess.open(output.get_basename()+"-placement.json",FileAccess.WRITE)
			receipt.store_string(JSON.stringify(placement,"  ")+"\n")
	M.box(world,Vector3(0,-1,0),Vector3(240,1,240),M.material(Color("112b32")),"FloodBed")
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(240,240)
	var water_mesh: SharedWater = SharedWater.new()
	water_mesh.configure(plane,preload("res://presentation/map/chapters/water/presets.gd").drowned_city())
	water_mesh.name = "FloodWater"
	world.add_child(water_mesh)
	water_mesh.position.y = 1.18
	water_mesh.visible = water_visible
	var camera: Camera3D = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 19
	camera.far = 80
	camera.position = Vector3(15,22,25)
	camera.look_at(Vector3(0,2,0))
	if chapter:
		camera.position += library.position
		camera.look_at(library.position+Vector3(2,2,3))
		camera.size = 28
		if whole:
			camera.size = 60
			camera.position = Vector3(0,52,42)
			camera.far = 150
			camera.look_at(Vector3(0,0,-2))
	camera.current = true
	if inspection:
		inspector = preload("res://tools/map_workshop/act2/inspect.gd").new()
		inspector.camera = camera
		inspector.world = world
		inspector.data = study_data
		inspector.anchors = study_anchors
		inspector.library_at = library.position
		for site: Dictionary in study_causeways.ruin_plan.sites:
			inspector.ruin_centres.append(site["centre"])
			inspector.ruin_owners[site["node"]] = "Boss library" if site["kind"]=="library" else "Sunken ruin approach (decoration)"
		root.add_child(inspector)
		if whole:
			inspector.focus_whole()
		elif journey_view:
			inspector.focus_journey()
		else:
			inspector.focus_library()
	if not detail_view.is_empty():
		preload("res://tools/map_workshop/act2/review_views.gd").apply(detail_view,camera,library,study_causeways,world)
	if clean and is_instance_valid(inspector):
		inspector.visible = false
	var warm_start: int = Time.get_ticks_usec()
	for frame: int in range(50):
		await process_frame
	var elapsed: float = (Time.get_ticks_usec()-warm_start)/1000000.0
	print("ACT_II_WARM_RENDER frames=50 seconds=",elapsed," average_fps=",50.0/elapsed)
	if not frames_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(frames_directory)
		for frame: int in range(240):
			water_mesh.set_capture_time(frame/30.0)
			await process_frame
			await RenderingServer.frame_post_draw
			var frame_error: Error = root.get_texture().get_image().save_png(frames_directory.path_join("%04d.png" % frame))
			if frame_error != OK:
				push_error("Could not save water film frame "+str(frame))
				quit(1)
				return
		print("ACT_II_WATER_FILM frames=240 fps=30 seconds=8 ",frames_directory)
	if exercise and is_instance_valid(inspector):
		var interaction: Dictionary = await inspector.exercise()
		print("ACT_II_INPUT_AUDIT ",JSON.stringify(interaction))
		if not output.is_empty():
			var receipt: FileAccess = FileAccess.open(output.get_basename()+"-input.json",FileAccess.WRITE)
			receipt.store_string(JSON.stringify(interaction,"  ")+"\n")
	if not output.is_empty():
		# Camera changes enqueue CanvasItem transforms; capture after complete
		# subsequent frames, rather than the frame that dispatched the click.
		for settled_frame: int in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var error: Error = root.get_texture().get_image().save_png(output)
		print("ACT_II_ARCHITECTURE_CAPTURE ",error," ",output)
		quit(0 if error == OK else 1)
