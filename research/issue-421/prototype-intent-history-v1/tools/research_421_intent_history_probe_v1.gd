extends SceneTree
## Frozen direct probe for #421 intent-history. It emits observations only;
## the preregistered Python runner owns every assertion and decision.

const ROW_MARKER: String = "RESEARCH421_INTENT_HISTORY_ROW "
const EVENT_TYPE: String = "research421IntentHistory"
const MEDIATOR_KEY: String = "_research421IntentHistory"
const SCENARIOS: Array[Dictionary] = [
	{"id": "repeat-play", "turn": 2, "aspect": 0, "embers": 0,
		"enemies": ["ashAcolyte"], "histories": [["ritual", "scorch"]],
		"action": "play", "cards": ["strike"]},
	{"id": "repeat-cap", "turn": 2, "aspect": 0, "embers": 9,
		"enemies": ["ashAcolyte"], "histories": [["ritual", "scorch"]],
		"action": "play", "cards": ["strike"]},
	{"id": "ash-repeat", "turn": 2, "aspect": 1, "embers": 0,
		"enemies": ["ashAcolyte"], "histories": [["ritual", "scorch"]],
		"action": "play", "cards": ["strike"]},
	{"id": "first-intent", "turn": 0, "aspect": 0, "embers": 0,
		"enemies": ["ashAcolyte"], "histories": [[]],
		"action": "play", "cards": ["strike"]},
	{"id": "changed-intent", "turn": 1, "aspect": 0, "embers": 0,
		"enemies": ["ashAcolyte"], "histories": [["ritual"]],
		"action": "play", "cards": ["strike"]},
	{"id": "two-back-return", "turn": 3, "aspect": 0, "embers": 0,
		"enemies": ["gravewarden"],
		"histories": [["entomb", "crush", "bulwark"]],
		"action": "play", "cards": ["strike"]},
	{"id": "skill-then-attack", "turn": 2, "aspect": 0, "embers": 0,
		"enemies": ["ashAcolyte"], "histories": [["ritual", "scorch"]],
		"action": "skill-then-attack", "cards": ["defend", "strike"]},
	{"id": "wrong-then-right", "turn": 2, "aspect": 0, "embers": 0,
		"enemies": ["ashAcolyte", "sporeling"],
		"histories": [["ritual", "scorch"], ["spit", "grow"]],
		"action": "wrong-then-right", "cards": ["strike", "strike"]},
	{"id": "same-move-other-enemy", "turn": 2, "aspect": 0, "embers": 0,
		"enemies": ["ashAcolyte", "starCultist"],
		"histories": [["ritual", "scorch"], ["ritual"]],
		"action": "play-other", "cards": ["strike"]},
	{"id": "unanswered-next-ai", "turn": 2, "aspect": 0, "embers": 0,
		"enemies": ["chaosHound"], "histories": [["bite", "bite"]],
		"action": "end-turn", "cards": ["strike"]},
	{"id": "staggered-history", "turn": 2, "aspect": 0, "embers": 0,
		"enemies": ["chaosHound"], "histories": [["bite", "bite"]],
		"action": "stagger-end-turn", "cards": ["strike"]},
	{"id": "target-death-other-route", "turn": 2, "aspect": 0, "embers": 0,
		"enemies": ["ashAcolyte", "sporeling"],
		"histories": [["ritual", "scorch"], ["spit", "grow"]],
		"action": "kill-target-direct", "cards": ["strike"]},
	{"id": "victory-expiry", "turn": 2, "aspect": 0, "embers": 0,
		"enemies": ["ashAcolyte"], "histories": [["ritual", "scorch"]],
		"action": "victory", "cards": ["strike"]},
	{"id": "defeat-expiry", "turn": 2, "aspect": 0, "embers": 0,
		"enemies": ["ashAcolyte"], "histories": [["ritual", "scorch"]],
		"action": "defeat", "cards": ["strike"]},
	{"id": "final-responding-attack", "turn": 2, "aspect": 0, "embers": 0,
		"enemies": ["ashAcolyte"], "histories": [["ritual", "scorch"]],
		"action": "play", "cards": ["strike"], "targetHp": 1},
	{"id": "nonfinal-target-kill", "turn": 2, "aspect": 0, "embers": 0,
		"enemies": ["ashAcolyte", "sporeling"],
		"histories": [["ritual", "scorch"], ["spit", "grow"]],
		"action": "play", "cards": ["strike"], "targetHp": 1},
	{"id": "multi-enemy-independent", "turn": 2, "aspect": 0, "embers": 0,
		"enemies": ["ashAcolyte", "starCultist"],
		"histories": [["ritual", "scorch"], ["ritual", "scorch"]],
		"action": "play-both", "cards": ["strike", "strike"]},
	{"id": "exhaust-settlement", "turn": 2, "aspect": 0, "embers": 0,
		"enemies": ["ashAcolyte"], "histories": [["ritual", "scorch"]],
		"action": "play", "cards": ["devour"]},
]


func _initialize() -> void:
	var source: String = _source_arg()
	var available: bool = _interface_available()
	if source != "baseline" and source != "candidate":
		_fail("expected --source=baseline|candidate")
		return
	if available != (source == "candidate"):
		_fail("source/interface identity mismatch")
		return
	var arms: Array[String] = ["baseline"]
	if source == "candidate":
		# Omitted is first and never calls the interface.
		arms = ["omitted", "off", "a", "b", "ab"]
	for arm: String in arms:
		for index: int in range(SCENARIOS.size()):
			_configure(arm)
			_emit(_run_core(source, arm, SCENARIOS[index], 421500 + index))
	if source == "candidate":
		for index: int in range(5):
			_configure("ab")
			_emit(_run_injected(index, 421590 + index))
	quit(0)


func _source_arg() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):
			return arg.trim_prefix("--source=")
	return ""


func _interface_available() -> bool:
	var script: Script = load("res://domain/rules/combat.gd")
	return script.has_method("configure_research421_intent_history")


func _configure(arm: String) -> void:
	if arm == "baseline" or arm == "omitted":
		return
	var script: Script = load("res://domain/rules/combat.gd")
	script.call(
		"configure_research421_intent_history",
		arm == "a" or arm == "ab", arm == "b" or arm == "ab"
	)


func _run_core(
	source: String, arm: String, scenario: Dictionary, seed: int
) -> Dictionary:
	var content: ContentDB = ContentDB.load_full(false)
	var aspect: int = _int(scenario, "aspect")
	var run: RunState = RunState.new_run(
		content, seed, "research421-intent-%s" % str(scenario["id"]),
		{"aspect": aspect}
	)
	run.player.relics.clear()
	var game: GlassvowGame = GlassvowGame.new(content, run)
	var enemy_ids_v: Variant = scenario.get("enemies", [])
	var enemy_ids: Array = enemy_ids_v if typeof(enemy_ids_v) == TYPE_ARRAY else []
	game.apply({"t": "startCombat", "enemies": enemy_ids, "kind": "normal"})
	var initial_events: Array[Dictionary] = game.cb.queue.duplicate(true)
	_prepare(game, scenario)
	var rng_before_compute: int = run.rng_state()
	game.rules.call("_compute_intents", run, game.cb)
	var rng_after_compute: int = run.rng_state()
	game.rules.call("_start_player_turn", run, game.cb)
	game.cb.player.energy = 99
	_add_cards(run, game.cb, scenario.get("cards", []))
	var before_action: Array = _mediators(game.cb)
	var before_action_combat: Dictionary = game.cb.to_dict().duplicate(true)
	var before_action_events: Array[Dictionary] = game.cb.queue.duplicate(true)
	var before_action_flags: Array = _enemy_flags(game.cb, true)
	var action_returns: Array = []
	var after_first: Array = []
	var action: String = str(scenario.get("action", "play"))
	match action:
		"play":
			action_returns.append(_play(game, 0, 0))
		"skill-then-attack":
			action_returns.append(_play(game, 0, null))
			after_first = _mediators(game.cb)
			action_returns.append(_play(game, 0, 0))
		"wrong-then-right":
			action_returns.append(_play(game, 0, 1))
			after_first = _mediators(game.cb)
			action_returns.append(_play(game, 0, 0))
		"play-other":
			action_returns.append(_play(game, 0, 1))
		"end-turn":
			game.apply({"t": "endTurn"})
			action_returns.append(game.last_ret)
		"stagger-end-turn":
			game.cb.enemies[0].staggered = true
			game.apply({"t": "endTurn"})
			action_returns.append(game.last_ret)
		"kill-target-direct":
			action_returns.append(game.rules.hit_enemy(
				run, game.cb, game.cb.enemies[0], 999, false
			))
		"victory":
			game.rules.call("_win_combat", run, game.cb)
			action_returns.append(true)
		"defeat":
			game.rules.lose_combat(run, game.cb)
			action_returns.append(true)
		"play-both":
			action_returns.append(_play(game, 0, 0))
			after_first = _mediators(game.cb)
			action_returns.append(_play(game, 0, 1))
		_:
			_fail("unknown action %s" % action)
	return {
		"source": source, "arm": arm, "scenario": str(scenario["id"]),
		"seed": seed, "policyIdentity": "direct-no-policy-v1",
		"initialEvents": initial_events, "action": action,
		"actionReturns": action_returns,
		"rngBeforeCompute": rng_before_compute,
		"rngAfterCompute": rng_after_compute,
		"rngState": run.rng_state(),
		"mediatorsBeforeAction": before_action,
		"combatBeforeAction": before_action_combat,
		"eventsBeforeAction": before_action_events,
		"enemyFlagsBeforeActionWithoutMediator": before_action_flags,
		"mediatorsAfterFirst": after_first,
		"mediators": _mediators(game.cb),
		"combat": game.cb.to_dict(), "run": run.to_dict(),
		"events": game.cb.queue.duplicate(true),
		"enemyHistory": _enemy_history(game.cb),
		"enemyFlags": _enemy_flags(game.cb, false),
		"enemyFlagsWithoutMediator": _enemy_flags(game.cb, true),
		"projectionHasMediator": JSON.stringify(game.cb.to_dict()).contains(MEDIATOR_KEY),
	}


func _prepare(game: GlassvowGame, scenario: Dictionary) -> void:
	var cb: CombatState = game.cb
	var run: RunState = game.run
	cb.queue.clear()
	cb.turn = _int(scenario, "turn")
	cb.over = false
	cb.result = ""
	cb.embers = _int(scenario, "embers")
	cb.ember_cap = 9
	cb.hand.clear()
	cb.draw.clear()
	cb.discard.clear()
	cb.exhaust.clear()
	cb.pending_chips_active = false
	cb.pending_chips.clear()
	cb.first_card_played = false
	cb.counters_played = 0
	cb.counters_attacks = 0
	cb.player.hp = 500
	cb.player.max_hp = 500
	cb.player.block = 0
	cb.player.energy = 99
	cb.player.energy_max = 99
	cb.player.statuses.clear()
	run.player.hp = 500
	run.player.max_hp = 500
	var histories_v: Variant = scenario.get("histories", [])
	var histories: Array = histories_v if typeof(histories_v) == TYPE_ARRAY else []
	for i: int in range(cb.enemies.size()):
		var enemy: EnemyCombatant = cb.enemies[i]
		enemy.hp = _int(scenario, "targetHp") if i == 0 and scenario.has("targetHp") else 500
		enemy.max_hp = 500
		enemy.block = 0
		enemy.chips = 0
		enemy.facet_max = 99
		enemy.statuses.clear()
		enemy.staggered = false
		enemy.last_moves.clear()
		var history_v: Variant = histories[i] if i < histories.size() else []
		var history: Array = history_v if typeof(history_v) == TYPE_ARRAY else []
		for move_v: Variant in history:
			enemy.last_moves.append(str(move_v))
		enemy.move_key = &""
		enemy.flags.erase(MEDIATOR_KEY)
		enemy.flags["_probeSentinel"] = "keep"


func _add_cards(run: RunState, cb: CombatState, ids_v: Variant) -> void:
	var ids: Array = ids_v if typeof(ids_v) == TYPE_ARRAY else []
	for id_v: Variant in ids:
		cb.hand.append(CardInst.new(run.next_uid(), StringName(str(id_v)), false))


func _play(game: GlassvowGame, hand_index: int, target: Variant) -> Variant:
	if hand_index < 0 or hand_index >= game.cb.hand.size():
		return null
	var card: CardInst = game.cb.hand[hand_index]
	var action: Dictionary = {"t": "playCard", "uid": card.uid}
	if target != null:
		action["target"] = target
	game.apply(action)
	return game.last_ret


func _run_injected(index: int, seed: int) -> Dictionary:
	var kinds: Array[String] = [
		"stale-play", "missing-play", "malformed-play",
		"move-mismatch-play", "malformed-before-ai",
	]
	var kind: String = kinds[index]
	var content: ContentDB = ContentDB.load_full(false)
	var run: RunState = RunState.new_run(
		content, seed, "research421-intent-injected-%s" % kind, {"aspect": 0}
	)
	run.player.relics.clear()
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": ["ashAcolyte"], "kind": "normal"})
	var cb: CombatState = game.cb
	cb.queue.clear()
	cb.turn = 3
	cb.over = false
	cb.result = ""
	cb.embers = 0
	cb.hand.clear()
	cb.draw.clear()
	cb.discard.clear()
	cb.exhaust.clear()
	cb.player.hp = 500
	cb.player.max_hp = 500
	cb.player.energy = 99
	cb.player.energy_max = 99
	run.player.hp = 500
	run.player.max_hp = 500
	var enemy: EnemyCombatant = cb.enemies[0]
	enemy.hp = 500
	enemy.max_hp = 500
	enemy.move_key = &"scorch"
	enemy.last_moves = ["ritual", "scorch"]
	enemy.flags.erase(MEDIATOR_KEY)
	var action_return: Variant = null
	if kind == "stale-play":
		enemy.flags[MEDIATOR_KEY] = {"move": "scorch", "createdTurn": 2}
	elif kind == "malformed-play" or kind == "malformed-before-ai":
		enemy.flags[MEDIATOR_KEY] = "bad"
	elif kind == "move-mismatch-play":
		enemy.flags[MEDIATOR_KEY] = {"move": "ritual", "createdTurn": 3}
	if kind == "malformed-before-ai":
		cb.turn = 2
		game.rules.call("_compute_intents", run, cb)
	else:
		_add_cards(run, cb, ["strike"])
		action_return = _play(game, 0, 0)
	return {
		"source": "candidate", "arm": "ab", "scenario": "injected-%s" % kind,
		"seed": seed, "policyIdentity": "direct-no-policy-v1",
		"actionReturns": [action_return], "rngState": run.rng_state(),
		"mediators": _mediators(cb), "combat": cb.to_dict(), "run": run.to_dict(),
		"events": cb.queue.duplicate(true), "enemyHistory": _enemy_history(cb),
		"enemyFlags": _enemy_flags(cb, false),
		"enemyFlagsWithoutMediator": _enemy_flags(cb, true),
		"projectionHasMediator": JSON.stringify(cb.to_dict()).contains(MEDIATOR_KEY),
	}


func _mediators(cb: CombatState) -> Array:
	var out: Array = []
	for enemy: EnemyCombatant in cb.enemies:
		var value: Variant = enemy.flags.get(MEDIATOR_KEY)
		if value != null:
			out.append({"idx": enemy.idx, "value": value})
	return out


func _enemy_flags(cb: CombatState, strip_mediator: bool) -> Array:
	var out: Array = []
	for enemy: EnemyCombatant in cb.enemies:
		var flags: Dictionary = enemy.flags.duplicate(true)
		if strip_mediator:
			flags.erase(MEDIATOR_KEY)
		out.append({"idx": enemy.idx, "flags": flags})
	return out


func _enemy_history(cb: CombatState) -> Array:
	var out: Array = []
	for enemy: EnemyCombatant in cb.enemies:
		out.append({
			"idx": enemy.idx, "hp": enemy.hp, "move": String(enemy.move_key),
			"lastMoves": enemy.last_moves.duplicate(), "staggered": enemy.staggered,
		})
	return out


static func _int(values: Dictionary, key: String) -> int:
	var value: Variant = values.get(key, 0)
	return value if typeof(value) == TYPE_INT else int(float(str(value)))


func _emit(row: Dictionary) -> void:
	print(ROW_MARKER + JSON.stringify(row))


func _fail(message: String) -> void:
	push_error("research_421_intent_history_probe_v1: %s" % message)
	quit(2)
