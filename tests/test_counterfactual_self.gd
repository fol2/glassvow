extends RefCounted
## Slice 1 + Slice 2 + multiplied selves + both elites + remaining normals.
## Kits are deterministic, flip under the intended fixture, and fail closed.

const RUN_PATH: String = "user://glassvow_test_unwalked_run_v2.json"
const VIGIL_PATH: String = "user://glassvow_test_unwalked_vigil_v2.json"
const REF_PATH: String = "user://glassvow_test_unwalked_scenario.json"
const BUILD: String = "test-unwalked-sha"
const EMBER_MOVES: Array[String] = ["scepterEcho", "starfallEcho", "ringbreak"]
const ASH_MOVES: Array[String] = ["gravitasEcho", "ruinEcho", "ringward"]
const BRINE_MOVES: Array[String] = ["brineBite", "falseLamp", "undertowEcho"]
const SHELL_MOVES: Array[String] = ["closedShell", "stillWater", "librarySpine"]
const GLASS_EMBER: Array[String] = ["glassCut", "shardVolley", "sealBlow"]
const GLASS_ASH: Array[String] = ["roseWard", "darkPane", "reliefWait"]
const ASHROOT_MOVES: Array[String] = ["rootLash", "greyAsh", "stillRoot"]
const LANTERN_MOVES: Array[String] = ["pairedDark", "wickUnlit", "lampWait"]
const UNSUNK_EMBER: Array[String] = ["tideCut", "unreadVolley", "brineWake"]
const UNSUNK_ASH: Array[String] = ["stackWard", "stillTide", "waitPage"]
const CARVE_MOVES: Array[String] = ["stoneCut", "glyphVolley", "sealCrack"]
const DOOR_MOVES: Array[String] = ["doorWard", "darkStamp", "waitStone"]
const STAR_MOVES: Array[String] = ["starGaze", "lightHang", "eyeMeet"]
const OBSIDIAN_MOVES: Array[String] = ["obsidianWard", "darkHarden", "courtWait"]
const WOOD_EMBER: Array[String] = ["branchCut", "roadVolley", "woodBlow"]
const WOOD_ASH: Array[String] = ["woodWard", "cinderHush", "standWood"]


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
	_unopened_row(content, fails)
	_unopened_kit(content, fails)
	_unopened_flips(content, fails)
	_unopened_fail_closed(content, fails)
	_unopened_scenario(content, fails)
	_unopened_ai(fails)
	_axis_reuse(content, fails)
	_unlit_row(content, fails)
	_unlit_kit(content, fails)
	_unlit_flips(content, fails)
	_unlit_fail_closed(content, fails)
	_unlit_scenario(content, fails)
	_unlit_ai(fails)
	_lean_reuse(content, fails)
	_unsunk_row(content, fails)
	_unsunk_kit(content, fails)
	_unsunk_flips(content, fails)
	_unsunk_fail_closed(content, fails)
	_unsunk_scenario(content, fails)
	_unsunk_ai(fails)
	_node_share(content, fails)
	_uncarved_row(content, fails)
	_uncarved_kit(content, fails)
	_uncarved_flips(content, fails)
	_uncarved_fail_closed(content, fails)
	_uncarved_scenario(content, fails)
	_uncarved_ai(fails)
	_threshold_share(content, fails)
	_unobsidian_row(content, fails)
	_unobsidian_kit(content, fails)
	_unobsidian_flips(content, fails)
	_unobsidian_fail_closed(content, fails)
	_unobsidian_scenario(content, fails)
	_unobsidian_ai(fails)
	_iii_share(content, fails)
	_unwooded_row(content, fails)
	_unwooded_kit(content, fails)
	_unwooded_flips(content, fails)
	_unwooded_fail_closed(content, fails)
	_unwooded_scenario(content, fails)
	_unwooded_ai(fails)
	_i_share(content, fails)


static func _content_row(content: ContentDB, fails: Array[String]) -> void:
	var def: Dictionary = content.enemy(&"unwalkedSelf")
	if def.is_empty() or not EnemyAi.handles(&"unwalkedSelf"):
		fails.append("unwalkedSelf: missing catalogue row or AI handler")
		return
	if not FileAccess.file_exists("res://assets/art/enemies/unwalkedSelf.png"):
		fails.append("unwalkedSelf: missing painting")
	if EnemyView.art_texture(&"unwalkedSelf") == null:
		fails.append("unwalkedSelf: painting did not import")
	# First landing boxed at scale 1.05 (194px). Counterfactual selves share
	# the hero silhouette, so the combat box has to read at least half again.
	if EnemyView.art_box(&"unwalkedSelf") < 185.0 * 1.05 * 1.5:
		fails.append("unwalkedSelf: combat box must be at least 50% above 1.05")
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
	if not FileAccess.file_exists("res://assets/art/enemies/uncrossedSelf.png"):
		fails.append("uncrossedSelf: missing painting")
	if EnemyView.art_texture(&"uncrossedSelf") == null:
		fails.append("uncrossedSelf: painting did not import")
	if EnemyView.art_box(&"uncrossedSelf") < 185.0 * 1.05 * 1.5:
		fails.append("uncrossedSelf: combat box must be at least 50% above 1.05")
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


static func _unopened_row(content: ContentDB, fails: Array[String]) -> void:
	var def: Dictionary = content.enemy(&"unopenedSelf")
	if def.is_empty() or not EnemyAi.handles(&"unopenedSelf"):
		fails.append("unopenedSelf: missing catalogue row or AI handler")
		return
	if not FileAccess.file_exists("res://assets/art/enemies/unopenedSelf.png"):
		fails.append("unopenedSelf: missing painting")
	if EnemyView.art_texture(&"unopenedSelf") == null:
		fails.append("unopenedSelf: painting did not import")
	if EnemyView.art_box(&"unopenedSelf") < 185.0 * 1.05 * 1.5:
		fails.append("unopenedSelf: combat box must be at least 50% above 1.05")
	if def.has("dialogue") or def.has("deathDialogue"):
		fails.append("unopenedSelf: counterfactual selves must stay silent")
	var spec: Dictionary = def.get("counterfactual", {})
	if str(spec.get("node", "")) != "threshold-prime" \
			or str(spec.get("motif", "")) != "stained-glass":
		fails.append("unopenedSelf: node/motif must stay on threshold-prime / stained-glass")
	if str(spec.get("axis", "")) != CounterfactualSelf.AXIS_DECK_TYPE:
		fails.append("unopenedSelf: axis must reuse deckType")
	var faults: PackedStringArray = content.enemy_faults("unopenedSelf", def)
	if not faults.is_empty():
		fails.append("unopenedSelf: authored row failed validation: %s" % faults[0])
	var broken: Dictionary = def.duplicate(true)
	var kits: Dictionary = broken["counterfactual"]["kits"]
	kits["ember"] = ["notAMove"]
	if content.enemy_faults("unopenedSelf", broken).is_empty():
		fails.append("unopenedSelf: unknown kit move was accepted")
	var third: Dictionary = def.duplicate(true)
	third["counterfactual"]["axis"] = "costLean"
	if content.enemy_faults("unopenedSelf", third).is_empty():
		fails.append("unopenedSelf: a third axis was accepted")


static func _unopened_kit(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = RunState.new_run(content, 22021, "unopened-dusk")
	var picked: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"unopenedSelf"), content)
	if picked.get("ok", false) != true or str(picked.get("id", "")) != "ash":
		fails.append("unopenedSelf: duskblade start deck should select ash, got %s"
			% str(picked.get("id", picked.get("error", ""))))
	var again: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"unopenedSelf"), content)
	if str(again.get("id", "")) != str(picked.get("id", "")):
		fails.append("unopenedSelf: identical deck produced a different kit")


static func _unopened_flips(content: ContentDB, fails: Array[String]) -> void:
	var ash_run: RunState = RunState.new_run(content, 22022, "unopened-ashwarden", {"aspect": 1})
	var ash_pick: Dictionary = CounterfactualSelf.resolve(
		ash_run, content.enemy(&"unopenedSelf"), content)
	if str(ash_pick.get("id", "")) != "ember":
		fails.append("unopenedSelf: ashwarden start deck should select ember, got %s"
			% str(ash_pick.get("id", ash_pick.get("error", ""))))
	var edited: RunState = RunState.new_run(content, 22023, "unopened-edited")
	var removed: int = 0
	var kept: Array[CardInst] = []
	for card: CardInst in edited.player.deck:
		if String(card.id) == "strike" and removed < 3:
			removed += 1
			continue
		kept.append(card)
	edited.player.deck = kept
	var flipped: Dictionary = CounterfactualSelf.resolve(
		edited, content.enemy(&"unopenedSelf"), content)
	if str(flipped.get("id", "")) != "ember":
		fails.append("unopenedSelf: strike-light duskblade should select ember, got %s"
			% str(flipped.get("id", flipped.get("error", ""))))


static func _unopened_fail_closed(content: ContentDB, fails: Array[String]) -> void:
	var empty: RunState = RunState.new_run(content, 22024, "unopened-empty")
	empty.player.deck.clear()
	var none: Dictionary = CounterfactualSelf.resolve(
		empty, content.enemy(&"unopenedSelf"), content)
	if none.get("ok", false) == true:
		fails.append("unopenedSelf: empty deck emitted a kit")
	var cursed: Dictionary = content.enemy(&"unopenedSelf").duplicate(true)
	cursed["counterfactual"]["axisToKit"]["ember"] = "noSuchKit"
	var run: RunState = RunState.new_run(content, 22025, "unopened-bad-kit")
	var bad: Dictionary = CounterfactualSelf.resolve(run, cursed, content)
	if bad.get("ok", false) == true:
		fails.append("unopenedSelf: unknown kit was emitted")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	content.enemies["unopenedSelf"] = cursed
	game.apply({"t": "startCombat", "enemies": ["unopenedSelf"], "kind": "normal"})
	if game.cb == null or not game.cb.enemies.is_empty():
		fails.append("unopenedSelf: invalid kit still entered combat")
	var restored: ContentDB = ContentDB.load_full()
	content.enemies["unopenedSelf"] = restored.enemy(&"unopenedSelf")


static func _unopened_scenario(content: ContentDB, fails: Array[String]) -> void:
	var kernel: ScenarioKernel = ScenarioKernel.new(content, RUN_PATH, VIGIL_PATH, REF_PATH)
	kernel.clear_profile()
	var ref: ScenarioReference = ScenarioReference.new()
	if not ref.load_from({
		"id": "combat-unopened-self", "revision": 1, "build": BUILD,
		"seed": 18501, "locale": "en", "shape": "pad-landscape",
		"overrides": {
			"act": 0, "node": "0,6", "kind": "monster",
			"enemies": ["unopenedSelf"],
		},
	}):
		fails.append("unopenedSelf: named Scenario rejected: %s" % ref.error)
		return
	var run: RunState = kernel.construct(ref)
	if run == null:
		fails.append("unopenedSelf: named Scenario failed: %s" % kernel.last_error)
		kernel.clear_profile()
		return
	if run.pending_enemy_ids != ["unopenedSelf"]:
		fails.append("unopenedSelf: Scenario did not freeze the threshold-prime enemy")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": run.pending_enemy_ids, "kind": "normal"})
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("unopenedSelf: startCombat dropped the threshold-prime self")
		kernel.clear_profile()
		return
	var enemy: EnemyCombatant = game.cb.enemies[0]
	if str(enemy.flags.get(CounterfactualSelf.KIT_FLAG, "")) != "ash":
		fails.append("unopenedSelf: Scenario combat did not wear the ash kit")
	if String(enemy.move_key) != "roseWard":
		fails.append("unopenedSelf: ash kit first intent was %s" % String(enemy.move_key))
	if not GLASS_ASH.has(String(enemy.move_key)):
		fails.append("unopenedSelf: ash intent is not an ash kit move")
	kernel.clear_profile()


static func _unopened_ai(fails: Array[String]) -> void:
	var rng: Rng = Rng.new(13)
	var before: int = rng.get_state()
	var flags: Dictionary = {CounterfactualSelf.KIT_FLAG: "ember"}
	for turn: int in range(1, 4):
		var move: StringName = EnemyAi.decide(
			&"unopenedSelf", turn, "", "", 1.0, rng, flags)
		if String(move) != GLASS_EMBER[turn - 1]:
			fails.append("unopenedSelf: ember turn %d expected %s got %s"
				% [turn, GLASS_EMBER[turn - 1], String(move)])
	if rng.get_state() != before:
		fails.append("unopenedSelf: AI consumed RNG")
	flags[CounterfactualSelf.KIT_FLAG] = "ash"
	for turn: int in range(1, 4):
		var move: StringName = EnemyAi.decide(
			&"unopenedSelf", turn, "", "", 1.0, rng, flags)
		if String(move) != GLASS_ASH[turn - 1]:
			fails.append("unopenedSelf: ash turn %d expected %s got %s"
				% [turn, GLASS_ASH[turn - 1], String(move)])
	var missing: StringName = EnemyAi.decide(&"unopenedSelf", 1, "", "", 1.0, rng, {})
	if missing != &"":
		fails.append("unopenedSelf: missing kit returned %s" % String(missing))


static func _axis_reuse(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = RunState.new_run(content, 22026, "reuse-ashwarden", {"aspect": 1})
	var court: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"unwalkedSelf"), content)
	var glass: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"unopenedSelf"), content)
	var wood: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"unwoodedSelf"), content)
	if str(court.get("id", "")) != "ember" or str(glass.get("id", "")) != "ember" \
			or str(wood.get("id", "")) != "ember":
		fails.append("reuse: ashwarden should invert deckType selves to ember")
	var court_moves: Variant = content.enemy(&"unwalkedSelf")["counterfactual"]["kits"]["ember"]
	var glass_moves: Variant = content.enemy(&"unopenedSelf")["counterfactual"]["kits"]["ember"]
	var wood_moves: Variant = content.enemy(&"unwoodedSelf")["counterfactual"]["kits"]["ember"]
	if str(court_moves) == str(glass_moves):
		fails.append("reuse: threshold-prime reused III-prime ember moves")
	if str(wood_moves) == str(court_moves) or str(wood_moves) == str(glass_moves):
		fails.append("reuse: I-prime reused another deckType ember kit")
	if CounterfactualSelf.axis_keys("costLean").size() != 0:
		fails.append("reuse: a third axis kind was registered")


static func _unlit_row(content: ContentDB, fails: Array[String]) -> void:
	var def: Dictionary = content.enemy(&"unlitSelf")
	if def.is_empty() or not EnemyAi.handles(&"unlitSelf"):
		fails.append("unlitSelf: missing catalogue row or AI handler")
		return
	if not FileAccess.file_exists("res://assets/art/enemies/unlitSelf.png"):
		fails.append("unlitSelf: missing painting")
	if EnemyView.art_texture(&"unlitSelf") == null:
		fails.append("unlitSelf: painting did not import")
	if EnemyView.art_box(&"unlitSelf") < 185.0 * 1.05 * 1.5:
		fails.append("unlitSelf: combat box must be at least 50% above 1.05")
	if def.has("dialogue") or def.has("deathDialogue"):
		fails.append("unlitSelf: counterfactual selves must stay silent")
	var spec: Dictionary = def.get("counterfactual", {})
	if str(spec.get("node", "")) != "I-prime" or str(spec.get("motif", "")) != "paired-lanterns":
		fails.append("unlitSelf: node/motif must stay on I-prime / paired-lanterns")
	if str(spec.get("axis", "")) != CounterfactualSelf.AXIS_STATUS_LEAN:
		fails.append("unlitSelf: axis must reuse statusLean")
	if str(def.get("name", "")).contains("Unlit"):
		fails.append("unlitSelf: display name collides with locked 'the Unlit Way'")
	var hp_v: Variant = def.get("hp", [])
	var other_hp: Variant = content.enemy(&"uncrossedSelf").get("hp", [])
	if str(hp_v) == str(other_hp):
		fails.append("unlitSelf: HP range cloned the II-prime self")
	var faults: PackedStringArray = content.enemy_faults("unlitSelf", def)
	if not faults.is_empty():
		fails.append("unlitSelf: authored row failed validation: %s" % faults[0])
	var broken: Dictionary = def.duplicate(true)
	broken["counterfactual"]["axis"] = "noSuchAxis"
	if content.enemy_faults("unlitSelf", broken).is_empty():
		fails.append("unlitSelf: unknown axis was accepted")
	var wrong_keys: Dictionary = def.duplicate(true)
	wrong_keys["counterfactual"]["axisToKit"] = {"ember": "ashroot", "ash": "lantern"}
	if content.enemy_faults("unlitSelf", wrong_keys).is_empty():
		fails.append("unlitSelf: deckType keys were accepted on statusLean")
	var third: Dictionary = def.duplicate(true)
	third["counterfactual"]["axis"] = "costLean"
	if content.enemy_faults("unlitSelf", third).is_empty():
		fails.append("unlitSelf: a third axis was accepted")


static func _unlit_kit(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = RunState.new_run(content, 22031, "unlit-dusk")
	var picked: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"unlitSelf"), content)
	if picked.get("ok", false) != true or str(picked.get("id", "")) != "ashroot":
		fails.append("unlitSelf: duskblade start deck should select ashroot, got %s"
			% str(picked.get("id", picked.get("error", ""))))
	var again: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"unlitSelf"), content)
	if str(again.get("id", "")) != str(picked.get("id", "")):
		fails.append("unlitSelf: identical deck produced a different kit")


static func _unlit_flips(content: ContentDB, fails: Array[String]) -> void:
	var ash_run: RunState = RunState.new_run(content, 22032, "unlit-ashwarden", {"aspect": 1})
	var ash_pick: Dictionary = CounterfactualSelf.resolve(
		ash_run, content.enemy(&"unlitSelf"), content)
	if str(ash_pick.get("id", "")) != "lantern":
		fails.append("unlitSelf: ashwarden start deck should select lantern, got %s"
			% str(ash_pick.get("id", ash_pick.get("error", ""))))
	var edited: RunState = RunState.new_run(content, 22033, "unlit-edited")
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
		edited, content.enemy(&"unlitSelf"), content)
	if str(flipped.get("id", "")) != "lantern":
		fails.append("unlitSelf: toxin-heavy duskblade should select lantern, got %s"
			% str(flipped.get("id", flipped.get("error", ""))))


static func _unlit_fail_closed(content: ContentDB, fails: Array[String]) -> void:
	var empty: RunState = RunState.new_run(content, 22034, "unlit-empty")
	empty.player.deck.clear()
	var none: Dictionary = CounterfactualSelf.resolve(
		empty, content.enemy(&"unlitSelf"), content)
	if none.get("ok", false) == true:
		fails.append("unlitSelf: empty deck emitted a kit")
	var dry: RunState = RunState.new_run(content, 22035, "unlit-dry")
	var strikes: Array[CardInst] = []
	for card: CardInst in dry.player.deck:
		if String(card.id) == "strike":
			strikes.append(card)
	dry.player.deck = strikes
	var dry_pick: Dictionary = CounterfactualSelf.resolve(
		dry, content.enemy(&"unlitSelf"), content)
	if dry_pick.get("ok", false) == true:
		fails.append("unlitSelf: strike-only deck emitted a kit")
	var cursed: Dictionary = content.enemy(&"unlitSelf").duplicate(true)
	cursed["counterfactual"]["axisToKit"]["ward"] = "noSuchKit"
	var run: RunState = RunState.new_run(content, 22036, "unlit-bad-kit")
	var bad: Dictionary = CounterfactualSelf.resolve(run, cursed, content)
	if bad.get("ok", false) == true:
		fails.append("unlitSelf: unknown kit was emitted")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	content.enemies["unlitSelf"] = cursed
	game.apply({"t": "startCombat", "enemies": ["unlitSelf"], "kind": "normal"})
	if game.cb == null or not game.cb.enemies.is_empty():
		fails.append("unlitSelf: invalid kit still entered combat")
	var restored: ContentDB = ContentDB.load_full()
	content.enemies["unlitSelf"] = restored.enemy(&"unlitSelf")


static func _unlit_scenario(content: ContentDB, fails: Array[String]) -> void:
	var kernel: ScenarioKernel = ScenarioKernel.new(content, RUN_PATH, VIGIL_PATH, REF_PATH)
	kernel.clear_profile()
	var ref: ScenarioReference = ScenarioReference.new()
	if not ref.load_from({
		"id": "combat-unlit-self", "revision": 1, "build": BUILD,
		"seed": 18501, "locale": "en", "shape": "pad-landscape",
		"overrides": {
			"act": 0, "node": "1,2", "kind": "monster",
			"enemies": ["unlitSelf"],
		},
	}):
		fails.append("unlitSelf: named Scenario rejected: %s" % ref.error)
		return
	var run: RunState = kernel.construct(ref)
	if run == null:
		fails.append("unlitSelf: named Scenario failed: %s" % kernel.last_error)
		kernel.clear_profile()
		return
	if run.pending_enemy_ids != ["unlitSelf"]:
		fails.append("unlitSelf: Scenario did not freeze the I-prime enemy")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": run.pending_enemy_ids, "kind": "normal"})
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("unlitSelf: startCombat dropped the I-prime self")
		kernel.clear_profile()
		return
	var enemy: EnemyCombatant = game.cb.enemies[0]
	if str(enemy.flags.get(CounterfactualSelf.KIT_FLAG, "")) != "ashroot":
		fails.append("unlitSelf: Scenario combat did not wear the ashroot kit")
	if String(enemy.move_key) != "rootLash":
		fails.append("unlitSelf: ashroot kit first intent was %s" % String(enemy.move_key))
	if not ASHROOT_MOVES.has(String(enemy.move_key)):
		fails.append("unlitSelf: ashroot intent is not an ashroot kit move")
	kernel.clear_profile()


static func _unlit_ai(fails: Array[String]) -> void:
	var rng: Rng = Rng.new(17)
	var before: int = rng.get_state()
	var flags: Dictionary = {CounterfactualSelf.KIT_FLAG: "ashroot"}
	for turn: int in range(1, 4):
		var move: StringName = EnemyAi.decide(
			&"unlitSelf", turn, "", "", 1.0, rng, flags)
		if String(move) != ASHROOT_MOVES[turn - 1]:
			fails.append("unlitSelf: ashroot turn %d expected %s got %s"
				% [turn, ASHROOT_MOVES[turn - 1], String(move)])
	if rng.get_state() != before:
		fails.append("unlitSelf: AI consumed RNG")
	flags[CounterfactualSelf.KIT_FLAG] = "lantern"
	for turn: int in range(1, 4):
		var move: StringName = EnemyAi.decide(
			&"unlitSelf", turn, "", "", 1.0, rng, flags)
		if String(move) != LANTERN_MOVES[turn - 1]:
			fails.append("unlitSelf: lantern turn %d expected %s got %s"
				% [turn, LANTERN_MOVES[turn - 1], String(move)])
	var missing: StringName = EnemyAi.decide(&"unlitSelf", 1, "", "", 1.0, rng, {})
	if missing != &"":
		fails.append("unlitSelf: missing kit returned %s" % String(missing))


static func _lean_reuse(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = RunState.new_run(content, 22037, "lean-ashwarden", {"aspect": 1})
	var water: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"uncrossedSelf"), content)
	var lamps: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"unlitSelf"), content)
	if str(water.get("id", "")) != "shell" or str(lamps.get("id", "")) != "lantern":
		fails.append("lean: ashwarden should invert both statusLean selves to ward kits")
	var court: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"unobsidianSelf"), content)
	if str(court.get("id", "")) != "obsidian":
		fails.append("lean: ashwarden should invert III-prime to obsidian, got %s"
			% str(court.get("id", court.get("error", ""))))
	var water_moves: Variant = content.enemy(&"uncrossedSelf")["counterfactual"]["kits"]["shell"]
	var lamp_moves: Variant = content.enemy(&"unlitSelf")["counterfactual"]["kits"]["lantern"]
	if str(water_moves) == str(lamp_moves):
		fails.append("lean: I-prime reused II-prime shell moves")
	if CounterfactualSelf.axis_keys("costLean").size() != 0:
		fails.append("lean: a third axis kind was registered")


static func _unsunk_row(content: ContentDB, fails: Array[String]) -> void:
	var def: Dictionary = content.enemy(&"unsunkSelf")
	if def.is_empty() or not EnemyAi.handles(&"unsunkSelf"):
		fails.append("unsunkSelf: missing catalogue row or AI handler")
		return
	if not FileAccess.file_exists("res://assets/art/enemies/unsunkSelf.png"):
		fails.append("unsunkSelf: missing painting")
	if EnemyView.art_texture(&"unsunkSelf") == null:
		fails.append("unsunkSelf: painting did not import")
	# Elite base 230 at 1.6 was 368px — larger than the hero (285) and the
	# tracer (296), and it crowded the END button. 1.4 stays a step above
	# the tracer without matching the first-landing 50% rule (that floor
	# on this base is 362px, which forces 1.6).
	if EnemyView.art_box(&"unsunkSelf") < 230.0 * 1.4:
		fails.append("unsunkSelf: elite combat box must stay at scale 1.4")
	if EnemyView.art_box(&"unsunkSelf") <= EnemyView.art_box(&"unwalkedSelf"):
		fails.append("unsunkSelf: elite must read larger than the tracer")
	if def.has("dialogue") or def.has("deathDialogue"):
		fails.append("unsunkSelf: counterfactual selves must stay silent")
	if def.get("elite", false) != true:
		fails.append("unsunkSelf: first elite must ship elite: true")
	if def.get("boss", false) == true:
		fails.append("unsunkSelf: elite must not also be a boss")
	var spec: Dictionary = def.get("counterfactual", {})
	if str(spec.get("node", "")) != "II-prime" or str(spec.get("motif", "")) != "library":
		fails.append("unsunkSelf: node/motif must stay on II-prime / library")
	if str(spec.get("axis", "")) != CounterfactualSelf.AXIS_DECK_TYPE:
		fails.append("unsunkSelf: axis must reuse deckType")
	var hp_v: Variant = def.get("hp", [])
	var other_hp: Variant = content.enemy(&"uncrossedSelf").get("hp", [])
	if str(hp_v) == str(other_hp):
		fails.append("unsunkSelf: HP range cloned the II-prime normal")
	var banned: PackedStringArray = PackedStringArray([
		"Uncut", "Unread", "Unwaited", "Tide", "Unclosed", "Unwoken",
	])
	var moves: Dictionary = def.get("moves", {})
	for move_id_v: Variant in moves.keys():
		var move_name: String = str(moves[move_id_v].get("name", ""))
		for word: String in banned:
			if move_name.contains(word):
				fails.append("unsunkSelf: %s display collides on '%s'"
					% [str(move_id_v), word])
	var water_fx: Variant = content.enemy(&"uncrossedSelf")["moves"]["stillWater"].get("fx", [])
	var tide_row: Dictionary = moves["stillTide"]
	var flood_fx: Variant = tide_row.get("fx", [])
	if str(water_fx) == str(flood_fx):
		fails.append("unsunkSelf: stillTide cloned stillWater's debuff")
	var faults: PackedStringArray = content.enemy_faults("unsunkSelf", def)
	if not faults.is_empty():
		fails.append("unsunkSelf: authored row failed validation: %s" % faults[0])
	var broken: Dictionary = def.duplicate(true)
	var kits: Dictionary = broken["counterfactual"]["kits"]
	kits["ember"] = ["notAMove"]
	if content.enemy_faults("unsunkSelf", broken).is_empty():
		fails.append("unsunkSelf: unknown kit move was accepted")
	var third: Dictionary = def.duplicate(true)
	third["counterfactual"]["axis"] = "costLean"
	if content.enemy_faults("unsunkSelf", third).is_empty():
		fails.append("unsunkSelf: a third axis was accepted")
	var both: Dictionary = def.duplicate(true)
	both["boss"] = true
	if content.enemy_faults("unsunkSelf", both).is_empty():
		fails.append("unsunkSelf: elite+boss was accepted")


static func _unsunk_kit(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = RunState.new_run(content, 22041, "unsunk-dusk")
	var picked: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"unsunkSelf"), content)
	if picked.get("ok", false) != true or str(picked.get("id", "")) != "ash":
		fails.append("unsunkSelf: duskblade start deck should select ash, got %s"
			% str(picked.get("id", picked.get("error", ""))))
	var again: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"unsunkSelf"), content)
	if str(again.get("id", "")) != str(picked.get("id", "")):
		fails.append("unsunkSelf: identical deck produced a different kit")


static func _unsunk_flips(content: ContentDB, fails: Array[String]) -> void:
	var ash_run: RunState = RunState.new_run(content, 22042, "unsunk-ashwarden", {"aspect": 1})
	var ash_pick: Dictionary = CounterfactualSelf.resolve(
		ash_run, content.enemy(&"unsunkSelf"), content)
	if str(ash_pick.get("id", "")) != "ember":
		fails.append("unsunkSelf: ashwarden start deck should select ember, got %s"
			% str(ash_pick.get("id", ash_pick.get("error", ""))))
	var edited: RunState = RunState.new_run(content, 22043, "unsunk-edited")
	var removed: int = 0
	var kept: Array[CardInst] = []
	for card: CardInst in edited.player.deck:
		if String(card.id) == "strike" and removed < 3:
			removed += 1
			continue
		kept.append(card)
	edited.player.deck = kept
	var flipped: Dictionary = CounterfactualSelf.resolve(
		edited, content.enemy(&"unsunkSelf"), content)
	if str(flipped.get("id", "")) != "ember":
		fails.append("unsunkSelf: strike-light duskblade should select ember, got %s"
			% str(flipped.get("id", flipped.get("error", ""))))


static func _unsunk_fail_closed(content: ContentDB, fails: Array[String]) -> void:
	var empty: RunState = RunState.new_run(content, 22044, "unsunk-empty")
	empty.player.deck.clear()
	var none: Dictionary = CounterfactualSelf.resolve(
		empty, content.enemy(&"unsunkSelf"), content)
	if none.get("ok", false) == true:
		fails.append("unsunkSelf: empty deck emitted a kit")
	var cursed: Dictionary = content.enemy(&"unsunkSelf").duplicate(true)
	cursed["counterfactual"]["axisToKit"]["ember"] = "noSuchKit"
	var run: RunState = RunState.new_run(content, 22045, "unsunk-bad-kit")
	var bad: Dictionary = CounterfactualSelf.resolve(run, cursed, content)
	if bad.get("ok", false) == true:
		fails.append("unsunkSelf: unknown kit was emitted")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	content.enemies["unsunkSelf"] = cursed
	game.apply({"t": "startCombat", "enemies": ["unsunkSelf"], "kind": "elite"})
	if game.cb == null or not game.cb.enemies.is_empty():
		fails.append("unsunkSelf: invalid kit still entered combat")
	var restored: ContentDB = ContentDB.load_full()
	content.enemies["unsunkSelf"] = restored.enemy(&"unsunkSelf")


static func _unsunk_scenario(content: ContentDB, fails: Array[String]) -> void:
	var kernel: ScenarioKernel = ScenarioKernel.new(content, RUN_PATH, VIGIL_PATH, REF_PATH)
	kernel.clear_profile()
	var ref: ScenarioReference = ScenarioReference.new()
	if not ref.load_from({
		"id": "combat-unsunk-self", "revision": 1, "build": BUILD,
		"seed": 18501, "locale": "en", "shape": "pad-landscape",
		"overrides": {
			"act": 1, "node": "0,6", "kind": "elite",
			"enemies": ["unsunkSelf"],
		},
	}):
		fails.append("unsunkSelf: named Scenario rejected: %s" % ref.error)
		return
	var run: RunState = kernel.construct(ref)
	if run == null:
		fails.append("unsunkSelf: named Scenario failed: %s" % kernel.last_error)
		kernel.clear_profile()
		return
	if run.pending_enemy_ids != ["unsunkSelf"]:
		fails.append("unsunkSelf: Scenario did not freeze the II-prime elite")
	if str(run.pending_combat) != "elite":
		fails.append("unsunkSelf: Scenario did not freeze kind elite")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": run.pending_enemy_ids, "kind": "elite"})
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("unsunkSelf: startCombat dropped the II-prime elite")
		kernel.clear_profile()
		return
	var enemy: EnemyCombatant = game.cb.enemies[0]
	if enemy.elite != true or enemy.boss == true:
		fails.append("unsunkSelf: combatant was not elite-only")
	if str(enemy.flags.get(CounterfactualSelf.KIT_FLAG, "")) != "ash":
		fails.append("unsunkSelf: Scenario combat did not wear the ash kit")
	if String(enemy.move_key) != "stackWard":
		fails.append("unsunkSelf: ash kit first intent was %s" % String(enemy.move_key))
	if not UNSUNK_ASH.has(String(enemy.move_key)):
		fails.append("unsunkSelf: ash intent is not an ash kit move")
	kernel.clear_profile()


static func _unsunk_ai(fails: Array[String]) -> void:
	var rng: Rng = Rng.new(19)
	var before: int = rng.get_state()
	var flags: Dictionary = {CounterfactualSelf.KIT_FLAG: "ember"}
	for turn: int in range(1, 4):
		var move: StringName = EnemyAi.decide(
			&"unsunkSelf", turn, "", "", 1.0, rng, flags)
		if String(move) != UNSUNK_EMBER[turn - 1]:
			fails.append("unsunkSelf: ember turn %d expected %s got %s"
				% [turn, UNSUNK_EMBER[turn - 1], String(move)])
	if rng.get_state() != before:
		fails.append("unsunkSelf: AI consumed RNG")
	flags[CounterfactualSelf.KIT_FLAG] = "ash"
	for turn: int in range(1, 4):
		var move: StringName = EnemyAi.decide(
			&"unsunkSelf", turn, "", "", 1.0, rng, flags)
		if String(move) != UNSUNK_ASH[turn - 1]:
			fails.append("unsunkSelf: ash turn %d expected %s got %s"
				% [turn, UNSUNK_ASH[turn - 1], String(move)])
	var missing: StringName = EnemyAi.decide(&"unsunkSelf", 1, "", "", 1.0, rng, {})
	if missing != &"":
		fails.append("unsunkSelf: missing kit returned %s" % String(missing))


static func _node_share(content: ContentDB, fails: Array[String]) -> void:
	var water: Dictionary = content.enemy(&"uncrossedSelf").get("counterfactual", {})
	var stacks: Dictionary = content.enemy(&"unsunkSelf").get("counterfactual", {})
	if str(water.get("node", "")) != "II-prime" or str(stacks.get("node", "")) != "II-prime":
		fails.append("node: II-prime must seat both the normal and the elite")
	if str(water.get("axis", "")) != CounterfactualSelf.AXIS_STATUS_LEAN:
		fails.append("node: II-prime normal must keep statusLean")
	if str(stacks.get("axis", "")) != CounterfactualSelf.AXIS_DECK_TYPE:
		fails.append("node: II-prime elite must reuse deckType")
	if str(water.get("axis", "")) == str(stacks.get("axis", "")):
		fails.append("node: II-prime selves must not share an axis")
	var water_moves: Variant = water.get("kits", {})
	var stack_moves: Variant = stacks.get("kits", {})
	if str(water_moves) == str(stack_moves):
		fails.append("node: II-prime elite reused the normal kits")
	if CounterfactualSelf.axis_keys("costLean").size() != 0:
		fails.append("node: a third axis kind was registered")


static func _uncarved_row(content: ContentDB, fails: Array[String]) -> void:
	var def: Dictionary = content.enemy(&"uncarvedSelf")
	if def.is_empty() or not EnemyAi.handles(&"uncarvedSelf"):
		fails.append("uncarvedSelf: missing catalogue row or AI handler")
		return
	if not FileAccess.file_exists("res://assets/art/enemies/uncarvedSelf.png"):
		fails.append("uncarvedSelf: missing painting")
	if EnemyView.art_texture(&"uncarvedSelf") == null:
		fails.append("uncarvedSelf: painting did not import")
	if EnemyView.art_box(&"uncarvedSelf") < 230.0 * 1.4:
		fails.append("uncarvedSelf: elite combat box must stay at scale 1.4")
	if EnemyView.art_box(&"uncarvedSelf") <= EnemyView.art_box(&"unwalkedSelf"):
		fails.append("uncarvedSelf: elite must read larger than the tracer")
	if def.has("dialogue") or def.has("deathDialogue"):
		fails.append("uncarvedSelf: counterfactual selves must stay silent")
	if def.get("elite", false) != true:
		fails.append("uncarvedSelf: second elite must ship elite: true")
	if def.get("boss", false) == true:
		fails.append("uncarvedSelf: elite must not also be a boss")
	var spec: Dictionary = def.get("counterfactual", {})
	if str(spec.get("node", "")) != "threshold-prime" \
			or str(spec.get("motif", "")) != "seal-relief":
		fails.append("uncarvedSelf: node/motif must stay on threshold-prime / seal-relief")
	if str(spec.get("axis", "")) != CounterfactualSelf.AXIS_STATUS_LEAN:
		fails.append("uncarvedSelf: axis must reuse statusLean")
	if str(def.get("name", "")).contains("Unopened"):
		fails.append("uncarvedSelf: display name collides with 【The Unopened】")
	var hp_v: Variant = def.get("hp", [])
	if str(hp_v) == str(content.enemy(&"unopenedSelf").get("hp", [])) \
			or str(hp_v) == str(content.enemy(&"unsunkSelf").get("hp", [])):
		fails.append("uncarvedSelf: HP range cloned a seated self")
	var banned: PackedStringArray = PackedStringArray([
		"Uncut", "Unread", "Unwaited", "Tide", "Unopened", "Unclosed", "Unwoken", "Door",
	])
	var moves: Dictionary = def.get("moves", {})
	for move_id_v: Variant in moves.keys():
		var move_name: String = str(moves[move_id_v].get("name", ""))
		for word: String in banned:
			if move_name.contains(word):
				fails.append("uncarvedSelf: %s display collides on '%s'"
					% [str(move_id_v), word])
	var once: PackedStringArray = PackedStringArray(["Stone", "Stamp", "Seal"])
	for word: String in once:
		var hits: int = 0
		for move_id_v: Variant in moves.keys():
			if str(moves[move_id_v].get("name", "")).contains(word):
				hits += 1
		if hits > 1:
			fails.append("uncarvedSelf: '%s' crowds %d move names" % [word, hits])
	var pane_fx: Variant = content.enemy(&"unopenedSelf")["moves"]["darkPane"].get("fx", [])
	var stamp_row: Dictionary = def["moves"]["darkStamp"]
	if str(stamp_row.get("fx", [])) == str(pane_fx):
		fails.append("uncarvedSelf: darkStamp cloned darkPane's debuff")
	var faults: PackedStringArray = content.enemy_faults("uncarvedSelf", def)
	if not faults.is_empty():
		fails.append("uncarvedSelf: authored row failed validation: %s" % faults[0])
	var broken_move: Dictionary = def.duplicate(true)
	var kits: Dictionary = broken_move["counterfactual"]["kits"]
	kits["carve"] = ["notAMove"]
	if content.enemy_faults("uncarvedSelf", broken_move).is_empty():
		fails.append("uncarvedSelf: unknown kit move was accepted")
	var broken: Dictionary = def.duplicate(true)
	broken["counterfactual"]["axis"] = "noSuchAxis"
	if content.enemy_faults("uncarvedSelf", broken).is_empty():
		fails.append("uncarvedSelf: unknown axis was accepted")
	var wrong_keys: Dictionary = def.duplicate(true)
	wrong_keys["counterfactual"]["axisToKit"] = {"ember": "carve", "ash": "door"}
	if content.enemy_faults("uncarvedSelf", wrong_keys).is_empty():
		fails.append("uncarvedSelf: deckType keys were accepted on statusLean")
	var third: Dictionary = def.duplicate(true)
	third["counterfactual"]["axis"] = "costLean"
	if content.enemy_faults("uncarvedSelf", third).is_empty():
		fails.append("uncarvedSelf: a third axis was accepted")
	var both: Dictionary = def.duplicate(true)
	both["boss"] = true
	if content.enemy_faults("uncarvedSelf", both).is_empty():
		fails.append("uncarvedSelf: elite+boss was accepted")


static func _uncarved_kit(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = RunState.new_run(content, 22051, "uncarved-dusk")
	var picked: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"uncarvedSelf"), content)
	if picked.get("ok", false) != true or str(picked.get("id", "")) != "carve":
		fails.append("uncarvedSelf: duskblade start deck should select carve, got %s"
			% str(picked.get("id", picked.get("error", ""))))
	var again: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"uncarvedSelf"), content)
	if str(again.get("id", "")) != str(picked.get("id", "")):
		fails.append("uncarvedSelf: identical deck produced a different kit")


static func _uncarved_flips(content: ContentDB, fails: Array[String]) -> void:
	var ash_run: RunState = RunState.new_run(content, 22052, "uncarved-ashwarden", {"aspect": 1})
	var ash_pick: Dictionary = CounterfactualSelf.resolve(
		ash_run, content.enemy(&"uncarvedSelf"), content)
	if str(ash_pick.get("id", "")) != "door":
		fails.append("uncarvedSelf: ashwarden start deck should select door, got %s"
			% str(ash_pick.get("id", ash_pick.get("error", ""))))
	var edited: RunState = RunState.new_run(content, 22053, "uncarved-edited")
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
		edited, content.enemy(&"uncarvedSelf"), content)
	if str(flipped.get("id", "")) != "door":
		fails.append("uncarvedSelf: toxin-heavy duskblade should select door, got %s"
			% str(flipped.get("id", flipped.get("error", ""))))


static func _uncarved_fail_closed(content: ContentDB, fails: Array[String]) -> void:
	var empty: RunState = RunState.new_run(content, 22054, "uncarved-empty")
	empty.player.deck.clear()
	var none: Dictionary = CounterfactualSelf.resolve(
		empty, content.enemy(&"uncarvedSelf"), content)
	if none.get("ok", false) == true:
		fails.append("uncarvedSelf: empty deck emitted a kit")
	var dry: RunState = RunState.new_run(content, 22055, "uncarved-dry")
	var strikes: Array[CardInst] = []
	for card: CardInst in dry.player.deck:
		if String(card.id) == "strike":
			strikes.append(card)
	dry.player.deck = strikes
	var dry_pick: Dictionary = CounterfactualSelf.resolve(
		dry, content.enemy(&"uncarvedSelf"), content)
	if dry_pick.get("ok", false) == true:
		fails.append("uncarvedSelf: strike-only deck emitted a kit")
	var cursed: Dictionary = content.enemy(&"uncarvedSelf").duplicate(true)
	cursed["counterfactual"]["axisToKit"]["ward"] = "noSuchKit"
	var run: RunState = RunState.new_run(content, 22056, "uncarved-bad-kit")
	var bad: Dictionary = CounterfactualSelf.resolve(run, cursed, content)
	if bad.get("ok", false) == true:
		fails.append("uncarvedSelf: unknown kit was emitted")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	content.enemies["uncarvedSelf"] = cursed
	game.apply({"t": "startCombat", "enemies": ["uncarvedSelf"], "kind": "elite"})
	if game.cb == null or not game.cb.enemies.is_empty():
		fails.append("uncarvedSelf: invalid kit still entered combat")
	var restored: ContentDB = ContentDB.load_full()
	content.enemies["uncarvedSelf"] = restored.enemy(&"uncarvedSelf")


static func _uncarved_scenario(content: ContentDB, fails: Array[String]) -> void:
	var kernel: ScenarioKernel = ScenarioKernel.new(content, RUN_PATH, VIGIL_PATH, REF_PATH)
	kernel.clear_profile()
	var ref: ScenarioReference = ScenarioReference.new()
	if not ref.load_from({
		"id": "combat-uncarved-self", "revision": 1, "build": BUILD,
		"seed": 18501, "locale": "en", "shape": "pad-landscape",
		"overrides": {
			"act": 0, "node": "6,3", "kind": "elite",
			"enemies": ["uncarvedSelf"],
		},
	}):
		fails.append("uncarvedSelf: named Scenario rejected: %s" % ref.error)
		return
	var run: RunState = kernel.construct(ref)
	if run == null:
		fails.append("uncarvedSelf: named Scenario failed: %s" % kernel.last_error)
		kernel.clear_profile()
		return
	if run.pending_enemy_ids != ["uncarvedSelf"]:
		fails.append("uncarvedSelf: Scenario did not freeze the threshold-prime elite")
	if str(run.pending_combat) != "elite":
		fails.append("uncarvedSelf: Scenario did not freeze kind elite")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": run.pending_enemy_ids, "kind": "elite"})
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("uncarvedSelf: startCombat dropped the threshold-prime elite")
		kernel.clear_profile()
		return
	var enemy: EnemyCombatant = game.cb.enemies[0]
	if enemy.elite != true or enemy.boss == true:
		fails.append("uncarvedSelf: combatant was not elite-only")
	if str(enemy.flags.get(CounterfactualSelf.KIT_FLAG, "")) != "carve":
		fails.append("uncarvedSelf: Scenario combat did not wear the carve kit")
	if String(enemy.move_key) != "stoneCut":
		fails.append("uncarvedSelf: carve kit first intent was %s" % String(enemy.move_key))
	if not CARVE_MOVES.has(String(enemy.move_key)):
		fails.append("uncarvedSelf: carve intent is not a carve kit move")
	kernel.clear_profile()


static func _uncarved_ai(fails: Array[String]) -> void:
	var rng: Rng = Rng.new(23)
	var before: int = rng.get_state()
	var flags: Dictionary = {CounterfactualSelf.KIT_FLAG: "carve"}
	for turn: int in range(1, 4):
		var move: StringName = EnemyAi.decide(
			&"uncarvedSelf", turn, "", "", 1.0, rng, flags)
		if String(move) != CARVE_MOVES[turn - 1]:
			fails.append("uncarvedSelf: carve turn %d expected %s got %s"
				% [turn, CARVE_MOVES[turn - 1], String(move)])
	if rng.get_state() != before:
		fails.append("uncarvedSelf: AI consumed RNG")
	flags[CounterfactualSelf.KIT_FLAG] = "door"
	for turn: int in range(1, 4):
		var move: StringName = EnemyAi.decide(
			&"uncarvedSelf", turn, "", "", 1.0, rng, flags)
		if String(move) != DOOR_MOVES[turn - 1]:
			fails.append("uncarvedSelf: door turn %d expected %s got %s"
				% [turn, DOOR_MOVES[turn - 1], String(move)])
	var missing: StringName = EnemyAi.decide(&"uncarvedSelf", 1, "", "", 1.0, rng, {})
	if missing != &"":
		fails.append("uncarvedSelf: missing kit returned %s" % String(missing))


static func _threshold_share(content: ContentDB, fails: Array[String]) -> void:
	var glass: Dictionary = content.enemy(&"unopenedSelf").get("counterfactual", {})
	var seal: Dictionary = content.enemy(&"uncarvedSelf").get("counterfactual", {})
	if str(glass.get("node", "")) != "threshold-prime" \
			or str(seal.get("node", "")) != "threshold-prime":
		fails.append("threshold: must seat both the normal and the elite")
	if str(glass.get("axis", "")) != CounterfactualSelf.AXIS_DECK_TYPE:
		fails.append("threshold: normal must keep deckType")
	if str(seal.get("axis", "")) != CounterfactualSelf.AXIS_STATUS_LEAN:
		fails.append("threshold: elite must reuse statusLean")
	if str(glass.get("axis", "")) == str(seal.get("axis", "")):
		fails.append("threshold: selves must not share an axis")
	var glass_moves: Variant = glass.get("kits", {})
	var seal_moves: Variant = seal.get("kits", {})
	if str(glass_moves) == str(seal_moves):
		fails.append("threshold: elite reused the normal kits")
	if CounterfactualSelf.axis_keys("costLean").size() != 0:
		fails.append("threshold: a third axis kind was registered")


static func _unobsidian_row(content: ContentDB, fails: Array[String]) -> void:
	var def: Dictionary = content.enemy(&"unobsidianSelf")
	if def.is_empty() or not EnemyAi.handles(&"unobsidianSelf"):
		fails.append("unobsidianSelf: missing catalogue row or AI handler")
		return
	if def.has("dialogue") or def.has("deathDialogue"):
		fails.append("unobsidianSelf: counterfactual selves must stay silent")
	if def.get("elite", false) == true or def.get("boss", false) == true:
		fails.append("unobsidianSelf: remaining normal must not be elite or boss")
	var spec: Dictionary = def.get("counterfactual", {})
	if str(spec.get("node", "")) != "III-prime" \
			or str(spec.get("motif", "")) != "obsidian-star":
		fails.append("unobsidianSelf: node/motif must stay on III-prime / obsidian-star")
	if str(spec.get("axis", "")) != CounterfactualSelf.AXIS_STATUS_LEAN:
		fails.append("unobsidianSelf: axis must reuse statusLean")
	if str(def.get("name", "")).contains("Unwalked"):
		fails.append("unobsidianSelf: display name collides with 【The Unwalked】")
	var hp_v: Variant = def.get("hp", [])
	if str(hp_v) == str(content.enemy(&"unwalkedSelf").get("hp", [])):
		fails.append("unobsidianSelf: HP range cloned the III-prime deckType self")
	var banned: PackedStringArray = PackedStringArray([
		"Uncut", "Unread", "Unwaited", "Tide", "Unopened", "Unclosed", "Unwoken",
		"Door", "Ring", "Halo", "Seat", "Scepter", "Stars", "Uncalled", "Unsaid",
		"Fall",
	])
	var moves: Dictionary = def.get("moves", {})
	for move_id_v: Variant in moves.keys():
		var move_name: String = str(moves[move_id_v].get("name", ""))
		for word: String in banned:
			if move_name.contains(word):
				fails.append("unobsidianSelf: %s display collides on '%s'"
					% [str(move_id_v), word])
	var once: PackedStringArray = PackedStringArray(["Star", "Glass", "Court", "Eye"])
	for word: String in once:
		var hits: int = 0
		for move_id_v: Variant in moves.keys():
			if str(moves[move_id_v].get("name", "")).contains(word):
				hits += 1
		if hits > 1:
			fails.append("unobsidianSelf: '%s' crowds %d move names" % [word, hits])
	var root_fx: Variant = content.enemy(&"unlitSelf")["moves"]["stillRoot"].get("fx", [])
	var harden_row: Dictionary = def["moves"]["darkHarden"]
	if str(harden_row.get("fx", [])) == str(root_fx):
		fails.append("unobsidianSelf: darkHarden cloned stillRoot's debuff")
	var wick_fx: Variant = content.enemy(&"unlitSelf")["moves"]["wickUnlit"].get("fx", [])
	if str(harden_row.get("fx", [])) == str(wick_fx):
		fails.append("unobsidianSelf: darkHarden cloned wickUnlit's debuff")
	var faults: PackedStringArray = content.enemy_faults("unobsidianSelf", def)
	if not faults.is_empty():
		fails.append("unobsidianSelf: authored row failed validation: %s" % faults[0])
	var broken_move: Dictionary = def.duplicate(true)
	var kits: Dictionary = broken_move["counterfactual"]["kits"]
	kits["star"] = ["notAMove"]
	if content.enemy_faults("unobsidianSelf", broken_move).is_empty():
		fails.append("unobsidianSelf: unknown kit move was accepted")
	var broken: Dictionary = def.duplicate(true)
	broken["counterfactual"]["axis"] = "noSuchAxis"
	if content.enemy_faults("unobsidianSelf", broken).is_empty():
		fails.append("unobsidianSelf: unknown axis was accepted")
	var wrong_keys: Dictionary = def.duplicate(true)
	wrong_keys["counterfactual"]["axisToKit"] = {"ember": "star", "ash": "obsidian"}
	if content.enemy_faults("unobsidianSelf", wrong_keys).is_empty():
		fails.append("unobsidianSelf: deckType keys were accepted on statusLean")
	var third: Dictionary = def.duplicate(true)
	third["counterfactual"]["axis"] = "costLean"
	if content.enemy_faults("unobsidianSelf", third).is_empty():
		fails.append("unobsidianSelf: a third axis was accepted")


static func _unobsidian_kit(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = RunState.new_run(content, 22061, "unobsidian-dusk")
	var picked: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"unobsidianSelf"), content)
	if picked.get("ok", false) != true or str(picked.get("id", "")) != "star":
		fails.append("unobsidianSelf: duskblade start deck should select star, got %s"
			% str(picked.get("id", picked.get("error", ""))))
	var again: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"unobsidianSelf"), content)
	if str(again.get("id", "")) != str(picked.get("id", "")):
		fails.append("unobsidianSelf: identical deck produced a different kit")


static func _unobsidian_flips(content: ContentDB, fails: Array[String]) -> void:
	var ash_run: RunState = RunState.new_run(content, 22062, "unobsidian-ashwarden", {"aspect": 1})
	var ash_pick: Dictionary = CounterfactualSelf.resolve(
		ash_run, content.enemy(&"unobsidianSelf"), content)
	if str(ash_pick.get("id", "")) != "obsidian":
		fails.append("unobsidianSelf: ashwarden start deck should select obsidian, got %s"
			% str(ash_pick.get("id", ash_pick.get("error", ""))))
	var edited: RunState = RunState.new_run(content, 22063, "unobsidian-edited")
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
		edited, content.enemy(&"unobsidianSelf"), content)
	if str(flipped.get("id", "")) != "obsidian":
		fails.append("unobsidianSelf: toxin-heavy duskblade should select obsidian, got %s"
			% str(flipped.get("id", flipped.get("error", ""))))


static func _unobsidian_fail_closed(content: ContentDB, fails: Array[String]) -> void:
	var empty: RunState = RunState.new_run(content, 22064, "unobsidian-empty")
	empty.player.deck.clear()
	var none: Dictionary = CounterfactualSelf.resolve(
		empty, content.enemy(&"unobsidianSelf"), content)
	if none.get("ok", false) == true:
		fails.append("unobsidianSelf: empty deck emitted a kit")
	var dry: RunState = RunState.new_run(content, 22065, "unobsidian-dry")
	var strikes: Array[CardInst] = []
	for card: CardInst in dry.player.deck:
		if String(card.id) == "strike":
			strikes.append(card)
	dry.player.deck = strikes
	var dry_pick: Dictionary = CounterfactualSelf.resolve(
		dry, content.enemy(&"unobsidianSelf"), content)
	if dry_pick.get("ok", false) == true:
		fails.append("unobsidianSelf: strike-only deck emitted a kit")
	var cursed: Dictionary = content.enemy(&"unobsidianSelf").duplicate(true)
	cursed["counterfactual"]["axisToKit"]["ward"] = "noSuchKit"
	var run: RunState = RunState.new_run(content, 22066, "unobsidian-bad-kit")
	var bad: Dictionary = CounterfactualSelf.resolve(run, cursed, content)
	if bad.get("ok", false) == true:
		fails.append("unobsidianSelf: unknown kit was emitted")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	content.enemies["unobsidianSelf"] = cursed
	game.apply({"t": "startCombat", "enemies": ["unobsidianSelf"], "kind": "normal"})
	if game.cb == null or not game.cb.enemies.is_empty():
		fails.append("unobsidianSelf: invalid kit still entered combat")
	var restored: ContentDB = ContentDB.load_full()
	content.enemies["unobsidianSelf"] = restored.enemy(&"unobsidianSelf")


static func _unobsidian_scenario(content: ContentDB, fails: Array[String]) -> void:
	var kernel: ScenarioKernel = ScenarioKernel.new(content, RUN_PATH, VIGIL_PATH, REF_PATH)
	kernel.clear_profile()
	var ref: ScenarioReference = ScenarioReference.new()
	if not ref.load_from({
		"id": "combat-unobsidian-self", "revision": 1, "build": BUILD,
		"seed": 18501, "locale": "en", "shape": "pad-landscape",
		"overrides": {
			"act": 2, "node": "0,6", "kind": "monster",
			"enemies": ["unobsidianSelf"],
		},
	}):
		fails.append("unobsidianSelf: named Scenario rejected: %s" % ref.error)
		return
	var run: RunState = kernel.construct(ref)
	if run == null:
		fails.append("unobsidianSelf: named Scenario failed: %s" % kernel.last_error)
		kernel.clear_profile()
		return
	if run.pending_enemy_ids != ["unobsidianSelf"]:
		fails.append("unobsidianSelf: Scenario did not freeze the III-prime self")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": run.pending_enemy_ids, "kind": "normal"})
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("unobsidianSelf: startCombat dropped the III-prime self")
		kernel.clear_profile()
		return
	var enemy: EnemyCombatant = game.cb.enemies[0]
	if str(enemy.flags.get(CounterfactualSelf.KIT_FLAG, "")) != "star":
		fails.append("unobsidianSelf: Scenario combat did not wear the star kit")
	if String(enemy.move_key) != "starGaze":
		fails.append("unobsidianSelf: star kit first intent was %s" % String(enemy.move_key))
	if not STAR_MOVES.has(String(enemy.move_key)):
		fails.append("unobsidianSelf: star intent is not a star kit move")
	kernel.clear_profile()


static func _unobsidian_ai(fails: Array[String]) -> void:
	var rng: Rng = Rng.new(23)
	var before: int = rng.get_state()
	var flags: Dictionary = {CounterfactualSelf.KIT_FLAG: "star"}
	for turn: int in range(1, 4):
		var move: StringName = EnemyAi.decide(
			&"unobsidianSelf", turn, "", "", 1.0, rng, flags)
		if String(move) != STAR_MOVES[turn - 1]:
			fails.append("unobsidianSelf: star turn %d expected %s got %s"
				% [turn, STAR_MOVES[turn - 1], String(move)])
	if rng.get_state() != before:
		fails.append("unobsidianSelf: AI consumed RNG")
	flags[CounterfactualSelf.KIT_FLAG] = "obsidian"
	for turn: int in range(1, 4):
		var move: StringName = EnemyAi.decide(
			&"unobsidianSelf", turn, "", "", 1.0, rng, flags)
		if String(move) != OBSIDIAN_MOVES[turn - 1]:
			fails.append("unobsidianSelf: obsidian turn %d expected %s got %s"
				% [turn, OBSIDIAN_MOVES[turn - 1], String(move)])
	var missing: StringName = EnemyAi.decide(&"unobsidianSelf", 1, "", "", 1.0, rng, {})
	if missing != &"":
		fails.append("unobsidianSelf: missing kit returned %s" % String(missing))


static func _iii_share(content: ContentDB, fails: Array[String]) -> void:
	var ring: Dictionary = content.enemy(&"unwalkedSelf").get("counterfactual", {})
	var star: Dictionary = content.enemy(&"unobsidianSelf").get("counterfactual", {})
	if str(ring.get("node", "")) != "III-prime" or str(star.get("node", "")) != "III-prime":
		fails.append("iii: must seat both the deckType and the statusLean self")
	if str(ring.get("axis", "")) != CounterfactualSelf.AXIS_DECK_TYPE:
		fails.append("iii: broken-ring must keep deckType")
	if str(star.get("axis", "")) != CounterfactualSelf.AXIS_STATUS_LEAN:
		fails.append("iii: obsidian-star must reuse statusLean")
	if str(ring.get("axis", "")) == str(star.get("axis", "")):
		fails.append("iii: selves must not share an axis")
	var ring_moves: Variant = ring.get("kits", {})
	var star_moves: Variant = star.get("kits", {})
	if str(ring_moves) == str(star_moves):
		fails.append("iii: statusLean self reused the deckType kits")
	if CounterfactualSelf.axis_keys("costLean").size() != 0:
		fails.append("iii: a third axis kind was registered")


static func _unwooded_row(content: ContentDB, fails: Array[String]) -> void:
	var def: Dictionary = content.enemy(&"unwoodedSelf")
	if def.is_empty() or not EnemyAi.handles(&"unwoodedSelf"):
		fails.append("unwoodedSelf: missing catalogue row or AI handler")
		return
	if def.has("dialogue") or def.has("deathDialogue"):
		fails.append("unwoodedSelf: counterfactual selves must stay silent")
	if def.get("elite", false) == true or def.get("boss", false) == true:
		fails.append("unwoodedSelf: remaining normal must not be elite or boss")
	var spec: Dictionary = def.get("counterfactual", {})
	if str(spec.get("node", "")) != "I-prime" or str(spec.get("motif", "")) != "ash-root":
		fails.append("unwoodedSelf: node/motif must stay on I-prime / ash-root")
	if str(spec.get("axis", "")) != CounterfactualSelf.AXIS_DECK_TYPE:
		fails.append("unwoodedSelf: axis must reuse deckType")
	if str(def.get("name", "")).contains("Unstruck") or str(def.get("name", "")).contains("Unlit"):
		fails.append("unwoodedSelf: display name collides with the I-prime lantern self")
	var hp_v: Variant = def.get("hp", [])
	if str(hp_v) == str(content.enemy(&"unlitSelf").get("hp", [])):
		fails.append("unwoodedSelf: HP range cloned the I-prime statusLean self")
	if str(hp_v) == str(content.enemy(&"unopenedSelf").get("hp", [])):
		fails.append("unwoodedSelf: HP range cloned the threshold-prime normal")
	var banned: PackedStringArray = PackedStringArray([
		"Root", "Ash", "Uncut", "Unscattered", "Unstruck", "Unburned",
		"Lamp", "Wick", "Pair", "Unwalked", "Tide", "Door", "Ring", "Halo",
		"Star", "Court", "Stone", "Seal", "Fall", "Unread",
	])
	var moves: Dictionary = def.get("moves", {})
	for move_id_v: Variant in moves.keys():
		var move_name: String = str(moves[move_id_v].get("name", ""))
		for word: String in banned:
			if move_name.contains(word):
				fails.append("unwoodedSelf: %s display collides on '%s'"
					% [str(move_id_v), word])
	var once: PackedStringArray = PackedStringArray([
		"Branch", "Road", "Wood", "Rest", "Cinder", "Grove",
	])
	for word: String in once:
		var hits: int = 0
		for move_id_v: Variant in moves.keys():
			if str(moves[move_id_v].get("name", "")).contains(word):
				hits += 1
		if hits != 1:
			fails.append("unwoodedSelf: '%s' crowds %d move names" % [word, hits])
	var hush_fx: Variant = def["moves"]["cinderHush"].get("fx", [])
	var root_fx: Variant = content.enemy(&"unlitSelf")["moves"]["rootLash"].get("fx", [])
	if str(hush_fx) == str(root_fx) and def["moves"]["cinderHush"].has("dmg"):
		fails.append("unwoodedSelf: cinderHush cloned rootLash")
	if def["moves"]["cinderHush"].has("dmg"):
		fails.append("unwoodedSelf: cinderHush must stay a pure debuff")
	var still_fx: Variant = content.enemy(&"unlitSelf")["moves"]["stillRoot"].get("fx", [])
	if str(hush_fx) == str(still_fx):
		fails.append("unwoodedSelf: cinderHush cloned stillRoot's debuff")
	var wick_fx: Variant = content.enemy(&"unlitSelf")["moves"]["wickUnlit"].get("fx", [])
	if str(hush_fx) == str(wick_fx):
		fails.append("unwoodedSelf: cinderHush cloned wickUnlit's debuff")
	var ward_name: String = str(def["moves"]["woodWard"].get("name", ""))
	if ward_name.contains("Wood"):
		fails.append("unwoodedSelf: woodWard English must not say Wood")
	var faults: PackedStringArray = content.enemy_faults("unwoodedSelf", def)
	if not faults.is_empty():
		fails.append("unwoodedSelf: authored row failed validation: %s" % faults[0])
	var broken: Dictionary = def.duplicate(true)
	var kits: Dictionary = broken["counterfactual"]["kits"]
	kits["ember"] = ["notAMove"]
	if content.enemy_faults("unwoodedSelf", broken).is_empty():
		fails.append("unwoodedSelf: unknown kit move was accepted")
	var third: Dictionary = def.duplicate(true)
	third["counterfactual"]["axis"] = "costLean"
	if content.enemy_faults("unwoodedSelf", third).is_empty():
		fails.append("unwoodedSelf: a third axis was accepted")


static func _unwooded_kit(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = RunState.new_run(content, 22071, "unwooded-dusk")
	var picked: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"unwoodedSelf"), content)
	if picked.get("ok", false) != true or str(picked.get("id", "")) != "ash":
		fails.append("unwoodedSelf: duskblade start deck should select ash, got %s"
			% str(picked.get("id", picked.get("error", ""))))
	var again: Dictionary = CounterfactualSelf.resolve(
		run, content.enemy(&"unwoodedSelf"), content)
	if str(again.get("id", "")) != str(picked.get("id", "")):
		fails.append("unwoodedSelf: identical deck produced a different kit")


static func _unwooded_flips(content: ContentDB, fails: Array[String]) -> void:
	var ash_run: RunState = RunState.new_run(content, 22072, "unwooded-ashwarden", {"aspect": 1})
	var ash_pick: Dictionary = CounterfactualSelf.resolve(
		ash_run, content.enemy(&"unwoodedSelf"), content)
	if str(ash_pick.get("id", "")) != "ember":
		fails.append("unwoodedSelf: ashwarden start deck should select ember, got %s"
			% str(ash_pick.get("id", ash_pick.get("error", ""))))
	var edited: RunState = RunState.new_run(content, 22073, "unwooded-edited")
	var removed: int = 0
	var kept: Array[CardInst] = []
	for card: CardInst in edited.player.deck:
		if String(card.id) == "strike" and removed < 3:
			removed += 1
			continue
		kept.append(card)
	edited.player.deck = kept
	var flipped: Dictionary = CounterfactualSelf.resolve(
		edited, content.enemy(&"unwoodedSelf"), content)
	if str(flipped.get("id", "")) != "ember":
		fails.append("unwoodedSelf: strike-light duskblade should select ember, got %s"
			% str(flipped.get("id", flipped.get("error", ""))))


static func _unwooded_fail_closed(content: ContentDB, fails: Array[String]) -> void:
	var empty: RunState = RunState.new_run(content, 22074, "unwooded-empty")
	empty.player.deck.clear()
	var none: Dictionary = CounterfactualSelf.resolve(
		empty, content.enemy(&"unwoodedSelf"), content)
	if none.get("ok", false) == true:
		fails.append("unwoodedSelf: empty deck emitted a kit")
	var cursed: Dictionary = content.enemy(&"unwoodedSelf").duplicate(true)
	cursed["counterfactual"]["axisToKit"]["ember"] = "noSuchKit"
	var run: RunState = RunState.new_run(content, 22075, "unwooded-bad-kit")
	var bad: Dictionary = CounterfactualSelf.resolve(run, cursed, content)
	if bad.get("ok", false) == true:
		fails.append("unwoodedSelf: unknown kit was emitted")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	content.enemies["unwoodedSelf"] = cursed
	game.apply({"t": "startCombat", "enemies": ["unwoodedSelf"], "kind": "normal"})
	if game.cb == null or not game.cb.enemies.is_empty():
		fails.append("unwoodedSelf: invalid kit still entered combat")
	var restored: ContentDB = ContentDB.load_full()
	content.enemies["unwoodedSelf"] = restored.enemy(&"unwoodedSelf")


static func _unwooded_scenario(content: ContentDB, fails: Array[String]) -> void:
	var kernel: ScenarioKernel = ScenarioKernel.new(content, RUN_PATH, VIGIL_PATH, REF_PATH)
	kernel.clear_profile()
	var ref: ScenarioReference = ScenarioReference.new()
	if not ref.load_from({
		"id": "combat-unwooded-self", "revision": 1, "build": BUILD,
		"seed": 18501, "locale": "en", "shape": "pad-landscape",
		"overrides": {
			"act": 0, "node": "1,2", "kind": "monster",
			"enemies": ["unwoodedSelf"],
		},
	}):
		fails.append("unwoodedSelf: named Scenario rejected: %s" % ref.error)
		return
	var run: RunState = kernel.construct(ref)
	if run == null:
		fails.append("unwoodedSelf: named Scenario failed: %s" % kernel.last_error)
		kernel.clear_profile()
		return
	if run.pending_enemy_ids != ["unwoodedSelf"]:
		fails.append("unwoodedSelf: Scenario did not freeze the I-prime enemy")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": run.pending_enemy_ids, "kind": "normal"})
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("unwoodedSelf: startCombat dropped the I-prime self")
		kernel.clear_profile()
		return
	var enemy: EnemyCombatant = game.cb.enemies[0]
	if str(enemy.flags.get(CounterfactualSelf.KIT_FLAG, "")) != "ash":
		fails.append("unwoodedSelf: Scenario combat did not wear the ash kit")
	if String(enemy.move_key) != "woodWard":
		fails.append("unwoodedSelf: ash kit first intent was %s" % String(enemy.move_key))
	if not WOOD_ASH.has(String(enemy.move_key)):
		fails.append("unwoodedSelf: ash intent is not an ash kit move")
	kernel.clear_profile()


static func _unwooded_ai(fails: Array[String]) -> void:
	var rng: Rng = Rng.new(19)
	var before: int = rng.get_state()
	for turn: int in range(1, 4):
		var flags: Dictionary = {CounterfactualSelf.KIT_FLAG: "ember"}
		var move: StringName = EnemyAi.decide(
			&"unwoodedSelf", turn, "", "", 1.0, rng, flags)
		if String(move) != WOOD_EMBER[turn - 1]:
			fails.append("unwoodedSelf: ember turn %d expected %s got %s"
				% [turn, WOOD_EMBER[turn - 1], String(move)])
	if rng.get_state() != before:
		fails.append("unwoodedSelf: AI consumed RNG")
	for turn: int in range(1, 4):
		var flags: Dictionary = {CounterfactualSelf.KIT_FLAG: "ash"}
		var move: StringName = EnemyAi.decide(
			&"unwoodedSelf", turn, "", "", 1.0, rng, flags)
		if String(move) != WOOD_ASH[turn - 1]:
			fails.append("unwoodedSelf: ash turn %d expected %s got %s"
				% [turn, WOOD_ASH[turn - 1], String(move)])
	var missing: StringName = EnemyAi.decide(&"unwoodedSelf", 1, "", "", 1.0, rng, {})
	if missing != &"":
		fails.append("unwoodedSelf: missing kit returned %s" % String(missing))


static func _i_share(content: ContentDB, fails: Array[String]) -> void:
	var lamps: Dictionary = content.enemy(&"unlitSelf").get("counterfactual", {})
	var wood: Dictionary = content.enemy(&"unwoodedSelf").get("counterfactual", {})
	if str(lamps.get("node", "")) != "I-prime" or str(wood.get("node", "")) != "I-prime":
		fails.append("i: must seat both the statusLean and the deckType self")
	if str(lamps.get("axis", "")) != CounterfactualSelf.AXIS_STATUS_LEAN:
		fails.append("i: paired-lanterns must keep statusLean")
	if str(wood.get("axis", "")) != CounterfactualSelf.AXIS_DECK_TYPE:
		fails.append("i: ash-root must reuse deckType")
	if str(lamps.get("axis", "")) == str(wood.get("axis", "")):
		fails.append("i: selves must not share an axis")
	var lamp_moves: Variant = lamps.get("kits", {})
	var wood_moves: Variant = wood.get("kits", {})
	if str(lamp_moves) == str(wood_moves):
		fails.append("i: deckType self reused the statusLean kits")
	if CounterfactualSelf.axis_keys("costLean").size() != 0:
		fails.append("i: a third axis kind was registered")
