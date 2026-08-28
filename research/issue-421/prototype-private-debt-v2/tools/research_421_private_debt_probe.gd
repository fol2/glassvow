extends SceneTree
## Direct identity controls for the issue #421 private combat-debt prototype.

const Policy: GDScript = preload("res://tools/balance_policy.gd")
const Sim: GDScript = preload("res://tools/balance_sim.gd")


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
	var rows_v: Variant = plan.get("rows", [])
	if typeof(rows_v) != TYPE_ARRAY:
		_fail("rows must be an array")
		return
	var rows: Array[Dictionary] = []
	var mode: String = str(plan.get("mode", "direct"))
	if mode == "direct":
		for spec_v: Variant in rows_v:
			if typeof(spec_v) != TYPE_DICTIONARY:
				_fail("every row must be a dictionary")
				return
			var spec: Dictionary = spec_v
			var content: ContentDB = ContentDB.load_from(str(spec.get("content", "")), false)
			if content == null:
				_fail("content did not load")
				return
			rows.append(_run(content, spec))
	elif mode == "whole-runs":
		var content: ContentDB = ContentDB.load_from(str(plan.get("content", "")), false)
		if content == null:
			_fail("content did not load")
			return
		var whole_rows: Array = rows_v
		rows = _whole_runs(content, whole_rows)
	else:
		_fail("mode must be direct or whole-runs")
		return
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


func _run(content: ContentDB, spec: Dictionary) -> Dictionary:
	var game: GlassvowGame = _game(content, spec)
	var kind: String = str(spec["kind"])
	if kind == "producer":
		return _producer(game, spec)
	if kind == "consumer":
		return _consumer(game, spec)
	if kind == "penalty":
		return _penalty(game, spec)
	_fail("unknown control kind %s" % kind)
	return {}


func _game(content: ContentDB, spec: Dictionary) -> GlassvowGame:
	var aspect: int = 1 if str(spec["aspect"]) == "ashwarden" else 0
	var run: RunState = RunState.new_run(
		content, _int(spec, "seed"), "private-debt-%s" % str(spec["id"]),
		{"aspect": aspect})
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": ["rootheart"], "kind": "normal"})
	game.cb.hand.clear()
	game.cb.discard.clear()
	game.cb.exhaust.clear()
	game.cb.queue.clear()
	game.cb.embers = 3
	game.cb.player.energy = 3
	game.cb.player.block = 0
	game.cb.player.hp = 20
	game.cb.player.max_hp = 20
	var enemy: EnemyCombatant = game.cb.enemies[0]
	enemy.hp = enemy.max_hp
	enemy.block = 0
	enemy.chips = 0
	enemy.facet_max = 8
	enemy.statuses.clear()
	return game


func _producer(game: GlassvowGame, spec: Dictionary) -> Dictionary:
	for _i: int in range(_int(spec, "fillerCount")):
		game.cb.hand.append(CardInst.new(game.run.next_uid(), &"defend", false))
	var card: CardInst = CardInst.new(
		game.run.next_uid(), &"debtEdge", _bool(spec, "upgraded"))
	game.cb.hand.append(card)
	var enemy: EnemyCombatant = game.cb.enemies[0]
	var hp_before: int = enemy.hp
	var rng_before: int = game.run.rng_state()
	var events: Array[Dictionary] = game.apply(
		{"t": "playCard", "uid": card.uid, "target": 0})
	return {
		"id": str(spec["id"]), "arm": str(spec["arm"]), "kind": "producer",
		"aspect": str(spec["aspect"]), "upgraded": card.up,
		"enemyHpBefore": hp_before, "enemyHpAfter": enemy.hp,
		"enemyChips": enemy.chips, "hand": _cards(game.cb.hand),
		"discard": _cards(game.cb.discard), "exhaust": _cards(game.cb.exhaust),
		"embers": game.cb.embers, "events": events,
		"rngBefore": rng_before, "rngAfter": game.run.rng_state(),
	}


func _consumer(game: GlassvowGame, spec: Dictionary) -> Dictionary:
	for _i: int in range(_int(spec, "debtCount")):
		game.cb.hand.append(CardInst.new(game.run.next_uid(), &"glassDebt", false))
	var card: CardInst = CardInst.new(
		game.run.next_uid(), &"debtWard", _bool(spec, "upgraded"))
	game.cb.hand.append(card)
	var rng_before: int = game.run.rng_state()
	var events: Array[Dictionary] = game.apply({"t": "playCard", "uid": card.uid})
	return {
		"id": str(spec["id"]), "arm": str(spec["arm"]), "kind": "consumer",
		"aspect": str(spec["aspect"]), "upgraded": card.up,
		"playerBlock": game.cb.player.block, "hand": _cards(game.cb.hand),
		"discard": _cards(game.cb.discard), "exhaust": _cards(game.cb.exhaust),
		"embers": game.cb.embers, "events": events,
		"rngBefore": rng_before, "rngAfter": game.run.rng_state(),
	}


func _penalty(game: GlassvowGame, spec: Dictionary) -> Dictionary:
	var debt: CardInst = CardInst.new(game.run.next_uid(), &"glassDebt", false)
	game.cb.hand.append(debt)
	game.cb.enemies[0].staggered = true
	var hp_before: int = game.cb.player.hp
	var rng_before: int = game.run.rng_state()
	var can_kindle: bool = game.rules.can_kindle(game.run, game.cb, debt)
	var events: Array[Dictionary] = game.apply({"t": "endTurn"})
	return {
		"id": str(spec["id"]), "arm": str(spec["arm"]), "kind": "penalty",
		"aspect": str(spec["aspect"]), "playerHpBefore": hp_before,
		"playerHpAfter": game.cb.player.hp, "canKindle": can_kindle,
		"hand": _cards(game.cb.hand), "discard": _cards(game.cb.discard),
		"exhaust": _cards(game.cb.exhaust), "embers": game.cb.embers,
		"events": events, "rngBefore": rng_before,
		"rngAfter": game.run.rng_state(),
	}


func _whole_runs(content: ContentDB, raw_rows: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for spec_v: Variant in raw_rows:
		if typeof(spec_v) != TYPE_DICTIONARY:
			_fail("every whole-run row must be a dictionary")
			return []
		var spec: Dictionary = spec_v
		var policies: Array[Dictionary] = Policy.sample_range(
			_int(spec, "policyRoot"), _int(spec, "policyIndex"), 1)
		var trace: Dictionary = {"capture": true}
		var row: Dictionary = Sim.simulate(
			content, str(spec["aspect"]), _int(spec, "seed"), _int(spec, "vow"),
			PackedStringArray(), policies[0], false, false, {}, null, false, {}, trace)
		row["id"] = str(spec["id"])
		row["stage"] = str(spec["stage"])
		row["arm"] = str(spec["arm"])
		row["policyRoot"] = _int(spec, "policyRoot")
		row["policyIndex"] = _int(spec, "policyIndex")
		row["trajectory"] = trace
		rows.append(row)
	return rows


static func _cards(cards: Array[CardInst]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for card: CardInst in cards:
		rows.append({
			"uid": card.uid, "id": String(card.id), "upgraded": card.up,
		})
	return rows


static func _int(values: Dictionary, key: String) -> int:
	var value: Variant = values.get(key, 0)
	return value if typeof(value) == TYPE_INT else int(float(str(value)))


static func _bool(values: Dictionary, key: String) -> bool:
	return values.get(key, false) == true


func _fail(message: String) -> void:
	push_error("research_421_private_debt_probe: %s" % message)
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
