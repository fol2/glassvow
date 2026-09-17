extends RefCounted
## Narrow Main/application driver for DD1-NATIVE-1 pending resume and
## explicitly invoked ordinary-route acquisition. Not a second campaign.
## Routine regression must not call drive_ordinary unless launch is permitted.

const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const Receipt: GDScript = preload("res://tests/support/dd1_native_launch_receipt.gd")
const DriverMain: GDScript = preload("res://tests/support/dd1_native_driver_main.gd")
const Ordinary: GDScript = preload("res://tests/support/dd1_ordinary_capture.gd")
const Unit: GDScript = preload("res://tests/support/dd1_unit_grant.gd")
const QUAL: String = "res://research/p9-six-route/dusk-design-1-20260916/native-qualification"
const RECOVERY: String = QUAL + "/recovery"
const TURN_CAP: int = 30
const STEP_CAP: int = 240
const PILOT_VERSION: String = "p8-d0-v1"


static func acquire_requested() -> bool:
	return OS.get_environment("DD1_NATIVE_ACQUIRE") == "1"


static func launch_permitted() -> bool:
	return Receipt.permitted() and Unit.remaining() > 0


## Object/encounter identity survives reward completion and all safe screens.
## The old caller Boolean is an extra refusal, never permission to re-arm.
static func dispatch_combat_result_once(main: Main, already_dispatched: bool) -> bool:
	if already_dispatched or not main.has_method("dispatch_once"):
		return false
	return main.call("dispatch_once") == true


static func bind_unmodified_pilot() -> Dictionary:
	Pilot.set_ban(PackedStringArray())
	Pilot.apply_policy({})
	Pilot.set_modes(false, false)
	return {"version": Pilot.VERSION, "snapshot": Pilot.policy_snapshot(),
		"random_build": Pilot.random_build, "random_play": Pilot.random_play}


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


static func _write_new_bytes(path: String, raw: String) -> bool:
	if raw.is_empty() or FileAccess.file_exists(path):
		return false  # original archives and failed captures are not overwritten
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(raw)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	return error == OK and file_text(path) == raw


static func archive_bytes(src_path: String, dest_path: String) -> String:
	var raw: Variant = file_text(src_path)
	if typeof(raw) != TYPE_STRING or not _write_new_bytes(dest_path, raw):
		return ""
	return str(raw).sha256_text()


## Retain the entire producer record, including initial bytes and journal.
## Derived access flags are summaries; they never authenticate acquisition.
static func durable_trace_row(seed: int, vow: int, row: Dictionary, vigil: VigilState) -> Dictionary:
	var trace: Dictionary = row.duplicate(true)
	if int(row.get("seed", seed)) != seed or int(row.get("vow", vow)) != vow:
		trace["status"] = "INCOMPLETE"
		trace["incomplete_reason"] = "trace_input_identity_mismatch"
	trace["seed"] = seed
	trace["vow"] = vow
	trace["p0_now"] = vigil != null and ledger_satisfies_p0(vigil)
	trace["p5_now"] = vigil != null and ledger_satisfies_p5(vigil)
	trace["vow_unlocked"] = vigil.vow_unlocked if vigil != null else 0
	return trace


static func archive_profile_run(row: Dictionary, dest_path: String) -> bool:
	var pre: Variant = row.get("pre_terminal_run")
	return typeof(pre) == TYPE_STRING and _write_new_bytes(dest_path, pre)


static func write_pv_traces(path: String, payload: Dictionary) -> bool:
	return _write_new_bytes(path, JSON.stringify(payload))


static func drive_ordinary(content: ContentDB, vigil: VigilState, seed: int, vow: int,
		run_path: String, vigil_path: String, contained_limit: int = 0) -> Dictionary:
	return Ordinary.drive(content, vigil, seed, vow, run_path, vigil_path, contained_limit)


static func _claim_pending_reward(main: Main, content: ContentDB) -> void:
	var pending: Dictionary = main.game.run.pending_reward
	var rewards_v: Variant = pending.get("rewards", {})
	if typeof(rewards_v) != TYPE_DICTIONARY:
		main._show_save_error("dd1_invalid_rewards")
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
	return false  # no invented finish for a route without a mapped public choice


static func _shop_legal(main: Main, commands: Array) -> bool:
	if not main.game.run.quest_scratch.has("shopStock"):
		main._show_shop()
	var stock_v: Variant = main.game.run.quest_scratch.get("shopStock", {})
	if typeof(stock_v) != TYPE_DICTIONARY:
		return false
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
			return false
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
		if typeof(pending_v) != TYPE_DICTIONARY:
			return false
		var pending: Dictionary = pending_v
		var kind: String = str(pending.get("kind", ""))
		if kind != "card":
			return false
		var cards: Array = pending.get("cards", [])
		if cards.is_empty():
			return false
		var pick: String = Pilot.choose_card(cards, main.content, main.game.run.aspect, main.game.run.rng)
		if pick.is_empty():
			pick = str(cards[0])
		main._on_event_pick(pick, kind)
	if typeof(main.game.run.quest_scratch.get("eventStory")) == TYPE_DICTIONARY:
		main._on_event_story_continue()
		if typeof(main.game.run.quest_scratch.get("eventStory")) == TYPE_DICTIONARY:
			main._on_event_story_continue()
	commands.append({"t": "event", "id": event_id})
	return true


static func ledger_satisfies_p0(vigil: VigilState) -> bool:
	# Both frozen required-deed and required-unlock obligations; not OR.
	return vigil.unlocks.has("card:resonantLance") \
		and int(float(str(vigil.deeds.get("shatters", 0)))) >= 15


static func ledger_satisfies_p5(vigil: VigilState) -> bool:
	return vigil.vow_unlocked >= 5 and ledger_satisfies_p0(vigil)


## Storage/structure preflight only. Full linked-byte provenance is checked by
## tools/dd1_provenance.py with the host's existing C/H evidence boundary.
## Loading four files, self-hashes and fixture fields cannot grant N0 ACCEPT.
static func evaluate_n0_witness(p0_run_path: String, p0_vigil_path: String,
		p5_run_path: String, p5_vigil_path: String, content: ContentDB) -> Dictionary:
	for path: String in [p0_run_path, p0_vigil_path, p5_run_path, p5_vigil_path]:
		if not FileAccess.file_exists(path):
			return {"result": "BLOCKED", "reason": "missing mandatory witness", "missing": [path]}
	var p0: VigilState = null
	var p5: VigilState = null
	for pair: Array in [[p0_run_path, p0_vigil_path], [p5_run_path, p5_vigil_path]]:
		var run: RunState = SaveService.load_run(content, pair[0])
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(pair[1]))
		var vigil: VigilState = VigilState.from_dict(parsed) if typeof(parsed) == TYPE_DICTIONARY else null
		if run == null or vigil == null:
			return {"result": "REJECT", "reason": "invalid run or vigil bytes"}
		var receipt: Variant = vigil.receipts.get("runEnd")
		var nodes: Array = run.map.get("nodes", [])
		if nodes.is_empty() or run.aspect != 0 or run.seed < 5421600 or run.seed > 5421615 \
				or typeof(run.pending_run_end) != TYPE_DICTIONARY or typeof(receipt) != TYPE_DICTIONARY:
			return {"result": "REJECT", "reason": "constructed or nonterminal witness"}
		if receipt.get("runId") != run.run_id or receipt.get("outcome") != run.pending_run_end.get("outcome"):
			return {"result": "REJECT", "reason": "unrelated terminal receipt"}
		if pair[0] == p0_run_path:
			p0 = vigil
		else:
			p5 = vigil
	if not ledger_satisfies_p0(p0) or not ledger_satisfies_p5(p5):
		return {"result": "REJECT", "reason": "missing frozen access requirements"}
	return {"result": "BLOCKED", "reason": "missing linked ordinary journal and authenticated C/H provenance",
		"structure": "VALID_NOT_EARNED_PROOF", "n0_accepted": false}


## Map-selection, encounter-arm, SaveService freeze. Does not start combat
## or write canonical qualification artifacts. Existing outputs are preserved.
static func capture_pending_map_route(content: ContentDB, seed: int,
		run_path: String, vigil_path: String) -> Dictionary:
	if FileAccess.file_exists(run_path) or FileAccess.file_exists(vigil_path):
		return {"ok": false, "reason": "existing isolated output"}
	bind_unmodified_pilot()
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
		"pick": pick, "pendingCombat": save.get("pendingCombat"),
		"pendingEnemyIds": save.get("pendingEnemyIds"), "nodeId": save.get("nodeId"),
		"runId": save.get("runId"), "seed": save.get("seed"), "node_count": nodes.size(),
		"bytes": str(raw) if typeof(raw) == TYPE_STRING else "",
		"sha256": str(raw).sha256_text() if typeof(raw) == TYPE_STRING else "",
		"reason": "" if ok else "save unreadable"}
	if result["ok"] != true and str(result["reason"]) == "":
		result["reason"] = "pending capture lacked map nodes or pendingCombat"
	dispose(main)
	return result
