extends SceneTree
## Native Act IV assembly; the compiled snapshot is the only route authority.
const Inspector = preload("res://tools/map_workshop/act4/inspection.gd")
const M = preload("res://presentation/map/landscape/mesh_tools.gd")
const Surface = preload("res://tools/map_workshop/common/resolved_route_surface.gd")
const Union = preload("res://tools/map_workshop/common/walking_surface_union.gd")
const FlightMesh = preload("res://tools/map_workshop/common/flight_mesh.gd")
var world: Node3D
var camera: Camera3D
var walking: MeshInstance3D
var sample: Dictionary
var structures: Array[Node3D] = []
var dimensions: Vector2i = Vector2i(1458,820)
var inspector: Inspector
var asset_cache: Dictionary = {}
var output: String = "/tmp/act4-blockout"
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var path: String = "res://docs/map/studies/act4-step3/void-v1/sample-717.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sample="): path = arg.trim_prefix("--sample=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--viewport="):
			var parts: PackedStringArray = arg.trim_prefix("--viewport=").split("x")
			dimensions = Vector2i(int(parts[0]),int(parts[1]))
	sample = JSON.parse_string(FileAccess.get_file_as_string(path))
	var source_errors: Array[String] = preload("res://tools/map_workshop/act4/audit.gd").source_errors(sample)
	if not source_errors.is_empty():
		push_error(str(source_errors))
		quit(1)
		return
	root.size = dimensions
	root.content_scale_size = dimensions
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.msaa_3d = Viewport.MSAA_4X
	world = Node3D.new()
	root.add_child(world)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CANVAS
	env.environment.background_canvas_max_layer = -1
	var background: CanvasLayer = CanvasLayer.new()
	background.layer = -10
	root.add_child(background)
	var void_rect: ColorRect = ColorRect.new()
	void_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	void_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var void_material: ShaderMaterial = ShaderMaterial.new()
	void_material.shader = load("res://tools/map_workshop/act4/void_background.gdshader")
	void_rect.material = void_material
	background.add_child(void_rect)
	env.environment.background_color = Color("111319")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b1b9ce")
	env.environment.ambient_light_energy = .24
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	world.add_child(preload("res://tools/map_workshop/act4/embers.gd").new())
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-30,0)
	sun.light_color = Color("bfc5dc")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 210
	world.add_child(sun)
	var paving: ShaderMaterial = ShaderMaterial.new()
	paving.shader = load("res://tools/map_workshop/act4/processional_stone.gdshader")
	preload("res://presentation/stage/mirrored_finish.gd").apply_world(paving)
	var plans: Array[Dictionary] = []
	for id: String in sample["edges"]:
		var edge: Dictionary = sample["edges"][id]
		var line: PackedVector3Array = []
		for p: Array in edge["centerline"]: line.append(M.v3(p))
		var plan: Dictionary = Surface.resolve(line,5.4,-1.5,8)
		assert(plan.get("ok")==true,str(plan))
		plans.append(plan)
	var routes: Dictionary = sample["edges"]
	var start_raw: Array = sample["anchors"]["n0"]
	var end_raw: Array = sample["anchors"]["n4"]
	var middle_raw: Array = sample["anchors"]["n2"]
	var start: Vector3 = M.v3(start_raw)
	var end: Vector3 = M.v3(end_raw)
	for spec: Array in [[start+Vector3(0,0,-4),28.0,14.0],[end+Vector3(0,0,-5),14.0,16.0]]:
		var centre: Vector3 = spec[0]
		var length: float = spec[1]
		var width: float = spec[2]
		plans.append(Surface.resolve(PackedVector3Array([centre+Vector3(-length*.5,0,0),centre+Vector3(length*.5,0,0)]),width,-1.5,8))
	for key: String in ["n1","n2","n3"]:
		var raw: Array = sample["anchors"][key]
		var at: Vector3 = M.v3(raw)
		plans.append(Surface.resolve(PackedVector3Array([at+Vector3(-3,0,0),at+Vector3(3,0,0)]),8,-1.5,8))
	var joined: Dictionary = Union.resolve(plans)
	assert(joined.get("ok")==true,str(joined))
	walking = M.node(world,FlightMesh.build(joined),paving,"ProcessionalWay")
	for placement: Dictionary in sample["hero_placements"].values():
		var source: Dictionary = sample["hero_sources"][placement["asset_id"]]
		var transform: Dictionary = placement["transform"]
		var origin_raw: Array = transform["origin"]
		var scale_raw: Array = transform["scale"]
		var hero: Node3D = _asset(str(source["path"]).get_file().get_basename(),M.v3(origin_raw))
		hero.scale = M.v3(scale_raw)
		hero.rotation.y = MapLayoutCanonical.float_value(transform["yaw_radians"])
		structures.append(hero)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.position = end+Vector3(0,2,-7)
	glow.light_color = Color("ffa34a")
	glow.light_energy = 4
	glow.omni_range = 25
	world.add_child(glow)
	var window_glow: OmniLight3D = OmniLight3D.new()
	window_glow.position = start+Vector3(0,7,-3)
	window_glow.light_color = Color("e7a34f")
	window_glow.light_energy = 8.0
	window_glow.omni_range = 22
	world.add_child(window_glow)
	var anchors: Dictionary = {}
	for id: String in sample["anchors"]:
		var raw: Array = sample["anchors"][id]
		anchors[id] = M.v3(raw)
	structures.append_array(preload("res://tools/map_workshop/act4/echoes.gd").build(world,anchors))
	var edge_index: int = 0
	for id: String in routes:
		var edge: Dictionary = routes[id]
		var line: Array = edge["centerline"]
		var a_raw: Array = line[1]
		var b_raw: Array = line[2]
		var a: Vector3 = M.v3(a_raw)
		var b: Vector3 = M.v3(b_raw)
		var side: Vector3 = (b-a).normalized().cross(Vector3.UP)
		var at: Vector3 = a.lerp(b,.42)+side*(2.08 if edge_index%2==0 else -2.08)
		var marker: Node3D = _asset("memory-stele",at)
		marker.scale = Vector3.ONE*(.70+edge_index*.06)
		marker.rotation.y = atan2(side.x,side.z)
		structures.append(marker)
		edge_index += 1
	var pilgrim: Node3D = preload("res://presentation/map/landscape/pilgrim.gd").new()
	world.add_child(pilgrim)
	pilgrim.position = anchors[sample["current"]]
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 400
	world.add_child(camera)
	camera.current = true
	_pose(Vector3(0,3,-1),104)
	for i: int in range(4): await process_frame
	await _capture("whole")
	_pose(start+Vector3(2,8,0),42)
	await _capture("window")
	_pose(M.v3(middle_raw)+Vector3(0,1,0),32)
	await _capture("journey")
	_pose(end+Vector3(0,2,-1),30)
	await _capture("hearth")
	var audit: Dictionary = preload("res://tools/map_workshop/common/threshold_mesh_audit.gd").run(structures,walking,routes,false)
	print("ACT4_SUPPORT ",JSON.stringify(audit))
	var foot_report: Dictionary = preload("res://tools/map_workshop/act4/audit.gd").feet(structures,walking)
	print("ACT4_FEET ",JSON.stringify(foot_report))
	if not foot_report["ok"]:
		quit(1)
		return
	if not audit["ok"]:
		for structure: Node3D in structures:
			var part: Dictionary = preload("res://tools/map_workshop/common/threshold_mesh_audit.gd").run([structure],walking,routes,false)
			if not part["ok"]: print("BLOCKING_STRUCTURE ",structure.name," ",JSON.stringify(part))
		quit(1)
		return
	if "--interactive" in OS.get_cmdline_user_args():
		inspector = Inspector.new()
		inspector.camera = camera
		inspector.world = world
		inspector.walking = walking
		inspector.pilgrim = pilgrim
		inspector.data = sample
		var points: Dictionary = {}
		for id: String in sample["anchors"]:
			var raw: Array = sample["anchors"][id]
			points[id] = M.v3(raw)
		inspector.anchors = points
		inspector.library_at = end
		for origin: Vector3 in [start,end]:
			for x: float in [-15,15]:
				for z: float in [-14,5]:
					for y: float in [0,29 if origin==start else 6]:
						inspector.chapter_points.append(origin+Vector3(x,y,z))
		inspector.chapter_points.append(M.v3(middle_raw)+Vector3(0,0,5))
		root.add_child(inspector)
		if "--exercise" in OS.get_cmdline_user_args():
			for i: int in range(4): await process_frame
			var input_report: Dictionary = await inspector.exercise()
			var guide_report: Dictionary = await inspector.exercise_guidance()
			print("ACT4_INPUT ",JSON.stringify(input_report))
			print("ACT4_GUIDANCE ",JSON.stringify(guide_report))
			inspector.focus_whole()
			await _capture("overview")
			inspector.focus_journey()
			await _capture("arrival")
			var input_ok: bool = true
			for value: Variant in input_report.values():
				if value is bool and not value: input_ok = false
			quit(0 if input_ok and guide_report["ok"] else 1)
		return
	quit(0)
func _pose(at: Vector3, size: float) -> void:
	camera.size = size
	camera.position = at+Vector3.UP*50+Vector3(sin(deg_to_rad(12)),0,cos(deg_to_rad(12)))*50/tan(deg_to_rad(55))
	camera.look_at(at)
func _capture(label: String) -> void:
	for i: int in range(3): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output+"-"+label+".png")==OK)

func _asset(label: String, at: Vector3) -> Node3D:
	if not asset_cache.has(label):
		var document: GLTFDocument = GLTFDocument.new()
		var state: GLTFState = GLTFState.new()
		assert(document.append_from_file("res://tools/map_workshop/act4/kit/"+label+".glb",state)==OK)
		var source: Node3D = document.generate_scene(state)
		_finish_kit(source)
		var packed: PackedScene = PackedScene.new()
		assert(packed.pack(source)==OK)
		asset_cache[label] = packed
		source.free()
	var packed: PackedScene = asset_cache[label]
	var item: Node3D = packed.instantiate()
	world.add_child(item)
	item.position = at
	item.name = label
	return item

func _finish_kit(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node
		for i: int in range(mesh_node.mesh.get_surface_count()):
			var mat: Material = mesh_node.mesh.surface_get_material(i)
			if not mat is StandardMaterial3D: continue
			var original: StandardMaterial3D = mat
			var name_value: String = original.resource_name
			if not (name_value.begins_with("Amber pane") or name_value.begins_with("Stone course") or name_value=="Charcoal dressed stone"): continue
			var finish: ShaderMaterial = ShaderMaterial.new()
			finish.shader = preload("res://tools/map_workshop/act4/kit_finish.gdshader")
			finish.set_shader_parameter("tint",original.albedo_color)
			finish.set_shader_parameter("glass",1.0 if name_value.begins_with("Amber pane") else 0.0)
			mesh_node.set_surface_override_material(i,finish)
	for child: Node in node.get_children(): _finish_kit(child)
