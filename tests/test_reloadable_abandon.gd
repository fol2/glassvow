extends RefCounted
## Regression for #149: malformed route scratch fails closed and every abandon
## checkpoint is a reloadable, mutually exclusive RunEnd route.

const TEST_RUN_PATH: String = "user://test_reloadable_abandon_v2.json"
const MAIN_PATH: String = "res://application/main.gd"
const RUN_STATE_PATH: String = "res://domain/state/run_state.gd"
const Diff: GDScript = preload("res://tests/support/diff.gd")
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	_reject_malformed_quest_scratch(content, fails)
	_abandon_source_contract(fails)
	_round_trip_abandon_routes(content, fails)


static func _reject_malformed_quest_scratch(
		content: ContentDB, fails: Array[String]) -> void:
	var loader: String = _function_body(
		FileAccess.get_file_as_string(RUN_STATE_PATH), "from_save_dict")
	var guard_at: int = loader.find(
		"if typeof(quest_scratch_v) != TYPE_DICTIONARY:")
	var assignment_at: int = loader.find("rs.quest_scratch = quest_scratch_v")
	if guard_at < 0 or assignment_at < 0 or guard_at > assignment_at:
		fails.append(
			"questScratch guard mutation: TYPE_DICTIONARY guard must precede typed assignment")
		return
	var base: Dictionary = _base_run(content, "malformed-scratch").to_save_dict()
	for case: Dictionary in [
		{"tag": "array", "value": []},
		{"tag": "string", "value": "not-a-dictionary"},
		{"tag": "null", "value": null},
	]:
		var save: Dictionary = base.duplicate(true)
		save["questScratch"] = case["value"]
		if RunState.from_save_dict(save, content) != null:
			fails.append("questScratch %s: malformed type was accepted" % case["tag"])
	var missing: Dictionary = base.duplicate(true)
	missing.erase("questScratch")
	var healed: RunState = RunState.from_save_dict(missing, content)
	if healed == null or healed.quest_scratch != {}:
		fails.append("questScratch missing: additive empty-dictionary heal was lost")


## Named source assertions are the mutation table: deleting any one clear, or
## bypassing the injected writer, produces the corresponding focused failure.
## The seam check runs before integration so a seam mutant never touches the
## production profile path.
static func _abandon_source_contract(fails: Array[String]) -> void:
	var source: String = FileAccess.get_file_as_string(MAIN_PATH)
	var body: String = _function_body(source, "_on_abandon_choice")
	var terminal_at: int = body.find("game.run.pending_run_end =")
	for field: String in [
		"pending_combat", "pending_enemy_ids", "pending_quest_id",
		"pending_reward", "pending_hollow", "pending_hollow_route",
		"pending_pool",
	]:
		var clear_at: int = body.find("game.run.%s = null" % field)
		if clear_at < 0 or terminal_at < 0 or clear_at > terminal_at:
			fails.append("abandon clear mutation: %s was not cleared before run end" % field)
	if not body.contains("if _store_run():"):
		fails.append("abandon persistence mutation: handler bypasses injected run path")
	if not _safe_injected_seam(source):
		fails.append("abandon persistence mutation: injected run path is not failure-safe")


static func _round_trip_abandon_routes(
		content: ContentDB, fails: Array[String]) -> void:
	var source: String = FileAccess.get_file_as_string(MAIN_PATH)
	if not _function_body(source, "_on_abandon_choice").contains("if _store_run():") \
			or not _safe_injected_seam(source):
		return
	var default_existed: bool = FileAccess.file_exists(SaveService.RUN_PATH)
	var default_before: String = FileAccess.get_file_as_string(SaveService.RUN_PATH) \
		if default_existed else ""
	var cases: Array[Dictionary] = [
		{
			"tag": "combat",
			"pending": {
				"pending_combat": "monster",
				"pending_enemy_ids": ["duskfang"],
				"pending_quest_id": "ownShade",
			},
		},
		{
			"tag": "reward",
			"pending": {"pending_reward": {
				"kind": "monster",
				"rewards": {
					"gold": 17, "cards": ["strike"],
					"potion": "healing", "relic": null,
				},
				"taken": {
					"gold": true, "card": false,
					"potion": false, "relic": false,
				},
				"perfect": false,
			}},
		},
		{
			"tag": "Hollow",
			"pending": {"pending_hollow": {
				"nodeId": "0", "type": "event", "meeting": 2,
				"paid": false, "deferred": false, "answer": "",
			}},
		},
		{
			"tag": "Hollow route",
			"pending": {"pending_hollow_route": {
				"nodeId": "0", "type": "rest", "eventId": null,
			}},
		},
	]
	for case: Dictionary in cases:
		_run_abandon_case(content, case, fails)
	_assert_default_untouched(default_existed, default_before, fails)
	SaveService.clear(TEST_RUN_PATH)


static func _run_abandon_case(
		content: ContentDB, case: Dictionary, fails: Array[String]) -> void:
	SaveService.clear(TEST_RUN_PATH)
	var tag: String = str(case["tag"])
	var run_state: RunState = _base_run(content, "abandon-%s" % tag.to_lower().replace(" ", "-"))
	var pending: Dictionary = case["pending"]
	for field: String in pending:
		run_state.set(field, pending[field])
	var preserved: Dictionary = _preserved_projection(run_state)
	var main: Main = _main_for(content, run_state)
	main.set("_run_save_path", TEST_RUN_PATH)
	main._on_abandon_choice("yes")
	var loaded: RunState = SaveService.load_run(content, TEST_RUN_PATH)
	if loaded == null:
		fails.append("abandon %s: stored checkpoint did not reload" % tag)
		main.free()
		return
	if loaded.pending_run_end != {"outcome": "abandon", "bequestAnswered": true}:
		fails.append("abandon %s: run-end contract changed" % tag)
	for field: String in [
		"pending_combat", "pending_enemy_ids", "pending_quest_id",
		"pending_reward", "pending_hollow", "pending_hollow_route",
		"pending_pool",
	]:
		if loaded.get(field) != null:
			fails.append("abandon %s: contradictory %s survived reload" % [tag, field])
	var divergence: String = Diff.deep_eq(
		StateBuild.jsonish(_preserved_projection(loaded)),
		StateBuild.jsonish(preserved))
	if divergence != "":
		fails.append("abandon %s: unrelated state changed at %s" % [tag, divergence])

	var routed: Main = _main_for(content, loaded)
	routed._route_run()
	if not routed._route_screen is RunEndScreen:
		fails.append("abandon %s: reload did not route to RunEndScreen" % tag)
	routed.free()
	main.free()


static func _base_run(content: ContentDB, run_id: String) -> RunState:
	var run_state: RunState = RunState.new_run(content, 149149, run_id)
	var world_map: WorldMap = WorldMap.benchmark(run_state)
	run_state.map = world_map.to_dict()
	run_state.node_id = "0"
	run_state.waystones_lit = 3
	run_state.rng = Rng.new(0x149149)
	run_state.stats["slain"] = 4
	run_state.stats["start"] = 1234567890
	run_state.quest_scratch["eventNode"] = "merchant"
	run_state.monument = {
		"act": 0, "row": 2,
		"bequest": {"kind": "gold", "amount": 25},
		"claimed": false,
	}
	return run_state


static func _preserved_projection(run_state: RunState) -> Dictionary:
	return {
		"runId": run_state.run_id,
		"rngState": run_state.rng_state(),
		"nodeId": run_state.node_id,
		"floorsClimbed": run_state.waystones_lit,
		"player": run_state.to_save_dict()["player"],
		"map": run_state.map,
		"stats": run_state.stats,
		"questScratch": run_state.quest_scratch,
		"monument": run_state.monument,
	}


static func _main_for(content: ContentDB, run_state: RunState) -> Main:
	Locale.active = Locale.new(Locale.CODE_EN)
	var main: Main = Main.new()
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main.content = content
	main.game = GlassvowGame.new(content, run_state)
	main._map = WorldMap.from_dict(run_state.map)
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	return main


static func _assert_default_untouched(
		before_existed: bool, before: String, fails: Array[String]) -> void:
	if FileAccess.file_exists(SaveService.RUN_PATH) != before_existed:
		fails.append("abandon injected path: production save existence changed")
	elif before_existed and FileAccess.get_file_as_string(SaveService.RUN_PATH) != before:
		fails.append("abandon injected path: production save contents changed")


static func _safe_injected_seam(source: String) -> bool:
	return source.contains("var _run_save_path: String = SaveService.RUN_PATH") \
		and _function_body(source, "_store_run").contains(
			"SaveService.store(game.run, _run_save_path)")


static func _function_body(source: String, name: String) -> String:
	var start: int = source.find("func %s(" % name)
	if start < 0:
		return ""
	var finish: int = source.find("\nfunc ", start + 1)
	return source.substr(start) if finish < 0 else source.substr(start, finish - start)
