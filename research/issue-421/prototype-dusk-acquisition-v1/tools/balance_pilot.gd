class_name BalancePilot
extends RefCounted
## Block lethal, else kill-lowest; Dusk favours Eclipse/Shatter, Ash stacks Smolder highest and blocks with Smother.
## Routes favour treasure, then low-HP rest; rewards take the highest card/relic score; shops buy by value/gold.
## Potions heal at 20 missing HP, block lethal intent, and spend offensive stock in elite/boss fights.
const Policy: GDScript = preload("res://tools/balance_policy.gd")
const VERSION: String = "p8-d0-v1"
const SHOP_MIN_RATIO: float = 0.06475653649074956
## T1a: keep a reward iff card_score >= this. #215 four-grid top-decile median.
const CARD_DECLINE_DEFAULT: float = 14.0958831273019
## T1b: shop-remove numerator and event pickRemove share this intercept.
const REMOVAL_APPETITE_DEFAULT: float = 16.4400114826858
## T1b: min copies of the worst card before a shop will remove it.
const REMOVAL_MIN_COPIES_DEFAULT: int = 2
## Shop eligibility ceiling is appetite minus this. Not a sampled knob.
const REMOVAL_SHOP_MARGIN: float = 2.0
static var banned: Dictionary = {}
static var vector: Dictionary = {}
static var card_decline_threshold: float = CARD_DECLINE_DEFAULT
static var removal_appetite: float = REMOVAL_APPETITE_DEFAULT
static var removal_min_copies: int = REMOVAL_MIN_COPIES_DEFAULT
static var shop_min_ratio: float = SHOP_MIN_RATIO
static var random_build: bool = false
static var random_play: bool = false
static func set_modes(build: bool, play: bool) -> void:
	random_build = build
	random_play = play
static func apply_policy(policy: Dictionary) -> void:
	vector = Policy.resolve(policy)
	card_decline_threshold = float(str(vector["cardDecline"]))
	removal_appetite = float(str(vector["removalAppetite"]))
	removal_min_copies = int(float(str(vector["removalMinCopies"])))
	shop_min_ratio = float(str(vector["shopMinRatio"]))
static func policy_snapshot() -> Dictionary:
	if vector.is_empty():
		apply_policy({})
	return vector.duplicate(true)
static func _group(name: String) -> Dictionary:
	if vector.is_empty():
		apply_policy({})
	var raw: Variant = vector[name]
	return raw if typeof(raw) == TYPE_DICTIONARY else {}
static func _w(group: String, key: String) -> float:
	var d: Dictionary = _group(group)
	return float(str(d[key]))
static func _wf(key: String) -> float:
	if vector.is_empty():
		apply_policy({})
	return float(str(vector[key]))
static func _wi(key: String) -> int:
	return int(_wf(key))
static func accepts_card_reward(score: float) -> bool:
	return score >= card_decline_threshold
static func remove_value(wscore: float) -> float:
	return removal_appetite - wscore
static func wants_shop_remove(copies: int, wscore: float) -> bool:
	return copies >= removal_min_copies and wscore <= removal_appetite - REMOVAL_SHOP_MARGIN
static func set_ban(ids: PackedStringArray) -> void:
	banned.clear()
	for id: String in ids:
		banned[id] = true
static func is_banned(id: String) -> bool:
	return banned.has(id)
static func choose_node(map: WorldMap, run: RunState) -> int:
	if random_build:
		var reachable: Array[int] = map.reachable()
		return reachable[run.rng.pick_index(reachable.size())]
	var best: int = map.reachable()[0]
	var best_score: int = -1
	var low: bool = run.player.hp * 100 <= run.player.max_hp * _wi("routeLowHpPct")
	var gold_high: int = _wi("shopGoldHigh")
	var gold_low: int = _wi("shopGoldLow")
	for i: int in map.reachable():
		var n: MapNode = map.nodes[i]
		var score: int = int(float(str({
			"boss": _w("route", "boss"), "treasure": _w("route", "treasure"),
			"rest": _w("route", "restLow") if low else _w("route", "restOk"),
			"shop": _w("route", "shopRich") if run.player.gold >= gold_high \
				else (_w("route", "shopMid") if run.player.gold >= gold_low else _w("route", "shopPoor")),
			"event": _w("route", "event"),
			"elite": _w("route", "eliteOk") if not low else _w("route", "eliteLow"),
			"monster": _w("route", "monster"),
		}.get(n.type, 0))))
		if score > best_score:
			best = i
			best_score = score
	return best
static func play_turn(game: GlassvowGame) -> void:
	_use_potions(game)
	if game.rules.can_use_art(game.run, game.cb):
		game.apply({"t": "useArt"})
	_play_cards(game)
	if game.cb.over:
		return
	var kindle: CardInst = worst_card(game.run, game.content, game.cb.hand, true)
	if kindle != null:
		game.apply({"t": "kindleFromHand", "uid": kindle.uid})
	if game.rules.can_use_art(game.run, game.cb):
		game.apply({"t": "useArt"})
	_play_cards(game) # Verdant Branch can draw from the kindle.
static func _play_cards(game: GlassvowGame) -> void:
	if game.cb.over: return
	for _guard: int in range(32):
		var pick: Dictionary = _pick_play(game)
		if pick.is_empty():
			return
		game.apply({"t": "playCard", "uid": pick["uid"], "target": pick["target"]})
		if game.last_ret != true or game.cb.over:
			return
static func _pick_play(game: GlassvowGame) -> Dictionary:
	if random_play:
		var legal: Array[Dictionary] = []
		for card: CardInst in game.cb.hand:
			var d: Dictionary = game.rules.card_data(card)
			var targets: Array[Variant] = [null]
			if str(d.get("target", "")) == "enemy":
				targets.clear()
				for enemy: EnemyCombatant in game.cb.living_enemies():
					targets.append(enemy.idx)
			for target: Variant in targets:
				if game.rules.can_play(game.run, game.cb, card, target):
					legal.append({"uid": card.uid, "target": target})
		return {} if legal.is_empty() else legal[game.run.rng.pick_index(legal.size())]
	var incoming: int = _incoming(game)
	var unblocked: int = incoming - game.cb.player.block
	var lethal: bool = unblocked >= game.cb.player.hp
	var best: Dictionary = {}
	var best_score: float = -INF
	var dusk: bool = game.run.aspect == 0
	for card: CardInst in game.cb.hand:
		var d: Dictionary = game.rules.card_data(card)
		var target: Variant = _target(game, card, d)
		if not game.rules.can_play(game.run, game.cb, card, target):
			continue
		var preview_v: Variant = game.rules.preview_play(game.cb, card, target, game.run)
		var preview: Dictionary = preview_v if typeof(preview_v) == TYPE_DICTIONARY else {}
		var block: int = int(float(str(preview.get("block", 0))))
		if lethal and block > 0:
			var block_score: float = 10000.0 + block
			if block_score > best_score:
				best = {"uid": card.uid, "target": target}
				best_score = block_score
			continue
		if lethal and best_score >= 10000.0:
			continue
		if not _advances_fight(d) and (block <= 0 or unblocked <= 0):
			continue
		var score: float = _combat_score(game, card, d, target, preview, unblocked, dusk)
		if score > best_score:
			best = {"uid": card.uid, "target": target}
			best_score = score
	return best
static func _combat_score(game: GlassvowGame, card: CardInst, d: Dictionary, target: Variant,
		preview: Dictionary, unblocked: int, dusk: bool) -> float:
	var cid: String = String(card.id)
	var score: float = card_score(d, game.run.aspect, cid)
	var loss: int = int(float(str(preview.get("loss", 0))))
	var block: int = int(float(str(preview.get("block", 0))))
	score += float(loss) * _w("combat", "loss")
	if unblocked > 0 and block > 0:
		score += float(mini(block, unblocked)) * (_w("combat", "blockUrgent") \
			if unblocked * 2 >= game.cb.player.hp else _w("combat", "blockNormal"))
	if preview.get("willShatter", false):
		score += _w("combat", "shatterDusk") if dusk else _w("combat", "shatterAsh")
	if preview.get("lethal", false):
		score += _w("combat", "lethal")
	var foe: EnemyCombatant = null
	if typeof(target) == TYPE_INT:
		var idx: int = int(float(str(target)))
		foe = game.cb.enemies[idx]
	var existing: int = 0 if foe == null else int(float(str(foe.statuses.get("poison", 0))))
	var applied: int = _status_n(d, "poison")
	if applied > 0:
		score += float(applied * (2 * existing + applied + 1)) \
			* (_w("combat", "poisonAsh") if not dusk else _w("combat", "poisonDusk"))
	if _special_id(d) == "catalyst" and existing > 0:
		score += float(existing) * (_w("combat", "catalystAsh") if not dusk else _w("combat", "catalystDusk"))
	var vuln: int = 0 if foe == null else int(float(str(foe.statuses.get("vulnerable", 0))))
	if dusk and cid == "eclipseSlash" and vuln <= 0:
		score += _w("combat", "eclipse")
		for other: CardInst in game.cb.hand:
			if other != card and str(game.rules.card_data(other).get("type", "")) == "attack":
				score += _w("combat", "eclipseFollow")
				break
	if dusk and vuln > 0 and str(d.get("type", "")) == "attack" and cid != "eclipseSlash":
		score += _w("combat", "vulnAttack")
	if dusk and foe != null:
		var chips: int = int(float(str(preview.get("chips", 0))))
		var need: int = foe.facet_max - foe.chips
		if chips > 0 and need > 0 and chips < need:
			score += _w("combat", "chip") * float(chips) / float(need)
	if str(d.get("type", "")) == "power":
		score += _w("combat", "power")
	return score
static func _target(game: GlassvowGame, card: CardInst, d: Dictionary) -> Variant:
	if str(d.get("target", "")) != "enemy":
		return null
	var living: Array[EnemyCombatant] = game.cb.living_enemies()
	var poison: bool = _has_effect(d, "status", "poison") \
		or _has_effect(d, "special", "catalyst")
	if _special_id(d) == "catalyst":
		var stacked: EnemyCombatant = living[0]
		for e: EnemyCombatant in living:
			if int(float(str(e.statuses.get("poison", 0)))) \
					> int(float(str(stacked.statuses.get("poison", 0)))):
				stacked = e
		return stacked.idx
	if game.run.aspect == 1 and poison:
		var highest: EnemyCombatant = living[0]
		for e: EnemyCombatant in living:
			if e.hp > highest.hp:
				highest = e
		return highest.idx
	if game.run.aspect == 0:
		for e: EnemyCombatant in living:
			var pv: Variant = game.rules.preview_play(game.cb, card, e.idx, game.run)
			if typeof(pv) == TYPE_DICTIONARY and pv.get("willShatter", false):
				return e.idx
	var lowest: EnemyCombatant = living[0]
	for e: EnemyCombatant in living:
		if e.hp < lowest.hp:
			lowest = e
	return lowest.idx
static func _incoming(game: GlassvowGame) -> int:
	var hp: Array[int] = []
	var smolder: Array[int] = []
	for e: EnemyCombatant in game.cb.enemies:
		hp.append(e.hp)
		smolder.append(int(float(str(e.statuses.get("poison", 0)))))
	var rng: Rng = Rng.new(game.run.rng_state()) # Forecast jumps without moving the run RNG.
	var total: int = 0
	for i: int in range(game.cb.enemies.size()):
		if hp[i] <= 0:
			continue
		if smolder[i] > 0:
			hp[i] -= smolder[i]
			smolder[i] = maxi(0, smolder[i] - 1)
			if hp[i] <= 0:
				var living: Array[int] = []
				for j: int in range(hp.size()):
					if j != i and hp[j] > 0:
						living.append(j)
				if smolder[i] > 0 and not living.is_empty():
					smolder[living[rng.pick_index(living.size())]] += smolder[i]
				continue
		var e: EnemyCombatant = game.cb.enemies[i]
		if e.staggered:
			continue
		var preview_v: Variant = game.rules.preview_enemy_dmg(game.cb, e, game.run)
		if typeof(preview_v) == TYPE_DICTIONARY:
			var preview: Dictionary = preview_v
			total += int(float(str(preview["dmg"]))) * int(float(str(preview["times"])))
	return total
static func _use_potions(game: GlassvowGame) -> void:
	var spend: bool = game.cb.kind != &"normal"
	for slot: int in range(game.run.player.potions.size()):
		var id: String = game.run.player.potions[slot]
		var use: bool = id == "healing" and game.cb.player.max_hp - game.cb.player.hp >= _wi("potionHealMissing")
		use = use or id == "block" and _incoming(game) - game.cb.player.block >= game.cb.player.hp
		use = use or spend and id in ["strength", "swift", "fire", "venom", "energy"]
		if not use:
			continue
		var target: Variant = null
		if id == "fire" or id == "venom":
			var living: Array[EnemyCombatant] = game.cb.living_enemies()
			target = living[0].idx
			for e: EnemyCombatant in living:
				if (id == "venom" and game.run.aspect == 1 and e.hp > game.cb.enemies[target].hp) \
						or (id != "venom" and e.hp < game.cb.enemies[target].hp):
					target = e.idx
		game.apply({"t": "usePotion", "slot": slot, "target": target})
		if game.cb.over:
			return
static func card_score(d: Dictionary, aspect: int, card_id: String = "") -> float:
	var dusk: bool = aspect == 0
	var card_w: Dictionary = _group("card")
	var rarity_v: Variant = card_w["rarity"]
	var rarity: Dictionary = rarity_v if typeof(rarity_v) == TYPE_DICTIONARY else {}
	var score: float = float(str(rarity.get(str(d.get("rarity", "starter")), 0))) \
		- float(str(d.get("cost", 0)))
	for fx_v: Variant in d.get("effects", []):
		var fx: Dictionary = fx_v
		match str(fx.get("kind", "")):
			"dmg": score += float(str(fx.get("n", 0))) * float(str(fx.get("times", 1)))
			"block", "heal": score += float(str(fx.get("n", 0))) * _w("card", "blockHeal")
			"draw", "energy": score += float(str(fx.get("n", 0))) * _w("card", "drawEnergy")
			"chip": score += float(str(fx.get("n", 0))) * (_w("card", "chipDusk") if dusk else _w("card", "chipAsh"))
			"ember": score += float(str(fx.get("n", 0))) * _w("card", "ember")
			"loseHp": score -= float(str(fx.get("n", 0))) * _w("card", "loseHp")
			"status": score += _status_value(str(fx.get("id", "")), int(float(str(fx.get("n", 0)))), dusk)
			"special": score += _special_value(str(fx.get("id", "")), dusk)
	if str(d.get("type", "")) == "power":
		score += _w("card", "power")
	score += float(str(d.get("chip", 0))) * (_w("card", "chipDusk") if dusk else _w("card", "chipAsh"))
	if dusk and card_id in ["eclipseSlash", "chisel", "warCry", "limitBreak", "resonantLance", "executioner"]:
		score += _w("card", "aspectBonus")
	if not dusk and card_id in ["ashBite", "smother", "venomStrike", "toxicMist", "ashenChoir",
			"catalyst", "virulence", "annihilate"]:
		score += _w("card", "aspectBonus")
	return score
static func _status_value(id: String, n: int, dusk: bool) -> float:
	match id:
		"poison":
			return float(n * (n + 1)) * (_w("status", "poisonAsh") if not dusk else _w("status", "poisonDusk"))
		"vulnerable":
			return float(n) * (_w("status", "vulnerableDusk") if dusk else _w("status", "vulnerableAsh"))
		"weak":
			return float(n) * _w("status", "weak")
		"str":
			return float(n) * _w("status", "str")
		"dex", "metallicize":
			return float(n) * _w("status", "dex")
		"regen":
			return float(n) * _w("status", "regen")
		"venomous":
			return _w("status", "venomousAsh") if not dusk else _w("status", "venomousDusk")
		"ritual":
			return float(n) * _w("status", "ritual")
		"barricade", "energized":
			return _w("status", "barricade")
		"beacon":
			return _w("status", "beaconDusk") if dusk else _w("status", "beaconAsh")
		"nightsight", "emberflow":
			return _w("status", "nightsight")
	return 0.0
static func _special_value(id: String, dusk: bool) -> float:
	match id:
		"catalyst":
			return _w("special", "catalystAsh") if not dusk else _w("special", "catalystDusk")
		"shatterEcho":
			return _w("special", "shatterEchoDusk") if dusk else _w("special", "shatterEchoAsh")
		"execute", "momentum":
			return _w("special", "execute")
		"leech", "devour", "phantom":
			return _w("special", "leech")
		"doubleBlock", "flawless", "emberNova":
			return _w("special", "doubleBlock")
		"pyreTithe", "emberdance":
			return _w("special", "pyreTithe")
	return _w("special", "fallback")
static func _status_n(d: Dictionary, id: String) -> int:
	var total: int = 0
	for fx_v: Variant in d.get("effects", []):
		var fx: Dictionary = fx_v
		if str(fx.get("kind", "")) == "status" and str(fx.get("id", "")) == id:
			total += int(float(str(fx.get("n", 0))))
	return total
static func _special_id(d: Dictionary) -> String:
	for fx_v: Variant in d.get("effects", []):
		var fx: Dictionary = fx_v
		if str(fx.get("kind", "")) == "special":
			return str(fx.get("id", ""))
	return ""
static func _advances_fight(d: Dictionary) -> bool:
	if str(d.get("type", "")) in ["attack", "power"]:
		return true
	for fx_v: Variant in d.get("effects", []):
		var fx: Dictionary = fx_v
		if str(fx.get("kind", "")) in ["draw", "energy", "heal", "chip", "special"] \
				or str(fx.get("who", "")) in ["target", "allEnemies"]:
			return true
	return false
static func _has_effect(d: Dictionary, kind: String, id: String) -> bool:
	for fx_v: Variant in d.get("effects", []):
		var fx: Dictionary = fx_v
		if str(fx.get("kind", "")) == kind and str(fx.get("id", "")) == id:
			return true
	return false
static func choose_card(ids: Array, content: ContentDB, aspect: int, rng: Rng = null) -> String:
	if random_build and rng != null:
		var legal: Array[String] = []
		for id_v: Variant in ids:
			if not is_banned(str(id_v)):
				legal.append(str(id_v))
		return "" if legal.is_empty() else legal[rng.pick_index(legal.size())]
	var best: String = ""
	var score: float = -INF
	for id_v: Variant in ids:
		var id: String = str(id_v)
		if is_banned(id):
			continue
		var definition: Dictionary = content.cards.get(id, {})
		var candidate: float = card_score(definition, aspect, id)
		if candidate > score:
			best = id
			score = candidate
	return best
static func choose_dusk_package(content: ContentDB) -> String:
	var id: String = choose_card(["executioner", "guardedStrike"], content, 0)
	if id.is_empty():
		return ""
	var definition: Dictionary = content.cards.get(id, {})
	var score: float = card_score(definition, 0, id)
	return id if accepts_card_reward(score) else ""
static func choose_relic(ids: Array, content: ContentDB, aspect: int = 0, rng: Rng = null) -> String:
	if random_build and rng != null:
		var legal: Array[String] = []
		for id_v: Variant in ids:
			if not is_banned(str(id_v)):
				legal.append(str(id_v))
		return "" if legal.is_empty() else legal[rng.pick_index(legal.size())]
	var best: String = ""
	var score: int = -1
	for id_v: Variant in ids:
		var id: String = str(id_v)
		if is_banned(id):
			continue
		var candidate: int = int(relic_score(id, content, aspect))
		if candidate > score:
			best = id
			score = candidate
	return best
static func worst_card(run: RunState, content: ContentDB, cards: Array, kindle: bool = false) -> CardInst:
	var worst: CardInst = null
	var score: float = INF
	for card: CardInst in cards:
		if kindle and str(content.cards.get(String(card.id), {}).get("type", "")) == "curse":
			continue
		var definition: Dictionary = content.cards.get(String(card.id), {})
		var candidate: float = card_score(definition, run.aspect, String(card.id))
		if candidate < score:
			worst = card
			score = candidate
	return worst
static func best_card(run: RunState, content: ContentDB, cards: Array) -> CardInst:
	var best: CardInst = null
	var score: float = -INF
	for card: CardInst in cards:
		var definition: Dictionary = content.cards.get(String(card.id), {})
		var candidate: float = card_score(definition, run.aspect, String(card.id))
		if candidate > score:
			best = card
			score = candidate
	return best
static func relic_score(id: String, content: ContentDB, aspect: int) -> float:
	var rarity: String = str(content.relics.get(id, {}).get("rarity", "common"))
	var table: Dictionary = _group("relics")
	var rarity_table: Dictionary = _group("relicRarity")
	var score: float = float(str(table.get(id, rarity_table.get(rarity, _wf("relicFallback")))))
	if aspect == 0 and id in ["shatterersCrown", "prismCharm", "executionersSeal"]:
		score += _wf("relicDuskBonus")
	if aspect == 1 and id in ["smolderingCoal", "ashenCore", "thornBand"]:
		score += _wf("relicAshBonus")
	return score
static func choose_shop(stock: Dictionary, run: RunState, content: ContentDB) -> Array[Dictionary]:
	if random_build:
		return _random_shop(stock, run)
	var gold: int = run.player.gold
	var potion_free: int = 0
	for slot: String in run.player.potions:
		if slot.is_empty():
			potion_free += 1
	var bought: Array[Dictionary] = []
	var taken: Dictionary = {}
	var removed: bool = false
	for _guard: int in range(8):
		var best: Dictionary = {}
		var best_ratio: float = shop_min_ratio
		for category: String in ["relics", "cards", "potions"]:
			for row_v: Variant in stock.get(category, []):
				var row: Dictionary = row_v
				var id: String = str(row["id"])
				var key: String = "%s:%s" % [category, id]
				var price: int = int(float(str(row["price"])))
				if taken.has(key) or is_banned(id) or gold < price:
					continue
				if category == "potions" and potion_free <= 0:
					continue
				var value: float = _wf("potionShopDefault")
				if category == "relics":
					value = relic_score(id, content, run.aspect)
				elif category == "cards":
					var definition: Dictionary = content.cards.get(id, {})
					value = card_score(definition, run.aspect, id)
				elif id == "healing":
					value = _wf("potionHealing")
				var ratio: float = value / float(maxi(price, 1))
				if ratio > best_ratio:
					best_ratio = ratio
					best = {"category": category, "id": id, "price": price, "key": key}
		var remove_cost: int = int(float(str(stock.get("removeCost", 75))))
		if not removed and gold >= remove_cost:
			var worst: CardInst = worst_card(run, content, run.player.deck)
			if worst != null:
				var copies: int = 0
				for card: CardInst in run.player.deck:
					if String(card.id) == String(worst.id):
						copies += 1
				var worst_def: Dictionary = content.cards.get(String(worst.id), {})
				var wscore: float = card_score(worst_def, run.aspect, String(worst.id))
				if wants_shop_remove(copies, wscore):
					var remove_ratio: float = remove_value(wscore) / float(maxi(remove_cost, 1))
					if remove_ratio > best_ratio:
						best = {"category": "remove", "id": String(worst.id),
							"price": remove_cost, "uid": worst.uid}
						best_ratio = remove_ratio
		if best.is_empty():
			break
		bought.append(best)
		gold -= int(float(str(best["price"])))
		if str(best.get("category", "")) == "remove":
			removed = true
		else:
			taken[str(best["key"])] = true
			if str(best["category"]) == "potions":
				potion_free -= 1
	return bought


static func _random_shop(stock: Dictionary, run: RunState) -> Array[Dictionary]:
	var gold: int = run.player.gold
	var potion_free: int = run.player.potions.count("")
	var taken: Dictionary = {}
	var removed: bool = false
	var bought: Array[Dictionary] = []
	var remove_cost: int = int(float(str(stock.get("removeCost", 75))))
	for _guard: int in range(8):
		var options: Array[Dictionary] = []
		for category: String in ["relics", "cards", "potions"]:
			for row_v: Variant in stock.get(category, []):
				var row: Dictionary = row_v
				var key: String = "%s:%s" % [category, row["id"]]
				if not taken.has(key) and not is_banned(str(row["id"])) \
						and int(float(str(row["price"]))) <= gold \
						and (category != "potions" or potion_free > 0):
					options.append({"category": category, "id": str(row["id"]),
						"price": row["price"], "key": key})
		if not removed and remove_cost <= gold and not run.player.deck.is_empty():
			options.append({"category": "remove", "price": remove_cost})
		# One equally weighted stop option prevents random build from always emptying the purse.
		var pick: int = run.rng.pick_index(options.size() + 1)
		if pick == options.size():
			break
		var chosen: Dictionary = options[pick]
		if str(chosen["category"]) == "remove":
			var card: CardInst = run.player.deck[run.rng.pick_index(run.player.deck.size())]
			chosen.merge({"id": String(card.id), "uid": card.uid})
			removed = true
		else:
			taken[str(chosen["key"])] = true
			if str(chosen["category"]) == "potions":
				potion_free -= 1
		bought.append(chosen)
		gold -= int(float(str(chosen["price"])))
	return bought
