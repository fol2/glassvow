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
