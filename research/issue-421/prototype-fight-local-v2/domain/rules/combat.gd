class_name CombatRules
extends RefCounted
## Combat core — port of the frozen web engine
## (roguecardv2-benchmark@6e06911). Every calculation and event mirrors the source; the
## fixture suites (tests/test_combat_probes.gd, tests/test_combat_traces.gd)
## are the proof.
##
## Damage law is sequential floors:
## base+str -> weak floor(x0.75) -> vulnerable floor(x1.5) -> max(0, .);
## block gains round.


var content: ContentDB
var quests: QuestRules

const SPECIAL_IDS: Array[String] = [
	"leech", "execute", "momentum", "doubleBlock", "phantom", "devour",
	"pyreTithe", "catalyst", "shatterEcho", "flawless", "emberNova", "emberdance",
]
const POTION_IDS: Array[String] = [
	"healing", "strength", "swift", "block", "fire", "venom", "energy",
]

static var _research421_scoreline_damage: int = 0
static var _research421_afterimage_ward_cap: int = 0


func _init(content_db: ContentDB) -> void:
	content = content_db
	quests = QuestRules.new(content_db)


static func set_research421_fight_local(scoreline_damage: int, afterimage_ward_cap: int) -> void:
	_research421_scoreline_damage = scoreline_damage
	_research421_afterimage_ward_cap = afterimage_ward_cap


static func handles_special(id: String) -> bool:
	return SPECIAL_IDS.has(id)


static func handles_potion(id: String) -> bool:
	return POTION_IDS.has(id)


## JSON numbers arrive as float; whole values are exact.
static func _ji(v: Variant) -> int:
	return int(float(str(v)))


## Status stack read (statuses never hold non-int values).
static func _sget(statuses: Dictionary, id: String) -> int:
	var n: int = statuses.get(id, 0)
	return n


func _omen_mods(run: RunState) -> Dictionary:
	if run.act < 0 or run.act >= run.omens.size() or run.omens[run.act] == null:
		return {}
	var omen: Dictionary = content.omens.get(str(run.omens[run.act]), {})
	return omen.get("mods", {})


func _vow_mods(run: RunState) -> Dictionary:
	var out: Dictionary = {
		"hpMult": 1.0, "enemyDmgBonus": 0, "bossFacetDelta": 0,
		"startHex": false,
	}
	for i: int in range(clampi(run.vow, 0, content.vows.size())):
		var vow: Dictionary = content.vows[i]
		var mods: Dictionary = vow.get("mods", {})
		out["hpMult"] = float(str(out["hpMult"])) * float(str(mods.get("hpMult", 1)))
		out["enemyDmgBonus"] = _ji(out["enemyDmgBonus"]) + _ji(mods.get("enemyDmgBonus", 0))
		out["bossFacetDelta"] = _ji(out["bossFacetDelta"]) + _ji(mods.get("bossFacetDelta", 0))
		if mods.get("startHex", false):
			out["startHex"] = true
		if mods.has("restHealFrac"):
			out["restHealFrac"] = minf(
				float(str(out.get("restHealFrac", 1))), float(str(mods["restHealFrac"]))
			)
	return out


func _resolved_enemy(run: RunState, requested_id: String) -> Dictionary:
	var variant_v: Variant = content.variants.get(requested_id)
	if typeof(variant_v) != TYPE_DICTIONARY:
		return _with_counterfactual(run, requested_id, content.enemy(requested_id))
	var variant: Dictionary = variant_v
	var base_id: String = str(variant.get("base"))
	var base: Dictionary
	var shade_kit: String = ""
	if base_id == "hero":
		var aspect_index: int = run.aspect
		if typeof(run.monument) == TYPE_DICTIONARY:
			var monument: Dictionary = run.monument
			aspect_index = _ji(monument.get("shadeAspect", aspect_index))
		aspect_index = clampi(aspect_index, 0, content.aspects.size() - 1)
		var aspect: Dictionary = content.aspects[aspect_index]
		shade_kit = str(aspect.get("id", "duskblade"))
		var kit: Dictionary = content.shade_kits.get(shade_kit, {})
		var aspect_bare: String = str(aspect.get("nameBare", aspect.get("name", shade_kit)))
		var name_pattern: String = str(kit.get("namePattern", "{aspect}"))
		base = {
			"name": name_pattern.replace("{aspect}", aspect_bare),
			"hp": [110, 110], "facets": 6, "boss": true,
			"art": content.enemies["shade"].get("art", {}),
			"moves": kit.get("moves", {}),
		}
		base_id = "shade"
	else:
		base = content.enemy(base_id)
	var resolved: Dictionary = base.duplicate(true)
	var mods: Dictionary = variant.get("statMods", {})
	var hp_mult: float = float(str(mods.get("hpMult", 1)))
	var hp: Array = base.get("hp", [1, 1])
	resolved["hp"] = [
		maxi(1, int(roundf(float(_ji(hp[0])) * hp_mult))),
		maxi(1, int(roundf(float(_ji(hp[1])) * hp_mult))),
	]
	var damage_mult: float = float(str(mods.get("dmgMult", 1)))
	var scaled_moves: Dictionary = {}
	var moves: Dictionary = base.get("moves", {})
	for move_id: String in moves:
		var move: Dictionary = moves[move_id].duplicate(true)
		if move.has("dmg"):
			move["dmg"] = maxi(0, int(roundf(float(_ji(move["dmg"])) * damage_mult)))
		scaled_moves[move_id] = move
	resolved["moves"] = scaled_moves
	var start_status: Dictionary = base.get("startStatus", {}).duplicate()
	var added_statuses: Dictionary = mods.get("addStatuses", {})
	start_status.merge(added_statuses, true)
	resolved["startStatus"] = start_status
	resolved["name"] = str(variant.get("name", base.get("name", requested_id)))
	resolved["drop"] = variant.get("drop")
	resolved["dialogue"] = variant.get("dialogue", [])
	resolved["deathDialogue"] = variant.get("deathDialogue")
	return {"key": base_id, "variant": requested_id, "def": resolved, "shadeKit": shade_kit}


func _with_counterfactual(run: RunState, requested_id: String, def: Dictionary) -> Dictionary:
	var picked: Dictionary = CounterfactualSelf.resolve(run, def, content)
	if picked.get("ok", false) != true:
		push_error("CounterfactualSelf: %s" % str(picked.get("error", "unresolved")))
		return {"key": requested_id, "variant": "", "def": def, "fault": true}
	var out: Dictionary = {"key": requested_id, "variant": "", "def": def}
	var kit_id: String = str(picked.get("id", ""))
	if not kit_id.is_empty():
		out[CounterfactualSelf.KIT_FLAG] = kit_id
	return out


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
	var omen: Dictionary = _omen_mods(run)
	var vow: Dictionary = _vow_mods(run)
	var cb: CombatState = CombatState.new()
	cb.kind = kind
	# Every elite arrives wearing a title (web: opts.affix || pick(rng, keys)).
	var affixed: bool = kind == &"elite" or (omen.get("allCombatsAffixed", false) and kind != &"boss")
	if affixed:
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
	var omen_hp_mult: float = float(str(omen.get("hpMult", 1)))
	var vow_hp_mult: float = float(str(vow.get("hpMult", 1)))

	cb.player.hp = run.player.hp
	cb.player.max_hp = run.player.max_hp
	cb.player.energy_max = run.player.energy_max

	var i: int = 0
	for id_v: Variant in enemy_ids:
		var requested_id: String = str(id_v)
		var resolved: Dictionary = _resolved_enemy(run, requested_id)
		if resolved.get("fault", false) == true:
			continue
		var eid: StringName = StringName(str(resolved["key"]))
		var d: Dictionary = resolved["def"]
		var e: EnemyCombatant = EnemyCombatant.new()
		e.key = eid
		e.variant_id = StringName(str(resolved["variant"]))
		e.def = d
		e.idx = i
		e.name = str(d.get("name", ""))
		var hp_pair: Array = d["hp"]
		e.max_hp = int(roundf(float(rng.irange(_ji(hp_pair[0]), _ji(hp_pair[1]))) \
			* omen_hp_mult * af_hp_mult * vow_hp_mult))
		e.hp = e.max_hp
		e.block = _ji(af.get("startBlock", 0))
		var start_status: Dictionary = d.get("startStatus", {})
		for k: Variant in start_status.keys():
			e.statuses[str(k)] = _ji(start_status[k])
		var imposed: Dictionary = omen.get("enemyStartStatus", {}).duplicate()
		var affix_start_status: Dictionary = af.get("startStatus", {})
		imposed.merge(affix_start_status, true)
		for k: String in imposed:
			e.statuses[k] = _sget(e.statuses, k) + _ji(imposed[k])
		if af.get("adamant", false):
			e.flags["adamant"] = true
		if not str(resolved.get("shadeKit", "")).is_empty():
			e.flags["shadeKit"] = resolved["shadeKit"]
		if not str(resolved.get(CounterfactualSelf.KIT_FLAG, "")).is_empty():
			e.flags[CounterfactualSelf.KIT_FLAG] = resolved[CounterfactualSelf.KIT_FLAG]
		var elite_flag: bool = d.get("elite", false)
		var boss_flag: bool = d.get("boss", false)
		e.elite = elite_flag
		e.boss = boss_flag
		var facets_default: int = 6 if e.boss else (5 if e.elite else 4)
		var facets: int = _ji(d.get("facets", facets_default))
		# Every creature is glass: fill its facet gauge and it shatters.
		e.facet_max = maxi(2, facets + _ji(omen.get("facetDelta", 0)) + af_facet_delta \
			+ (_ji(vow.get("bossFacetDelta", 0)) if e.boss else 0))
		cb.enemies.append(e)
		_gate_death_dialogue(run, e)
		i += 1

	# The boss announces itself, then every variant speaks its lines —
	# engine.js:1133-1139, queued before the deck deals. No slice fight is a
	# boss and no slice enemy carries dialogue, so the traces replay unmoved.
	if kind == &"boss" and not cb.enemies.is_empty():
		cb.queue.append({"t": EventTypes.BOSS_INTRO, "name": cb.enemies[0].name})
	var aspect_name: String = ""
	if run.aspect >= 0 and run.aspect < content.aspects.size():
		var aspect_v: Variant = content.aspects[run.aspect]
		if typeof(aspect_v) == TYPE_DICTIONARY:
			var aspect_d: Dictionary = aspect_v
			aspect_name = str(aspect_d.get("nameBare", aspect_d.get("name", "")))
	for speaker: EnemyCombatant in cb.enemies:
		var lines_v: Variant = speaker.def.get("dialogue")
		if typeof(lines_v) != TYPE_ARRAY:
			continue
		var lines: Array = lines_v
		for line_v: Variant in lines:
			cb.queue.append({"t": EventTypes.VARIANT_DIALOGUE, "idx": speaker.idx,
				"text": str(line_v).replace("{aspect}", aspect_name)})

	# Deck: fresh combat copies of the run deck, then one shuffle.
	for c: CardInst in run.player.deck:
		cb.draw.append(c.combat_copy())
	_shuffle_cards(rng, cb.draw)
	cb.embers = clampi(_ji(omen.get("startEmbers", 0)), 0, cb.ember_cap)
	_apply_start_relics(run, cb)
	_compute_intents(run, cb)
	_start_player_turn(run, cb)
	return cb


func _gate_death_dialogue(run: RunState, enemy: EnemyCombatant) -> void:
	var slot: String = "death.%s" % String(enemy.variant_id)
	if not LineTable.has_slot(content.line_table, slot):
		return
	var ctx: Dictionary = LineTable.context(
		run, LineTable.projected_shard_count(run, enemy.variant_id))
	if not LineTable.slot_open(content.line_table, slot, ctx):
		enemy.def.erase("deathDialogue")


func _apply_start_relics(run: RunState, cb: CombatState) -> void:
	if run.has_relic("basaltIdol"):
		cb.player.block += 10
		_proc(cb, "basaltIdol")
	if run.has_relic("warFetish"):
		add_status_player(cb, "str", 1)
		_proc(cb, "warFetish")
	if run.has_relic("riverPearl"):
		add_status_player(cb, "dex", 1)
		_proc(cb, "riverPearl")
	if run.has_relic("thornBand"):
		add_status_player(cb, "thorns", 2)
		_proc(cb, "thornBand")
	if run.has_relic("vialOfLife"):
		heal_player(run, cb, 2)
		_proc(cb, "vialOfLife")
	if run.has_relic("crownOfCinders"):
		cb.ember_cap = 12
		cb.embers = clampi(cb.embers + 2, 0, cb.ember_cap)
		_proc(cb, "crownOfCinders")
	if run.has_relic("shatterersCrown"):
		for e: EnemyCombatant in cb.enemies:
			e.facet_max = maxi(2, e.facet_max - 1)
			e.statuses["str"] = _sget(e.statuses, "str") + 1
		_proc(cb, "shatterersCrown")
	if run.has_relic("smolderingCoal") and not _player_smolder_blocked(run):
		var coal_smolder: int = _ji(content.relic(&"smolderingCoal").get("startSmolder", 2))
		for e: EnemyCombatant in cb.enemies:
			e.statuses["poison"] = _sget(e.statuses, "poison") + coal_smolder
		_proc(cb, "smolderingCoal")
	if run.has_relic("ashenCore") and not _player_smolder_blocked(run):
		var core_smolder: int = _ji(content.relic(&"ashenCore").get("startSmolder", 3))
		for e: EnemyCombatant in cb.enemies:
			e.statuses["poison"] = _sget(e.statuses, "poison") + core_smolder
		_proc(cb, "ashenCore")


static func _proc(cb: CombatState, relic_id: String) -> void:
	cb.queue.append({"t": EventTypes.RELIC_PROC, "id": relic_id})


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
			e.key, cb.turn + 1, last, prev, float(e.hp) / float(e.max_hp), run.rng, e.flags
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
	var energy: int = p.energy_max + _sget(p.statuses, "energized")
	if cb.turn == 1 and run.has_relic("emberLantern"):
		energy += 1
		_proc(cb, "emberLantern")
	p.energy = (p.energy if run.has_relic("frozenCore") else 0) + energy
	cb.first_card_played = false
	cb.queue.append({"t": EventTypes.ENERGY, "n": p.energy})
	var draws: int = 5 + _sget(p.statuses, "nightsight") \
		+ _ji(_omen_mods(run).get("drawDelta", 0))
	if cb.turn == 1 and run.has_relic("travelersPack"):
		draws += 2
		_proc(cb, "travelersPack")
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


## Enemy poison from the player is Ash-only (aspect != 0). Slice goldens still
## pin Dusk Flare smolder; the live catalogue id is `core`.
func add_status_enemy(
	cb: CombatState, e: EnemyCombatant, id: String, n: int, run: RunState = null
) -> void:
	if id == "poison" and _player_smolder_blocked(run):
		return
	_add_status(cb, e.statuses, e.idx, id, n)


func _player_smolder_blocked(run: RunState) -> bool:
	return run != null and run.aspect == 0 and content.id == "core"


func _add_status(cb: CombatState, statuses: Dictionary, who: Variant, id: String, n: int) -> void:
	var next: int = _sget(statuses, id) + n
	if next == 0:
		statuses.erase(id)
	else:
		statuses[id] = next
	cb.queue.append({"t": EventTypes.STATUS, "who": who, "id": id, "n": n})


## Spilled fire, caught by your lantern. Negative n = spent. Returns the delta.
func gain_embers(run: RunState, cb: CombatState, n: int) -> int:
	n = quests.tithe_embers(run, n)
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
		dmg += _sget(attacker.statuses, "str") + _ji(attacker.flags.get("rampBonus", 0))
		dmg += _ji(_omen_mods(run).get("enemyDmgBonus", 0))
		dmg += _ji(_vow_mods(run).get("enemyDmgBonus", 0))
		if _sget(attacker.statuses, "weak") > 0:
			dmg = int(floorf(float(dmg) * 0.75))
		if _sget(p.statuses, "vulnerable") > 0:
			dmg = int(floorf(float(dmg) * 1.5))
		if run.has_relic("wardingCharm") and dmg > 0 and dmg <= 5:
			dmg = 1
			_proc(cb, "wardingCharm")
	dmg = maxi(0, dmg)
	var blocked: int = 0
	if is_attack or str(source) == "thorns":  # poison/burn/self ignore block
		blocked = mini(p.block, dmg)
		p.block -= blocked
	var loss: int = dmg - blocked
	p.hp -= loss
	run.stats["dmgTaken"] = _ji(run.stats.get("dmgTaken", 0)) + maxi(0, loss)
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
	if is_attack and attacker != null:
		var applies: Dictionary = _omen_mods(run).get("playerHitApplies", {}).duplicate()
		if cb.affix != &"":
			var affix_def: Dictionary = content.affixes.get(String(cb.affix), {})
			var affix_mods: Dictionary = affix_def.get("mods", {})
			var affix_applies: Dictionary = affix_mods.get("attackApplies", {})
			applies.merge(affix_applies, true)
		for id: String in applies:
			add_status_player(cb, id, _ji(applies[id]))
		if _sget(p.statuses, "thorns") > 0 and attacker.hp > 0:
			hit_enemy(run, cb, attacker, _sget(p.statuses, "thorns"), false)
	return loss


func lose_combat(run: RunState, cb: CombatState) -> void:
	_research421_expire_combat(cb)
	cb.over = true
	cb.result = "loss"
	cb.player.hp = 0
	run.player.hp = 0
	cb.queue.append({"t": EventTypes.DEFEAT})


func _win_combat(run: RunState, cb: CombatState) -> void:
	_research421_expire_combat(cb)
	cb.over = true
	cb.result = "win"
	quests.on_combat_win(run, cb)
	run.player.hp = clampi(cb.player.hp, 1, run.player.max_hp)
	if run.has_relic("emberHeart"):
		heal_player(run, null, _ji(content.relic(&"emberHeart").get("heal", 6)))
		_proc(cb, "emberHeart")
	if run.has_relic("crownOfTheHearth") and cb.embers > 0:
		heal_player(run, null, cb.embers * 3)
		_proc(cb, "crownOfTheHearth")
	if run.has_relic("gravebloom") and run.player.hp <= run.player.max_hp * 0.5:
		heal_player(run, null, 10)
		_proc(cb, "gravebloom")
	run.player.hp = clampi(run.player.hp, 1, run.player.max_hp)
	if cb.hp_lost == 0:
		run.stats["perfects"] = _ji(run.stats.get("perfects", 0)) + 1
	# An untouched fight is worth saying so.
	cb.queue.append({"t": EventTypes.VICTORY, "perfect": cb.hp_lost == 0})


## Heals cb.player when cb is given (with a heal event), else run.player silently.
func heal_player(run: RunState, cb: CombatState, n: int) -> int:
	if run.has_relic("sunBlossom"):
		n = int(roundf(float(n) * 1.5))
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
func hit_enemy(
	run: RunState,
	cb: CombatState,
	e: EnemyCombatant,
	base: int,
	is_attack: bool = true,
	damage_mult: int = 1
) -> int:
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
	dmg = maxi(0, dmg * damage_mult)
	var blocked: int = mini(e.block, dmg)
	e.block -= blocked
	var loss: int = dmg - blocked
	var next_hp: int = e.hp - loss
	var handoff: bool = next_hp <= 0 and _is_finale_handoff(e)
	if handoff:
		loss = maxi(0, e.hp - 1)
		e.hp = 1
	else:
		e.hp = next_hp
	run.stats["dmgDealt"] = _ji(run.stats.get("dmgDealt", 0)) + loss
	cb.queue.append({
		"t": EventTypes.HIT_ENEMY,
		"idx": e.idx,
		"amount": loss,
		"blocked": blocked,
		"hpAfter": maxi(0, e.hp),
		"dead": (not handoff) and e.hp <= 0,
		"killingBlow": (not handoff) and e.hp <= 0 and loss > 0,
		"overkill": 0 if handoff else maxi(0, -e.hp),
	})
	# An attack card that draws unblocked blood earns its facet chip (once per card).
	if cb.pending_chips_active and is_attack and loss > 0:
		var rec: Dictionary = cb.pending_chips.get(e.idx, {"hit": false, "extra": 0})
		rec["hit"] = true
		cb.pending_chips[e.idx] = rec
	if is_attack and _sget(e.statuses, "thorns") > 0 and e.hp > 0 and not handoff:
		damage_player(run, cb, _sget(e.statuses, "thorns"), "thorns")
	if handoff:
		_begin_finale_handoff(run, cb, e)
		return loss
	if e.hp <= 0:
		_on_enemy_death(run, cb, e)
	return loss


func _is_finale_handoff(e: EnemyCombatant) -> bool:
	return e.def.get("finaleHandoff", false) == true


func _begin_finale_handoff(run: RunState, cb: CombatState, e: EnemyCombatant) -> void:
	e.hp = 1
	cb.finale_handoff = true
	cb.queue.append({"t": EventTypes.FINALE_HANDOFF, "idx": e.idx, "hpAfter": 1})
	_win_combat(run, cb)


func _on_enemy_death(run: RunState, cb: CombatState, e: EnemyCombatant) -> void:
	_research421_expire_scoreline(cb, e.idx, "target-death")
	e.hp = 0
	var smolder: int = _sget(e.statuses, "poison")  # capture before the vessel empties
	e.statuses = {}
	e.staggered = false
	cb.queue.append({"t": EventTypes.DIE, "idx": e.idx})
	# The death line rides right behind the die event (engine.js:1384-1385).
	var death_line_v: Variant = e.def.get("deathDialogue")
	if typeof(death_line_v) == TYPE_STRING and not str(death_line_v).is_empty():
		cb.queue.append({"t": EventTypes.VARIANT_DIALOGUE, "idx": e.idx,
			"text": str(death_line_v)})
	quests.on_enemy_death(run, e.def)
	run.stats["slain"] = _ji(run.stats.get("slain", 0)) + 1
	if e.elite:
		run.stats["elites"] = _ji(run.stats.get("elites", 0)) + 1
	if e.boss:
		run.stats["bosses"] = _ji(run.stats.get("bosses", 0)) + 1
	for o: EnemyCombatant in cb.enemies:
		if o.hp > 0:
			gain_embers(run, cb, 1)  # the fire inside spills to your lantern
			_jump_smolder(run, cb, e, smolder)
			if run.has_relic("reapersBell"):
				cb.player.energy += 1
				draw_cards(run, cb, 1)
				_proc(cb, "reapersBell")
				cb.queue.append({"t": EventTypes.ENERGY, "n": cb.player.energy})
			return
	_win_combat(run, cb)


func gain_block_player(
	cb: CombatState, base: int, with_dex: bool = true, run: RunState = null
) -> int:
	var b: int = base
	if with_dex:
		b += _sget(cb.player.statuses, "dex")
		if _sget(cb.player.statuses, "frail") > 0:
			b = int(floorf(float(b) * 0.75))
	b = maxi(0, b)
	if run != null:
		b = int(roundf(float(b) * float(str(_omen_mods(run).get("wardMult", 1)))))
	cb.player.block += b
	cb.queue.append({"t": EventTypes.BLOCK_GAIN, "who": "player", "n": b, "total": cb.player.block})
	return b


func gain_block_enemy(
	cb: CombatState, e: EnemyCombatant, base: int, run: RunState = null
) -> int:
	var b: int = maxi(0, base)
	if run != null:
		b = int(roundf(float(b) * float(str(_omen_mods(run).get("wardMult", 1)))))
	e.block += b
	cb.queue.append({"t": EventTypes.BLOCK_GAIN, "who": e.idx, "n": b, "total": e.block})
	return b


# ---------------------------------------------------------------- shatter

## Facet chips land after the card that earned them resolves (see play_card);
## overflow carries into the next, harder pane. Shatter/stagger is Dusk-only
## (aspect 0): Ashwarden connecting attacks still compute implicit chip, but
## this no-op means they never stun.
func apply_chips(run: RunState, cb: CombatState, e: EnemyCombatant, n: int) -> void:
	if run.aspect != 0:
		return
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
	if e.flags.get("adamant", false) and not e.flags.get("adamantSpent", false):
		e.flags["adamantSpent"] = true
		cb.queue.append({"t": &"adamantHold", "idx": e.idx})
		return
	run.stats["shatters"] = _ji(run.stats.get("shatters", 0)) + 1
	e.staggered = true
	cb.queue.append({"t": EventTypes.SHATTER, "idx": e.idx, "facetMax": e.facet_max})
	add_status_enemy(cb, e, "vulnerable", 2)
	gain_embers(run, cb, 2)
	if run.has_relic("prismCharm") and not cb.prism_procd:
		cb.prism_procd = true
		gain_embers(run, cb, 2)
		_proc(cb, "prismCharm")
	var sm: int = _sget(e.statuses, "poison")
	if sm > 0:
		for o: EnemyCombatant in cb.enemies:
			if o != e and o.hp > 0:
				e.statuses.erase("poison")
				_jump_smolder(run, cb, e, sm)
				break
	if run.has_relic("bellOfEndings"):
		_proc(cb, "bellOfEndings")
		for o: EnemyCombatant in cb.enemies:
			if cb.over:
				break
			if o != e and o.hp > 0:
				hit_enemy(run, cb, o, 4, false)


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

func eff_cost(run: RunState, cb: CombatState, inst: CardInst) -> int:
	var d: Dictionary = card_data(inst)
	var cost_v: Variant = d.get("cost")
	if cost_v == null:
		return 0  # unreachable for playable cards; unplayable is checked first
	if run.has_relic("duskmirror") and not cb.first_card_played:
		return 0
	if not cb.first_card_played:
		return maxi(0, _ji(cost_v) - _ji(_omen_mods(run).get("firstCardDiscount", 0)))
	return _ji(cost_v)


func can_play(run: RunState, cb: CombatState, inst: CardInst, target_idx: Variant) -> bool:
	if cb.over:
		return false
	var d: Dictionary = card_data(inst)
	var unplayable: bool = d.get("unplayable", false)
	if unplayable:
		return false
	if eff_cost(run, cb, inst) > cb.player.energy:
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
	_research421_after_card(run, cb, inst, target)

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


func _research421_after_card(
	run: RunState,
	cb: CombatState,
	inst: CardInst,
	target: EnemyCombatant
) -> void:
	if run.aspect != 0:
		return
	var card_id: String = String(inst.id)
	if card_id == "executioner" and _research421_scoreline_damage > 0 \
			and not cb.over and target != null and target.hp > 0 \
			and cb.research421_scoreline_targets.has(target.idx):
		cb.queue.append({
			"t": &"research421Scoreline", "stage": "consumer",
			"idx": target.idx,
		})
		cb.research421_scoreline_targets.erase(target.idx)
		cb.queue.append({
			"t": &"research421Scoreline", "stage": "mediator-consume",
			"idx": target.idx, "value": -1,
		})
		var realised: int = hit_enemy(
			run, cb, target, _research421_scoreline_damage, false
		)
		cb.queue.append({
			"t": &"research421Scoreline", "stage": "payoff",
			"idx": target.idx, "requested": _research421_scoreline_damage,
			"realised": realised,
		})
	elif card_id == "guardedStrike" and _research421_afterimage_ward_cap > 0 \
			and not cb.over and cb.research421_afterimage_ward > 0:
		var mirrored: int = cb.research421_afterimage_ward
		cb.queue.append({
			"t": &"research421Afterimage", "stage": "consumer",
			"storedWard": mirrored,
		})
		cb.research421_afterimage_ward = 0
		cb.queue.append({
			"t": &"research421Afterimage", "stage": "mediator-consume",
			"value": -mirrored,
		})
		var realised: int = gain_block_player(cb, mirrored, false, null)
		cb.queue.append({
			"t": &"research421Afterimage", "stage": "payoff",
			"requested": mirrored, "realised": realised,
		})


func _research421_scoreline_producer(
	run: RunState, cb: CombatState, inst: CardInst, target: EnemyCombatant, loss: int
) -> void:
	if run.aspect != 0 or String(inst.id) != "chisel" \
			or _research421_scoreline_damage <= 0 or loss <= 0 \
			or cb.over or target.hp <= 0:
		return
	var replaced: bool = cb.research421_scoreline_targets.has(target.idx)
	cb.queue.append({
		"t": &"research421Scoreline", "stage": "producer",
		"idx": target.idx, "loss": loss,
	})
	cb.research421_scoreline_targets[target.idx] = true
	cb.queue.append({
		"t": &"research421Scoreline", "stage": "mediator-set",
		"idx": target.idx, "value": 1, "replaced": replaced,
	})


func _research421_afterimage_producer(
	run: RunState, cb: CombatState, inst: CardInst, realised_ward: int
) -> void:
	if run.aspect != 0 or String(inst.id) != "defend" \
			or _research421_afterimage_ward_cap <= 0 or realised_ward <= 0:
		return
	var stored: int = mini(realised_ward, _research421_afterimage_ward_cap)
	var replaced: bool = cb.research421_afterimage_ward > 0
	cb.queue.append({
		"t": &"research421Afterimage", "stage": "producer",
		"realisedWard": realised_ward, "storedWard": stored,
	})
	cb.research421_afterimage_ward = stored
	cb.queue.append({
		"t": &"research421Afterimage", "stage": "mediator-set",
		"value": stored, "replaced": replaced,
	})


func _research421_expire_scoreline(cb: CombatState, idx: int, reason: String) -> void:
	if not cb.research421_scoreline_targets.has(idx):
		return
	cb.research421_scoreline_targets.erase(idx)
	cb.queue.append({
		"t": &"research421Scoreline", "stage": "expiry",
		"idx": idx, "reason": reason,
	})


func _research421_expire_afterimage(cb: CombatState, reason: String) -> void:
	if cb.research421_afterimage_ward <= 0:
		return
	var expired: int = cb.research421_afterimage_ward
	cb.research421_afterimage_ward = 0
	cb.queue.append({
		"t": &"research421Afterimage", "stage": "expiry",
		"value": expired, "reason": reason,
	})


func _research421_expire_combat(cb: CombatState) -> void:
	for idx_v: Variant in cb.research421_scoreline_targets.keys():
		_research421_expire_scoreline(cb, int(float(str(idx_v))), "combat-end")
	_research421_expire_afterimage(cb, "combat-end")


func exhaust_card(run: RunState, cb: CombatState, inst: CardInst) -> void:
	cb.exhaust.append(inst)
	cb.queue.append({"t": EventTypes.EXHAUST, "uid": inst.uid})
	gain_embers(run, cb, 1)  # everything burned feeds the lantern
	if run.has_relic("verdantBranch"):
		draw_cards(run, cb, 1)
		_proc(cb, "verdantBranch")


func _apply_effect(
	run: RunState,
	cb: CombatState,
	inst: CardInst,
	d: Dictionary,
	fx: Dictionary,
	target: EnemyCombatant,
	damage_mult: int = 1
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
							hit_enemy(run, cb, e, n, true, damage_mult)
				elif target != null:
					if cb.over:
						return
					var realised_damage: int = hit_enemy(
						run, cb, target, n, true, damage_mult
					)
					_research421_scoreline_producer(
						run, cb, inst, target, realised_damage
					)
		"block":
			var realised_ward: int = gain_block_player(cb, _ji(fx["n"]), true, run)
			_research421_afterimage_producer(run, cb, inst, realised_ward)
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
						add_status_enemy(cb, e, sid, sn, run)
			elif target != null and target.hp > 0:
				add_status_enemy(cb, target, sid, sn, run)
		"addCard":
			var add_count: int = _ji(fx.get("n", 1))
			for _i: int in range(add_count):
				var added: CardInst = CardInst.new(run.next_uid(), StringName(str(fx["id"])), false)
				var to_hand: bool = str(fx.get("where", "discard")) == "hand" and cb.hand.size() < 10
				if to_hand:
					cb.hand.append(added)
				else:
					cb.discard.append(added)
				cb.queue.append({
					"t": &"addCard", "id": String(added.id),
					"where": "hand" if to_hand else "discard",
				})
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
			_apply_special(run, cb, inst, fx, target, damage_mult)
		_:
			push_error("CombatRules: unknown effect kind %s" % kind)


func _apply_special(
	run: RunState,
	cb: CombatState,
	inst: CardInst,
	fx: Dictionary,
	target: EnemyCombatant,
	damage_mult: int
) -> void:
	var sid: String = str(fx.get("id", ""))
	match sid:
		"leech":
			var leech_loss: int = hit_enemy(run, cb, target, _ji(fx["n"]), true, damage_mult)
			if leech_loss > 0:
				heal_player(run, cb, leech_loss / 2)
		"execute":
			var bonus: int = 0
			if _sget(target.statuses, "vulnerable") > 0:
				bonus = _ji(fx.get("bonus", 0))
			hit_enemy(run, cb, target, _ji(fx["n"]) + bonus, true, damage_mult)
		"momentum":
			hit_enemy(run, cb, target, _ji(fx["n"]) + inst.bonus, true, damage_mult)
			inst.bonus += _ji(fx.get("grow", 0))
		"doubleBlock":
			gain_block_player(cb, cb.player.block, false, run)
		"phantom":
			hit_enemy(run, cb, target, _ji(fx["n"]) * cb.hand.size(), true, damage_mult)
		"devour":
			hit_enemy(run, cb, target, _ji(fx["n"]), true, damage_mult)
			if target.hp <= 0:
				if cb.over:
					heal_player(run, null, _ji(fx["heal"]))
				else:
					gain_embers(run, cb, _ji(fx["embers"]))
					heal_player(run, cb, _ji(fx["heal"]))
		"catalyst":
			var poison: int = _sget(target.statuses, "poison")
			if poison > 0:
				add_status_enemy(cb, target, "poison", poison * (_ji(fx["n"]) - 1), run)
		"shatterEcho":
			var echo: int = 2 if target.staggered or _sget(target.statuses, "vulnerable") > 0 else 1
			hit_enemy(run, cb, target, _ji(fx["n"]) * echo, true, damage_mult)
		"emberNova":
			hit_enemy(run, cb, target, _ji(fx["n"]) * cb.embers, true, damage_mult)
		"pyreTithe":
			for held: CardInst in cb.hand.duplicate():
				cb.hand.erase(held)
				cb.queue.append({"t": EventTypes.KINDLE, "uid": held.uid, "id": String(held.id)})
				exhaust_card(run, cb, held)
			draw_cards(run, cb, _ji(fx["draw"]))
		"flawless":
			gain_block_player(cb, _ji(fx["n"]), true, run)
			if cb.hp_lost == 0:
				gain_block_player(cb, _ji(fx["n"]), true, run)
		"emberdance":
			var spent: int = cb.embers
			if spent > 0:
				run.stats["embersSpent"] = _ji(run.stats.get("embersSpent", 0)) + spent
				gain_embers(run, cb, -spent)
				gain_block_player(cb, _ji(fx["n"]) * spent, false, run)
		_:
			push_error("CombatRules: unknown special %s" % sid)


# ---------------------------------------------------------------- end of turn

func end_turn(run: RunState, cb: CombatState) -> void:
	if cb.over:
		return
	var p: PlayerCombatant = cb.player
	_research421_expire_afterimage(cb, "player-turn-end")
	cb.queue.append({"t": EventTypes.END_TURN})
	# Hand end-of-turn penalties (burn / hex).
	for c: CardInst in cb.hand.duplicate():
		var d: Dictionary = card_data(c)
		if d.get("endTurnDmg") != null:
			damage_player(run, cb, _ji(d["endTurnDmg"]), "burn")
		if d.get("endTurnLoseHp") != null:
			damage_player(run, cb, _ji(d["endTurnLoseHp"]), "burn")
		if cb.over:
			return
	var metallicize: int = _sget(p.statuses, "metallicize")
	if metallicize > 0:
		gain_block_player(cb, metallicize, false, run)
	var regen: int = _sget(p.statuses, "regen")
	if regen > 0:
		heal_player(run, cb, regen)
	# Discard hand.
	var uids: Array = []
	for c: CardInst in cb.hand:
		uids.append(c.uid)
	cb.discard.append_array(cb.hand)
	cb.hand = []
	cb.queue.append({"t": EventTypes.DISCARD_HAND, "uids": uids})
	# Player debuffs (and turn-scoped buffs) tick down at end of your turn.
	for s: String in ["vulnerable", "weak", "frail", "beacon"]:
		_tick_status(p.statuses, s)

	# ---- enemy phase
	for e: EnemyCombatant in cb.enemies:
		if e.hp <= 0 or cb.over:
			continue
		var poison: int = _sget(e.statuses, "poison")
		if poison > 0:
			var next_hp: int = e.hp - poison
			var handoff: bool = next_hp <= 0 and _is_finale_handoff(e)
			var amount: int = poison
			if handoff:
				amount = maxi(0, e.hp - 1)
				e.hp = 1
			else:
				e.hp = next_hp
			cb.queue.append({
				"t": EventTypes.HIT_ENEMY,
				"idx": e.idx,
				"amount": amount,
				"blocked": 0,
				"hpAfter": maxi(0, e.hp),
				"dead": (not handoff) and e.hp <= 0,
				"poison": true,
			})
			_tick_status(e.statuses, "poison")
			if handoff:
				_begin_finale_handoff(run, cb, e)
				continue
			if e.hp <= 0:
				_on_enemy_death(run, cb, e)
				continue
		e.block = 0
		if e.staggered:
			# A shattered pane spends its turn reseaming: the move is skipped, but
			# its key still enters last_moves so rotation scripts don't repeat-lock.
			e.staggered = false
			e.last_moves.append(String(e.move_key))
			cb.queue.append({"t": EventTypes.STAGGERED, "idx": e.idx})
		else:
			var mv: Dictionary = e.move()
			cb.queue.append({
				"t": EventTypes.ENEMY_ACT,
				"idx": e.idx,
				"move": String(e.move_key),
				"name": str(mv.get("name", "")),
			})
			e.last_moves.append(String(e.move_key))
			if mv.get("dmg") != null:
				var times: int = _ji(mv.get("times", 1))
				for _t: int in range(times):
					if cb.over:
						break
					damage_player(run, cb, _ji(mv["dmg"]), e.idx, true, e)
				if mv.get("ramp") != null:
					e.flags["rampBonus"] = _ji(e.flags.get("rampBonus", 0)) + _ji(mv["ramp"])
			if cb.over:
				return
			if mv.get("block") != null:
				gain_block_enemy(cb, e, _ji(mv["block"]), run)
			if mv.get("heal") != null:
				var heal_before: int = e.hp
				e.hp = mini(e.max_hp, e.hp + _ji(mv["heal"]))
				cb.queue.append({"t": EventTypes.HEAL, "who": e.idx, "n": e.hp - heal_before})
			var mv_fx_v: Variant = mv.get("fx")
			if mv_fx_v != null:
				var mv_fx: Array = mv_fx_v
				for s_v: Variant in mv_fx:
					var s: Dictionary = s_v
					var who: String = str(s.get("who", ""))
					if who == "player":
						add_status_player(cb, str(s["id"]), _ji(s["n"]))
					elif who == "self":
						add_status_enemy(cb, e, str(s["id"]), _ji(s["n"]))
					elif who == "allies":
						for ally: EnemyCombatant in cb.enemies:
							if ally.hp > 0:
								add_status_enemy(cb, ally, str(s["id"]), _ji(s["n"]))
			var adds_v: Variant = mv.get("addCards")
			if typeof(adds_v) == TYPE_DICTIONARY:
				var adds: Dictionary = adds_v
				for _i: int in range(_ji(adds.get("n", 1))):
					var added: CardInst = CardInst.new(
						run.next_uid(), StringName(str(adds["id"])), false
					)
					cb.discard.append(added)
					cb.queue.append({"t": &"addCard", "id": String(added.id), "where": "discard"})
		# Enemy end-of-action: ritual, debuff tick (a staggered turn still ticks).
		var ritual: int = _sget(e.statuses, "ritual")
		if ritual > 0:
			add_status_enemy(cb, e, "str", ritual)
		_tick_status(e.statuses, "vulnerable")
		_tick_status(e.statuses, "weak")
	if cb.over:
		return
	_compute_intents(run, cb)
	_start_player_turn(run, cb)


static func _tick_status(statuses: Dictionary, id: String) -> void:
	var n: int = statuses.get(id, 0)
	if n > 0:
		n -= 1
		if n == 0:
			statuses.erase(id)
		else:
			statuses[id] = n


# ---------------------------------------------------------------- kindle & the Lantern Art

## The universal rite: once per turn, feed any hand card to the lantern.
## (crownOfTithes kindle limit 2: no slice source — the limit is 1.)
func can_kindle(run: RunState, cb: CombatState, inst: CardInst) -> bool:
	if inst == null or cb.over:
		return false
	if str(card_data(inst).get("type", "")) == "curse":
		return false  # hexes cling to the hand
	var limit: int = 2 if run.has_relic("crownOfTithes") else 1
	return not (cb.kindled_turn == cb.turn and cb.kindles_this_turn >= limit)


func kindle_from_hand(run: RunState, cb: CombatState, uid: int) -> bool:
	var i: int = -1
	for k: int in range(cb.hand.size()):
		if cb.hand[k].uid == uid:
			i = k
			break
	if i < 0:
		return false
	var inst: CardInst = cb.hand[i]
	if not can_kindle(run, cb, inst):
		return false
	if cb.kindled_turn != cb.turn:
		cb.kindled_turn = cb.turn
		cb.kindles_this_turn = 0
	cb.kindles_this_turn += 1
	cb.hand.remove_at(i)
	run.stats["kindles"] = _ji(run.stats.get("kindles", 0)) + 1
	cb.queue.append({"t": EventTypes.KINDLE, "uid": inst.uid, "id": String(inst.id)})
	exhaust_card(run, cb, inst)
	if run.has_relic("crownOfTithes"):
		gain_block_player(cb, 3, false, run)
		_proc(cb, "crownOfTithes")
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
	var cost: int = _ji(art.get("cost", 0))
	run.stats["embersSpent"] = _ji(run.stats.get("embersSpent", 0)) + cost
	gain_embers(run, cb, -cost)
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
					add_status_enemy(cb, e, sid, sn, run)
		"block":
			gain_block_player(cb, _ji(fx["n"]), false, run)
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

func use_potion(run: RunState, cb: CombatState, slot: int, target_idx: Variant = null) -> bool:
	if slot < 0 or slot >= run.player.potions.size():
		return false
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
		"swift":
			draw_cards(run, cb, 3)
		"block":
			gain_block_player(cb, 12, false, run)
		"fire":
			var fire_ti: int = target_idx
			hit_enemy(run, cb, cb.enemies[fire_ti], 20, false)
		"venom":
			var venom_ti: int = target_idx
			add_status_enemy(cb, cb.enemies[venom_ti], "poison", 7, run)
		"energy":
			gain_embers(run, cb, 3)
		_:
			push_error("CombatRules: unknown potion %s" % id)
	return true


# ---------------------------------------------------------------- previews
# Pure arithmetic mirrors of the laws above — no state touched. If a combat
# calculation changes, its mirror here must change in lockstep.

func preview_block(cb: CombatState, base: int, run: RunState = null) -> int:
	var b: int = base + _sget(cb.player.statuses, "dex")
	if _sget(cb.player.statuses, "frail") > 0:
		b = int(floorf(float(b) * 0.75))
	b = maxi(0, b)
	return int(roundf(float(b) * float(str(_omen_mods(run).get("wardMult", 1))))) \
		if run != null else b


## null when the intent deals no damage, else {"dmg": int, "times": int}.
func preview_enemy_dmg(
	cb: CombatState, e: EnemyCombatant, run: RunState = null
) -> Variant:
	var mv: Dictionary = e.move()
	var dmg_v: Variant = mv.get("dmg")
	if dmg_v == null:
		return null
	var dmg: int = _ji(dmg_v) + _sget(e.statuses, "str") + _ji(e.flags.get("rampBonus", 0))
	if run != null:
		dmg += _ji(_omen_mods(run).get("enemyDmgBonus", 0))
		dmg += _ji(_vow_mods(run).get("enemyDmgBonus", 0))
	if _sget(e.statuses, "weak") > 0:
		dmg = int(floorf(float(dmg) * 0.75))
	if _sget(cb.player.statuses, "vulnerable") > 0:
		dmg = int(floorf(float(dmg) * 1.5))
	if run != null and run.has_relic("wardingCharm") and dmg > 0 and dmg <= 5:
		dmg = 1
	return {"dmg": maxi(0, dmg), "times": _ji(mv.get("times", 1))}


## What would this card actually do to this target? null when it previews nothing.
func preview_play(
	cb: CombatState, inst: CardInst, target_idx: Variant = null, run: RunState = null
) -> Variant:
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
			block += preview_block(cb, _ji(fx["n"]), run)
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
		# Ash (aspect != 0) still computes per, then zeros — apply_chips no-ops.
		var per: int = 0
		if str(d.get("type", "")) == "attack":
			per = 1 + _ji(d.get("chip", 0)) + _sget(p.statuses, "beacon")
		chips = (per if (hits.size() > 0 and loss > 0) else 0) + fx_chips
		if run != null and run.aspect != 0:
			chips = 0
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
