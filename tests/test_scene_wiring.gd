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
	_guidance_skipped_roundtrip(fails)
	_hints_seen_roundtrip(fails)
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
	_lamplighter_pre_once(fails)
	_lamplighter_pre_resume(fails)
	_lamplighter_leave_skips_post(fails)
	_lamplighter_cannot_skips_post(fails)
	_lamplighter_post_once(fails)
	_lamplighter_post_resume(fails)
	_lamplighter_does_not_inflate_unlocks(fails)
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


static func _guidance_skipped_roundtrip(fails: Array[String]) -> void:
	var vigil: VigilState = VigilState.blank()
	vigil.guidance_skipped = true
	SaveService.clear_vigil(VIGIL_PATH)
	_check(fails, SaveService.store_vigil(vigil, VIGIL_PATH),
		"guidance_skipped store failed")
	var loaded: VigilState = SaveService.load_vigil(VIGIL_PATH)
	_check(fails, loaded != null and loaded.guidance_skipped,
		"guidance_skipped did not round-trip")
	_check(fails, loaded.unlocks.is_empty(),
		"guidance_skipped leaked into unlocks")
	var raw: Dictionary = VigilState.blank().to_dict()
	raw.erase("guidanceSkipped")
	var old: VigilState = VigilState.from_dict(raw)
	_check(fails, old != null and not old.guidance_skipped,
		"a v2 vigil without guidanceSkipped did not default")
	SaveService.clear_vigil(VIGIL_PATH)


static func _hints_seen_roundtrip(fails: Array[String]) -> void:
	var vigil: VigilState = VigilState.blank()
	vigil.hints_seen.append("hint_map_select")
	SaveService.clear_vigil(VIGIL_PATH)
	_check(fails, SaveService.store_vigil(vigil, VIGIL_PATH),
		"hints_seen store failed")
	var loaded: VigilState = SaveService.load_vigil(VIGIL_PATH)
	_check(fails, loaded != null and loaded.hints_seen.size() == 1
			and loaded.hints_seen[0] == "hint_map_select",
		"hints_seen did not round-trip")
	_check(fails, loaded.unlocks.is_empty(),
		"hints_seen leaked into unlocks")
	var raw: Dictionary = VigilState.blank().to_dict()
	raw.erase("hintsSeen")
	var old: VigilState = VigilState.from_dict(raw)
	_check(fails, old != null and old.hints_seen.is_empty(),
		"a v2 vigil without hintsSeen did not default")
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
	var dark: DepartureStaging = DepartureStaging.new(
		"res://assets/art/scenes/__no_such_plate__.png")
	dark.instant = false
	var dark_done: Array[int] = [0]
	dark.finished.connect(func() -> void: dark_done[0] += 1)
	dark._ready()
	_check(fails, ResourceLoader.exists(DepartureStaging.HEARTH_PLATE),
		"the real hearth plate is missing; #310 shipped it")
	_check(fails, dark.find_child("HearthPlant", true, false) == null,
		"a missing hearth plate still staged the plant")
	_check(fails, dark_done[0] == 1, "a missing plate did not finish immediately")
	dark.free()
	var lit: DepartureStaging = DepartureStaging.new(
		"res://assets/art/scenes/night-stall.png")
	lit.instant = false
	var lit_done: Array[int] = [0]
	lit.finished.connect(func() -> void: lit_done[0] += 1)
	lit._ready()
	_check(fails, lit.find_child("HearthPlant", true, false) != null
			and lit.find_child("HearthWindow", true, false) != null,
		"a present hearth plate did not stage the plant")
	_check(fails, lit_done[0] == 0, "the plant handed off before the hold")
	lit.free()


## Run 1 rides the opening's beats ③–④; run 2+ rides DepartureStaging on
## the Embark → run transition. The map never plants — every act starts
## unseated, and an unguarded waystone plant would fire the hearth from
## the middle of acts II and III.
static func _hearth_plant_is_departure_only(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _main(content)
	main._forced_seed = 30903
	main._new_run()
	_drive(main)
	_check(fails, main._map_screen is WorldMapScreen
			and not (main._route_screen is ScenePlayer),
		"run 1 did not hand the opening to the map")
	var walk: WorldMap = WorldMap.slice()
	walk.at = -1
	var screen: WorldMapScreen = WorldMapScreen.new(walk, content)
	screen.instant = false
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	_check(fails, screen.choose(0), "unseated map choice was refused")
	_check(fails, screen.find_child("HearthPlant", true, false) == null,
		"the map still planted the hearth on a waystone")
	tree.root.remove_child(screen)
	screen.free()
	_dispose(main)
	var next: Main = _main(content)
	next._forced_seed = 30903
	next._vigil.scenes_seen.append("opening")
	next._transitions.instant = false
	next._new_run()
	_check(fails, next._route_screen is DepartureStaging,
		"run 2 did not fire departure staging")
	_check(fails, not (next._route_screen is ScenePlayer),
		"run 2 replayed the opening")
	_dispose(next)


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


static func _lamplighter_pre_once(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	for meeting: int in range(5):
		var scene_id: String = "lamplighter-m%d-pre" % (meeting + 1)
		var main: Main = _hollow(content, meeting, false)
		main._show_hollow()
		_wake(main)
		_check(fails, main._route_screen is ScenePlayer,
			"%s did not play before HollowScreen" % scene_id)
		if main._route_screen is ScenePlayer:
			_check(fails, (main._route_screen as ScenePlayer)._script.id == scene_id,
				"%s played a different scene" % scene_id)
		_check(fails, typeof(main.game.run.pending_scene) == TYPE_DICTIONARY
				and str(main.game.run.pending_scene.get("id", "")) == scene_id,
			"%s did not persist a run-side cursor" % scene_id)
		_drive(main)
		_check(fails, main._vigil.scenes_seen.has(scene_id),
			"finishing %s did not mark scenes_seen" % scene_id)
		_check(fails, main._route_screen is HollowScreen,
			"finishing %s did not hand off to HollowScreen" % scene_id)
		var seen: Array[String] = main._vigil.scenes_seen.duplicate()
		_dispose(main)
		var again: Main = _hollow(content, meeting, false)
		again._vigil.scenes_seen = seen
		again._show_hollow()
		_check(fails, again._route_screen is HollowScreen
				and not (again._route_screen is ScenePlayer),
			"%s fired a second time" % scene_id)
		_dispose(again)


static func _lamplighter_pre_resume(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var producer: Main = _hollow(content, 0, false)
	producer._show_hollow()
	_wake(producer)
	var player: ScenePlayer = producer._route_screen as ScenePlayer
	_check(fails, player != null, "pre resume producer did not open m1-pre")
	if player != null:
		player._process(0.016)
	var loaded: RunState = SaveService.load_run(content, RUN_PATH)
	_dispose(producer)
	_check(fails, loaded != null and typeof(loaded.pending_scene) == TYPE_DICTIONARY
			and str(loaded.pending_scene.get("id", "")) == "lamplighter-m1-pre"
			and int(float(str(loaded.pending_scene.get("cursor", -1)))) == 1,
		"an interrupted m1-pre did not persist cursor 1")
	var resumed: Main = _main(content)
	resumed._vigil.scenes_seen.append("opening")
	resumed._continue_run(loaded)
	_wake(resumed)
	var again: ScenePlayer = resumed._route_screen as ScenePlayer
	_check(fails, again != null, "resume did not restore the m1-pre ScenePlayer")
	if again != null:
		var line: Label = again.find_child("Line", true, false) as Label
		_check(fails, line != null
				and line.text == Locale.active.t("story.lamplighter-m1.pre.l2"),
			"resume replayed m1-pre from line 0 instead of the owed line")
	_dispose(resumed)


static func _lamplighter_leave_skips_post(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _hollow(content, 0, false)
	main._show_hollow()
	_drive(main)
	_check(fails, main._route_screen is HollowScreen, "leave producer did not reach HollowScreen")
	main._on_hollow_choice("leave")
	_check(fails, not (main._route_screen is ScenePlayer),
		"leaving unpaid played a post scene")
	_check(fails, not main._vigil.scenes_seen.has("lamplighter-m1-post"),
		"leaving unpaid marked the post as seen")
	_dispose(main)


static func _lamplighter_cannot_skips_post(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _hollow(content, 1, false)
	main._vigil.scenes_seen.append("lamplighter-m2-pre")
	main.game.run.player.gold = 0
	main._show_hollow()
	_check(fails, main._route_screen is HollowScreen, "cannot producer did not open HollowScreen")
	main._on_hollow_choice("pay")
	_check(fails, main._route_screen is HollowScreen
			and not (main._route_screen as HollowScreen)._error.text.is_empty(),
		"cannot did not stay a HollowScreen error")
	_check(fails, not (main._route_screen is ScenePlayer),
		"cannot played a scene")
	_check(fails, not main._vigil.scenes_seen.has("lamplighter-m2-post"),
		"cannot marked the post as seen")
	_dispose(main)


static func _lamplighter_post_once(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _hollow(content, 0, false)
	main._vigil.scenes_seen.append("lamplighter-m1-pre")
	main._show_hollow()
	_check(fails, main._route_screen is HollowScreen, "post producer skipped HollowScreen")
	main._on_hollow_choice("pay")
	_check(fails, main._route_screen is HollowScreen
			and str(main.game.run.pending_hollow.get("paid", false)) == "true",
		"paying did not return to the paid HollowScreen")
	main._on_hollow_choice("continue")
	_wake(main)
	_check(fails, main._route_screen is ScenePlayer,
		"continue after pay did not play m1-post")
	if main._route_screen is ScenePlayer:
		_check(fails, (main._route_screen as ScenePlayer)._script.id == "lamplighter-m1-post",
			"continue after pay played a scene other than m1-post")
	_check(fails, typeof(main.game.run.pending_scene) == TYPE_DICTIONARY
			and str(main.game.run.pending_scene.get("id", "")) == "lamplighter-m1-post",
		"m1-post did not persist a run-side cursor")
	_drive(main)
	_check(fails, main._vigil.scenes_seen.has("lamplighter-m1-post"),
		"finishing m1-post did not mark scenes_seen")
	var persisted: VigilState = SaveService.load_vigil(VIGIL_PATH)
	_check(fails, persisted.scenes_seen.has("lamplighter-m1-post"),
		"finishing m1-post did not persist scenes_seen to disk")
	_check(fails, not (main._route_screen is ScenePlayer),
		"finishing m1-post did not hand off to the held destination")
	var seen: Array[String] = main._vigil.scenes_seen.duplicate()
	_dispose(main)
	var again: Main = _hollow(content, 0, true)
	again._vigil.scenes_seen = seen
	again._on_hollow_choice("continue")
	_check(fails, not (again._route_screen is ScenePlayer),
		"m1-post fired a second time")
	_dispose(again)


static func _lamplighter_post_resume(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var producer: Main = _hollow(content, 0, true)
	producer._vigil.scenes_seen.append("lamplighter-m1-pre")
	producer._on_hollow_choice("continue")
	_wake(producer)
	var player: ScenePlayer = producer._route_screen as ScenePlayer
	_check(fails, player != null, "post resume producer did not open m1-post")
	if player != null:
		player._process(0.016)
	var loaded: RunState = SaveService.load_run(content, RUN_PATH)
	_dispose(producer)
	_check(fails, loaded != null and typeof(loaded.pending_scene) == TYPE_DICTIONARY
			and str(loaded.pending_scene.get("id", "")) == "lamplighter-m1-post"
			and int(float(str(loaded.pending_scene.get("cursor", -1)))) == 1,
		"an interrupted m1-post did not persist cursor 1")
	var resumed: Main = _main(content)
	resumed._vigil.scenes_seen.append("opening")
	resumed._vigil.scenes_seen.append("lamplighter-m1-pre")
	resumed._continue_run(loaded)
	_wake(resumed)
	var again: ScenePlayer = resumed._route_screen as ScenePlayer
	_check(fails, again != null, "resume did not restore the m1-post ScenePlayer")
	if again != null:
		var line: Label = again.find_child("Line", true, false) as Label
		_check(fails, line != null
				and line.text == Locale.active.t("story.lamplighter-m1.post.l2"),
			"resume replayed m1-post from line 0 instead of the owed line")
	_dispose(resumed)


static func _lamplighter_does_not_inflate_unlocks(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _hollow(content, 0, false)
	var before: int = main._vigil.unlocks.size()
	main._show_hollow()
	_drive(main)
	main._on_hollow_choice("pay")
	main._on_hollow_choice("continue")
	_drive(main)
	_check(fails, main._vigil.unlocks.size() == before,
		"lamplighter scenes wrote into unlocks")
	_check(fails, not main._vigil.unlocks.has("lamplighter-m1-pre")
			and not main._vigil.unlocks.has("lamplighter-m1-post"),
		"lamplighter scene ids landed in unlocks")
	_dispose(main)


static func _hollow(content: ContentDB, meeting: int, paid: bool) -> Main:
	var main: Main = _main(content)
	main._vigil.scenes_seen.append("opening")
	var run: RunState = RunState.new_run(content, 32801 + meeting, "run-lamp-%d" % meeting)
	run.quests["hollowLamplighter"] = {
		"state": "armed", "progress": meeting, "memory": {},
	}
	var walk: WorldMap = WorldMap.slice()
	walk.at = 3
	walk.nodes[3].type = "rest"
	run.node_id = walk.nodes[3].id
	run.map = walk.to_dict()
	run.pending_hollow = {
		"nodeId": walk.nodes[3].id, "type": "rest", "meeting": meeting,
		"paid": paid, "deferred": false, "answer": "",
	}
	main.game = GlassvowGame.new(content, run)
	main._map = walk
	return main


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
