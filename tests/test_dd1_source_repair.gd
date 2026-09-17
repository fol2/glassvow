extends RefCounted
## UNEXECUTED in source batch 5721191528. Constructed runtime controls only;
## forced combat results here are never ordinary-profile/N0 evidence.
const Route: GDScript = preload("res://tests/support/dd1_native_main_route.gd")
const Unit: GDScript = preload("res://tests/support/dd1_unit_grant.gd")
const Journal: GDScript = preload("res://tests/support/dd1_route_journal.gd")
static var native_starts: int = 0


static func run(fails: Array[String]) -> void:
	native_starts = 0
	# No fixture-local reset, fabricated grant or bypass of the process bound.
	if Unit.remaining() < 2:
		fails.append("dd1-source: focused runtime fixture needs an enclosing two-combat reservation")
		return
	var content: ContentDB = ContentDB.load_full(false)
	var run_path: String = "user://dd1_source_identity_run_v2.json"
	var vigil_path: String = "user://dd1_source_identity_vigil_v2.json"
	if FileAccess.file_exists(run_path) or FileAccess.file_exists(vigil_path):
		fails.append("dd1-source: isolated fixture outputs already exist; retained")
		return
	var main: Variant = Route.make_main(content, run_path, vigil_path)
	main.contained_limit = 2
	main._forced_seed = 5420099
	main._new_run({"aspect": 0, "vow": 0})
	if main.game == null or main._map == null or not main.capture.errors.is_empty():
		fails.append("dd1-source: native fixture initial route/save failed")
		Route.dispose(main)
		return
	if not _enter(main, "monster") or main.game.cb == null:
		fails.append("dd1-source: first real combat creation failed")
		Route.dispose(main)
		return
	var first: CombatState = main.game.cb
	first.over = true  # SYNTHETIC dispatch fixture, not an earned victory.
	first.result = "win"
	_check(fails, main.dispatch_once(), "initial completed object dispatches")
	_check(fails, not main.dispatch_once(), "pending reward cannot redispatch")
	main._on_reward_finished()
	_check(fails, main.game.run.pending_reward == null, "real reward completion")
	for kind: String in ["rest", "shop", "treasure"]:
		if not _enter(main, kind):
			fails.append("dd1-source: synthetic safe-node entry failed: " + kind)
			break
		var rng: int = main.game.run.rng.get_state()
		_check(fails, main.game.cb == first, "safe screen retains old object: " + kind)
		_check(fails, not main.dispatch_once(), "after-reward stale result denied: " + kind)
		_check(fails, main.game.run.rng.get_state() == rng and main.game.run.pending_reward == null,
			"no duplicate reward/RNG advancement: " + kind)
		_check(fails, main.contained_starts == 1 and main.combat_dispatches == 1,
			"safe node does not count as start or reset dispatch: " + kind)
		if kind == "rest":
			main._on_rest_choice("heal")
		elif kind == "shop":
			main._on_shop_choice("leave")
		else:
			main._finish_node()
	# Synthetic act/boss transition checks both components of encounter identity.
	main.game.run.act = main.game.run.final_act()
	if _enter(main, "boss") and main.game.cb != null:
		_check(fails, main.game.cb != first and main.contained_starts == 2,
			"next actual creation gets a new identity and one debit")
		main.game.cb.over = true
		main.game.cb.result = "win"  # Still a constructed terminal fixture.
		_check(fails, main.dispatch_once(), "new boss object dispatches once")
		_check(fails, not main.dispatch_once(), "boss repeat denied")
		_check(fails, main.game.run.pending_run_end != null, "native final-boss terminal staged")
		main._on_terminal_commit("commit")
		_check(fails, FileAccess.file_exists(run_path), "native win still owes Dawn save")
		_check(fails, main.complete_terminal(), "real Dawn advance/finish and durable clear")
		_check(fails, not FileAccess.file_exists(run_path), "terminal run actually cleared")
		_check(fails, main.terminal.get("receipt", {}).get("outcome") == "win",
			"native terminal receipt retained with preterminal bytes")
	else:
		fails.append("dd1-source: next genuine combat creation failed")
	native_starts = main.contained_starts
	_check(fails, main.capture.errors.is_empty(), "complete native observation: " + str(main.capture.errors))
	Route.dispose(main)
	# Preserve failed evidence; clean only this explicitly isolated fixture on success.
	if fails.is_empty():
		SaveService.clear(run_path)
		SaveService.clear_vigil(vigil_path)
	_capture_failure_controls(fails, content)


static func _enter(main: Variant, kind: String) -> bool:
	var reachable: Array[int] = main._map.reachable()
	if reachable.is_empty():
		return false
	var index: int = reachable[0]
	main._map.nodes[index].type = kind  # Declared synthetic topology, never ordinary input.
	if not main._map.enter(index):
		return false
	main._on_node_chosen(index)
	return main.capture.errors.is_empty()


static func _capture_failure_controls(fails: Array[String], content: ContentDB) -> void:
	var journal: Variant = Journal.new()
	journal.max_bytes = 1
	_check(fails, journal.begin("apply", {"t": "endTurn"}) == -1,
		"failed begin write cannot authorize a command")
	_check(fails, not journal.errors.is_empty(), "journal failure is sticky")
	var blocker: String = "user://dd1_source_file_not_directory"
	if not Route._write_new_bytes(blocker, "SYNTHETIC isolated ENOTDIR fixture"):
		fails.append("dd1-source: save-failure fixture path is not new")
		return
	var path: String = blocker.path_join("run.json")
	var main: Variant = Route.make_main(content, path, blocker.path_join("vigil.json"))
	main._forced_seed = 5420099
	main._new_run({"aspect": 0, "vow": 0})
	_check(fails, not main.capture.errors.is_empty(), "native save failure marks INCOMPLETE")
	var used: int = Unit._used
	if main.game != null:
		var events: Array[Dictionary] = main.game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
		_check(fails, events.is_empty() and Unit._used == used, "sticky capture failure prevents another start")
	Route.dispose(main)
	SaveService.clear(blocker)


static func _check(fails: Array[String], ok: bool, detail: String) -> void:
	if not ok:
		fails.append("dd1-source: " + detail)
