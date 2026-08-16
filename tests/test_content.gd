extends RefCounted
## ContentDB loads the slice projection, exposes every manifest id, and confirms
## every slice enemy has an AI handler (validate). Cross-checks slice-content.json
## against slice-manifest.json so a divergence between the two fixtures is caught.


static func run(fails: Array[String]) -> void:
	var db: ContentDB = ContentDB.load_slice()
	if db.id != "slice-v1":
		fails.append("ContentDB: id expected slice-v1 got %s" % db.id)

	var raw: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://port_fixtures/content/slice-manifest.json")
	)
	if typeof(raw) != TYPE_DICTIONARY:
		fails.append("slice-manifest.json: parse failed")
		return
	var manifest: Dictionary = raw

	var man_cards: Array = manifest["cards"]
	for cv: Variant in man_cards:
		var cid: String = cv
		if db.card(StringName(cid)).is_empty():
			fails.append("ContentDB: manifest card %s missing from slice-content" % cid)

	var man_enemies: Dictionary = manifest["enemies"]
	var enemy_list: Array = []
	var normals: Array = man_enemies["normals"]
	var elite: Array = man_enemies["elite"]
	enemy_list.append_array(normals)
	enemy_list.append_array(elite)
	for ev: Variant in enemy_list:
		var eid: String = ev
		if db.enemy(StringName(eid)).is_empty():
			fails.append("ContentDB: manifest enemy %s missing from slice-content" % eid)

	var man_potions: Array = manifest["potions"]
	for pv: Variant in man_potions:
		var pid: String = pv
		if db.potion(StringName(pid)).is_empty():
			fails.append("ContentDB: manifest potion %s missing from slice-content" % pid)

	# Every enemy the content ships must have an AI handler.
	db.validate(fails)

	# One full-registry completeness gate; individual cards do not get their own
	# catalogue tests.
	var full: ContentDB = ContentDB.load_full()
	var full_counts: Array[int] = [full.cards.size(), full.enemies.size(),
		full.relics.size(), full.quest_ids.size()]
	if full_counts != [61, 27, 31, 6]:
		fails.append("ContentDB: full catalogue counts diverged from port baseline")
	if full.reveal_ids.size() != 8 or full.aspects.size() != 2 or full.vows.size() != 5:
		fails.append("ContentDB: full progression registries are incomplete")
	full.validate(fails)
	_validate_requires_ai(fails)
	_emberheart_heal(full, 3, "full content", fails)
	_emberheart_heal(db, 6, "fixture fallback", fails)
	_enemy_overrides(fails)
	var pickup_run: RunState = RunState.new_run(full, 5, "run-relic-pickup")
	var rewards: RewardRules = RewardRules.new(full)
	var act_four: RunState = RunState.new_run(full, 4, "act-four-reward")
	act_four.act = 3
	var act_four_reward: Dictionary = rewards.gen_combat_rewards(act_four, "normal")
	var last_gold: Array = full.reward_gold[full.reward_gold.size() - 1]["normal"]
	var paid_gold: int = int(float(str(act_four_reward["gold"])))
	if paid_gold < int(float(str(last_gold[0]))) or paid_gold > int(float(str(last_gold[1]))):
		fails.append("ContentDB: act 4 reward gold did not clamp to the final authored row")
	rewards.gain_relic(pickup_run, "sweetRoot")
	rewards.gain_relic(pickup_run, "hollowCrown")
	if pickup_run.player.max_hp != 70 or pickup_run.player.hp != 70 \
			or pickup_run.player.energy_max != 4:
		fails.append("ContentDB: instant relic pickup laws are not applied")
	pickup_run.unlocks = ["card:quakeblow", "relic:smolderingCoal"]
	if not rewards.card_pool(pickup_run, "uncommon").has("quakeblow") \
			or not rewards.relic_pool(pickup_run, "uncommon").has("smolderingCoal"):
		fails.append("ContentDB: deed unlocks do not extend reward pools")
	_rising_litany_pools(full, fails)


static func _emberheart_heal(
	content: ContentDB, expected: int, label: String, fails: Array[String]
) -> void:
	var run_state: RunState = RunState.new_run(content, 11, "emberheart-%s" % label)
	run_state.player.hp = 20
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
	game.rules.hit_enemy(run_state, game.cb, game.cb.enemies[0], 999, false)
	if run_state.player.hp != 20 + expected:
		fails.append("Emberheart: %s expected heal %d got %d" % [
			label, expected, run_state.player.hp - 20,
		])


static func _enemy_overrides(fails: Array[String]) -> void:
	var baseline: ContentDB = ContentDB.load_full(false)
	var duskfang: Dictionary = baseline.enemy(&"duskfang").duplicate(true)
	duskfang["hp"] = [31, 35]
	if not baseline.apply_enemy_overrides({"duskfang": duskfang}).is_empty() \
			or baseline.enemy(&"duskfang").get("hp") != [31, 35]:
		fails.append("ContentDB: valid mob override did not apply")

	var untouched: ContentDB = ContentDB.load_full(false)
	var broken: Dictionary = untouched.enemy(&"duskfang").duplicate(true)
	var broken_moves: Dictionary = broken["moves"]
	broken_moves.erase("bite")
	var before: Dictionary = untouched.enemy(&"duskfang").duplicate(true)
	if untouched.apply_enemy_overrides({"duskfang": broken, "notAMob": duskfang}).is_empty():
		fails.append("ContentDB: invalid mob override file was accepted")
	if untouched.enemy(&"duskfang") != before:
		fails.append("ContentDB: invalid mob override file applied partially")
	var bad_kind: Dictionary = untouched.enemy(&"duskfang").duplicate(true)
	bad_kind["art"]["kind"] = "slmie"
	if untouched.enemy_faults("duskfang", bad_kind).is_empty():
		fails.append("ContentDB: unknown mob art kind was accepted")


## Every enemy the catalogue ships has an AI handler, so `validate` above can
## never demonstrate that the check fires. Inject one that has none — into a
## private catalogue, because a ghost enemy left in the shared `full` would
## reach every assertion after this one.
static func _validate_requires_ai(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	content.enemies["noAiGhost"] = {
		"hp": [8, 8],
		"name": "No AI Ghost",
		"art": {"kind": "wisp", "hue": 0.0, "size": 1.0},
		"moves": {"wail": {"intent": "attack", "dmg": 1, "name": "Wail"}},
	}
	var faults: Array[String] = []
	content.validate(faults)
	var found: bool = false
	for msg: String in faults:
		if msg.contains("noAiGhost") and msg.contains("no AI handler"):
			found = true
			break
	if not found:
		fails.append("ContentDB: validate did not catch enemy without AI handler")


static func _rising_litany_pools(full: ContentDB, fails: Array[String]) -> void:
	if not full.cards.has("risingLitany"):
		fails.append("ContentDB: risingLitany missing from cards")
	if full.cards.has("ascension"):
		fails.append("ContentDB: retired ascension id still present")
	var rare_v: Variant = full.card_pools.get("rare", [])
	if typeof(rare_v) != TYPE_ARRAY:
		fails.append("ContentDB: cardPools.rare is not an array")
	else:
		var rare: Array = rare_v
		if not rare.has("risingLitany"):
			fails.append("ContentDB: risingLitany missing from cardPools.rare")
	if str(full.pool_gate_cards.get("risingLitany", "")) != "poolFull":
		fails.append("ContentDB: risingLitany missing from poolGate.cards")
	var waves_v: Variant = full.progression.get("poolWaves", {})
	if typeof(waves_v) != TYPE_DICTIONARY:
		fails.append("ContentDB: progression.poolWaves is not a dictionary")
		return
	var waves: Dictionary = waves_v
	var pool_full_v: Variant = waves.get("poolFull", {})
	if typeof(pool_full_v) != TYPE_DICTIONARY:
		fails.append("ContentDB: poolWaves.poolFull is not a dictionary")
		return
	var pool_full: Dictionary = pool_full_v
	var wave_cards_v: Variant = pool_full.get("cards", [])
	if typeof(wave_cards_v) != TYPE_ARRAY:
		fails.append("ContentDB: poolWaves.poolFull.cards is not an array")
		return
	var wave_cards: Array = wave_cards_v
	if not wave_cards.has("risingLitany"):
		fails.append("ContentDB: risingLitany missing from poolWaves.poolFull.cards")
	var run: RunState = RunState.new_run(full, 13, "run-rising-litany")
	run.reveals.append("poolFull")
	if not RewardRules.new(full).card_pool(run, "rare").has("risingLitany"):
		fails.append("ContentDB: risingLitany not reachable in rare once poolFull is revealed")
	if not FileAccess.file_exists("res://assets/art/cards/risingLitany.jpg"):
		fails.append("ContentDB: risingLitany art file missing")
	var eighth_v: Variant = full.quests.get("eighthOmen", {})
	if typeof(eighth_v) != TYPE_DICTIONARY:
		fails.append("ContentDB: eighthOmen is not a dictionary")
		return
	var eighth: Dictionary = eighth_v
	if not eighth.has("waystoneEchoes"):
		fails.append("ContentDB: eighthOmen.waystoneEchoes missing")
	if eighth.has("floorEchoes"):
		fails.append("ContentDB: retired floorEchoes key still present")

