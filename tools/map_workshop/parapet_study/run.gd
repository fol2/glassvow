extends SceneTree
## Six controlled native captures; the approved chapter scene is untouched.
const M = preload("res://tools/map_workshop/mesh_tools.gd")
const Panels = preload("res://tools/map_workshop/parapet_study/panels.gd")
const DEST: String = "res://docs/map/studies/parapet-language/"
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DisplayServer.window_set_size(Vector2i(1458,820))
	root.size = Vector2i(1458,820)
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("10252f")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("85a9c4")
	env.environment.ambient_light_energy = .65
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	world.add_child(sun)
	sun.rotation_degrees = Vector3(-48,-35,0)
	sun.light_color = Color("bacdda")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.shadow_opacity = .65
	sun.shadow_normal_bias = .5
	var mats: Dictionary = preload("res://tools/map_workshop/stone_bridge/presets.gd").materials(preload("res://tools/map_workshop/stone_bridge/presets.gd").drowned_city())
	var stone: Material = mats["body"]
	var trim: Material = mats["trim"]
	var paving: Material = mats["deck"]
	M.box(world,Vector3(0,-.5,0),Vector3(90,.5,90),M.material(Color("233641")))
	var water: MeshInstance3D = preload("res://tools/map_workshop/water/surface.gd").new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(90,90)
	water.configure(plane,preload("res://tools/map_workshop/water/presets.gd").drowned_city())
	water.set_capture_time(2)
	water.position.y = .35
	world.add_child(water)
	M.box(world,Vector3(0,3.3,0),Vector3(12,.20,2.6),paving)
	# Two true structural arch openings beneath an unchanged deck.
	for centre: float in [-3,3]:
		for i: int in range(40):
			var a: float = -2.65+5.3*i/40.0
			var b: float = -2.65+5.3*(i+1)/40.0
			var ya: float = .75+2.05*sqrt(maxf(0,1-pow(a/2.65,2)))
			var yb: float = .75+2.05*sqrt(maxf(0,1-pow(b/2.65,2)))
			Panels.strip(world,centre+a,centre+b,0,2.6,ya,yb,3.2,3.2,stone)
			for side: int in [-1,1]:
				Panels.strip(world,centre+a,centre+b,side*1.32,.08,ya,yb,ya+.15,yb+.15,trim)
	for x: float in [-6,0,6]:
		M.box(world,Vector3(x,1.45,0),Vector3(.70,3.5,2.8),stone)
		M.box(world,Vector3(x,.12,0),Vector3(.95,.5,3.05),trim)
	for side: int in [-1,1]:
		for i: int in range(6):
			var height: float = 3.4-(i+1)*.17
			M.box(world,Vector3(side*(6.25+i*.5),(height-.35)*.5,0),Vector3(.5,height+.25,2.6),stone)
			M.box(world,Vector3(side*(6.25+i*.5),height-.025,0),Vector3(.5,.05,2.6),paving)
		M.box(world,Vector3(side*9.5,1.015,0),Vector3(1,2.63,3.1),stone)
		M.box(world,Vector3(side*9.5,2.355,0),Vector3(1,.05,3.1),paving)
	var figure: Node3D = preload("res://tools/map_workshop/pilgrim.gd").new()
	world.add_child(figure)
	figure.position = Vector3(.6,3.4,0)
	var camera: Camera3D = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 150
	camera.current = true
	for kind: String in ["a","b","c"]:
		var rails: Node3D = Node3D.new()
		world.add_child(rails)
		for side: int in [-1,1]:
			var z: float = side*1.28
			for bay: int in range(4):
				Panels.panel(rails,kind,-5.8+bay*3,-3.2+bay*3,z,stone,trim)
			for x: float in [-6,-3,0,3,6]:
				M.box(rails,Vector3(x,3.87,z),Vector3(.35,.94,.36),stone)
				M.box(rails,Vector3(x,4.39,z),Vector3(.46,.14,.48),trim)
			for sign_value: int in [-1,1]:
				for i: int in range(6):
					var x: float = sign_value*(6.25+i*.5)
					var y: float = 3.4-(i+1)*.17
					M.box(rails,Vector3(x,y+.35,z),Vector3(.16,.7,.20),stone)
				var rail: MeshInstance3D = M.box(rails,Vector3(sign_value*7.5,3.68,z),Vector3(3.17,.12,.28),trim)
				rail.rotation.z = -sign_value*atan(.34)
		for view: String in ["close","game"]:
			camera.size = 12 if view=="close" else 19
			camera.position = Vector3(7,9,14) if view=="close" else Vector3(10,23,22)
			camera.look_at(Vector3(0,3.1,0))
			for frame: int in range(12):
				await process_frame
				await RenderingServer.frame_post_draw
			var error: Error = root.get_texture().get_image().save_png(DEST+kind+"-"+view+".png")
			assert(error==OK)
			print("PARAPET_CAPTURE ",kind," ",view)
		rails.queue_free()
		await process_frame
	quit()
