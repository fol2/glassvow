extends SceneTree
## Deterministic, research-only legal combat probe for issue #421.

const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const Policy: GDScript = preload("res://tools/balance_policy.gd")
const Sim: GDScript = preload("res://tools/balance_sim.gd")


func _initialize() -> void:
	var opts: Dictionary = _options(OS.get_cmdline_user_args())
	if opts.has("error"):
		push_error("research_421_probe: %s" % str(opts["error"]))
		quit(2)
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(opts["plan"])))
	if typeof(raw) != TYPE_DICTIONARY:
		push_error("research_421_probe: plan must be a dictionary")
		quit(2)
		return
	var plan: Dictionary = raw
	var rows_v: Variant = plan.get("rows", [])
	if typeof(rows_v) != TYPE_ARRAY:
		push_error("research_421_probe: plan rows must be an array")
		quit(2)
		return
	var loaded: Dictionary = BalanceCatalogue.open({"content": str(plan.get("content", ""))})
	if loaded.has("error"):
		push_error("research_421_probe: %s" % str(loaded["error"]))
		quit(2)
		return
	var content: ContentDB = BalanceCatalogue.load_prepared(loaded)
	if content == null:
		push_error("research_421_probe: content did not load a catalogue")
		quit(2)
		return
	var pilot_fault: String = _pilot_self_check(content)
	if not pilot_fault.is_empty():
		push_error("research_421_probe: %s" % pilot_fault)
		quit(2)
		return
	var rows: Array = []
	for spec_v: Variant in rows_v:
		if typeof(spec_v) != TYPE_DICTIONARY:
			push_error("research_421_probe: every row must be a dictionary")
			quit(2)
			return
		var spec: Dictionary = spec_v
		var row: Dictionary = _run(content, spec)
		if not str(row.get("error", "")).is_empty():
			push_error("research_421_probe: %s: %s" % [str(spec.get("id", "?")), row["error"]])
			quit(2)
			return
		rows.append(row)
	var output: Dictionary = {
		"schemaVersion": 1,
		"planSha256": FileAccess.get_sha256(str(opts["plan"])),
		"runnerSha256": FileAccess.get_sha256(str(get_script().resource_path)),
		"contentIdentity": loaded["identity"],
		"rows": rows,
	}
	var file: FileAccess = FileAccess.open(str(opts["out"]), FileAccess.WRITE)
	if file == null:
		push_error("research_421_probe: cannot write --out")
		quit(2)
		return
	file.store_string(JSON.stringify(output) + "\n")
	print(JSON.stringify({"status": "PASS", "rows": rows.size()}))
	quit(0)


func _pilot_self_check(content: ContentDB) -> String:
	if not content.cards.has("chisel") or not content.cards.has("executioner"):
		return ""
	Pilot.apply_policy({"card": {"aspectBonus": 7.0}})
	var deck: Array = [CardInst.new(1, &"chisel", false)]
	var consumer: Dictionary = content.cards.get("executioner", {})
	var dusk_base: float = Pilot.card_score(consumer, 0, "executioner")
	var completion_bonus: float = float(str(
		Pilot.card_reward_score(consumer, 0, "executioner", deck))) - dusk_base
	if not is_equal_approx(completion_bonus, 28.0):
		return "planned build did not apply the frozen package-completion multiplier"
	var ash_base: float = Pilot.card_score(consumer, 1, "executioner")
	if Pilot.card_reward_score(consumer, 1, "executioner", deck) != ash_base:
		return "package-completion value crossed the aspect boundary"
	Pilot.apply_policy({"card": {"aspectBonus": 7.0}})
	var research_fault: String = Pilot.set_research421({"acquisitionPriority": 2.0})
	if not research_fault.is_empty():
		return research_fault
	completion_bonus = float(str(
		Pilot.card_reward_score(consumer, 0, "executioner", deck))) - dusk_base
	if not is_equal_approx(completion_bonus, 14.0):
		return "research acquisition priority did not reach card reward scoring"
	return ""


func _run(content: ContentDB, spec: Dictionary) -> Dictionary:
	var aspect_name: String = str(spec.get("aspect", "duskblade"))
	var aspect: int = 1 if aspect_name == "ashwarden" else 0
	var seed: int = int(float(str(spec.get("seed", 0))))
	var policy: Dictionary = spec.get("policy", {})
	if spec.has("policyRoot") and spec.has("policyIndex"):
		var sampled: Array[Dictionary] = Policy.sample_range(
			int(float(str(spec["policyRoot"]))), int(float(str(spec["policyIndex"]))), 1)
		policy = sampled[0]
	var research_v: Variant = spec.get("research421", {})
	if typeof(research_v) != TYPE_DICTIONARY:
		return _error(spec, "research421 must be a dictionary")
	var research: Dictionary = research_v
	var mode: String = str(spec.get("mode", "pilot"))
	if mode == "knob-surface":
		return _knob_surface(content, spec, policy, research)
	if mode == "mirror-oath-surface":
		return _mirror_oath_surface(content, spec, policy, research)
	if mode == "package-order-surface":
		return _package_order_surface(content, spec, policy, research)
	if mode == "momentum-preference-surface":
		return _momentum_preference_surface(content, spec, policy, research)
	if mode == "whole-run":
		var trace: Dictionary = {"capture": true} \
			if spec.get("captureTrace", false) == true else {}
		var whole: Dictionary = Sim.simulate(
			content, aspect_name, seed, int(float(str(spec.get("vow", 0)))),
			PackedStringArray(), policy,
			spec.get("randomBuild", false) == true, spec.get("randomPlay", false) == true,
			{}, null, false, research, trace)
		whole["id"] = str(spec.get("id", ""))
		whole["stage"] = str(spec.get("stage", ""))
		whole["arm"] = str(spec.get("arm", ""))
		whole["policyRoot"] = int(float(str(spec.get("policyRoot", -1))))
		whole["policyIndex"] = int(float(str(spec.get("policyIndex", -1))))
		if not trace.is_empty():
			whole["trajectory"] = trace
		return whole
	var profile: Dictionary = {
		"aspect": aspect,
		"vow": int(float(str(spec.get("vow", 0)))),
		"reveals": content.reveal_ids.duplicate(),
		"unlocks": spec.get("unlocks", ["aspect2"]),
		"quests": {},
		"shards": [],
		"lamplighter": false,
	}
	var run_id: String = str(spec.get("runId", "probe-%s" % str(spec.get("id", seed))))
	var run: RunState = RunState.new_run(content, seed, run_id, profile)
	run.act = int(float(str(spec.get("act", 0))))
	run.player.deck.clear()
	for id_v: Variant in spec.get("deck", []):
		var card_id: String = str(id_v)
		if not content.cards.has(card_id):
			return _error(spec, "unknown deck card %s" % card_id)
		run.player.deck.append(CardInst.new(run.next_uid(), StringName(card_id), false))
	if run.player.deck.is_empty():
		return _error(spec, "deck must not be empty")
	run.player.relics.clear()
	for id_v: Variant in spec.get("relics", []):
		var relic_id: String = str(id_v)
		if not content.relics.has(relic_id):
			return _error(spec, "unknown relic %s" % relic_id)
		run.player.relics.append(relic_id)
	Pilot.set_ban(PackedStringArray())
	Pilot.apply_policy(policy)
	var research_fault: String = Pilot.set_research421(research)
	if not research_fault.is_empty():
		return _error(spec, research_fault)
	Pilot.set_modes(false, false)
	Sim.apply_research421(run)
	var game: GlassvowGame = GlassvowGame.new(content, run)
	var enemies_v: Variant = spec.get("enemies", ["gloomslime"])
	if typeof(enemies_v) != TYPE_ARRAY:
		return _error(spec, "enemies must be an array")
	var enemies: Array = enemies_v
	game.apply({"t": "startCombat", "enemies": enemies,
		"kind": str(spec.get("kind", "normal"))})
	if game.cb.enemies.is_empty():
		return _error(spec, "combat did not create an enemy")
	var fault: String = ""
	if mode == "crown-surface":
		return _crown_surface(game, spec)
	elif mode == "scripted":
		fault = _scripted(game, spec)
	elif mode == "pilot":
		fault = _pilot(game, int(float(str(spec.get("maxTurns", 20)))))
	else:
		fault = "unknown mode %s" % mode
	if not fault.is_empty():
		return _error(spec, fault)
	return _metrics(game, spec)


func _crown_surface(game: GlassvowGame, spec: Dictionary) -> Dictionary:
	var enemy: EnemyCombatant = game.cb.enemies[0]
	return {
		"id": str(spec.get("id", "")),
		"mode": "crown-surface",
		"policy": Pilot.policy_snapshot(),
		"research421": Pilot.research421_snapshot(),
		"relics": game.run.player.relics.duplicate(),
		"enemyFacetMax": enemy.facet_max,
		"enemyStatuses": enemy.statuses.duplicate(true),
		"queue": game.cb.queue.duplicate(true),
		"rng": game.run.rng_state(),
		"error": "",
	}


func _knob_surface(content: ContentDB, spec: Dictionary, policy: Dictionary,
		research: Dictionary) -> Dictionary:
	Pilot.set_ban(PackedStringArray())
	Pilot.apply_policy(policy)
	var research_fault: String = Pilot.set_research421(research)
	if not research_fault.is_empty():
		return _error(spec, research_fault)
	Pilot.set_modes(false, false)
	var scoreline_deck: Array = [CardInst.new(1, &"chisel", false)]
	var afterimage_deck: Array = [CardInst.new(2, &"defend", false)]
	var scoreline: Dictionary = content.cards["executioner"]
	var afterimage: Dictionary = content.cards["guardedStrike"]
	var scoreline_bonus: float = Pilot.card_reward_score(
		scoreline, 0, "executioner", scoreline_deck) \
		- Pilot.card_score(scoreline, 0, "executioner")
	var afterimage_bonus: float = Pilot.card_reward_score(
		afterimage, 0, "guardedStrike", afterimage_deck) \
		- Pilot.card_score(afterimage, 0, "guardedStrike")
	var profile: Dictionary = {"aspect": 0, "vow": 0,
		"reveals": content.reveal_ids.duplicate(), "unlocks": ["aspect2"],
		"quests": {}, "shards": [], "lamplighter": false}
	var seed: int = int(float(str(spec.get("seed", 345100))))
	var run: RunState = RunState.new_run(content, seed, "knob-surface", profile)
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": ["gravewarden"], "kind": "normal"})
	game.cb.hand.clear()
	for card_id: StringName in [&"defend", &"guardedStrike", &"strike"]:
		game.cb.hand.append(CardInst.new(run.next_uid(), card_id, false))
	game.cb.player.energy = 3
	var rng_before: int = run.rng_state()
	var combat_scores: Dictionary = {}
	var unblocked: int = Pilot._incoming(game) - game.cb.player.block
	for card: CardInst in game.cb.hand:
		var definition: Dictionary = game.rules.card_data(card)
		var target: Variant = Pilot._target(game, card, definition)
		if not game.rules.can_play(game.run, game.cb, card, target):
			continue
		var preview_v: Variant = game.rules.preview_play(game.cb, card, target, game.run)
		var preview: Dictionary = preview_v if typeof(preview_v) == TYPE_DICTIONARY else {}
		combat_scores[String(card.id)] = Pilot._combat_score(
			game, card, definition, target, preview, unblocked, true)
	var pick: Dictionary = Pilot._pick_play(game)
	var first_choice: String = ""
	for card: CardInst in game.cb.hand:
		if int(float(str(pick.get("uid", -1)))) == card.uid:
			first_choice = String(card.id)
			break
	return {
		"id": str(spec.get("id", "")),
		"mode": "knob-surface",
		"policy": Pilot.policy_snapshot(),
		"research421": Pilot.research421_snapshot(),
		"scorelineCompletionBonus": scoreline_bonus,
		"afterimageCompletionBonus": afterimage_bonus,
		"combatScores": combat_scores,
		"firstChoice": first_choice,
		"rngBeforeChoice": rng_before,
		"rngAfterChoice": run.rng_state(),
		"error": "",
	}


func _mirror_oath_surface(content: ContentDB, spec: Dictionary, policy: Dictionary,
		research: Dictionary) -> Dictionary:
	Pilot.set_ban(PackedStringArray())
	Pilot.apply_policy(policy)
	var research_fault: String = Pilot.set_research421(research)
	if not research_fault.is_empty():
		return _error(spec, research_fault)
	Pilot.set_modes(false, false)
	var aspect_name: String = str(spec.get("aspect", "duskblade"))
	var aspect: int = 1 if aspect_name == "ashwarden" else 0
	var profile: Dictionary = {"aspect": aspect, "vow": 0,
		"reveals": content.reveal_ids.duplicate(), "unlocks": ["aspect2"],
		"quests": {}, "shards": [], "lamplighter": false}
	if aspect == 0 and Pilot._research421("mirrorOathPool") > 0.0:
		profile["unlocks"].append("card:mirrorOath")
	var seed: int = int(float(str(spec.get("seed", 347000))))
	var run: RunState = RunState.new_run(content, seed, "mirror-oath-surface", profile)
	Sim.apply_research421(run)
	var game: GlassvowGame = GlassvowGame.new(content, run)
	var pool_rng_before: int = run.rng_state()
	var uncommon_pool: Array = game.rewards.card_pool(run, "uncommon")
	var pool_rng_after: int = run.rng_state()
	game.apply({"t": "startCombat", "enemies": ["gravewarden"], "kind": "normal"})
	game.cb.hand.clear()
	game.cb.draw.clear()
	game.cb.discard.clear()
	game.cb.exhaust.clear()
	game.cb.queue.clear()
	var route: String = str(spec.get("route", "afterimage"))
	var cards: Array[StringName] = []
	if route == "scoreline":
		cards.assign([&"chisel", &"executioner"])
	else:
		if spec.get("playOath", false) == true:
			cards.append(&"mirrorOath")
		cards.append(&"defend")
	for card_id: StringName in cards:
		game.cb.hand.append(CardInst.new(run.next_uid(), card_id, false))
	game.cb.player.energy = 20
	var rng_before_actions: int = run.rng_state()
	for card_id: StringName in cards:
		var card: CardInst = null
		for held: CardInst in game.cb.hand:
			if held.id == card_id:
				card = held
				break
		if card == null:
			return _error(spec, "surface card %s left the hand" % String(card_id))
		var target: Variant = 0 if str(game.rules.card_data(card).get("target", "")) == "enemy" \
			else null
		game.apply({"t": "playCard", "uid": card.uid, "target": target})
		if game.last_ret != true:
			return _error(spec, "surface card %s was not legal" % String(card_id))
	var state_before_harvest: Dictionary = _mirror_oath_state(game)
	var telemetry: Dictionary = Sim.research421_harvest_probe(game)
	var state_after_harvest: Dictionary = _mirror_oath_state(game)
	return {
		"id": str(spec.get("id", "")),
		"mode": "mirror-oath-surface",
		"route": route,
		"aspect": aspect_name,
		"policy": Pilot.policy_snapshot(),
		"research421": Pilot.research421_snapshot(),
		"unlocks": run.unlocks.duplicate(),
		"uncommonPool": uncommon_pool,
		"poolRngBefore": pool_rng_before,
		"poolRngAfter": pool_rng_after,
		"rngBeforeActions": rng_before_actions,
		"stateBeforeHarvest": state_before_harvest,
		"stateAfterHarvest": state_after_harvest,
		"telemetry": telemetry,
		"error": "",
	}


func _mirror_oath_state(game: GlassvowGame) -> Dictionary:
	var enemy: EnemyCombatant = game.cb.enemies[0]
	return {
		"rng": game.run.rng_state(),
		"playerHp": game.cb.player.hp,
		"playerBlock": game.cb.player.block,
		"playerEnergy": game.cb.player.energy,
		"playerStatuses": game.cb.player.statuses.duplicate(true),
		"enemyHp": enemy.hp,
		"enemyChips": enemy.chips,
		"enemyStatuses": enemy.statuses.duplicate(true),
		"queue": game.cb.queue.duplicate(true),
	}


func _package_order_surface(content: ContentDB, spec: Dictionary, policy: Dictionary,
		research: Dictionary) -> Dictionary:
	var pair_index: int = int(float(str(spec.get("pairIndex", -1))))
	if pair_index < 0 or pair_index >= Pilot.RESEARCH421_COMBAT_PAIRS.size():
		return _error(spec, "pairIndex is outside the registered package set")
	var pair: Dictionary = Pilot.RESEARCH421_COMBAT_PAIRS[pair_index]
	var producer: StringName = StringName(str(pair["producer"]))
	var consumer: StringName = StringName(str(pair["consumer"]))
	var mediator: StringName = StringName(str(pair["status"]))
	var preference_group: String = str(pair["preferenceGroup"])
	var preference_key: String = str(pair["preferenceKey"])
	var preference_median: float = float(str(pair["preferenceMedian"]))
	if not content.cards.has(producer) or not content.cards.has(consumer):
		return _error(spec, "registered package card is absent from content")
	Pilot.set_ban(PackedStringArray())
	Pilot.apply_policy(policy)
	var research_fault: String = Pilot.set_research421(research)
	if not research_fault.is_empty():
		return _error(spec, research_fault)
	Pilot.set_modes(false, false)
	var aspect: int = int(float(str(pair["aspect"])))
	var profile: Dictionary = {"aspect": aspect, "vow": 0,
		"reveals": content.reveal_ids.duplicate(), "unlocks": ["aspect2"],
		"quests": {}, "shards": [], "lamplighter": false}
	var seed: int = int(float(str(spec.get("seed", 345200))))
	var run: RunState = RunState.new_run(content, seed, "package-order-surface", profile)
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": ["gravewarden"], "kind": "normal"})
	game.cb.hand.clear()
	for card_id: StringName in [producer, consumer, &"strike"]:
		game.cb.hand.append(CardInst.new(run.next_uid(), card_id, false))
	game.cb.player.energy = 3
	var mediator_present: bool = spec.get("mediatorPresent", false) == true
	var statuses: Dictionary = game.cb.player.statuses if pair["onPlayer"] == true \
		else game.cb.enemies[0].statuses
	if mediator_present:
		statuses[mediator] = 1
	var rng_before: int = run.rng_state()
	var combat_scores: Dictionary = {}
	var unblocked: int = Pilot._incoming(game) - game.cb.player.block
	for card: CardInst in game.cb.hand:
		var definition: Dictionary = game.rules.card_data(card)
		var target: Variant = Pilot._target(game, card, definition)
		if not game.rules.can_play(game.run, game.cb, card, target):
			continue
		var preview_v: Variant = game.rules.preview_play(game.cb, card, target, game.run)
		var preview: Dictionary = preview_v if typeof(preview_v) == TYPE_DICTIONARY else {}
		combat_scores[String(card.id)] = Pilot._combat_score(
			game, card, definition, target, preview, unblocked, aspect == 0)
	var pick: Dictionary = Pilot._pick_play(game)
	var first_choice: String = ""
	for card: CardInst in game.cb.hand:
		if int(float(str(pick.get("uid", -1)))) == card.uid:
			first_choice = String(card.id)
			break
	var establishes_mediator: bool = false
	for effect_v: Variant in content.cards[producer].get("effects", []):
		var effect: Dictionary = effect_v
		if str(effect.get("kind", "")) == "status" \
				and str(effect.get("id", "")) == String(mediator):
			establishes_mediator = true
			break
	return {
		"id": str(spec.get("id", "")),
		"mode": "package-order-surface",
		"pairIndex": pair_index,
		"producer": String(producer),
		"consumer": String(consumer),
		"mediator": String(mediator),
		"preferenceGroup": preference_group,
		"preferenceKey": preference_key,
		"preferenceMedian": preference_median,
		"preferenceValue": Pilot._w(preference_group, preference_key),
		"policyEligible": Pilot._package_order_policy_prefers(pair),
		"mediatorPresent": mediator_present,
		"producerEstablishesMediator": establishes_mediator,
		"policy": Pilot.policy_snapshot(),
		"research421": Pilot.research421_snapshot(),
		"combatScores": combat_scores,
		"firstChoice": first_choice,
		"rngBeforeChoice": rng_before,
		"rngAfterChoice": run.rng_state(),
		"error": "",
	}


func _momentum_preference_surface(content: ContentDB, spec: Dictionary, policy: Dictionary,
		research: Dictionary) -> Dictionary:
	Pilot.set_ban(PackedStringArray())
	Pilot.apply_policy(policy)
	var research_fault: String = Pilot.set_research421(research)
	if not research_fault.is_empty():
		return _error(spec, research_fault)
	Pilot.set_modes(false, false)
	var dusk_scores: Dictionary = {}
	var ash_scores: Dictionary = {}
	for id_v: Variant in content.cards.keys():
		var id: String = str(id_v)
		var definition: Dictionary = content.cards[id_v]
		dusk_scores[id] = Pilot.card_score(definition, 0, id)
		ash_scores[id] = Pilot.card_score(definition, 1, id)
	return {
		"id": str(spec.get("id", "")),
		"mode": "momentum-preference-surface",
		"policy": Pilot.policy_snapshot(),
		"research421": Pilot.research421_snapshot(),
		"executePreference": Pilot._w("special", "execute"),
		"momentumPreference": Pilot._w("special", "shatterEchoDusk") \
			if Pilot._research421("momentumPolicyPreference") > 0.0 \
			else Pilot._w("special", "execute"),
		"duskCardScores": dusk_scores,
		"ashCardScores": ash_scores,
		"error": "",
	}


func _scripted(game: GlassvowGame, spec: Dictionary) -> String:
	var actions_v: Variant = spec.get("actions", [])
	if typeof(actions_v) != TYPE_ARRAY:
		return "actions must be an array"
	var actions: Array = actions_v
	game.cb.hand.clear()
	game.cb.draw.clear()
	game.cb.discard.clear()
	game.cb.exhaust.clear()
	for action_v: Variant in actions:
		var action: Dictionary = action_v
		if str(action.get("command", "")) == "endTurn":
			continue
		var card_id: String = str(action.get("card", ""))
		if not game.content.cards.has(card_id):
			return "unknown action card %s" % card_id
		var upgraded: bool = action.get("up", false) == true
		game.cb.hand.append(CardInst.new(game.run.next_uid(), StringName(card_id), upgraded))
	for filler_v: Variant in spec.get("handFill", []):
		var filler: String = str(filler_v)
		if not game.content.cards.has(filler):
			return "unknown hand filler %s" % filler
		game.cb.hand.append(CardInst.new(game.run.next_uid(), StringName(filler), false))
	for draw_v: Variant in spec.get("drawFill", []):
		var draw_id: String = str(draw_v)
		if not game.content.cards.has(draw_id):
			return "unknown draw filler %s" % draw_id
		game.cb.draw.append(CardInst.new(game.run.next_uid(), StringName(draw_id), false))
	var setup_v: Variant = spec.get("setup", {})
	var setup: Dictionary = setup_v if typeof(setup_v) == TYPE_DICTIONARY else {}
	game.cb.player.energy = int(float(str(setup.get("energy", 20))))
	game.cb.player.block = int(float(str(setup.get("block", game.cb.player.block))))
	game.cb.embers = clampi(int(float(str(setup.get("embers", game.cb.embers)))), 0, game.cb.ember_cap)
	game.cb.player.hp = clampi(int(float(str(setup.get("playerHp", game.cb.player.hp)))),
		0, game.cb.player.max_hp)
	_apply_statuses(game.cb.player.statuses, setup.get("playerStatus", {}))
	var enemy: EnemyCombatant = game.cb.enemies[0]
	_apply_statuses(enemy.statuses, setup.get("enemyStatus", {}))
	if setup.has("enemyHp"):
		enemy.hp = clampi(int(float(str(setup["enemyHp"]))), 1, enemy.max_hp)
	if setup.has("enemyChipsFromMax"):
		enemy.chips = maxi(0, enemy.facet_max + int(float(str(setup["enemyChipsFromMax"]))))
	if setup.get("enemyStaggered", false) == true:
		enemy.staggered = true
	for action_v: Variant in actions:
		var action: Dictionary = action_v
		if str(action.get("command", "")) == "endTurn":
			if not game.cb.over:
				game.apply({"t": "endTurn"})
			continue
		var card_id: StringName = StringName(str(action["card"]))
		var card: CardInst = null
		for held: CardInst in game.cb.hand:
			if held.id == card_id:
				card = held
				break
		if card == null:
			return "scripted card %s is no longer in hand" % String(card_id)
		var target: Variant = action.get("target")
		if target == null and str(game.rules.card_data(card).get("target", "")) == "enemy":
			target = 0
		game.apply({"t": "playCard", "uid": card.uid, "target": target})
		if game.last_ret != true:
			return "scripted card %s was not legal" % String(card_id)
		if game.cb.over:
			break
	return ""


func _pilot(game: GlassvowGame, max_turns: int) -> String:
	if max_turns < 1 or max_turns > 30:
		return "maxTurns must be 1..30"
	while not game.cb.over:
		Pilot.play_turn(game)
		if game.cb.over or game.cb.turn >= max_turns:
			break
		game.apply({"t": "endTurn"})
	return ""


func _metrics(game: GlassvowGame, spec: Dictionary) -> Dictionary:
	var totals: Dictionary = {
		"damage": 0, "directDamage": 0, "poisonDamage": 0, "blockGain": 0,
		"heal": 0, "draw": 0, "poisonApplied": 0, "vulnerableApplied": 0,
		"emberGain": 0, "emberSpent": 0, "shatter": 0, "kindle": 0,
		"exhaust": 0, "relicProc": 0,
	}
	var cards: Dictionary = {}
	var relics: Dictionary = {}
	var last_play: String = ""
	var peak_block: int = game.cb.player.block
	for event_v: Variant in game.cb.queue:
		var event: Dictionary = event_v
		var kind: String = str(event.get("t", ""))
		if kind == "play":
			last_play = str(event.get("id", ""))
			_bump_nested(cards, last_play, "play", 1)
		elif kind == "hitEnemy":
			var amount: int = maxi(0, int(float(str(event.get("amount", 0)))))
			_bump(totals, "damage", amount)
			if event.get("poison", false) == true:
				_bump(totals, "poisonDamage", amount)
			else:
				_bump(totals, "directDamage", amount)
				_bump_nested(cards, last_play, "damage", amount)
		elif kind == "blockGain" and str(event.get("who", "")) == "player":
			var amount: int = maxi(0, int(float(str(event.get("n", 0)))))
			_bump(totals, "blockGain", amount)
			_bump_nested(cards, last_play, "block", amount)
			peak_block = maxi(peak_block, int(float(str(event.get("total", 0)))))
		elif kind == "heal" and str(event.get("who", "")) == "player":
			var amount: int = maxi(0, int(float(str(event.get("n", 0)))))
			_bump(totals, "heal", amount)
			_bump_nested(cards, last_play, "heal", amount)
		elif kind == "draw":
			_bump(totals, "draw", 1)
			_bump_nested(cards, last_play, "draw", 1)
		elif kind == "status":
			var amount: int = int(float(str(event.get("n", 0))))
			var status_id: String = str(event.get("id", ""))
			if amount > 0 and status_id == "poison":
				_bump(totals, "poisonApplied", amount)
			elif amount > 0 and status_id == "vulnerable":
				_bump(totals, "vulnerableApplied", amount)
			_bump_nested(cards, last_play, "status:%s" % status_id, amount)
		elif kind == "ember":
			var amount: int = int(float(str(event.get("n", 0))))
			if amount > 0:
				_bump(totals, "emberGain", amount)
			else:
				_bump(totals, "emberSpent", -amount)
			_bump_nested(cards, last_play, "ember", amount)
		elif kind == "shatter":
			_bump(totals, "shatter", 1)
			_bump_nested(cards, last_play, "shatter", 1)
		elif kind == "kindle":
			_bump(totals, "kindle", 1)
		elif kind == "exhaust":
			_bump(totals, "exhaust", 1)
		elif kind == "relicProc":
			var relic_id: String = str(event.get("id", ""))
			_bump(totals, "relicProc", 1)
			_bump(relics, relic_id, 1)
		elif kind in ["turn", "endTurn", "enemyAct", "toDiscard", "powerConsumed"]:
			last_play = ""
	var enemy_hp: int = 0
	for enemy: EnemyCombatant in game.cb.enemies:
		enemy_hp += maxi(0, enemy.hp)
	var result: Dictionary = {
		"id": str(spec.get("id", "")),
		"stage": str(spec.get("stage", "")),
		"package": str(spec.get("package", "")),
		"edge": str(spec.get("edge", "")),
		"arm": str(spec.get("arm", "")),
		"split": str(spec.get("split", "")),
		"context": str(spec.get("context", "")),
		"aspect": str(spec.get("aspect", "duskblade")),
		"seed": int(float(str(spec.get("seed", 0)))),
		"response": str(spec.get("response", "damage")),
		"outcome": game.cb.result if game.cb.over else "stall",
		"turns": game.cb.turn,
		"hpLost": game.cb.hp_lost,
		"endingHp": game.cb.player.hp,
		"endingBlock": game.cb.player.block,
		"peakBlock": peak_block,
		"enemyHpRemaining": enemy_hp,
		"rng": game.run.rng_state(),
		"totals": totals,
		"cards": cards,
		"relics": relics,
		"error": "",
	}
	if spec.get("captureTrace", false) == true:
		result["trajectory"] = _local_trajectory(game)
	return result


func _local_trajectory(game: GlassvowGame) -> Array[Dictionary]:
	var trace: Array[Dictionary] = []
	for event_v: Variant in game.cb.queue:
		var event: Dictionary = event_v
		var row: Dictionary = {"t": str(event.get("t", ""))}
		for key: String in ["id", "n", "amount", "who", "target", "dead"]:
			if event.has(key):
				row[key] = str(event[key]) if typeof(event[key]) == TYPE_STRING_NAME \
					else event[key]
		trace.append(row)
	return trace


func _apply_statuses(target: Dictionary, values_v: Variant) -> void:
	if typeof(values_v) != TYPE_DICTIONARY:
		return
	var values: Dictionary = values_v
	for key_v: Variant in values:
		target[str(key_v)] = int(float(str(values[key_v])))


func _bump(values: Dictionary, key: String, amount: int) -> void:
	values[key] = int(float(str(values.get(key, 0)))) + amount


func _bump_nested(values: Dictionary, outer: String, inner: String, amount: int) -> void:
	if outer.is_empty():
		return
	var row_v: Variant = values.get(outer, {})
	var row: Dictionary = row_v if typeof(row_v) == TYPE_DICTIONARY else {}
	_bump(row, inner, amount)
	values[outer] = row


func _error(spec: Dictionary, message: String) -> Dictionary:
	return {"id": str(spec.get("id", "")), "error": message}


func _options(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {"plan": "", "out": ""}
	for arg: String in args:
		if not arg.begins_with("--") or not arg.contains("="):
			return {"error": "expected --name=value, got %s" % arg}
		var key: String = arg.get_slice("=", 0).trim_prefix("--")
		if not out.has(key):
			return {"error": "unknown option --%s" % key}
		out[key] = arg.substr(arg.find("=") + 1)
	if str(out["plan"]).is_empty() or str(out["out"]).is_empty():
		return {"error": "--plan and --out are required"}
	return out
