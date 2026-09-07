extends SceneTree
## Native title -> Continue -> map -> encounter probe on an isolated v2 profile.
## Preparation creates a valid starting checkpoint; it never edits a real profile.
const MainScene: PackedScene = preload("res://application/main.tscn")
const RUN: String = "user://glassvow_map_delivery_probe_run.json"
const VIGIL: String = "user://glassvow_map_delivery_probe_vigil.json"
var main: Main
var output: String = ""
var travel: bool = false
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var prepare: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument=="--prepare": prepare=true
		elif argument=="--travel": travel=true
		elif argument.begins_with("--output="): output=argument.trim_prefix("--output=")
		else:
			push_error("Unknown campaign probe argument: "+argument)
			quit(2)
			return
	if prepare:
		var content: ContentDB = ContentDB.load_full()
		var run: RunState = RunState.new_run(content,4,"map-delivery-probe")
		run.map = WorldMap.for_run(run,content).to_dict()
		var vigil: VigilState = VigilState.blank()
		vigil.guidance_skipped = true
		var stored: bool = SaveService.store(run,RUN) and SaveService.store_vigil(vigil,VIGIL)
		print("CAMPAIGN_PROBE_PREPARED ",stored)
		quit(0 if stored else 1)
		return
	if DisplayServer.get_name()=="headless":
		push_error("Campaign input and rendered load timing require a native viewport")
		quit(2)
		return
	root.size=Vector2i(1458,820)
	root.content_scale_size=root.size
	DisplayServer.window_set_size(root.size)
	main=MainScene.instantiate() as Main
	main._run_save_path=RUN
	main._vigil_save_path=VIGIL
	root.add_child(main)
	var title_deadline: int = Time.get_ticks_msec()+15000
	while main._choice_screen==null or not main._choice_screen.is_visible_in_tree() or main._choice_screen.modulate.a<0.999:
		if Time.get_ticks_msec()>title_deadline:
			_fail("Title did not finish its visible entrance")
			return
		await process_frame
	await RenderingServer.frame_post_draw
	var title_ms: int = Time.get_ticks_msec()
	var preloaded: int = main._map_asset_preload.get("completed") if main._map_asset_preload!=null else 0
	var saved: RunState = SaveService.load_run(main.content,RUN)
	if saved==null or main._choice_screen==null:
		_fail("Prepared title checkpoint is unavailable")
		return
	var before: Dictionary = saved.to_dict()
	var button: Button = main._choice_screen.get("_first_button")
	if button==null or button.text!=Locale.active.t("ui.menu.backToRoad"):
		_fail("Title does not expose Continue as its first action")
		return
	var started: int = Time.get_ticks_usec()
	_click(button.get_global_rect().get_center())
	await process_frame
	await RenderingServer.frame_post_draw
	var restored_ms: float = (Time.get_ticks_usec()-started)/1000.0
	var screen: WorldMapScreen = main._map_screen
	if screen==null or screen.layout_result()==null:
		_fail("Continue did not construct the production map")
		return
	var same_run: bool = main.game.run.to_dict()==before
	var receipt: Dictionary = {"engine_elapsed_to_title_ms":title_ms,"preloaded_assets":preloaded,"cold_continue_to_render_ms":restored_ms,"run_unchanged":same_run,
		"input_digest":screen.layout_input_digest(),"layout_digest":screen.layout_digest(),
		"binding":screen.layout_diagnostics().get("binding_stages_ms",{}),"assembly":screen._map_scene.layout_diagnostics().get("assembly_ms",{}),
		"source_override":screen._layout_compile.is_valid(),"derived_cache":screen._map_scene.layout_diagnostics().get("derived_cache_hit",false)}
	if not same_run:
		_fail("Presentation changed the restored run")
		return
	for i: int in range(35): await process_frame
	if not output.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output)
	if travel:
		var reachable: Array[int] = screen.map.reachable()
		var index: int = reachable[0]
		var old_at: int = screen.map.at
		screen._journey_navigation.return_to_journey()
		var stone: GlassWaystone = screen._waystones[index]
		stone.grab_focus()
		var key: InputEventKey = InputEventKey.new()
		key.keycode=KEY_ENTER
		key.pressed=true
		root.push_input(key,true)
		key=key.duplicate() as InputEventKey
		key.pressed=false
		root.push_input(key,true)
		await process_frame
		receipt["inspection_preserved_at"]=screen.map.at==old_at
		if screen._journey_navigation.selected!=index or screen._journey_navigation._travel.disabled:
			_fail("Native inspection did not enable the legal journey")
			return
		_click(screen._journey_navigation._travel.get_global_rect().get_center())
		var deadline: int = Time.get_ticks_msec()+12000
		while main._screen==null and Time.get_ticks_msec()<deadline: await process_frame
		receipt["encounter_entered"]=main._screen!=null and main.game.cb!=null
		receipt["single_current_node"]=main._map.at==index
		receipt["parked_surface"]=main._parked_map_screen==screen
		receipt["parked_viewport_stopped"]=screen._map_scene.get_stage().render_target_update_mode==SubViewport.UPDATE_DISABLED
		if not receipt["encounter_entered"]:
			_fail("Confirmed journey did not reach the real combat screen")
			return
		for i: int in range(90): await process_frame
		if not output.is_empty():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.get_basename()+"-encounter.png")
	print("CAMPAIGN_PROBE ",JSON.stringify(receipt))
	quit(0)
func _click(point: Vector2) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=true
	press.position=point
	root.push_input(press,true)
	var release: InputEventMouseButton = press.duplicate() as InputEventMouseButton
	release.pressed=false
	root.push_input(release,true)
func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
