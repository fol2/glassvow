extends RefCounted
## Slice 1 tracer plus Slice 2: a second self on a different meta axis.
## Kits are deterministic, flip under the intended fixture, and fail closed.

const RUN_PATH: String = "user://glassvow_test_unwalked_run_v2.json"
const VIGIL_PATH: String = "user://glassvow_test_unwalked_vigil_v2.json"
const REF_PATH: String = "user://glassvow_test_unwalked_scenario.json"
const BUILD: String = "test-unwalked-sha"
const EMBER_MOVES: Array[String] = ["scepterEcho", "starfallEcho", "ringbreak"]
const ASH_MOVES: Array[String] = ["gravitasEcho", "ruinEcho", "ringward"]
const BRINE_MOVES: Array[String] = ["brineBite", "falseLamp", "undertowEcho"]
const SHELL_MOVES: Array[String] = ["closedShell", "stillWater", "librarySpine"]


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	_content_row(content, fails)
	_kit_from_deck(content, fails)
	_kit_flips(content, fails)
	_fail_closed(content, fails)
	_scenario_combat(content, fails)
	_ai_cycle(fails)
	_silent(content, fails)
	_uncrossed_row(content, fails)
	_uncrossed_kit(content, fails)
	_uncrossed_flips(content, fails)
	_uncrossed_fail_closed(content, fails)
	_uncrossed_scenario(content, fails)
	_uncrossed_ai(fails)
	_axes_diverge(content, fails)


static func _content_row(content: ContentDB, fails: Array[String]) -> void:
	var def: Dictionary = content.enemy(&"unwalkedSelf")
	if def.is_empty() or not EnemyAi.handles(&"unwalkedSelf"):
		fails.append("unwalkedSelf: missing catalogue row or AI handler")
		return
	if def.has("dialogue") or def.has("deathDialogue"):
		fails.append("unwalkedSelf: counterfactual selves must stay silent")
	var spec: Dictionary = def.get("counterfactual", {})
	if str(spec.get("node", "")) != "III-prime" or str(spec.get("motif", "")) != "broken-ring":
		fails.append("unwalkedSelf: node/motif must stay on III-prime / broken-ring")
	var faults: PackedStringArray = content.enemy_faults("unwalkedSelf", def)
	if not faults.is_empty():
		fails.append("unwalkedSelf: authored row failed validation: %s" % faults[0])
	var broken: Dictionary = def.duplicate(true)
	var kits: Dictionary = broken["counterfactual"]["kits"]
	kits["ember"] = ["notAMove"]
	if content.enemy_faults("unwalkedSelf", broken).is_empty():
		fails.append("unwalkedSelf: unknown kit move was accepted")


static func _kit_from_deck(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = RunState.new_run(content, 22001, "unwalked-dusk")
	var picked: Dictionary = CounterfactualSelf.resolve(run, content.enemy(&"unwalkedSelf"), content)
	if picked.get("ok", false) != true or str(picked.get("id", "")) != "ash":
		fails.append("unwalkedSelf: duskblade start deck should select ash, got %s"
			% str(picked.get("id", picked.get("error", ""))))
	var again: Dictionary = CounterfactualSelf.resolve(run, content.enemy(&"unwalkedSelf"), content)
	if str(again.get("id", "")) != str(picked.get("id", "")):
		fails.append("unwalkedSelf: identical deck produced a different kit")


static func _kit_flips(content: ContentDB, fails: Array[String]) -> void:
	var ash_run: RunState = RunState.new_run(content, 22002, "unwalked-ashwarden", {"aspect": 1})
	var ash_pick: Dictionary = CounterfactualSelf.resolve(
		ash_run, content.enemy(&"unwalkedSelf"), content)
	if str(ash_pick.get("id", "")) != "ember":
		fails.append("unwalkedSelf: ashwarden start deck should select ember, got %s"
			% str(ash_pick.get("id", ash_pick.get("error", ""))))
	var edited: RunState = RunState.new_run(content, 22003, "unwalked-edited")
	var removed: int = 0
	var kept: Array[CardInst] = []
	for card: CardInst in edited.player.deck:
		if String(card.id) == "strike" and removed < 3:
			removed += 1
			continue
		kept.append(card)
	edited.player.deck = kept
	var flipped: Dictionary = CounterfactualSelf.resolve(
		edited, content.enemy(&"unwalkedSelf"), content)
	if str(flipped.get("id", "")) != "ember":
		fails.append("unwalkedSelf: strike-light duskblade should select ember, got %s"
			% str(flipped.get("id", flipped.get("error", ""))))


static func _fail_closed(content: ContentDB, fails: Array[String]) -> void:
	var empty: RunState = RunState.new_run(content, 22004, "unwalked-empty")
	empty.player.deck.clear()
	var none: Dictionary = CounterfactualSelf.resolve(
		empty, content.enemy(&"unwalkedSelf"), content)
	if none.get("ok", false) == true:
		fails.append("unwalkedSelf: empty deck emitted a kit")
	var cursed: Dictionary = content.enemy(&"unwalkedSelf").duplicate(true)
	cursed["counterfactual"]["axisToKit"]["ember"] = "noSuchKit"
	var run: RunState = RunState.new_run(content, 22005, "unwalked-bad-kit")
	var bad: Dictionary = CounterfactualSelf.resolve(run, cursed, content)
	if bad.get("ok", false) == true:
		fails.append("unwalkedSelf: unknown kit was emitted")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	content.enemies["unwalkedSelf"] = cursed
	game.apply({"t": "startCombat", "enemies": ["unwalkedSelf"], "kind": "normal"})
	if game.cb == null or not game.cb.enemies.is_empty():
		fails.append("unwalkedSelf: invalid kit still entered combat")
	content.enemies["unwalkedSelf"] = cursed
	var restored: ContentDB = ContentDB.load_full()
	content.enemies["unwalkedSelf"] = restored.enemy(&"unwalkedSelf")


static func _scenario_combat(content: ContentDB, fails: Array[String]) -> void:
	var kernel: ScenarioKernel = ScenarioKernel.new(content, RUN_PATH, VIGIL_PATH, REF_PATH)
	kernel.clear_profile()
	var ref: ScenarioReference = ScenarioReference.new()
	if not ref.load_from({
		"id": "combat-unwalked-self", "revision": 1, "build": BUILD,
		"seed": 18501, "locale": "en", "shape": "pad-landscape",
		"overrides": {
			"act": 2, "node": "0,6", "kind": "monster",
			"enemies": ["unwalkedSelf"],
		},
	}):
		fails.append("unwalkedSelf: named Scenario rejected: %s" % ref.error)
		return
	var run: RunState = kernel.construct(ref)
	if run == null:
		fails.append("unwalkedSelf: named Scenario failed: %s" % kernel.last_error)
		kernel.clear_profile()
		return
	if run.pending_enemy_ids != ["unwalkedSelf"]:
		fails.append("unwalkedSelf: Scenario did not freeze the tracer enemy")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": run.pending_enemy_ids, "kind": "normal"})
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("unwalkedSelf: startCombat dropped the tracer")
		kernel.clear_profile()
		return
	var enemy: EnemyCombatant = game.cb.enemies[0]
	if str(enemy.flags.get(CounterfactualSelf.KIT_FLAG, "")) != "ash":
		fails.append("unwalkedSelf: Scenario combat did not wear the ash kit")
	if String(enemy.move_key) != "gravitasEcho":
		fails.append("unwalkedSelf: ash kit first intent was %s" % String(enemy.move_key))
	if not ASH_MOVES.has(String(enemy.move_key)):
		fails.append("unwalkedSelf: ash intent is not an ash kit move")
	kernel.clear_profile()


static func _ai_cycle(fails: Array[String]) -> void:
	var rng: Rng = Rng.new(7)
	var before: int = rng.get_state()
	var flags: Dictionary = {CounterfactualSelf.KIT_FLAG: "ember"}
	for turn: int in range(1, 4):
		var move: StringName = EnemyAi.decide(
			&"unwalkedSelf", turn, "", "", 1.0, rng, flags)
		if String(move) != EMBER_MOVES[turn - 1]:
			fails.append("unwalkedSelf: ember turn %d expected %s got %s"
				% [turn, EMBER_MOVES[turn - 1], String(move)])
	if rng.get_state() != before:
		fails.append("unwalkedSelf: AI consumed RNG")
	flags[CounterfactualSelf.KIT_FLAG] = "ash"
	for turn: int in range(1, 4):
		var move: StringName = EnemyAi.decide(
			&"unwalkedSelf", turn, "", "", 1.0, rng, flags)
		if String(move) != ASH_MOVES[turn - 1]:
			fails.append("unwalkedSelf: ash turn %d expected %s got %s"
				% [turn, ASH_MOVES[turn - 1], String(move)])
	var missing: StringName = EnemyAi.decide(&"unwalkedSelf", 1, "", "", 1.0, rng, {})
	if missing != &"":
		fails.append("unwalkedSelf: missing kit returned %s" % String(missing))


static func _silent(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = RunState.new_run(content, 22006, "unwalked-silent")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	var events: Array[Dictionary] = game.apply({
		"t": "startCombat", "enemies": ["unwalkedSelf"], "kind": "normal",
	})
	for ev: Dictionary in events:
		if ev.get("t") == EventTypes.VARIANT_DIALOGUE:
			fails.append("unwalkedSelf: emitted dialogue")
			return


static func _uncrossed_row(content: ContentDB, fails: Array[String]) -> void:
	var def: Dictionary = content.enemy(&"uncrossedSelf")
	if def.is_empty() or not EnemyAi.handles(&"uncrossedSelf"):
		fails.append("uncrossedSelf: missing catalogue row or AI handler")
		return
	if def.has("dialogue") or def.has("deathDialogue"):
		fails.append("uncrossedSelf: counterfactual selves must stay silent")
	var spec: Dictionary = def.get("counterfactual", {})
	if str(spec.get("node", "")) != "II-prime" or str(spec.get("motif", "")) != "false-light":
		fails.append("uncrossedSelf: node/motif must stay on II-prime / false-light")
	if str(spec.get("axis", "")) != CounterfactualSelf.AXIS_STATUS_LEAN:
		fails.append("uncrossedSelf: axis must be statusLean")
	var faults: PackedStringArray = content.enemy_faults("uncrossedSelf", def)
	if not faults.is_empty():
		fails.append("uncrossedSelf: authored row failed validation: %s" % faults[0])
	var broken: Dictionary = def.duplicate(true)
	broken["counterfactual"]["axis"] = "noSuchAxis"
	if content.enemy_faults("uncrossedSelf", broken).is_empty():
		fails.append("uncrossedSelf: unknown axis was accepted")
	var wrong_keys: Dictionary = def.duplicate(true)
	wrong_keys["counterfactual"]["axisToKit"] = {"ember": "brine", "ash": "shell"}
	if content.enemy_faults("uncrossedSelf", wrong_keys).is_empty():
		fails.append("uncrossedSelf: deckType keys were accepted on statusLean")


static func _uncrossed_kit(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = RunState.new_run(content, 22011, "uncrossed-dusk")
	var picked: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"uncrossedSelf"), content)
	if picked.get("ok", false) != true or str(picked.get("id", "")) != "brine":
		fails.append("uncrossedSelf: duskblade start deck should select brine, got %s"
			% str(picked.get("id", picked.get("error", ""))))
	var again: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"uncrossedSelf"), content)
	if str(again.get("id", "")) != str(picked.get("id", "")):
		fails.append("uncrossedSelf: identical deck produced a different kit")


static func _uncrossed_flips(content: ContentDB, fails: Array[String]) -> void:
	var ash_run: RunState = RunState.new_run(content, 22012, "uncrossed-ashwarden", {"aspect": 1})
	var ash_pick: Dictionary = CounterfactualSelf.resolve(
		ash_run, content.enemy(&"uncrossedSelf"), content)
	if str(ash_pick.get("id", "")) != "shell":
		fails.append("uncrossedSelf: ashwarden start deck should select shell, got %s"
			% str(ash_pick.get("id", ash_pick.get("error", ""))))
	var edited: RunState = RunState.new_run(content, 22013, "uncrossed-edited")
	var removed: int = 0
	var kept: Array[CardInst] = []
	for card: CardInst in edited.player.deck:
		if String(card.id) == "defend" and removed < 3:
			removed += 1
			continue
		kept.append(card)
	kept.append(CardInst.new(9001, &"ashBite"))
	kept.append(CardInst.new(9002, &"ashBite"))
	kept.append(CardInst.new(9003, &"ashBite"))
	kept.append(CardInst.new(9004, &"ashBite"))
	edited.player.deck = kept
	var flipped: Dictionary = CounterfactualSelf.resolve(
		edited, content.enemy(&"uncrossedSelf"), content)
	if str(flipped.get("id", "")) != "shell":
		fails.append("uncrossedSelf: toxin-heavy duskblade should select shell, got %s"
			% str(flipped.get("id", flipped.get("error", ""))))


static func _uncrossed_fail_closed(content: ContentDB, fails: Array[String]) -> void:
	var empty: RunState = RunState.new_run(content, 22014, "uncrossed-empty")
	empty.player.deck.clear()
	var none: Dictionary = CounterfactualSelf.resolve(
		empty, content.enemy(&"uncrossedSelf"), content)
	if none.get("ok", false) == true:
		fails.append("uncrossedSelf: empty deck emitted a kit")
	var dry: RunState = RunState.new_run(content, 22015, "uncrossed-dry")
	var strikes: Array[CardInst] = []
	for card: CardInst in dry.player.deck:
		if String(card.id) == "strike":
			strikes.append(card)
	dry.player.deck = strikes
	var dry_pick: Dictionary = CounterfactualSelf.resolve(
		dry, content.enemy(&"uncrossedSelf"), content)
	if dry_pick.get("ok", false) == true:
		fails.append("uncrossedSelf: strike-only deck emitted a kit")
	var cursed: Dictionary = content.enemy(&"uncrossedSelf").duplicate(true)
	cursed["counterfactual"]["axisToKit"]["ward"] = "noSuchKit"
	var run: RunState = RunState.new_run(content, 22016, "uncrossed-bad-kit")
	var bad: Dictionary = CounterfactualSelf.resolve(run, cursed, content)
	if bad.get("ok", false) == true:
		fails.append("uncrossedSelf: unknown kit was emitted")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	content.enemies["uncrossedSelf"] = cursed
	game.apply({"t": "startCombat", "enemies": ["uncrossedSelf"], "kind": "normal"})
	if game.cb == null or not game.cb.enemies.is_empty():
		fails.append("uncrossedSelf: invalid kit still entered combat")
	var restored: ContentDB = ContentDB.load_full()
	content.enemies["uncrossedSelf"] = restored.enemy(&"uncrossedSelf")


static func _uncrossed_scenario(content: ContentDB, fails: Array[String]) -> void:
	var kernel: ScenarioKernel = ScenarioKernel.new(content, RUN_PATH, VIGIL_PATH, REF_PATH)
	kernel.clear_profile()
	var ref: ScenarioReference = ScenarioReference.new()
	if not ref.load_from({
		"id": "combat-uncrossed-self", "revision": 1, "build": BUILD,
		"seed": 18501, "locale": "en", "shape": "pad-landscape",
		"overrides": {
			"act": 1, "node": "0,6", "kind": "monster",
			"enemies": ["uncrossedSelf"],
		},
	}):
		fails.append("uncrossedSelf: named Scenario rejected: %s" % ref.error)
		return
	var run: RunState = kernel.construct(ref)
	if run == null:
		fails.append("uncrossedSelf: named Scenario failed: %s" % kernel.last_error)
		kernel.clear_profile()
		return
	if run.pending_enemy_ids != ["uncrossedSelf"]:
		fails.append("uncrossedSelf: Scenario did not freeze the II-prime enemy")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": run.pending_enemy_ids, "kind": "normal"})
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("uncrossedSelf: startCombat dropped the II-prime self")
		kernel.clear_profile()
		return
	var enemy: EnemyCombatant = game.cb.enemies[0]
	if str(enemy.flags.get(CounterfactualSelf.KIT_FLAG, "")) != "brine":
		fails.append("uncrossedSelf: Scenario combat did not wear the brine kit")
	if String(enemy.move_key) != "brineBite":
		fails.append("uncrossedSelf: brine kit first intent was %s" % String(enemy.move_key))
	if not BRINE_MOVES.has(String(enemy.move_key)):
		fails.append("uncrossedSelf: brine intent is not a brine kit move")
	kernel.clear_profile()


static func _uncrossed_ai(fails: Array[String]) -> void:
	var rng: Rng = Rng.new(11)
	var before: int = rng.get_state()
	var flags: Dictionary = {CounterfactualSelf.KIT_FLAG: "brine"}
	for turn: int in range(1, 4):
		var move: StringName = EnemyAi.decide(
			&"uncrossedSelf", turn, "", "", 1.0, rng, flags)
		if String(move) != BRINE_MOVES[turn - 1]:
			fails.append("uncrossedSelf: brine turn %d expected %s got %s"
				% [turn, BRINE_MOVES[turn - 1], String(move)])
	if rng.get_state() != before:
		fails.append("uncrossedSelf: AI consumed RNG")
	flags[CounterfactualSelf.KIT_FLAG] = "shell"
	for turn: int in range(1, 4):
		var move: StringName = EnemyAi.decide(
			&"uncrossedSelf", turn, "", "", 1.0, rng, flags)
		if String(move) != SHELL_MOVES[turn - 1]:
			fails.append("uncrossedSelf: shell turn %d expected %s got %s"
				% [turn, SHELL_MOVES[turn - 1], String(move)])
	var missing: StringName = EnemyAi.decide(&"uncrossedSelf", 1, "", "", 1.0, rng, {})
	if missing != &"":
		fails.append("uncrossedSelf: missing kit returned %s" % String(missing))


static func _axes_diverge(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = RunState.new_run(content, 22017, "axes-ashwarden", {"aspect": 1})
	var court: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"unwalkedSelf"), content)
	var water: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"uncrossedSelf"), content)
	if str(court.get("id", "")) != "ember":
		fails.append("axes: ashwarden should still invert deckType to ember, got %s"
			% str(court.get("id", court.get("error", ""))))
	if str(water.get("id", "")) != "shell":
		fails.append("axes: ashwarden should invert statusLean to shell, got %s"
			% str(water.get("id", water.get("error", ""))))
	if str(court.get("id", "")) == str(water.get("id", "")):
		fails.append("axes: both selves wore the same kit on one deck")
