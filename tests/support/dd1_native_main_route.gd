extends RefCounted
## Narrow Main/application driver for DD1-NATIVE-1 pending resume and
## explicitly invoked ordinary-route acquisition. Not a second campaign.
## Routine regression must not call drive_ordinary unless launch is permitted.


const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const Receipt: GDScript = preload("res://tests/support/dd1_native_launch_receipt.gd")
const DriverMain: GDScript = preload("res://tests/support/dd1_native_driver_main.gd")
const QUAL: String = "res://research/p9-six-route/dusk-design-1-20260916/native-qualification"
const RECOVERY: String = QUAL + "/recovery"
const TURN_CAP: int = 30
const STEP_CAP: int = 240
const PILOT_VERSION: String = "p8-d0-v1"


static func acquire_requested() -> bool:
	return OS.get_environment("DD1_NATIVE_ACQUIRE") == "1"


static func launch_permitted() -> bool:
	return Receipt.permitted()


## Returns true when this call actually entered Main._on_combat_over.
## A completed combat is dispatched once: a second poll must not regenerate
## rewards or advance RNG even if the caller passes already_dispatched=false.
static func dispatch_combat_result_once(main: Main, already_dispatched: bool) -> bool:
	if already_dispatched:
		return false
	if main.game == null or main.game.cb == null or not main.game.cb.over:
		return false
	if main.game.run != null and (
			main.game.run.pending_reward != null or main.game.run.pending_run_end != null):
		return false
	main._on_combat_over(str(main.game.cb.result))
	return true


static func bind_unmodified_pilot() -> Dictionary:
	Pilot.set_ban(PackedStringArray())
	Pilot.apply_policy({})
	Pilot.set_modes(false, false)
	return {
		"version": Pilot.VERSION,
		"snapshot": Pilot.policy_snapshot(),
		"random_build": Pilot.random_build,
		"random_play": Pilot.random_play,
	}


static func make_main(content: ContentDB, run_path: String, vigil_path: String) -> Main:
	var main: Main = DriverMain.new()
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


static func make_application_main(content: ContentDB, run_path: String, vigil_path: String) -> Main:
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


static func resume_pending(content: ContentDB, loaded: RunState, run_path: String, vigil_path: String) -> Main:
	var main: Main = make_application_main(content, run_path, vigil_path)
	main._continue_run(loaded)
	return main


static func file_text(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return FileAccess.get_file_as_string(path)


static func archive_bytes(src_path: String, dest_path: String) -> String:
	if not FileAccess.file_exists(src_path):
		return ""
	var raw: String = FileAccess.get_file_as_string(src_path)
	var dest: FileAccess = FileAccess.open(dest_path, FileAccess.WRITE)
	if dest == null:
		return ""
	dest.store_string(raw)
	dest.close()
	return raw.sha256_text()


## Durable P_v row: keep drive_ordinary commands, pre-terminal run bytes,
## initial SHA and post-commit vigil receipts. Status/counts alone are not
## a trace. Do not read post-terminal disk for the run archive.
static func durable_trace_row(
	seed: int,
	vow: int,
	row: Dictionary,
	vigil: VigilState
) -> Dictionary:
	var commands_v: Variant = row.get("commands", [])
	var commands: Array = commands_v if typeof(commands_v) == TYPE_ARRAY else []
	var pre_v: Variant = row.get("pre_terminal_run", "")
	var commit_v: Variant = row.get("commit_vigil", "")
	return {
		"seed": seed,
		"vow": vow,
		"status": row.get("status", ""),
		"starts": row.get("starts", 0),
		"shatters": row.get("shatters", 0),
		"incomplete_reason": row.get("incomplete_reason", ""),
		"run_id": row.get("run_id", ""),
		"run_sha": row.get("run_sha", ""),
		"vigil_sha": row.get("vigil_sha", ""),
		"combat_dispatches": row.get("combat_dispatches", 0),
		"rng_initial": row.get("rng_initial", 0),
		"rng_final": row.get("rng_final", 0),
		"commands": commands,
		"pre_terminal_run": pre_v if typeof(pre_v) == TYPE_STRING else "",
		"initial_run_sha": row.get("initial_run_sha", ""),
		"initial_vigil_sha": row.get("initial_vigil_sha", ""),
		"commit_vigil": commit_v if typeof(commit_v) == TYPE_STRING else "",
		"p0_now": vigil != null and ledger_satisfies_p0(vigil),
		"p5_now": vigil != null and ledger_satisfies_p5(vigil),
		"vow_unlocked": vigil.vow_unlocked if vigil != null else 0,
		"pilot_version": row.get("pilot_version", PILOT_VERSION),
	}


## Archive P_0/P_5 run bytes from the pre-terminal snapshot. Empty
## pre_terminal_run is failure; never fall back to post-terminal disk.
static func archive_profile_run(row: Dictionary, dest_path: String) -> bool:
	var pre_v: Variant = row.get("pre_terminal_run", "")
	if typeof(pre_v) != TYPE_STRING or str(pre_v).is_empty():
		return false
	var dest: FileAccess = FileAccess.open(dest_path, FileAccess.WRITE)
	if dest == null:
		return false
	dest.store_string(str(pre_v))
	dest.close()
	return true


static func write_pv_traces(path: String, payload: Dictionary) -> bool:
	var tf: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if tf == null:
		return false
	tf.store_string(JSON.stringify(payload))
	tf.close()
	return true


## Ordinary-route campaign through Main choice/combat/terminal seams.
## A turn/action cap is INCOMPLETE, never a fabricated death.
## Each completed combat is dispatched through Main._on_combat_over once.
static func drive_ordinary(
	content: ContentDB,
	vigil: VigilState,
	seed: int,
	vow: int,
	run_path: String,
	vigil_path: String
) -> Dictionary:
	bind_unmodified_pilot()
	SaveService.clear(run_path)
	SaveService.clear_vigil(vigil_path)
	var main: Main = make_main(content, run_path, vigil_path)
	main._vigil = vigil
	main._forced_seed = seed
	main._new_run({"aspect": 0, "vow": vow})
	var initial_run: Variant = file_text(run_path)
	var initial_vigil: Variant = file_text(vigil_path)
	var rng_initial: int = 0
	if main.game != null and main.game.run != null:
		rng_initial = main.game.run.rng.get_state()
	var starts: int = 0
	var combat_dispatches: int = 0
	var reward_claims: int = 0
	var status: String = "INCOMPLETE"
	var incomplete_reason: String = "step_cap"
	var steps: int = 0
	var commands: Array = []
	var combat_result_dispatched: bool = false
	while steps < STEP_CAP:
		steps += 1
		if main.game == null or main.game.run == null:
			incomplete_reason = "missing_game"
			break
		if main.game.run.pending_run_end != null:
			var pending: Dictionary = main.game.run.pending_run_end
			status = str(pending.get("outcome", "INCOMPLETE"))
			var pre_terminal: Variant = file_text(run_path)
			var shatters_term: int = 0
			var run_id_term: String = ""
			var rng_final_term: int = rng_initial
			var map_at_term: int = -1
			if main.game != null and main.game.run != null:
				shatters_term = int(float(str(main.game.run.stats.get("shatters", 0))))
				run_id_term = main.game.run.run_id
				rng_final_term = main.game.run.rng.get_state()
			if main._map != null:
				map_at_term = main._map.at
			commands.append({"t": "terminal_commit", "outcome": status})
			main._on_terminal_commit("ok")
			incomplete_reason = ""
			var vigil_after: Variant = file_text(vigil_path)
			dispose(main)
			return {
				"status": status,
				"starts": starts,
				"shatters": shatters_term,
				"steps": steps,
				"combat_dispatches": combat_dispatches,
				"reward_claims": reward_claims,
				"incomplete_reason": "",
				"run_id": run_id_term,
				"seed": seed,
				"vow": vow,
				"rng_initial": rng_initial,
				"rng_final": rng_final_term,
				"map_at": map_at_term,
				"pre_terminal_run": pre_terminal if typeof(pre_terminal) == TYPE_STRING else "",
				"commit_vigil": vigil_after if typeof(vigil_after) == TYPE_STRING else "",
				"initial_run_sha": str(initial_run).sha256_text() if typeof(initial_run) == TYPE_STRING else "",
				"initial_vigil_sha": str(initial_vigil).sha256_text() if typeof(initial_vigil) == TYPE_STRING else "",
				"run_sha": str(pre_terminal).sha256_text() if typeof(pre_terminal) == TYPE_STRING else "",
				"vigil_sha": str(vigil_after).sha256_text() if typeof(vigil_after) == TYPE_STRING else "",
				"commands": commands,
				"pilot_version": Pilot.VERSION,
			}
		if main.game.cb != null and not main.game.cb.over:
			if main.game.cb.turn >= TURN_CAP:
				status = "INCOMPLETE"
				incomplete_reason = "turn_cap"
				break
			var rng_before_turn: int = main.game.run.rng.get_state()
			Pilot.play_turn(main.game)
			commands.append({
				"t": "play_turn",
				"turn": main.game.cb.turn if main.game.cb != null else -1,
				"rng_before": rng_before_turn,
			})
			if main.game.cb != null and not main.game.cb.over:
				main.game.apply({"t": "endTurn"})
				commands.append({"t": "endTurn"})
			continue
		if main.game.cb != null and main.game.cb.over and not combat_result_dispatched:
			var rng_before: int = main.game.run.rng.get_state()
			if dispatch_combat_result_once(main, combat_result_dispatched):
				combat_result_dispatched = true
				combat_dispatches += 1
				commands.append({
					"t": "combat_over",
					"result": str(main.game.cb.result) if main.game.cb != null else "",
					"rng_before": rng_before,
					"rng_after": main.game.run.rng.get_state(),
				})
		if main.game.run.pending_reward != null:
			_claim_pending_reward(main, content)
			reward_claims += 1
			commands.append({"t": "reward"})
			continue
		if main._has_pending_boss_relic():
			var offer_v: Variant = main.game.run.quest_scratch.get("bossRelicOffer")
			var relic_id: String = ""
			if typeof(offer_v) == TYPE_ARRAY:
				relic_id = Pilot.choose_relic(offer_v, content, main.game.run.aspect, main.game.run.rng)
			main._on_boss_relic_chosen(relic_id)
			commands.append({"t": "boss_relic", "id": relic_id})
			continue
		if main.game.run.pending_combat != null:
			if main._screen == null or main.game.cb == null:
				main._resume_pending_combat()
				starts += 1
				combat_result_dispatched = false
				commands.append({"t": "resume_pending_combat", "starts": starts})
			continue
		if main._map == null:
			incomplete_reason = "missing_map"
			break
		var node: MapNode = main._map.current()
		if node != null and not main._map.is_cleared(main._map.at):
			if not _resolve_current_safe(main, node, commands):
				status = "INCOMPLETE"
				incomplete_reason = "unresolved_node:%s" % node.type
				break
			continue
		if main._map.is_finished():
			status = "INCOMPLETE"
			incomplete_reason = "map_finished_without_terminal"
			break
		var reachable: Array[int] = main._map.reachable()
		if reachable.is_empty():
			status = "INCOMPLETE"
			incomplete_reason = "no_reachable"
			break
		var pick: int = Pilot.choose_node(main._map, main.game.run)
		if pick < 0 or not reachable.has(pick):
			pick = reachable[0]
		if not main._map.enter(pick):
			incomplete_reason = "map_enter_failed"
			status = "INCOMPLETE"
			break
		commands.append({"t": "node_chosen", "index": pick})
		main._on_node_chosen(pick)
		if main.game != null and main.game.cb != null:
			starts += 1
			combat_result_dispatched = false
	var shatters: int = 0
	var run_id: String = ""
	var rng_final: int = rng_initial
	var map_at: int = -1
	if main.game != null and main.game.run != null:
		shatters = int(float(str(main.game.run.stats.get("shatters", 0))))
		run_id = main.game.run.run_id
		rng_final = main.game.run.rng.get_state()
	if main._map != null:
		map_at = main._map.at
	var run_bytes: Variant = file_text(run_path)
	var vigil_bytes: Variant = file_text(vigil_path)
	dispose(main)
	return {
		"status": status,
		"starts": starts,
		"shatters": shatters,
		"steps": steps,
		"combat_dispatches": combat_dispatches,
		"reward_claims": reward_claims,
		"incomplete_reason": incomplete_reason,
		"run_id": run_id,
		"seed": seed,
		"vow": vow,
		"rng_initial": rng_initial,
		"rng_final": rng_final,
		"map_at": map_at,
		"pilot_version": Pilot.VERSION,
		"commands": commands,
		"pre_terminal_run": "",
		"commit_vigil": vigil_bytes if typeof(vigil_bytes) == TYPE_STRING else "",
		"initial_run_sha": str(initial_run).sha256_text() if typeof(initial_run) == TYPE_STRING else "",
		"run_sha": str(run_bytes).sha256_text() if typeof(run_bytes) == TYPE_STRING else "",
		"vigil_sha": str(vigil_bytes).sha256_text() if typeof(vigil_bytes) == TYPE_STRING else "",
		"initial_vigil_sha": str(initial_vigil).sha256_text() if typeof(initial_vigil) == TYPE_STRING else "",
	}


static func _claim_pending_reward(main: Main, content: ContentDB) -> void:
	var pending: Dictionary = main.game.run.pending_reward
	var rewards_v: Variant = pending.get("rewards", {})
	if typeof(rewards_v) != TYPE_DICTIONARY:
		main._on_reward_finished()
		return
	var rewards: Dictionary = rewards_v
	main._on_reward_claimed(&"gold", "")
	var cards_v: Variant = rewards.get("cards", [])
	if typeof(cards_v) == TYPE_ARRAY:
		var cards: Array = cards_v
		if not cards.is_empty():
			var pick: String = Pilot.choose_card(cards, content, main.game.run.aspect, main.game.run.rng)
			if not pick.is_empty():
				var definition: Dictionary = content.cards.get(pick, {})
				if Pilot.accepts_card_reward(Pilot.card_score(definition, main.game.run.aspect, pick)):
					main._on_reward_claimed(&"card", pick)
	var relics_v: Variant = rewards.get("relics", [])
	if typeof(relics_v) == TYPE_ARRAY:
		var relics: Array = relics_v
		if not relics.is_empty():
			var relic: String = Pilot.choose_relic(relics, content, main.game.run.aspect, main.game.run.rng)
			if not relic.is_empty():
				main._on_reward_claimed(&"relic", relic)
	var potion: String = str(rewards.get("potion", ""))
	if not potion.is_empty() and main.game.run.player.potions.has(""):
		main._on_reward_claimed(&"potion", potion)
	main._on_reward_finished()


static func _resolve_current_safe(main: Main, node: MapNode, commands: Array) -> bool:
	match node.type:
		"monster", "elite", "boss":
			if main.game.run.pending_combat == null:
				main._prepare_encounter(node)
				commands.append({"t": "prepare_encounter", "type": node.type})
			return true
		"rest":
			main._on_rest_choice("heal")
			commands.append({"t": "rest", "choice": "heal"})
			return true
		"shop":
			return _shop_legal(main, commands)
		"treasure":
			if not main.game.run.quest_scratch.has("treasureClaim"):
				main._show_treasure()
			main._finish_node()
			commands.append({"t": "treasure"})
			return true
		"event":
			return _event_legal(main, commands)
		_:
			main._finish_node()
			commands.append({"t": "finish", "type": node.type})
			return true


static func _shop_legal(main: Main, commands: Array) -> bool:
	if not main.game.run.quest_scratch.has("shopStock"):
		main._show_shop()
	var stock_v: Variant = main.game.run.quest_scratch.get("shopStock", {})
	if typeof(stock_v) != TYPE_DICTIONARY:
		main._on_shop_choice("leave")
		commands.append({"t": "shop", "choice": "leave"})
		return true
	var stock: Dictionary = stock_v
	var bought: Array[Dictionary] = Pilot.choose_shop(stock, main.game.run, main.content)
	for row: Dictionary in bought:
		var category: String = str(row.get("category", ""))
		if category == "remove":
			main._on_shop_choice("remove")
			main._on_shop_remove(str(row.get("uid", "")))
			commands.append({"t": "shop_remove", "uid": row.get("uid", "")})
			continue
		var rows_v: Variant = stock.get(category, [])
		if typeof(rows_v) != TYPE_ARRAY:
			continue
		var rows: Array = rows_v
		var want: String = str(row.get("id", ""))
		for i: int in range(rows.size()):
			var item: Dictionary = rows[i]
			if str(item.get("id", "")) == want and item.get("sold", false) != true:
				main._on_shop_choice("%s:%d" % [category, i])
				commands.append({"t": "shop_buy", "id": want, "category": category})
				break
	main._on_shop_choice("leave")
	commands.append({"t": "shop", "choice": "leave"})
	return true


static func _event_legal(main: Main, commands: Array) -> bool:
	var event_id: String = str(main.game.run.quest_scratch.get("eventNode", ""))
	if event_id.is_empty():
		main._show_event()
		event_id = str(main.game.run.quest_scratch.get("eventNode", ""))
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
				var pick: String = Pilot.choose_card(cards, main.content, main.game.run.aspect, main.game.run.rng)
				if pick.is_empty():
					pick = str(cards[0])
				main._on_event_pick(pick, kind)
			else:
				return false
	if typeof(main.game.run.quest_scratch.get("eventStory")) == TYPE_DICTIONARY:
		main._on_event_story_continue()
		if typeof(main.game.run.quest_scratch.get("eventStory")) == TYPE_DICTIONARY:
			main._on_event_story_continue()
	commands.append({"t": "event", "id": event_id})
	return true


static func ledger_satisfies_p0(vigil: VigilState) -> bool:
	return vigil.unlocks.has("card:resonantLance") \
		or int(float(str(vigil.deeds.get("shatters", 0)))) >= 15


static func ledger_satisfies_p5(vigil: VigilState) -> bool:
	return vigil.vow_unlocked >= 5 and ledger_satisfies_p0(vigil)


static func evaluate_n0_witness(
	p0_run_path: String,
	p0_vigil_path: String,
	p5_run_path: String,
	p5_vigil_path: String,
	content: ContentDB
) -> Dictionary:
	var missing: Array[String] = []
	for path: String in [p0_run_path, p0_vigil_path, p5_run_path, p5_vigil_path]:
		if not FileAccess.file_exists(path):
			missing.append(path)
	if not missing.is_empty():
		return {
			"result": "BLOCKED",
			"reason": "missing mandatory witness",
			"missing": missing,
		}
	var p0_run: RunState = SaveService.load_run(content, p0_run_path)
	var p0_vigil: VigilState = SaveService.load_vigil(p0_vigil_path)
	var p5_run: RunState = SaveService.load_run(content, p5_run_path)
	var p5_vigil: VigilState = SaveService.load_vigil(p5_vigil_path)
	if p0_run == null or p5_run == null:
		return {"result": "REJECT", "reason": "run bytes failed SaveService.load_run"}
	if p0_vigil == null or p5_vigil == null:
		return {"result": "REJECT", "reason": "vigil bytes failed load"}
	if not ledger_satisfies_p0(p0_vigil):
		return {"result": "REJECT", "reason": "P_0 lacks paneBreaker / resonantLance opportunity"}
	if not ledger_satisfies_p5(p5_vigil):
		return {"result": "REJECT", "reason": "P_5 lacks vow_unlocked>=5"}
	if p0_run.seed < 0 or p5_run.seed < 0:
		return {"result": "REJECT", "reason": "seed missing"}
	return {
		"result": "ACCEPT",
		"reason": "",
		"p0_seed": p0_run.seed,
		"p5_seed": p5_run.seed,
		"p0_shatters": int(float(str(p0_vigil.deeds.get("shatters", 0)))),
		"p5_vow_unlocked": p5_vigil.vow_unlocked,
	}


## Map-selection, encounter-arm, SaveService freeze. Does not start combat
## or write canonical qualification artifacts.
static func capture_pending_map_route(
	content: ContentDB,
	seed: int,
	run_path: String,
	vigil_path: String
) -> Dictionary:
	bind_unmodified_pilot()
	SaveService.clear(run_path)
	SaveService.clear_vigil(vigil_path)
	var main: Main = make_main(content, run_path, vigil_path)
	main._vigil = VigilState.blank()
	main._forced_seed = seed
	main._new_run({"aspect": 0, "vow": 0})
	if main._map == null or main.game == null:
		dispose(main)
		return {"ok": false, "reason": "map missing after _new_run"}
	var reachable: Array[int] = main._map.reachable()
	if reachable.is_empty():
		dispose(main)
		return {"ok": false, "reason": "no reachable row-0 nodes"}
	var pick: int = Pilot.choose_node(main._map, main.game.run)
	if pick < 0 or not reachable.has(pick):
		pick = reachable[0]
	if not main._map.enter(pick):
		dispose(main)
		return {"ok": false, "reason": "map.enter failed"}
	var node: MapNode = main._map.nodes[pick]
	main.game.run.node_id = node.id
	main.game.run.waystones_lit = node.row + 1
	main.game.run.map = main._map.to_dict()
	if not main._store_run():
		dispose(main)
		return {"ok": false, "reason": "chosen waystone store failed"}
	main._arm_encounter(node)
	if typeof(main.game.run.pending_enemy_ids) != TYPE_ARRAY:
		dispose(main)
		return {"ok": false, "reason": "encounter arm produced no enemies"}
	if not main._store_run():
		dispose(main)
		return {"ok": false, "reason": "armed encounter store failed"}
	var raw: Variant = file_text(run_path)
	var parsed: Variant = JSON.parse_string(str(raw)) if typeof(raw) == TYPE_STRING else null
	var ok: bool = typeof(parsed) == TYPE_DICTIONARY
	var save: Dictionary = parsed if ok else {}
	var nodes: Array = []
	var map_v: Variant = save.get("map", {})
	if typeof(map_v) == TYPE_DICTIONARY:
		nodes = map_v.get("nodes", [])
	var result: Dictionary = {
		"ok": ok and not nodes.is_empty() and save.get("pendingCombat") != null,
		"pick": pick,
		"pendingCombat": save.get("pendingCombat"),
		"pendingEnemyIds": save.get("pendingEnemyIds"),
		"nodeId": save.get("nodeId"),
		"runId": save.get("runId"),
		"seed": save.get("seed"),
		"node_count": nodes.size(),
		"bytes": str(raw) if typeof(raw) == TYPE_STRING else "",
		"sha256": str(raw).sha256_text() if typeof(raw) == TYPE_STRING else "",
		"reason": "" if ok else "save unreadable",
	}
	if result["ok"] != true and str(result["reason"]) == "":
		result["reason"] = "pending capture lacked map nodes or pendingCombat"
	dispose(main)
	return result
