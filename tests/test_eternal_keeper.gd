extends RefCounted
## Slice 3 — Eternal Keeper. Twin of Sovereign's cycle; lethal damage hands off.

const RUN_PATH: String = "user://glassvow_test_keeper_run_v2.json"
const VIGIL_PATH: String = "user://glassvow_test_keeper_vigil_v2.json"
const REF_PATH: String = "user://glassvow_test_keeper_scenario.json"
const BUILD: String = "test-keeper-sha"
const PHASE1: Array[String] = ["hearthBlow", "sitDown", "cinderFall", "kindWord"]


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	_content_row(content, fails)
	_silent(content, fails)
	_ai_cycle(fails)
	_handoff_hit(content, fails)
	_handoff_poison(content, fails)
	_sovereign_still_dies(content, fails)
	_scenario(content, fails)


static func _content_row(content: ContentDB, fails: Array[String]) -> void:
	var def: Dictionary = content.enemy(&"eternalKeeper")
	if def.is_empty() or not EnemyAi.handles(&"eternalKeeper"):
		fails.append("eternalKeeper: missing catalogue row or AI handler")
		return
	if def.get("boss", false) != true or def.get("finaleHandoff", false) != true:
		fails.append("eternalKeeper: must be a boss with finaleHandoff")
	if def.has("dialogue") or def.has("deathDialogue"):
		fails.append("eternalKeeper: combat must stay silent; reveal is #312")
	var faults: PackedStringArray = content.enemy_faults("eternalKeeper", def)
	if not faults.is_empty():
		fails.append("eternalKeeper: authored row failed validation: %s" % faults[0])
	var broken: Dictionary = def.duplicate(true)
	broken["finaleHandoff"] = true
	broken["boss"] = false
	if content.enemy_faults("eternalKeeper", broken).is_empty():
		fails.append("eternalKeeper: finaleHandoff on a non-boss was accepted")
	var cost_stub: Dictionary = content.enemy(&"sporeling").duplicate(true)
	cost_stub["finaleHandoff"] = true
	if content.enemy_faults("sporeling", cost_stub).is_empty():
		fails.append("eternalKeeper: a normal enemy was allowed to hand off")


static func _silent(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = RunState.new_run(content, 22040, "keeper-silent")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	var events: Array[Dictionary] = game.apply({
		"t": "startCombat", "enemies": ["eternalKeeper"], "kind": "boss",
	})
	for ev: Dictionary in events:
		if ev.get("t") == EventTypes.VARIANT_DIALOGUE:
			fails.append("eternalKeeper: startCombat emitted variant dialogue")
			return
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("eternalKeeper: startCombat dropped the boss")
		return
	if String(game.cb.enemies[0].key) != "eternalKeeper":
		fails.append("eternalKeeper: startCombat seated the wrong enemy")


static func _ai_cycle(fails: Array[String]) -> void:
	var rng: Rng = Rng.new(7)
	var before: int = rng.get_state()
	var flags: Dictionary = {}
	for turn: int in range(1, 5):
		var got: StringName = EnemyAi.decide(
			&"eternalKeeper", turn, "", "", 1.0, rng, flags)
		if String(got) != PHASE1[turn - 1]:
			fails.append("eternalKeeper: turn %d expected %s got %s"
				% [turn, PHASE1[turn - 1], String(got)])
	if rng.get_state() != before:
		fails.append("eternalKeeper: AI consumed RNG")
	var phase: StringName = EnemyAi.decide(
		&"eternalKeeper", 4, "kindWord", "cinderFall", 0.5, rng, flags)
	if phase != &"keepTheFire":
		fails.append("eternalKeeper: phase transition returned %s" % String(phase))
	if flags.get("keptFire", false) != true:
		fails.append("eternalKeeper: keptFire flag was not set")
	var second: StringName = EnemyAi.decide(
		&"eternalKeeper", 5, "keepTheFire", "kindWord", 0.4, rng, flags)
	if second == &"keepTheFire" or String(second).is_empty():
		fails.append("eternalKeeper: phase 2 stayed on the transform (got %s)" % String(second))


static func _handoff_hit(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = RunState.new_run(content, 22041, "keeper-handoff")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": ["eternalKeeper"], "kind": "boss"})
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("eternalKeeper: handoff fight did not start")
		return
	var foe: EnemyCombatant = game.cb.enemies[0]
	foe.hp = 4
	foe.block = 0
	game.cb.queue.clear()
	var bosses_before: int = int(float(str(run.stats.get("bosses", 0))))
	game.rules.hit_enemy(run, game.cb, foe, 999, false)
	if foe.hp != 1:
		fails.append("eternalKeeper: lethal blow left hp %d" % foe.hp)
	if game.cb.finale_handoff != true or game.cb.over != true or game.cb.result != "win":
		fails.append("eternalKeeper: lethal blow did not hand off")
	if int(float(str(run.stats.get("bosses", 0)))) != bosses_before:
		fails.append("eternalKeeper: handoff counted as a boss kill")
	var saw_handoff: bool = false
	for ev: Dictionary in game.cb.queue:
		if ev.get("t") == EventTypes.DIE:
			fails.append("eternalKeeper: lethal blow emitted DIE")
		if ev.get("t") == EventTypes.FINALE_HANDOFF:
			saw_handoff = true
		if ev.get("t") == EventTypes.HIT_ENEMY and ev.get("dead", false) == true:
			fails.append("eternalKeeper: handoff hit was marked dead")
	if not saw_handoff:
		fails.append("eternalKeeper: lethal blow did not emit finaleHandoff")
	foe.hp = 40
	game.cb.over = false
	game.cb.finale_handoff = false
	game.cb.result = ""
	game.cb.queue.clear()
	game.rules.hit_enemy(run, game.cb, foe, 6, false)
	if game.cb.finale_handoff == true or foe.hp != 34:
		fails.append("eternalKeeper: a non-lethal hit handed off")


static func _handoff_poison(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = RunState.new_run(content, 22042, "keeper-poison")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": ["eternalKeeper"], "kind": "boss"})
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("eternalKeeper: poison fight did not start")
		return
	var foe: EnemyCombatant = game.cb.enemies[0]
	foe.hp = 3
	foe.block = 0
	foe.statuses["poison"] = 8
	game.cb.queue.clear()
	game.apply({"t": "endTurn"})
	if foe.hp != 1 or game.cb.finale_handoff != true:
		fails.append("eternalKeeper: poison tick did not hand off")
	for ev: Dictionary in game.cb.queue:
		if ev.get("t") == EventTypes.DIE:
			fails.append("eternalKeeper: poison tick emitted DIE")


static func _sovereign_still_dies(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = RunState.new_run(content, 22043, "sovereign-dies")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": ["sovereign"], "kind": "boss"})
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("eternalKeeper: sovereign control fight did not start")
		return
	var foe: EnemyCombatant = game.cb.enemies[0]
	foe.hp = 4
	foe.block = 0
	game.cb.queue.clear()
	game.rules.hit_enemy(run, game.cb, foe, 999, false)
	if foe.hp != 0 or game.cb.finale_handoff == true:
		fails.append("eternalKeeper: Sovereign was handed off instead of dying")
	var saw_die: bool = false
	for ev: Dictionary in game.cb.queue:
		if ev.get("t") == EventTypes.DIE:
			saw_die = true
	if not saw_die:
		fails.append("eternalKeeper: Sovereign lethal blow did not emit DIE")


static func _scenario(content: ContentDB, fails: Array[String]) -> void:
	var kernel: ScenarioKernel = ScenarioKernel.new(content, RUN_PATH, VIGIL_PATH, REF_PATH)
	kernel.clear_profile()
	var ref: ScenarioReference = ScenarioReference.new()
	if not ref.load_from({
		"id": "combat-eternal-keeper", "revision": 1, "build": BUILD,
		"seed": 18501, "locale": "en", "shape": "pad-landscape",
		"overrides": {
			"act": 0, "node": "14,3", "kind": "boss",
			"enemies": ["eternalKeeper"],
		},
	}):
		fails.append("eternalKeeper: named Scenario rejected: %s" % ref.error)
		return
	var run: RunState = kernel.construct(ref)
	if run == null:
		fails.append("eternalKeeper: named Scenario failed: %s" % kernel.last_error)
		kernel.clear_profile()
		return
	if run.pending_enemy_ids != ["eternalKeeper"]:
		fails.append("eternalKeeper: Scenario did not freeze the boss")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": run.pending_enemy_ids, "kind": "boss"})
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("eternalKeeper: Scenario startCombat dropped the boss")
		kernel.clear_profile()
		return
	var enemy: EnemyCombatant = game.cb.enemies[0]
	if String(enemy.key) != "eternalKeeper":
		fails.append("eternalKeeper: Scenario seated %s" % String(enemy.key))
	if String(enemy.move_key) != "hearthBlow":
		fails.append("eternalKeeper: first intent was %s" % String(enemy.move_key))
	kernel.clear_profile()
