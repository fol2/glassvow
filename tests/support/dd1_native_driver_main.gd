extends Main
## Headless observation adapter. Native game, Pilot, rewards and persistence
## laws are unchanged. A sticky capture error prevents further driver actions.

const Journal: GDScript = preload("res://tests/support/dd1_route_journal.gd")
var capture: Variant = Journal.new()
var contained_limit: int = 0  # enclosing meter reservation, NOT launch authority
var contained_starts: int = 0
var combat_dispatches: int = 0
var current_combat: CombatState = null
var current_encounter: String = ""
var dispatched: bool = false
var encountered: Dictionary = {}
var terminal: Dictionary = {}


func observe_game() -> void:
	capture.attach(self)
	if game != null and not game is Journal.ObservedGame:
		game = Journal.ObservedGame.new(game, self)


func encounter_key() -> String:
	if game == null or game.run == null or _map == null or _map.current() == null:
		return ""
	return JSON.stringify([game.run.run_id, game.run.act, _map.current().id])


func before_combat_start() -> bool:
	if not capture.errors.is_empty():
		return false
	var key: String = encounter_key()
	if key.is_empty() or encountered.has(key):
		capture.fail("duplicate_or_missing_encounter")
		return false
	if contained_limit <= contained_starts:
		capture.fail("contained_start_reservation_exhausted")
		return false
	if game.cb != null and not game.cb.over:
		capture.fail("start_during_active_combat")
		return false
	# Charge attempted creation BEFORE native execution; failures never refund it.
	contained_starts += 1
	encountered[key] = true
	return true


func after_combat_start(old: CombatState) -> void:
	if game.cb == null or game.cb == old:
		capture.fail("start_did_not_create_combat")
		return
	current_combat = game.cb
	current_encounter = encounter_key()
	dispatched = false


func dispatch_once() -> bool:
	if not capture.errors.is_empty() or game == null or game.cb == null:
		return false
	if dispatched or game.cb != current_combat or not game.cb.over:
		return false
	if current_encounter != encounter_key():
		capture.fail("combat_encounter_mismatch")
		return false
	if game.run.pending_reward != null or game.run.pending_run_end != null:
		return false
	dispatched = true  # before the native call, including persistence failure
	combat_dispatches += 1
	var token: int = capture.begin("combat_result", {"encounter": current_encounter,
		"result": str(game.cb.result)})
	super._on_combat_over(str(game.cb.result))
	capture.finish(token)
	return true


func _on_combat_over(_result: String) -> void:
	dispatch_once()


func _store_run() -> bool:
	observe_game()
	if not capture.errors.is_empty():
		return false
	var token: int = capture.begin("store_run")
	var expected: String = JSON.stringify(game.run.to_save_dict())
	var ok: bool = super._store_run()
	var raw: String = FileAccess.get_file_as_string(_run_save_path) if ok else ""
	ok = ok and raw == expected and SaveService.load_run(content, _run_save_path) != null
	capture.finish(token, {"ok": ok, "bytes": raw})
	if not ok:
		capture.fail("run_save_failed_or_changed")
	return ok


func _store_vigil() -> bool:
	capture.attach(self)
	if not capture.errors.is_empty():
		return false
	var token: int = capture.begin("store_vigil")
	var expected: String = JSON.stringify(_vigil.to_dict())
	var ok: bool = super._store_vigil()
	var raw: String = FileAccess.get_file_as_string(_vigil_save_path) if ok else ""
	ok = ok and raw == expected
	capture.finish(token, {"ok": ok, "bytes": raw})
	if not ok:
		capture.fail("vigil_save_failed_or_changed")
	return ok


func _clear_run(expected_run_id: String = "") -> bool:
	var token: int = capture.begin("clear_run", {"expected_run_id": expected_run_id})
	var before: String = FileAccess.get_file_as_string(_run_save_path)
	var ok: bool = super._clear_run(expected_run_id)
	ok = ok and not FileAccess.file_exists(_run_save_path)
	capture.finish(token, {"ok": ok, "before_bytes": before})
	if not ok:
		capture.fail("run_clear_failed")
	return ok


func _show_save_error(key: String) -> void:
	capture.fail("native_save_error:" + key)


func _resume_pending_combat() -> void:
	if not capture.errors.is_empty() or game == null or game.run == null:
		return
	if typeof(game.run.pending_enemy_ids) != TYPE_ARRAY:
		capture.fail("missing_pending_enemies")
		return
	if game.cb == current_combat and current_encounter == encounter_key():
		return  # same encounter; presentation's null screen is not a new start
	if game.run.pending_quest_id == "ownShade" and _vigil.last_fall != null:
		_vigil.last_fall = null
		if not _store_vigil():
			return
	var enemies: Array = []
	for id_v: Variant in game.run.pending_enemy_ids:
		enemies.append(str(id_v))
	var kind: String = str(game.run.pending_combat)
	game.apply({"t": "startCombat", "enemies": enemies,
		"kind": "normal" if kind == "monster" else kind})


func _on_terminal_commit(id: String) -> void:
	if not capture.errors.is_empty() or not terminal.is_empty():
		return
	var raw: String = FileAccess.get_file_as_string(_run_save_path)
	if raw.is_empty() or raw != JSON.stringify(game.run.to_save_dict()):
		capture.fail("missing_exact_preterminal_bytes")
		return
	var run_id: String = game.run.run_id
	var outcome: String = str(game.run.pending_run_end.get("outcome", ""))
	var token: int = capture.begin("terminal_commit", {"choice": id})
	terminal = {"run_id": run_id, "outcome": outcome, "pre_terminal_run": raw}
	super._on_terminal_commit(id)
	var committed: String = FileAccess.get_file_as_string(_vigil_save_path)
	terminal["commit_vigil"] = committed
	terminal["receipt"] = _vigil.receipts.get("runEnd", {}).duplicate(true)
	terminal["run_cleared"] = not FileAccess.file_exists(_run_save_path)
	capture.finish(token, terminal)
	if committed.is_empty() or not capture.errors.is_empty():
		capture.fail("terminal_capture_incomplete")


func _show_map() -> void:
	_clear_route()


func _show_pending_reward() -> void:
	_clear_route()


func _show_run_end() -> void:
	_clear_route()


func _show_dawn() -> void:
	_clear_route()


func _route_idle() -> void:
	_clear_route()


func _show_rest() -> void:
	_clear_route()


func _show_boss_relic() -> void:
	if typeof(game.run.quest_scratch.get("bossRelicOffer")) != TYPE_ARRAY:
		game.run.quest_scratch["bossRelicOffer"] = game.rewards.roll_boss_relics(game.run)
		if not _store_run():
			return
	_clear_route()


func _show_shop() -> void:
	if typeof(game.run.quest_scratch.get("shopStock")) != TYPE_DICTIONARY:
		game.run.quest_scratch["shopStock"] = game.rewards.gen_shop(game.run)
		if not _store_run():
			return
	_clear_route()


func _show_treasure() -> void:
	if typeof(game.run.quest_scratch.get("treasureClaim")) != TYPE_DICTIONARY:
		game.run.quest_scratch["treasureClaim"] = game.rewards.claim_treasure(game.run)
		if not _store_run():
			return
	_clear_route()


func _show_event() -> void:
	if str(game.run.quest_scratch.get("eventNode", "")).is_empty():
		game.run.quest_scratch["eventNode"] = game.rewards.roll_event(game.run)
		if not _store_run():
			return
	_clear_route()


func _on_reward_claimed(what: StringName, id: String) -> void:
	if not capture.errors.is_empty():
		return
	var token: int = capture.begin("reward_claim", {"what": str(what), "id": id})
	super._on_reward_claimed(what, id)
	capture.finish(token)


func _on_reward_finished() -> void:
	if not capture.errors.is_empty():
		return
	var token: int = capture.begin("reward_finished")
	super._on_reward_finished()
	capture.finish(token)


func _on_shop_choice(id: String) -> void:
	if not capture.errors.is_empty():
		return
	var token: int = capture.begin("shop_choice", {"id": id})
	super._on_shop_choice(id)
	capture.finish(token)


func _on_shop_remove(uid: String) -> void:
	if not capture.errors.is_empty():
		return
	var token: int = capture.begin("shop_remove", {"uid": uid})
	super._on_shop_remove(uid)
	capture.finish(token)


func _on_event_choice(choice: String, event_id: String) -> void:
	if not capture.errors.is_empty():
		return
	var token: int = capture.begin("event_choice", {"choice": choice, "event_id": event_id})
	super._on_event_choice(choice, event_id)
	capture.finish(token)


func _on_event_pick(id: String, kind: String) -> void:
	if not capture.errors.is_empty():
		return
	var token: int = capture.begin("event_pick", {"id": id, "kind": kind})
	super._on_event_pick(id, kind)
	capture.finish(token)
