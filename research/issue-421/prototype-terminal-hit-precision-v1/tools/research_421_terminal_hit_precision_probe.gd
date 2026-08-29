extends SceneTree
## Direct source/interface/null probe for issue #421 terminal-hit precision.

const PRECISION_EVENT: String = "research421TerminalHitPrecision"


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
		content, _int(spec, "seed"), "terminal-hit-%s" % str(spec["id"]), profile)
	run.player.relics.clear()
	var game: GlassvowGame = GlassvowGame.new(content, run)
	var enemies_v: Variant = spec.get("enemies", [])
	if typeof(enemies_v) != TYPE_ARRAY or enemies_v.is_empty():
		return {"id": str(spec["id"]), "error": "enemies must be a non-empty array"}
	var enemy_states: Array = enemies_v
	var enemy_ids: Array[String] = []
	for state_v: Variant in enemy_states:
		if typeof(state_v) != TYPE_DICTIONARY:
			return {"id": str(spec["id"]), "error": "enemy state must be a dictionary"}
		var state: Dictionary = state_v
		enemy_ids.append(str(state.get("id", "rootheart")))
	game.apply({"t": "startCombat", "enemies": enemy_ids, "kind": "normal"})
	_prepare(game, spec, enemy_states)
	for key: String in ["producer", "consumer"]:
		if spec.has(key) and typeof(spec[key]) != TYPE_BOOL:
			return {"id": str(spec["id"]), "error": "%s must be boolean" % key}
	var configured: bool = spec.has("producer") or spec.has("consumer")
	var producer: bool = _bool(spec, "producer")
	var consumer: bool = _bool(spec, "consumer")
	var factor_available: bool = game.rules.has_method(
		"configure_research421_terminal_hit_precision")
	if configured:
		if not factor_available:
			return {"id": str(spec["id"]), "error": "precision interface unavailable"}
		game.rules.call(
			"configure_research421_terminal_hit_precision", producer, consumer)
	var rng_before: int = run.rng_state()
	var mode: String = str(spec.get("mode", "play"))
	var play_returned: Variant = null
	if mode == "play":
		var card: CardInst = CardInst.new(
			run.next_uid(), StringName(str(spec.get("card", "strike"))),
			_bool(spec, "upgraded"))
		game.cb.hand.append(card)
		var action: Dictionary = {"t": "playCard", "uid": card.uid}
		if spec.has("target"):
			action["target"] = spec["target"]
		game.apply(action)
		play_returned = game.last_ret
	elif mode == "direct-hit":
		game.rules.hit_enemy(
			run, game.cb, game.cb.enemies[_int(spec, "target")],
			_int(spec, "damage"), _bool(spec, "isAttack"))
	elif mode == "poison":
		game.cb.enemies[_int(spec, "target")].statuses["poison"] = _int(spec, "poison")
		game.apply({"t": "endTurn"})
	else:
		return {"id": str(spec["id"]), "error": "unknown mode %s" % mode}
	var queue: Array[Dictionary] = game.cb.queue.duplicate(true)
	var baseline_events: Array[Dictionary] = []
	var precision_events: Array[Dictionary] = []
	var ember_events: Array[Dictionary] = []
	var event_index: int = 0
	for event_v: Variant in queue:
		var event: Dictionary = event_v
		if str(event.get("t", "")) == PRECISION_EVENT:
			precision_events.append(event.duplicate(true))
		else:
			baseline_events.append(event.duplicate(true))
		if str(event.get("t", "")) == "ember":
			ember_events.append({
				"event": event_index, "n": _int(event, "n"),
				"total": _int(event, "total"),
			})
		event_index += 1
	var enemies_after: Array[Dictionary] = []
	for enemy: EnemyCombatant in game.cb.enemies:
		enemies_after.append(_enemy_row(enemy))
	return {
		"id": str(spec["id"]), "error": "", "aspect": str(spec.get("aspect", "")),
		"producer": producer, "consumer": consumer,
		"configured": configured, "factorAvailable": factor_available, "mode": mode,
		"playReturned": play_returned, "state": game.cb.to_dict(),
		"enemiesAfter": enemies_after, "queue": queue,
		"baselineEvents": baseline_events, "precisionEvents": precision_events,
		"emberEvents": ember_events, "rngBefore": rng_before,
		"rngAfter": run.rng_state(), "runStats": run.stats.duplicate(true),
		"pendingChipsActive": game.cb.pending_chips_active,
		"pendingChips": game.cb.pending_chips.duplicate(true),
	}


func _prepare(game: GlassvowGame, spec: Dictionary, enemies: Array) -> void:
	game.cb.queue.clear()
	game.cb.hand.clear()
	game.cb.draw.clear()
	game.cb.discard.clear()
	game.cb.exhaust.clear()
	game.cb.embers = _int(spec, "embers")
	game.cb.player.energy = 99
	game.cb.player.block = 0
	game.cb.player.statuses.clear()
	var beacon: int = _int(spec, "beacon")
	if beacon > 0:
		game.cb.player.statuses["beacon"] = beacon
	for i: int in range(enemies.size()):
		var state: Dictionary = enemies[i]
		var enemy: EnemyCombatant = game.cb.enemies[i]
		enemy.max_hp = _int(state, "hp")
		enemy.hp = _int(state, "hp")
		enemy.block = _int(state, "block")
		enemy.chips = _int(state, "chips")
		enemy.facet_max = maxi(1, _int(state, "facetMax"))
		enemy.statuses.clear()


static func _enemy_row(enemy: EnemyCombatant) -> Dictionary:
	return {
		"idx": enemy.idx, "hp": enemy.hp, "block": enemy.block,
		"chips": enemy.chips, "facetMax": enemy.facet_max,
		"staggered": enemy.staggered,
		"statuses": enemy.statuses.duplicate(true),
	}


static func _int(values: Dictionary, key: String) -> int:
	var value: Variant = values.get(key, 0)
	return value if typeof(value) == TYPE_INT else int(float(str(value)))


static func _bool(values: Dictionary, key: String) -> bool:
	var value: Variant = values.get(key, false)
	return value if typeof(value) == TYPE_BOOL else false


func _fail(message: String) -> void:
	push_error("research_421_terminal_hit_precision_probe: %s" % message)
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
