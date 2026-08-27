extends SceneTree
## Deterministic, research-only legal combat probe for issue #524.

const Pilot: GDScript = preload("res://tools/balance_pilot.gd")


func _initialize() -> void:
	var opts: Dictionary = _options(OS.get_cmdline_user_args())
	if opts.has("error"):
		push_error("mechanism_probe: %s" % str(opts["error"]))
		quit(2)
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(opts["plan"])))
	if typeof(raw) != TYPE_DICTIONARY:
		push_error("mechanism_probe: plan must be a dictionary")
		quit(2)
		return
	var plan: Dictionary = raw
	var rows_v: Variant = plan.get("rows", [])
	if typeof(rows_v) != TYPE_ARRAY:
		push_error("mechanism_probe: plan rows must be an array")
		quit(2)
		return
	var content: ContentDB = ContentDB.load_full(false)
	var rows: Array = []
	for spec_v: Variant in rows_v:
		if typeof(spec_v) != TYPE_DICTIONARY:
			push_error("mechanism_probe: every row must be a dictionary")
			quit(2)
			return
		var spec: Dictionary = spec_v
		var row: Dictionary = _run(content, spec)
		if not str(row.get("error", "")).is_empty():
			push_error("mechanism_probe: %s: %s" % [str(spec.get("id", "?")), row["error"]])
			quit(2)
			return
		rows.append(row)
	var output: Dictionary = {
		"schemaVersion": 1,
		"planSha256": FileAccess.get_sha256(str(opts["plan"])),
		"runnerSha256": FileAccess.get_sha256(str(get_script().resource_path)),
		"rows": rows,
	}
	var file: FileAccess = FileAccess.open(str(opts["out"]), FileAccess.WRITE)
	if file == null:
		push_error("mechanism_probe: cannot write --out")
		quit(2)
		return
	file.store_string(JSON.stringify(output) + "\n")
	print(JSON.stringify({"status": "PASS", "rows": rows.size()}))
	quit(0)


func _run(content: ContentDB, spec: Dictionary) -> Dictionary:
	var aspect_name: String = str(spec.get("aspect", "duskblade"))
	var aspect: int = 1 if aspect_name == "ashwarden" else 0
	var profile: Dictionary = {
		"aspect": aspect,
		"vow": int(float(str(spec.get("vow", 0)))),
		"reveals": content.reveal_ids.duplicate(),
		"unlocks": spec.get("unlocks", ["aspect2"]),
		"quests": {},
		"shards": [],
		"lamplighter": false,
	}
	var seed: int = int(float(str(spec.get("seed", 0))))
	var run: RunState = RunState.new_run(content, seed, "probe-%s" % str(spec.get("id", seed)), profile)
	run.act = int(float(str(spec.get("act", 0))))
	run.player.deck.clear()
	for id_v: Variant in spec.get("deck", []):
		var card_id: String = str(id_v)
		if not content.cards.has(card_id):
			return _error(spec, "unknown deck card %s" % card_id)
		run.player.deck.append(CardInst.new(run.next_uid(), StringName(card_id), false))
	if run.player.deck.is_empty():
		return _error(spec, "deck must not be empty")
	run.player.relics.clear()
	for id_v: Variant in spec.get("relics", []):
		var relic_id: String = str(id_v)
		if not content.relics.has(relic_id):
			return _error(spec, "unknown relic %s" % relic_id)
		run.player.relics.append(relic_id)
	Pilot.set_ban(PackedStringArray())
	Pilot.apply_policy(spec.get("policy", {}))
	Pilot.set_modes(false, false)
	var game: GlassvowGame = GlassvowGame.new(content, run)
	var enemies_v: Variant = spec.get("enemies", ["gloomslime"])
	if typeof(enemies_v) != TYPE_ARRAY:
		return _error(spec, "enemies must be an array")
	var enemies: Array = enemies_v
	game.apply({"t": "startCombat", "enemies": enemies,
		"kind": str(spec.get("kind", "normal"))})
	if game.cb.enemies.is_empty():
		return _error(spec, "combat did not create an enemy")
	var mode: String = str(spec.get("mode", "pilot"))
	var fault: String = ""
	if mode == "scripted":
		fault = _scripted(game, spec)
	elif mode == "pilot":
		fault = _pilot(game, int(float(str(spec.get("maxTurns", 20)))))
	else:
		fault = "unknown mode %s" % mode
	if not fault.is_empty():
		return _error(spec, fault)
	return _metrics(game, spec)


func _scripted(game: GlassvowGame, spec: Dictionary) -> String:
	var actions_v: Variant = spec.get("actions", [])
	if typeof(actions_v) != TYPE_ARRAY:
		return "actions must be an array"
	var actions: Array = actions_v
	game.cb.hand.clear()
	game.cb.draw.clear()
	game.cb.discard.clear()
	game.cb.exhaust.clear()
	for action_v: Variant in actions:
		var action: Dictionary = action_v
		if str(action.get("command", "")) == "endTurn":
			continue
		var card_id: String = str(action.get("card", ""))
		if not game.content.cards.has(card_id):
			return "unknown action card %s" % card_id
		var upgraded: bool = action.get("up", false) == true
		game.cb.hand.append(CardInst.new(game.run.next_uid(), StringName(card_id), upgraded))
	for filler_v: Variant in spec.get("handFill", []):
		var filler: String = str(filler_v)
		if not game.content.cards.has(filler):
			return "unknown hand filler %s" % filler
		game.cb.hand.append(CardInst.new(game.run.next_uid(), StringName(filler), false))
	for draw_v: Variant in spec.get("drawFill", []):
		var draw_id: String = str(draw_v)
		if not game.content.cards.has(draw_id):
			return "unknown draw filler %s" % draw_id
		game.cb.draw.append(CardInst.new(game.run.next_uid(), StringName(draw_id), false))
	var setup_v: Variant = spec.get("setup", {})
	var setup: Dictionary = setup_v if typeof(setup_v) == TYPE_DICTIONARY else {}
	game.cb.player.energy = int(float(str(setup.get("energy", 20))))
	game.cb.player.block = int(float(str(setup.get("block", game.cb.player.block))))
	game.cb.embers = clampi(int(float(str(setup.get("embers", game.cb.embers)))), 0, game.cb.ember_cap)
	game.cb.player.hp = clampi(int(float(str(setup.get("playerHp", game.cb.player.hp)))),
		0, game.cb.player.max_hp)
	_apply_statuses(game.cb.player.statuses, setup.get("playerStatus", {}))
	var enemy: EnemyCombatant = game.cb.enemies[0]
	_apply_statuses(enemy.statuses, setup.get("enemyStatus", {}))
	if setup.has("enemyHp"):
		enemy.hp = clampi(int(float(str(setup["enemyHp"]))), 1, enemy.max_hp)
	if setup.has("enemyChipsFromMax"):
		enemy.chips = maxi(0, enemy.facet_max + int(float(str(setup["enemyChipsFromMax"]))))
	if setup.get("enemyStaggered", false) == true:
		enemy.staggered = true
	for action_v: Variant in actions:
		var action: Dictionary = action_v
		if str(action.get("command", "")) == "endTurn":
			if not game.cb.over:
				game.apply({"t": "endTurn"})
			continue
		var card_id: StringName = StringName(str(action["card"]))
		var card: CardInst = null
		for held: CardInst in game.cb.hand:
			if held.id == card_id:
				card = held
				break
		if card == null:
			return "scripted card %s is no longer in hand" % String(card_id)
		var target: Variant = action.get("target")
		if target == null and str(game.rules.card_data(card).get("target", "")) == "enemy":
			target = 0
		game.apply({"t": "playCard", "uid": card.uid, "target": target})
		if game.last_ret != true:
			return "scripted card %s was not legal" % String(card_id)
		if game.cb.over:
			break
	return ""


func _pilot(game: GlassvowGame, max_turns: int) -> String:
	if max_turns < 1 or max_turns > 30:
		return "maxTurns must be 1..30"
	while not game.cb.over:
		Pilot.play_turn(game)
		if game.cb.over or game.cb.turn >= max_turns:
			break
		game.apply({"t": "endTurn"})
	return ""


func _metrics(game: GlassvowGame, spec: Dictionary) -> Dictionary:
	var totals: Dictionary = {
		"damage": 0, "directDamage": 0, "poisonDamage": 0, "blockGain": 0,
		"heal": 0, "draw": 0, "poisonApplied": 0, "vulnerableApplied": 0,
		"emberGain": 0, "emberSpent": 0, "shatter": 0, "kindle": 0,
		"exhaust": 0, "relicProc": 0,
	}
	var cards: Dictionary = {}
	var relics: Dictionary = {}
	var last_play: String = ""
	var peak_block: int = game.cb.player.block
	for event_v: Variant in game.cb.queue:
		var event: Dictionary = event_v
		var kind: String = str(event.get("t", ""))
		if kind == "play":
			last_play = str(event.get("id", ""))
			_bump_nested(cards, last_play, "play", 1)
		elif kind == "hitEnemy":
			var amount: int = maxi(0, int(float(str(event.get("amount", 0)))))
			_bump(totals, "damage", amount)
			if event.get("poison", false) == true:
				_bump(totals, "poisonDamage", amount)
			else:
				_bump(totals, "directDamage", amount)
				_bump_nested(cards, last_play, "damage", amount)
		elif kind == "blockGain" and str(event.get("who", "")) == "player":
			var amount: int = maxi(0, int(float(str(event.get("n", 0)))))
			_bump(totals, "blockGain", amount)
			_bump_nested(cards, last_play, "block", amount)
			peak_block = maxi(peak_block, int(float(str(event.get("total", 0)))))
		elif kind == "heal" and str(event.get("who", "")) == "player":
			var amount: int = maxi(0, int(float(str(event.get("n", 0)))))
			_bump(totals, "heal", amount)
			_bump_nested(cards, last_play, "heal", amount)
		elif kind == "draw":
			_bump(totals, "draw", 1)
			_bump_nested(cards, last_play, "draw", 1)
		elif kind == "status":
			var amount: int = int(float(str(event.get("n", 0))))
			var status_id: String = str(event.get("id", ""))
			if amount > 0 and status_id == "poison":
				_bump(totals, "poisonApplied", amount)
			elif amount > 0 and status_id == "vulnerable":
				_bump(totals, "vulnerableApplied", amount)
			_bump_nested(cards, last_play, "status:%s" % status_id, amount)
		elif kind == "ember":
			var amount: int = int(float(str(event.get("n", 0))))
			if amount > 0:
				_bump(totals, "emberGain", amount)
			else:
				_bump(totals, "emberSpent", -amount)
			_bump_nested(cards, last_play, "ember", amount)
		elif kind == "shatter":
			_bump(totals, "shatter", 1)
			_bump_nested(cards, last_play, "shatter", 1)
		elif kind == "kindle":
			_bump(totals, "kindle", 1)
		elif kind == "exhaust":
			_bump(totals, "exhaust", 1)
		elif kind == "relicProc":
			var relic_id: String = str(event.get("id", ""))
			_bump(totals, "relicProc", 1)
			_bump(relics, relic_id, 1)
		elif kind in ["turn", "endTurn", "enemyAct", "toDiscard", "powerConsumed"]:
			last_play = ""
	var enemy_hp: int = 0
	for enemy: EnemyCombatant in game.cb.enemies:
		enemy_hp += maxi(0, enemy.hp)
	return {
		"id": str(spec.get("id", "")),
		"stage": str(spec.get("stage", "")),
		"package": str(spec.get("package", "")),
		"edge": str(spec.get("edge", "")),
		"arm": str(spec.get("arm", "")),
		"split": str(spec.get("split", "")),
		"context": str(spec.get("context", "")),
		"aspect": str(spec.get("aspect", "duskblade")),
		"seed": int(float(str(spec.get("seed", 0)))),
		"response": str(spec.get("response", "damage")),
		"outcome": game.cb.result if game.cb.over else "stall",
		"turns": game.cb.turn,
		"hpLost": game.cb.hp_lost,
		"endingHp": game.cb.player.hp,
		"endingBlock": game.cb.player.block,
		"peakBlock": peak_block,
		"enemyHpRemaining": enemy_hp,
		"rng": game.run.rng_state(),
		"totals": totals,
		"cards": cards,
		"relics": relics,
		"error": "",
	}


func _apply_statuses(target: Dictionary, values_v: Variant) -> void:
	if typeof(values_v) != TYPE_DICTIONARY:
		return
	var values: Dictionary = values_v
	for key_v: Variant in values:
		target[str(key_v)] = int(float(str(values[key_v])))


func _bump(values: Dictionary, key: String, amount: int) -> void:
	values[key] = int(float(str(values.get(key, 0)))) + amount


func _bump_nested(values: Dictionary, outer: String, inner: String, amount: int) -> void:
	if outer.is_empty():
		return
	var row_v: Variant = values.get(outer, {})
	var row: Dictionary = row_v if typeof(row_v) == TYPE_DICTIONARY else {}
	_bump(row, inner, amount)
	values[outer] = row


func _error(spec: Dictionary, message: String) -> Dictionary:
	return {"id": str(spec.get("id", "")), "error": message}


func _options(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {"plan": "", "out": ""}
	for arg: String in args:
		if not arg.begins_with("--") or not arg.contains("="):
			return {"error": "expected --name=value, got %s" % arg}
		var key: String = arg.get_slice("=", 0).trim_prefix("--")
		if not out.has(key):
			return {"error": "unknown option --%s" % key}
		out[key] = arg.substr(arg.find("=") + 1)
	if str(out["plan"]).is_empty() or str(out["out"]).is_empty():
		return {"error": "--plan and --out are required"}
	return out
