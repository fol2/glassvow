extends SceneTree
## Deterministic identity probe for issue #421 Scoreline commitment.

const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
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
	var loaded: Dictionary = BalanceCatalogue.open({"content": str(plan.get("content", ""))})
	if loaded.has("error"):
		_fail(str(loaded["error"]))
		return
	var content: ContentDB = BalanceCatalogue.load_prepared(loaded)
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
		var row: Dictionary = _whole_run(content, spec) \
			if str(spec.get("mode", "")) == "whole-run" else _scripted(content, spec)
		if not str(row.get("error", "")).is_empty():
			_fail("%s: %s" % [str(spec.get("id", "?")), str(row["error"])])
			return
		rows.append(row)
	var output: Dictionary = {
		"schemaVersion": 1,
		"planSha256": FileAccess.get_sha256(str(opts["plan"])),
		"probeSha256": FileAccess.get_sha256(str(get_script().resource_path)),
		"contentIdentity": loaded["identity"],
		"rows": rows,
	}
	var file: FileAccess = FileAccess.open(str(opts["out"]), FileAccess.WRITE)
	if file == null:
		_fail("cannot write output")
		return
	file.store_string(JSON.stringify(output) + "\n")
	print(JSON.stringify({"status": "PASS", "rows": rows.size()}))
	quit(0)


func _whole_run(content: ContentDB, spec: Dictionary) -> Dictionary:
	var sampled: Array[Dictionary] = Policy.sample_range(
		int(float(str(spec["policyRoot"]))), int(float(str(spec["policyIndex"]))), 1
	)
	var settings_v: Variant = spec.get("research421", {})
	if typeof(settings_v) != TYPE_DICTIONARY:
		return {"error": "research421 must be a dictionary"}
	var settings: Dictionary = settings_v
	var row: Dictionary = Sim.simulate(
		content, str(spec["aspect"]), int(float(str(spec["seed"]))),
		int(float(str(spec["vow"]))),
		PackedStringArray(), sampled[0], false, false, {}, null, false, settings
	)
	row["id"] = str(spec.get("id", ""))
	return row


func _scripted(content: ContentDB, spec: Dictionary) -> Dictionary:
	var settings_v: Variant = spec.get("research421", {})
	if typeof(settings_v) != TYPE_DICTIONARY:
		return {"error": "research421 must be a dictionary"}
	var settings: Dictionary = settings_v
	var research_fault: String = Sim.configure_research421_scoreline_commitment(
		settings, content
	)
	if not research_fault.is_empty():
		return {"error": research_fault}
	var aspect: int = 1 if str(spec.get("aspect", "duskblade")) == "ashwarden" else 0
	var profile: Dictionary = {
		"aspect": aspect, "vow": 0, "reveals": content.reveal_ids.duplicate(),
		"unlocks": ["aspect2"], "quests": {}, "shards": [], "lamplighter": false,
	}
	var run: RunState = RunState.new_run(content,
		int(float(str(spec.get("seed", 347603)))),
		"fight-local-scripted", profile)
	run.player.relics.clear()
	var uid_before: int = run.uid
	var rng_before: int = run.rng_state()
	var deck_before: int = run.player.deck.size()
	research_fault = Sim.apply_research421_scoreline_commitment(content, run, settings)
	if not research_fault.is_empty():
		return {"error": research_fault}
	var commitment: Dictionary = _commitment_snapshot(
		run, content, uid_before, rng_before, deck_before
	)
	Pilot.set_ban(PackedStringArray())
	var policy_v: Variant = spec.get("policy", {})
	if typeof(policy_v) != TYPE_DICTIONARY:
		return {"error": "policy must be a dictionary"}
	Pilot.apply_policy(policy_v)
	Pilot.set_modes(false, false)
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": spec.get("enemies", ["gravewarden"]),
		"kind": "normal"})
	_prepare_combat(game, spec)
	var choices: Array[Dictionary] = []
	for action_v: Variant in spec.get("actions", []):
		var action: Dictionary = action_v
		var kind: String = str(action.get("t", ""))
		if kind == "playCard":
			choices.append(_choice_snapshot(game))
			var card: CardInst = _held(game.cb.hand, StringName(str(action["card"])))
			if card == null:
				return {"error": "missing scripted card %s" % str(action["card"])}
			game.apply({"t": "playCard", "uid": card.uid, "target": action.get("target")})
			if game.last_ret != true:
				return {"error": "scripted card was not playable"}
		elif kind == "setEnemyHp":
			var enemy: EnemyCombatant = game.cb.enemies[
				int(float(str(action.get("idx", 0))))
			]
			enemy.hp = int(float(str(action["hp"])))
		elif kind == "endTurn":
			game.apply({"t": "endTurn"})
		elif kind == "loseCombat":
			game.rules.lose_combat(game.run, game.cb)
		else:
			return {"error": "unknown scripted action %s" % kind}
	return {
		"id": str(spec.get("id", "")), "mode": "scripted", "error": "",
		"state": game.cb.to_dict(), "queue": game.cb.queue.duplicate(true),
		"rng": game.run.rng_state(), "runStats": game.run.stats.duplicate(true),
		"policyChoices": choices, "lastRet": game.last_ret,
		"commitment": commitment,
		"research421": {
			"scorelineTargets": game.cb.research421_scoreline_targets.duplicate(true),
		},
	}


func _commitment_snapshot(
	run: RunState, content: ContentDB, uid_before: int, rng_before: int, deck_before: int
) -> Dictionary:
	var restored: RunState = RunState.from_save_dict(run.to_save_dict(), content)
	return {
		"relics": run.player.relics.duplicate(),
		"deckIds": _deck_ids(run.player.deck),
		"deckUids": _deck_uids(run.player.deck),
		"uidDelta": run.uid - uid_before,
		"deckDelta": run.player.deck.size() - deck_before,
		"rngBefore": rng_before,
		"rngAfter": run.rng_state(),
		"contentHasOath": content.relics.has(Sim.RESEARCH421_SCORELINE_OATH),
		"reloadOk": restored != null,
		"reloadRelics": [] if restored == null else restored.player.relics.duplicate(),
		"reloadDeckIds": [] if restored == null else _deck_ids(restored.player.deck),
		"reloadDeckUids": [] if restored == null else _deck_uids(restored.player.deck),
		"reloadUid": -1 if restored == null else restored.uid,
	}


func _deck_ids(deck: Array[CardInst]) -> Array[String]:
	var ids: Array[String] = []
	for card: CardInst in deck:
		ids.append(String(card.id))
	return ids


func _deck_uids(deck: Array[CardInst]) -> Array[int]:
	var uids: Array[int] = []
	for card: CardInst in deck:
		uids.append(card.uid)
	return uids


func _prepare_combat(game: GlassvowGame, spec: Dictionary) -> void:
	game.cb.queue.clear()
	game.cb.hand.clear()
	game.cb.draw.clear()
	game.cb.discard.clear()
	game.cb.exhaust.clear()
	game.cb.player.energy = 99
	game.cb.player.block = 0
	var enemy_hp: int = int(float(str(spec.get("enemyHp", 200))))
	for enemy: EnemyCombatant in game.cb.enemies:
		enemy.hp = enemy_hp
		enemy.max_hp = enemy_hp
		enemy.block = 0
		enemy.statuses.clear()
	for card_v: Variant in spec.get("cards", []):
		var card_spec: Dictionary = card_v if typeof(card_v) == TYPE_DICTIONARY \
			else {"id": str(card_v)}
		var upgraded: bool = card_spec.get("up", false) == true
		game.cb.hand.append(CardInst.new(
			game.run.next_uid(), StringName(str(card_spec["id"])),
			upgraded
		))


func _choice_snapshot(game: GlassvowGame) -> Dictionary:
	var before: int = game.run.rng_state()
	var scores: Dictionary = {}
	var unblocked: int = Pilot._incoming(game) - game.cb.player.block
	for card: CardInst in game.cb.hand:
		var definition: Dictionary = game.rules.card_data(card)
		var target: Variant = Pilot._target(game, card, definition)
		if not game.rules.can_play(game.run, game.cb, card, target):
			continue
		var preview_v: Variant = game.rules.preview_play(game.cb, card, target, game.run)
		var preview: Dictionary = preview_v if typeof(preview_v) == TYPE_DICTIONARY else {}
		scores[String(card.id)] = Pilot._combat_score(
			game, card, definition, target, preview, unblocked, game.run.aspect == 0
		)
	var pick: Dictionary = Pilot._pick_play(game)
	var chosen: String = ""
	for card: CardInst in game.cb.hand:
		if card.uid == int(float(str(pick.get("uid", -1)))):
			chosen = String(card.id)
			break
	return {
		"scores": scores, "chosen": chosen, "target": pick.get("target"),
		"rngBefore": before, "rngAfter": game.run.rng_state(),
	}


func _held(hand: Array[CardInst], id: StringName) -> CardInst:
	for card: CardInst in hand:
		if card.id == id:
			return card
	return null


func _options(args: PackedStringArray) -> Dictionary:
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


func _fail(message: String) -> void:
	push_error("research_421_scoreline_commitment_probe: %s" % message)
	quit(2)
