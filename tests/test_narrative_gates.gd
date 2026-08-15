extends RefCounted
## #270 acceptance: shard gates, durable loss slots, and shipping seams agree.

static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_narrative_gates: %s" % what)


static func _i(value: Variant) -> int:
	return int(float(str(value)))


static func run(fails: Array[String]) -> void:
	_thresholds(fails)
	_losses(fails)
	_dialogue(fails)
	_monument(fails)


static func _thresholds(fails: Array[String]) -> void:
	var cases: Array = [
		[0, 0, true], [1, 0, false], [1, 1, true],
		[2, 3, false], [2, 4, true], [3, 5, false], [3, 6, true],
	]
	for row_v: Variant in cases:
		var row: Array = row_v
		var level: int = _i(row[0])
		var shards: int = _i(row[1])
		_check(fails, NarrativeGates.allows(level, shards) == bool(row[2]),
			"level %d / shards %d" % [level, shards])
	_check(fails, NarrativeGates.loss_pool_index(0, 0) == -1
		and NarrativeGates.loss_pool_index(0, 1) == 0
		and NarrativeGates.loss_pool_index(49, 1) == 49
		and NarrativeGates.loss_pool_index(50, 6) == -1,
		"loss pool seal/order/exhaustion drifted")
	_check(fails, NarrativeGates.death_dialogue_level(&"ownShade1") == 1
		and NarrativeGates.death_dialogue_level(&"ownShade3") == 2,
		"Shade ledger levels drifted")


static func _run(content: ContentDB, vigil: VigilState, id: String) -> RunState:
	var state: RunState = RunState.new_run(content, id.hash() & 0x7FFFFFFF,
		id, {"quests": vigil.quests, "shards": vigil.shards})
	state.act = 1
	state.floors_climbed = 7
	return state


static func _fall(vigil: VigilState) -> Dictionary:
	if typeof(vigil.last_fall) != TYPE_DICTIONARY:
		return {}
	var fall: Dictionary = vigil.last_fall
	return fall


static func _cursor(vigil: VigilState) -> int:
	var quest: Dictionary = vigil.quests["ownShade"]
	var memory: Dictionary = quest["memory"]
	return _i(memory.get("lossPoolCursor", 0))


static func _losses(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var vigil: VigilState = VigilState.blank()
	var l0: RunState = _run(content, vigil, "run-loss-l0")
	_check(fails, vigil.commit_run(l0, "death", content)
		and _fall(vigil).get("standing", false)
		and _i(_fall(vigil).get("lastWords", 99)) == -1
		and _i(_fall(vigil).get("row", -1)) == 6
		and _cursor(vigil) == 0 and vigil.whispers == 0,
		"shard-zero death was not a silent standing monument")

	vigil.shards.append("paleOnes")
	var first: RunState = _run(content, vigil, "run-loss-first")
	_check(fails, vigil.commit_run(first, "death", content)
		and _i(_fall(vigil).get("lastWords", -1)) == 0
		and _cursor(vigil) == 1,
		"first eligible loss did not draw slot zero")
	_check(fails, vigil.commit_run(first, "death", content) and _cursor(vigil) == 1,
		"terminal retry consumed the pool twice")

	var loaded: VigilState = VigilState.from_dict(vigil.to_dict())
	_check(fails, loaded != null and _cursor(loaded) == 1,
		"loss cursor did not survive v2 load")
	if loaded == null:
		return
	var second: RunState = _run(content, loaded, "run-loss-second")
	_check(fails, loaded.commit_run(second, "death", content)
		and _i(_fall(loaded).get("lastWords", -1)) == 1
		and _cursor(loaded) == 2,
		"second loss repeated slot zero")

	loaded.quests["ownShade"]["memory"]["lossPoolCursor"] = 49
	var last: RunState = _run(content, loaded, "run-loss-last")
	_check(fails, loaded.commit_run(last, "death", content)
		and _i(_fall(loaded).get("lastWords", -1)) == 49
		and _cursor(loaded) == 50, "last loss slot was not reachable")
	var exhausted: RunState = _run(content, loaded, "run-loss-exhausted")
	_check(fails, loaded.commit_run(exhausted, "death", content)
		and _i(_fall(loaded).get("lastWords", 99)) == -1
		and _cursor(loaded) == 50, "exhausted pool wrapped or advanced")
	var before: int = loaded.whispers
	_check(fails, loaded.commit_run(_run(content, loaded, "run-win"), "win", content)
		and loaded.whispers == before + 1,
		"win whisper path changed")


static func _speaks(content: ContentDB, variant: String,
		shards: Array, current: Array = []) -> bool:
	var vigil: VigilState = VigilState.blank()
	var progress: int = 2 if variant == "ownShade3" else 0
	vigil.quests["ownShade"] = {
		"state": "armed", "progress": progress, "memory": {},
	}
	var state: RunState = RunState.new_run(content, variant.hash() & 0x7FFFFFFF,
		"run-" + variant, {"quests": vigil.quests, "shards": shards})
	for id_v: Variant in current:
		state.quest_completions.append(str(id_v))
	var game: GlassvowGame = GlassvowGame.new(content, state)
	if not (game.rules is ShardGatedCombatRules):
		return true
	game.apply({"t": "startCombat", "enemies": [variant], "kind": "monster"})
	game.cb.queue.clear()
	var enemy: EnemyCombatant = game.cb.enemies[0]
	game.rules.hit_enemy(state, game.cb, enemy, 999, false)
	for event: Dictionary in game.cb.queue:
		if event.get("t") == EventTypes.VARIANT_DIALOGUE:
			return true
	return false


static func _dialogue(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	_check(fails, not _speaks(content, "ownShade1", [])
		and _speaks(content, "ownShade1", ["paleOnes"]),
		"L1 Shade line crossed the one-shard gate")
	_check(fails, not _speaks(content, "ownShade3", ["paleOnes"])
		and _speaks(content, "ownShade3",
			["paleOnes", "usurper"], ["eighthOmen"]),
		"L2 closer ignored projected current-run shards")


static func _monument(fails: Array[String]) -> void:
	var locale: Locale = Locale.new(Locale.CODE_EN)
	_check(fails, MainStoryGates.monument_title(0, locale).is_empty()
		and MainStoryGates.monument_body({"lastWords": 0}, 0, locale).is_empty(),
		"shard-zero monument rendered narrative copy")
	_check(fails, MainStoryGates.monument_body({"lastWords": -1}, 6, locale).is_empty()
		and MainStoryGates.monument_body({"lastWords": 1}, 1, locale).is_empty(),
		"silent/missing loss slot repeated copy")
	_check(fails, MainStoryGates.monument_body({"lastWords": 0}, 1, locale)
		== locale.t("ui.end.monument.body")
		and MainStoryGates.monument_body(
			{"lastWords": 0, "bequest": {"kind": "gold"}}, 1, locale)
		== locale.t("ui.end.monument.bodyWithBequest"),
		"slot-zero compatibility copy drifted")
	var scene: String = FileAccess.get_file_as_string("res://application/main.tscn")
	_check(fails, scene.contains("main_story_gates.gd"),
		"shipping scene bypasses story gate")
