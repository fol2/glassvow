extends Control
## Native isolated workshop. Domain WorldMap controls legal preview steps.
const Terrain = preload("res://presentation/map/landscape/terrain.gd")
const Rig = preload("res://tools/map_workshop/camera.gd")
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
const Kit = preload("res://presentation/map/landscape/kit.gd")
const Pin = preload("res://tools/map_workshop/journey_pin.gd")
const Journey = preload("res://presentation/map/landscape/journey.gd")
const TYPES: Dictionary = {"monster": "×", "elite": "✦", "event": "?", "rest": "⌂", "shop": "¤", "treasure": "◇", "boss": "♜", "monument": "†"}
var sample: Dictionary
var world_map: WorldMap
var stage: SubViewport
var rig: Rig
var terrain: Terrain
var world: Node3D
var stones: Array[Button] = []
var anchors: PackedVector3Array = []
var source_anchors: PackedVector3Array = []
var selected: int = -1
var whole: bool = false
var show_stones: bool = true
var greybox: bool = true
var dragging: bool = false
var drag_distance: float = 0.0
var title_label: Label
var detail: Label
var travel: Button
var journey_button: Button
var survey_button: Button
var kit: Kit
var step_count: int = 0
var journey: Journey
var travelling: bool = false
var reduced_motion: bool = false
var hero_override: String = ""
var motion_button: Button
var hint_label: Label

func setup(data: Dictionary, map: WorldMap, grey: bool) -> void:
	sample = data
	world_map = map
	greybox = grey
	for node: MapNode in world_map.nodes:
		var value: Array = data["anchors"][node.id]
		anchors.append(Meshes.v3(value))
		source_anchors.append(Meshes.v3(value))

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_world()
	_build_hud()
	_make_stones()
	resized.connect(_resize)
	_resize()
	focus_journey(true)
	_apply_motion()
	_sync()

func _build_world() -> void:
	stage = SubViewport.new()
	stage.name = "WorkshopStage"
	stage.own_world_3d = true
	stage.msaa_3d = Viewport.MSAA_4X
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	world = Node3D.new()
	stage.add_child(world)
	rig = Rig.new()
	world.add_child(rig)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("252530")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a19caa")
	environment.ambient_light_energy = 0.50
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var setting: WorldEnvironment = WorldEnvironment.new()
	setting.environment = environment
	world.add_child(setting)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52, -32, 0)
	key.light_color = Color("ddd7d2")
	key.light_energy = 0.95
	key.shadow_enabled = true
	key.shadow_opacity = 0.68
	key.directional_shadow_max_distance = 130
	world.add_child(key)
	terrain = Terrain.new()
	world.add_child(terrain)
	terrain.build(sample, greybox)
	for i: int in range(anchors.size()):
		anchors[i] = terrain.present(anchors[i])
	kit = Kit.new()
	kit.hero_override = hero_override
	world.add_child(kit)
	kit.build(terrain, anchors, greybox)
	if not greybox and kit.build_complete:
		preload("res://presentation/map/landscape/road_details.gd").build(terrain)
	var display: TextureRect = TextureRect.new()
	display.texture = stage.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	journey = Journey.new()
	world.add_child(journey)
	journey.reduced_motion = reduced_motion
	journey.build(terrain,anchors,source_anchors)

func _build_hud() -> void:
	var top: Panel = Panel.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 60
	add_child(top)
	_style_panel(top)
	title_label = Label.new()
	title_label.text = "ACT I  /  THE ASHEN WOODS"
	title_label.position = Vector2(18, 10)
	title_label.add_theme_font_size_override("font_size", 19)
	title_label.add_theme_font_override("font",preload("res://assets/fonts/Cinzel-500.woff2"))
	title_label.add_theme_color_override("font_color",Color("e8d6b9"))
	top.add_child(title_label)
	var hint: Label = Label.new()
	hint_label = hint
	hint.text = "A road through the ash · drag to explore · scroll to see further"
	hint.position = Vector2(18, 35)
	hint.add_theme_font_size_override("font_size", 12)
	top.add_child(hint)
	var controls: HBoxContainer = HBoxContainer.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	controls.offset_left = -374
	controls.offset_right = -12
	controls.offset_top = 8
	controls.offset_bottom = 52
	top.add_child(controls)
	journey_button = _button("Journey", controls, func() -> void: focus_journey())
	survey_button = _button("Whole act", controls, focus_all)
	_button("−", controls, func() -> void: rig.zoom_by(1.2))
	_button("+", controls, func() -> void: rig.zoom_by(0.84))
	motion_button = _button("Motion",controls,_toggle_motion)
	var bottom: Panel = Panel.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -72
	add_child(bottom)
	_style_panel(bottom)
	detail = Label.new()
	detail.position = Vector2(18, 9)
	detail.add_theme_font_size_override("font_size", 15)
	bottom.add_child(detail)
	var footer: Label = Label.new()
	footer.text = "Journey study · encounters resolve on arrival · progress is not saved"
	footer.position = Vector2(18, 40)
	footer.add_theme_font_size_override("font_size", 11)
	bottom.add_child(footer)
	travel = _button("Choose a next stone", bottom, _travel)
	travel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	travel.offset_left = -216
	travel.offset_right = -16
	travel.offset_top = -61
	travel.offset_bottom = -17
	travel.disabled = true

func _style_panel(panel: Panel) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.059, 0.073, 0.96)
	style.border_color = Color("4b4143")
	style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", style)

func _button(label: String, parent: Node, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(44, 44)
	button.add_theme_font_size_override("font_size", 14)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("29232b")
	style.border_color = Color("5c4d45")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal",style)
	button.add_theme_color_override("font_color",Color("e7d6bb"))
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _make_stones() -> void:
	for i: int in range(world_map.nodes.size()):
		var button: Pin = Pin.new()
		button.size = Vector2(48, 48)
		button.add_theme_font_size_override("font_size", 21)
		button.tooltip_text = world_map.nodes[i].type.capitalize()
		button.pressed.connect(_select.bind(i))
		add_child(button)
		stones.append(button)

func _sync() -> void:
	var reachable: Array[int] = world_map.reachable()
	for i: int in range(stones.size()):
		var node: MapNode = world_map.nodes[i]
		var visited: bool = world_map.is_cleared(i)
		var pin: Pin = stones[i] as Pin
		pin.configure(node,reachable.has(i),i==world_map.at,visited,i==selected)
		pin.disabled = travelling
	journey.sync(world_map,selected)
	var chosen: String = "Select a stone to inspect your next step"
	if selected >= 0:
		var node: MapNode = world_map.nodes[selected]
		chosen = "%s · stage %d" % ["Unknown encounter" if node.unlit else node.type.capitalize(), node.row + 1]
		if node.unlit:
			chosen += " · bounty %d" % node.bounty
	detail.text = "Whole act · select an area to look closer" if whole else chosen
	travel.disabled = whole or travelling or selected < 0 or not reachable.has(selected)
	travel.text = "Walking…" if travelling else ("Walk here" if not travel.disabled else "Choose a next stone")

func _select(index: int) -> void:
	if travelling or drag_distance > 8:
		return
	selected = index
	if whole:
		whole = false
		var points: PackedVector3Array = [anchors[index]]
		for to_id: String in world_map.nodes[index].next:
			var raw: Array = sample["anchors"][to_id]
			points.append(terrain.present(Meshes.v3(raw)))
		rig.frame(points, size, false)
	_sync()

func _travel() -> void:
	if travelling or selected<0 or not world_map.reachable().has(selected):
		return
	var target: int = selected
	var route: PackedVector3Array = []
	if world_map.at>=0:
		route = journey.path(world_map.nodes[world_map.at].id,world_map.nodes[target].id)
		if route.size()<2:
			push_error("A reachable journey is missing its compiled route")
			return
	travelling = true
	_sync()
	await journey.walk(route,anchors[target])
	if not world_map.enter(target):
		push_error("Preview route changed during travel")
		travelling = false
		_sync()
		return
	world_map.clear_current()
	step_count += 1
	selected = -1
	travelling = false
	focus_journey(reduced_motion)
	_sync()

func focus_journey(immediate: bool = false) -> void:
	whole = false
	var points: PackedVector3Array = []
	if world_map.at >= 0:
		points.append(anchors[world_map.at])
	for i: int in world_map.reachable():
		points.append(anchors[i])
	rig.frame(points, size, false, immediate)
	if journey!=null:
		_sync()

func focus_all() -> void:
	whole = true
	var points: PackedVector3Array = anchors.duplicate()
	for edge: Dictionary in sample["edges"].values():
		for raw: Array in edge["centerline"]:
			points.append(terrain.present(Meshes.v3(raw)))
	rig.frame(points, size, true)
	_sync()

func _resize() -> void:
	if hint_label!=null:
		hint_label.text = "Drag to explore · scroll to zoom" if size.x<1000 else "A road through the ash · drag to explore · scroll to see further"
	stage.size = Vector2i(size)
	if whole:
		focus_all()
	else:
		focus_journey(true)

func _process(_delta: float) -> void:
	if rig == null:
		return
	for i: int in range(stones.size()):
		var pos: Vector2 = rig.unproject_position(journey.bases[i].position + Vector3(0,.48,.14))
		var pin: Pin = stones[i] as Pin
		if pin.overview!=whole:
			pin.overview = whole
			pin.queue_redraw()
		# The overview is an inspection surface; dense symbols are not tiny
		# encounter buttons with overlapping, misleading touch rectangles.
		pin.mouse_filter = Control.MOUSE_FILTER_IGNORE if whole else Control.MOUSE_FILTER_STOP
		pin.focus_mode = Control.FOCUS_NONE if whole else Control.FOCUS_ALL
		var extent: float = 48
		stones[i].size = Vector2.ONE * extent
		stones[i].position = pos - Vector2.ONE * extent * 0.5
		stones[i].add_theme_font_size_override("font_size", 12 if whole else 21)
		stones[i].visible = show_stones and pos.x >= extent * 0.5 and pos.x <= size.x - extent * 0.5 and pos.y > 60 + extent * 0.5 and pos.y < size.y - 72 - extent * 0.5

func _gui_input(event: InputEvent) -> void:
	if travelling:
		return
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			rig.zoom_by(0.88)
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rig.zoom_by(1.14)
		elif mouse.button_index == MOUSE_BUTTON_LEFT:
			dragging = mouse.pressed
			if dragging:
				drag_distance = 0
			elif whole and drag_distance<8:
				_inspect_area(mouse.position)
	elif event is InputEventMouseMotion and dragging:
		var mouse: InputEventMouseMotion = event
		drag_distance += mouse.relative.length()
		rig.pan_pixels(mouse.relative, size.y)
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		dragging = touch.pressed
		if dragging:
			drag_distance = 0
		elif whole and drag_distance<8:
			_inspect_area(touch.position)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		drag_distance += drag.relative.length()
		rig.pan_pixels(drag.relative, size.y)
	elif event is InputEventMagnifyGesture:
		var magnify: InputEventMagnifyGesture = event
		rig.zoom_by(1.0 / magnify.factor)

func _toggle_motion() -> void:
	if travelling:
		return
	reduced_motion = not reduced_motion
	_apply_motion()

func _apply_motion() -> void:
	journey.reduced_motion = reduced_motion
	rig.reduced_motion = reduced_motion
	var river: Node = terrain.get_node("Stream")
	river.animate = not reduced_motion
	motion_button.text = "Motion: off" if reduced_motion else "Motion: on"

func _inspect_area(point: Vector2) -> void:
	var nearest: int = -1
	var distance: float = INF
	for i: int in range(stones.size()):
		var candidate: float = point.distance_squared_to(stones[i].position+stones[i].size*.5)
		if candidate<distance:
			distance = candidate
			nearest = i
	if nearest<0:
		return
	whole = false
	var points: PackedVector3Array = [anchors[nearest]]
	for to_id: String in world_map.nodes[nearest].next:
		var raw: Array = sample["anchors"][to_id]
		points.append(terrain.present(Meshes.v3(raw)))
	rig.frame(points,size,false)
	_sync()
