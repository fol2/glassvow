extends SceneTree
## Headed map workshop using the verified seed-717 compiler geometry.
const Locator = preload("res://tools/map_workshop/asset_locator.gd")
const Gallery = preload("res://tools/map_workshop/gallery.gd")
const View = preload("res://tools/map_workshop/view.gd")
const TerrainRiver = preload("res://tools/map_workshop/river.gd")
var view: View
var output: String = ""
var grey: bool = true
var dimensions: Vector2i = Vector2i(1458, 820)
var site: bool = false
var survey: bool = false
var exercise: bool = false
var steps: int = 4
var gallery: bool = false
var rotation: float = 0.0
var trial: String = ""
var turntable: bool = false
var frames_directory: String = ""
var detail: String = ""
var locate: String = ""
var located: Dictionary = {}
var water_loop: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg.begins_with("--steps="):
			steps = clampi(int(arg.trim_prefix("--steps=")), 0, 14)
		elif arg in ["--variety","--new-variety"]:
			gallery = true
		elif arg == "--gallery":
			gallery = true
		elif arg == "--turntable":
			turntable = true
		elif arg == "--water-loop":
			water_loop = true
		elif arg.begins_with("--frames="):
			frames_directory = arg.trim_prefix("--frames=")
		elif arg.begins_with("--rotation="):
			rotation = float(arg.trim_prefix("--rotation="))
		elif arg.begins_with("--trial="):
			trial = arg.trim_prefix("--trial=")
		elif arg == "--assets":
			grey = false
		elif arg == "--phone":
			dimensions = Vector2i(844, 390)
		elif arg == "--pad":
			dimensions = Vector2i(1180, 820)
		elif arg.begins_with("--locate="):
			locate = arg.trim_prefix("--locate=")
		elif arg.begins_with("--detail="):
			detail = arg.trim_prefix("--detail=")
		elif arg == "--site":
			site = true
		elif arg == "--survey":
			survey = true
		elif arg == "--exercise":
			exercise = true
		else:
			push_error("Unknown workshop argument: " + arg)
			quit(2)
			return
	if DisplayServer.get_name() == "headless":
		push_error("Workshop needs a headed renderer")
		quit(2)
		return
	DisplayServer.window_set_size(dimensions)
	root.size = dimensions
	root.content_scale_size = dimensions
	if gallery:
		await _gallery()
		return
	Locale.active = Locale.new(&"en")
	var content: ContentDB = ContentDB.load_full()
	Locale.active.hydrate_content(content)
	var run: RunState = RunState.new_run(content, 717)
	var world: WorldMap = WorldMap.for_run(run, content)
	var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/studies/camera-composition/act1-seed717.json"))
	var bound: Dictionary = MapLayoutInputBinding.bind(world, 0)
	if sample["nodes"].size() != world.nodes.size() or sample["edges"].size() != bound["edges"].size():
		push_error("Workshop sample no longer covers the generated graph")
		quit(1)
		return
	for node: MapNode in world.nodes:
		if not sample["anchors"].has(node.id):
			push_error("Missing generated node: " + node.id)
			quit(1)
			return
	for edge: Dictionary in bound["edges"]:
		var id: String = str(edge["id"])
		var actual: Dictionary = sample["edges"].get(id, {})
		if actual.get("from", "") != edge["from"] or actual.get("to", "") != edge["to"] or actual.get("centerline", []).size() < 2:
			push_error("Missing or mismatched generated edge: " + id)
			quit(1)
			return
	for step: int in range(steps):
		var reachable: Array[int] = world.reachable()
		world.enter(reachable[0])
		world.clear_current()
	view = View.new()
	view.hero_override = trial
	view.setup(sample, world, grey)
	root.add_child(view)
	for frame: int in range(16):
		await process_frame
	if view.terrain.bridge_spans == 0 or view.kit == null or not view.kit.build_complete or not view.kit.failure.is_empty():
		push_error("Workshop asset build did not complete successfully")
		quit(1)
		return
	if not locate.is_empty():
		var hero: Vector3 = view.kit.placed[0]["position"]
		var nearest: float = INF
		for item: Dictionary in view.kit.placed:
			var position: Vector3 = item["position"]
			if str(item["kind"]) == locate and position.distance_to(hero)<nearest:
				nearest = position.distance_to(hero)
				located = item
		if located.is_empty():
			push_error("Requested model is not placed: "+locate)
			quit(1)
			return
		var at: Vector3 = located["position"]
		var height: float = float(str(located["height"]))
		var centre: Vector3 = Vector3(clampf(at.x,-35,35),at.y,clampf(at.z,-18,18))
		view.rig.frame(PackedVector3Array([centre+Vector3(-4,0,4),centre+Vector3(4,height,-4)]),view.size,true,true)
	elif not detail.is_empty():
		var locations: Dictionary = {"bridge":Vector3(-5,0,15), "cross":Vector3(-21,0,19),
			"bend":Vector3(-25,0,14), "overpass":Vector3(7,0,3), "switchback":Vector3(32,0,11),
			"trail":Vector3(-27,0,14), "landing":Vector3(-6,0,18), "ramp":Vector3(8,0,3), "clearance":Vector3(8.227,0,2.995), "river-section":Vector3(-4,0,18), "water":Vector3(-3,0,16)}
		var at: Vector3 = locations.get(detail,Vector3(-21,0,19))
		at.y = view.terrain.landform.upland(at.x,at.z)
		if detail in ["clearance","river-section"]:
			view.rig.pitch = 25
			view.rig.heading = -58 if detail=="clearance" else -18
			at.y -= 1.3
			view.show_stones = false
			if detail=="clearance":
				var figure: Vector3 = Vector3(7.15,0,3.67)
				figure.y = view.terrain.surface_height(figure.x,figure.z)
				preload("res://tools/map_workshop/scale_reference.gd").place(view.world,figure,-.6)
				var upper: Vector3 = Vector3(9.0,0,3.5)
				upper = view.terrain.present(upper+Vector3.UP*.384)
				preload("res://tools/map_workshop/scale_reference.gd").place(view.world,upper,.6)
		view.rig.frame(PackedVector3Array([at+Vector3(-5,0,4),at+Vector3(5,3,-4)]),view.size,true,true)
		if detail in ["trail","landing","ramp","clearance","river-section"]:
			view.rig.goal_size = 10
			view.rig.size = 10
		if detail=="water":
			# A closer inspection camera, distinct from the playable zoom limit.
			view.rig.pitch = 62
			view.show_stones = false
			at.y = TerrainRiver.LEVEL
			view.rig.frame(PackedVector3Array([at+Vector3(-3,0,2.5),at+Vector3(3,0,-2.5)]),view.size,true,true)
			view.rig.goal_size = 6
			view.rig.size = 6
	elif survey:
		view.focus_all()
	elif site:
		for placement: Dictionary in view.kit.placed:
			if str(placement["kind"]) == "amber-arch":
				var at: Vector3 = placement["position"]
				view.rig.frame(PackedVector3Array([at + Vector3(-7, 0, 6), at + Vector3(7, 6, -7)]), view.size, true, true)
				break
	for frame: int in range(48):
		await process_frame
	print("WORKSHOP_READY ", JSON.stringify({"nodes": world.nodes.size(), "edges": sample["edges"].size(), "segments": view.terrain.road_segments, "bridge_spans": view.terrain.bridge_spans, "placements": view.kit.placed.size(), "greybox": grey, "size": [dimensions.x, dimensions.y]}))
	if exercise:
		if not await _exercise():
			quit(1)
			return
		for frame: int in range(60):
			await process_frame
	if water_loop:
		if frames_directory.is_empty():
			push_error("River motion capture requires a frame directory")
			quit(2)
			return
		var recorded: bool = await preload("res://tools/map_workshop/river_capture.gd").record(view,self,frames_directory)
		view.queue_free()
		for frame: int in range(8):
			await process_frame
		quit(0 if recorded else 1)
		return
	if output.is_empty():
		return
	var river: TerrainRiver = view.terrain.get_node("Stream") as TerrainRiver
	river.animate = false
	river.set_time(2.0)
	await process_frame
	if not located.is_empty():
		var marker: Locator = Locator.new()
		var at: Vector3 = located["position"]
		marker.point = view.rig.unproject_position(at)
		marker.caption = str({"conifer-wind":"Wind-bent pine", "conifer-snag":"Forked woodland snag", "slate-shard":"Split slate blade", "slate-scree":"Part-buried scree", "ash-fern":"Woodland fern", "ash-bramble":"Trailing thorn bramble"}.get(locate,locate))
		view.add_child(marker)
		print("WORKSHOP_LOCATED ",JSON.stringify(located))
		await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(output)
	print("WORKSHOP_CAPTURE ", error_string(error))
	view.queue_free()
	for frame: int in range(8):
		await process_frame
	quit(0 if error == OK else 1)

func _exercise() -> bool:
	var before: Vector2 = view.rig.centre
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(200, 180)
	root.push_input(press)
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = Vector2(260, 180)
	move.relative = Vector2(60, 0)
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(move)
	var release: InputEventMouseButton = press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.position = move.position
	root.push_input(release)
	await process_frame
	var pan_pass: bool = view.rig.centre.distance_to(before) > 0.1
	var old_zoom: float = view.rig.goal_size
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.position = Vector2(200, 180)
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	root.push_input(wheel)
	var wheel_release: InputEventMouseButton = wheel.duplicate() as InputEventMouseButton
	wheel_release.pressed = false
	root.push_input(wheel_release)
	await process_frame
	var zoom_pass: bool = view.rig.goal_size > old_zoom
	view.focus_journey(true)
	view.drag_distance = 0
	for frame: int in range(3):
		await process_frame
	var next: Array[int] = view.world_map.reachable()
	var expected: int = next[0]
	await _click(view.stones[expected].get_global_rect().get_center())
	await process_frame
	var select_pass: bool = view.selected == expected
	await _click(view.travel.get_global_rect().get_center())
	await process_frame
	var travel_pass: bool = view.world_map.at == expected and view.step_count == 1
	print("WORKSHOP_EXERCISE ", JSON.stringify({"pan": pan_pass, "wheel_zoom": zoom_pass,
		"native_selection": select_pass, "legal_preview_travel": travel_pass}))
	return pan_pass and zoom_pass and select_pass and travel_pass

func _click(at: Vector2) -> void:
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	root.push_input(move, true)
	await process_frame
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.position = at
	press.global_position = at
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release: InputEventMouseButton = press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)

func _gallery() -> void:
	var sheet: Gallery = Gallery.new()
	sheet.hero_override = trial
	root.add_child(sheet)
	for frame: int in range(20):
		await process_frame
	if not sheet.failure.is_empty():
		quit(1)
		return
	sheet.rotate_models(rotation)
	for frame: int in range(20):
		await process_frame
	print("WORKSHOP_GALLERY ", sheet.models.size(), " models; rotation=", rotation)
	if turntable:
		if not frames_directory.is_empty():
			DirAccess.make_dir_recursive_absolute(frames_directory)
		for frame: int in range(240):
			sheet.rotate_models(TAU / 240)
			await process_frame
			if not frames_directory.is_empty():
				await RenderingServer.frame_post_draw
				var saved: Error = root.get_texture().get_image().save_png(frames_directory.path_join("%04d.png" % frame))
				if saved != OK:
					push_error("Cannot save native turntable frame")
					quit(1)
					return
		print("WORKSHOP_TURNTABLE 240 frames; full rotation")
		quit(0)
		return
	if output.is_empty():
		return
	if not located.is_empty():
		var marker: Locator = Locator.new()
		var at: Vector3 = located["position"]
		marker.point = view.rig.unproject_position(at)
		marker.caption = str({"conifer-wind":"Wind-bent pine", "conifer-snag":"Forked woodland snag", "slate-shard":"Split slate blade", "slate-scree":"Part-buried scree", "ash-fern":"Woodland fern", "ash-bramble":"Trailing thorn bramble"}.get(locate,locate))
		view.add_child(marker)
		print("WORKSHOP_LOCATED ",JSON.stringify(located))
		await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(output)
	print("WORKSHOP_CAPTURE ", error_string(error))
	quit(0 if error == OK else 1)
