class_name RunState
extends RefCounted
## Run-scoped state the combat core reads and writes. M3 carries the minimal
## surface the recorded slice traces exercise; map/rewards/saves land in M4.
## The one rng stream: every draw goes through `rng`, whose signed 32-bit
## state is the fixture `rngState` cursor.


## Persistent run-scoped hero state (web run.player).
class Player:
	var hp: int = 0
	var max_hp: int = 0
	var gold: int = 0
	var energy_max: int = 0
	var relics: Array[String] = []
	var potions: Array[String] = []  # "" == empty slot (fixture null)
	var deck: Array[CardInst] = []


var seed: int = 0
var rng: Rng = Rng.new(0)
var act: int = 0
var floors_climbed: int = 0
var aspect: int = 0
var vow: int = 0
var art: StringName = &""
var uid: int = 1
## Progressive-delivery reveals (web run.reveals). A fresh profile carries an
## explicit list; `reveals_all` mirrors the web's null = legacy "everything
## revealed" profile.
var reveals_all: bool = false
var reveals: Array[String] = []
var player: Player = Player.new()
## Save-carried run fields (heal defaults per the web additive-heal contract).
## Data-only until their systems port: unlocks/omens/boon/shards behavior
## lands with the Vigil/omen waves.
var unlocks: Array = []
var omens: Array = []  # one entry per act; null == no omen that act
var boon: Variant = null
var boss_relic_act: int = -1
var shards: Array = []
var map: Dictionary = {"nodes": []}  # slice placeholder; horizontal map lands at M4c/M6
var pending_combat: Variant = null
var pending_enemy_ids: Variant = null


func rng_state() -> int:
	return rng.get_state()


func has_relic(relic_id: String) -> bool:
	return player.relics.has(relic_id)


## Post-increment uid allocator (web run.uid++).
func next_uid() -> int:
	var u: int = uid
	uid += 1
	return u


## Save-result projection (web exporter projectSaveResult) — the trace
## projection plus the save-carried fields.
func to_save_result_dict() -> Dictionary:
	var out: Dictionary = to_dict()
	out["unlocks"] = unlocks.duplicate()
	out["omens"] = omens.duplicate()
	out["boon"] = boon
	out["bossRelicAct"] = boss_relic_act
	out["reveals"] = null if reveals_all else reveals.duplicate()
	out["shards"] = shards.duplicate()
	return out


## The persisted envelope (user://glassvow_save_v1.json). Web saves never
## migrate; this is the new lineage with the web's *semantics* (versioned
## envelope, id-validation-on-load, resume-via-pending-encounter).
func to_save_dict() -> Dictionary:
	var out: Dictionary = to_save_result_dict()
	out["v"] = 1
	out["map"] = map.duplicate(true)
	out["pendingCombat"] = pending_combat
	out["pendingEnemyIds"] = pending_enemy_ids
	return out


static func _sji(v: Variant) -> int:
	return int(float(str(v)))


## Fresh-profile run built from content.player (web newRun with reveals:[]).
## Not parity-pinned — the web newRun also rolls the tower map, which is
## redesigned — but combat parity holds from any rng cursor. reveals stays []
## (fresh profile = core only): omens/lamplighter/pool-waves gated off.
static func new_run(content: ContentDB, run_seed: int) -> RunState:
	var rs: RunState = RunState.new()
	rs.seed = run_seed
	rs.rng = Rng.new(run_seed)
	var cp: Dictionary = content.player
	rs.art = StringName(str(cp.get("art", "flare")))
	rs.player.max_hp = _sji(cp.get("maxHp", 1))
	rs.player.hp = rs.player.max_hp
	rs.player.gold = _sji(cp.get("startGold", 0))
	rs.player.energy_max = _sji(cp.get("energy", 3))
	rs.player.relics.append(str(cp.get("startRelic", "")))
	for _i: int in range(_sji(cp.get("potionSlots", 3))):
		rs.player.potions.append("")
	var deck_ids: Array = cp.get("startDeck", [])
	for id_v: Variant in deck_ids:
		rs.player.deck.append(CardInst.new(rs.next_uid(), StringName(str(id_v)), false))
	rs.omens.append(null)  # act 0 top-up; fresh profile rolls no omen
	return rs


## Load + validate a save envelope. Returns null on reject — any unknown
## content id drops the WHOLE save (stale-content shield; never partially
## heal by substituting items). Missing additive fields self-heal so a save
## from an older v1 build stays playable. Mirrors the web normaliseRunSnapshot
## order: envelope -> id shield -> additive heals -> reveals validation.
static func from_save_dict(save: Dictionary, content: ContentDB) -> RunState:
	# ---- envelope
	if _sji(save.get("v", -1)) != 1:
		return null
	if typeof(save.get("player")) != TYPE_DICTIONARY:
		return null
	if typeof(save.get("map")) != TYPE_DICTIONARY:
		return null
	var p: Dictionary = save["player"]
	# ---- stale-content shield
	if typeof(p.get("deck")) != TYPE_ARRAY:
		return null
	var deck_list: Array = p["deck"]
	for c_v: Variant in deck_list:
		if typeof(c_v) != TYPE_DICTIONARY:
			return null
		var cd: Dictionary = c_v
		if not content.cards.has(str(cd.get("id"))):
			return null
	var relics_list: Array = p.get("relics", [])
	for r_v: Variant in relics_list:
		if not content.relics.has(str(r_v)):
			return null
	var potions_list: Array = p.get("potions", [])
	for pv: Variant in potions_list:
		if pv != null and not content.potions.has(str(pv)):
			return null
	var art_v: Variant = save.get("art")
	if art_v != null and not content.arts.has(str(art_v)):
		return null
	var omens_list: Array = save.get("omens", [])
	for o_v: Variant in omens_list:
		# The slice ships no omen registry, so any non-null omen id is stale
		# content — same shield as the web's hasOwn(content.omens, id).
		if o_v != null:
			return null
	# ---- additive heals + build
	var rs: RunState = RunState.new()
	rs.seed = _sji(save.get("seed", 0))
	rs.rng = Rng.new(_sji(save.get("rngState", 0)))
	rs.act = _sji(save.get("act", 0))
	rs.floors_climbed = _sji(save.get("floorsClimbed", 0))
	# aspect/vow registry clamps need the aspects/vows registries (full wave).
	rs.aspect = _sji(save.get("aspect", 0))
	rs.vow = _sji(save.get("vow", 0))
	var content_player: Dictionary = content.player
	rs.art = StringName(str(art_v)) if art_v != null else StringName(str(content_player.get("art", "flare")))
	rs.unlocks = save.get("unlocks", [])
	rs.omens = omens_list
	rs.boon = save.get("boon")
	rs.boss_relic_act = _sji(save.get("bossRelicAct", -1))
	rs.shards = save.get("shards", [])
	rs.map = save["map"]
	rs.pending_combat = save.get("pendingCombat")
	rs.pending_enemy_ids = save.get("pendingEnemyIds")
	var reveals_v: Variant = save.get("reveals")
	if reveals_v == null:
		rs.reveals_all = true
	else:
		if typeof(reveals_v) != TYPE_ARRAY:
			return null
		var reveals_list: Array = reveals_v
		for rev_v: Variant in reveals_list:
			if not content.reveal_ids.has(str(rev_v)):
				return null
			rs.reveals.append(str(rev_v))
	# Omen top-up to one entry per act (web: omenEnabled ? rollOmen : null).
	# Omens are reveal-gated; the slice/fresh profile always tops up with null.
	# The rollOmen rng path lands with the omen system.
	while rs.omens.size() <= rs.act:
		if rs.reveals_all or rs.reveals.has("omens"):
			push_error("RunState.from_save_dict: omen roll path not ported")
		rs.omens.append(null)
	rs.player.hp = _sji(p.get("hp", 0))
	rs.player.max_hp = _sji(p.get("maxHp", 0))
	rs.player.gold = _sji(p.get("gold", 0))
	rs.player.energy_max = _sji(p.get("energyMax", 0))
	for r_v: Variant in relics_list:
		rs.player.relics.append(str(r_v))
	for pv: Variant in potions_list:
		rs.player.potions.append("" if pv == null else str(pv))
	var max_uid: int = 0
	for c_v: Variant in deck_list:
		var cd: Dictionary = c_v
		var up: bool = cd.get("up", false)
		var inst: CardInst = CardInst.new(_sji(cd.get("uid", 0)), StringName(str(cd.get("id"))), up)
		inst.bonus = _sji(cd.get("bonus", 0))
		rs.player.deck.append(inst)
		max_uid = maxi(max_uid, inst.uid)
	rs.uid = max_uid + 1
	return rs


## Fixture projection (web exporter projectRunSnapshot).
func to_dict() -> Dictionary:
	var deck_out: Array = []
	for c: CardInst in player.deck:
		deck_out.append(c.to_dict())
	var potions_out: Array = []
	for p: String in player.potions:
		potions_out.append(null if p == "" else p)
	return {
		"seed": seed,
		"rngState": rng.get_state(),
		"act": act,
		"floorsClimbed": floors_climbed,
		"aspect": aspect,
		"vow": vow,
		"art": String(art),
		"player": {
			"hp": player.hp,
			"maxHp": player.max_hp,
			"gold": player.gold,
			"energyMax": player.energy_max,
			"relics": player.relics.duplicate(),
			"potions": potions_out,
			"deck": deck_out,
		},
	}
