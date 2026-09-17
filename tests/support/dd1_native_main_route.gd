extends RefCounted
## Narrow Main/application driver for DD1-NATIVE-1 pending resume and
## explicitly invoked ordinary-route acquisition. Not a second campaign.
## Routine regression must not call drive_ordinary unless launch is permitted.


const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const QUAL: String = "res://research/p9-six-route/dusk-design-1-20260916/native-qualification"
const LAUNCH_PERMITTED_PATH: String = QUAL + "/LAUNCH-PERMITTED.json"
const TURN_CAP: int = 30
const STEP_CAP: int = 240


static func acquire_requested() -> bool:
	return OS.get_environment("DD1_NATIVE_ACQUIRE") == "1"


static func launch_permitted() -> bool:
	return FileAccess.file_exists(LAUNCH_PERMITTED_PATH)


static func make_main(content: ContentDB, run_path: String, vigil_path: String) -> Main:
	var main: Main = Main.new()
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main.content = content
	main._run_save_path = run_path
	main._vigil_save_path = vigil_path
	main._vigil = VigilState.blank()
	main._opening_suppressed = true
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	return main


static func dispose(main: Main) -> void:
	main._clear_route()
	for child: Node in main.get_children():
		child.free()
	main.free()


static func resume_pending(content: ContentDB, loaded: RunState, run_path: String, vigil_path: String) -> Main:
	var main: Main = make_main(content, run_path, vigil_path)
	main._continue_run(loaded)
	return main


## Ordinary-route campaign through Main choice/combat/terminal seams.
## A turn/action cap is INCOMPLETE, never a fabricated death.
## Terminal win/death only via Main._on_combat_over and _on_terminal_commit.
static func drive_ordinary(
	content: ContentDB,
	vigil: VigilState,
	seed: int,
	vow: int,
	run_path: String,
	vigil_path: String
) -> Dictionary:
	SaveService.clear(run_path)
	SaveService.clear_vigil(vigil_path)
	var main: Main = make_main(content, run_path, vigil_path)
	main._vigil = vigil
	main._forced_seed = seed
	main._new_run({"aspect": 0, "vow": vow})
	var starts: int = 0
	var status: String = "INCOMPLETE"
	var steps: int = 0
	while steps < STEP_CAP:
		steps += 1
		if main.game == null or main.game.run == null:
			break
		if main.game.run.pending_run_end != null:
			var pending: Dictionary = main.game.run.pending_run_end
			status = str(pending.get("outcome", "INCOMPLETE"))
			main._on_terminal_commit("ok")
			break
		if main.game.cb != null and main.game.cb.over:
			var result: String = str(main.game.cb.result)
			main._on_combat_over(result)
			continue
		if main.game.cb != null and not main.game.cb.over:
			if main.game.cb.turn >= TURN_CAP:
				status = "INCOMPLETE"
				break
			Pilot.play_turn(main.game)
			if main.game.cb != null and not main.game.cb.over:
				main.game.apply({"t": "endTurn"})
			continue
		if main.game.run.pending_reward != null:
			main._on_reward_claimed(&"gold", "")
			main._on_reward_finished()
			continue
		if main._has_pending_boss_relic():
			main._on_boss_relic_chosen("")
			continue
		if main.game.run.pending_combat != null:
			if main._screen == null or main.game.cb == null:
				main._resume_pending_combat()
				starts += 1
			continue
		if main._map == null:
			break
		var node: MapNode = main._map.current()
		if node != null and not main._map.is_cleared(main._map.at):
			if not _resolve_current_safe(main, node):
				status = "INCOMPLETE"
				break
			continue
		if main._map.is_finished():
			status = "INCOMPLETE"
			break
		var reachable: Array[int] = main._map.reachable()
		if reachable.is_empty():
			status = "INCOMPLETE"
			break
		var pick: int = Pilot.choose_node(main._map, main.game.run)
		if pick < 0 or not reachable.has(pick):
			pick = reachable[0]
		main._on_node_chosen(pick)
		if main.game != null and main.game.cb != null:
			starts += 1
	var shatters: int = 0
	if main.game != null and main.game.run != null:
		shatters = int(float(str(main.game.run.stats.get("shatters", 0))))
	dispose(main)
	return {
		"status": status,
		"starts": starts,
		"shatters": shatters,
		"steps": steps,
	}


static func _resolve_current_safe(main: Main, node: MapNode) -> bool:
	match node.type:
		"monster", "elite", "boss":
			if main.game.run.pending_combat == null:
				main._prepare_encounter(node)
			return true
		"rest":
			main._on_rest_choice("heal")
			return true
		"shop":
			main._on_shop_choice("leave")
			return true
		"treasure":
			main._finish_node()
			return true
		"event":
			var event_id: String = str(main.game.run.quest_scratch.get("eventNode", ""))
			if event_id.is_empty():
				return false
			main._on_event_choice("0", event_id)
			if main.game.run.quest_scratch.has("eventPending"):
				var pending_v: Variant = main.game.run.quest_scratch.get("eventPending")
				if typeof(pending_v) == TYPE_DICTIONARY:
					var pending: Dictionary = pending_v
					var kind: String = str(pending.get("kind", ""))
					if kind == "card":
						var cards: Array = pending.get("cards", [])
						if cards.is_empty():
							return false
						main._on_event_pick(str(cards[0]), kind)
					else:
						return false
			if typeof(main.game.run.quest_scratch.get("eventStory")) == TYPE_DICTIONARY:
				main._on_event_story_continue()
				if typeof(main.game.run.quest_scratch.get("eventStory")) == TYPE_DICTIONARY:
					main._on_event_story_continue()
			return true
		_:
			main._finish_node()
			return true
