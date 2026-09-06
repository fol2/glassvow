extends SceneTree
## Native contact sheet of all shared aquatic models under the chapter lighting.
const Assets = preload("res://tools/map_workshop/act2/scenery_assets.gd")
const M = preload("res://tools/map_workshop/mesh_tools.gd")
func _initialize() -> void:
	_build.call_deferred()

func _build() -> void:
	root.size = Vector2i(1458,820)
	DisplayServer.window_set_size(root.size)
	root.msaa_3d = Viewport.MSAA_4X
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("10252f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("85a9c4")
	environment.ambient_light_energy = .65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var settings: WorldEnvironment = WorldEnvironment.new()
	settings.environment = environment
	world.add_child(settings)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	world.add_child(sun)
	sun.rotation_degrees = Vector3(-48,-35,0)
	sun.light_color = Color("bacdda")
	sun.light_energy = 1.1
	var kit: Assets = Assets.new()
	kit.build()
	for column: int in range(6):
		var kind: String = kit.KINDS[column]
		for row: int in range(3):
			var mesh: ArrayMesh = kit.meshes[kind+str(row)]
			M.node(world,mesh,kit.material,kind+str(row)).position = Vector3((column-2.5)*4.6,0,(row-1)*4.7)
	M.box(world,Vector3(0,-1,0),Vector3(70,1,70),M.material(Color("112b32")),"FloodBed")
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(70,70)
	var water: Node3D = preload("res://tools/map_workshop/water/surface.gd").new()
	water.configure(plane,preload("res://tools/map_workshop/water/presets.gd").drowned_city())
	world.add_child(water)
	water.position.y = 1.18
	water.set_capture_time(2.0)
	var camera: Camera3D = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	camera.position = Vector3(0,26,25)
	camera.look_at(Vector3(0,0,-1))
	camera.current = true
	for i: int in range(40):
		await process_frame
	await RenderingServer.frame_post_draw
	var output: String = "res://docs/map/studies/act2-step3/scenery-v2-assets.png"
	var error: Error = root.get_texture().get_image().save_png(output)
	print("SCENERY_GALLERY_CAPTURE ",error)
	quit(0 if error==OK else 1)
