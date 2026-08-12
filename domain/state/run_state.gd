class_name RunState
extends RefCounted
## Run-scoped state for combat, map, rewards, quests and durable routing. Every
## draw uses the one RNG stream whose signed 32-bit state is the fixture cursor.

const SAVE_VERSION: int = 2


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
var run_id: String = ""
var rng: Rng = Rng.new(0)
var act: int = 0
var node_id: Variant = null
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
var boon_receipt: Variant = null
var boss_relic_act: int = -1
var shards: Array = []
var monument: Variant = null
var quests: Dictionary = {}
var quest_scratch: Dictionary = {}
var quest_completions: Array = []
var stats: Dictionary = {
	"slain": 0, "elites": 0, "bosses": 0, "dmgDealt": 0, "dmgTaken": 0,
	"cardsPlayed": 0, "goldEarned": 0, "shatters": 0, "kindles": 0,
	"perfects": 0, "smolderKills": 0, "unlitVisited": 0, "embersSpent": 0,
}
var map: Dictionary = {"nodes": [], "visited": []}
var pending_combat: Variant = null
var pending_enemy_ids: Variant = null
var pending_quest_id: Variant = null
var pending_reward: Variant = null
var pending_run_end: Variant = null
var pending_dawn: Variant = null
var pending_hollow: Variant = null
var pending_hollow_route: Variant = null
var pending_lamplighter: bool = false


func rng_state() -> int:
	return rng.get_state()


func has_relic(relic_id: String) -> bool:
	return player.relics.has(relic_id)


## Post-increment uid allocator (web run.uid++).
func next_uid() -> int:
	var u: int = uid
	uid += 1
	return u


func start_next_act(content: ContentDB) -> void:
	act += 1
	node_id = null
	player.hp = mini(player.max_hp,
		player.hp + int(roundf(float(player.max_hp) * 0.35)))
	while omens.size() <= act:
		omens.append(_roll_omen(self, content)
			if reveals_all or reveals.has("omens") else null)


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


## The persisted envelope (user://glassvow_run_v2.json). v1 is deliberately
## ignored: this programme starts a new lineage rather than guessing at a
## partial migration.
func to_save_dict() -> Dictionary:
	var out: Dictionary = to_save_result_dict()
	out["v"] = SAVE_VERSION
	out["runId"] = run_id
	out["boonReceipt"] = boon_receipt
	out["nodeId"] = node_id
	out["map"] = map.duplicate(true)
	out["monument"] = monument
	out["quests"] = quests.duplicate(true)
	out["questScratch"] = quest_scratch.duplicate(true)
	out["questCompletions"] = quest_completions.duplicate()
	out["stats"] = stats.duplicate(true)
	out["pendingCombat"] = pending_combat
	out["pendingEnemyIds"] = pending_enemy_ids
	out["pendingQuestId"] = pending_quest_id
	out["pendingReward"] = pending_reward
	out["pendingRunEnd"] = pending_run_end
	out["pendingDawn"] = pending_dawn
	out["pendingHollow"] = pending_hollow
	out["pendingHollowRoute"] = pending_hollow_route
	out["pendingLamplighter"] = pending_lamplighter
	return out


static func _sji(v: Variant) -> int:
	return int(float(str(v)))


## Fresh-profile run built from content.player (web newRun with reveals:[]).
## Not parity-pinned — the web newRun also rolls the tower map, which is
## redesigned — but combat parity holds from any rng cursor. reveals stays []
## (fresh profile = core only): omens/lamplighter/pool-waves gated off.
static func new_run(
	content: ContentDB,
	run_seed: int,
	requested_run_id: String = "",
	profile: Dictionary = {}
) -> RunState:
	var rs: RunState = RunState.new()
	rs.seed = run_seed
	rs.run_id = requested_run_id if not requested_run_id.is_empty() else "run-%08x" % (run_seed & 0xFFFFFFFF)
	rs.rng = Rng.new(run_seed)
	rs.aspect = clampi(_sji(profile.get("aspect", 0)), 0, maxi(0, content.aspects.size() - 1))
	rs.vow = clampi(_sji(profile.get("vow", 0)), 0, content.vows.size())
	var cp: Dictionary = content.aspects[rs.aspect] if not content.aspects.is_empty() else content.player
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
	for unlock_v: Variant in profile.get("unlocks", []):
		rs.unlocks.append(str(unlock_v))
	var reveals_v: Variant = profile.get("reveals", [])
	if reveals_v == null:
		rs.reveals_all = true
	else:
		for reveal_v: Variant in reveals_v:
			rs.reveals.append(str(reveal_v))
	rs.boon = profile.get("boon")
	rs.monument = profile.get("monument")
	rs.shards = profile.get("shards", []).duplicate()
	var quests_v: Variant = profile.get("quests")
	if typeof(quests_v) == TYPE_DICTIONARY:
		var profile_quests: Dictionary = quests_v
		for quest_id: String in content.quest_ids:
			var source_v: Variant = profile_quests.get(quest_id)
			if typeof(source_v) == TYPE_DICTIONARY:
				var source: Dictionary = source_v
				rs.quests[quest_id] = {
					"state": str(source.get("state", "dormant")),
					"progress": clampi(
						_sji(source.get("progress", 0)), 0,
						_sji(content.quests[quest_id].get("target", 0))
					),
					"memory": source.get("memory", {}).duplicate(true),
				}
	rs.pending_lamplighter = profile.get("lamplighter", false)
	if rs.vow >= 4:
		rs.player.deck.append(CardInst.new(rs.next_uid(), &"hex", false))
	rs.omens.append(_roll_omen(rs, content) if rs.reveals_all or rs.reveals.has("omens") else null)
	return rs


static func _roll_omen(rs: RunState, content: ContentDB) -> Variant:
	var ids: Array = content.omens.keys()
	ids.erase("eighthOmen")
	return ids[rs.rng.pick_index(ids.size())] if not ids.is_empty() else null


## Load + validate a save envelope. Returns null on reject — any unknown
## content id drops the WHOLE save (stale-content shield; never partially
## heal by substituting items). Missing additive fields self-heal so a save
## from an older v2 build stays playable. Mirrors the web normaliseRunSnapshot
## order: envelope -> id shield -> additive heals -> reveals validation.
static func from_save_dict(save: Dictionary, content: ContentDB) -> RunState:
	# ---- envelope
	if _sji(save.get("v", -1)) != SAVE_VERSION:
		return null
	if typeof(save.get("player")) != TYPE_DICTIONARY:
		return null
	if typeof(save.get("map")) != TYPE_DICTIONARY:
		return null
	if not _valid_pending(save, content):
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
		if o_v != null and not content.omens.has(str(o_v)):
			return null
	var boon_v: Variant = save.get("boon")
	if boon_v != null and not content.boons.has(str(boon_v)):
		return null
	var boon_receipt_v: Variant = save.get("boonReceipt")
	if boon_receipt_v != null and not _valid_boon_receipt(boon_receipt_v, boon_v, content):
		return null
	var quest_scratch_v: Variant = save.get("questScratch", {})
	if typeof(quest_scratch_v) != TYPE_DICTIONARY:
		return null
	# ---- additive heals + build
	var rs: RunState = RunState.new()
	rs.seed = _sji(save.get("seed", 0))
	rs.run_id = str(save.get("runId", ""))
	if rs.run_id.is_empty():
		return null
	rs.rng = Rng.new(_sji(save.get("rngState", 0)))
	rs.act = _sji(save.get("act", 0))
	rs.node_id = save.get("nodeId")
	rs.floors_climbed = _sji(save.get("floorsClimbed", 0))
	rs.aspect = clampi(_sji(save.get("aspect", 0)), 0, maxi(0, content.aspects.size() - 1))
	rs.vow = clampi(_sji(save.get("vow", 0)), 0, content.vows.size())
	var content_player: Dictionary = content.player
	rs.art = StringName(str(art_v)) if art_v != null else StringName(str(content_player.get("art", "flare")))
	rs.unlocks = save.get("unlocks", [])
	rs.omens = omens_list
	rs.boon = boon_v
	rs.boon_receipt = boon_receipt_v
	rs.boss_relic_act = _sji(save.get("bossRelicAct", -1))
	rs.shards = save.get("shards", [])
	rs.monument = save.get("monument")
	rs.quests = save.get("quests", {})
	rs.quest_scratch = quest_scratch_v
	rs.quest_completions = save.get("questCompletions", [])
	var saved_stats: Dictionary = save.get("stats", {})
	rs.stats.merge(saved_stats, true)
	rs.map = save["map"]
	rs.pending_combat = save.get("pendingCombat")
	rs.pending_enemy_ids = save.get("pendingEnemyIds")
	rs.pending_quest_id = save.get("pendingQuestId")
	rs.pending_reward = save.get("pendingReward")
	rs.pending_run_end = save.get("pendingRunEnd")
	rs.pending_dawn = save.get("pendingDawn")
	rs.pending_hollow = save.get("pendingHollow")
	rs.pending_hollow_route = save.get("pendingHollowRoute")
	rs.pending_lamplighter = save.get("pendingLamplighter", false)
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
			rs.omens.append(_roll_omen(rs, content))
		else:
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


static func _valid_pending(save: Dictionary, content: ContentDB) -> bool:
	var combat: Variant = save.get("pendingCombat")
	var enemies: Variant = save.get("pendingEnemyIds")
	var reward: Variant = save.get("pendingReward")
	var run_end: Variant = save.get("pendingRunEnd")
	var dawn: Variant = save.get("pendingDawn")
	var hollow: Variant = save.get("pendingHollow")
	var route: Variant = save.get("pendingHollowRoute")
	var lamplighter: Variant = save.get("pendingLamplighter", false)
	if typeof(lamplighter) != TYPE_BOOL:
		return false
	if combat != null and str(combat) not in ["monster", "elite", "boss"]:
		return false
	if enemies != null:
		if combat == null or typeof(enemies) != TYPE_ARRAY or enemies.is_empty():
			return false
		for enemy_v: Variant in enemies:
			if not content.enemies.has(str(enemy_v)):
				return false
	if reward != null and not _valid_pending_reward(reward, content):
		return false
	if run_end != null:
		if typeof(run_end) != TYPE_DICTIONARY or str(run_end.get("outcome")) not in ["win", "death", "abandon"]:
			return false
	if dawn != null:
		if typeof(dawn) != TYPE_DICTIONARY or typeof(dawn.get("events")) != TYPE_ARRAY:
			return false
		var cursor: int = _sji(dawn.get("cursor", -1))
		if cursor < 0 or cursor > dawn["events"].size():
			return false
	if hollow != null and typeof(hollow) != TYPE_DICTIONARY:
		return false
	if route != null and typeof(route) != TYPE_DICTIONARY:
		return false
	if hollow != null and (route != null or combat != null or reward != null or run_end != null or dawn != null):
		return false
	if route != null and (hollow != null or combat != null or reward != null or run_end != null or dawn != null):
		return false
	if reward != null and combat != null:
		return false
	if run_end != null and (combat != null or reward != null or dawn != null):
		return false
	if dawn != null and (combat != null or reward != null or run_end != null or hollow != null or route != null):
		return false
	return true


static func _valid_pending_reward(value: Variant, content: ContentDB) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var pending: Dictionary = value
	if typeof(pending.get("rewards")) != TYPE_DICTIONARY or typeof(pending.get("taken")) != TYPE_DICTIONARY:
		return false
	var rewards: Dictionary = pending["rewards"]
	var cards_v: Variant = rewards.get("cards")
	if typeof(cards_v) != TYPE_ARRAY or cards_v.is_empty():
		return false
	for card_v: Variant in cards_v:
		if not content.cards.has(str(card_v)):
			return false
	var potion_v: Variant = rewards.get("potion")
	var relic_v: Variant = rewards.get("relic")
	return (potion_v == null or content.potions.has(str(potion_v))) \
		and (relic_v == null or content.relics.has(str(relic_v)))


static func _valid_boon_receipt(
	value: Variant, boon: Variant, content: ContentDB
) -> bool:
	if typeof(value) != TYPE_DICTIONARY or boon == null:
		return false
	var receipt: Dictionary = value
	var id: String = str(receipt.get("id", ""))
	if id != str(boon) or not content.boons.has(id) \
			or typeof(receipt.get("playerDelta")) != TYPE_DICTIONARY \
			or typeof(receipt.get("relicsAdded")) != TYPE_ARRAY \
			or typeof(receipt.get("potionSlotsAdded")) != TYPE_ARRAY:
		return false
	for relic_v: Variant in receipt["relicsAdded"]:
		if not content.relics.has(str(relic_v)):
			return false
	for row_v: Variant in receipt["potionSlotsAdded"]:
		if typeof(row_v) != TYPE_DICTIONARY:
			return false
		var row: Dictionary = row_v
		if _sji(row.get("index", -1)) < 0 or not content.potions.has(str(row.get("id", ""))):
			return false
	return true


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
