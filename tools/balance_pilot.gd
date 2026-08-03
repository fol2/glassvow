class_name BalancePilot
extends RefCounted
## Block lethal, else kill-lowest; Dusk favours Eclipse/Shatter, Ash stacks Smolder highest and blocks with Smother.
## Routes favour treasure, then low-HP rest; rewards take the highest card/relic score and one affordable shop item.
## Potions heal at 20 missing HP, block lethal intent, and spend offensive stock in elite/boss fights.
const VERSION: String = "p6-b0-v1"
const RELIC_SCORE: Dictionary = {"hollowCrown": 90, "crownOfCinders": 80,
	"crownOfTheHearth": 75, "shatterersCrown": 70, "crownOfTithes": 65}
static func choose_node(map: WorldMap, run: RunState) -> int:
	var best: int = map.reachable()[0]
	var best_score: int = -1
	var low: bool = run.player.hp * 100 <= run.player.max_hp * 60
	for i: int in map.reachable():
		var n: MapNode = map.nodes[i]
		var score: int = {
			"boss": 1000, "treasure": 900, "rest": 800 if low else 150,
			"shop": 500 if run.player.gold >= 45 else 100, "event": 400,
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
	var lethal: bool = _incoming(game) - game.cb.player.block >= game.cb.player.hp
	var best: Dictionary = {}
	var best_score: float = -INF
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
		if String(card.id) == "smother" or not _advances_fight(d):
			continue
		var score: float = card_score(d, game.run.aspect)
		if game.run.aspect == 0 and String(card.id) == "eclipseSlash":
			score += 1000.0
		if preview.get("willShatter", false):
			score += 500.0
		if preview.get("lethal", false):
			score += 300.0
		if score > best_score:
			best = {"uid": card.uid, "target": target}
			best_score = score
	return best
static func _target(game: GlassvowGame, card: CardInst, d: Dictionary) -> Variant:
	if str(d.get("target", "")) != "enemy":
		return null
	var living: Array[EnemyCombatant] = game.cb.living_enemies()
	var poison: bool = _has_effect(d, "status", "poison") \
		or _has_effect(d, "special", "catalyst")
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
static func card_score(d: Dictionary, aspect: int) -> float:
	var score: float = float(str({"starter": 0, "common": 4, "uncommon": 8, "rare": 12}.get(
		str(d.get("rarity", "starter")), 0))) - float(str(d.get("cost", 0)))
	for fx_v: Variant in d.get("effects", []):
		var fx: Dictionary = fx_v
		match str(fx.get("kind", "")):
			"dmg": score += float(str(fx.get("n", 0))) * float(str(fx.get("times", 1)))
			"block", "heal": score += float(str(fx.get("n", 0))) * 0.7
			"draw", "energy": score += float(str(fx.get("n", 0))) * 4.0
			"chip": score += float(str(fx.get("n", 0))) * (5.0 if aspect == 0 else 3.0)
			"status":
				if str(fx.get("id", "")) == "poison":
					score += float(str(fx.get("n", 0))) * (5.0 if aspect == 1 else 2.0)
			"special": score += 8.0
	if str(d.get("type", "")) == "power":
		score += 8.0
	return score + float(str(d.get("chip", 0))) * (5.0 if aspect == 0 else 3.0)
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
		var definition: Dictionary = content.cards.get(id, {})
		var candidate: float = card_score(definition, aspect)
		if candidate > score:
			best = id
			score = candidate
	return best
static func choose_relic(ids: Array, content: ContentDB) -> String:
	var best: String = ""
	var score: int = -1
	for id_v: Variant in ids:
		var id: String = str(id_v)
		var rarity: String = str(content.relics.get(id, {}).get("rarity", "common"))
		var candidate: int = int(float(str(RELIC_SCORE.get(id, {"common": 10, "uncommon": 20, "rare": 30}.get(rarity, 0)))))
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
		var candidate: float = card_score(definition, run.aspect)
		if candidate < score:
			worst = card
			score = candidate
	return worst
