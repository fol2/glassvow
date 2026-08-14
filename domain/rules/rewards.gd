class_name RewardRules
extends RefCounted
## Combat-reward generation — port of the frozen web engine's genCombatRewards
## / rollCardReward / randomRelic (roguecardv2-benchmark@6e06911),
## verified against the 16 recorded reward rows in the slice traces.
##
## THE STALE-CURSOR QUIRK (frozen spec, do not "fix"): in the web engine,
## genCombatRewards holds one rng closure across the call, but rollCardReward
## advances run.rngState through its own closure. The outer closure's next
## write (the potion roll) then OVERWRITES the cursor, discarding every card
## draw. Net cursor movement: gold (1) + potion roll (1) + randomRelic's
## draws for elites — the card draws happen on a chain that is ultimately
## thrown away. We mirror that with a detached Rng for the card rolls.
##
var content: ContentDB


func _init(content_db: ContentDB) -> void:
	content = content_db


static func _ji(v: Variant) -> int:
	return int(float(str(v)))


func _omen_mods(run: RunState) -> Dictionary:
	if run.act < 0 or run.act >= run.omens.size() or run.omens[run.act] == null:
		return {}
	var omen: Dictionary = content.omens.get(str(run.omens[run.act]), {})
	return omen.get("mods", {})


## Reveal-gated card pool (web cardPool): gated ids show only once revealed.
func card_pool(run: RunState, tier: String) -> Array:
	var base: Array = content.card_pools.get(tier, [])
	var out: Array = []
	for id_v: Variant in base:
		var id: String = str(id_v)
		if not _pool_open(run, content.pool_gate_cards, id):
			continue
		out.append(id)
	for unlock_v: Variant in run.unlocks:
		var unlock: String = str(unlock_v)
		if unlock.begins_with("card:"):
			var id: String = unlock.trim_prefix("card:")
			if content.cards.has(id) and content.cards[id].get("rarity") == tier and not out.has(id):
				out.append(id)
	return out


func relic_pool(run: RunState, tier: String) -> Array:
	var base: Array = content.relic_pools.get(tier, [])
	var out: Array = []
	for id_v: Variant in base:
		var id: String = str(id_v)
		if not _pool_open(run, content.pool_gate_relics, id):
			continue
		out.append(id)
	for unlock_v: Variant in run.unlocks:
		var unlock: String = str(unlock_v)
		if unlock.begins_with("relic:"):
			var id: String = unlock.trim_prefix("relic:")
			if content.relics.has(id) and content.relics[id].get("rarity") == tier and not out.has(id):
				out.append(id)
	return out


static func _pool_open(run: RunState, gate: Dictionary, id: String) -> bool:
	if run.reveals_all or not gate.has(id):
		return true
	return run.reveals.has(str(gate[id]))


## {"gold": int, "cards": Array[String], "potion": null|String, "relic": null|String}
func gen_combat_rewards(run: RunState, kind: String, affix: StringName = &"") -> Dictionary:
	var tier_key: String = "boss" if kind == "boss" else ("elite" if kind == "elite" else "normal")
	var act_row: Dictionary = content.reward_gold[
		clampi(run.act, 0, content.reward_gold.size() - 1)]
	var pair: Array = act_row[tier_key]
	var gold: int = run.rng.irange(_ji(pair[0]), _ji(pair[1]))
	var gold_mult: float = float(str(_omen_mods(run).get("goldMult", 1)))
	if affix != &"":
		var af_def: Dictionary = content.affixes.get(String(affix), {})
		var af_mods: Dictionary = af_def.get("mods", {})
		gold_mult *= float(str(af_mods.get("goldMult", 1)))
	gold = int(roundf(float(gold) * gold_mult))
	var cards: Array = _roll_card_reward(run, kind)
	var potion: Variant = null
	if kind != "boss":
		var potion_roll: float = run.rng.next()
		if potion_roll < 0.4 and (run.reveals_all or run.reveals.has("phials")):
			var potion_ids: Array = content.potions.keys()
			potion = potion_ids[run.rng.pick_index(potion_ids.size())]
	var relic: Variant = null
	if kind == "elite":
		relic = _random_relic(run)
	return {"gold": gold, "cards": cards, "potion": potion, "relic": relic}


func _roll_card_reward(run: RunState, kind: String) -> Array:
	# Detached chain: the web quirk discards these draws' cursor movement.
	var crng: Rng = Rng.new(run.rng_state())
	var out: Array = []  # may briefly hold one null from an empty-pool pick
	var guard: Dictionary = {}
	var wanted: int = 3 + (1 if run.has_relic("seersOrb") else 0) \
		+ _ji(_omen_mods(run).get("rewardChoiceBonus", 0))
	while out.size() < wanted and guard.size() < 40:
		var pool_tier: String
		if kind == "boss":
			pool_tier = "rare"
		else:
			var r: float = crng.next()
			if kind == "elite":
				pool_tier = "common" if r < 0.45 else ("uncommon" if r < 0.85 else "rare")
			else:
				pool_tier = "common" if r < 0.6 else ("uncommon" if r < 0.92 else "rare")
		var pool: Array = card_pool(run, pool_tier)
		var idx: int = crng.pick_index(pool.size())  # the pick draw fires even on an empty pool
		var id: Variant = pool[idx] if pool.size() > 0 else null
		var digit: int = int(floorf(crng.next() * 4.0))
		# Web guard key is `id + digit` — string concat for real ids, NaN for an
		# empty-pool undefined (all four digits collapse into one Set entry).
		var guard_key: String = "NaN" if id == null else str(id) + str(digit)
		guard[guard_key] = true
		if not out.has(id):
			out.append(id)
	var cards: Array = []
	for c: Variant in out:
		if c != null:  # the exporter's canonical JSON strips the undefined slot
			cards.append(c)
	return cards


func roll_boss_relics(run: RunState) -> Array[String]:
	var available: Array[String] = []
	for id_v: Variant in relic_pool(run, "boss"):
		var id: String = str(id_v)
		if not run.player.relics.has(id):
			available.append(id)
	var out: Array[String] = []
	while out.size() < mini(3, available.size()):
		var id: String = available[run.rng.pick_index(available.size())]
		if not out.has(id):
			out.append(id)
	return out


func roll_encounter(run: RunState, type: String, row: int, node: MapNode = null) -> Array[String]:
	if node != null and node.quest_variant_id != null:
		return [str(node.quest_variant_id)]
	var act_encounters: Dictionary = content.encounters[clampi(run.act, 0, content.encounters.size() - 1)]
	var pool_key: String = "boss" if type == "boss" else (
		"elite" if type == "elite" else ("weak" if row < 3 else "normal")
	)
	var pool: Array = act_encounters.get(pool_key, [])
	var picked: Array = pool[run.rng.pick_index(pool.size())]
	var out: Array[String] = []
	for id_v: Variant in picked:
		out.append(str(id_v))
	return out


func rest_heal_fraction(run: RunState) -> float:
	var fraction: float = minf(0.3, float(str(_omen_mods(run).get("restHealFrac", 0.3))))
	for i: int in range(clampi(run.vow, 0, content.vows.size())):
		var vow: Dictionary = content.vows[i]
		var mods: Dictionary = vow.get("mods", {})
		fraction = minf(fraction, float(str(mods.get("restHealFrac", 1))))
	return fraction


func roll_event(run: RunState) -> String:
	var seen_v: Variant = run.quest_scratch.get("seenEvents", [])
	var seen: Array = seen_v if typeof(seen_v) == TYPE_ARRAY else []
	var available: Array[String] = []
	for id_v: Variant in content.events.keys():
		var id: String = str(id_v)
		if not seen.has(id):
			available.append(id)
	if available.is_empty():
		seen.clear()
		for id_v: Variant in content.events.keys():
			available.append(str(id_v))
	var picked: String = available[run.rng.pick_index(available.size())]
	seen.append(picked)
	run.quest_scratch["seenEvents"] = seen
	return picked


## Pure semantic checks for route checkpoints already produced and applied.
func valid_event_checkpoint(run: RunState, event_id: String, value: Variant) -> bool:
	if not content.events.has(event_id) or typeof(value) != TYPE_DICTIONARY:
		return false
	var pending: Dictionary = value
	if typeof(pending.get("kind")) != TYPE_STRING:
		return false
	var kind: String = pending["kind"]
	var authored_count: int = -1
	var event: Dictionary = content.events[event_id]
	for choice_v: Variant in event.get("choices", []):
		var choice: Dictionary = choice_v
		for op_v: Variant in choice.get("ops", []):
			var op: Dictionary = op_v
			if kind == "card" and op.has("pickCard"):
				authored_count = maxi(authored_count, _ji(op["pickCard"]))
			elif kind == "remove" and op.get("pickRemove", false) == true:
				authored_count = 0
			elif kind == "upgrade" and op.get("pickUpgrade", false) == true:
				authored_count = 0
			elif kind == "duplicate" and op.get("pickDuplicate", false) == true:
				authored_count = 0
	if authored_count < 0:
		return false
	if kind != "card":
		return pending.size() == 1
	if pending.size() != 2 or typeof(pending.get("cards")) != TYPE_ARRAY:
		return false
	var cards: Array = pending["cards"]
	if cards.is_empty() or cards.size() > authored_count:
		return false
	var eligible: Array = []
	for tier: String in ["common", "uncommon", "rare"]:
		eligible.append_array(card_pool(run, tier))
	var seen: Dictionary = {}
	for id_v: Variant in cards:
		if typeof(id_v) != TYPE_STRING or seen.has(id_v) or not eligible.has(id_v):
			return false
		seen[id_v] = true
	return true


func claim_treasure(run: RunState) -> Dictionary:
	var id_v: Variant = _random_relic(run)
	if id_v == null:
		run.player.gold += 60
		return {"relic": null, "gold": 60}
	var id: String = str(id_v)
	gain_relic(run, id)
	return {"relic": id, "gold": 0}


func valid_treasure_checkpoint(run: RunState, value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var claim: Dictionary = value
	if claim.size() != 2 or not claim.has("relic") or not _whole_nonnegative(claim.get("gold")):
		return false
	var eligible: Array = []
	for tier: String in ["common", "uncommon", "rare"]:
		eligible.append_array(relic_pool(run, tier))
	var relic_v: Variant = claim["relic"]
	if relic_v != null:
		return typeof(relic_v) == TYPE_STRING and _ji(claim["gold"]) == 0 \
			and eligible.has(relic_v) and run.player.relics.has(relic_v)
	if _ji(claim["gold"]) != 60 or run.player.gold < 60:
		return false
	for id_v: Variant in eligible:
		if not run.player.relics.has(str(id_v)):
			return false
	return true


func gain_relic(run: RunState, id: String) -> bool:
	if not content.relics.has(id) or run.player.relics.has(id):
		return false
	var relic: Dictionary = content.relics[id]
	var replaced: String = str(relic.get("replaces", ""))
	if not replaced.is_empty():
		run.player.relics.erase(replaced)
	run.player.relics.append(id)
	match id:
		"sweetRoot":
			run.player.max_hp += 8
			run.player.hp += 8
		"hollowCrown":
			run.player.energy_max += 1
			run.player.max_hp = maxi(1, run.player.max_hp - 10)
			run.player.hp = mini(run.player.hp, run.player.max_hp)
	return true


func apply_boon(run: RunState, id: String) -> bool:
	if not content.boons.has(id):
		return false
	var before: Dictionary = {
		"gold": run.player.gold,
		"hp": run.player.hp,
		"maxHp": run.player.max_hp,
		"energyMax": run.player.energy_max,
		"goldEarned": _ji(run.stats.get("goldEarned", 0)),
		"relics": run.player.relics.duplicate(),
		"potions": run.player.potions.duplicate(),
	}
	var boon: Dictionary = content.boons[id]
	var ops: Array = boon.get("ops", [])
	apply_event_ops(run, ops)
	var relics_added: Array[String] = []
	for relic_id: String in run.player.relics:
		if not before["relics"].has(relic_id):
			relics_added.append(relic_id)
	var potion_slots_added: Array[Dictionary] = []
	for slot: int in range(run.player.potions.size()):
		if run.player.potions[slot] != "" and run.player.potions[slot] != before["potions"][slot]:
			potion_slots_added.append({"index": slot, "id": run.player.potions[slot]})
	run.boon = id
	run.boon_receipt = {
		"id": id,
		"playerDelta": {
			"gold": run.player.gold - _ji(before["gold"]),
			"hp": run.player.hp - _ji(before["hp"]),
			"maxHp": run.player.max_hp - _ji(before["maxHp"]),
			"energyMax": run.player.energy_max - _ji(before["energyMax"]),
		},
		"statsGoldEarned": _ji(run.stats.get("goldEarned", 0)) - _ji(before["goldEarned"]),
		"relicsAdded": relics_added,
		"potionSlotsAdded": potion_slots_added,
	}
	return true


func reverse_boon(run: RunState) -> bool:
	if typeof(run.boon_receipt) != TYPE_DICTIONARY:
		return false
	var receipt: Dictionary = run.boon_receipt
	if run.boon == null or str(run.boon) != str(receipt.get("id", "")):
		return false
	var delta: Dictionary = receipt.get("playerDelta", {})
	if _ji(delta.get("gold", 0)) > 0 and run.player.gold < _ji(delta["gold"]):
		return false
	for id_v: Variant in receipt.get("relicsAdded", []):
		if not run.player.relics.has(str(id_v)):
			return false
	for row_v: Variant in receipt.get("potionSlotsAdded", []):
		var row: Dictionary = row_v
		var slot: int = _ji(row.get("index", -1))
		if slot < 0 or slot >= run.player.potions.size() \
				or run.player.potions[slot] != str(row.get("id", "")):
			return false
	for id_v: Variant in receipt.get("relicsAdded", []):
		run.player.relics.erase(str(id_v))
	for row_v: Variant in receipt.get("potionSlotsAdded", []):
		var row: Dictionary = row_v
		run.player.potions[_ji(row["index"])] = ""
	run.player.gold -= _ji(delta.get("gold", 0))
	run.player.energy_max = maxi(1, run.player.energy_max - _ji(delta.get("energyMax", 0)))
	run.player.max_hp = maxi(1, run.player.max_hp - _ji(delta.get("maxHp", 0)))
	run.player.hp = clampi(run.player.hp - _ji(delta.get("hp", 0)), 1, run.player.max_hp)
	run.stats["goldEarned"] = maxi(0,
		_ji(run.stats.get("goldEarned", 0)) - _ji(receipt.get("statsGoldEarned", 0)))
	run.boon = null
	run.boon_receipt = null
	return true


func gen_shop(run: RunState) -> Dictionary:
	var discount: float = (0.75 if run.has_relic("merchantsMark") else 1.0) \
		* float(str(_omen_mods(run).get("shopMult", 1)))
	var cards: Array = []
	for tier: String in ["common", "common", "uncommon", "uncommon", "rare"]:
		var pool: Array = card_pool(run, tier)
		var id: String = str(pool[run.rng.pick_index(pool.size())])
		var price_pair: Array = content.shop["cardPrice"][tier]
		cards.append({
			"id": id,
			"price": int(roundf(float(run.rng.irange(_ji(price_pair[0]), _ji(price_pair[1]))) * discount)),
			"sold": false,
		})
	var relics: Array = []
	for tier: String in ["common", "uncommon"]:
		var available: Array = relic_pool(run, tier).filter(
			func(id_v: Variant) -> bool: return not run.player.relics.has(str(id_v))
		)
		if not available.is_empty():
			var id: String = str(available[run.rng.pick_index(available.size())])
			var price_pair: Array = content.shop["relicPrice"][tier]
			relics.append({
				"id": id,
				"price": int(roundf(float(run.rng.irange(
					_ji(price_pair[0]), _ji(price_pair[1]))) * discount)),
				"sold": false,
			})
	var potions: Array = []
	if run.reveals_all or run.reveals.has("phials"):
		var potion_ids: Array = content.potions.keys()
		var potion_price: Array = content.shop["potionPrice"]
		for _i: int in range(2):
			potions.append({
				"id": str(potion_ids[run.rng.pick_index(potion_ids.size())]),
				"price": int(roundf(float(run.rng.irange(
					_ji(potion_price[0]), _ji(potion_price[1]))) * discount)),
				"sold": false,
			})
	return {
		"cards": cards,
		"relics": relics,
		"potions": potions,
		"removeCost": int(roundf(float(_ji(content.shop.get("removeCost", 75))) * discount)),
		"removed": false,
	}


func valid_shop_checkpoint(run: RunState, value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var stock: Dictionary = value
	if not _exact_keys(stock, ["cards", "relics", "potions", "removeCost", "removed"]) \
			or typeof(stock["cards"]) != TYPE_ARRAY or typeof(stock["relics"]) != TYPE_ARRAY \
			or typeof(stock["potions"]) != TYPE_ARRAY or not _whole_nonnegative(stock["removeCost"]) \
			or typeof(stock["removed"]) != TYPE_BOOL:
		return false
	var bought_mark: bool = false
	for row_v: Variant in stock["relics"]:
		if typeof(row_v) == TYPE_DICTIONARY:
			var row: Dictionary = row_v
			bought_mark = bought_mark or (row.get("id") == "merchantsMark" and row.get("sold") == true)
	var creation_mark: bool = run.has_relic("merchantsMark") and not bought_mark
	var discount: float = (0.75 if creation_mark else 1.0) \
		* float(str(_omen_mods(run).get("shopMult", 1)))
	var card_tiers: Array[String] = ["common", "common", "uncommon", "uncommon", "rare"]
	var cards: Array = stock["cards"]
	if cards.size() != card_tiers.size():
		return false
	for i: int in range(cards.size()):
		if not _valid_shop_row(cards[i], card_pool(run, card_tiers[i]),
				content.shop["cardPrice"][card_tiers[i]], discount):
			return false

	var seen_tiers: Dictionary = {}
	var previous_tier: int = -1
	for row_v: Variant in stock["relics"]:
		var tier: String = ""
		if typeof(row_v) == TYPE_DICTIONARY:
			var row: Dictionary = row_v
			for candidate: String in ["common", "uncommon"]:
				if relic_pool(run, candidate).has(row.get("id")):
					tier = candidate
					break
		var tier_index: int = ["common", "uncommon"].find(tier)
		if tier_index <= previous_tier or seen_tiers.has(tier) or not _valid_shop_row(row_v,
				relic_pool(run, tier), content.shop["relicPrice"][tier], discount):
			return false
		previous_tier = tier_index
		var relic_row: Dictionary = row_v
		if relic_row["sold"] != run.player.relics.has(relic_row["id"]):
			return false
		seen_tiers[tier] = true
	for tier: String in ["common", "uncommon"]:
		if not seen_tiers.has(tier):
			for id_v: Variant in relic_pool(run, tier):
				if not run.player.relics.has(str(id_v)):
					return false

	var potions: Array = stock["potions"]
	var expected_potions: int = 2 if run.reveals_all or run.reveals.has("phials") else 0
	if potions.size() != expected_potions:
		return false
	for row_v: Variant in potions:
		if not _valid_shop_row(row_v, content.potions.keys(), content.shop["potionPrice"], discount):
			return false
	return _ji(stock["removeCost"]) == int(roundf(float(_ji(content.shop["removeCost"])) * discount))


static func _exact_keys(row: Dictionary, wanted: Array) -> bool:
	if row.size() != wanted.size():
		return false
	for key: Variant in wanted:
		if not row.has(key):
			return false
	return true


static func _whole_nonnegative(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var encoded: String = str(value)
	if encoded in ["inf", "-inf", "nan"]:
		return false
	var number: float = float(encoded)
	return is_finite(number) and number >= 0.0 and number == floorf(number)


func _valid_shop_row(row_v: Variant, pool: Array, price_pair: Variant, discount: float) -> bool:
	if typeof(row_v) != TYPE_DICTIONARY:
		return false
	var row: Dictionary = row_v
	if not _exact_keys(row, ["id", "price", "sold"]) or typeof(row["id"]) != TYPE_STRING \
			or not _whole_nonnegative(row["price"]) or typeof(row["sold"]) != TYPE_BOOL \
			or not pool.has(row["id"]):
		return false
	for authored: int in range(_ji(price_pair[0]), _ji(price_pair[1]) + 1):
		if _ji(row["price"]) == int(roundf(float(authored) * discount)):
			return true
	return false


func apply_event_ops(run: RunState, ops: Array) -> Dictionary:
	for op_v: Variant in ops:
		var op: Dictionary = op_v
		if op.has("roll"):
			var branches: Array = op["roll"]
			var roll: float = run.rng.next()
			var acc: float = 0.0
			for branch_v: Variant in branches:
				var branch: Dictionary = branch_v
				acc += float(str(branch.get("p", 0)))
				if roll < acc:
					var nested_ops: Array = branch.get("ops", [])
					var nested: Dictionary = apply_event_ops(run, nested_ops)
					nested["text"] = str(branch.get("text", ""))
					return nested
		elif op.has("gold"):
			var gold: int = _ji(op["gold"])
			run.player.gold = maxi(0, run.player.gold + gold)
			if gold > 0:
				run.stats["goldEarned"] = _ji(run.stats.get("goldEarned", 0)) + gold
		elif op.has("hp"):
			run.player.hp = clampi(run.player.hp + _ji(op["hp"]), 1, run.player.max_hp)
		elif op.has("heal"):
			run.player.hp = mini(run.player.max_hp,
				run.player.hp + int(roundf(float(run.player.max_hp) * float(str(op["heal"])))))
		elif op.has("maxHp"):
			var delta: int = _ji(op["maxHp"])
			run.player.max_hp = maxi(1, run.player.max_hp + delta)
			run.player.hp = mini(run.player.max_hp, maxi(1, run.player.hp + maxi(0, delta)))
		elif op.has("addCard"):
			run.player.deck.append(CardInst.new(run.next_uid(), StringName(str(op["addCard"])), false))
		elif op.has("addRelic"):
			var relic_v: Variant = _random_relic(run) if str(op["addRelic"]) == "random" else op["addRelic"]
			if relic_v != null:
				gain_relic(run, str(relic_v))
			else:
				run.player.gold += 50
		elif op.has("potion"):
			if not run.reveals_all and not run.reveals.has("phials"):
				continue
			var potion_id: String = str(op["potion"])
			if potion_id == "random":
				var potion_ids: Array = content.potions.keys()
				potion_id = str(potion_ids[run.rng.pick_index(potion_ids.size())])
			var slot: int = run.player.potions.find("")
			if slot >= 0:
				run.player.potions[slot] = potion_id
		elif op.get("pickRemove", false):
			return {"kind": "remove"}
		elif op.get("pickUpgrade", false):
			return {"kind": "upgrade"}
		elif op.get("pickDuplicate", false):
			return {"kind": "duplicate"}
		elif op.has("pickCard"):
			return {"kind": "card", "cards": roll_event_cards(run, _ji(op["pickCard"]))}
	return {"kind": ""}


func roll_event_cards(run: RunState, count: int) -> Array[String]:
	var weighted: Array = []
	weighted.append_array(card_pool(run, "common"))
	weighted.append_array(card_pool(run, "common"))
	weighted.append_array(card_pool(run, "uncommon"))
	weighted.append_array(card_pool(run, "uncommon"))
	weighted.append_array(card_pool(run, "rare"))
	var out: Array[String] = []
	var guard: int = 0
	while out.size() < count and guard < 60:
		guard += 1
		var id: String = str(weighted[run.rng.pick_index(weighted.size())])
		if not out.has(id):
			out.append(id)
	return out


## Web randomRelic: tier roll on the SHARED cursor (its closure's writes are
## the last ones, so they stick), then first non-empty pool wins. Every slice
## relic pool is empty -> null after exactly one draw.
func _random_relic(run: RunState) -> Variant:
	var r: float = run.rng.next()
	var order: Array[String] = ["common", "uncommon", "rare"]
	var weights: Dictionary = {"common": 0.5, "uncommon": 0.35, "rare": 0.15}
	var tier: String = "common"
	var acc: float = 0.0
	for t: String in order:
		acc += float(str(weights[t]))
		if r < acc:
			tier = t
			break
	var idx: int = order.find(tier)
	for i: int in range(order.size()):
		var t: String = order[(idx + i) % order.size()]
		var avail: Array = []
		for id_v: Variant in relic_pool(run, t):
			var id: String = str(id_v)
			if not run.player.relics.has(id):
				avail.append(id)
		if avail.size() > 0:
			return avail[run.rng.pick_index(avail.size())]
	return null
