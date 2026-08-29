extends SceneTree
## Direct source, null-path and mediator probe for issue #421 Ember overflow.

const OVERFLOW_EVENT: String = "research421EmberOverflow"


func _initialize() -> void:
	var opts: Dictionary = _options(OS.get_cmdline_user_args())
	if opts.has("error"):
		_fail(str(opts["error"]))
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(opts["plan"])))
	if typeof(raw) != TYPE_DICTIONARY:
		_fail("plan must be a dictionary")
		return
	var plan: Dictionary = raw
	var content: ContentDB = ContentDB.load_from(str(plan.get("content", "")), false)
	if content == null:
		_fail("content did not load")
		return
	var rows_v: Variant = plan.get("rows", [])
	if typeof(rows_v) != TYPE_ARRAY:
		_fail("rows must be an array")
		return
	var rows: Array[Dictionary] = []
	for spec_v: Variant in rows_v:
		if typeof(spec_v) != TYPE_DICTIONARY:
			_fail("every row must be a dictionary")
			return
		var spec: Dictionary = spec_v
		rows.append(_run_row(content, spec))
	var output: Dictionary = {
		"schemaVersion": 1,
		"planSha256": FileAccess.get_sha256(str(opts["plan"])),
		"probeSha256": FileAccess.get_sha256(str(get_script().resource_path)),
		"rows": rows,
	}
	var file: FileAccess = FileAccess.open(str(opts["out"]), FileAccess.WRITE)
	if file == null:
		_fail("cannot write output")
		return
	file.store_string(JSON.stringify(output) + "\n")
	print(JSON.stringify({"status": "PASS", "rows": rows.size()}))
	quit(0)


func _run_row(content: ContentDB, spec: Dictionary) -> Dictionary:
	var aspect: int = 1 if str(spec.get("aspect", "duskblade")) == "ashwarden" else 0
	var profile: Dictionary = {
		"aspect": aspect, "vow": 0, "reveals": content.reveal_ids.duplicate(),
		"unlocks": ["aspect2"], "quests": {}, "shards": [], "lamplighter": false,
	}
	var run: RunState = RunState.new_run(
		content, _int(spec, "seed"), "ember-overflow-%s" % str(spec["id"]), profile)
	run.player.relics.clear()
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": ["shade"], "kind": "normal"})
	_prepare(game, spec)
	for key: String in ["producer", "consumer"]:
		if spec.has(key) and typeof(spec[key]) != TYPE_BOOL:
			return {"id": str(spec["id"]), "error": "%s must be boolean" % key}
	var configured: bool = spec.has("producer") or spec.has("consumer")
	var producer: bool = _bool(spec, "producer")
	var consumer: bool = _bool(spec, "consumer")
	var factor_available: bool = game.rules.has_method(
		"configure_research421_ember_overflow")
	if configured:
		if not factor_available:
			return {"id": str(spec["id"]), "error": "overflow interface unavailable"}
		game.rules.call("configure_research421_ember_overflow", producer, consumer)
	var rng_before: int = run.rng_state()
	var actions: Array[Dictionary] = []
	var action_specs_v: Variant = spec.get("actions", [])
	if typeof(action_specs_v) != TYPE_ARRAY:
		return {"id": str(spec["id"]), "error": "actions must be an array"}
	var action_specs: Array = action_specs_v
	for action_v: Variant in action_specs:
		if typeof(action_v) != TYPE_DICTIONARY:
			return {"id": str(spec["id"]), "error": "action must be a dictionary"}
		var action: Dictionary = action_v
		var result: Dictionary = _apply_action(game, run, action, factor_available)
		if result.has("error"):
			return {"id": str(spec["id"]), "error": str(result["error"])}
		actions.append(result)
	var queue: Array[Dictionary] = game.cb.queue.duplicate(true)
	var baseline_events: Array[Dictionary] = []
	var overflow_events: Array[Dictionary] = []
	for event_v: Variant in queue:
		var event: Dictionary = event_v
		if str(event.get("t", "")) == OVERFLOW_EVENT:
			overflow_events.append(event.duplicate(true))
		else:
			baseline_events.append(event.duplicate(true))
	return {
		"id": str(spec["id"]), "error": "", "aspect": str(spec.get("aspect", "")),
		"producer": producer, "consumer": consumer, "configured": configured,
		"factorAvailable": factor_available, "actions": actions,
		"state": game.cb.to_dict(), "researchMark": _mark(game, factor_available),
		"queue": queue, "baselineEvents": baseline_events,
		"overflowEvents": overflow_events, "rngBefore": rng_before,
		"rngAfter": run.rng_state(), "runStats": run.stats.duplicate(true),
	}


func _apply_action(
	game: GlassvowGame, run: RunState, action: Dictionary, factor_available: bool
) -> Dictionary:
	var kind: String = str(action.get("kind", ""))
	if kind == "gain":
		var requested: int = _int(action, "n")
		var realised: int = game.rules.gain_embers(run, game.cb, requested)
		return {
			"kind": kind, "requested": requested, "realised": realised,
			"embersAfter": game.cb.embers, "markAfter": _mark(game, factor_available),
		}
	if kind == "play":
		var card_id: StringName = StringName(str(action.get("card", "heavyBlow")))
		var card: CardInst = CardInst.new(run.next_uid(), card_id, _bool(action, "up"))
		var target: Variant = action.get("target")
		var preview: Variant = game.rules.preview_play(game.cb, card, target, run)
		game.cb.hand.append(card)
		game.apply({"t": "playCard", "uid": card.uid, "target": target})
		return {
			"kind": kind, "card": String(card_id), "up": card.up,
			"preview": preview, "returned": game.last_ret,
			"markAfter": _mark(game, factor_available),
		}
	if kind == "end":
		game.apply({"t": "endTurn"})
		return {
			"kind": kind, "turnAfter": game.cb.turn,
			"markAfter": _mark(game, factor_available),
		}
	if kind == "lose":
		game.rules.lose_combat(run, game.cb)
		return {
			"kind": kind, "result": game.cb.result,
			"markAfter": _mark(game, factor_available),
		}
	return {"error": "unknown action %s" % kind}


func _prepare(game: GlassvowGame, spec: Dictionary) -> void:
	game.cb.queue.clear()
	game.cb.hand.clear()
	game.cb.draw.clear()
	game.cb.discard.clear()
	game.cb.exhaust.clear()
	game.cb.ember_cap = _int(spec, "emberCap")
	game.cb.embers = _int(spec, "embers")
	game.cb.player.max_hp = 100
	game.cb.player.hp = 100
	game.cb.player.energy = 99
	game.cb.player.block = 0
	game.cb.player.statuses.clear()
	var enemy: EnemyCombatant = game.cb.enemies[0]
	enemy.max_hp = _int(spec, "enemyHp")
	enemy.hp = enemy.max_hp
	enemy.block = _int(spec, "enemyBlock")
	enemy.chips = 0
	enemy.facet_max = 99
	enemy.statuses.clear()


static func _mark(game: GlassvowGame, factor_available: bool) -> int:
	if not factor_available:
		return 0
	var value: Variant = game.cb.player.get("research421_ember_overflow")
	return value if typeof(value) == TYPE_INT else 0


static func _int(values: Dictionary, key: String) -> int:
	var value: Variant = values.get(key, 0)
	return value if typeof(value) == TYPE_INT else int(float(str(value)))


static func _bool(values: Dictionary, key: String) -> bool:
	var value: Variant = values.get(key, false)
	return value if typeof(value) == TYPE_BOOL else false


func _fail(message: String) -> void:
	push_error("research_421_ember_overflow_probe: %s" % message)
	quit(2)


static func _options(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {"plan": "", "out": ""}
	for arg: String in args:
		if not arg.begins_with("--") or not arg.contains("="):
			return {"error": "expected --name=value"}
		var key: String = arg.get_slice("=", 0).trim_prefix("--")
		if not out.has(key):
			return {"error": "unknown option --%s" % key}
		out[key] = arg.substr(arg.find("=") + 1)
	if str(out["plan"]).is_empty() or str(out["out"]).is_empty():
		return {"error": "--plan and --out are required"}
	return out
