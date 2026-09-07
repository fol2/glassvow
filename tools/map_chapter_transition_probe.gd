extends "res://tools/map_campaign_probe.gd"
## Isolated cleared-boss checkpoint -> native relic choice -> next chapter.
## The checkpoint is prepared; winning the preceding chapter is not claimed.
func _run() -> void:
	var prepare: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument=="--prepare": prepare=true
		elif argument.begins_with("--from-act="): act=argument.trim_prefix("--from-act=").to_int()
		elif argument.begins_with("--output="): output=argument.trim_prefix("--output=")
		else:
			_fail("Unknown transition probe argument: "+argument)
			return
	if act<0 or act>2:
		_fail("Transition requires a preceding chapter from 0 to 2")
		return
	if prepare:
		var content: ContentDB = ContentDB.load_full()
		var vigil: VigilState = VigilState.blank()
		for id: String in VigilState.QUEST_IDS:
			vigil.quests[id]["state"]="complete"
			vigil.shards.append(id)
		vigil.guidance_skipped=true
		var run: RunState = RunState.new_run(content,4,"map-delivery-probe",{
			"quests":vigil.quests.duplicate(true),"shards":vigil.shards.duplicate()})
		run.act=act
		var map: WorldMap = WorldMap.for_run(run,content)
		while not map.reachable().is_empty():
			map.enter(map.reachable()[0])
			map.clear_current()
			if map.current().type=="boss": break
		if map.current().type!="boss":
			_fail("Prepared route did not reach a boss")
			return
		run.map=map.to_dict()
		var stored: bool = SaveService.store(run,RUN) and SaveService.store_vigil(vigil,VIGIL)
		print("CHAPTER_TRANSITION_PREPARED ",stored)
		quit(0 if stored else 1)
		return
	if DisplayServer.get_name()=="headless":
		_fail("Chapter transition requires native rendering/input")
		return
	root.size=Vector2i(1458,820)
	root.content_scale_size=root.size
	DisplayServer.window_set_size(root.size)
	main=MainScene.instantiate() as Main
	main._run_save_path=RUN
	main._vigil_save_path=VIGIL
	root.add_child(main)
	var deadline: int = Time.get_ticks_msec()+20000
	while main._choice_screen==null or main._choice_screen.modulate.a<.999:
		if Time.get_ticks_msec()>deadline:
			_fail("Title entrance timed out")
			return
		await process_frame
	var continue_button: Button = main._choice_screen._first_button
	_click(continue_button.get_global_rect().get_center())
	for i: int in range(60): await process_frame
	var decline: Button
	if main._choice_screen!=null:
		for node: Node in main._choice_screen.find_children("*","Button",true,false):
			var candidate: Button = node
			if candidate.text==Locale.active.t("ui.reward.bossTakeNone"): decline=candidate
	if decline==null:
		_fail("Saved cleared boss did not restore the native relic choice")
		return
	var started: int = Time.get_ticks_msec()
	_click(decline.get_global_rect().get_center())
	var scenes: Array[String] = []
	deadline=Time.get_ticks_msec()+180000
	while main._map_screen==null:
		if Time.get_ticks_msec()>deadline:
			_fail("Chapter arrival timed out")
			return
		if main._route_screen is ScenePlayer:
			var player: ScenePlayer = main._route_screen
			if not scenes.has(player._script.id):
				scenes.append(player._script.id)
				if not output.is_empty():
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output.get_basename()+"-"+player._script.id+".png")
			# Tap the same native advance input used by the player; no instant mode.
			var key: InputEventKey = InputEventKey.new()
			key.keycode=KEY_SPACE
			key.pressed=true
			root.push_input(key,true)
			await process_frame
			key=key.duplicate() as InputEventKey
			key.pressed=false
			root.push_input(key,true)
		for i: int in range(12): await process_frame
	for i: int in range(150): await process_frame
	await RenderingServer.frame_post_draw
	var screen: WorldMapScreen = main._map_screen
	var disk: RunState = SaveService.load_run(main.content,RUN)
	var expected: Variant = JSON.parse_string(JSON.stringify(main.game.run.map))
	var receipt: Dictionary = {"from_act":act,"to_act":main.game.run.act,
		"elapsed_ms":Time.get_ticks_msec()-started,"scenes":scenes,
		"source_override":screen._layout_compile.is_valid(),
		"chapter_theme_matches":screen._act==main.game.run.act,
		"route_states_complete":screen._map_scene.set_waylight_states(screen._route_states()),
		"layout_digest":screen.layout_digest(),"input_digest":screen.layout_input_digest(),
		"saved_next_map":disk!=null and disk.act==act+1 and disk.map==expected,
		"scene_completed":main.game.run.pending_scene==null,
		"previous_surface_released":main._parked_map_screen==null,
		"first_entry_seen":main._vigil.scenes_seen.has("act4-entry") if act==2 else true,
		"checkpoint":"Prepared cleared boss; preceding combat wins not claimed"}
	if not output.is_empty(): root.get_texture().get_image().save_png(output)
	print("CHAPTER_TRANSITION ",JSON.stringify(receipt))
	var passed: bool = main.game.run.act==act+1 and not receipt["source_override"] and not screen.layout_digest().is_empty() and receipt["saved_next_map"] and receipt["scene_completed"] and receipt["previous_surface_released"] and receipt["first_entry_seen"] and receipt["chapter_theme_matches"] and receipt["route_states_complete"]
	main.queue_free()
	main=null
	for i: int in range(3): await process_frame
	quit(0 if passed else 1)
