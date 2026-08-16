extends RefCounted
## Slice 3–4 of #309: pending_scene / scenes_seen round-trip, the opening
## fires once, a mid-scene kill resumes the owed line, the L0 plant is
## art-gated, and the unsealing fires on both run outcomes.

const RUN_PATH: String = "user://test_scene_wiring_run_v2.json"
const VIGIL_PATH: String = "user://test_scene_wiring_vigil_v2.json"


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("scene_wiring: %s" % what)


static func run(fails: Array[String]) -> void:
	var default_run: Variant = _file_snapshot(SaveService.RUN_PATH)
	var default_vigil: Variant = _file_snapshot(SaveService.VIGIL_PATH)
	_pending_scene_roundtrip(fails)
	_scenes_seen_roundtrip(fails)
	_opening_once(fails)
	_resume_owed_line(fails)
	_hearth_plant_art_gate(fails)
	_hearth_plant_is_departure_only(fails)
	_vigil_pending_roundtrip(fails)
	_unsealing_on_loss(fails)
	_unsealing_on_win(fails)
	_unsealing_once(fails)
	_unsealing_needs_six(fails)
	_unsealing_boot_resume(fails)
	_unsealing_yields_to_a_resumable_run(fails)
	_finish_stores_vigil_before_run(fails)
	_unsealing_retry_restores_the_scene(fails)
	_unsealing_replay_is_transient(fails)
	if _file_snapshot(SaveService.RUN_PATH) != default_run \
			or _file_snapshot(SaveService.VIGIL_PATH) != default_vigil:
		fails.append("scene_wiring: tests touched the default save")
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)


static func _pending_scene_roundtrip(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var run: RunState = RunState.new_run(content, 30903, "run-scene-rt")
	run.pending_scene = {"id": "opening", "cursor": 4}
	_check(fails, not run.to_dict().has("pendingScene"),
		"pending_scene leaked into the fixture projection")
	SaveService.clear(RUN_PATH)
	_check(fails, SaveService.store(run, RUN_PATH), "pending_scene store failed")
	var loaded: RunState = SaveService.load_run(content, RUN_PATH)
	_check(fails, loaded != null and typeof(loaded.pending_scene) == TYPE_DICTIONARY,
		"pending_scene did not reload")
	if typeof(loaded.pending_scene) == TYPE_DICTIONARY:
		var pending: Dictionary = loaded.pending_scene
		_check(fails, str(pending.get("id", "")) == "opening"
				and int(float(str(pending.get("cursor", -1)))) == 4,
			"pending_scene round-trip lost id or cursor")
	var bad: Dictionary = run.to_save_dict()
	bad["pendingScene"] = {"id": "", "cursor": 0}
	_check(fails, RunState.from_save_dict(bad, content) == null,
		"empty scene id was accepted")
	SaveService.clear(RUN_PATH)


static func _scenes_seen_roundtrip(fails: Array[String]) -> void:
	var vigil: VigilState = VigilState.blank()
	vigil.scenes_seen.append("opening")
	SaveService.clear_vigil(VIGIL_PATH)
	_check(fails, SaveService.store_vigil(vigil, VIGIL_PATH),
		"scenes_seen store failed")
	var loaded: VigilState = SaveService.load_vigil(VIGIL_PATH)
	_check(fails, loaded.scenes_seen.size() == 1 and loaded.scenes_seen[0] == "opening",
		"scenes_seen did not round-trip")
	var raw: Dictionary = VigilState.blank().to_dict()
	raw.erase("scenesSeen")
	var old: VigilState = VigilState.from_dict(raw)
	_check(fails, old != null and old.scenes_seen.is_empty(),
		"a v2 vigil without scenesSeen did not default")
	SaveService.clear_vigil(VIGIL_PATH)


static func _opening_once(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _main(content)
	main._forced_seed = 30903
	main._new_run()
	_wake(main)
	_check(fails, main._route_screen is ScenePlayer,
		"first run did not play the opening")
	_check(fails, typeof(main.game.run.pending_scene) == TYPE_DICTIONARY
			and str(main.game.run.pending_scene.get("id", "")) == "opening",
		"first run did not persist pending_scene")
	_drive(main)
	_check(fails, main._vigil.scenes_seen.has("opening"),
		"finishing the opening did not mark scenes_seen")
	var persisted_opening: VigilState = SaveService.load_vigil(VIGIL_PATH)
	_check(fails, persisted_opening.scenes_seen.has("opening"),
		"finishing the opening did not persist scenes_seen to disk")
	_check(fails, main._map_screen is WorldMapScreen
			and not (main._route_screen is ScenePlayer),
		"the opening did not hand off to the map")
	main._new_run()
	_check(fails, main._map_screen is WorldMapScreen
			and not (main._route_screen is ScenePlayer),
		"a second run replayed the opening")
	_dispose(main)


static func _resume_owed_line(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var producer: Main = _main(content)
	producer._forced_seed = 30903
	producer._new_run()
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


static func _hearth_plant_art_gate(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var walk: WorldMap = WorldMap.slice()
	walk.at = -1
	var dark: WorldMapScreen = WorldMapScreen.new(walk, content)
	dark.instant = false
	# The absent case takes a path that cannot exist, the mirror of the present
	# case below pointing `hearth_plate` at a stand-in. It used to assert that
	# HEARTH_PLATE itself was missing, which made this a tripwire on the art's
	# arrival rather than a test of the gate: #310 shipped the plate and inverted
	# it. What the gate owes us is "no plate, no plant", true whatever is on disk.
	dark.hearth_plate = "res://assets/art/scenes/__no_such_plate__.png"
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(dark)
	_check(fails, ResourceLoader.exists(WorldMapScreen.HEARTH_PLATE),
		"the real hearth plate is missing; #310 shipped it")
	_check(fails, dark.choose(0), "unseated departure without art was refused")
	_check(fails, dark.find_child("HearthPlant", true, false) == null,
		"a missing hearth plate still staged the plant")
	tree.root.remove_child(dark)
	dark.free()
	walk = WorldMap.slice()
	walk.at = -1
	var lit: WorldMapScreen = WorldMapScreen.new(walk, content)
	lit.instant = false
	lit.hearth_plate = "res://assets/art/scenes/night-stall.png"
	var arrived: Array[int] = []
	lit.node_chosen.connect(func(i: int) -> void: arrived.append(i))
	tree.root.add_child(lit)
	_check(fails, lit.choose(0), "unseated departure with art was refused")
	_check(fails, lit.find_child("HearthPlant", true, false) != null
			and lit.find_child("HearthWindow", true, false) != null,
		"a present hearth plate did not stage the plant")
	_check(fails, arrived.is_empty(), "the plant handed off before the hold")
	tree.root.remove_child(lit)
	lit.free()


## The screen can only see "the lantern is unseated", and every act starts
## that way — so main, which knows which unseated map is the DEPARTURE, has to
## withhold the plate for acts II and III.
static func _hearth_plant_is_departure_only(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _main(content)
	main._forced_seed = 30903
	main._new_run()
	_drive(main)
	var screen: WorldMapScreen = main._map_screen as WorldMapScreen
	_check(fails, screen != null and not screen.hearth_plate.is_empty(),
		"act I departure lost the hearth plant")
	main.game.run.act = 1
	main._show_map()
	var later: WorldMapScreen = main._map_screen as WorldMapScreen
	_check(fails, later != null and later.hearth_plate.is_empty(),
		"act II planted the hearth mid-journey")
	_dispose(main)


static func _vigil_pending_roundtrip(fails: Array[String]) -> void:
	var vigil: VigilState = VigilState.blank()
	vigil.pending_scene = {"id": "unsealing", "cursor": 2}
	SaveService.clear_vigil(VIGIL_PATH)
	_check(fails, SaveService.store_vigil(vigil, VIGIL_PATH),
		"vigil pending_scene store failed")
	var loaded: VigilState = SaveService.load_vigil(VIGIL_PATH)
	_check(fails, typeof(loaded.pending_scene) == TYPE_DICTIONARY,
		"vigil pending_scene did not reload")
	if typeof(loaded.pending_scene) == TYPE_DICTIONARY:
		var pending: Dictionary = loaded.pending_scene
		_check(fails, str(pending.get("id", "")) == "unsealing"
				and int(float(str(pending.get("cursor", -1)))) == 2,
			"vigil pending_scene round-trip lost id or cursor")
	var raw: Dictionary = VigilState.blank().to_dict()
	raw.erase("pendingScene")
	var old: VigilState = VigilState.from_dict(raw)
	_check(fails, old != null and old.pending_scene == null,
		"a v2 vigil without pendingScene did not default")
	SaveService.clear_vigil(VIGIL_PATH)


static func _unsealing_on_loss(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _terminal(content, 5, true, "death")
	main._on_terminal_commit("commit")
	_wake(main)
	_check(fails, main._vigil.shards.size() == 6,
		"a lost run did not fold the sixth shard")
	_check(fails, main._route_screen is ScenePlayer,
		"six shards on a lost run did not play the unsealing")
	if main._route_screen is ScenePlayer:
		_check(fails, (main._route_screen as ScenePlayer)._script.id == "unsealing",
			"the loss path played a scene other than unsealing")
	_check(fails, typeof(main._vigil.pending_scene) == TYPE_DICTIONARY
			and str(main._vigil.pending_scene.get("id", "")) == "unsealing",
		"the loss path did not persist a Vigil-scoped cursor")
	_dispose(main)


static func _unsealing_on_win(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _terminal(content, 5, true, "win")
	main._on_terminal_commit("commit")
	_check(fails, main._route_screen is DawnScreen,
		"a won run skipped Dawn before the unsealing")
	if main.game != null and typeof(main.game.run.pending_dawn) == TYPE_DICTIONARY:
		var dawn: Dictionary = main.game.run.pending_dawn
		var events_v: Variant = dawn.get("events", [])
		if typeof(events_v) == TYPE_ARRAY:
			var events: Array = events_v
			dawn["cursor"] = events.size()
	main._finish_dawn()
	_wake(main)
	_check(fails, main._route_screen is ScenePlayer,
		"six shards on a won run did not play the unsealing before title")
	_dispose(main)


static func _unsealing_once(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _terminal(content, 5, true, "death")
	main._on_terminal_commit("commit")
	_drive(main)
	_check(fails, main._vigil.scenes_seen.has("unsealing"),
		"finishing the unsealing did not mark scenes_seen")
	var persisted_unsealing: VigilState = SaveService.load_vigil(VIGIL_PATH)
	_check(fails, persisted_unsealing.scenes_seen.has("unsealing"),
		"finishing the unsealing did not persist scenes_seen to disk")
	_check(fails, not (main._route_screen is ScenePlayer),
		"the unsealing did not hand off to title")
	var seen: Array[String] = main._vigil.scenes_seen.duplicate()
	_dispose(main)
	var again: Main = _terminal(content, 6, false, "death")
	again._vigil.scenes_seen = seen
	again._on_terminal_commit("commit")
	_check(fails, not (again._route_screen is ScenePlayer),
		"the unsealing fired a second time")
	_dispose(again)


static func _unsealing_needs_six(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _terminal(content, 5, false, "death")
	main._on_terminal_commit("commit")
	_check(fails, main._vigil.shards.size() == 5,
		"five shards grew a sixth without a completion")
	_check(fails, not (main._route_screen is ScenePlayer),
		"five shards played the unsealing")
	_dispose(main)


static func _unsealing_boot_resume(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _main(content)
	main._vigil.pending_scene = {"id": "unsealing", "cursor": 1}
	_check(fails, main._store_vigil(), "boot resume could not store the cursor")
	main._vigil = main._load_vigil()
	main.game = null
	main._route_idle()
	_wake(main)
	var player: ScenePlayer = main._route_screen as ScenePlayer
	_check(fails, player != null, "a boot with no live run dropped the unsealing")
	if player != null:
		var line: Label = player.find_child("Line", true, false) as Label
		_check(fails, line != null and line.text == Locale.active.t("story.unsealing.b2.l1"),
			"boot resume replayed from line 0 instead of the owed line")
	_dispose(main)


## A run that can still be continued owns the boot. Six shards and an unseen
## unsealing are not enough to queue the scene while pending_dawn is on disk —
## that is the process-death window between the Vigil fold and the dawn write.
static func _unsealing_yields_to_a_resumable_run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _terminal(content, 6, false, "win")
	main.game.run.pending_run_end = null
	main.game.run.pending_dawn = {
		"events": [{"kind": "memory", "title": "x", "body": "y"}],
		"cursor": 0,
	}
	_check(fails, main._store_run(), "yield-to-run could not store pending_dawn")
	main.game = null
	main._route_idle()
	_check(fails, typeof(main._vigil.pending_scene) != TYPE_DICTIONARY,
		"a resumable run queued the unsealing ahead of its dawn")
	_check(fails, not (main._route_screen is ScenePlayer),
		"a resumable run played the unsealing ahead of its dawn")
	_dispose(main)


## Poison the run path so the second store fails. Vigil-first still records
## the flag; run-first short-circuits and never reaches the Vigil.
static func _finish_stores_vigil_before_run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _main(content)
	main._forced_seed = 30903
	main._new_run()
	_wake(main)
	_check(fails, typeof(main.game.run.pending_scene) == TYPE_DICTIONARY,
		"finish-order producer did not open the opening")
	main._run_save_path = "user://__no_such_dir_309__/run.json"
	main._on_scene_finished()
	var persisted: VigilState = SaveService.load_vigil(VIGIL_PATH)
	_check(fails, persisted.scenes_seen.has("opening"),
		"finishing the opening stored the run before the Vigil")
	_dispose(main)
	SaveService.clear("user://__no_such_dir_309__/run.json")


## The unsealing plays with game == null, so Retry cannot take the live-run
## branch. It must re-store the Vigil and route back into the scene.
static func _unsealing_retry_restores_the_scene(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _terminal(content, 5, true, "death")
	main._on_terminal_commit("commit")
	_wake(main)
	_check(fails, main._route_screen is ScenePlayer and main.game == null,
		"retry producer did not play a Vigil-scoped unsealing")
	if typeof(main._vigil.pending_scene) != TYPE_DICTIONARY:
		_check(fails, false, "retry producer lost the Vigil cursor")
		_dispose(main)
		return
	var pending: Dictionary = main._vigil.pending_scene
	pending["cursor"] = int(float(str(pending.get("cursor", 0)))) + 1
	main._on_save_error_choice("retry")
	_wake(main)
	_check(fails, main._route_screen is ScenePlayer,
		"Vigil-scoped Retry dropped the unsealing")
	var disk: VigilState = SaveService.load_vigil(VIGIL_PATH)
	_check(fails, typeof(disk.pending_scene) == TYPE_DICTIONARY
			and int(float(str(disk.pending_scene.get("cursor", -1)))) \
				== int(float(str(pending.get("cursor", -1)))),
		"Vigil-scoped Retry did not re-store the cursor")
	_dispose(main)


static func _unsealing_replay_is_transient(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _main(content)
	main._vigil = _six_pane_vigil()
	main._vigil.scenes_seen.append("unsealing")
	var seen: Array[String] = main._vigil.scenes_seen.duplicate()
	main._show_vigil(true)
	var replay: Button = main._route_screen.find_child("Replay", true, false) as Button
	_check(fails, replay != null, "a six-pane rose has no window-body replay")
	if replay != null:
		replay.pressed.emit()
	_wake(main)
	_check(fails, main._route_screen is ScenePlayer,
		"rose replay did not play the unsealing")
	_check(fails, main._vigil.pending_scene == null,
		"rose replay persisted a cursor")
	_drive(main)
	_check(fails, main._vigil.scenes_seen == seen,
		"rose replay touched scenes_seen")
	_check(fails, main._route_screen is VigilScreen,
		"rose replay did not return to the Vigil")
	_dispose(main)
	var dark: RoseWindowView = RoseWindowView.new({}, {}, 0, [])
	_check(fails, dark.find_child("Replay", true, false) == null,
		"an unlit rose still offered replay")
	dark.free()


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


static func _terminal(content: ContentDB, shards: int, complete_next: bool,
		outcome: String) -> Main:
	var main: Main = _main(content)
	main._vigil = VigilState.blank()
	main._vigil.scenes_seen.append("opening")
	for i: int in range(mini(shards, VigilState.QUEST_IDS.size())):
		var id: String = VigilState.QUEST_IDS[i]
		main._vigil.quests[id]["state"] = "complete"
		main._vigil.shards.append(id)
	var run: RunState = RunState.new_run(content, 30904, "run-unseal-%s" % outcome, {
		"quests": main._vigil.quests.duplicate(true),
		"shards": main._vigil.shards.duplicate(),
	})
	if complete_next and shards < VigilState.QUEST_IDS.size():
		var next_id: String = VigilState.QUEST_IDS[shards]
		run.quests[next_id] = {"state": "complete", "progress": 1, "memory": {}}
	run.pending_run_end = {"outcome": outcome, "bequestAnswered": true}
	main.game = GlassvowGame.new(content, run)
	main._store_run()
	return main


static func _six_pane_vigil() -> VigilState:
	var vigil: VigilState = VigilState.blank()
	vigil.unlocks.append("emberglass")
	for id: String in VigilState.QUEST_IDS:
		vigil.quests[id]["state"] = "complete"
		vigil.shards.append(id)
	vigil.scenes_seen.append("opening")
	return vigil


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
