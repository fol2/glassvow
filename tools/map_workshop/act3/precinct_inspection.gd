extends "res://tools/map_workshop/act3/inspect.gd"
## Precinct-scale adaptation of the shared, read-only Step 3 inspector.
const Sightlines = preload("res://tools/map_workshop/common/precinct_sightlines.gd")
const Guidance = preload("res://tools/map_workshop/common/route_guidance.gd")
var guidance: Guidance
var walking: MeshInstance3D
func _ready() -> void:
	super._ready()
	for button: Button in markers.values():
		_style_target(button)
	guidance = Guidance.new()
	world.add_child(guidance)
	if not guidance.configure(data,walking,camera):
		get_tree().quit(1)

var sightlines: Sightlines = Sightlines.new()
var sightline_report: Dictionary = {}
const Travel = preload("res://tools/map_workshop/common/route_travel.gd")
var travel: Travel = Travel.new()
var travel_frames: int = 0
var travel_occlusions: int = 0
var travel_last_heading: float = 0
var travel_max_turn_speed: float = 0
var cluster_buttons: Array[Button] = []
var overview_groups: Array[Dictionary] = []
func _pose(at: Vector3,size_value: float,heading: float) -> void:
	super._pose(at,maxf(32.0,size_value),heading)
	camera.far = 600

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.pressed and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			camera.size = clampf(camera.size*(.9 if mouse.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),12,350)
			whole = camera.size>45
			return
	super._unhandled_input(event)

func _process(_delta: float) -> void:
	if guidance != null:
		guidance.show_state(selected,whole,markers_visible)
	if travel.active:
		var pose: Dictionary = travel.advance(_delta)
		if not pose.is_empty():
			var point: Vector3 = pose["point"]
			var heading: float = pose["heading"]
			var points: Array[Vector3] = [point]
			_frame(points,false,heading)
			var actual_heading: float = rad_to_deg(atan2(camera.global_basis.z.x,camera.global_basis.z.z))
			if _delta>0:
				travel_max_turn_speed = maxf(travel_max_turn_speed,absf(actual_heading-travel_last_heading)/_delta)
			travel_last_heading = actual_heading
			travel_frames += 1
			if sightlines.blocked(camera,point+Vector3.UP*.25):
				travel_occlusions += 1
			if pose["finished"]:
				detail.text = "  Road preview complete · Drag to explore"

	if not whole:
		super._process(_delta)
		for button: Button in cluster_buttons:
			button.visible = false
		return
	var dimensions: Vector2 = get_viewport().get_visible_rect().size
	var points: Array[Dictionary] = []
	for id: String in markers:
		var marker: Button = markers[id]
		var at: Vector3 = anchors[id]
		var screen: Vector2 = camera.unproject_position(at+Vector3.UP*.65)
		marker.position = screen-Vector2.ONE*marker_extent*.5
		if markers_visible and not camera.is_position_behind(at) and screen.x>marker_extent*.5+2 and screen.x<dimensions.x-marker_extent*.5-2 and screen.y>80+marker_extent*.5 and screen.y<dimensions.y-42-marker_extent*.5:
			points.append({"id":id,"at":screen})
	overview_groups = preload("res://tools/map_workshop/common/overview_groups.gd").build(points,marker_extent+4)
	var index: int = 0
	var singles: Dictionary = {}
	for group: Dictionary in overview_groups:
		var ids: Array = group["ids"]
		if ids.size() == 1:
			singles[str(ids[0])] = true
			continue
		if index == cluster_buttons.size():
			var button: Button = Button.new()
			button.size = Vector2.ONE*marker_extent
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = Color("272131")
			style.border_color = Color("9d789c")
			style.set_border_width_all(1)
			style.set_corner_radius_all(int(marker_extent*.5))
			button.add_theme_stylebox_override("normal",style)
			_style_target(button)
			canvas.add_child(button)
			button.pressed.connect(func() -> void: _open_group(button.get_meta("ids")))
			cluster_buttons.append(button)
		var button: Button = cluster_buttons[index]
		var centre: Vector2 = group["at"]
		button.position = centre-Vector2.ONE*marker_extent*.5
		button.text = str(ids.size())
		button.add_theme_color_override("font_color",Color("efbd79") if data["current"] in ids else Color("ded3e1"))
		button.tooltip_text = "%d waystones — zoom to inspect" % ids.size()
		button.set_meta("ids",ids)
		button.visible = true
		index += 1
	for id: String in markers:
		markers[id].visible = singles.has(id)
	for unused: int in range(index,cluster_buttons.size()):
		cluster_buttons[unused].visible = false

func _open_group(value: Variant) -> void:
	var ids: Array = value
	var points: Array[Vector3] = []
	for id: String in ids:
		points.append(anchors[id])
	whole = false
	_focus_points(points)
	detail.text = "  Choose a waystone to inspect · Drag to explore"

func focus_journey() -> void:
	whole = false
	if detail != null:
		detail.text = "  Select a next waystone to reveal its approach · Travel previews your choice"
	var points: Array[Vector3] = [anchors[data["current"]]]
	for id: String in data["reachable"]:
		points.append(anchors[id])
	_focus_points(points)

func _focus_points(points: Array[Vector3]) -> void:
	var best_heading: float = -25
	var best_blocked: int = 2147483647
	for heading: float in [-25.0,25.0,-55.0,55.0,0.0,-85.0,85.0]:
		_frame(points,false,heading)
		var count: int = 0
		for point: Vector3 in points:
			if sightlines.blocked(camera,point+Vector3.UP*.25):
				count += 1
		if count < best_blocked:
			best_blocked = count
			best_heading = heading
		if count == 0:
			break
	_frame(points,false,best_heading)
	sightline_report = {"heading_degrees":best_heading,"blocked_node_centres":best_blocked,
		"tested_node_centres":points.size(),"scope":"current and reachable centres at focus; not entire routes"}

func exercise_all_nodes() -> Dictionary:
	var previous_selection: String = selected
	var previous_detail: String = detail.text
	var failures: Array[Dictionary] = []
	for id: String in anchors:
		whole = false
		var points: Array[Vector3] = [anchors[id]]
		_focus_points(points)
		await get_tree().process_frame
		await get_tree().process_frame
		var marker: Button = markers[id]
		if not marker.visible or marker.size.x < marker_extent-.001 or marker.size.y < marker_extent-.001:
			failures.append({"node":id,"reason":"missing or undersized target"})
			continue
		await _click(marker.get_global_rect().get_center())
		if selected != id:
			failures.append({"node":id,"reason":"click selected another node","selected":selected})
		if sightline_report["blocked_node_centres"] != 0:
			failures.append({"node":id,"reason":"all bounded camera headings occluded"})
	focus_journey()
	selected = previous_selection
	detail.text = previous_detail
	return {"tested_nodes":anchors.size(),"failures":failures,"ok":failures.is_empty(),
		"scope":"each node focused and clicked; desktop pointer, not physical touch"}

## Diagnose centre-line travel before adding animation. Each sample is rendered;
## this does not claim uninterrupted collision-free motion between samples.
func exercise_routes() -> Dictionary:
	var failures: Array[Dictionary] = []
	var probes: int = 0
	var heading_changes: int = 0
	var maximum_turn: float = 0
	var only_edge: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--route-edge="):
			only_edge = argument.trim_prefix("--route-edge=")
	for id: String in data["edges"]:
		if not only_edge.is_empty() and id != only_edge:
			continue
		var plan: Dictionary = _plan_travel(id)
		if plan["ok"] != true:
			var failure: Dictionary = plan.get("last_failure",plan)
			if failure.has("position"):
				var point: Vector3 = _route_point(failure["position"])
				_heading_visible(point,MapLayoutCanonical.float_value(failure.get("heading",0.0)))
				var pixels: Array[Vector2] = [camera.unproject_position(point+Vector3.UP*.25)]
				plan["occluder_probe"] = preload("res://tools/map_workshop/common/mesh_screen_probe.gd").run(world,camera,pixels)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("/tmp/act3-route-plan-failure.png")
			failures.append({"edge":id,"plan":plan})
			continue
		var route_points: Array[Vector3] = plan["points"]
		var headings: Array[float] = plan["headings"]
		var last_heading: float = NAN
		for sample_index: int in range(route_points.size()):
				var point: Vector3 = route_points[sample_index]
				var clear: bool = _heading_visible(point,headings[sample_index])
				await get_tree().process_frame
				probes += 1
				var heading: float = rad_to_deg(atan2(camera.global_basis.z.x,camera.global_basis.z.z))
				if is_finite(last_heading) and not is_equal_approx(heading,last_heading):
					heading_changes += 1
					maximum_turn = maxf(maximum_turn,absf(heading-last_heading))
				if is_finite(last_heading) and absf(heading-last_heading)>90.0*point.distance_to(route_points[sample_index-1])+.001:
					failures.append({"edge":id,"reason":"actual camera turn exceeds distance bound"})
				last_heading = heading
				if not clear:
					failures.append({"edge":id,"position":[point.x,point.y,point.z],"heading":heading})
					if failures.size() == 1:
						await RenderingServer.frame_post_draw
						get_viewport().get_texture().get_image().save_png("/tmp/act3-route-camera-first-failure.png")
	focus_journey()
	return {"ok":failures.is_empty() and probes>0,"probes":probes,
		"edge_filter":only_edge,"occlusions":failures,"heading_changes":heading_changes,"maximum_turn_degrees":maximum_turn,
		"scope":"rendered centre-line focus samples at <=0.5 m; no interpolation or full-width guarantee"}

func _heading_visible(point: Vector3,heading: float) -> bool:
	var points: Array[Vector3] = [point]
	_frame(points,false,heading)
	return not sightlines.blocked(camera,point+Vector3.UP*.25)

func _route_point(raw: Variant) -> Vector3:
	var value: Array = raw
	return Vector3(MapLayoutCanonical.float_value(value[0]),MapLayoutCanonical.float_value(value[1]),MapLayoutCanonical.float_value(value[2]))

func measure_overview() -> Dictionary:
	var previous_selection: String = selected
	var previous_detail: String = detail.text
	focus_whole()
	await get_tree().process_frame
	await get_tree().process_frame
	var overlaps: Array[Array] = []
	var targets: Array[Button] = []
	for marker: Button in markers.values():
		if marker.visible:
			targets.append(marker)
	for button: Button in cluster_buttons:
		if button.visible:
			targets.append(button)
	var represented: int = 0
	for group: Dictionary in overview_groups:
		represented += group["ids"].size()
	var target_sizes_pass: bool = true
	for button: Button in targets:
		target_sizes_pass = target_sizes_pass and minf(button.size.x,button.size.y)>=marker_extent-.001
	for i: int in range(targets.size()):
		for j: int in range(i+1,targets.size()):
			if targets[i].get_global_rect().intersects(targets[j].get_global_rect()):
				overlaps.append([i,j])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/act3-overview-input.png")
	var cluster_open: bool = true
	var cluster_transition: Dictionary = {}
	for button: Button in cluster_buttons:
		if button.visible:
			var old_size: float = camera.size
			await _click(button.get_global_rect().get_center())
			cluster_open = not whole and camera.size < old_size
			cluster_transition = {"before":old_size,"after":camera.size,"whole":whole}
			break
	focus_whole()
	await get_tree().process_frame
	await get_tree().process_frame
	var single_select: bool = true
	for id: String in markers:
		var marker: Button = markers[id]
		if marker.visible:
			await _click(marker.get_global_rect().get_center())
			single_select = selected == id
			break
	focus_journey()
	selected = previous_selection
	detail.text = previous_detail
	return {"target_sizes_pass":target_sizes_pass,"nodes":markers.size(),"represented":represented,"targets":targets.size(),"overlaps":overlaps,"cluster_open":cluster_open,"cluster_transition":cluster_transition,"single_select":single_select}

func _drag_probe_origin(dimensions: Vector2) -> Vector2:
	var buttons: Array = markers.values()+controls.values()+cluster_buttons
	for y: float in [.5,.35,.7]:
		for x: float in [12.0,dimensions.x-12]:
			var at: Vector2 = Vector2(x,dimensions.y*y)
			var occupied: bool = false
			for button: Button in buttons:
				if button.visible and button.get_global_rect().has_point(at):
					occupied = true
					break
			if not occupied:
				return at
	return super._drag_probe_origin(dimensions)

func _plan_travel(id: String) -> Dictionary:
	var line: Array = data["edges"][id]["centerline"]
	var route_points: Array[Vector3] = []
	for index: int in range(line.size()-1):
		var a: Vector3 = _route_point(line[index])
		var b: Vector3 = _route_point(line[index+1])
		var steps: int = maxi(1,ceili(a.distance_to(b)/.5))
		for step: int in range(steps+1):
			var point: Vector3 = a.lerp(b,float(step)/steps)
			route_points.append(point)
	var plan: Dictionary = preload("res://tools/map_workshop/common/route_camera_heading.gd").choose(route_points,[-25.0,25.0,-55.0,55.0,0.0,-85.0,85.0],_heading_visible)
	var headings: Array[float] = []
	if plan["ok"] == true:
		var constant_headings: Array[float] = [MapLayoutCanonical.float_value(plan["heading"])]
		plan = preload("res://tools/map_workshop/common/route_camera_heading.gd").visible_path(route_points,constant_headings,_heading_visible)
	if plan["ok"] == true:
		headings = plan["headings"]
	else:
		var candidates: Array[float] = []
		for angle: int in range(-85,86):
			candidates.append(float(angle))
		plan = preload("res://tools/map_workshop/common/route_camera_heading.gd").visible_path(route_points,candidates,_heading_visible)
		if plan["ok"] != true:
			return plan
		var planned_headings: Array = plan["headings"]
		headings.assign(planned_headings)
	return {"ok":true,"points":route_points,"headings":headings}

func _action(action: String) -> void:
	travel.cancel()
	if action != "Travel":
		super._action(action)
		return
	var chosen_edge: String = Guidance.selection(data,selected)
	var origin: String = str(data["current"]) if not chosen_edge.is_empty() else (selected if not selected.is_empty() else str(data["current"]))
	var edges: Dictionary = data["edges"]
	for id: String in MapLayoutCanonical.sorted_keys(edges):
		var edge: Dictionary = data["edges"][id]
		if str(edge["from"]) != origin or (not chosen_edge.is_empty() and id != chosen_edge):
			continue
		var plan: Dictionary = _plan_travel(id)
		if plan["ok"] != true:
			if plan.has("last_failure"):
				var failure: Dictionary = plan["last_failure"]
				var point: Vector3 = _route_point(failure["position"])
				_heading_visible(point,MapLayoutCanonical.float_value(failure["heading"]))
				var pixels: Array[Vector2] = [camera.unproject_position(point+Vector3.UP*.25)]
				plan["occluder_probe"] = preload("res://tools/map_workshop/common/mesh_screen_probe.gd").run(world,camera,pixels)
			print("TRAVEL_PLAN_FAILURE ",JSON.stringify({"edge":id,"plan":plan}))
			detail.text = "  This road needs a clearer camera view"
			return
		var points: Array[Vector3] = plan["points"]
		var headings: Array[float] = plan["headings"]
		travel_frames = 0
		travel_occlusions = 0
		travel_last_heading = headings[0]
		travel_max_turn_speed = 0
		var start_points: Array[Vector3] = [points[0]]
		_frame(start_points,false,headings[0])
		travel.begin(points,headings)
		detail.text = "  Road preview · Drag, scroll or press Escape to stop"
		return
	detail.text = "  No onward road from this waystone"

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		travel.cancel()
	if event is InputEventKey:
		var key: InputEventKey = event
		if key.pressed and key.keycode == KEY_ESCAPE:
			travel.cancel()
	super._input(event)

func exercise_tour() -> Dictionary:
	var before: String = str(data["current"])
	var node: String = ""
	var visited: Array[String] = []
	var route_ids: Array[String] = []
	var points: Array[Vector3] = []
	var headings: Array[float] = []
	var tour_edges: Dictionary = data["edges"]
	var incoming: Dictionary = {}
	for edge: Dictionary in tour_edges.values():
		incoming[str(edge["to"])] = true
	for id: String in MapLayoutCanonical.sorted_keys(anchors):
		if not incoming.has(id):
			node = id
			break
	if node.is_empty():
		return {"ok":false,"reason":"tour has no generated entrance"}
	var entrance: String = node
	while node != "14,3":
		if node in visited:
			return {"ok":false,"reason":"tour encountered a cycle"}
		visited.append(node)
		var onward: String = ""
		for id: String in MapLayoutCanonical.sorted_keys(tour_edges):
			if str(data["edges"][id]["from"]) == node:
				onward = id
				break
		if onward.is_empty():
			return {"ok":false,"reason":"tour ended before sovereign court","node":node}
		var plan: Dictionary = _plan_travel(onward)
		if plan.get("ok") != true:
			return {"ok":false,"reason":"tour camera plan failed","edge":onward,"plan":plan}
		var leg_points: Array = plan["points"]
		var leg_headings: Array = plan["headings"]
		points.append_array(leg_points)
		headings.append_array(leg_headings)
		route_ids.append(onward)
		node = str(data["edges"][onward]["to"])
	travel_frames = 0
	travel_occlusions = 0
	travel_max_turn_speed = 0
	travel_last_heading = headings[0]
	var first: Array[Vector3] = [points[0]]
	_frame(first,false,headings[0])
	var started: bool = travel.begin(points,headings)
	detail.text = "  The Obsidian Court · Entrance to sovereign forecourt"
	var deadline: int = Time.get_ticks_msec()+180000
	while travel.active and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	var complete: bool = started and not travel.active and travel_frames>2
	travel.cancel()
	return {"ok":complete and travel_occlusions==0 and travel_max_turn_speed<=40.02 and before==str(data["current"]),
		"completed":complete,"entrance":entrance,"edges":route_ids,"destination":node,"frames":travel_frames,
		"occlusions":travel_occlusions,"maximum_turn_degrees_per_second":travel_max_turn_speed,
		"current_unchanged":before==str(data["current"]),
		"scope":"one continuous generated entrance-to-boss route; all rendered frames; other branches excluded"}

func exercise_travel() -> Dictionary:
	var before: String = str(data["current"])
	var button: Button = controls["Travel"]
	await _click(button.get_global_rect().get_center())
	var started: bool = travel.active
	var captured: bool = false
	var deadline: int = Time.get_ticks_msec()+30000
	while travel.active and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if not captured and travel.segment>=travel.points.size()/2:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/act3-travel-midpoint.png")
			captured = true
	var frames: int = travel_frames
	var occlusions: int = travel_occlusions
	var turn_speed: float = travel_max_turn_speed
	var completed: bool = started and not travel.active and frames>2
	travel.cancel()
	await _click(button.get_global_rect().get_center())
	await get_tree().create_timer(.15).timeout
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	var cancelled: bool = not travel.active
	key.pressed = false
	Input.parse_input_event(key)
	return {"ok":completed and cancelled and occlusions==0 and turn_speed<=40.02 and before==str(data["current"]),
		"completed":completed,"cancelled":cancelled,"frames":frames,"occlusions":occlusions,"maximum_turn_degrees_per_second":turn_speed,
		"current_unchanged":before==str(data["current"]),"scope":"actual Travel button, current first outgoing road, rendered interpolation and Escape"}

func exercise_guidance() -> Dictionary:
	var before: String = JSON.stringify(data)
	var failures: Array[String] = []
	var choices: Array = data["reachable"]
	selected = ""
	focus_journey()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/act3-guidance-arrival.png")
	for index: int in range(choices.size()):
		var id: String = str(choices[index])
		focus_journey()
		await get_tree().process_frame
		var choice_button: Button = markers[id]
		await _click(choice_button.get_global_rect().get_center())
		await get_tree().process_frame
		var edge: String = Guidance.selection(data,id)
		if selected != id or guidance.selected_edge != edge or edge.is_empty():
			failures.append("Selection did not reveal the actual available edge: "+id)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/act3-guidance-choice-"+str(index)+".png")
		var travel_button: Button = controls["Travel"]
		await _click(travel_button.get_global_rect().get_center())
		await get_tree().process_frame
		var source_at: Vector3 = anchors[data["current"]]
		var target_at: Vector3 = anchors[id]
		if not travel.active or travel.points.is_empty() or travel.points[0].distance_to(source_at)>.01 or travel.points[-1].distance_to(target_at)>.01:
			failures.append("Travel did not follow selected current-to-destination edge: "+id)
		travel.cancel()
	focus_whole()
	await get_tree().process_frame
	await get_tree().process_frame
	if not guidance.overview.visible or guidance.paths.size()!=data["edges"].size():
		failures.append("Overview did not expose the complete graph")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/act3-guidance-overview.png")
	focus_journey()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var current_button: Button = markers[data["current"]]
	await _click(current_button.get_global_rect().get_center())
	await get_tree().process_frame
	if not guidance.selected_edge.is_empty(): failures.append("Current node incorrectly previews an outgoing choice")
	if JSON.stringify(data)!=before: failures.append("Read-only guidance mutated game data")
	return {"ok":failures.is_empty(),"failures":failures,"choices_clicked":choices.size(),"edges":guidance.paths.size(),"surface_samples":guidance.sampled_points,"source_unchanged":JSON.stringify(data)==before}

func _style_target(button: Button) -> void:
	var normal: StyleBoxFlat = button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(.12)
	for state: String in ["hover","pressed","hover_pressed"]:
		button.add_theme_stylebox_override(state,hover)
	var focus: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	focus.draw_center = false
	focus.border_color = Color("e4c6e7")
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus",focus)
func _select(id: String,type: String) -> void:
	super._select(id,type)
	if guidance != null: guidance.show_state(id,whole,markers_visible)

func focus_whole() -> void:
	super.focus_whole()
	if detail != null:
		detail.text = "  Gold: travelled · Lilac: available next · Grey: later · Select a group to zoom"
