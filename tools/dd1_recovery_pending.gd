extends SceneTree
## Unchanged-M pending capture: map-selection, encounter-arm, SaveService store.
## Isolated user paths. Does not overwrite the owner's default saves.


const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const RUN_PATH: String = "user://dd1_recovery_pending_run_v2.json"
const VIGIL_PATH: String = "user://dd1_recovery_pending_vigil_v2.json"
const SEED: int = 5420099


func _initialize() -> void:
	var default_run: Variant = _text("user://glassvow_run_v2.json")
	var default_vigil: Variant = _text("user://glassvow_vigil_v2.json")
	Pilot.set_ban(PackedStringArray())
	Pilot.apply_policy({})
	Pilot.set_modes(false, false)
	var content: ContentDB = ContentDB.load_full(false)
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)
	var main: Main = Main.new()
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main.content = content
	main._run_save_path = RUN_PATH
	main._vigil_save_path = VIGIL_PATH
	main._vigil = VigilState.blank()
	main._opening_suppressed = true
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	var run_id: String = "run-%08x-pending" % SEED
	var merged: Dictionary = {"aspect": 0, "vow": 0}
	main.game = GlassvowGame.new(content, RunState.new_run(content, SEED, run_id, merged))
	main.game.quests.prepare_run(main.game.run)
	main._map = WorldMap.benchmark(main.game.run)
	main.game.quests.decorate_map(main.game.run, main._map)
	main.game.run.map = main._map.to_dict()
	if not main._store_run():
		_fail("pending: initial store failed")
		return
	if main._map == null or main.game == null:
		_fail("pending: missing map after new run")
		return
	var reachable: Array[int] = main._map.reachable()
	if reachable.is_empty():
		_fail("pending: no reachable row-0 nodes")
		return
	var pick: int = Pilot.choose_node(main._map, main.game.run)
	if pick < 0 or not reachable.has(pick):
		pick = reachable[0]
	if not main._map.enter(pick):
		_fail("pending: map.enter failed")
		return
	var n: MapNode = main._map.nodes[pick]
	main.game.run.node_id = n.id
	main.game.run.waystones_lit = n.row + 1
	main.game.run.map = main._map.to_dict()
	if not main._store_run():
		_fail("pending: chosen waystone store failed")
		return
	main._arm_encounter(n)
	if typeof(main.game.run.pending_enemy_ids) != TYPE_ARRAY:
		_fail("pending: encounter arm produced no enemies")
		return
	if not main._store_run():
		_fail("pending: armed encounter store failed")
		return
	var raw: Variant = _text(RUN_PATH)
	if typeof(raw) != TYPE_STRING or str(raw).is_empty():
		_fail("pending: SaveService wrote no bytes")
		return
	var parsed: Variant = JSON.parse_string(str(raw))
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("pending: save is not JSON object")
		return
	var save: Dictionary = parsed
	var map_v: Variant = save.get("map", {})
	var nodes: Array = []
	if typeof(map_v) == TYPE_DICTIONARY:
		nodes = map_v.get("nodes", [])
	if nodes.is_empty() or save.get("pendingCombat") == null:
		_fail("pending: empty map or missing pendingCombat")
		return
	var global_path: String = ProjectSettings.globalize_path(RUN_PATH)
	print("DD1_PENDING_OK seed=%d pick=%d nodes=%d pendingCombat=%s pendingEnemyIds=%s runId=%s bytes=%d global=%s sha256=%s" % [
		int(float(str(save.get("seed", -1)))),
		pick,
		nodes.size(),
		str(save.get("pendingCombat", "")),
		str(save.get("pendingEnemyIds", [])),
		str(save.get("runId", "")),
		str(raw).length(),
		global_path,
		str(raw).sha256_text(),
	])
	main._clear_route()
	for child: Node in main.get_children():
		child.free()
	main.free()
	if _text("user://glassvow_run_v2.json") != default_run \
			or _text("user://glassvow_vigil_v2.json") != default_vigil:
		_fail("pending: default owner saves were touched")
		return
	quit(0)


func _text(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return FileAccess.get_file_as_string(path)


func _fail(msg: String) -> void:
	print("DD1_PENDING_FAIL %s" % msg)
	quit(1)
