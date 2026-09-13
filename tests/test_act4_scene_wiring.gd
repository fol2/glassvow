extends RefCounted
## #312: the Act IV interstitials and the finale swap ride the scene player.
## Crossing beat at the act turn, arrival beats once per Vigil, the walk-line
## grammar break, and the win / repeat-win / loss scene chains.

const RUN_PATH: String = "user://test_act4_wiring_run_v2.json"
const VIGIL_PATH: String = "user://test_act4_wiring_vigil_v2.json"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("act4_wiring: %s" % what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	_crossing_first_and_repeat(fails, content)
	_arrival_fronts_the_fight(fails, content)
	_arrival_once_per_vigil(fails, content)
	_walk_line_owes_the_hand(fails)
	_walk_forms(fails)
	_finale_win_chain(fails, content)
	_repeat_win_short_close(fails, content)
	_finale_loss_epitaph(fails, content)
	_clear_matrix(fails, content)
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)


## The Act III boss-relic turn queues act4-entry once; a Vigil that has seen
## it crosses on unsealing-short instead, ungated — the ceremony repeats.
static func _crossing_first_and_repeat(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _act4_main(content, 2, -1)
	main._on_boss_relic_chosen("")
	_wake(main)
	_check(fails, main.game.run.act == 3 and main.game.run.is_final_act(),
		"the relic turn did not enter the final act")
	_check(fails, _playing(main, "act4-entry"),
		"the first crossing did not play act4-entry")
	_drive(main)
	_check(fails, main._vigil.scenes_seen.has("act4-entry"),
		"finishing act4-entry did not mark scenes_seen")
	_check(fails, main._map_screen is WorldMapScreen,
		"act4-entry did not hand off to the Act IV map")
	_dispose(main)
	var again: Main = _act4_main(content, 2, -1)
	again._vigil.scenes_seen.append("act4-entry")
	again._vigil.scenes_seen.append("unsealing-short")
	again._on_boss_relic_chosen("")
	_wake(again)
	_check(fails, _playing(again, "unsealing-short"),
		"a repeat crossing did not play unsealing-short")
	_dispose(again)


## A first arrival at an Act IV waystone fronts the node with its interstitial
## and arms the fight in the same store, so a kill mid-scene owes the fight.
static func _arrival_fronts_the_fight(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _act4_main(content, 3, 0)
	main._enter_chosen_node(main._map.nodes[0])
	_wake(main)
	_check(fails, _playing(main, "act4-node1"),
		"arriving at n0 did not play act4-node1")
	_check(fails, str(main.game.run.pending_combat) == "monster"
			and typeof(main.game.run.pending_enemy_ids) == TYPE_ARRAY,
		"the n0 interstitial did not arm the fight in the same store")
	var disk: RunState = SaveService.load_run(content, RUN_PATH)
	_check(fails, disk != null and typeof(disk.pending_scene) == TYPE_DICTIONARY
			and str(disk.pending_scene.get("id", "")) == "act4-node1"
			and disk.pending_combat != null,
		"the armed arrival did not persist scene and fight together")
	_drive(main)
	_check(fails, main._screen is CombatScreen,
		"finishing act4-node1 did not resume into the owed fight")
	_check(fails, main._vigil.scenes_seen.has("act4-node1"),
		"finishing act4-node1 did not mark scenes_seen")
	_dispose(main)


static func _arrival_once_per_vigil(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _act4_main(content, 3, 3)
	_check(fails, main._act4_arrival_scene(main._map.nodes[3]) == "act4-node4",
		"the rest waystone did not name act4-node4")
	main._vigil.scenes_seen.append("act4-node4")
	_check(fails, main._act4_arrival_scene(main._map.nodes[3]).is_empty(),
		"a seen interstitial fired a second time")
	main.game.run.act = 2
	_check(fails, main._act4_arrival_scene(main._map.nodes[3]).is_empty(),
		"an Act III arrival claimed an Act IV interstitial")
	_dispose(main)


## The grammar break (07-scenes §5): a walk line never advances on the dwell
## and skip cannot arm across it; instant mode (captures, headless) keeps the
## shared grammar so full-run drives still finish.
static func _walk_line_owes_the_hand(fails: Array[String]) -> void:
	var finale: SceneScript = _script("finale")
	if finale == null:
		_check(fails, false, "finale did not load")
		return
	var walk_at: int = _first_walk_cursor(finale)
	_check(fails, walk_at >= 0, "finale carries no walk line")
	if walk_at < 0:
		return
	var asked: Array[int] = [0]
	var player: ScenePlayer = ScenePlayer.new(finale, walk_at)
	player.advance_requested.connect(func() -> void: asked[0] += 1)
	player._ready()
	player._process(ScenePlayer.REVEAL_TIME + 0.01)
	player._process(60.0)
	_check(fails, asked[0] == 0, "a walk line advanced on its own dwell")
	_check(fails, FinaleStaging.form == FinaleStaging.FORM_HOLD,
		"the shipped walk form is not the signed FORM_HOLD")
	player._press(true)
	player._process(ScenePlayer.SKIP_HOLD * 3.0)
	_check(fails, not player._skipping, "skip armed on a walk line")
	_check(fails, asked[0] == 1, "a filled hold on the walk line did not step")
	player._press(false)
	var caption: Label = player.find_child("Caption", true, false) as Label
	_check(fails, caption != null
			and caption.text == Locale.active.t("ui.map.openDoor.hold"),
		"the walk line does not name its input form")
	player.free()
	var instant_asked: Array[int] = [0]
	var still: ScenePlayer = ScenePlayer.new(finale, walk_at)
	still.instant = true
	still.advance_requested.connect(func() -> void: instant_asked[0] += 1)
	still._ready()
	still._process(0.016)
	_check(fails, instant_asked[0] == 1, "instant mode stalled on the walk line")
	still.free()


## The unshipped FORM_STEP stays a working dev capture switch (#312: James
## picked FORM_HOLD off the renders; hold semantics live in the default test).
static func _walk_forms(fails: Array[String]) -> void:
	var finale: SceneScript = _script("finale")
	var walk_at: int = _first_walk_cursor(finale)
	if walk_at < 0:
		return
	FinaleStaging.form = FinaleStaging.FORM_STEP
	var asked: Array[int] = [0]
	var player: ScenePlayer = ScenePlayer.new(finale, walk_at)
	player.advance_requested.connect(func() -> void: asked[0] += 1)
	player._ready()
	player._process(ScenePlayer.REVEAL_TIME + 0.01)
	player._press(true)
	player._process(FinaleStaging.HOLD_TIME + 0.5)
	_check(fails, asked[0] == 0, "FORM_STEP stepped on the hold, not the tap")
	player._press(false)
	_check(fails, asked[0] == 1, "FORM_STEP did not step on the tap")
	var pips: FinaleStaging = player.find_child("FinaleWalk", true, false) as FinaleStaging
	_check(fails, pips != null and pips.visible, "the walk overlay is not staged")
	player.free()
	FinaleStaging.form = FinaleStaging.FORM_HOLD


## First win at the swap: the full segment plays, chains into the ascended
## close, and only then reaches the terminal commit (Dawn, per the win flow).
static func _finale_win_chain(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _boss_main(content)
	main._on_combat_over("win")
	_wake(main)
	_check(fails, _playing(main, "finale"),
		"a first Keeper win did not play the swap segment")
	_check(fails, main.game.run.unlocks.has(RunState.MIRRORED_ROAD),
		"the win did not mark the Mirrored Road cleared")
	_drive(main)
	_check(fails, main._vigil.scenes_seen.has("finale")
			and main._vigil.scenes_seen.has("finale-win"),
		"the win chain did not play both finale and finale-win")
	_check(fails, main._route_screen is DawnScreen,
		"the ascended close did not hand off to the win commit")
	_dispose(main)


static func _repeat_win_short_close(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _boss_main(content)
	main._vigil.scenes_seen.append("finale")
	main._on_combat_over("win")
	_wake(main)
	_check(fails, _playing(main, "finale-win"),
		"a repeat win did not go straight to the short close")
	_drive(main)
	_check(fails, not main._vigil.scenes_seen.has("finale-loss"),
		"a repeat win touched the loss epitaph")
	_check(fails, main._route_screen is DawnScreen,
		"the repeat close did not hand off to the win commit")
	_dispose(main)


static func _finale_loss_epitaph(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _boss_main(content)
	main._vigil.scenes_seen.append("finale-loss")
	main._on_combat_over("lose")
	_wake(main)
	_check(fails, _playing(main, "finale-loss"),
		"a fall at the swap did not play the finale epitaph (or played it once-only)")
	_drive(main)
	_check(fails, main._route_screen is RunEndScreen,
		"the epitaph did not hand off to RunEndScreen")
	_check(fails, main.game.run.pending_run_end != null
			and str(main.game.run.pending_run_end.get("outcome", "")) == "death",
		"the loss outcome was rewritten by the scene")
	_dispose(main)


static func _playing(main: Main, scene_id: String) -> bool:
	var player: ScenePlayer = main._route_screen as ScenePlayer
	return player != null and player._script.id == scene_id


static func _script(scene_id: String) -> SceneScript:
	var loaded: Variant = SceneScript.load_all()
	if typeof(loaded) != TYPE_DICTIONARY:
		return null
	var scenes: Dictionary = loaded
	var found: Variant = scenes.get(scene_id)
	if found is SceneScript:
		return found
	return null


static func _first_walk_cursor(finale: SceneScript) -> int:
	if finale == null:
		return -1
	for i: int in range(finale.line_count()):
		if FinaleStaging.walk_key(str(finale.lines[i]["key"])):
			return i
	return -1


static func _act4_main(content: ContentDB, act: int, at: int) -> Main:
	var main: Main = _main(content)
	var run: RunState = _shard_run(content, act)
	var map: WorldMap = WorldMap.for_run(run, content)
	map.at = at
	if at >= 0:
		run.node_id = map.nodes[at].id
	run.map = map.to_dict()
	main.game = GlassvowGame.new(content, run)
	main._map = map
	return main


static func _boss_main(content: ContentDB) -> Main:
	var main: Main = _act4_main(content, 3, 4)
	main.game.cb = CombatState.new()
	main.game.cb.finale_handoff = true
	main.game.run.pending_combat = "boss"
	main.game.run.pending_enemy_ids = ["eternalKeeper"]
	return main


static func _shard_run(content: ContentDB, act: int) -> RunState:
	var vigil: VigilState = VigilState.blank()
	for id: String in VigilState.QUEST_IDS:
		vigil.quests[id]["state"] = "complete"
		vigil.shards.append(id)
	var run: RunState = RunState.new_run(content, 31200, "run-312", {
		"quests": vigil.quests.duplicate(true),
		"shards": vigil.shards.duplicate(),
	})
	run.act = act
	return run


static func _wake(main: Main) -> void:
	var player: ScenePlayer = main._route_screen as ScenePlayer
	if player != null and player._beat == ScenePlayer.BEAT_IDLE and not player._done:
		player._ready()


## Wakes each frame: a chained scene (finale → finale-win) arrives as a new
## ScenePlayer whose _ready never fires outside the tree.
static func _drive(main: Main) -> void:
	var steps: int = 0
	while main._route_screen is ScenePlayer and steps < 32:
		_wake(main)
		(main._route_screen as ScenePlayer)._process(0.016)
		steps += 1


static func _main(content: ContentDB) -> Main:
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)
	var main: Main = Main.new()
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main.content = content
	main._run_save_path = RUN_PATH
	main._vigil_save_path = VIGIL_PATH
	main._vigil = VigilState.blank()
	main._vigil.scenes_seen.append("opening")
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


static func _clear_matrix(fails: Array[String], content: ContentDB) -> void:
	_f6_act3_boss_win(fails, content)
	_act4_victory_grants_once(fails, content)
	_non_granting_terminals(fails, content)
	_six_shards_and_entry_do_not_grant(fails, content)
	_clear_bit_persists(fails, content)
	_cross_run_beats_stay_distinct(fails, content)


static func _f6_act3_boss_win(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _act3_boss_main(content)
	_check(fails, main.game.run.act == 2 and main.game.run.is_final_act()
			and main.game.run.shards.size() < 6,
		"Act III fixture was not a <6-shard final act")
	main._on_combat_over("win")
	_check(fails, not main.game.run.unlocks.has(RunState.MIRRORED_ROAD)
			and not main._vigil.unlocks.has(RunState.MIRRORED_ROAD),
		"F6 Act III win granted mirroredRoad")
	_check(fails, main.game.run.pending_dawn != null or main._route_screen is DawnScreen
			or main.game.run.pending_run_end != null,
		"Act III boss win did not take the ordinary terminal-win path")
	_dispose(main)


static func _act4_victory_grants_once(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _boss_main(content)
	main._on_combat_over("win")
	_check(fails, main.game.run.unlocks.has(RunState.MIRRORED_ROAD),
		"genuine Act IV victory did not grant mirroredRoad")
	main.game.run.mark_mirrored_road_cleared()
	_check(fails, main.game.run.unlocks.count(RunState.MIRRORED_ROAD) == 1,
		"Act IV clear bit was granted twice")
	_dispose(main)


static func _non_granting_terminals(fails: Array[String], content: ContentDB) -> void:
	var death: Main = _act3_boss_main(content)
	death._on_combat_over("lose")
	_check(fails, not death.game.run.unlocks.has(RunState.MIRRORED_ROAD)
			and not death._vigil.unlocks.has(RunState.MIRRORED_ROAD)
			and death.game.run.pending_run_end != null
			and str(death.game.run.pending_run_end.get("outcome", "")) == "death",
		"Act III boss death granted mirroredRoad")
	_dispose(death)
	var act4_death: Main = _boss_main(content)
	act4_death._on_combat_over("lose")
	_check(fails, not act4_death.game.run.unlocks.has(RunState.MIRRORED_ROAD),
		"Act IV boss death granted mirroredRoad")
	_dispose(act4_death)
	var abandon: Main = _act3_boss_main(content)
	abandon._on_abandon_choice("yes")
	_check(fails, not abandon.game.run.unlocks.has(RunState.MIRRORED_ROAD)
			and not abandon._vigil.unlocks.has(RunState.MIRRORED_ROAD)
			and abandon.game.run.pending_run_end != null
			and str(abandon.game.run.pending_run_end.get("outcome", "")) == "abandon",
		"abandon granted mirroredRoad")
	_dispose(abandon)
	var non_boss: Main = _act3_node_main(content, "monster", ["duskfang"], "monster")
	non_boss.game.cb = CombatState.new()
	non_boss._on_combat_over("win")
	_check(fails, not non_boss.game.run.unlocks.has(RunState.MIRRORED_ROAD),
		"non-boss win granted mirroredRoad")
	_dispose(non_boss)


static func _six_shards_and_entry_do_not_grant(fails: Array[String], content: ContentDB) -> void:
	var shards_only: RunState = _shard_run(content, 0)
	_check(fails, shards_only.shards.size() == 6 and shards_only.final_act() == 3
			and not shards_only.unlocks.has(RunState.MIRRORED_ROAD),
		"accelerated six-shard fixture itself granted mirroredRoad")
	shards_only.mark_mirrored_road_cleared()
	_check(fails, not shards_only.unlocks.has(RunState.MIRRORED_ROAD),
		"six shards alone marked mirroredRoad")
	var entry: Main = _act4_main(content, 2, -1)
	entry._on_boss_relic_chosen("")
	_wake(entry)
	_check(fails, entry.game.run.act == 3 and entry.game.run.is_final_act()
			and not entry.game.run.unlocks.has(RunState.MIRRORED_ROAD)
			and not entry._vigil.unlocks.has(RunState.MIRRORED_ROAD),
		"Act IV entry granted mirroredRoad")
	_dispose(entry)


static func _clear_bit_persists(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _boss_main(content)
	main._on_combat_over("win")
	_check(fails, main.game.run.unlocks.has(RunState.MIRRORED_ROAD),
		"Act IV win did not mark the run before save")
	var disk: RunState = SaveService.load_run(content, RUN_PATH)
	_check(fails, disk != null and disk.unlocks.has(RunState.MIRRORED_ROAD),
		"mirroredRoad did not persist through the terminal run save")
	var vigil: VigilState = VigilState.blank()
	for unlock_v: Variant in disk.unlocks:
		var unlock: String = str(unlock_v)
		if not vigil.unlocks.has(unlock):
			vigil.unlocks.append(unlock)
	SaveService.store_vigil(vigil, VIGIL_PATH)
	var loaded_vigil: VigilState = SaveService.load_vigil(VIGIL_PATH)
	_check(fails, loaded_vigil != null and loaded_vigil.unlocks.has(RunState.MIRRORED_ROAD),
		"mirroredRoad did not persist through vigil save/reload")
	_dispose(main)


static func _cross_run_beats_stay_distinct(fails: Array[String], content: ContentDB) -> void:
	var eighth: RunState = RunState.new_run(content, 55120, "run-551-eighth-beat", {
		"quests": _armed_eighth_quests(),
	})
	eighth.act = QuestRules.EMBERGLASS_ACT
	eighth.quest_scratch["eighthOmen"] = {"active": true}
	var boss: CombatState = CombatState.new()
	boss.kind = &"boss"
	QuestRules.new(content).on_combat_win(eighth, boss)
	_check(fails, str(eighth.quests["eighthOmen"].get("state", "")) == "complete"
			and not eighth.unlocks.has(RunState.MIRRORED_ROAD),
		"Eighth completion on the Act III boss was not distinct from the clear bit")
	var vigil: VigilState = VigilState.blank()
	for id: String in VigilState.QUEST_IDS:
		vigil.quests[id]["state"] = "complete"
		vigil.shards.append(id)
	var folding: RunState = RunState.new_run(content, 55121, "run-551-final-shard", {
		"quests": vigil.quests.duplicate(true),
		"shards": vigil.shards.duplicate(),
	})
	folding.act = QuestRules.EMBERGLASS_ACT
	_check(fails, vigil.commit_run(folding, "win", content)
			and vigil.shards.size() == 6
			and vigil.unlocks.has("act4")
			and not vigil.unlocks.has(RunState.MIRRORED_ROAD),
		"final-shard terminal fold was not distinct from an Act IV clear")
	var next: Main = _act4_main(content, 2, -1)
	next._vigil.shards = vigil.shards.duplicate()
	next._vigil.unlocks = vigil.unlocks.duplicate()
	next._on_boss_relic_chosen("")
	_wake(next)
	_check(fails, next.game.run.act == 3 and next.game.run.is_final_act()
			and not next.game.run.unlocks.has(RunState.MIRRORED_ROAD),
		"next-run Act IV entry was not distinct from an Act IV clear")
	_dispose(next)
	var clear: Main = _boss_main(content)
	clear._on_combat_over("win")
	_check(fails, clear.game.run.unlocks.has(RunState.MIRRORED_ROAD),
		"actual Act IV clear did not grant the bit")
	_dispose(clear)


static func _armed_eighth_quests() -> Dictionary:
	var quests: Dictionary = {}
	for id: String in VigilState.QUEST_IDS:
		quests[id] = {"state": "dormant", "progress": 0, "memory": {}}
	quests["eighthOmen"] = {
		"state": "armed", "progress": 0, "memory": {"dueIn": 1},
	}
	return quests


static func _act3_boss_main(content: ContentDB) -> Main:
	return _act3_node_main(content, "boss", ["sovereign"], "boss")


static func _act3_node_main(
	content: ContentDB, type_key: String, enemies: Array[String], pending: String
) -> Main:
	var main: Main = _main(content)
	var run: RunState = RunState.new_run(content, 55106, "run-551-act3")
	run.act = 2
	var map: WorldMap = WorldMap.new()
	map.nodes.append(MapNode.make(type_key, enemies, 0))
	map.at = 0
	run.node_id = map.nodes[0].id
	run.map = map.to_dict()
	run.pending_combat = pending
	run.pending_enemy_ids = enemies.duplicate()
	main.game = GlassvowGame.new(content, run)
	main._map = map
	main.game.cb = CombatState.new()
	main.game.cb.kind = StringName(pending)
	return main
