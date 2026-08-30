extends RefCounted
## #321: six state-triggered first-run hints. Records live on Vigil
## `hints_seen`, never `unlocks`. Gated on opening completion and story flow.

const RUN_PATH: String = "user://test_hint_system_run_v2.json"
const VIGIL_PATH: String = "user://test_hint_system_vigil_v2.json"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("hint_system: %s" % what)


static func run(fails: Array[String]) -> void:
	var default_run: Variant = _file_snapshot(SaveService.RUN_PATH)
	var default_vigil: Variant = _file_snapshot(SaveService.VIGIL_PATH)
	_map_select_not_before_opening(fails)
	_map_select_fires_and_flush(fails)
	_combat_states(fails)
	_guidance_skipped_is_silent(fails)
	_dev_and_scenario_silent(fails)
	_skip_from_first_hint(fails)
	_dismiss_retry_holds_vigil(fails)
	if _file_snapshot(SaveService.RUN_PATH) != default_run \
			or _file_snapshot(SaveService.VIGIL_PATH) != default_vigil:
		fails.append("hint_system: tests touched the default save")
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)


static func _map_select_not_before_opening(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _main(content)
	main._forced_seed = 32101
	main._new_run()
	_check(fails, not (main._map_screen is WorldMapScreen)
			or main._hints.showing().is_empty(),
		"a hint fired before the opening completed")
	_check(fails, main._vigil.hints_seen.is_empty(),
		"hints_seen was written before the opening")
	_dispose(main)


static func _map_select_fires_and_flush(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _opened(content, 32102)
	_check(fails, main._hints.showing() == HintGuide.MAP_SELECT,
		"map-select did not fire on the first interactive map")
	_check(fails, main._map_screen != null and not main._map_screen._hint_label.visible,
		"survey label did not retire when H1 landed")
	_check(fails, main._hints.overlay._skip.visible,
		"the first hint did not carry skip-guidance")
	var before: int = main._vigil.unlocks.size()
	var live: Array[int] = main._map.reachable()
	_check(fails, not live.is_empty(), "fresh map has no reachable node")
	if not live.is_empty():
		# Quarantine the route so the pick cannot fall into `_prepare_encounter`,
		# which stores the run on the default path. before_pick still records.
		main._route_checkpoint_quarantined = true
		main._map_screen.instant = true
		main._map_screen.choose(live[0])
	_check(fails, main._vigil.hints_seen.has(HintGuide.MAP_SELECT),
		"picking a node did not record hint_map_select")
	_check(fails, main._vigil.unlocks.size() == before,
		"hint dismissal leaked into unlocks")
	var disk: VigilState = SaveService.load_vigil(VIGIL_PATH)
	_check(fails, disk != null and disk.hints_seen.has(HintGuide.MAP_SELECT),
		"hint_map_select was not flushed at dismissal")
	_check(fails, disk.unlocks.size() == before,
		"flushed vigil grew unlocks")
	var crashed: Main = _opened(content, 32103)
	crashed._vigil = SaveService.load_vigil(VIGIL_PATH)
	crashed._hints.hide_callout()
	crashed._show_map()
	_check(fails, crashed._hints.showing().is_empty(),
		"a flushed map-select hint returned after a simulated crash")
	_dispose(main)
	_dispose(crashed)


static func _combat_states(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var one: Main = _opened(content, 32104)
	_fight(one, ["duskfang"])
	_check(fails, one._hints.showing() == HintGuide.DRAG_PLAY,
		"drag-play did not fire on the first dealt hand")
	_check(fails, one._hints.showing() != HintGuide.TARGETING,
		"targeting fired with one living enemy")
	_check(fails, one._hints.showing() != HintGuide.END_TURN,
		"end-turn fired before energy was spent")
	_check(fails, one._hints.showing() != HintGuide.INTENT,
		"intent fired before the second player turn")
	var drag_uid: int = _enemy_card(one)
	if drag_uid >= 0:
		one._screen.request_play(drag_uid, 0)
	_check(fails, one._vigil.hints_seen.has(HintGuide.DRAG_PLAY),
		"playing a card did not dismiss drag-play")
	var disk: VigilState = SaveService.load_vigil(VIGIL_PATH)
	_check(fails, disk != null and disk.hints_seen.has(HintGuide.DRAG_PLAY),
		"drag-play dismiss was not flushed")
	_dispose(one)
	var two: Main = _opened(content, 32105)
	two._vigil.hints_seen.append(HintGuide.DRAG_PLAY)
	_fight(two, ["sporeling", "sporeling"])
	_check(fails, two._hints.showing().is_empty(),
		"drag-play returned after it was recorded")
	var grab_uid: int = _enemy_card(two)
	_check(fails, grab_uid >= 0, "two-foe hand has no enemy-target card")
	if grab_uid >= 0:
		var view: CardView = two._screen._hand.card_view(grab_uid)
		two._hints.on_card_grabbed(two._screen, view)
	_check(fails, two._hints.showing() == HintGuide.TARGETING,
		"targeting did not fire on a 2+ enemy grab")
	if grab_uid >= 0:
		two._screen.request_play(grab_uid, 0)
	_check(fails, two._vigil.hints_seen.has(HintGuide.TARGETING),
		"playing the aimed card did not dismiss targeting")
	_dispose(two)
	var spent: Main = _opened(content, 32106)
	spent._vigil.hints_seen.append(HintGuide.DRAG_PLAY)
	_fight(spent, ["duskfang"])
	spent.game.cb.player.energy = 0
	spent._hints.consider_combat(spent._screen)
	_check(fails, spent._hints.showing() == HintGuide.END_TURN,
		"end-turn did not fire when energy was exhausted")
	spent._screen._on_end_turn_pressed()
	_check(fails, spent._vigil.hints_seen.has(HintGuide.END_TURN),
		"ending the turn did not dismiss end-turn")
	_dispose(spent)
	var second: Main = _opened(content, 32107)
	second._vigil.hints_seen.append(HintGuide.DRAG_PLAY)
	_fight(second, ["duskfang"])
	second._screen._on_end_turn_pressed()
	_check(fails, second.game.cb != null and second.game.cb.turn >= 2,
		"end-turn did not reach turn 2")
	_check(fails, second._hints.showing() == HintGuide.INTENT,
		"intent did not fire on the second player turn")
	_dispose(second)
	var reward: Main = _opened(content, 32108)
	reward.game.run.pending_reward = {
		"rewards": reward.game.gen_combat_rewards("normal", &""),
		"taken": {"gold": false, "card": false, "potion": false, "relic": false},
		"slain_enemy": {},
	}
	reward._show_pending_reward()
	_check(fails, reward._hints.showing() == HintGuide.REWARD,
		"reward did not fire on the first reward screen")
	var default_run: Variant = _file_snapshot(SaveService.RUN_PATH)
	reward._on_reward_claimed(&"gold", "")
	_restore_snapshot(SaveService.RUN_PATH, default_run)
	_check(fails, reward._vigil.hints_seen.has(HintGuide.REWARD),
		"claiming a reward did not dismiss the hint")
	_dispose(reward)


static func _guidance_skipped_is_silent(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _opened(content, 32109)
	main._vigil.guidance_skipped = true
	main._hints.hide_callout()
	main._show_map()
	_check(fails, main._hints.showing().is_empty(),
		"a guidance_skipped profile still saw the map hint")
	_fight(main, ["duskfang"])
	_check(fails, main._hints.showing().is_empty(),
		"a guidance_skipped profile still saw a combat hint")
	_dispose(main)


static func _dev_and_scenario_silent(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var dev: Main = _main(content)
	dev._opening_suppressed = true
	dev._forced_seed = 32110
	dev._vigil.scenes_seen.append("opening")
	dev._new_run()
	_check(fails, dev._hints.showing().is_empty(),
		"a --map-style suppressed boot showed a hint")
	_fight(dev, ["duskfang"])
	_check(fails, dev._hints.showing().is_empty(),
		"a suppressed combat boot showed a hint")
	_dispose(dev)
	var claimed: Main = _main(content)
	claimed._dev_claimed = true
	claimed._forced_seed = 32111
	claimed._vigil.scenes_seen.append("opening")
	claimed._new_run()
	_check(fails, claimed._hints.showing().is_empty(),
		"a Scenario-claimed boot showed a hint")
	_dispose(claimed)
	var kernel: ScenarioKernel = ScenarioKernel.new(
		content, "user://test_hint_scn_run.json",
		"user://test_hint_scn_vigil.json", "user://test_hint_scn_ref.json")
	kernel.clear_profile()
	var ref: ScenarioReference = ScenarioReference.new()
	_check(fails, ref.load_from({
		"id": "custom", "revision": 1, "build": "t", "seed": 32112,
		"locale": "en", "shape": "pad-landscape", "overrides": {},
	}), "default Scenario reference rejected")
	var run: RunState = kernel.construct(ref)
	_check(fails, run != null, "default Scenario construct failed: %s" % kernel.last_error)
	var kvigil: VigilState = SaveService.load_vigil("user://test_hint_scn_vigil.json")
	_check(fails, kvigil != null and not kvigil.scenes_seen.has("opening"),
		"a default Scenario vigil marked the opening seen")
	var review: ScenarioReference = ScenarioReference.new()
	_check(fails, review.load_from({
		"id": "custom", "revision": 1, "build": "t", "seed": 32113,
		"locale": "en", "shape": "pad-landscape",
		"overrides": {"scenes_seen": ["opening"]},
	}), "scenes_seen Scenario override was rejected")
	var reviewed: RunState = kernel.construct(review)
	_check(fails, reviewed != null, "review Scenario construct failed: %s" % kernel.last_error)
	var rvigil: VigilState = SaveService.load_vigil("user://test_hint_scn_vigil.json")
	_check(fails, rvigil != null and rvigil.scenes_seen.has("opening"),
		"the bounded kernel control did not write scenes_seen")
	kernel.clear_profile()
	SaveService.clear("user://test_hint_scn_run.json")
	SaveService.clear_vigil("user://test_hint_scn_vigil.json")
	SaveService.clear("user://test_hint_scn_ref.json")


static func _skip_from_first_hint(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _opened(content, 32114)
	var before: int = main._vigil.unlocks.size()
	main._hints.skip_guidance()
	_check(fails, main._vigil.guidance_skipped, "skip-guidance did not record")
	_check(fails, main._hints.showing().is_empty(),
		"skip-guidance left a hint on screen")
	_check(fails, main._vigil.unlocks.size() == before,
		"skip-guidance leaked into unlocks")
	var disk: VigilState = SaveService.load_vigil(VIGIL_PATH)
	_check(fails, disk != null and disk.guidance_skipped,
		"skip-guidance was not flushed")
	_fight(main, ["duskfang"])
	_check(fails, main._hints.showing().is_empty(),
		"skip-guidance still showed a later hint")
	_dispose(main)


static func _dismiss_retry_holds_vigil(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _opened(content, 32115)
	main._vigil_save_path = "user://__no_such_dir_321__/vigil.json"
	var live: Array[int] = main._map.reachable()
	if not live.is_empty():
		main._map_screen.instant = true
		main._map_screen.choose(live[0])
	_check(fails, main._vigil.hints_seen.has(HintGuide.MAP_SELECT),
		"a failed flush still has to remember the dismissal")
	var before: VigilState = SaveService.load_vigil(VIGIL_PATH)
	_check(fails, before != null and not before.hints_seen.has(HintGuide.MAP_SELECT),
		"a failed Vigil store still wrote hints_seen")
	main._vigil_save_path = VIGIL_PATH
	main._on_save_error_choice("retry")
	var persisted: VigilState = SaveService.load_vigil(VIGIL_PATH)
	_check(fails, persisted != null and persisted.hints_seen.has(HintGuide.MAP_SELECT),
		"Retry dropped the Vigil continuation; the dismissal evaporated")
	_dispose(main)
	SaveService.clear("user://__no_such_dir_321__/vigil.json")


static func _opened(content: ContentDB, seed: int) -> Main:
	var main: Main = _main(content)
	main._forced_seed = seed
	main._vigil.scenes_seen.append("opening")
	main._new_run()
	if main._route_screen is DepartureStaging:
		main._show_map()
	elif main._map_screen == null:
		main._show_map()
	return main


static func _fight(main: Main, ids: Array) -> void:
	var packed: PackedStringArray = PackedStringArray()
	for id_v: Variant in ids:
		packed.append(str(id_v))
	main._clear_route()
	main._screen = CombatScreen.new(main.game, main._shape, 0, main._sfx_bus)
	main._screen.seq.instant = true
	main._screen.hint_guide = main._hints
	main.add_child(main._screen)
	main._screen.start_encounter(packed, "normal", "hint test")


static func _enemy_card(main: Main) -> int:
	if main._screen == null or main.game == null or main.game.cb == null:
		return -1
	for c: CardInst in main.game.cb.hand:
		var d: Dictionary = main.game.rules.card_data(c)
		if str(d.get("target", "")) == "enemy" \
				and main.game.rules.can_play(main.game.run, main.game.cb, c, 0):
			return c.uid
	return -1


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


static func _restore_snapshot(path: String, snap: Variant) -> void:
	if snap == null:
		SaveService.clear(path)
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(str(snap))
		file.close()
