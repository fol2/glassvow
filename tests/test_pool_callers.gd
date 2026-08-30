extends RefCounted
## #354: Batch 3 waystone/hearth callers. Loss is already live; this file
## pins the two remaining surfaces and the same-run h57 hearth consult.

const RUN_PATH: String = "user://test_pool_callers_run_v2.json"
const VIGIL_PATH: String = "user://test_pool_callers_vigil_v2.json"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_pool_callers: %s" % what)


static func run(fails: Array[String]) -> void:
	var default_run: Variant = _file_snapshot(SaveService.RUN_PATH)
	var default_vigil: Variant = _file_snapshot(SaveService.VIGIL_PATH)
	_hearth_start_once(fails)
	_hearth_resume_holds_row(fails)
	_waystone_once(fails)
	_waystone_resume_holds_row(fails)
	_idle_does_not_draw(fails)
	_rebuild_does_not_redraw(fails)
	_h57_same_run(fails)
	_shop_is_not_the_hearth(fails)
	if _file_snapshot(SaveService.RUN_PATH) != default_run \
			or _file_snapshot(SaveService.VIGIL_PATH) != default_vigil:
		fails.append("test_pool_callers: tests touched the default save")
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)


static func _hearth_start_once(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _departing(content, 35401)
	var screen: DepartureStaging = main._route_screen as DepartureStaging
	_check(fails, screen != null, "run-start hearth did not stage DepartureStaging")
	var row: Dictionary = PoolBeats.row_of(content.line_table, main.game.run)
	_check(fails, str(row.get("slot", "")) == PoolBeats.SLOT_HEARTH
			and str(row.get("id", "")).begins_with("pool.hearth."),
		"run-start hearth did not draw a pool.hearth row")
	var line: Label = screen.find_child("Line", true, false) as Label
	_check(fails, line != null and line.text == LineTable.text(row, false),
		"run-start hearth did not display the authored row")
	_check(fails, main.game.run.pool_draws.size() == 1,
		"run-start hearth did not consume exactly one row")
	if screen != null:
		screen._tap()
	_check(fails, main._map_screen is WorldMapScreen,
		"dismissing the hearth line did not reach the map")
	_check(fails, typeof(main.game.run.pending_pool) != TYPE_DICTIONARY,
		"dismissing the hearth line left pending_pool live")
	_dispose(main)


static func _hearth_resume_holds_row(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var producer: Main = _departing(content, 35402)
	var row: Dictionary = PoolBeats.row_of(content.line_table, producer.game.run)
	var id: String = str(row.get("id", ""))
	var saved: RunState = SaveService.load_run(content, RUN_PATH)
	_dispose(producer)
	var resumed: Main = _main(content)
	resumed._vigil.scenes_seen.append("opening")
	resumed._transitions.instant = false
	resumed._continue_run(saved)
	_wake(resumed)
	var screen: DepartureStaging = resumed._route_screen as DepartureStaging
	_check(fails, screen != null, "hearth resume did not restage DepartureStaging")
	var again: Dictionary = PoolBeats.row_of(content.line_table, resumed.game.run)
	_check(fails, str(again.get("id", "")) == id,
		"hearth resume advanced to a different row")
	_check(fails, resumed.game.run.pool_draws.size() == 1,
		"hearth resume consumed a second row")
	var line: Label = screen.find_child("Line", true, false) as Label \
		if screen != null else null
	_check(fails, line != null and line.text == LineTable.text(row, false),
		"hearth resume did not keep the authored line")
	_dispose(resumed)


static func _waystone_once(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _on_map(content, 35403)
	_pick_first(main)
	var screen: ScenePlayer = main._route_screen as ScenePlayer
	_wake(main)
	_check(fails, screen != null, "waystone interstitial did not mount ScenePlayer")
	var row: Dictionary = PoolBeats.row_of(content.line_table, main.game.run)
	_check(fails, str(row.get("slot", "")) == PoolBeats.SLOT_WAYSTONE
			and str(row.get("id", "")).begins_with("pool.waystone."),
		"waystone interstitial did not draw a pool.waystone row")
	var line: Label = screen.find_child("Line", true, false) as Label \
		if screen != null else null
	_check(fails, line != null and line.text == LineTable.text(row, false),
		"waystone interstitial did not display the authored row")
	_check(fails, main.game.run.pool_draws.size() == 2,
		"waystone interstitial did not add exactly one draw after hearth")
	_drive(main)
	_check(fails, typeof(main.game.run.pending_pool) != TYPE_DICTIONARY,
		"finishing the waystone interstitial left pending_pool live")
	_check(fails, main.game.run.pool_draws.size() == 2,
		"finishing the waystone interstitial consumed another row")
	_dispose(main)


static func _waystone_resume_holds_row(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var producer: Main = _on_map(content, 35404)
	_pick_first(producer)
	_wake(producer)
	var id: String = str(PoolBeats.row_of(content.line_table, producer.game.run).get("id", ""))
	var saved: RunState = SaveService.load_run(content, RUN_PATH)
	_dispose(producer)
	var resumed: Main = _main(content)
	resumed._vigil.scenes_seen.append("opening")
	resumed._transitions.instant = false
	resumed._continue_run(saved)
	_wake(resumed)
	var again: Dictionary = PoolBeats.row_of(content.line_table, resumed.game.run)
	_check(fails, str(again.get("id", "")) == id,
		"waystone resume advanced to a different row")
	_check(fails, resumed.game.run.pool_draws.size() == 2,
		"waystone resume consumed a second waystone row")
	var screen: ScenePlayer = resumed._route_screen as ScenePlayer
	var line: Label = screen.find_child("Line", true, false) as Label \
		if screen != null else null
	_check(fails, line != null and line.text == LineTable.text(again, false),
		"waystone resume did not keep the authored line")
	_dispose(resumed)


static func _idle_does_not_draw(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _on_map(content, 35405)
	_check(fails, main._map_screen is WorldMapScreen,
		"idle map probe did not land on the map")
	_check(fails, typeof(main.game.run.pending_pool) != TYPE_DICTIONARY,
		"idle map staged a pool beat")
	_check(fails, not main.game.run.pool_beats.has(PoolBeats.waystone_key(
			main._map.nodes[0].id)),
		"idle map drew a waystone row")
	_check(fails, main.game.run.pool_draws.size() == 1
			and main.game.run.pool_beats.has(PoolBeats.KEY_START),
		"idle map dropped the run-start hearth receipt")
	_dispose(main)


static func _rebuild_does_not_redraw(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _on_map(content, 35406)
	_pick_first(main)
	_wake(main)
	var id: String = str(PoolBeats.row_of(content.line_table, main.game.run).get("id", ""))
	var draws: int = main.game.run.pool_draws.size()
	main._rebuild_active_route()
	_wake(main)
	_check(fails, str(PoolBeats.row_of(content.line_table, main.game.run).get("id", "")) == id
			and main.game.run.pool_draws.size() == draws,
		"rebuilding the waystone interstitial consumed another row")
	_dispose(main)


static func _h57_same_run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _on_map(content, 35407)
	main.game.run.act = 1
	main.game.run.player.gold = 1000
	main.game.run.quests["usurper"] = {
		"state": "armed", "progress": 0, "memory": {},
	}
	_check(fails, main.game.quests.buy_usurper(main.game.run),
		"buy_usurper failed in the h57 probe")
	_check(fails, str(main.game.run.quests["usurper"].get("state", "")) == "revealed",
		"buy_usurper did not set usurper.revealed")
	_check(fails, not main.game.run.pool_beats.has(PoolBeats.KEY_USURPER),
		"buying the lantern consulted the hearth at the shop")
	var row: Dictionary = PoolBeats.stage(
		main.game.run, main._vigil, content,
		PoolBeats.SLOT_HEARTH, PoolBeats.KEY_USURPER, PoolBeats.RESUME_LEAVE)
	_check(fails, str(row.get("id", "")) == "pool.hearth.h57",
		"same-run hearth consult after buy_usurper did not select h57")
	main._transitions.instant = false
	main._show_pending_pool()
	_wake(main)
	var screen: DepartureStaging = main._route_screen as DepartureStaging
	var line: Label = screen.find_child("Line", true, false) as Label \
		if screen != null else null
	_check(fails, screen != null and line != null
			and line.text == LineTable.text(row, false),
		"h57 was not displayed on the hearth surface")
	_check(fails, str(main.game.run.pool_beats.get(PoolBeats.KEY_USURPER, ""))
			== "pool.hearth.h57",
		"h57 consult did not persist the beat key")
	_dispose(main)


static func _shop_is_not_the_hearth(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _on_map(content, 35408)
	var walk: WorldMap = WorldMap.slice()
	walk.at = 3
	walk.nodes[3].type = "shop"
	main.game.run.node_id = walk.nodes[3].id
	main.game.run.map = walk.to_dict()
	main._map = walk
	main.game.run.act = 1
	main.game.run.player.gold = 1000
	main.game.run.quests["usurper"] = {
		"state": "armed", "progress": 0, "memory": {},
	}
	main._show_shop()
	_check(fails, main.game.quests.buy_usurper(main.game.run),
		"shop probe could not buy the lantern")
	_check(fails, main._route_screen is ShopScreen,
		"buying the lantern left the shop")
	_check(fails, not main.game.run.pool_beats.has(PoolBeats.KEY_USURPER),
		"the shop itself consulted pool.hearth")
	main._transitions.instant = false
	main._on_shop_choice("leave")
	var screen: DepartureStaging = main._route_screen as DepartureStaging
	var row: Dictionary = PoolBeats.row_of(content.line_table, main.game.run)
	_check(fails, screen != null and str(row.get("id", "")) == "pool.hearth.h57",
		"leaving the shop after buy_usurper did not consult the hearth")
	_dispose(main)


static func _departing(content: ContentDB, seed: int) -> Main:
	var main: Main = _main(content)
	main._forced_seed = seed
	main._vigil.scenes_seen.append("opening")
	main._transitions.instant = false
	main._new_run()
	_wake(main)
	return main


static func _on_map(content: ContentDB, seed: int) -> Main:
	var main: Main = _departing(content, seed)
	var screen: DepartureStaging = main._route_screen as DepartureStaging
	if screen != null:
		screen._tap()
	return main


static func _pick_first(main: Main) -> void:
	if main._map_screen != null:
		main._map_screen.instant = true
	var live: Array[int] = main._map.reachable() if main._map != null else []
	if live.is_empty():
		return
	if main._map_screen != null:
		main._map_screen.choose(live[0])
	else:
		main._on_node_chosen(live[0])


static func _wake(main: Main) -> void:
	var hearth: DepartureStaging = main._route_screen as DepartureStaging
	if hearth != null and not hearth._line_up and not hearth._done:
		hearth._bind_line()
		hearth._await_line()
		return
	var player: ScenePlayer = main._route_screen as ScenePlayer
	if player != null and player._beat == ScenePlayer.BEAT_IDLE and not player._done:
		player._ready()


static func _drive(main: Main) -> void:
	_wake(main)
	var player: ScenePlayer = main._route_screen as ScenePlayer
	if player == null:
		return
	player._press(true)
	player._press(false)


static func _main(content: ContentDB) -> Main:
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)
	var main: Main = Main.new()
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main.content = content
	main._run_save_path = RUN_PATH
	main._vigil_save_path = VIGIL_PATH
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
