class_name StateBuild
extends RefCounted
## Test support: build domain state from fixture projections, and normalize
## domain values into the JSON type universe (floats/Strings/null) so
## diff.gd deep_eq compares them directly against parsed fixtures.


static func jsonish(v: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(v))


static func ji(v: Variant) -> int:
	return int(float(str(v)))


static func statuses_into(src: Dictionary, dst: Dictionary) -> void:
	for k: Variant in src.keys():
		dst[str(k)] = ji(src[k])


static func cards_from(list: Array) -> Array[CardInst]:
	var out: Array[CardInst] = []
	for c: Variant in list:
		var cd: Dictionary = c
		var up: bool = cd.get("up", false)
		var inst: CardInst = CardInst.new(ji(cd["uid"]), StringName(str(cd["id"])), up)
		inst.bonus = ji(cd.get("bonus", 0))
		out.append(inst)
	return out


## The run behind a probe row: the slice starter loadout (emberHeart, flare),
## hp mirrored from the probe's player projection. Probes are rng-free.
static func probe_run(pre_player: Dictionary) -> RunState:
	var rs: RunState = RunState.new()
	rs.rng = Rng.new(0)
	rs.art = &"flare"
	rs.player.relics.append("emberHeart")
	rs.player.potions = ["", "", ""]
	rs.player.hp = ji(pre_player["hp"])
	rs.player.max_hp = ji(pre_player["maxHp"])
	rs.player.energy_max = ji(pre_player["energyMax"])
	rs.uid = 100
	return rs


static func enemy_from(content: ContentDB, ed: Dictionary) -> EnemyCombatant:
	var e: EnemyCombatant = EnemyCombatant.new()
	e.key = StringName(str(ed["key"]))
	e.def = content.enemy(e.key)
	e.name = str(e.def.get("name", ""))
	var elite_flag: bool = e.def.get("elite", false)
	var boss_flag: bool = e.def.get("boss", false)
	e.elite = elite_flag
	e.boss = boss_flag
	e.idx = ji(ed.get("idx", 0))
	e.hp = ji(ed.get("hp", 0))
	e.max_hp = ji(ed.get("maxHp", 0))
	e.block = ji(ed.get("block", 0))
	e.chips = ji(ed.get("chips", 0))
	e.facet_max = ji(ed.get("facetMax", 0))
	var mk: Variant = ed.get("moveKey")
	e.move_key = &"" if mk == null else StringName(str(mk))
	var st: Dictionary = ed.get("statuses", {})
	statuses_into(st, e.statuses)
	return e


## CombatState reconstructed from a probe row's `pre` projection.
static func combat_from_projection(content: ContentDB, proj: Dictionary) -> CombatState:
	var cb: CombatState = CombatState.new()
	cb.kind = StringName(str(proj["kind"]))
	var affix_v: Variant = proj["affix"]
	cb.affix = &"" if affix_v == null else StringName(str(affix_v))
	cb.turn = ji(proj["turn"])
	var over: bool = proj["over"]
	cb.over = over
	var result_v: Variant = proj["result"]
	cb.result = "" if result_v == null else str(result_v)
	cb.embers = ji(proj["embers"])
	var pp: Dictionary = proj["player"]
	cb.player.hp = ji(pp["hp"])
	cb.player.max_hp = ji(pp["maxHp"])
	cb.player.block = ji(pp["block"])
	cb.player.energy = ji(pp["energy"])
	cb.player.energy_max = ji(pp["energyMax"])
	var pst: Dictionary = pp["statuses"]
	statuses_into(pst, cb.player.statuses)
	var enemies: Array = proj["enemies"]
	for ev: Variant in enemies:
		var ed: Dictionary = ev
		cb.enemies.append(enemy_from(content, ed))
	var hand_list: Array = proj["hand"]
	var draw_list: Array = proj["draw"]
	var discard_list: Array = proj["discard"]
	var exhaust_list: Array = proj["exhaust"]
	cb.hand = cards_from(hand_list)
	cb.draw = cards_from(draw_list)
	cb.discard = cards_from(discard_list)
	cb.exhaust = cards_from(exhaust_list)
	return cb


## RunState from a trace `snapshot` row's `run` projection. The uid allocator
## is not exported; the next uid is max(deck uid) + 1 by construction.
static func run_from_snapshot(snap: Dictionary) -> RunState:
	var rs: RunState = RunState.new()
	rs.seed = ji(snap["seed"])
	rs.rng = Rng.new(ji(snap["rngState"]))
	rs.act = ji(snap["act"])
	rs.floors_climbed = ji(snap["floorsClimbed"])
	rs.aspect = ji(snap["aspect"])
	rs.vow = ji(snap["vow"])
	rs.art = StringName(str(snap["art"]))
	var p: Dictionary = snap["player"]
	rs.player.hp = ji(p["hp"])
	rs.player.max_hp = ji(p["maxHp"])
	rs.player.gold = ji(p["gold"])
	rs.player.energy_max = ji(p["energyMax"])
	var relics: Array = p["relics"]
	for r: Variant in relics:
		rs.player.relics.append(str(r))
	var potions: Array = p["potions"]
	for pv: Variant in potions:
		rs.player.potions.append("" if pv == null else str(pv))
	var deck: Array = p["deck"]
	var max_uid: int = 0
	for c: Variant in deck:
		var cd: Dictionary = c
		var inst: CardInst = CardInst.new(ji(cd["uid"]), StringName(str(cd["id"])), false)
		rs.player.deck.append(inst)
		max_uid = maxi(max_uid, inst.uid)
	rs.uid = max_uid + 1
	return rs
