extends RefCounted
## #270: line-table selection, Vigil epitaphs, and the condition-column gate.

const TEST_VIGIL_PATH: String = "user://glassvow_test_line_table_vigil_v2.json"


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_line_table: %s" % what)


static func _i(value: Variant) -> int:
	return int(float(str(value)))


static func run(fails: Array[String]) -> void:
	_selection(fails)
	_thresholds(fails)
	_losses(fails)
	_dialogue(fails)
	_vigil_surface(fails)


static func _rows() -> Array:
	return ContentDB.load_full(false).line_table


static func _ctx(shards: int, act: int = 0) -> Dictionary:
	return {"shards": shards, "act": act, "quests": {}}


static func _selection(fails: Array[String]) -> void:
	var rows: Array = [
		{"id": "g", "slot": "loss", "conditions": {}, "weight": 1,
			"cooldown_runs": 3, "zh": "通", "en": "generic"},
		{"id": "a", "slot": "loss", "conditions": {"act": 1}, "weight": 1,
			"cooldown_runs": 3, "zh": "一", "en": "act-one"},
	]
	var generic: Dictionary = LineTable.select(rows, "loss", _ctx(0, 0), null, {})
	_check(fails, str(generic.get("id")) == "g", "empty conditions are the generic fallback")
	var specific: Dictionary = LineTable.select(rows, "loss", _ctx(0, 1), null, {})
	_check(fails, str(specific.get("id")) == "a", "most-specific-wins lost to the generic row")
	var shard0: Dictionary = LineTable.select(_rows(), "loss", _ctx(0), null, {})
	_check(fails, str(shard0.get("id")).begins_with("loss.generic."),
		"shard-zero loss did not draw a generic epitaph")
	_check(fails, LineTable.ladder_of(shard0) == 0,
		"generic fallback carried an L1+ ladder")
	_check(fails, not LineTable.conditions_match(
			LineTable.row_by_id(_rows(), "loss.standing").get("conditions", {}),
			_ctx(0)),
		"reveal-bearing loss.standing matched below one shard")
	_check(fails, not LineTable.conditions_match(
			LineTable.row_by_id(_rows(), "loss.act1.01").get("conditions", {}),
			_ctx(0, 1)),
		"act-specific loss.act1.01 matched below one shard")
	var open: Dictionary = LineTable.select(_rows(), "loss", _ctx(1), null, {})
	_check(fails, not open.is_empty(), "L1 loss pool went silent")
	_check(fails, LineTable.slot_open(_rows(), "whisper", _ctx(0)) == false
		and LineTable.slot_open(_rows(), "whisper", _ctx(1)),
		"whisper channel is not the conditions column")
	_check(fails, LineTable.slot_open(_rows(), "closer.ownShade", _ctx(1)) == false
		and LineTable.slot_open(_rows(), "closer.ownShade", _ctx(4)),
		"L2 closer opened below four shards")


static func _thresholds(fails: Array[String]) -> void:
	var cases: Array = [
		[0, 0, 1], [1, 0, 0], [1, 1, 1],
		[2, 3, 0], [2, 4, 1], [3, 5, 0], [3, 6, 1],
	]
	for row_v: Variant in cases:
		var row: Array = row_v
		var level: int = _i(row[0])
		var shards: int = _i(row[1])
		var want: bool = _i(row[2]) == 1
		var conditions: Dictionary = {}
		if level == 1:
			conditions["shards_gte"] = LineTable.L1_SHARDS
		elif level == 2:
			conditions["shards_gte"] = LineTable.L2_SHARDS
		elif level == 3:
			conditions["shards_gte"] = LineTable.L3_SHARDS
		_check(fails, LineTable.conditions_match(conditions, _ctx(shards)) == want,
			"level %d / shards %d" % [level, shards])


static func _run(content: ContentDB, vigil: VigilState, id: String) -> RunState:
	var state: RunState = RunState.new_run(content, id.hash() & 0x7FFFFFFF,
		id, {"quests": vigil.quests, "shards": vigil.shards})
	state.act = 1
	state.floors_climbed = 7
	return state


static func _losses(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var sealed: VigilState = VigilState.blank()
	_check(fails, sealed.commit_run(_run(content, sealed, "run-win-l0"), "win", content)
		and sealed.whispers == 0, "shard-zero win exposed an L1 whisper")
	var opened: VigilState = VigilState.blank()
	var opening_win: RunState = _run(content, opened, "run-win-first-shard")
	var opening_quest: Dictionary = opening_win.quests["paleOnes"]
	opening_quest["state"] = "complete"
	_check(fails, opened.commit_run(opening_win, "win", content)
		and opened.shards.has("paleOnes") and opened.whispers == 1,
		"same-run first shard did not open the whisper channel")

	var vigil: VigilState = VigilState.blank()
	var l0: RunState = _run(content, vigil, "run-loss-l0")
	_check(fails, vigil.commit_run(l0, "death", content)
		and vigil.defeat_epitaphs.size() == 1 and vigil.whispers == 0,
		"shard-zero death did not write exactly one epitaph")
	_check(fails, str(vigil.defeat_epitaphs[0]).begins_with("loss.generic."),
		"shard-zero death wrote a non-generic epitaph")

	vigil.shards.append("paleOnes")
	var first: RunState = _run(content, vigil, "run-loss-first")
	_check(fails, vigil.commit_run(first, "death", content)
		and vigil.defeat_epitaphs.size() == 2,
		"first eligible loss did not write an epitaph")
	var first_id: String = vigil.defeat_epitaphs[1]
	_check(fails, vigil.commit_run(first, "death", content)
		and vigil.defeat_epitaphs.size() == 2,
		"terminal retry consumed the pool twice")

	var loaded: VigilState = VigilState.from_dict(vigil.to_dict())
	_check(fails, loaded != null and loaded.defeat_epitaphs == vigil.defeat_epitaphs,
		"epitaph ledger did not survive v2 load")
	if loaded == null:
		return
	var second: RunState = _run(content, loaded, "run-loss-second")
	_check(fails, loaded.commit_run(second, "death", content)
		and loaded.defeat_epitaphs.size() == 3
		and loaded.defeat_epitaphs[2] != first_id,
		"second loss repeated the first line inside cooldown")

	var raw: Dictionary = VigilState.blank().to_dict()
	raw.erase("defeatEpitaphs")
	raw.erase("lineRecent")
	raw.erase("lineOnce")
	var old: VigilState = VigilState.from_dict(raw)
	_check(fails, old != null and old.defeat_epitaphs.is_empty(),
		"a v2 vigil without defeatEpitaphs did not default")

	SaveService.clear_vigil(TEST_VIGIL_PATH)
	_check(fails, SaveService.store_vigil(loaded, TEST_VIGIL_PATH), "epitaph store failed")
	var disk: VigilState = SaveService.load_vigil(TEST_VIGIL_PATH)
	_check(fails, disk.defeat_epitaphs.size() == 3, "epitaphs did not round-trip through SaveService")
	SaveService.clear_vigil(TEST_VIGIL_PATH)

	var exhaust: VigilState = VigilState.blank()
	exhaust.shards.append("paleOnes")
	var seen: Dictionary = {}
	var last: String = ""
	for n: int in range(8):
		var loss: RunState = _run(content, exhaust, "run-loss-ex-%d" % n)
		_check(fails, exhaust.commit_run(loss, "death", content), "exhaust death %d rejected" % n)
		_check(fails, exhaust.defeat_epitaphs.size() == n + 1, "exhaust death %d silent" % n)
		var id: String = exhaust.defeat_epitaphs[n]
		if n > 0:
			_check(fails, id != last, "exhaust recycled the same line consecutively")
		seen[id] = true
		last = id
	_check(fails, seen.size() >= 2, "loss pool never recycled across distinct lines")


static func _speaks(content: ContentDB, variant: String, shards: Array,
		current: Array = []) -> bool:
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
	game.apply({"t": "startCombat", "enemies": [variant], "kind": "monster"})
	game.cb.queue.clear()
	var enemy: EnemyCombatant = game.cb.enemies[0]
	game.rules.hit_enemy(state, game.cb, enemy, 999, false)
	for event: Dictionary in game.cb.queue:
		if event.get("t") == EventTypes.VARIANT_DIALOGUE:
			return true
	return false


static func _dialogue(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	_check(fails, not _speaks(content, "ownShade1", [])
		and _speaks(content, "ownShade1", ["paleOnes"]),
		"L1 Shade line crossed the one-shard gate")
	_check(fails, not LineTable.slot_open(content.line_table, "closer.ownShade",
			_ctx(1)),
		"L2 closer opened below four shards")
	_check(fails, _speaks(content, "ownShade3", ["paleOnes"]),
		"ownShade3 L1 death line stayed sealed at one shard")
	_check(fails, _speaks(content, "ownShade3",
			["paleOnes", "usurper"], ["eighthOmen"]),
		"projected current-run shards did not open an L1 Shade death line")
	var projected: RunState = RunState.new_run(content, 7, "run-proj", {
		"shards": ["paleOnes", "usurper", "eighthOmen"],
	})
	projected.quests["ownShade"] = {"state": "armed", "progress": 2, "memory": {}}
	_check(fails, LineTable.projected_shard_count(projected, &"ownShade3") >= 4,
		"ownShade3 kill does not project the fourth pane")
	_check(fails, LineTable.slot_open(content.line_table, "closer.ownShade",
			LineTable.context(projected,
				LineTable.projected_shard_count(projected, &"ownShade3"))),
		"projected fourth pane did not open the L2 closer")


static func _vigil_surface(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var vigil: VigilState = VigilState.blank()
	vigil.defeat_epitaphs.append("loss.generic.01")
	var screen: VigilScreen = VigilScreen.new(vigil, content)
	_check(fails, screen._epitaph_tab != null and screen._epitaph_list != null,
		"Vigil hid a non-empty epitaph ledger")
	screen._show_epitaphs()
	_check(fails, screen._epitaph_list.visible and not screen._deed_list.visible,
		"epitaph tab did not reveal the ledger")
	screen.free()
	var empty: VigilScreen = VigilScreen.new(VigilState.blank(), content)
	_check(fails, empty._epitaph_tab == null,
		"empty ledger still grew an epitaph tab")
	empty.free()
