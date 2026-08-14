extends RefCounted
## #217: six Shards start an ordinary pilgrimage; the sealed door is an overlay
## on the generated final-act map, not a one-node Act IV graph.

const SAVE_PATH: String = "user://test_sealed_door_run_v2.json"


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_sealed_door: %s" % what)


static func run(fails: Array[String]) -> void:
	var default_before: Variant = _file_snapshot(SaveService.RUN_PATH)
	_new_run_keeps_ordinary_map(fails)
	_door_on_final_act(fails)
	_door_hidden_off_final_act(fails)
	_door_opens_threshold(fails)
	if _file_snapshot(SaveService.RUN_PATH) != default_before:
		fails.append("test_sealed_door: tests touched the default save")
	SaveService.clear(SAVE_PATH)


static func _new_run_keeps_ordinary_map(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _main(content)
	main._vigil = _six_shard_vigil()
	main._forced_seed = 717
	main._new_run()
	_check(fails, main._map != null and main._map.nodes.size() > 1,
		"six-shard vigil starts on a generated map, not a single node")
	_check(fails, main._map.region != "rose_window",
		"six-shard vigil does not open the rose-window ceremony map")
	_check(fails, main._map.nodes.size() == 65,
		"seed 717 six-shard start is the ordinary 65-node graph")
	var types: Dictionary = {}
	for n: MapNode in main._map.nodes:
		types[n.type] = true
	_check(fails, not types.has("act4"),
		"six-shard start has no act4 ceremony node")
	_check(fails, main._map_screen != null and not main._map_screen._sealed_door.visible,
		"the sealed door stays hidden on act 0")
	_dispose(main)


static func _door_on_final_act(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var run: RunState = _final_act_run(content, VigilState.QUEST_IDS.duplicate())
	var map: WorldMap = WorldMap.benchmark(run)
	_check(fails, map.nodes.size() > 1 and map.region == "obsidian_spire",
		"final-act six-shard map is the generated Spire graph")
	var screen: WorldMapScreen = WorldMapScreen.new(map, content)
	screen.refresh(run)
	_check(fails, screen._sealed_door.visible,
		"six shards on the final act show the sealed-door affordance")
	_check(fails, screen._sealed_door.tooltip_text
			== Locale.active.t("ui.map.sealedDoor.aria"),
		"sealed-door aria is the locale key")
	var fired: Array[bool] = [false]
	screen.sealed_door_requested.connect(func() -> void: fired[0] = true)
	screen._sealed_door.pressed.emit()
	_check(fails, fired[0], "sealed-door affordance is exercisable headless")
	screen.free()


static func _door_hidden_off_final_act(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var five: Array = []
	for i: int in range(5):
		five.append(VigilState.QUEST_IDS[i])
	var short: RunState = _final_act_run(content, five)
	var screen: WorldMapScreen = WorldMapScreen.new(WorldMap.benchmark(short), content)
	screen.refresh(short)
	_check(fails, not screen._sealed_door.visible,
		"five shards on the final act hide the sealed door")
	screen.free()
	var early: RunState = RunState.new_run(content, 717, "run-sealed-early", {
		"shards": VigilState.QUEST_IDS.duplicate(),
	})
	screen = WorldMapScreen.new(WorldMap.benchmark(early), content)
	screen.refresh(early)
	_check(fails, early.act == 0 and not screen._sealed_door.visible,
		"six shards before the final act hide the sealed door")
	screen.free()


static func _door_opens_threshold(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var run: RunState = _final_act_run(content, VigilState.QUEST_IDS.duplicate())
	var main: Main = _main(content)
	main.game = GlassvowGame.new(content, run)
	main._map = WorldMap.benchmark(run)
	main._show_map()
	_check(fails, main._map_screen != null and main._map_screen._sealed_door.visible,
		"final-act map screen shows the sealed door")
	main._map_screen.sealed_door_requested.emit()
	_check(fails, main._modal is ThresholdScreen,
		"sealed door opens ThresholdScreen as an overlay")
	var overlay: ThresholdScreen = main._modal as ThresholdScreen
	overlay.vigil_requested.emit()
	_check(fails, main._modal == null, "closing the door returns to the map")
	_check(fails, main._map_screen != null, "the generated map stays under the overlay")
	_dispose(main)


static func _final_act_run(content: ContentDB, shards: Array) -> RunState:
	var run: RunState = RunState.new_run(content, 717, "run-sealed-final", {
		"shards": shards,
	})
	run.start_next_act(content)
	run.start_next_act(content)
	return run


static func _six_shard_vigil() -> VigilState:
	var vigil: VigilState = VigilState.blank()
	for id: String in VigilState.QUEST_IDS:
		vigil.quests[id]["state"] = "complete"
		vigil.shards.append(id)
	return vigil


static func _main(content: ContentDB) -> Main:
	var main: Main = Main.new()
	main.content = content
	main._run_save_path = SAVE_PATH
	main._vigil = VigilState.blank()
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	return main


static func _dispose(main: Main) -> void:
	main._clear_route()
	for child: Node in main.get_children():
		child.free()
	main.free()


static func _file_snapshot(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else null
