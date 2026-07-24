class_name StateBuild
extends RefCounted
## Test support: build domain state from fixture projections, and normalize
## domain values into the JSON type universe (floats/Strings/null) so
## diff.gd deep_eq compares them directly against parsed fixtures.


static func jsonish(v: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(v))


static func ji(v: Variant) -> int:
	return int(float(str(v)))


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
