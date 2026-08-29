extends SceneTree
## Frozen direct probe for #421 cross-turn hold. It emits observations only;
## the preregistered Python runner owns every assertion and decision.

const ROW_MARKER: String = "RESEARCH421_CROSS_TURN_HOLD_ROW "
const DRAW_IDS: Array[String] = [
	"defend", "aegis", "fortify", "deflect", "defend", "aegis",
	"fortify", "deflect", "defend", "aegis", "fortify", "deflect",
]
const SCENARIOS: Array[Dictionary] = [
	{"id": "valid-play", "aspect": 0, "embers": 0,
		"hand": ["defend", "strike", "heavyBlow"], "action": "play-held"},
	{"id": "cap-play", "aspect": 0, "embers": 9,
		"hand": ["defend", "strike", "heavyBlow"], "action": "play-held"},
	{"id": "ash-null", "aspect": 1, "embers": 0,
		"hand": ["defend", "strike"], "action": "none"},
	{"id": "no-attack-null", "aspect": 0, "embers": 0,
		"hand": ["defend", "aegis"], "action": "none"},
	{"id": "same-id-other-uid", "aspect": 0, "embers": 0,
		"hand": ["defend", "strike", "heavyBlow"], "action": "play-other-uid"},
	{"id": "kindle-held", "aspect": 0, "embers": 0,
		"hand": ["defend", "strike", "heavyBlow"], "action": "kindle-held"},
	{"id": "next-end-expiry", "aspect": 0, "embers": 0,
		"hand": ["defend", "strike", "heavyBlow"], "action": "end-again"},
	{"id": "defeat-expiry", "aspect": 0, "embers": 0,
		"hand": ["defend", "strike", "heavyBlow"], "action": "terminal-loss"},
	{"id": "victory-expiry", "aspect": 0, "embers": 0,
		"hand": ["defend", "strike", "heavyBlow"], "action": "terminal-win"},
]


func _initialize() -> void:
	var source: String = _source_arg()
	var available: bool = _interface_available()
	if source != "baseline" and source != "candidate":
		push_error("cross-turn hold probe: expected --source=baseline|candidate")
		quit(2)
		return
	if available != (source == "candidate"):
		push_error("cross-turn hold probe: source/interface identity mismatch")
		quit(2)
		return
	var arms: Array[String] = ["baseline"]
	if source == "candidate":
		# Omitted must be first: it proves the static defaults without calling the interface.
		arms = ["omitted", "off", "a", "b", "ab"]
	for arm: String in arms:
		for index: int in range(SCENARIOS.size()):
			_configure(arm)
			_emit(_run_core(source, arm, SCENARIOS[index], 421300 + index))
	if source == "candidate":
		_configure("ab")
		_emit(_run_injected("stale-play", 421390))
		_configure("ab")
		_emit(_run_injected("missing-at-turn-start", 421391))
		_configure("ab")
		_emit(_run_injected("malformed-at-turn-start", 421392))
	quit(0)


func _source_arg() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):
			return arg.trim_prefix("--source=")
	return ""


func _interface_available() -> bool:
	var script: Script = load("res://domain/rules/combat.gd")
	return script.has_method("configure_research421_cross_turn_hold")


func _configure(arm: String) -> void:
	if arm == "baseline" or arm == "omitted":
		return
	var script: Script = load("res://domain/rules/combat.gd")
	script.call(
		"configure_research421_cross_turn_hold",
		arm == "a" or arm == "ab",
		arm == "b" or arm == "ab"
	)


func _run_core(
	source: String, arm: String, scenario: Dictionary, seed: int
) -> Dictionary:
	var content: ContentDB = ContentDB.load_full(false)
	var aspect: int = int(float(str(scenario.get("aspect", 0))))
	var run: RunState = RunState.new_run(
		content, seed, "research421-hold-%s-%s" % [arm, str(scenario["id"])],
		{"aspect": aspect}
	)
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
	var cb: CombatState = game.cb
	_prepare_combat(game, scenario)
	var first_attack_uid: int = _first_attack_uid(game)
	var before_rng: int = run.rng_state()
	game.apply({"t": "endTurn"})
	var after_end: Dictionary = {
		"combat": cb.to_dict(),
		"mediator": _mediator(cb),
		"events": cb.queue.duplicate(true),
		"rngState": run.rng_state(),
	}
	var action: String = str(scenario.get("action", "none"))
	var action_uid: int = first_attack_uid
	var action_ret: Variant = null
	match action:
		"play-held":
			game.apply({"t": "playCard", "uid": first_attack_uid, "target": 0})
			action_ret = game.last_ret
		"play-other-uid":
			action_uid = _other_strike_uid(cb, first_attack_uid)
			game.apply({"t": "playCard", "uid": action_uid, "target": 0})
			action_ret = game.last_ret
		"kindle-held":
			action_ret = game.rules.kindle_from_hand(run, cb, first_attack_uid)
		"end-again":
			cb.enemies[0].staggered = true
			game.apply({"t": "endTurn"})
		"terminal-loss":
			game.rules.lose_combat(run, cb)
			action_ret = true
		"terminal-win":
			game.rules.call("_win_combat", run, cb)
			action_ret = true
		"none":
			pass
		_:
			push_error("cross-turn hold probe: unknown action %s" % action)
	return {
		"source": source,
		"arm": arm,
		"scenario": str(scenario["id"]),
		"seed": seed,
		"policyIdentity": "direct-no-policy-v1",
		"firstAttackUid": first_attack_uid,
		"action": action,
		"actionUid": action_uid,
		"actionRet": action_ret,
		"beforeRngState": before_rng,
		"afterEnd": after_end,
		"combat": cb.to_dict(),
		"run": run.to_dict(),
		"events": cb.queue.duplicate(true),
		"mediator": _mediator(cb),
		"snapshotHasMediator": cb.to_dict().has("research421CrossTurnHold") \
			or cb.to_dict().has("research421_cross_turn_hold"),
		"rngState": run.rng_state(),
	}


func _prepare_combat(game: GlassvowGame, scenario: Dictionary) -> void:
	var cb: CombatState = game.cb
	var run: RunState = game.run
	cb.queue = []
	cb.turn = 1
	cb.over = false
	cb.result = ""
	cb.embers = int(float(str(scenario.get("embers", 0))))
	cb.ember_cap = 9
	var hand_ids: Array = scenario.get("hand", [])
	cb.hand = _cards(run, hand_ids)
	var draw_ids: Array = DRAW_IDS.duplicate()
	if str(scenario.get("id", "")) == "same-id-other-uid":
		draw_ids[draw_ids.size() - 1] = "strike"
	cb.draw = _cards(run, draw_ids)
	cb.discard = []
	cb.exhaust = []
	cb.player.hp = 500
	cb.player.max_hp = 500
	cb.player.block = 0
	cb.player.energy = 3
	cb.player.energy_max = 3
	cb.player.statuses = {}
	run.player.hp = 500
	run.player.max_hp = 500
	var enemy: EnemyCombatant = cb.enemies[0]
	enemy.hp = 500
	enemy.max_hp = 500
	enemy.block = 0
	enemy.chips = 0
	enemy.facet_max = 99
	enemy.statuses = {}
	enemy.staggered = true


func _cards(run: RunState, ids: Array) -> Array[CardInst]:
	var out: Array[CardInst] = []
	for id_v: Variant in ids:
		out.append(CardInst.new(run.next_uid(), StringName(str(id_v)), false))
	return out


func _first_attack_uid(game: GlassvowGame) -> int:
	for card: CardInst in game.cb.hand:
		if str(game.rules.card_data(card).get("type", "")) == "attack":
			return card.uid
	return 0


func _other_strike_uid(cb: CombatState, excluded_uid: int) -> int:
	for card: CardInst in cb.hand:
		if card.id == &"strike" and card.uid != excluded_uid:
			return card.uid
	return 0


func _mediator(cb: CombatState) -> Dictionary:
	for property: Dictionary in cb.get_property_list():
		if str(property.get("name", "")) == "research421_cross_turn_hold":
			var value_v: Variant = cb.get("research421_cross_turn_hold")
			if typeof(value_v) == TYPE_DICTIONARY:
				var value: Dictionary = value_v
				return value.duplicate(true)
	return {}


func _run_injected(kind: String, seed: int) -> Dictionary:
	var content: ContentDB = ContentDB.load_full(false)
	var run: RunState = RunState.new_run(
		content, seed, "research421-hold-injected-%s" % kind, {"aspect": 0}
	)
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
	var cb: CombatState = game.cb
	cb.queue = []
	cb.over = false
	cb.result = ""
	cb.draw = _cards(run, DRAW_IDS.duplicate())
	cb.discard = []
	cb.exhaust = []
	cb.player.hp = 500
	cb.player.max_hp = 500
	cb.player.energy = 3
	cb.player.energy_max = 3
	cb.player.statuses = {}
	run.player.hp = 500
	run.player.max_hp = 500
	var card: CardInst = CardInst.new(run.next_uid(), &"strike", false)
	var action_ret: Variant = null
	if kind == "stale-play":
		cb.turn = 2
		cb.hand = [card]
		cb.set("research421_cross_turn_hold", {
			"uid": card.uid, "cardId": "strike", "createdTurn": 0,
		})
		action_ret = game.rules.play_card(run, cb, card.uid, 0)
	else:
		cb.turn = 1
		cb.hand = _cards(run, ["defend"])
		cb.set("research421_cross_turn_hold", {
			"uid": 999999 if kind == "missing-at-turn-start" else 0,
			"cardId": "strike" if kind == "missing-at-turn-start" else "",
			"createdTurn": 1,
		})
		game.rules.call("_start_player_turn", run, cb)
	return {
		"source": "candidate",
		"arm": "ab",
		"scenario": "injected-%s" % kind,
		"seed": seed,
		"policyIdentity": "direct-no-policy-v1",
		"actionRet": action_ret,
		"combat": cb.to_dict(),
		"run": run.to_dict(),
		"events": cb.queue.duplicate(true),
		"mediator": _mediator(cb),
		"snapshotHasMediator": cb.to_dict().has("research421CrossTurnHold") \
			or cb.to_dict().has("research421_cross_turn_hold"),
		"rngState": run.rng_state(),
	}


func _emit(row: Dictionary) -> void:
	print(ROW_MARKER + JSON.stringify(row))
