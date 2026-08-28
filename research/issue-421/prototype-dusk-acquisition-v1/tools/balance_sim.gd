class_name BalanceSim
extends SceneTree
## Domain-only whole runs: all reveals, no quests or cross-run side state.
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const Policy: GDScript = preload("res://tools/balance_policy.gd")
const Metrics: GDScript = preload("res://tools/balance_metrics.gd")
const Incentives: GDScript = preload("res://tools/vow_incentives.gd")
const PROFILE: String = "mature-three-act-no-side-state-v1"
static var _probe: Dictionary = {}
func _initialize() -> void:
	var opts: Dictionary = _options(OS.get_cmdline_user_args())
	if opts.has("error"):
		push_error("balance_sim: %s" % opts["error"])
		quit(2)
		return
	var loaded: Dictionary = BalanceCatalogue.open(opts)
	if loaded.has("error"):
		push_error("balance_sim: %s" % loaded["error"])
		quit(2)
		return
	var identity_v: Variant = loaded["identity"]
	if typeof(identity_v) != TYPE_DICTIONARY:
		push_error("balance_sim: missing catalogue identity")
		quit(2)
		return
	var identity: Dictionary = identity_v
	var content: ContentDB = BalanceCatalogue.load_prepared(loaded)
	if content == null:
		push_error("balance_sim: content did not load a catalogue")
		quit(2)
		return
	var overlay: String = str(opts["mobs"])
	if not overlay.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(overlay))
		var faults: PackedStringArray = content.apply_enemy_overrides(raw)
		if not faults.is_empty():
			push_error("balance_sim: invalid --mobs: %s" % faults[0])
			quit(2)
			return
	var rows: Array[Dictionary] = []
	var aspects: Array[String] = [str(opts["aspect"])]
	if aspects[0] == "all":
		aspects = ["duskblade", "ashwarden"]
	var ban: PackedStringArray = PackedStringArray()
	for id: String in str(opts["ban"]).split(",", false):
		if not id.is_empty():
			ban.append(id)
	for aspect: String in aspects:
		for offset: int in range(int(float(str(opts["runs"])))):
			rows.append(simulate(content, aspect, int(float(str(opts["seed0"]))) + offset,
				int(float(str(opts["vow"]))), ban, _policy(opts), false, false, _mix(opts)))
	var report: Dictionary = Metrics.report(rows, _manifest(opts, overlay, identity))
	if rows.size() == 1:
		report["outcomeDigest"] = outcome_digest(rows[0])
	var text: String = JSON.stringify(report)
	if str(opts["out"]).is_empty():
		print(text)
	else:
		var file: FileAccess = FileAccess.open(str(opts["out"]), FileAccess.WRITE)
		if file == null:
			push_error("balance_sim: cannot write --out")
			quit(2)
			return
		file.store_string(text + "\n")
		print(JSON.stringify({"calibration": report["calibration"], "summary": report["summary"]}))
	quit(0)
static func simulate(content: ContentDB, aspect: String, seed: int, vow: int = 0,
		ban: PackedStringArray = PackedStringArray(), policy: Dictionary = {},
		random_build: bool = false, random_play: bool = false, mix: Dictionary = {},
		vigil: VigilState = null, strip_start_hex: bool = false,
		dusk_acquisition: bool = false) -> Dictionary:
	_probe = {}
	Pilot.set_ban(ban)
	Pilot.apply_policy(policy)
	Pilot.set_modes(random_build, random_play)
	var aspect_index: int = 1 if aspect == "ashwarden" else 0
	var profile: Dictionary = {
		"aspect": aspect_index, "vow": vow, "reveals": content.reveal_ids.duplicate(),
		"unlocks": ["aspect2"], "quests": {}, "shards": [], "lamplighter": false,
	}
	if vigil != null:
		profile["quests"] = vigil.quests.duplicate(true)
		profile["shards"] = vigil.shards.duplicate()
	if dusk_acquisition and aspect == "duskblade":
		var package_consumer: String = Pilot.choose_dusk_package(content)
		if not package_consumer.is_empty():
			profile["duskPackageConsumer"] = package_consumer
	var run: RunState = RunState.new_run(content, seed, "sim-%s-%d" % [aspect, seed], profile)
	if strip_start_hex:
		_strip_hex(run)
	_apply_ban(run)
	var game: GlassvowGame = GlassvowGame.new(content, run)
	# Empty mix follows the live shipping overlay. Pass catalog `none` to measure
	# the penalty ladder without incentives.
	Incentives.apply(game.rewards, mix if not mix.is_empty() else Incentives.shipping(),
		vow)
	var fights: Array[Dictionary] = []
	var economy: Array[Dictionary] = []
	for _act: int in range(3):
		var map: WorldMap = WorldMap.benchmark(run)
		while not map.is_finished():
			var i: int = Pilot.choose_node(map, run)
			if not map.enter(i):
				return _finish(run, aspect, seed, "error", fights, "unreachable node", economy,
					vigil, content)
			var node: MapNode = map.current()
			_enter_node(run, node)
			if node.is_combat():
				var fight: Dictionary = _fight(game, node)
				_harvest_fight(game)
				fights.append(fight)
				if fight["result"] != "win":
					return _finish(run, aspect, seed,
						"stall" if fight["result"] == "stall" else "loss",
						fights, "", economy, vigil, content)
				if node.type == "boss" and run.act == 2:
					economy.append(_economy_row(run))
					return _finish(run, aspect, seed, "win", fights, "", economy, vigil, content)
				_claim_rewards(game, game.gen_combat_rewards(node.combat_kind(), game.cb.affix))
			else:
				_resolve_safe_node(game, node)
			map.clear_current()
			if node.type == "boss" and not run.is_final_act():
				economy.append(_economy_row(run))
				var offered: Array[String] = game.rewards.roll_boss_relics(run)
				for offered_id: String in offered:
					if offered_id == "hollowCrown":
						_bump("hollowCrownOffered")
				var relic: String = Pilot.choose_relic(offered, content, run.aspect, run.rng)
				if not relic.is_empty():
					if relic == "hollowCrown":
						_bump("hollowCrownPicked")
						_bump("maxHpLostToCrown", _ji(content.relic(&"hollowCrown").get("maxHpPenalty", 10)))
					game.rewards.gain_relic(run, relic)
				run.boss_relic_act = run.act
				run.start_next_act(content)
				break
	return _finish(run, aspect, seed, "error", fights, "run route exhausted", economy, vigil, content)
static func _fight(game: GlassvowGame, node: MapNode) -> Dictionary:
	var enemies: Array[String] = node.enemies.duplicate()
	if enemies.is_empty():
		enemies = game.rewards.roll_encounter(game.run, node.type, node.row, node)
	var shatters_before: int = int(float(str(game.run.stats.get("shatters", 0))))
	game.apply({"t": "startCombat", "enemies": enemies, "kind": node.combat_kind()})
	while not game.cb.over:
		Pilot.play_turn(game)
		if game.cb.over:
			break
		if game.cb.turn >= 30:
			game.run.player.hp = maxi(0, game.cb.player.hp)
			break
		game.apply({"t": "endTurn"})
	var smolder_kills: int = 0
	for event: Dictionary in game.cb.queue:
		if event.get("t") == EventTypes.HIT_ENEMY and event.get("poison", false) \
				and event.get("dead", false):
			smolder_kills += 1
	return {
		"act": game.run.act + 1, "kind": node.combat_kind(), "enemies": enemies,
		"result": game.cb.result if game.cb.over else "stall", "turns": game.cb.turn,
		"hpLost": game.cb.hp_lost,
		"shatters": int(float(str(game.run.stats.get("shatters", 0)))) - shatters_before,
		"smolderKills": smolder_kills,
	}
static func _enter_node(run: RunState, node: MapNode) -> void:
	run.node_id = node.id
	run.waystones_lit = node.row + 1
	if node.unlit:
		var bounty: int = node.bounty * (2 if run.has_relic("thiefOfWicks") else 1)
		run.player.gold += bounty
		run.stats["goldEarned"] = int(float(str(run.stats.get("goldEarned", 0)))) + bounty
		run.stats["unlitVisited"] = int(float(str(run.stats.get("unlitVisited", 0)))) + 1
static func _claim_rewards(game: GlassvowGame, rewards: Dictionary) -> void:
	var gold: int = int(float(str(rewards.get("gold", 0))))
	game.run.player.gold += gold
	game.run.stats["goldEarned"] = int(float(str(game.run.stats.get("goldEarned", 0)))) + gold
	for card_v: Variant in rewards.get("cards", []):
		_bump("%sOffered" % str(card_v))
	var card: String = Pilot.choose_card(rewards.get("cards", []), game.content, game.run.aspect,
		game.run.rng)
	if not card.is_empty() and not Pilot.is_banned(card):
		var score: float = Pilot.card_score(game.content.cards.get(card, {}), game.run.aspect, card)
		if Pilot.accepts_card_reward(score):
			game.run.player.deck.append(CardInst.new(game.run.next_uid(), StringName(card), false))
	var potion_v: Variant = rewards.get("potion")
	if potion_v != null and not Pilot.is_banned(str(potion_v)):
		var slot: int = game.run.player.potions.find("")
		if slot >= 0:
			game.run.player.potions[slot] = str(potion_v)
	var relic_v: Variant = rewards.get("relic")
	if relic_v != null and not Pilot.is_banned(str(relic_v)):
		game.rewards.gain_relic(game.run, str(relic_v))
	var relic2_v: Variant = rewards.get("relic2")
	if relic2_v != null and not Pilot.is_banned(str(relic2_v)):
		game.rewards.gain_relic(game.run, str(relic2_v))
static func _resolve_safe_node(game: GlassvowGame, node: MapNode) -> void:
	match node.type:
		"rest":
			if game.run.player.hp * 100 <= game.run.player.max_hp * Pilot._wi("restHpPct"):
				var amount: int = int(roundf(float(game.run.player.max_hp) \
					* game.rewards.rest_heal_fraction(game.run)))
				game.run.player.hp = mini(game.run.player.max_hp, game.run.player.hp + amount)
			else:
				_upgrade_best(game)
		"event": _resolve_event(game)
		"shop": _resolve_shop(game)
		"treasure": _claim_treasure(game)
static func _upgrade_best(game: GlassvowGame) -> void:
	var best: CardInst = null
	var best_score: float = -INF
	for card: CardInst in game.run.player.deck:
		var d: Dictionary = game.content.cards.get(String(card.id), {})
		if card.up or not d.has("up"):
			continue
		var upgraded: Dictionary = d.duplicate()
		var up: Dictionary = d["up"]
		upgraded.merge(up, true)
		var score: float = Pilot.card_score(upgraded, game.run.aspect, String(card.id)) \
			- Pilot.card_score(d, game.run.aspect, String(card.id))
		if score > best_score:
			best = card
			best_score = score
	if best != null:
		best.up = true
static func _resolve_event(game: GlassvowGame) -> void:
	var event_id: String = game.rewards.roll_event(game.run)
	if event_id == "forgottenShrine":
		_bump("forgottenShrineSeen")
	elif event_id == "mirror":
		_bump("mirrorSeen")
	var event: Dictionary = game.content.events[event_id]
	var choice: Dictionary = {}
	var best_score: float = -INF
	for row_v: Variant in event.get("choices", []):
		var row: Dictionary = row_v
		if game.run.player.gold < int(float(str(row.get("needGold", 0)))):
			continue
		var score: float = _event_choice_score(game, row)
		if score > best_score:
			best_score = score
			choice = row
	var ops: Array = choice.get("ops", [])
	var pending: Dictionary = game.rewards.apply_event_ops(game.run, ops)
	match str(pending.get("kind", "")):
		"card":
			for pending_card: Variant in pending.get("cards", []):
				_bump("%sOffered" % str(pending_card))
			var id: String = Pilot.choose_card(pending.get("cards", []), game.content, game.run.aspect,
				game.run.rng)
			if not id.is_empty():
				game.run.player.deck.append(CardInst.new(game.run.next_uid(), StringName(id), false))
		"upgrade": _upgrade_best(game)
		"remove":
			var worst: CardInst = Pilot.worst_card(game.run, game.content, game.run.player.deck)
			if worst != null:
				game.run.player.deck.erase(worst)
				if event_id == "forgottenShrine":
					_bump("shrineRemovalChosen")
				elif event_id == "mirror":
					_bump("mirrorRemovalChosen")
		"duplicate":
			var source: CardInst = Pilot.best_card(game.run, game.content, game.run.player.deck)
			if source != null:
				game.run.player.deck.append(CardInst.new(game.run.next_uid(), source.id, source.up))
static func _event_choice_score(game: GlassvowGame, choice: Dictionary) -> float:
	var total: float = 0.0
	for op_v: Variant in choice.get("ops", []):
		total += _event_op_score(game, op_v)
	return total
static func _event_op_score(game: GlassvowGame, op_v: Variant) -> float:
	var op: Dictionary = op_v
	if op.has("roll"):
		var expected: float = 0.0
		for branch_v: Variant in op["roll"]:
			var branch: Dictionary = branch_v
			expected += float(str(branch.get("p", 0))) * _event_choice_score(game, branch)
		return expected
	if op.has("gold"):
		return float(int(float(str(op["gold"])))) * Pilot.shop_min_ratio
	if op.has("hp"):
		var hp: int = int(float(str(op["hp"])))
		var kind: String = "heal" if hp >= 0 else "loseHp"
		return Pilot.card_score({"effects": [{"kind": kind, "n": absi(hp)}]}, game.run.aspect)
	if op.has("heal"):
		var healed: int = int(roundf(float(game.run.player.max_hp) * float(str(op["heal"]))))
		return Pilot.card_score({"effects": [{"kind": "heal", "n": healed}]}, game.run.aspect)
	if op.has("maxHp"):
		# loseHp weights only; this under-values permanence of a max-HP change.
		var lost: int = absi(int(float(str(op["maxHp"]))))
		return Pilot.card_score({"effects": [{"kind": "loseHp", "n": lost}]}, game.run.aspect)
	if op.has("addCard"):
		var card_id: String = str(op["addCard"])
		return Pilot.card_score(game.content.cards.get(card_id, {}), game.run.aspect, card_id)
	if op.has("addRelic"):
		var relic_id: String = str(op["addRelic"])
		if relic_id == "random":
			return _expected_relic_score(game)
		return Pilot.relic_score(relic_id, game.content, game.run.aspect)
	if op.has("potion"):
		return _potion_shop_value(game)
	if op.get("pickRemove", false):
		var worst: CardInst = Pilot.worst_card(game.run, game.content, game.run.player.deck)
		if worst == null:
			return 0.0
		var wscore: float = Pilot.card_score(game.content.cards.get(String(worst.id), {}),
			game.run.aspect, String(worst.id))
		return Pilot.remove_value(wscore)
	if op.has("pickCard"):
		return _expected_card_max(game, int(float(str(op["pickCard"]))))
	if op.get("pickUpgrade", false):
		return _best_upgrade_delta(game)
	if op.get("pickDuplicate", false):
		var best: CardInst = Pilot.best_card(game.run, game.content, game.run.player.deck)
		if best == null:
			return 0.0
		return Pilot.card_score(game.content.cards.get(String(best.id), {}), game.run.aspect, String(best.id))
	return 0.0
static func _potion_shop_value(game: GlassvowGame) -> float:
	var pair: Array = game.content.shop["potionPrice"]
	return (float(str(pair[0])) + float(str(pair[1]))) * 0.5 * Pilot.shop_min_ratio
static func _expected_card_max(game: GlassvowGame, n: int) -> float:
	# roll_event_cards weights: common×2, uncommon×2, rare×1. No RNG — read the pools.
	if n <= 0:
		return 0.0
	var scores: Array[float] = []
	var copies: Dictionary = {"common": 2, "uncommon": 2, "rare": 1}
	for tier: String in ["common", "uncommon", "rare"]:
		var weight: int = int(float(str(copies[tier])))
		for id_v: Variant in game.rewards.card_pool(game.run, tier):
			var id: String = str(id_v)
			if Pilot.is_banned(id):
				continue
			var score: float = Pilot.card_score(game.content.cards.get(id, {}), game.run.aspect, id)
			for _copy: int in range(weight):
				scores.append(score)
	var m: int = scores.size()
	if m == 0:
		return 0.0
	scores.sort()
	var expected: float = 0.0
	var prev_cdf: float = 0.0
	var i: int = 0
	while i < m:
		var s: float = scores[i]
		var j: int = i + 1
		while j < m and scores[j] == s:
			j += 1
		var cdf: float = float(j) / float(m)
		expected += s * (cdf ** n - prev_cdf ** n)
		prev_cdf = cdf
		i = j
	return expected
static func _expected_relic_score(game: GlassvowGame) -> float:
	var weights: Dictionary = {"common": 0.5, "uncommon": 0.35, "rare": 0.15}
	var total: float = 0.0
	for tier: String in ["common", "uncommon", "rare"]:
		var mean: float = 0.0
		var n: int = 0
		for id_v: Variant in game.rewards.relic_pool(game.run, tier):
			var id: String = str(id_v)
			if game.run.player.relics.has(id) or Pilot.is_banned(id):
				continue
			mean += Pilot.relic_score(id, game.content, game.run.aspect)
			n += 1
		if n > 0:
			total += float(str(weights[tier])) * mean / float(n)
	return total
static func _best_upgrade_delta(game: GlassvowGame) -> float:
	var best_score: float = 0.0
	var found: bool = false
	for card: CardInst in game.run.player.deck:
		var d: Dictionary = game.content.cards.get(String(card.id), {})
		if card.up or not d.has("up"):
			continue
		var upgraded: Dictionary = d.duplicate()
		var up: Dictionary = d["up"]
		upgraded.merge(up, true)
		var score: float = Pilot.card_score(upgraded, game.run.aspect, String(card.id)) \
			- Pilot.card_score(d, game.run.aspect, String(card.id))
		if not found or score > best_score:
			found = true
			best_score = score
	return best_score if found else 0.0
static func _resolve_shop(game: GlassvowGame) -> void:
	_bump("shopVisited")
	var stock: Dictionary = game.rewards.gen_shop(game.run)
	for row_v: Variant in stock.get("cards", []):
		var row: Dictionary = row_v
		_bump("%sOffered" % str(row.get("id", "")))
	var buys: Array[Dictionary] = Pilot.choose_shop(stock, game.run, game.content)
	for buy: Dictionary in buys:
		var price: int = int(float(str(buy["price"])))
		if game.run.player.gold < price:
			continue
		game.run.player.gold -= price
		var category: String = str(buy["category"])
		var id: String = str(buy["id"])
		if category == "relics":
			game.rewards.gain_relic(game.run, id)
		elif category == "cards":
			game.run.player.deck.append(CardInst.new(game.run.next_uid(), StringName(id), false))
		elif category == "potions":
			var slot: int = game.run.player.potions.find("")
			if slot >= 0:
				game.run.player.potions[slot] = id
		elif category == "remove":
			_bump("shopRemovalBought")
			var remove: CardInst = null
			for card: CardInst in game.run.player.deck:
				if card.uid == int(float(str(buy.get("uid", -1)))):
					remove = card
					break
			if remove == null:
				remove = Pilot.worst_card(game.run, game.content, game.run.player.deck)
			if remove != null:
				game.run.player.deck.erase(remove)
static func _claim_treasure(game: GlassvowGame) -> void:
	var before: Array[String] = game.run.player.relics.duplicate()
	game.rewards.claim_treasure(game.run)
	for id: String in game.run.player.relics:
		if not before.has(id) and Pilot.is_banned(id):
			game.run.player.relics.erase(id)
			if id == "sweetRoot":
				game.run.player.max_hp = maxi(1, game.run.player.max_hp - 8)
				game.run.player.hp = mini(game.run.player.hp, game.run.player.max_hp)
			break
static func _apply_ban(run: RunState) -> void:
	if Pilot.banned.is_empty():
		return
	var kept_deck: Array[CardInst] = []
	for card: CardInst in run.player.deck:
		if not Pilot.is_banned(String(card.id)):
			kept_deck.append(card)
	run.player.deck.clear()
	for card: CardInst in kept_deck:
		run.player.deck.append(card)
	var kept_relics: Array[String] = []
	for id: String in run.player.relics:
		if not Pilot.is_banned(id):
			kept_relics.append(id)
	run.player.relics.clear()
	for id: String in kept_relics:
		run.player.relics.append(id)
static func _ji(value: Variant) -> int:
	return int(float(str(value)))


static func _bump(key: String, n: int = 1) -> void:
	_probe[key] = int(float(str(_probe.get(key, 0)))) + n


static func _harvest_fight(game: GlassvowGame) -> void:
	var relics: Array[String] = game.run.player.relics
	if relics.has("ashenCore"):
		_bump("ashenCoreOwned")
	if relics.has("smolderingCoal"):
		_bump("smolderingCoalOwned")
	if relics.has("hollowCrown"):
		_bump("hollowCrownOwned")
	var last_play: String = ""
	for event_v: Variant in game.cb.queue:
		var event: Dictionary = event_v
		var kind: String = str(event.get("t", ""))
		if kind == "turn":
			last_play = ""
			if relics.has("hollowCrown"):
				var gain: int = _ji(game.content.relic(&"hollowCrown").get("energyGain", 1))
				if gain > 0:
					_bump("extraEnergyGrantedByCrown", gain)
		elif kind == "draw":
			var drawn: String = str(event.get("id", ""))
			_bump("%sDrawn" % drawn)
			if last_play in ["quickSlash", "sidestep", "preparation"]:
				_bump("cardsDrawnByCycle")
			elif last_play == "deflect":
				_bump("cardsDrawnByDeflect")
		elif kind == "play":
			last_play = str(event.get("id", ""))
			_bump("%sPlayed" % last_play)
		elif kind == "status":
			var status_id: String = str(event.get("id", ""))
			if last_play == "eclipseSlash" and status_id == "vulnerable":
				_bump("crackedAppliedByEclipseSlash")
			elif last_play in ["ashBite", "smother"] and status_id == "poison":
				_bump("smolderAppliedByStarters")
			elif last_play == "toxicMist" and status_id == "poison":
				_bump("smolderAppliedByToxicMist")
			elif last_play == "ashenChoir" and status_id == "poison":
				_bump("smolderAppliedByStack")
		elif kind == "blockGain" and str(event.get("who", "")) == "player":
			if last_play == "smother":
				_bump("wardGainedBySmother")
			elif last_play == "deflect":
				_bump("wardGainedByDeflect")
		elif kind == "relicProc":
			var relic_id: String = str(event.get("id", ""))
			if relic_id == "ashenCore":
				_bump("ashenCoreTriggered")
			elif relic_id == "smolderingCoal":
				_bump("smolderingCoalTriggered")


static func _economy_row(run: RunState) -> Dictionary:
	return {"act": run.act + 1, "gold": run.player.gold, "hp": run.player.hp,
		"maxHp": run.player.max_hp, "deck": run.player.deck.size()}
static func _result(run: RunState, aspect: String, seed: int, outcome: String,
		fights: Array[Dictionary], error: String, economy: Array[Dictionary]) -> Dictionary:
	var deck_ids: Array[String] = []
	for card: CardInst in run.player.deck:
		deck_ids.append(String(card.id))
	return {
		"seed": seed, "aspect": aspect, "vow": run.vow, "outcome": outcome,
		"error": error, "hp": run.player.hp, "maxHp": run.player.max_hp,
		"gold": run.player.gold, "deck": run.player.deck.size(), "rng": run.rng_state(),
		"fights": fights, "relics": run.player.relics.duplicate(), "deckIds": deck_ids,
		"goldEarned": int(float(str(run.stats.get("goldEarned", 0)))), "economy": economy,
		"policy": Pilot.policy_snapshot(),
		"packageEvents": _probe.duplicate(),
	}


static func _finish(run: RunState, aspect: String, seed: int, outcome: String,
		fights: Array[Dictionary], error: String, economy: Array[Dictionary],
		vigil: VigilState, content: ContentDB) -> Dictionary:
	var row: Dictionary = _result(run, aspect, seed, outcome, fights, error, economy)
	if vigil != null:
		var commit: String = "win" if outcome == "win" else "death"
		vigil.commit_run(run, commit, content)
	return row


static func _strip_hex(run: RunState) -> void:
	var kept: Array[CardInst] = []
	for card: CardInst in run.player.deck:
		if card.id != &"hex":
			kept.append(card)
	run.player.deck.clear()
	for card: CardInst in kept:
		run.player.deck.append(card)
static func outcome_digest(row: Dictionary) -> String:
	var copy: Dictionary = row.duplicate(true)
	copy.erase("packageEvents")
	return JSON.stringify(copy).sha256_text()
static func _options(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {"aspect": "all", "runs": 200, "seed0": 1000, "vow": 0, "mobs": "",
		"out": "", "ban": "", "mix": "", "content": "", "space": BalanceCatalogue.DEFAULT_SPACE,
		"stage": "", "cardDecline": Pilot.CARD_DECLINE_DEFAULT,
		"removalAppetite": Pilot.REMOVAL_APPETITE_DEFAULT,
		"removalMinCopies": Pilot.REMOVAL_MIN_COPIES_DEFAULT}
	for arg: String in args:
		if not arg.begins_with("--") or not arg.contains("="):
			return {"error": "expected --name=value, got %s" % arg}
		var key: String = arg.get_slice("=", 0).trim_prefix("--")
		if not out.has(key):
			return {"error": "unknown option --%s" % key}
		out[key] = arg.substr(arg.find("=") + 1)
	for key: String in ["runs", "seed0", "vow", "removalMinCopies"]:
		if not str(out[key]).is_valid_int():
			return {"error": "--%s must be an integer" % key}
		out[key] = int(float(str(out[key])))
	for key: String in ["cardDecline", "removalAppetite"]:
		if not str(out[key]).is_valid_float():
			return {"error": "--%s must be a number" % key}
		out[key] = float(str(out[key]))
	if str(out["aspect"]) not in ["all", "duskblade", "ashwarden"]:
		return {"error": "--aspect must be all, duskblade or ashwarden"}
	if int(float(str(out["runs"]))) < 1 or int(float(str(out["vow"]))) < 0 or int(float(str(out["vow"]))) > 5:
		return {"error": "--runs must be positive and --vow must be 0..5"}
	if not str(out["mix"]).is_empty() and not Incentives.has_id(str(out["mix"])):
		return {"error": "unknown --mix %s" % out["mix"]}
	return out
static func _mix(opts: Dictionary) -> Dictionary:
	var id: String = str(opts.get("mix", ""))
	if id.is_empty():
		return Incentives.shipping()
	return Incentives.by_id(id)
static func _policy(opts: Dictionary) -> Dictionary:
	return Policy.resolve({"cardDecline": opts["cardDecline"],
		"removalAppetite": opts["removalAppetite"],
		"removalMinCopies": opts["removalMinCopies"]})
static func _manifest(opts: Dictionary, overlay: String, identity: Dictionary) -> Dictionary:
	var row: Dictionary = identity.duplicate()
	row["contentSha256"] = str(identity.get("contentFileSha256", ""))
	row["overlay"] = null if overlay.is_empty() else {"path": overlay,
		"sha256": FileAccess.get_sha256(overlay)}
	row["pilot"] = Pilot.VERSION
	row["profile"] = PROFILE
	row["aspect"] = opts["aspect"]
	row["vow"] = opts["vow"]
	row["ban"] = opts["ban"]
	row["policy"] = _policy(opts)
	row["seeds"] = {"first": opts["seed0"],
		"last": int(float(str(opts["seed0"]))) + int(float(str(opts["runs"]))) - 1,
		"count": opts["runs"]}
	row["mix"] = str(opts["mix"]) if not str(opts.get("mix", "")).is_empty() \
		else Incentives.SHIPPING_ID
	return row
