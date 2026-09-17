extends RefCounted
## One ordinary route, observed once. No policy refit, replay or launch grant.

const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const Unit: GDScript = preload("res://tests/support/dd1_unit_grant.gd")
const TURN_CAP: int = 30
const STEP_CAP: int = 240


static func drive(content: ContentDB, vigil: VigilState, seed: int, vow: int,
		run_path: String, vigil_path: String, contained_limit: int = 0) -> Dictionary:
	var route: GDScript = load("res://tests/support/dd1_native_main_route.gd")
	if not route.launch_permitted():
		return _incomplete("missing_launch_authority_or_reservation")
	contained_limit = mini(contained_limit, Unit.remaining()) if contained_limit > 0 else Unit.remaining()
	var initial_vigil: Variant = route.file_text(vigil_path)
	var journal_path: String = run_path + ".journal.jsonl"
	if contained_limit <= 0 or FileAccess.file_exists(run_path) or FileAccess.file_exists(journal_path):
		return _incomplete("missing_bound_or_existing_output")
	if typeof(initial_vigil) != TYPE_STRING or str(initial_vigil) != JSON.stringify(vigil.to_dict()):
		return _incomplete("initial_vigil_missing_or_mismatched")
	if seed < 5421600 or seed > 5421615 or vow != mini(vigil.vow_unlocked, 4):
		return _incomplete("procedure_input_mismatch")
	if not Unit.claim_root(seed):
		return _incomplete("root_order_or_unit_mismatch")
	var expected_sources: Dictionary = Unit.source_manifest()
	var freeze: Dictionary = route.bind_unmodified_pilot()
	var main: Variant = route.make_main(content, run_path, vigil_path)
	main._vigil = vigil
	main._forced_seed = seed
	main.contained_limit = contained_limit
	main.capture.attach(main)
	main.capture.sink = journal_path
	main.capture.max_bytes = Unit.journal_limit()
	var sources: Dictionary = main.capture.source_bytes(expected_sources)
	main.capture.append_row({"phase": "header", "operation": "DD1-N0-RECOVERY-1",
		"seed": seed, "vow": vow, "sources": sources, "pilot": freeze,
		"initial_vigil": initial_vigil, "initial_vigil_sha": str(initial_vigil).sha256_text()})
	var token: int = main.capture.begin("new_run", {"aspect": 0, "vow": vow, "seed": seed})
	if token >= 0:
		main._new_run({"aspect": 0, "vow": vow})
		main.capture.finish(token)
	var initial_run: Variant = route.file_text(run_path)
	if typeof(initial_run) != TYPE_STRING or str(initial_run).is_empty():
		main.capture.fail("initial_run_not_durable")
	var rng_initial: String = str(main.game.run.rng.get_state()) if main.game != null else ""
	var reward_claims: int = 0
	var reason: String = "step_cap"
	var steps: int = 0
	while steps < STEP_CAP and main.capture.errors.is_empty():
		steps += 1
		if main.game == null or main.game.run == null:
			reason = "missing_game"
			break
		if main.game.run.pending_run_end != null:
			main._on_terminal_commit("commit")
			reason = "" if main.complete_terminal() else "terminal_incomplete"
			break
		if main._route_checkpoint_quarantined:
			reason = "quarantined_route"
			break
		if main.game.run.pending_scene != null or main.game.run.pending_pool != null \
				or main.game.run.pending_hollow != null or main.game.run.pending_lamplighter:
			reason = "unmapped_pending_public_choice"
			break
		if main.game.cb != null and not main.game.cb.over:
			if main.game.cb.turn >= TURN_CAP:
				reason = "turn_cap"
				break
			token = main.capture.begin("pilot_play_turn")
			if token < 0:
				break
			Pilot.play_turn(main.game)  # The observer records every actual apply, once.
			main.capture.finish(token)
			if main.capture.errors.is_empty() and main.game.cb != null and not main.game.cb.over:
				main.game.apply({"t": "endTurn"})
			continue
		if main.game.cb != null and main.game.cb.over:
			main.dispatch_once()
		if not main.capture.errors.is_empty():
			break
		if main.game.run.pending_run_end != null:
			continue
		if main.game.run.pending_reward != null:
			token = main.capture.begin("reward_policy", main.game.run.pending_reward.duplicate(true))
			if token < 0:
				break
			route._claim_pending_reward(main, content)
			main.capture.finish(token)
			reward_claims += 1
			continue
		if main._has_pending_boss_relic():
			var offer: Variant = main.game.run.quest_scratch.get("bossRelicOffer")
			if typeof(offer) != TYPE_ARRAY:
				reason = "missing_boss_offer"
				break
			token = main.capture.begin("boss_relic_policy", {"offer": offer})
			if token < 0:
				break
			var relic: String = Pilot.choose_relic(offer, content, main.game.run.aspect, main.game.run.rng)
			main._on_boss_relic_chosen(relic)
			main.capture.finish(token, {"choice": relic})
			continue
		if main.game.run.pending_combat != null:
			var before: int = main.contained_starts
			main._resume_pending_combat()
			if before == main.contained_starts and (main.game.cb == null or main.game.cb.over):
				reason = "pending_combat_without_new_creation"
				break
			continue
		if main._map == null:
			reason = "missing_map"
			break
		var node: MapNode = main._map.current()
		if node != null and not main._map.is_cleared(main._map.at):
			if node.type not in ["monster", "elite", "boss", "rest", "shop", "treasure", "event"]:
				reason = "unmapped_public_choice:" + node.type
				break
			var choices: Array = []
			token = main.capture.begin("safe_node", {"node_id": node.id, "type": node.type})
			if token < 0:
				break
			var resolved: bool = route._resolve_current_safe(main, node, choices)
			main.capture.finish(token, {"choices": choices})
			if not resolved:
				reason = "unresolved_node:" + node.type
				break
			continue
		var reachable: Array[int] = main._map.reachable()
		if reachable.is_empty() or main._map.is_finished():
			reason = "no_reachable_or_missing_terminal"
			break
		token = main.capture.begin("node_policy", {"reachable": reachable})
		if token < 0:
			break
		var pick: int = Pilot.choose_node(main._map, main.game.run)
		if pick < 0 or not reachable.has(pick):
			main.capture.finish(token, {"choice": pick})
			reason = "illegal_pilot_node_choice"
			break  # no replacement choice or refit to turn a failure into a run
		main.capture.finish(token, {"choice": pick})
		token = main.capture.begin("node_chosen", {"index": pick})
		if token < 0:
			break
		var entered: bool = main._map.enter(pick)
		if entered:
			main._on_node_chosen(pick)
		main.capture.finish(token, {"entered": entered})
		if not entered:
			reason = "map_enter_failed"
			break
	if not main.capture.errors.is_empty():
		reason = "capture_error:" + ";".join(main.capture.errors)
	main.capture.source_bytes(expected_sources)  # Detect changed source during capture.
	var terminal: Dictionary = main.terminal.duplicate(true)
	var pre: String = str(terminal.get("pre_terminal_run", ""))
	var committed: String = str(terminal.get("commit_vigil", ""))
	var complete: bool = reason.is_empty() and terminal.get("run_cleared", false) \
		and not pre.is_empty() and not committed.is_empty()
	main.capture.append_row({"phase": "footer", "complete": complete,
		"reason": reason, "starts": main.contained_starts, "dispatches": main.combat_dispatches,
		"terminal": terminal})
	var capture: Dictionary = main.capture.packet()
	if not capture["errors"].is_empty() or not capture["open_actions"].is_empty():
		complete = false
		reason = "capture_finalisation_failed"
	var row: Dictionary = {"status": terminal.get("outcome", "INCOMPLETE") if complete else "INCOMPLETE",
		"incomplete_reason": reason, "starts": main.contained_starts,
		"combat_dispatches": main.combat_dispatches, "reward_claims": reward_claims,
		"steps": steps, "seed": seed, "vow": vow, "run_id": terminal.get("run_id", ""),
		"initial_vigil": initial_vigil, "initial_vigil_sha": str(initial_vigil).sha256_text(),
		"initial_run": initial_run, "initial_run_sha": str(initial_run).sha256_text(),
		"rng_initial": rng_initial, "rng_final": terminal.get("rng_final", ""),
		"map_at": terminal.get("map_at", -1), "shatters": terminal.get("shatters", 0),
		"pre_terminal_run": pre, "run_sha": pre.sha256_text(),
		"commit_vigil": committed, "vigil_sha": committed.sha256_text(),
		"terminal": terminal, "capture": capture, "sources": sources,
		"pilot_version": Pilot.VERSION, "commands": capture["rows"]}
	route.dispose(main)
	return row


static func _incomplete(reason: String) -> Dictionary:
	return {"status": "INCOMPLETE", "starts": 0, "incomplete_reason": reason}
