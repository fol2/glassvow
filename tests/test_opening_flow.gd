extends RefCounted
## #320: first-run 續火 skips Embark, run 2 returns it, a mid-opening
## crash resumes the owed line, and every later departure stages without
## replaying the opening.

const RUN_PATH: String = "user://test_opening_flow_run_v2.json"
const VIGIL_PATH: String = "user://test_opening_flow_vigil_v2.json"
const DEV_PATH: String = "user://test_opening_flow_dev_run_v2.json"


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("opening_flow: %s" % what)


static func run(fails: Array[String]) -> void:
	var default_run: Variant = _file_snapshot(SaveService.RUN_PATH)
	var default_vigil: Variant = _file_snapshot(SaveService.VIGIL_PATH)
	_fresh_begin_skips_embark(fails)
	_run_two_returns_embark(fails)
	_choiceful_unseen_gets_embark(fails)
	_crash_resumes_owed_line(fails)
	_departure_stages_without_opening(fails)
	_run_menu_refused_over_opening(fails)
	_dev_boot_skips_opening(fails)
	_skip_offer_records_guidance(fails)
	_skip_guidance_retry_stores_vigil(fails)
	_new_run_retry_restages(fails)
	_begin_anew_spares_production(fails)
	_opening_completion_is_the_hint_gate(fails)
	if _file_snapshot(SaveService.RUN_PATH) != default_run \
			or _file_snapshot(SaveService.VIGIL_PATH) != default_vigil:
		fails.append("opening_flow: tests touched the default save")
	SaveService.clear(RUN_PATH)
	SaveService.clear(DEV_PATH)
	SaveService.clear_vigil(VIGIL_PATH)


static func _fresh_begin_skips_embark(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _main(content)
	main._show_title()
	main._on_title_choice("begin", null)
	_wake(main)
	_check(fails, main.game != null, "續火 did not create a run")
	_check(fails, main._route_screen is ScenePlayer,
		"fresh profile 續火 did not play the opening")
	_check(fails, not (main._route_screen is EmbarkScreen)
			and not (main._choice_screen is EmbarkScreen),
		"fresh profile 續火 still opened Embark")
	_check(fails, typeof(main.game.run.pending_scene) == TYPE_DICTIONARY
			and str(main.game.run.pending_scene.get("id", "")) == "opening",
		"fresh profile 續火 did not persist pending_scene")
	_dispose(main)


static func _choiceful_unseen_gets_embark(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var cases: Array[Dictionary] = [
		{"tag": "aspect2", "unlock": "aspect2", "vow": 0},
		{"tag": "vow", "unlock": "", "vow": 1},
	]
	for case: Dictionary in cases:
		var main: Main = _main(content)
		var unlock: String = str(case["unlock"])
		if not unlock.is_empty():
			main._vigil.unlocks.append(unlock)
		var vow: int = case["vow"]
		main._vigil.vow_unlocked = vow
		main._show_title()
		main._on_title_choice("begin", null)
		_check(fails, main._route_screen is EmbarkScreen,
			"choiceful-but-unseen (%s) skipped Embark" % str(case["tag"]))
		_check(fails, not (main._route_screen is ScenePlayer),
			"choiceful-but-unseen (%s) played the opening before Embark" % str(case["tag"]))
		main._on_embark_begin(0, 0)
		_wake(main)
		_check(fails, main._route_screen is ScenePlayer,
			"choiceful-but-unseen (%s) did not play the opening after Embark" % str(case["tag"]))
		_dispose(main)


static func _run_two_returns_embark(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _main(content)
	main._vigil.scenes_seen.append("opening")
	main._show_title()
	main._on_title_choice("begin", null)
	_check(fails, main._route_screen is EmbarkScreen,
		"run 2 續火 did not return Embark")
	_check(fails, not (main._route_screen is ScenePlayer),
		"run 2 續火 replayed the opening")
	_dispose(main)


static func _crash_resumes_owed_line(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var producer: Main = _main(content)
	producer._show_title()
	producer._on_title_choice("begin", null)
	_wake(producer)
	var player: ScenePlayer = producer._route_screen as ScenePlayer
	_check(fails, player != null, "resume producer did not open the opening")
	if player != null:
		player._process(0.016)
	var loaded: RunState = SaveService.load_run(content, RUN_PATH)
	_dispose(producer)
	_check(fails, loaded != null and typeof(loaded.pending_scene) == TYPE_DICTIONARY
			and int(float(str(loaded.pending_scene.get("cursor", -1)))) == 1,
		"an interrupted opening did not persist cursor 1")
	var resumed: Main = _main(content)
	resumed._continue_run(loaded)
	_wake(resumed)
	var again: ScenePlayer = resumed._route_screen as ScenePlayer
	_check(fails, again != null, "resume did not restore ScenePlayer")
	if again != null:
		var line: Label = again.find_child("Line", true, false) as Label
		_check(fails, line != null and line.text == Locale.active.t("story.opening.b1.l2"),
			"resume replayed from line 0 instead of the owed line")
	_dispose(resumed)


static func _departure_stages_without_opening(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var first: Main = _main(content)
	first._forced_seed = 32001
	first._show_title()
	first._on_title_choice("begin", null)
	_drive(first)
	_check(fails, first._vigil.scenes_seen.has("opening"),
		"finishing the opening did not mark scenes_seen")
	_check(fails, first._map_screen is WorldMapScreen
			and not (first._route_screen is ScenePlayer),
		"the opening did not hand off to the map")
	_dispose(first)
	var later: Main = _main(content)
	later._forced_seed = 32002
	later._vigil.scenes_seen.append("opening")
	later._transitions.instant = false
	later._new_run()
	_check(fails, later._route_screen is DepartureStaging,
		"run 2 departure did not fire staging")
	_check(fails, not (later._route_screen is ScenePlayer),
		"run 2 departure replayed the opening")
	_dispose(later)


static func _run_menu_refused_over_opening(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _main(content)
	main._new_run()
	_wake(main)
	_check(fails, main._route_screen is ScenePlayer, "opening did not mount")
	_check(fails, main._run_hud == null, "run HUD mounted over the opening")
	main._show_run_menu()
	_check(fails, main._modal == null, "run menu opened over the opening")
	_dispose(main)


static func _dev_boot_skips_opening(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _main(content)
	main._opening_suppressed = true
	main._forced_seed = 32003
	main._new_run()
	_check(fails, not (main._route_screen is ScenePlayer),
		"a suppressed boot played the opening")
	_check(fails, main._map_screen is WorldMapScreen,
		"a suppressed boot did not land on the map")
	_check(fails, not main._vigil.scenes_seen.has("opening"),
		"a suppressed boot marked the opening seen")
	_dispose(main)
	var claimed: Main = _main(content)
	claimed._dev_claimed = true
	claimed._forced_seed = 32004
	claimed._new_run()
	_check(fails, not (claimed._route_screen is ScenePlayer),
		"a claimed dev boot played the opening")
	_dispose(claimed)


static func _skip_offer_records_guidance(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _main(content)
	main._forced_seed = 32005
	main._new_run()
	_wake(main)
	var player: ScenePlayer = main._route_screen as ScenePlayer
	_check(fails, player != null, "skip-offer producer did not open the opening")
	if player == null:
		_dispose(main)
		return
	player._press(true)
	player._process(ScenePlayer.SKIP_HOLD)
	player._press(false)
	_drive(main)
	_check(fails, main._vigil.scenes_seen.has("opening"),
		"hold-skip did not complete the opening")
	var offer: ChoiceScreen = main._choice_screen as ChoiceScreen
	_check(fails, offer != null, "hold-skip did not offer skip-guidance")
	if offer != null:
		var titles: Array[String] = []
		for node: Node in offer.find_children("", "Label", true, false):
			titles.append(str((node as Label).text))
		_check(fails, titles.has(Locale.active.t("ui.scene.skipGuidance.title")),
			"skip-guidance offer title drifted")
	var before: int = main._vigil.unlocks.size()
	main._on_skip_guidance_choice("skip")
	_check(fails, main._vigil.guidance_skipped, "accepting the offer did not record")
	_check(fails, main._vigil.unlocks.size() == before,
		"guidance_skipped leaked into unlocks")
	var persisted: VigilState = SaveService.load_vigil(VIGIL_PATH)
	_check(fails, persisted != null and persisted.guidance_skipped,
		"guidance_skipped did not persist")
	_check(fails, main._map_screen is WorldMapScreen,
		"accepting skip-guidance did not hand off to the map")
	_dispose(main)


static func _skip_guidance_retry_stores_vigil(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _main(content)
	main._forced_seed = 32006
	main._new_run()
	_wake(main)
	var player: ScenePlayer = main._route_screen as ScenePlayer
	_check(fails, player != null, "guidance-retry producer did not open the opening")
	if player == null:
		_dispose(main)
		return
	player._press(true)
	player._process(ScenePlayer.SKIP_HOLD)
	player._press(false)
	_drive(main)
	_check(fails, main._choice_screen is ChoiceScreen,
		"guidance-retry producer did not offer skip-guidance")
	main._vigil_save_path = "user://__no_such_dir_320__/vigil.json"
	main._on_skip_guidance_choice("skip")
	_check(fails, main._vigil.guidance_skipped,
		"accepting skip-guidance did not mark memory")
	var before: VigilState = SaveService.load_vigil(VIGIL_PATH)
	_check(fails, before != null and not before.guidance_skipped,
		"a failed Vigil store still wrote guidance_skipped")
	main._vigil_save_path = VIGIL_PATH
	main._on_save_error_choice("retry")
	var persisted: VigilState = SaveService.load_vigil(VIGIL_PATH)
	_check(fails, persisted != null and persisted.guidance_skipped,
		"Retry dropped the Vigil continuation; guidance_skipped evaporated")
	_check(fails, main._map_screen is WorldMapScreen,
		"Retry stored Vigil but did not continue into the run")
	_dispose(main)
	SaveService.clear("user://__no_such_dir_320__/vigil.json")


static func _new_run_retry_restages(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _main(content)
	main._forced_seed = 32007
	main._vigil.scenes_seen.append("opening")
	main._transitions.instant = false
	main._run_save_path = "user://__no_such_dir_320__/run.json"
	main._new_run()
	_check(fails, main.game != null, "staging-retry producer did not build a run")
	_check(fails, not (main._route_screen is DepartureStaging),
		"a failed run store still entered DepartureStaging")
	main._run_save_path = RUN_PATH
	main._on_save_error_choice("retry")
	_check(fails, main._route_screen is DepartureStaging,
		"Retry dropped the DepartureStaging continuation")
	var loaded: RunState = SaveService.load_run(content, RUN_PATH)
	_check(fails, loaded != null and loaded.run_id == main.game.run.run_id,
		"Retry did not persist the run before staging")
	_dispose(main)
	SaveService.clear("user://__no_such_dir_320__/run.json")


static func _begin_anew_spares_production(fails: Array[String]) -> void:
	var source: String = FileAccess.get_file_as_string("res://application/main.gd")
	var start: int = source.find("func _on_begin_anew(")
	var finish: int = source.find("\nfunc ", start + 1)
	var body: String = ""
	if start >= 0:
		body = source.substr(start) if finish < 0 else source.substr(start, finish - start)
	_check(fails, body.contains("SaveService.clear_run(game.run.run_id, _run_save_path)"),
		"Begin Anew clear_run does not pass _run_save_path")
	var content: ContentDB = ContentDB.load_full()
	var prod_snap: Variant = _file_snapshot(SaveService.RUN_PATH)
	var prod: RunState = RunState.new_run(content, 32041, "run-prod-320")
	prod.map = WorldMap.benchmark(prod).to_dict()
	var dev: RunState = RunState.new_run(content, 32042, "run-dev-320")
	dev.map = WorldMap.benchmark(dev).to_dict()
	if not SaveService.store(prod, SaveService.RUN_PATH) \
			or not SaveService.store(dev, DEV_PATH):
		_check(fails, false, "could not seed production and dev-profile runs")
		_restore_snapshot(SaveService.RUN_PATH, prod_snap)
		SaveService.clear(DEV_PATH)
		return
	var main: Main = _main(content)
	main._forced_seed = 32008
	main._run_save_path = DEV_PATH
	main._on_begin_anew("begin")
	var prod_after: RunState = SaveService.load_run(content, SaveService.RUN_PATH)
	_check(fails, prod_after != null and prod_after.run_id == "run-prod-320",
		"Begin Anew in the dev profile touched the production save")
	var leftover: RunState = SaveService.load_run(content, DEV_PATH)
	_check(fails, leftover != null and leftover.run_id != "run-dev-320",
		"Begin Anew in the dev profile did not replace the dev run")
	_check(fails, leftover != null and leftover.run_id == main.game.run.run_id,
		"Begin Anew in the dev profile did not create the new run on the injected path")
	_dispose(main)
	_restore_snapshot(SaveService.RUN_PATH, prod_snap)
	SaveService.clear(DEV_PATH)


static func _restore_snapshot(path: String, snap: Variant) -> void:
	if snap == null:
		SaveService.clear(path)
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(str(snap))
		file.close()


static func _opening_completion_is_the_hint_gate(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _main(content)
	main._new_run()
	_check(fails, not main._vigil.scenes_seen.has("opening"),
		"scenes_seen gained opening before the scene finished")
	_drive(main)
	_check(fails, main._vigil.scenes_seen.has("opening"),
		"#321's scenes_seen.has(\"opening\") gate is not written at completion")
	_dispose(main)


static func _wake(main: Main) -> void:
	var player: ScenePlayer = main._route_screen as ScenePlayer
	if player != null and player._beat == ScenePlayer.BEAT_IDLE and not player._done:
		player._ready()


static func _drive(main: Main) -> void:
	_wake(main)
	var steps: int = 0
	while main._route_screen is ScenePlayer and steps < 24:
		(main._route_screen as ScenePlayer)._process(0.016)
		steps += 1


static func _main(content: ContentDB) -> Main:
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)
	var main: Main = Main.new()
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
