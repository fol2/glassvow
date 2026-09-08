extends CombatRules
func play_card(run: RunState, cb: CombatState, uid: int, target_idx: Variant = null) -> bool:
	var i: int = -1
	for k: int in range(cb.hand.size()):
		if cb.hand[k].uid == uid:
			i = k
			break
	if i < 0:
		return false
	var inst: CardInst = cb.hand[i]
	var d: Dictionary = card_data(inst)
	if not can_play(run, cb, inst, target_idx):
		return false
	var p: PlayerCombatant = cb.player
	var cost: int = eff_cost(run, cb, inst)
	p.energy -= cost
	if run.has_relic("duskmirror") and not cb.first_card_played and _ji(d.get("cost", 0)) > 0:
		_proc(cb, "duskmirror")
	cb.first_card_played = true
	cb.hand.remove_at(i)
	cb.counters_played += 1
	run.stats["cardsPlayed"] = _ji(run.stats.get("cardsPlayed", 0)) + 1
	cb.queue.append({"t": EventTypes.PLAY, "uid": inst.uid, "id": String(inst.id), "targetIdx": target_idx})
	cb.queue.append({"t": EventTypes.ENERGY, "n": p.energy})

	var card_type: String = str(d.get("type", ""))
	var seal_mult: int = 1
	if card_type == "attack":
		cb.counters_attacks += 1
		if run.has_relic("ironTalisman") and cb.counters_attacks % 3 == 0:
			add_status_player(cb, "str", 1)
			_proc(cb, "ironTalisman")
		if run.has_relic("executionersSeal") and cb.counters_attacks % 10 == 0:
			seal_mult = 2
			_proc(cb, "executionersSeal")
	var target: EnemyCombatant = null
	if target_idx != null:
		var ti: int = target_idx
		target = cb.enemies[ti]

	cb.pending_chips_active = true  # facet chips land after the whole card resolves
	cb.pending_chips = {}
	var effects: Array = d.get("effects", [])
	if effects.size() == 2:
		if not cb.over:
			_apply_effect(run, cb, inst, d, effects[0], target, seal_mult)
		if not cb.over:
			_apply_effect(run, cb, inst, d, effects[1], target, seal_mult)
	else:
		for fx_v: Variant in effects:
			if cb.over:
				break
			var fx: Dictionary = fx_v
			_apply_effect(run, cb, inst, d, fx, target, seal_mult)
	if cb.pending_chips_active and not cb.over:
		var per: int = 0
		if card_type == "attack":
			per = 1 + _ji(d.get("chip", 0)) + _sget(p.statuses, "beacon")
		for idx_v: Variant in cb.pending_chips.keys():  # insertion order == JS Map order
			var idx: int = idx_v
			var rec: Dictionary = cb.pending_chips[idx]
			var e: EnemyCombatant = cb.enemies[idx]
			if e.hp <= 0 or cb.over:
				continue
			var hit_flag: bool = rec["hit"]
			var extra: int = rec["extra"]
			var n: int = (per if hit_flag else 0) + extra
			if n > 0:
				apply_chips(run, cb, e, n)
	cb.pending_chips_active = false
	cb.pending_chips = {}
	if not cb.over and card_type == "attack" and _sget(p.statuses, "venomous") > 0:
		var venom_targets: Array[EnemyCombatant] = []
		if str(d.get("target", "")) == "allEnemies":
			venom_targets = cb.living_enemies()
		elif target != null and target.hp > 0:
			venom_targets.append(target)
		for e: EnemyCombatant in venom_targets:
			add_status_enemy(cb, e, "poison", _sget(p.statuses, "venomous"), run)
	if not cb.over and run.has_relic("silkFan") and cb.counters_played % 3 == 0:
		gain_block_player(cb, 3, false, run)
		_proc(cb, "silkFan")

	if card_type == "power":
		cb.queue.append({"t": EventTypes.POWER_CONSUMED, "uid": inst.uid})
	else:
		var exhaust_flag: bool = d.get("exhaust", false)
		if exhaust_flag:
			exhaust_card(run, cb, inst)
		else:
			cb.discard.append(inst)
			cb.queue.append({"t": EventTypes.TO_DISCARD, "uid": inst.uid})
	return true
