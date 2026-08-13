class_name BalancePilot
extends RefCounted
## Block lethal, else kill-lowest; Dusk favours Eclipse/Shatter, Ash stacks Smolder highest and blocks with Smother.
## Routes favour treasure, then low-HP rest; rewards take the highest card/relic score; shops buy by value/gold.
## Potions heal at 20 missing HP, block lethal intent, and spend offensive stock in elite/boss fights.
const VERSION: String = "p7-d0-v1"
const SHOP_MIN_RATIO: float = 0.06
const RELIC_SCORE: Dictionary = {
	"hollowCrown": 90, "frozenCore": 70, "crownOfCinders": 68, "verdantBranch": 62,
	"crownOfTheHearth": 60, "shatterersCrown": 58, "crownOfTithes": 55, "warFetish": 48,
	"emberLantern": 46, "sunBlossom": 44, "duskmirror": 42, "merchantsMark": 40,
	"travelersPack": 38, "silkFan": 36, "seersOrb": 34, "ironTalisman": 32,
	"executionersSeal": 30, "wardingCharm": 28, "basaltIdol": 26, "riverPearl": 24,
	"gravebloom": 24, "reapersBell": 22, "vialOfLife": 20, "thornBand": 18,
	"sweetRoot": 18, "prismCharm": 16, "bellOfEndings": 16, "thiefOfWicks": 14,
}
static var banned: Dictionary = {}
static func set_ban(ids: PackedStringArray) -> void:
	banned.clear()
	for id: String in ids:
		banned[id] = true
static func is_banned(id: String) -> bool:
	return banned.has(id)
static func choose_node(map: WorldMap, run: RunState) -> int:
	var best: int = map.reachable()[0]
	var best_score: int = -1
	var low: bool = run.player.hp * 100 <= run.player.max_hp * 60
	for i: int in map.reachable():
		var n: MapNode = map.nodes[i]
		var score: int = {
			"boss": 1000, "treasure": 900, "rest": 800 if low else 150,
			"shop": 700 if run.player.gold >= 140 else (520 if run.player.gold >= 45 else 100),
			"event": 400,
			"elite": 450 if not low else 50, "monster": 300,
		}.get(n.type, 0)
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
	score += float(loss) * 1.15
	if unblocked > 0 and block > 0:
		score += float(mini(block, unblocked)) * (1.6 if unblocked * 2 >= game.cb.player.hp else 0.85)
	if preview.get("willShatter", false):
		score += 80.0 if dusk else 22.0
	if preview.get("lethal", false):
		score += 280.0
	var foe: EnemyCombatant = null
	if typeof(target) == TYPE_INT:
		var idx: int = int(float(str(target)))
		foe = game.cb.enemies[idx]
	var existing: int = 0 if foe == null else int(float(str(foe.statuses.get("poison", 0))))
	var applied: int = _status_n(d, "poison")
	if applied > 0:
		score += float(applied * (2 * existing + applied + 1)) * (0.85 if not dusk else 0.22)
	if _special_id(d) == "catalyst" and existing > 0:
		score += float(existing) * (3.2 if not dusk else 0.8)
	var vuln: int = 0 if foe == null else int(float(str(foe.statuses.get("vulnerable", 0))))
	if dusk and cid == "eclipseSlash" and vuln <= 0:
		score += 48.0
		for other: CardInst in game.cb.hand:
			if other != card and str(game.rules.card_data(other).get("type", "")) == "attack":
				score += 36.0
				break
	if dusk and vuln > 0 and str(d.get("type", "")) == "attack" and cid != "eclipseSlash":
		score += 18.0
	if dusk and foe != null:
		var chips: int = int(float(str(preview.get("chips", 0))))
		var need: int = foe.facet_max - foe.chips
		if chips > 0 and need > 0 and chips < need:
			score += 12.0 * float(chips) / float(need)
	if str(d.get("type", "")) == "power":
		score += 14.0
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
		var use: bool = id == "healing" and game.cb.player.max_hp - game.cb.player.hp >= 20
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
	var score: float = float(str({"starter": 0, "common": 3, "uncommon": 6, "rare": 10}.get(
		str(d.get("rarity", "starter")), 0))) - float(str(d.get("cost", 0)))
	for fx_v: Variant in d.get("effects", []):
		var fx: Dictionary = fx_v
		match str(fx.get("kind", "")):
			"dmg": score += float(str(fx.get("n", 0))) * float(str(fx.get("times", 1)))
			"block", "heal": score += float(str(fx.get("n", 0))) * 0.7
			"draw", "energy": score += float(str(fx.get("n", 0))) * 4.5
			"chip": score += float(str(fx.get("n", 0))) * (6.0 if dusk else 2.5)
			"ember": score += float(str(fx.get("n", 0))) * 2.0
			"loseHp": score -= float(str(fx.get("n", 0))) * 0.4
			"status": score += _status_value(str(fx.get("id", "")), int(float(str(fx.get("n", 0)))), dusk)
			"special": score += _special_value(str(fx.get("id", "")), dusk)
	if str(d.get("type", "")) == "power":
		score += 10.0
	score += float(str(d.get("chip", 0))) * (6.0 if dusk else 2.5)
	if dusk and card_id in ["eclipseSlash", "chisel", "warCry", "limitBreak", "resonantLance", "executioner"]:
		score += 8.0
	if not dusk and card_id in ["ashBite", "smother", "venomStrike", "toxicMist", "ashenChoir",
			"catalyst", "virulence", "annihilate"]:
		score += 8.0
	return score
static func _status_value(id: String, n: int, dusk: bool) -> float:
	match id:
		"poison":
			return float(n * (n + 1)) * (0.85 if not dusk else 0.22)
		"vulnerable":
			return float(n) * (12.0 if dusk else 4.0)
		"weak":
			return float(n) * 5.0
		"str":
			return float(n) * 8.0
		"dex", "metallicize":
			return float(n) * 5.5
		"regen":
			return float(n) * 6.0
		"venomous":
			return 20.0 if not dusk else 6.0
		"ritual":
			return float(n) * 10.0
		"barricade", "energized":
			return 12.0
		"beacon":
			return 10.0 if dusk else 4.0
		"nightsight", "emberflow":
			return 8.0
	return 0.0
static func _special_value(id: String, dusk: bool) -> float:
	match id:
		"catalyst":
			return 30.0 if not dusk else 6.0
		"shatterEcho":
			return 16.0 if dusk else 8.0
		"execute", "momentum":
			return 13.0
		"leech", "devour", "phantom":
			return 12.0
		"doubleBlock", "flawless", "emberNova":
			return 9.0
		"pyreTithe", "emberdance":
			return 6.0
	return 8.0
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
static func choose_card(ids: Array, content: ContentDB, aspect: int) -> String:
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
static func choose_relic(ids: Array, content: ContentDB, aspect: int = 0) -> String:
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
static func relic_score(id: String, content: ContentDB, aspect: int) -> float:
	var rarity: String = str(content.relics.get(id, {}).get("rarity", "common"))
	var score: float = float(str(RELIC_SCORE.get(id,
		{"common": 12, "uncommon": 22, "rare": 34, "boss": 50}.get(rarity, 10))))
	if aspect == 0 and id in ["shatterersCrown", "prismCharm", "executionersSeal"]:
		score += 12.0
	if aspect == 1 and id in ["smolderingCoal", "ashenCore", "thornBand"]:
		score += 16.0
	return score
static func choose_shop(stock: Dictionary, run: RunState, content: ContentDB) -> Array[Dictionary]:
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
		var best_ratio: float = SHOP_MIN_RATIO
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
				var value: float = 16.0
				if category == "relics":
					value = relic_score(id, content, run.aspect)
				elif category == "cards":
					var definition: Dictionary = content.cards.get(id, {})
					value = card_score(definition, run.aspect, id)
				elif id == "healing":
					value = 22.0
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
				if copies >= 3 and wscore <= 6.5:
					var remove_ratio: float = (8.5 - wscore) / float(maxi(remove_cost, 1))
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
