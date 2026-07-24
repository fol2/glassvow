class_name RewardRules
extends RefCounted
## Combat-reward generation — port of the frozen web engine's genCombatRewards
## / rollCardReward / randomRelic (roguecardv2 src/engine.js @ web-reference-v1),
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
## Slice scope: seersOrb/omen choice bonus, goldMult omens, phial reveal, and
## unlock-extended pools are not ported (no slice source).


var content: ContentDB


func _init(content_db: ContentDB) -> void:
	content = content_db


static func _ji(v: Variant) -> int:
	return int(float(str(v)))


## Reveal-gated card pool (web cardPool): gated ids show only once revealed.
func card_pool(run: RunState, tier: String) -> Array:
	var base: Array = content.card_pools.get(tier, [])
	var out: Array = []
	for id_v: Variant in base:
		var id: String = str(id_v)
		if not _pool_open(run, content.pool_gate_cards, id):
			continue
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
	return out


static func _pool_open(run: RunState, gate: Dictionary, id: String) -> bool:
	if run.reveals_all or not gate.has(id):
		return true
	return run.reveals.has(str(gate[id]))


## {"gold": int, "cards": Array[String], "potion": null|String, "relic": null|String}
func gen_combat_rewards(run: RunState, kind: String, affix: StringName = &"") -> Dictionary:
	var tier_key: String = "boss" if kind == "boss" else ("elite" if kind == "elite" else "normal")
	var act_row: Dictionary = content.reward_gold[run.act]
	var pair: Array = act_row[tier_key]
	var gold: int = run.rng.irange(_ji(pair[0]), _ji(pair[1]))
	var gold_mult: float = 1.0  # omen goldMult: not ported
	if affix != &"":
		var af_def: Dictionary = content.affixes.get(String(affix), {})
		var af_mods: Dictionary = af_def.get("mods", {})
		gold_mult *= float(str(af_mods.get("goldMult", 1)))
	gold = int(roundf(float(gold) * gold_mult))
	var cards: Array = _roll_card_reward(run, kind)
	var potion: Variant = null
	if kind != "boss":
		var potion_roll: float = run.rng.next()
		# The draw fires unconditionally; the phial itself needs the "phials"
		# reveal, which a fresh profile does not have. Full port: when revealed
		# and potion_roll < 0.4, pick from the potion registry (more draws).
		if potion_roll < 0.4 and run.reveals_all:
			push_error("RewardRules: phial reward path not ported")
	var relic: Variant = null
	if kind == "elite":
		relic = _random_relic(run)
	return {"gold": gold, "cards": cards, "potion": potion, "relic": relic}


func _roll_card_reward(run: RunState, kind: String) -> Array:
	# Detached chain: the web quirk discards these draws' cursor movement.
	var crng: Rng = Rng.new(run.rng_state())
	var out: Array = []  # may briefly hold one null from an empty-pool pick
	var guard: Dictionary = {}
	while out.size() < 3 and guard.size() < 40:
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
