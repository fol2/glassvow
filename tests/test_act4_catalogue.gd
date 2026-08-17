extends RefCounted
## Slice 4 — production Act IV catalogue: acts[3], rewards, five-node encounters,
## named map Scenarios, and fail-closed encounter ids.

const RUN_PATH: String = "user://glassvow_test_act4_run_v2.json"
const VIGIL_PATH: String = "user://glassvow_test_act4_vigil_v2.json"
const REF_PATH: String = "user://glassvow_test_act4_scenario.json"
const BUILD: String = "test-act4-sha"
const ROSTER: PackedStringArray = [
	"unopenedSelf", "unwalkedSelf", "uncrossedSelf", "unlitSelf",
	"unobsidianSelf", "unwoodedSelf", "unsunkSelf", "uncarvedSelf",
]
const ACT3: PackedStringArray = [
	"voidWisp", "shade", "starCultist", "obsidianGolem", "chaosHound",
	"watcherEye", "voidColossus", "heraldOfEnd", "sovereign",
]


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	_act_row(content, fails)
	_gold(content, fails)
	_encounters(content, fails)
	_unknown_id_fails(content, fails)
	_scenarios(content, fails)
	_handoff(content, fails)


static func _act_row(content: ContentDB, fails: Array[String]) -> void:
	if content.acts.size() != 4:
		fails.append("act4: expected 4 act rows, got %d" % content.acts.size())
		return
	var row: Dictionary = content.acts[3]
	if str(row.get("name", "")) != "The Mirrored Road":
		fails.append("act4: act name must be The Mirrored Road")
	if str(row.get("bossName", "")) != "The Eternal Keeper":
		fails.append("act4: bossName must be The Eternal Keeper")
	if str(row.get("boss", "")) != "eternalKeeper":
		fails.append("act4: boss id must be eternalKeeper")
	var theme_v: Variant = row.get("theme", {})
	if typeof(theme_v) != TYPE_DICTIONARY:
		fails.append("act4: theme missing")
	else:
		var theme: Dictionary = theme_v
		if str(theme.get("accent", "")) != "#e8b890":
			fails.append("act4: theme accent must match the authored dawn row")


static func _gold(content: ContentDB, fails: Array[String]) -> void:
	if content.reward_gold.size() != 4:
		fails.append("act4: expected 4 rewardGold rows, got %d" % content.reward_gold.size())
		return
	var prior: Dictionary = content.reward_gold[2]
	var row: Dictionary = content.reward_gold[3]
	for tier: String in ["normal", "elite", "boss"]:
		var prev_v: Variant = prior.get(tier, [])
		var next_v: Variant = row.get(tier, [])
		if typeof(prev_v) != TYPE_ARRAY or typeof(next_v) != TYPE_ARRAY:
			fails.append("act4: rewardGold.%s is not a range" % tier)
			continue
		var prev: Array = prev_v
		var nxt: Array = next_v
		if nxt.size() != 2 or float(str(nxt[0])) <= float(str(prev[0])) \
				or float(str(nxt[1])) <= float(str(prev[1])):
			fails.append("act4: rewardGold.%s did not step up from act III" % tier)


static func _encounters(content: ContentDB, fails: Array[String]) -> void:
	if content.encounters.size() != 4:
		fails.append("act4: expected 4 encounter rows, got %d" % content.encounters.size())
		return
	var row: Dictionary = content.encounters[3]
	var seen: Dictionary = {}
	var groups: int = 0
	for tier: String in ["weak", "normal", "elite", "boss"]:
		var pool_v: Variant = row.get(tier, [])
		if typeof(pool_v) != TYPE_ARRAY:
			fails.append("act4: %s tier is not an array" % tier)
			continue
		var pool: Array = pool_v
		if pool.is_empty():
			fails.append("act4: %s tier is empty" % tier)
			continue
		groups += pool.size()
		for group_v: Variant in pool:
			if typeof(group_v) != TYPE_ARRAY:
				fails.append("act4: %s has a non-array group" % tier)
				continue
			var group: Array = group_v
			for id_v: Variant in group:
				var eid: String = str(id_v)
				seen[eid] = true
				if not content.enemies.has(eid):
					fails.append("act4: unknown encounter id %s" % eid)
				if ACT3.has(eid):
					fails.append("act4: Act III enemy %s leaked into the mirror roster" % eid)
	if groups < 13 or groups > 14:
		fails.append("act4: expected 13–14 encounter groups, got %d" % groups)
	for id: String in ROSTER:
		if not seen.has(id):
			fails.append("act4: roster id %s never appears" % id)
	if not seen.has("eternalKeeper"):
		fails.append("act4: boss pool dropped eternalKeeper")
	var boss_v: Variant = row.get("boss", [])
	if typeof(boss_v) != TYPE_ARRAY:
		fails.append("act4: boss tier is not an array")
	else:
		var boss: Array = boss_v
		var head: Array = []
		if not boss.is_empty() and typeof(boss[0]) == TYPE_ARRAY:
			head = boss[0]
		if boss.size() != 1 or head.size() != 1 or str(head[0]) != "eternalKeeper":
			fails.append("act4: boss tier must be exactly [eternalKeeper]")
	var keeper: Dictionary = content.enemy(&"eternalKeeper")
	if keeper.get("finaleHandoff", false) != true:
		fails.append("act4: Keeper lost finaleHandoff")


static func _unknown_id_fails(content: ContentDB, fails: Array[String]) -> void:
	var cursed: Array = content.encounters.duplicate(true)
	var row: Dictionary = cursed[3]
	var weak: Array = row["weak"]
	weak.append(["notAFoe"])
	content.encounters = cursed
	var faults: Array[String] = []
	content.validate(faults)
	var caught: bool = false
	for msg: String in faults:
		if msg.contains("notAFoe"):
			caught = true
			break
	if not caught:
		fails.append("act4: unknown encounter id was accepted")
	content.encounters = ContentDB.load_full().encounters


static func _scenarios(content: ContentDB, fails: Array[String]) -> void:
	var kernel: ScenarioKernel = ScenarioKernel.new(content, RUN_PATH, VIGIL_PATH, REF_PATH)
	kernel.clear_profile()
	for id: String in ["act-4-map-start", "act-4-map-branch", "act-4-map-terminus"]:
		var ref: ScenarioReference = ScenarioReference.new()
		if not ref.load_from({
			"id": id, "revision": 1, "build": BUILD,
			"seed": 18501, "locale": "en", "shape": "pad-landscape",
			"overrides": _overrides_for(id),
		}):
			fails.append("act4: %s rejected: %s" % [id, ref.error])
			continue
		var run: RunState = kernel.construct(ref)
		if run == null:
			fails.append("act4: %s failed: %s" % [id, kernel.last_error])
			continue
		if run.act != 3:
			fails.append("act4: %s did not seat act 3" % id)
		if id == "act-4-map-terminus":
			if run.pending_enemy_ids != ["eternalKeeper"]:
				fails.append("act4: terminus did not freeze the Keeper")
			if str(run.pending_combat) != "boss":
				fails.append("act4: terminus kind was %s" % str(run.pending_combat))
	kernel.clear_profile()


static func _overrides_for(id: String) -> Dictionary:
	if id == "act-4-map-start":
		return {"act": 3, "shards": 6}
	if id == "act-4-map-branch":
		return {"act": 3, "shards": 6, "node": "4,6"}
	return {
		"act": 3, "shards": 6, "node": "14,3",
		"kind": "boss", "enemies": ["eternalKeeper"],
	}


static func _handoff(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = RunState.new_run(content, 22080, "act4-handoff")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": ["eternalKeeper"], "kind": "boss"})
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("act4: Keeper fight did not start")
		return
	var foe: EnemyCombatant = game.cb.enemies[0]
	foe.hp = 4
	foe.block = 0
	game.cb.queue.clear()
	game.rules.hit_enemy(run, game.cb, foe, 999, false)
	if game.cb.finale_handoff != true or game.cb.over != true:
		fails.append("act4: assembled catalogue lost the Keeper handoff")
	for ev: Dictionary in game.cb.queue:
		if ev.get("t") == EventTypes.DIE:
			fails.append("act4: lethal blow emitted DIE")
