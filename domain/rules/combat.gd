class_name CombatRules
extends RefCounted
## Combat core — port of the frozen web engine (roguecardv2 src/engine.js at
## tag web-reference-v1). Every calculation and event mirrors the source; the
## fixture suites (tests/test_combat_probes.gd, tests/test_combat_traces.gd)
## are the proof.
##
## Slice scope (full content wave lands post-gate): quests, omens, vows > 0,
## relic hooks other than emberHeart, enemy variants, and the affix mods the
## slice affix (vitrified) does not carry (startBlock / startStatus / adamant /
## attackApplies) are not ported. Player thorns and enemy ramp/heal/addCards
## moves have no slice source either. Damage law is sequential floors:
## base+str -> weak floor(x0.75) -> vulnerable floor(x1.5) -> max(0, .);
## block gains round.


var content: ContentDB


func _init(content_db: ContentDB) -> void:
	content = content_db


## JSON numbers arrive as float; whole values are exact.
static func _ji(v: Variant) -> int:
	return int(float(str(v)))


## Status stack read (statuses never hold non-int values).
static func _sget(statuses: Dictionary, id: String) -> int:
	var n: int = statuses.get(id, 0)
	return n


## Resolved card data: base def merged with its `up` overrides when upgraded.
func card_data(inst: CardInst) -> Dictionary:
	var base: Dictionary = content.card(inst.id)
	if not inst.up or not base.has("up"):
		return base
	var merged: Dictionary = base.duplicate()
	var up: Dictionary = base["up"]
	for k: Variant in up.keys():
		merged[k] = up[k]
	return merged


# ---------------------------------------------------------------- start

func start_combat(
	run: RunState, enemy_ids: Array, kind: StringName, affix: StringName = &""
) -> CombatState:
	var rng: Rng = run.rng
	var cb: CombatState = CombatState.new()
	cb.kind = kind
	# Every elite arrives wearing a title (web: opts.affix || pick(rng, keys)).
	if kind == &"elite":
		if affix == &"":
			var keys: Array = content.affixes.keys()
			affix = StringName(str(keys[rng.pick_index(keys.size())]))
		cb.affix = affix
	var af: Dictionary = {}
	if cb.affix != &"":
		var af_def: Dictionary = content.affixes[String(cb.affix)]
		af = af_def.get("mods", {})
	var af_hp_mult: float = float(str(af.get("hpMult", 1)))
	var af_facet_delta: int = _ji(af.get("facetDelta", 0))

	cb.player.hp = run.player.hp
	cb.player.max_hp = run.player.max_hp
	cb.player.energy_max = run.player.energy_max

	var i: int = 0
	for id_v: Variant in enemy_ids:
		var eid: StringName = StringName(str(id_v))
		var d: Dictionary = content.enemy(eid)
		var e: EnemyCombatant = EnemyCombatant.new()
		e.key = eid
		e.def = d
		e.idx = i
		e.name = str(d.get("name", ""))
		var hp_pair: Array = d["hp"]
		e.max_hp = int(roundf(float(rng.irange(_ji(hp_pair[0]), _ji(hp_pair[1]))) * af_hp_mult))
		e.hp = e.max_hp
		var start_status: Dictionary = d.get("startStatus", {})
		for k: Variant in start_status.keys():
			e.statuses[str(k)] = _ji(start_status[k])
		var elite_flag: bool = d.get("elite", false)
		var boss_flag: bool = d.get("boss", false)
		e.elite = elite_flag
		e.boss = boss_flag
		var facets_default: int = 6 if e.boss else (5 if e.elite else 4)
		var facets: int = _ji(d.get("facets", facets_default))
		# Every creature is glass: fill its facet gauge and it shatters.
		e.facet_max = maxi(2, facets + af_facet_delta)
		cb.enemies.append(e)
		i += 1

	# Deck: fresh combat copies of the run deck, then one shuffle.
	for c: CardInst in run.player.deck:
		cb.draw.append(c.combat_copy())
	_shuffle_cards(rng, cb.draw)
	_compute_intents(run, cb)
	_start_player_turn(run, cb)
	return cb


## Fisher-Yates, identical draw order to the web shuffle().
static func _shuffle_cards(rng: Rng, arr: Array[CardInst]) -> void:
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = rng.pick_index(i + 1)
		var tmp: CardInst = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _compute_intents(run: RunState, cb: CombatState) -> void:
	for e: EnemyCombatant in cb.enemies:
		if e.hp <= 0:
			continue
		var last: String = e.last_moves[e.last_moves.size() - 1] if e.last_moves.size() >= 1 else ""
		var prev: String = e.last_moves[e.last_moves.size() - 2] if e.last_moves.size() >= 2 else ""
		e.move_key = EnemyAi.decide(
			e.key, cb.turn + 1, last, prev, float(e.hp) / float(e.max_hp), run.rng
		)
		cb.queue.append({"t": EventTypes.INTENT, "idx": e.idx, "move": String(e.move_key)})


func _start_player_turn(run: RunState, cb: CombatState) -> void:
	if cb.over:
		return
	cb.turn += 1
	var p: PlayerCombatant = cb.player
	cb.queue.append({"t": EventTypes.TURN, "n": cb.turn})
	# Smolder ticks at the start of your turn.
	var poison: int = _sget(p.statuses, "poison")
	if poison > 0:
		damage_player(run, cb, poison, "poison")
		poison -= 1
		if poison == 0:
			p.statuses.erase("poison")
		else:
			p.statuses["poison"] = poison
		if cb.over:
			return
	if _sget(p.statuses, "barricade") == 0:
		p.block = 0
	var ritual: int = _sget(p.statuses, "ritual")
	if ritual > 0:
		add_status_player(cb, "str", ritual)
	var emberflow: int = _sget(p.statuses, "emberflow")
	if emberflow > 0:
		gain_embers(run, cb, emberflow)
	p.energy = p.energy_max + _sget(p.statuses, "energized")
	cb.first_card_played = false
	cb.queue.append({"t": EventTypes.ENERGY, "n": p.energy})
	var draws: int = 5 + _sget(p.statuses, "nightsight")
	draw_cards(run, cb, maxi(1, draws))


func draw_cards(run: RunState, cb: CombatState, n: int) -> void:
	for _i: int in range(n):
		if cb.hand.size() >= 10:
			break
		if cb.draw.is_empty():
			if cb.discard.is_empty():
				break
			var count: int = cb.discard.size()
			cb.draw = cb.discard
			cb.discard = []
			_shuffle_cards(run.rng, cb.draw)
			cb.queue.append({"t": EventTypes.RESHUFFLE, "n": count})
		var c: CardInst = cb.draw.pop_back()
		cb.hand.append(c)
		cb.queue.append({"t": EventTypes.DRAW, "uid": c.uid, "id": String(c.id)})


# ---------------------------------------------------------------- shared laws

func add_status_player(cb: CombatState, id: String, n: int) -> void:
	_add_status(cb, cb.player.statuses, "player", id, n)


func add_status_enemy(cb: CombatState, e: EnemyCombatant, id: String, n: int) -> void:
	_add_status(cb, e.statuses, e.idx, id, n)


func _add_status(cb: CombatState, statuses: Dictionary, who: Variant, id: String, n: int) -> void:
	var next: int = _sget(statuses, id) + n
	if next == 0:
		statuses.erase(id)
	else:
		statuses[id] = next
	cb.queue.append({"t": EventTypes.STATUS, "who": who, "id": id, "n": n})


## Spilled fire, caught by your lantern. Negative n = spent. Returns the delta.
func gain_embers(_run: RunState, cb: CombatState, n: int) -> int:
	var next: int = clampi(cb.embers + n, 0, cb.ember_cap)
	var delta: int = next - cb.embers
	if delta == 0:
		return 0
	cb.embers = next
	cb.queue.append({"t": EventTypes.EMBER, "n": delta, "total": cb.embers})
	return delta


## Damage the player. source: enemy idx | "thorns" | "poison" | "burn" | "self".
func damage_player(
	run: RunState,
	cb: CombatState,
	base: int,
	source: Variant,
	is_attack: bool = false,
	attacker: EnemyCombatant = null
) -> int:
	if cb.over:
		return 0
	var p: PlayerCombatant = cb.player
	var dmg: int = base
	if is_attack and attacker != null:
		dmg += _sget(attacker.statuses, "str")
		if _sget(attacker.statuses, "weak") > 0:
			dmg = int(floorf(float(dmg) * 0.75))
		if _sget(p.statuses, "vulnerable") > 0:
			dmg = int(floorf(float(dmg) * 1.5))
	dmg = maxi(0, dmg)
	var blocked: int = 0
	if is_attack or str(source) == "thorns":  # poison/burn/self ignore block
		blocked = mini(p.block, dmg)
		p.block -= blocked
	var loss: int = dmg - blocked
	p.hp -= loss
	cb.hp_lost += maxi(0, loss)
	cb.queue.append({
		"t": EventTypes.HIT_PLAYER,
		"amount": loss,
		"blocked": blocked,
		"hpAfter": maxi(0, p.hp),
		"source": source,
	})
	if p.hp <= 0:
		lose_combat(run, cb)
		return loss
	return loss


func lose_combat(run: RunState, cb: CombatState) -> void:
	cb.over = true
	cb.result = "loss"
	cb.player.hp = 0
	run.player.hp = 0
	cb.queue.append({"t": EventTypes.DEFEAT})


func _win_combat(run: RunState, cb: CombatState) -> void:
	cb.over = true
	cb.result = "win"
	run.player.hp = clampi(cb.player.hp, 1, run.player.max_hp)
	if run.has_relic("emberHeart"):
		heal_player(run, null, 6)
		cb.queue.append({"t": EventTypes.RELIC_PROC, "id": "emberHeart"})
	run.player.hp = clampi(run.player.hp, 1, run.player.max_hp)
	# An untouched fight is worth saying so.
	cb.queue.append({"t": EventTypes.VICTORY, "perfect": cb.hp_lost == 0})


## Heals cb.player when cb is given (with a heal event), else run.player silently.
func heal_player(run: RunState, cb: CombatState, n: int) -> int:
	# sunBlossom: no slice source
	if cb != null:
		var before: int = cb.player.hp
		cb.player.hp = clampi(cb.player.hp + n, 0, cb.player.max_hp)
		var healed: int = cb.player.hp - before
		if healed > 0:
			cb.queue.append({"t": EventTypes.HEAL, "who": "player", "n": healed})
		return healed
	var run_before: int = run.player.hp
	run.player.hp = clampi(run.player.hp + n, 0, run.player.max_hp)
	return run.player.hp - run_before


# ---------------------------------------------------------------- hitting & blocking

## Damage an enemy from the player. Returns actual hp loss.
func hit_enemy(run: RunState, cb: CombatState, e: EnemyCombatant, base: int, is_attack: bool = true) -> int:
	if e.hp <= 0 or cb.over:
		return 0
	var p: PlayerCombatant = cb.player
	var dmg: int = base
	if is_attack:
		dmg += _sget(p.statuses, "str")
		if _sget(p.statuses, "weak") > 0:
			dmg = int(floorf(float(dmg) * 0.75))
		if _sget(e.statuses, "vulnerable") > 0:
			dmg = int(floorf(float(dmg) * 1.5))
	dmg = maxi(0, dmg)  # executionersSeal mult: no slice source (x1)
	var blocked: int = mini(e.block, dmg)
	e.block -= blocked
	var loss: int = dmg - blocked
	e.hp -= loss
	cb.queue.append({
		"t": EventTypes.HIT_ENEMY,
		"idx": e.idx,
		"amount": loss,
		"blocked": blocked,
		"hpAfter": maxi(0, e.hp),
		"dead": e.hp <= 0,
		"killingBlow": e.hp <= 0 and loss > 0,
		"overkill": maxi(0, -e.hp),
	})
	# An attack card that draws unblocked blood earns its facet chip (once per card).
	if cb.pending_chips_active and is_attack and loss > 0:
		var rec: Dictionary = cb.pending_chips.get(e.idx, {"hit": false, "extra": 0})
		rec["hit"] = true
		cb.pending_chips[e.idx] = rec
	# enemy thorns: no slice source
	if e.hp <= 0:
		_on_enemy_death(run, cb, e)
	return loss


func _on_enemy_death(run: RunState, cb: CombatState, e: EnemyCombatant) -> void:
	e.hp = 0
	var smolder: int = _sget(e.statuses, "poison")  # capture before the vessel empties
	e.statuses = {}
	e.staggered = false
	cb.queue.append({"t": EventTypes.DIE, "idx": e.idx})
	# quest drops: no slice source
	for o: EnemyCombatant in cb.enemies:
		if o.hp > 0:
			gain_embers(run, cb, 1)  # the fire inside spills to your lantern
			_jump_smolder(run, cb, e, smolder)
			# reapersBell: no slice source
			return
	_win_combat(run, cb)


func gain_block_player(cb: CombatState, base: int, with_dex: bool = true) -> int:
	var b: int = base
	if with_dex:
		b += _sget(cb.player.statuses, "dex")
		if _sget(cb.player.statuses, "frail") > 0:
			b = int(floorf(float(b) * 0.75))
	b = maxi(0, b)  # omen wardMult: not ported (x1)
	cb.player.block += b
	cb.queue.append({"t": EventTypes.BLOCK_GAIN, "who": "player", "n": b, "total": cb.player.block})
	return b


func gain_block_enemy(cb: CombatState, e: EnemyCombatant, base: int) -> int:
	var b: int = maxi(0, base)
	e.block += b
	cb.queue.append({"t": EventTypes.BLOCK_GAIN, "who": e.idx, "n": b, "total": e.block})
	return b


# ---------------------------------------------------------------- shatter

## Facet chips land after the card that earned them resolves (see play_card);
## overflow carries into the next, harder pane.
func apply_chips(run: RunState, cb: CombatState, e: EnemyCombatant, n: int) -> void:
	if cb.over or e.hp <= 0 or n <= 0:
		return
	e.chips += n
	cb.queue.append({
		"t": EventTypes.CHIP,
		"idx": e.idx,
		"n": n,
		"chips": mini(e.chips, e.facet_max),
		"facetMax": e.facet_max,
	})
	while e.chips >= e.facet_max and e.hp > 0:
		e.chips -= e.facet_max
		_shatter_enemy(run, cb, e)


func _shatter_enemy(run: RunState, cb: CombatState, e: EnemyCombatant) -> void:
	e.facet_max += 1  # annealed: each pane reseams harder than the last
	# adamant affix flag: no slice source
	e.staggered = true
	cb.queue.append({"t": EventTypes.SHATTER, "idx": e.idx, "facetMax": e.facet_max})
	add_status_enemy(cb, e, "vulnerable", 2)
	gain_embers(run, cb, 2)
	# prismCharm / bellOfEndings: no slice source
	var sm: int = _sget(e.statuses, "poison")
	if sm > 0:
		for o: EnemyCombatant in cb.enemies:
			if o != e and o.hp > 0:
				e.statuses.erase("poison")
				_jump_smolder(run, cb, e, sm)
				return


## Smolder is faithful to the fire, not the vessel: when its host shatters or
## dies, it leaps to another living enemy (or is lost with the last one).
func _jump_smolder(run: RunState, cb: CombatState, from: EnemyCombatant, amount: int) -> void:
	if amount <= 0:
		return
	var others: Array[EnemyCombatant] = []
	for o: EnemyCombatant in cb.enemies:
		if o != from and o.hp > 0:
			others.append(o)
	if others.is_empty():
		return
	var to: EnemyCombatant = others[run.rng.pick_index(others.size())]
	add_status_enemy(cb, to, "poison", amount)
	cb.queue.append({"t": EventTypes.SMOLDER_JUMP, "from": from.idx, "to": to.idx, "n": amount})


# ---------------------------------------------------------------- playing cards

## Effective energy cost (duskmirror / omen discounts: no slice source).
func eff_cost(inst: CardInst) -> int:
	var d: Dictionary = card_data(inst)
	var cost_v: Variant = d.get("cost")
	if cost_v == null:
		return 0  # unreachable for playable cards; unplayable is checked first
	return _ji(cost_v)


func can_play(cb: CombatState, inst: CardInst, target_idx: Variant) -> bool:
	if cb.over:
		return false
	var d: Dictionary = card_data(inst)
	var unplayable: bool = d.get("unplayable", false)
	if unplayable:
		return false
	if eff_cost(inst) > cb.player.energy:
		return false
	if str(d.get("target", "")) == "enemy":
		if target_idx == null:
			return false
		var ti: int = target_idx
		if ti < 0 or ti >= cb.enemies.size() or cb.enemies[ti].hp <= 0:
			return false
	return true


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
	if not can_play(cb, inst, target_idx):
		return false
	var p: PlayerCombatant = cb.player
	p.energy -= eff_cost(inst)
	cb.first_card_played = true
	cb.hand.remove_at(i)
	cb.counters_played += 1
	cb.queue.append({"t": EventTypes.PLAY, "uid": inst.uid, "id": String(inst.id), "targetIdx": target_idx})
	cb.queue.append({"t": EventTypes.ENERGY, "n": p.energy})

	var card_type: String = str(d.get("type", ""))
	if card_type == "attack":
		cb.counters_attacks += 1
		# ironTalisman / executionersSeal: no slice source
	var target: EnemyCombatant = null
	if target_idx != null:
		var ti: int = target_idx
		target = cb.enemies[ti]

	cb.pending_chips_active = true  # facet chips land after the whole card resolves
	cb.pending_chips = {}
	var effects: Array = d.get("effects", [])
	for fx_v: Variant in effects:
		if cb.over:
			break
		var fx: Dictionary = fx_v
		_apply_effect(run, cb, inst, d, fx, target)
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
	# venomous power / silkFan: no slice source

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


func exhaust_card(run: RunState, cb: CombatState, inst: CardInst) -> void:
	cb.exhaust.append(inst)
	cb.queue.append({"t": EventTypes.EXHAUST, "uid": inst.uid})
	gain_embers(run, cb, 1)  # everything burned feeds the lantern
	# verdantBranch: no slice source


func _apply_effect(
	run: RunState,
	cb: CombatState,
	inst: CardInst,
	d: Dictionary,
	fx: Dictionary,
	target: EnemyCombatant
) -> void:
	var p: PlayerCombatant = cb.player
	var kind: String = str(fx.get("kind", ""))
	var all_enemies: bool = str(d.get("target", "")) == "allEnemies"
	match kind:
		"dmg":
			var times: int = _ji(fx.get("times", 1))
			var n: int = _ji(fx["n"])
			for _t: int in range(times):
				if all_enemies:
					for e: EnemyCombatant in cb.enemies:
						if cb.over:
							return
						if e.hp > 0:
							hit_enemy(run, cb, e, n)
				elif target != null:
					if cb.over:
						return
					hit_enemy(run, cb, target, n)
		"block":
			gain_block_player(cb, _ji(fx["n"]))
		"draw":
			draw_cards(run, cb, _ji(fx["n"]))
		"energy":
			p.energy += _ji(fx["n"])
			cb.queue.append({"t": EventTypes.ENERGY, "n": p.energy})
		"heal":
			heal_player(run, cb, _ji(fx["n"]))
		"loseHp":
			damage_player(run, cb, _ji(fx["n"]), "self")
		"status":
			var sid: String = str(fx["id"])
			var sn: int = _ji(fx["n"])
			var who: String = str(fx.get("who", ""))
			if who == "self":
				add_status_player(cb, sid, sn)
			elif who == "allEnemies":
				for e: EnemyCombatant in cb.enemies:
					if e.hp > 0:
						add_status_enemy(cb, e, sid, sn)
			elif target != null and target.hp > 0:
				add_status_enemy(cb, target, sid, sn)
		"chip":  # strikes at the glass itself, no blood needed
			var cn: int = _ji(fx["n"])
			var each: Array[EnemyCombatant] = []
			if all_enemies:
				each = cb.living_enemies()
			elif target != null:
				each = [target]
			for e: EnemyCombatant in each:
				if e.hp <= 0:
					continue
				if cb.pending_chips_active:
					var rec: Dictionary = cb.pending_chips.get(e.idx, {"hit": false, "extra": 0})
					var extra: int = rec["extra"]
					rec["extra"] = extra + cn
					cb.pending_chips[e.idx] = rec
				else:
					apply_chips(run, cb, e, cn)  # arts/phials chip immediately
		"ember":
			gain_embers(run, cb, _ji(fx["n"]))
		"special":
			_apply_special(run, cb, inst, fx, target)
		_:
			push_error("CombatRules: unknown effect kind %s" % kind)


## Slice specials: execute / momentum / doubleBlock. The remaining seven land
## with the full content wave.
func _apply_special(
	run: RunState, cb: CombatState, inst: CardInst, fx: Dictionary, target: EnemyCombatant
) -> void:
	var sid: String = str(fx.get("id", ""))
	match sid:
		"execute":
			var bonus: int = 0
			if _sget(target.statuses, "vulnerable") > 0:
				bonus = _ji(fx.get("bonus", 0))
			hit_enemy(run, cb, target, _ji(fx["n"]) + bonus)
		"momentum":
			hit_enemy(run, cb, target, _ji(fx["n"]) + inst.bonus)
			inst.bonus += _ji(fx.get("grow", 0))
		"doubleBlock":
			gain_block_player(cb, cb.player.block, false)
		_:
			push_error("CombatRules: unknown special %s" % sid)


# ---------------------------------------------------------------- kindle & the Lantern Art

## The universal rite: once per turn, feed any hand card to the lantern.
## (crownOfTithes kindle limit 2: no slice source — the limit is 1.)
func can_kindle(cb: CombatState, inst: CardInst) -> bool:
	if inst == null or cb.over:
		return false
	if str(card_data(inst).get("type", "")) == "curse":
		return false  # hexes cling to the hand
	return not (cb.kindled_turn == cb.turn and cb.kindles_this_turn >= 1)


func kindle_from_hand(run: RunState, cb: CombatState, uid: int) -> bool:
	var i: int = -1
	for k: int in range(cb.hand.size()):
		if cb.hand[k].uid == uid:
			i = k
			break
	if i < 0:
		return false
	var inst: CardInst = cb.hand[i]
	if not can_kindle(cb, inst):
		return false
	if cb.kindled_turn != cb.turn:
		cb.kindled_turn = cb.turn
		cb.kindles_this_turn = 0
	cb.kindles_this_turn += 1
	cb.hand.remove_at(i)
	cb.queue.append({"t": EventTypes.KINDLE, "uid": inst.uid, "id": String(inst.id)})
	exhaust_card(run, cb, inst)
	return true


## The hero's one always-available answer, paid in embers.
func can_use_art(run: RunState, cb: CombatState) -> bool:
	if not content.arts.has(String(run.art)):
		return false
	var art: Dictionary = content.arts[String(run.art)]
	return not cb.over and cb.art_used_turn != cb.turn and cb.embers >= _ji(art.get("cost", 0))


func use_art(run: RunState, cb: CombatState) -> bool:
	if not can_use_art(run, cb):
		return false
	var art: Dictionary = content.arts[String(run.art)]
	cb.art_used_turn = cb.turn
	gain_embers(run, cb, -_ji(art.get("cost", 0)))
	cb.queue.append({"t": EventTypes.ART, "id": String(run.art)})
	var effects: Array = art.get("effects", [])
	for fx_v: Variant in effects:
		if cb.over:
			break
		var fx: Dictionary = fx_v
		_apply_art_effect(run, cb, fx)
	return true


## Lantern fire is not a blade: it ignores Fervor/Dimmed/Cracked and strikes everyone.
func _apply_art_effect(run: RunState, cb: CombatState, fx: Dictionary) -> void:
	var p: PlayerCombatant = cb.player
	var kind: String = str(fx.get("kind", ""))
	match kind:
		"dmg":
			for e: EnemyCombatant in cb.living_enemies():
				if not cb.over:
					hit_enemy(run, cb, e, _ji(fx["n"]), false)
		"status":
			var sid: String = str(fx["id"])
			var sn: int = _ji(fx["n"])
			if str(fx.get("who", "")) == "self":
				add_status_player(cb, sid, sn)
			else:
				for e: EnemyCombatant in cb.living_enemies():
					add_status_enemy(cb, e, sid, sn)
		"block":
			gain_block_player(cb, _ji(fx["n"]), false)
		"heal":
			heal_player(run, cb, _ji(fx["n"]))
		"energy":
			p.energy += _ji(fx["n"])
			cb.queue.append({"t": EventTypes.ENERGY, "n": p.energy})
		"draw":
			draw_cards(run, cb, _ji(fx["n"]))
		"chip":
			for e: EnemyCombatant in cb.living_enemies():
				apply_chips(run, cb, e, _ji(fx["n"]))
		"ember":
			gain_embers(run, cb, _ji(fx["n"]))
		_:
			push_error("CombatRules: unknown art effect kind %s" % kind)


# ---------------------------------------------------------------- potions

## Slice potions: healing / strength / block / fire (swift / venom / energy
## land with the full content wave). M3 scope is in-combat use only.
func use_potion(run: RunState, cb: CombatState, slot: int, target_idx: Variant = null) -> bool:
	var id: String = run.player.potions[slot]
	if id == "":
		return false
	var pdef: Dictionary = content.potion(StringName(id))
	var combat_only: bool = pdef.get("combatOnly", false)
	if combat_only and (cb == null or cb.over):
		return false
	var needs_target: bool = pdef.get("needsTarget", false)
	if needs_target:
		if target_idx == null:
			return false
		var ti: int = target_idx
		if ti < 0 or ti >= cb.enemies.size() or cb.enemies[ti].hp <= 0:
			return false
	run.player.potions[slot] = ""
	if cb != null:
		cb.queue.append({"t": EventTypes.POTION, "id": id})
	match id:
		"healing":
			heal_player(run, cb, 20)
		"strength":
			add_status_player(cb, "str", 2)
		"block":
			gain_block_player(cb, 12, false)
		"fire":
			var fire_ti: int = target_idx
			hit_enemy(run, cb, cb.enemies[fire_ti], 20, false)
		_:
			push_error("CombatRules: unknown potion %s" % id)
	return true


# ---------------------------------------------------------------- previews
# Pure arithmetic mirrors of the laws above — no state touched. If a combat
# calculation changes, its mirror here must change in lockstep.

func preview_block(cb: CombatState, base: int) -> int:
	var b: int = base + _sget(cb.player.statuses, "dex")
	if _sget(cb.player.statuses, "frail") > 0:
		b = int(floorf(float(b) * 0.75))
	return maxi(0, b)  # omen wardMult: not ported (x1)


## null when the intent deals no damage, else {"dmg": int, "times": int}.
func preview_enemy_dmg(cb: CombatState, e: EnemyCombatant) -> Variant:
	var mv: Dictionary = e.move()
	var dmg_v: Variant = mv.get("dmg")
	if dmg_v == null:
		return null
	var dmg: int = _ji(dmg_v) + _sget(e.statuses, "str")  # ramp/omen/vow bonuses: no slice source
	if _sget(e.statuses, "weak") > 0:
		dmg = int(floorf(float(dmg) * 0.75))
	if _sget(cb.player.statuses, "vulnerable") > 0:
		dmg = int(floorf(float(dmg) * 1.5))
	return {"dmg": maxi(0, dmg), "times": _ji(mv.get("times", 1))}


## What would this card actually do to this target? null when it previews nothing.
func preview_play(cb: CombatState, inst: CardInst, target_idx: Variant = null) -> Variant:
	var d: Dictionary = card_data(inst)
	var p: PlayerCombatant = cb.player
	var target: EnemyCombatant = null
	if target_idx != null:
		var ti: int = target_idx
		target = cb.enemies[ti]
	var hits: Array[Dictionary] = []
	var block: int = 0
	var effects: Array = d.get("effects", [])
	for fx_v: Variant in effects:
		var fx: Dictionary = fx_v
		var kind: String = str(fx.get("kind", ""))
		if kind == "dmg":
			hits.append({"dmg": _preview_hit(p, target, _ji(fx["n"])), "times": _ji(fx.get("times", 1))})
		elif kind == "block":
			block += preview_block(cb, _ji(fx["n"]))
		elif kind == "special":
			var sid: String = str(fx.get("id", ""))
			if sid == "execute":
				var bonus: int = 0
				if target != null and _sget(target.statuses, "vulnerable") > 0:
					bonus = _ji(fx.get("bonus", 0))
				hits.append({"dmg": _preview_hit(p, target, _ji(fx["n"]) + bonus), "times": 1})
			elif sid == "momentum":
				hits.append({"dmg": _preview_hit(p, target, _ji(fx["n"]) + inst.bonus), "times": 1})
			elif sid == "doubleBlock":
				block += p.block
	var fx_chips: int = 0
	for fx_v: Variant in effects:
		var fx: Dictionary = fx_v
		if str(fx.get("kind", "")) == "chip":
			fx_chips += _ji(fx["n"])
	if hits.is_empty() and block == 0 and fx_chips == 0:
		return null
	var total: int = 0
	for h: Dictionary in hits:
		var hd: int = h["dmg"]
		var ht: int = h["times"]
		total += hd * ht
	var loss: int = total
	var lethal: bool = false
	var chips: int = 0
	var will_shatter: bool = false
	if target != null:
		var b: int = target.block
		loss = 0
		for h: Dictionary in hits:
			var hd: int = h["dmg"]
			var ht: int = h["times"]
			for _i: int in range(ht):
				var soak: int = mini(b, hd)
				b -= soak
				loss += hd - soak
		lethal = loss >= target.hp
		# Facet arithmetic mirrors play_card: an attack that draws unblocked
		# blood chips once (plus card/beacon bonuses); explicit chips always land.
		var per: int = 0
		if str(d.get("type", "")) == "attack":
			per = 1 + _ji(d.get("chip", 0)) + _sget(p.statuses, "beacon")
		chips = (per if (hits.size() > 0 and loss > 0) else 0) + fx_chips
		will_shatter = chips > 0 and target.chips + chips >= target.facet_max and not lethal
	return {
		"hits": hits,
		"total": total,
		"loss": loss,
		"lethal": lethal,
		"block": block,
		"chips": chips,
		"willShatter": will_shatter,
	}


func _preview_hit(p: PlayerCombatant, target: EnemyCombatant, base: int) -> int:
	var dmg: int = base + _sget(p.statuses, "str")
	if _sget(p.statuses, "weak") > 0:
		dmg = int(floorf(float(dmg) * 0.75))
	if target != null and _sget(target.statuses, "vulnerable") > 0:
		dmg = int(floorf(float(dmg) * 1.5))
	return maxi(0, dmg)
