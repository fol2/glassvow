extends Control
## Native material and form review under the same camera/light as the workshop.
const Meshes = preload("res://tools/map_workshop/mesh_tools.gd")
const AssetLights = preload("res://tools/map_workshop/asset_lights.gd")
const AssetSurfaces = preload("res://tools/map_workshop/asset_surfaces.gd")
var IDS: Array[String] = ["amber-arch", "conifer", "ash-copse", "slate-bank", "memorial", "waystone", "bridge-bay"]
var LABELS: Array[String] = ["Paired-lamp arch", "Charcoal conifer", "Ash-red copse", "Slate bank", "Memorial", "Waystone", "Bridge bay"]
var POSITIONS: Array[Vector3] = [Vector3(-7,0,-2.5),Vector3(0,0,-2.5),Vector3(5.5,0,-2.5),Vector3(-7,0,3.3),Vector3(-2.3,0,3.3),Vector3(1.1,0,3.3),Vector3(6.0,0,3.3)]
var models: Array[Node3D] = []
var labels: Array[Label] = []
var camera: Camera3D
var stage: SubViewport
var failure: String = ""
var angle: float = 0
var hero_override: String = ""

func _ready() -> void:
	if "--variety" in OS.get_cmdline_user_args() or "--new-variety" in OS.get_cmdline_user_args():
		IDS = ["conifer", "conifer-spire", "ash-copse", "ash-heath", "slate-bank", "slate-ridge"]
		LABELS = ["Broad charcoal conifer", "Sparse charcoal spire", "Upright ash copse", "Spreading ash heath", "Standing slate bank", "Low slate ridge"]
		POSITIONS = [Vector3(-7,0,-2.5), Vector3(-1,0,-2.5), Vector3(5.5,0,-2.5), Vector3(-7,0,3.5), Vector3(-1,0,3.5), Vector3(5.5,0,3.5)]
		hero_override = ""
		if "--new-variety" in OS.get_cmdline_user_args():
			IDS = ["conifer-wind","conifer-snag","ash-bramble","ash-fern","slate-shard","slate-scree"]
			LABELS = ["Wind-bent pine","Forked woodland snag","Trailing thorn bramble","Divided woodland fern","Split slate blade","Part-buried scree"]
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage = SubViewport.new()
	stage.size = Vector2i(size)
	stage.own_world_3d = true
	stage.msaa_3d = Viewport.MSAA_4X
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var world: Node3D = Node3D.new()
	stage.add_child(world)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(-55,0,0)
	camera.position = Vector3(0,24,24/tan(deg_to_rad(55)))
	camera.size = 14.5
	camera.current = true
	world.add_child(camera)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52,-32,0)
	key.light_color = Color("ddd7d2")
	key.light_energy = 0.95
	key.shadow_enabled = true
	key.shadow_opacity = 0.68
	world.add_child(key)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("292731")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a19caa")
	environment.ambient_light_energy = 0.50
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var setting: WorldEnvironment = WorldEnvironment.new()
	setting.environment = environment
	world.add_child(setting)
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(100,100)
	Meshes.node(world,plane,Meshes.material(Color("1f2029")),"Neutral review ground").position.y=-0.025
	for i: int in range(IDS.size()):
		var path: String = "res://assets/art/map-journey/%s.glb" % IDS[i]
		if i == 0 and not hero_override.is_empty():
			path = hero_override
		var source: PackedScene = load(path) as PackedScene
		if source == null:
			failure = "Missing gallery asset " + IDS[i]
			push_error(failure)
			return
		var model: Node3D = source.instantiate() as Node3D
		world.add_child(model)
		model.position = POSITIONS[i]
		var foliage_surfaces: int = AssetSurfaces.prepare(model)
		if IDS[i] in ["conifer", "conifer-spire", "ash-copse", "ash-heath"] and foliage_surfaces == 0:
			failure = "No cut-out foliage surface prepared: " + IDS[i]
			return
		if hero_override.is_empty() or i != 0:
			AssetLights.attach(model, IDS[i])
		elif not AssetLights.attach_trial(model):
			failure = "Missing trial lamp attachment"
			return
		models.append(model)
	var display: TextureRect = TextureRect.new()
	display.texture = stage.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	for i: int in range(IDS.size()):
		var label: Label = Label.new()
		label.text = LABELS[i]
		if i == 0 and not hero_override.is_empty():
			label.text = "Arch trial · paired lamps"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size.x = 180
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color",Color("d5c5b7"))
		add_child(label)
		labels.append(label)
	var title: Label = Label.new()
	title.text = "ACT I / SCULPTED ASSET STUDY"
	title.position = Vector2(24,18)
	title.add_theme_font_size_override("font_size",22)
	add_child(title)
	var hint: Label = Label.new()
	hint.text = "Native Godot render · 55° camera · original Blender geometry · shared light and shadow"
	if not hero_override.is_empty():
		hint.text = "Native Godot render · 55° camera · external arch trial beside original kit · shared key light"
	hint.position = Vector2(24,50)
	hint.add_theme_font_size_override("font_size",13)
	add_child(hint)
	for i: int in range(2):
		var button: Button = Button.new()
		button.text = "↶ Rotate" if i == 0 else "Rotate ↷"
		button.position = Vector2(size.x-250+i*115,18)
		button.size = Vector2(110,44)
		button.pressed.connect(rotate_models.bind(-0.35 if i==0 else 0.35))
		add_child(button)
	resized.connect(func() -> void: stage.size=Vector2i(size))

func rotate_models(delta: float) -> void:
	angle += delta
	for model: Node3D in models:
		model.rotation.y = angle

func _process(_delta: float) -> void:
	if camera == null:
		return
	for i: int in range(labels.size()):
		labels[i].position = camera.unproject_position(POSITIONS[i]+Vector3(0,0,1.4)) - Vector2(90,-9)
