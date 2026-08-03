class_name BalanceSim
extends SceneTree
## Domain-only whole runs: all reveals, no quests or cross-run side state.
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
func _initialize() -> void:
	var opts: Dictionary = _options(OS.get_cmdline_user_args())
	if opts.has("error"):
		push_error("balance_sim: %s" % opts["error"])
		quit(2)
		return
	var content: ContentDB = ContentDB.load_full(false)
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
	for aspect: String in aspects:
		for offset: int in range(int(float(str(opts["runs"])))):
			rows.append(simulate(content, aspect, int(float(str(opts["seed0"]))) + offset, int(float(str(opts["vow"])))))
	print(JSON.stringify(rows))
	quit(0)
static func simulate(content: ContentDB, aspect: String, seed: int, vow: int = 0) -> Dictionary:
	var aspect_index: int = 1 if aspect == "ashwarden" else 0
	var profile: Dictionary = {
		"aspect": aspect_index, "vow": vow, "reveals": content.reveal_ids.duplicate(),
		"unlocks": ["aspect2"], "quests": {}, "shards": [], "lamplighter": false,
	}
	var run: RunState = RunState.new_run(content, seed, "sim-%s-%d" % [aspect, seed], profile)
	var game: GlassvowGame = GlassvowGame.new(content, run)
	var fights: Array[Dictionary] = []
	for _act: int in range(3):
		var map: WorldMap = WorldMap.benchmark(run)
		while not map.is_finished():
			var i: int = Pilot.choose_node(map, run)
			if not map.enter(i):
				return _result(run, aspect, seed, "error", fights, "unreachable node")
			var node: MapNode = map.current()
			_enter_node(run, node)
			if node.is_combat():
				var fight: Dictionary = _fight(game, node)
				fights.append(fight)
				if fight["result"] != "win":
					return _result(run, aspect, seed, "stall" if fight["result"] == "stall" else "loss", fights)
				if node.type == "boss" and run.act == 2:
					return _result(run, aspect, seed, "win", fights)
				_claim_rewards(game, game.gen_combat_rewards(node.combat_kind(), game.cb.affix))
			else:
				_resolve_safe_node(game, node)
			map.clear_current()
			if node.type == "boss":
				var relic: String = Pilot.choose_relic(game.rewards.roll_boss_relics(run), content)
				if not relic.is_empty():
					game.rewards.gain_relic(run, relic)
				run.boss_relic_act = run.act
				run.start_next_act(content)
				break
	return _result(run, aspect, seed, "error", fights, "run route exhausted")
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
	run.floors_climbed = node.row + 1
	if node.unlit:
		var bounty: int = node.bounty * (2 if run.has_relic("thiefOfWicks") else 1)
		run.player.gold += bounty
		run.stats["goldEarned"] = int(float(str(run.stats.get("goldEarned", 0)))) + bounty
		run.stats["unlitVisited"] = int(float(str(run.stats.get("unlitVisited", 0)))) + 1
static func _claim_rewards(game: GlassvowGame, rewards: Dictionary) -> void:
	var gold: int = int(float(str(rewards.get("gold", 0))))
	game.run.player.gold += gold
	game.run.stats["goldEarned"] = int(float(str(game.run.stats.get("goldEarned", 0)))) + gold
	var card: String = Pilot.choose_card(rewards.get("cards", []), game.content, game.run.aspect)
	if not card.is_empty():
		game.run.player.deck.append(CardInst.new(game.run.next_uid(), StringName(card), false))
	var potion_v: Variant = rewards.get("potion")
	if potion_v != null:
		var slot: int = game.run.player.potions.find("")
		if slot >= 0:
			game.run.player.potions[slot] = str(potion_v)
	var relic_v: Variant = rewards.get("relic")
	if relic_v != null:
		game.rewards.gain_relic(game.run, str(relic_v))
static func _resolve_safe_node(game: GlassvowGame, node: MapNode) -> void:
	match node.type:
		"rest":
			if game.run.player.hp * 100 <= game.run.player.max_hp * 70:
				var amount: int = int(roundf(float(game.run.player.max_hp) \
					* game.rewards.rest_heal_fraction(game.run)))
				game.run.player.hp = mini(game.run.player.max_hp, game.run.player.hp + amount)
			else:
				_upgrade_best(game)
		"event": _resolve_event(game)
		"shop": _resolve_shop(game)
		"treasure": game.rewards.claim_treasure(game.run)
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
		var score: float = Pilot.card_score(upgraded, game.run.aspect) - Pilot.card_score(d, game.run.aspect)
		if score > best_score:
			best = card
			best_score = score
	if best != null:
		best.up = true
static func _resolve_event(game: GlassvowGame) -> void:
	var event: Dictionary = game.content.events[game.rewards.roll_event(game.run)]
	var choice: Dictionary = {}
	for row_v: Variant in event.get("choices", []):
		var row: Dictionary = row_v
		if game.run.player.gold >= int(float(str(row.get("needGold", 0)))):
			choice = row
			break
	var ops: Array = choice.get("ops", [])
	var pending: Dictionary = game.rewards.apply_event_ops(game.run, ops)
	match str(pending.get("kind", "")):
		"card":
			var id: String = Pilot.choose_card(pending.get("cards", []), game.content, game.run.aspect)
			if not id.is_empty():
				game.run.player.deck.append(CardInst.new(game.run.next_uid(), StringName(id), false))
		"upgrade": _upgrade_best(game)
		"remove":
			var worst: CardInst = Pilot.worst_card(game.run, game.content, game.run.player.deck)
			if worst != null: game.run.player.deck.erase(worst)
		"duplicate":
			var source: CardInst = game.run.player.deck[0]
			game.run.player.deck.append(CardInst.new(game.run.next_uid(), source.id, source.up))
static func _resolve_shop(game: GlassvowGame) -> void:
	var stock: Dictionary = game.rewards.gen_shop(game.run)
	for category: String in ["relics", "cards", "potions"]:
		for row_v: Variant in stock.get(category, []):
			var row: Dictionary = row_v
			var price: int = int(float(str(row["price"])))
			if game.run.player.gold < price or (category == "potions" and not game.run.player.potions.has("")):
				continue
			game.run.player.gold -= price
			var id: String = str(row["id"])
			if category == "relics":
				game.rewards.gain_relic(game.run, id)
			elif category == "cards":
				game.run.player.deck.append(CardInst.new(game.run.next_uid(), StringName(id), false))
			else:
				game.run.player.potions[game.run.player.potions.find("")] = id
			return # One deliberate purchase keeps the policy stable and legible.
static func _result(run: RunState, aspect: String, seed: int, outcome: String,
		fights: Array[Dictionary], error: String = "") -> Dictionary:
	return {
		"seed": seed, "aspect": aspect, "vow": run.vow, "outcome": outcome,
		"error": error, "hp": run.player.hp, "maxHp": run.player.max_hp,
		"gold": run.player.gold, "deck": run.player.deck.size(), "rng": run.rng_state(),
		"fights": fights,
	}
static func _options(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {"aspect": "all", "runs": 200, "seed0": 1000, "vow": 0, "mobs": ""}
	for arg: String in args:
		if not arg.begins_with("--") or not arg.contains("="):
			return {"error": "expected --name=value, got %s" % arg}
		var key: String = arg.get_slice("=", 0).trim_prefix("--")
		if not out.has(key):
			return {"error": "unknown option --%s" % key}
		out[key] = arg.substr(arg.find("=") + 1)
	for key: String in ["runs", "seed0", "vow"]:
		if not str(out[key]).is_valid_int():
			return {"error": "--%s must be an integer" % key}
		out[key] = int(float(str(out[key])))
	if str(out["aspect"]) not in ["all", "duskblade", "ashwarden"]:
		return {"error": "--aspect must be all, duskblade or ashwarden"}
	if int(float(str(out["runs"]))) < 1 or int(float(str(out["vow"]))) < 0 or int(float(str(out["vow"]))) > 5:
		return {"error": "--runs must be positive and --vow must be 0..5"}
	return out
