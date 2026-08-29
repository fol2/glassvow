extends SceneTree
## Engine-correct direct mediator probe for issue #421 Ward spend v2.

const RESEARCH_EVENT: String = "research421WardSpend"


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
		rows.append(_run_row(content, plan, spec))
	var output: Dictionary = {
		"schemaVersion": 2,
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


func _run_row(content: ContentDB, plan: Dictionary, spec: Dictionary) -> Dictionary:
	var aspect: int = 1 if str(spec.get("aspect", "duskblade")) == "ashwarden" else 0
	var profile: Dictionary = {
		"aspect": aspect, "vow": 0, "reveals": [], "unlocks": [],
		"quests": {}, "shards": [], "lamplighter": false,
	}
	var run: RunState = RunState.new_run(
		content, _int(spec, "seed"), "ward-spend-v2-%s" % str(spec["id"]), profile)
	run.player.relics.clear()
	var omen: String = str(spec.get("omen", ""))
	run.omens[run.act] = null if omen.is_empty() else omen
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": ["shade"], "kind": "normal"})
	_prepare(game, spec)
	var factor_available: bool = game.rules.has_method("configure_research421_ward_spend")
	var configured: bool = plan.has("configuration")
	if configured:
		if not factor_available:
			return {"id": str(spec["id"]), "error": "Ward-spend interface unavailable"}
		var config_v: Variant = plan.get("configuration")
		if typeof(config_v) != TYPE_DICTIONARY:
			return {"id": str(spec["id"]), "error": "configuration must be a dictionary"}
		var config: Dictionary = config_v
		game.rules.call(
			"configure_research421_ward_spend",
			StringName(str(config.get("producer", ""))),
			_bool(config, "consumer"), _int(config, "spend"), _int(config, "numerator"))
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
		var result: Dictionary = _apply_action(game, run, action)
		if result.has("error"):
			return {"id": str(spec["id"]), "error": str(result["error"])}
		actions.append(result)
	var queue: Array[Dictionary] = game.cb.queue.duplicate(true)
	var ordinary_events: Array[Dictionary] = []
	var research_events: Array[Dictionary] = []
	for event_v: Variant in queue:
		var event: Dictionary = event_v
		if str(event.get("t", "")) == RESEARCH_EVENT:
			research_events.append(event.duplicate(true))
		else:
			ordinary_events.append(event.duplicate(true))
	return {
		"id": str(spec["id"]), "error": "", "configured": configured,
		"factorAvailable": factor_available, "omen": omen,
		"actions": actions, "state": game.cb.to_dict(),
		"mark": _mark(game, factor_available), "queue": queue,
		"ordinaryEvents": ordinary_events, "researchEvents": research_events,
		"rngBefore": rng_before, "rngAfter": run.rng_state(),
		"runStats": run.stats.duplicate(true),
	}


func _apply_action(game: GlassvowGame, run: RunState, action: Dictionary) -> Dictionary:
	var kind: String = str(action.get("kind", ""))
	if kind == "play":
		var card_id: StringName = StringName(str(action.get("card", "")))
		var card: CardInst = CardInst.new(run.next_uid(), card_id, _bool(action, "up"))
		var target: Variant = action.get("target")
		var preview: Variant = game.rules.preview_play(game.cb, card, target, run)
		game.cb.hand.append(card)
		var command: Dictionary = {"t": "playCard", "uid": card.uid}
		if action.has("target"):
			command["target"] = target
		game.apply(command)
		return {
			"kind": kind, "card": String(card_id), "up": card.up,
			"target": target, "preview": preview, "returned": game.last_ret,
		}
	if kind == "setWard":
		game.cb.player.block = _int(action, "n")
		return {"kind": kind, "n": game.cb.player.block}
	if kind == "end":
		game.apply({"t": "endTurn"})
		return {"kind": kind, "turnAfter": game.cb.turn}
	if kind == "lose":
		game.rules.lose_combat(run, game.cb)
		return {"kind": kind, "result": game.cb.result}
	if kind == "hit":
		var realised: int = game.rules.hit_enemy(
			run, game.cb, game.cb.enemies[0], _int(action, "n"), false)
		return {"kind": kind, "requested": _int(action, "n"), "realised": realised}
	return {"error": "unknown action %s" % kind}


func _prepare(game: GlassvowGame, spec: Dictionary) -> void:
	game.cb.queue.clear()
	game.cb.hand.clear()
	game.cb.draw.clear()
	game.cb.discard.clear()
	game.cb.exhaust.clear()
	game.cb.player.max_hp = 100
	game.cb.player.hp = 100
	game.cb.player.energy = 99
	game.cb.player.block = _int(spec, "playerWard")
	game.cb.player.statuses.clear()
	var statuses_v: Variant = spec.get("playerStatuses", {})
	if typeof(statuses_v) == TYPE_DICTIONARY:
		game.cb.player.statuses = statuses_v.duplicate(true)
	var enemy: EnemyCombatant = game.cb.enemies[0]
	enemy.max_hp = _int(spec, "enemyHp")
	enemy.hp = enemy.max_hp
	enemy.block = _int(spec, "enemyWard")
	enemy.chips = 0
	enemy.facet_max = 99
	enemy.statuses.clear()


static func _mark(game: GlassvowGame, factor_available: bool) -> Dictionary:
	if not factor_available:
		return {}
	var value: Variant = game.cb.player.get("research421_ward_spend")
	return value.duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _int(values: Dictionary, key: String) -> int:
	var value: Variant = values.get(key, 0)
	return value if typeof(value) == TYPE_INT else int(float(str(value)))


static func _bool(values: Dictionary, key: String) -> bool:
	var value: Variant = values.get(key, false)
	return value if typeof(value) == TYPE_BOOL else false


func _fail(message: String) -> void:
	push_error("research_421_ward_spend_probe_v2: %s" % message)
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
