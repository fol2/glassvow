extends RefCounted

const SAVE_PATH: String = "user://test_resume_routes_v2.json"


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var default_before: Variant = _file_snapshot(SaveService.RUN_PATH)
	for route: String in ["rest", "event", "shop", "treasure"]:
		_ordinary_roundtrip(content, route, fails)
	for kind: String in ["card", "remove", "duplicate", "upgrade"]:
		_event_pending_roundtrip(content, kind, fails)
	for route: String in ["rest", "event", "shop", "treasure"]:
		_hollow_roundtrip(content, route, route == "event", fails)
	_hollow_priority_roundtrip(content, fails)
	_priority(content, fails)
	_quarantine_cases(content, fails)
	if _file_snapshot(SaveService.RUN_PATH) != default_before:
		fails.append("resume routes: injected route tests touched the default save")
	SaveService.clear(SAVE_PATH)


static func _ordinary_roundtrip(content: ContentDB, route: String,
		fails: Array[String]) -> void:
	var prepared: RunState = _route_run(content, route)
	var producer: Main = _main(content)
	producer._continue_run(prepared)
	if route == "rest":
		producer._store_run()
	if route == "shop":
		producer.game.run.quest_scratch["shopStock"]["cards"][0]["sold"] = true
		producer._store_run()
	var loaded: RunState = SaveService.load_run(content, SAVE_PATH)
	if loaded == null:
		fails.append("resume routes: ordinary %s producer did not store" % route)
		_dispose(producer)
		return
	var expected: Dictionary = _fingerprint(loaded)
	_dispose(producer)
	var resumed: Main = _main(content)
	resumed._continue_run(loaded)
	_assert_screen(resumed, route, "ordinary", fails)
	_assert_same(resumed.game.run, expected, "ordinary %s" % route, fails)
	if route == "shop" and not resumed.game.run.quest_scratch["shopStock"]["cards"][0]["sold"]:
		fails.append("resume routes: sold shop row reopened")
	_dispose(resumed)


static func _event_pending_roundtrip(content: ContentDB, kind: String,
		fails: Array[String]) -> void:
	var event_id: String = {
		"card": "library", "remove": "forgottenShrine",
		"duplicate": "mirror", "upgrade": "forge",
	}[kind]
	var prepared: RunState = _route_run(content, "event")
	prepared.quest_scratch["eventNode"] = event_id
	if kind == "upgrade":
		for card: CardInst in prepared.player.deck:
			card.up = true
	var producer: Main = _main(content)
	producer._continue_run(prepared)
	if kind == "upgrade":
		var ops: Array = content.events[event_id]["choices"][0]["ops"]
		producer.game.run.quest_scratch["eventPending"] = \
			producer.game.rewards.apply_event_ops(producer.game.run, ops)
		producer._store_run()
	else:
		producer._on_event_choice("0", event_id)
	var loaded: RunState = SaveService.load_run(content, SAVE_PATH)
	if loaded == null:
		fails.append("resume routes: eventPending %s producer did not store" % kind)
		_dispose(producer)
		return
	var expected: Dictionary = _fingerprint(loaded)
	_dispose(producer)
	var resumed: Main = _main(content)
	resumed._continue_run(loaded)
	if kind == "upgrade":
		if not resumed._map.is_cleared(3) or resumed.game.run.quest_scratch.has("eventPending"):
			fails.append("resume routes: all-upgraded Forge did not use the empty consumer")
	else:
		_assert_event_overlay(resumed, event_id, kind, fails)
		_assert_same(resumed.game.run, expected, "eventPending %s" % kind, fails)
	_dispose(resumed)


static func _hollow_roundtrip(content: ContentDB, route: String,
		event_pending: bool, fails: Array[String]) -> void:
	var producer: Main = _main(content)
	var run: RunState = _route_run(content, route)
	if route == "event":
		run.quest_scratch["seenEvents"] = content.events.keys().filter(
			func(id: Variant) -> bool: return str(id) != "library")
	producer.game = GlassvowGame.new(content, run)
	producer._map = WorldMap.from_dict(run.map)
	producer.game.run.pending_hollow = {
		"nodeId": producer._map.current().id, "type": route, "meeting": 0,
		"paid": false, "deferred": false, "answer": "",
	}
	producer._stage_hollow_exit()
	if event_pending:
		producer._on_event_choice("0", "library")
	var loaded: RunState = SaveService.load_run(content, SAVE_PATH)
	if loaded == null:
		fails.append("resume routes: Hollow %s producer did not use injected store" % route)
		_dispose(producer)
		return
	var expected: Dictionary = _fingerprint(loaded)
	_dispose(producer)
	var resumed: Main = _main(content)
	resumed._continue_run(loaded)
	_assert_screen(resumed, route, "Hollow", fails)
	if event_pending:
		_assert_event_overlay(resumed, "library", "card", fails)
	_assert_same(resumed.game.run, expected, "Hollow %s" % route, fails)
	_dispose(resumed)


static func _priority(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = _route_run(content, "rest")
	run.pending_run_end = {"outcome": "abandon", "bequestAnswered": true}
	var main: Main = _main(content)
	main._continue_run(run)
	if not main._route_screen is RunEndScreen:
		fails.append("resume routes: run-end lost priority over current route")
	_dispose(main)


static func _hollow_priority_roundtrip(content: ContentDB,
		fails: Array[String]) -> void:
	var producer: Main = _main(content)
	var run: RunState = _route_run(content, "rest")
	run.pending_lamplighter = true
	run.quest_scratch["lamplighterOffer"] = {"boons": [content.boons.keys()[0]]}
	producer.game = GlassvowGame.new(content, run)
	producer._map = WorldMap.from_dict(run.map)
	producer.game.run.pending_hollow = {
		"nodeId": producer._map.current().id, "type": "rest", "meeting": 0,
		"paid": false, "deferred": false, "answer": "",
	}
	producer._stage_hollow_exit()
	var loaded: RunState = SaveService.load_run(content, SAVE_PATH)
	if loaded == null:
		fails.append("resume routes: Hollow priority producer did not store")
		_dispose(producer)
		return
	var expected: Dictionary = _fingerprint(loaded)
	_dispose(producer)
	var resumed: Main = _main(content)
	resumed._continue_run(loaded)
	if not resumed._route_screen is RestScreen or not resumed.game.run.pending_lamplighter:
		fails.append("resume routes: Hollow receipt lost priority over Lamplighter")
	_assert_same(resumed.game.run, expected, "Hollow/Lamplighter coexistence", fails)
	resumed._finish_node()
	if not resumed._route_screen is LamplighterScreen:
		fails.append("resume routes: Lamplighter did not resume after Hollow destination")
	_dispose(resumed)


static func _quarantine_cases(content: ContentDB, fails: Array[String]) -> void:
	for case: Dictionary in [
		{"tag": "receipt nodeId", "route": "rest", "receipt": {"nodeId": "wrong", "type": "rest", "eventId": null}},
		{"tag": "receipt type", "route": "rest", "receipt_type": "shop"},
		{"tag": "receipt eventId", "route": "event", "event": "library", "receipt_event": "forge"},
		{"tag": "event scratch mismatch", "route": "event", "event": "forge", "pending": {"kind": "remove"}},
		{"tag": "null current stale scratch", "route": "rest", "stale": true, "current": "null"},
		{"tag": "cleared current stale scratch", "route": "rest", "stale": true, "current": "cleared"},
		{"tag": "unsupported current stale scratch", "route": "monster", "stale": true},
	]:
		var run: RunState = _route_run(content, str(case["route"]))
		if case.has("event"):
			run.quest_scratch["eventNode"] = case["event"]
		if case.has("pending"):
			run.quest_scratch["eventPending"] = case["pending"]
		if case.get("stale", false):
			run.quest_scratch["shopStock"] = {}
			if case.get("current") == "null":
				var map: WorldMap = WorldMap.from_dict(run.map)
				map.at = -1
				run.map = map.to_dict()
			elif case.get("current") == "cleared":
				var map: WorldMap = WorldMap.from_dict(run.map)
				map.clear_current()
				run.map = map.to_dict()
		if case.has("receipt_type"):
			run.pending_hollow_route = {"nodeId": run.node_id,
				"type": case["receipt_type"], "eventId": null}
		elif case.has("receipt_event"):
			run.pending_hollow_route = {"nodeId": run.node_id,
				"type": "event", "eventId": case["receipt_event"]}
		elif case.has("receipt"):
			run.pending_hollow_route = case["receipt"]
		var before: Dictionary = _fingerprint(run)
		var main: Main = _main(content)
		main._continue_run(run)
		if not main._map_screen is WorldMapScreen or main._route_screen != null:
			fails.append("resume routes: %s was not quarantined to map" % case["tag"])
		_assert_same(main.game.run, before, str(case["tag"]), fails)
		main._on_node_chosen(3)
		_assert_same(main.game.run, before, "%s click" % case["tag"], fails)
		_dispose(main)
	var reset: Main = _main(content)
	reset._continue_run(_route_run(content, "rest"))
	if not reset._route_screen is RestScreen or reset._route_checkpoint_quarantined:
		fails.append("resume routes: a valid continue retained quarantine")
	_dispose(reset)


static func _route_run(content: ContentDB, route: String) -> RunState:
	SaveService.clear(SAVE_PATH)
	var run: RunState = RunState.new_run(content, 145147, "resume-%s" % route)
	var map: WorldMap = WorldMap.slice()
	map.at = 3
	map.nodes[3].type = route
	run.node_id = map.nodes[3].id
	run.map = map.to_dict()
	return run


static func _main(content: ContentDB) -> Main:
	var main: Main = Main.new()
	main.content = content
	main._run_save_path = SAVE_PATH
	main._vigil = VigilState.blank()
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	return main


static func _dispose(main: Main) -> void:
	main._clear_route()
	for child: Node in main.get_children():
		child.free()
	main.free()


static func _assert_screen(main: Main, route: String, lane: String,
		fails: Array[String]) -> void:
	var expected: Script = {
		"rest": RestScreen, "event": EventScreen,
		"shop": ShopScreen, "treasure": TreasureScreen,
	}[route]
	if main._route_screen == null or main._route_screen.get_script() != expected:
		fails.append("resume routes: %s %s did not restore exact screen" % [lane, route])


static func _assert_event_overlay(main: Main, event_id: String, kind: String,
		fails: Array[String]) -> void:
	if not main._route_screen is EventScreen or main._route_screen._event_id != event_id \
			or main._choice_screen == null or not main._choice_screen._overlay:
		fails.append("resume routes: %s eventPending did not restore EventScreen and overlay" % kind)


static func _fingerprint(run: RunState) -> Dictionary:
	return {
		"save": JSON.stringify(run.to_save_dict()), "rng": run.rng_state(),
		"map": JSON.stringify(run.map),
		"scratch": JSON.stringify(run.quest_scratch),
		"pending": JSON.stringify(run.pending_hollow_route),
	}


static func _assert_same(run: RunState, before: Dictionary, tag: String,
		fails: Array[String]) -> void:
	if _fingerprint(run) != before:
		fails.append("resume routes: %s changed save/RNG/map/scratch/pending" % tag)


static func _file_snapshot(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else null
