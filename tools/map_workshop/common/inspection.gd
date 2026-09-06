extends CanvasLayer
## Read-only chapter inspection. Snapshot states come from the compiled sample.
const M = preload("res://tools/map_workshop/mesh_tools.gd")
const SYMBOLS: Dictionary = {"monster":"×","elite":"!","event":"?","rest":"⌂","shop":"¤","treasure":"◇","boss":"♜","monument":"†"}
var chapter_heading: String = "  II  /  THE SUNKEN CITY"
var landmark_label: String = "Library"
var camera: Camera3D
var world: Node3D
var data: Dictionary
var anchors: Dictionary
var ruin_centres: Array[Vector3] = []
var ruin_owners: Dictionary = {}
var library_at: Vector3
var markers: Dictionary = {}
var controls: Dictionary = {}
var canvas: Control
var detail: Label
var drag: bool = false
var markers_visible: bool = true
var selected: String = ""
var focus_at: Vector3 = Vector3.ZERO
var whole: bool = false

func _ready() -> void:
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	var header: PanelContainer = PanelContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = 76
	canvas.add_child(header)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	header.add_child(row)
	var title: Label = Label.new()
	title.text = chapter_heading+"\n  Native asset study · Step 3"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	for name_value: String in ["Library","Journey","Whole act","Markers"]:
		var button: Button = Button.new()
		button.text = landmark_label if name_value=="Library" else name_value
		button.custom_minimum_size = Vector2(80,48)
		row.add_child(button)
		controls[name_value] = button
		button.pressed.connect(func() -> void: _action(name_value))
	detail = Label.new()
	detail.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	detail.offset_top = -40
	detail.text = "  Drag to explore · Scroll to zoom · Select a waystone to inspect"
	canvas.add_child(detail)
	for node: Dictionary in data["nodes"]:
		var id: String = node["id"]
		var type: String = node["type"]
		var tint: Color = Color("778b9e")
		if id in data["history"]:
			tint = Color("aa9b7b")
		if id in data["reachable"]:
			tint = Color("91d4bb")
		if id == data["current"]:
			tint = Color("efbd79")
		var at: Vector3 = anchors[id]
		M.box(world,at+Vector3(0,.22,0),Vector3(.34,.44,.34),M.material(Color("344551")),"Waystone_"+id)
		var light: StandardMaterial3D = M.material(tint)
		light.emission_enabled = true
		light.emission = tint
		light.emission_energy_multiplier = .3
		M.box(world,at+Vector3(0,.45,0),Vector3(.27,.07,.27),light,"WaystoneGlass_"+id)
		var marker: Button = Button.new()
		marker.text = SYMBOLS.get(type,"·")
		marker.tooltip_text = type.capitalize()+" · "+id
		marker.size = Vector2(44,44)
		marker.add_theme_color_override("font_color",tint)
		marker.add_theme_font_size_override("font_size",23)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(.04,.075,.10,.94)
		style.set_corner_radius_all(22)
		style.set_border_width_all(1)
		style.border_color = tint.darkened(.35)
		marker.add_theme_stylebox_override("normal",style)
		canvas.add_child(marker)
		markers[id] = marker
		marker.pressed.connect(func() -> void: _select(id,type))

func _select(id: String,type: String) -> void:
	selected = id
	var state: String = "Unvisited"
	if id in data["history"]:
		state = "Visited"
	if id in data["reachable"]:
		state = "Available next"
	if id == data["current"]:
		state = "Current location"
	detail.text = "  "+type.capitalize()+" · "+state+" · "+id+"   |   "+str(ruin_owners.get(id,"Inspection only"))

func _action(action: String) -> void:
	if action == "Markers":
		markers_visible = not markers_visible
	elif action == "Library":
		focus_library()
	elif action == "Journey":
		focus_journey()
	else:
		focus_whole()

func focus_library() -> void:
	whole = false
	var points: Array[Vector3] = []
	for x: float in [-7,7]:
		for z: float in [-6,8]:
			for y: float in [0,8]:
				points.append(library_at+Vector3(x,y,z))
	_frame(points,false,25)

func focus_journey() -> void:
	whole = false
	var points: Array[Vector3] = [anchors[data["current"]]]
	for id: String in data["reachable"]:
		points.append(anchors[id])
	_frame(points,false)

func focus_whole() -> void:
	whole = true
	var points: Array[Vector3] = []
	for p: Vector3 in anchors.values():
		points.append(p)
	for centre: Vector3 in ruin_centres:
		points.append(centre+Vector3(-9,8,-9))
		points.append(centre+Vector3(9,8,9))
	points.append(library_at+Vector3(-7,8,-6))
	points.append(library_at+Vector3(7,8,-6))
	_frame(points,true)

func _frame(points: Array[Vector3],overview: bool,heading: float = 0) -> void:
	var right: Vector2 = Vector2(cos(deg_to_rad(heading)),-sin(deg_to_rad(heading)))
	var forward: Vector2 = Vector2(sin(deg_to_rad(heading)),cos(deg_to_rad(heading)))
	var low: Vector2 = Vector2.INF
	var high: Vector2 = -Vector2.INF
	var sine: float = sin(deg_to_rad(55))
	var cosine: float = cos(deg_to_rad(55))
	for p: Vector3 in points:
		var horizontal: Vector2 = Vector2(p.x,p.z)
		var q: Vector2 = Vector2(horizontal.dot(right),horizontal.dot(forward)*sine-p.y*cosine)
		low = low.min(q)
		high = high.max(q)
	var dimensions: Vector2 = get_viewport().get_visible_rect().size
	var extent: Vector2 = high-low+Vector2(8,9)
	var size_value: float = maxf(extent.x*dimensions.y/(dimensions.x-80),extent.y*dimensions.y/(dimensions.y-150))
	var centre: Vector2 = (low+high)*.5
	var horizontal: Vector2 = right*centre.x+forward*centre.y/sine
	_pose(Vector3(horizontal.x,0,horizontal.y),maxf(16,size_value),heading)
	whole = overview

func _pose(at: Vector3,size_value: float,heading: float) -> void:
	focus_at = at
	camera.size = size_value
	var direction: Vector3 = Vector3(sin(deg_to_rad(heading)),0,cos(deg_to_rad(heading)))
	camera.position = at+Vector3.UP*36+direction*36/tan(deg_to_rad(55))
	camera.far = 180
	camera.look_at(at)

func _process(_delta: float) -> void:
	var dimensions: Vector2 = get_viewport().get_visible_rect().size
	for id: String in markers:
		var marker: Button = markers[id]
		var at: Vector3 = anchors[id]
		var screen: Vector2 = camera.unproject_position(at+Vector3.UP*.65)
		marker.position = screen-Vector2(22,22)
		marker.visible = markers_visible and (not whole or ruin_owners.has(id)) and not camera.is_position_behind(at) and screen.x>24 and screen.x<dimensions.x-24 and screen.y>102 and screen.y<dimensions.y-64

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			drag = mouse.pressed
		elif mouse.pressed and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			camera.size = clampf(camera.size*(.9 if mouse.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),12,90)
			whole = camera.size>45
	elif event is InputEventMouseMotion and drag:
		var motion: InputEventMouseMotion = event
		var dimensions: Vector2 = get_viewport().get_visible_rect().size
		var right: Vector3 = camera.global_basis.x
		var forward: Vector3 = Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()
		var movement: Vector3 = -(right*motion.relative.x+forward*motion.relative.y/sin(deg_to_rad(55)))*camera.size/dimensions.y
		camera.position += movement
		focus_at += movement

func exercise() -> Dictionary:
	var dimensions: Vector2 = get_viewport().get_visible_rect().size
	var actual_pixels: bool = get_viewport().get_texture().get_size()==dimensions
	var whole_button: Button = controls["Whole act"]
	await _click(whole_button.get_global_rect().get_center())
	var whole_pass: bool = whole
	var journey_button: Button = controls["Journey"]
	await _click(journey_button.get_global_rect().get_center())
	var journey_pass: bool = not whole
	var current_id: String = data["current"]
	var marker: Button = markers[current_id]
	var current_visible: bool = marker.visible
	await _click(marker.get_global_rect().get_center())
	var selection_pass: bool = selected==current_id and detail.text.contains("Current location")
	var camera_before: Vector3 = camera.position
	var origin: Vector2 = Vector2(12,dimensions.y*.5)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = origin
	Input.parse_input_event(down)
	await get_tree().process_frame
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = origin+Vector2(30,10)
	motion.relative = Vector2(30,10)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	await get_tree().process_frame
	var up: InputEventMouseButton = down.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
	var pan_pass: bool = camera.position.distance_to(camera_before)>.1
	var previous_size: float = camera.size
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = origin
	Input.parse_input_event(wheel)
	await get_tree().process_frame
	var zoom_pass: bool = camera.size<previous_size
	await _click(journey_button.get_global_rect().get_center())
	return {"dimensions":[dimensions.x,dimensions.y],"viewport_matches_pixels":actual_pixels,
		"whole_button":whole_pass,"journey_button":journey_pass,"current_visible":current_visible,
		"select_current":selection_pass,"drag_pan":pan_pass,"wheel_zoom":zoom_pass,
		"marker_target":[marker.size.x,marker.size.y],"source_current_unchanged":data["current"]==current_id}

func _click(at: Vector2) -> void:
	# Move the pointer before pressing, and finish a rendered frame before
	# inspecting controls whose visibility depends on the new camera state.
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await get_tree().process_frame
	for pressed: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
