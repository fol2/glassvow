extends RefCounted
## One fixed whole-run digest catches drift in real routing, pilot and content.

const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const EXPECTED: String = "d371cb26d4763445709bda1cbb61ebb41f89dd8a42ca74682fc9091ee8f069fc"


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	_check_incoming(content, fails)
	var first: Dictionary = Sim.simulate(content, "duskblade", 1000, 0)
	var second: Dictionary = Sim.simulate(content, "duskblade", 1000, 0)
	var digest: String = Sim.outcome_digest(first)
	if digest != Sim.outcome_digest(second):
		fails.append("balance sim: seed 1000 is not deterministic")
	if digest != EXPECTED:
		fails.append("balance sim: seed 1000 outcome digest expected %s got %s" % [EXPECTED, digest])


static func _check_incoming(content: ContentDB, fails: Array[String]) -> void:
	for condition: String in ["smolder-lethal", "staggered"]:
		var run_state: RunState = RunState.new_run(content, 7, "incoming-%s" % condition)
		var game: GlassvowGame = GlassvowGame.new(content, run_state)
		var enemies: Array = ["sporeling", "sporeling"] \
			if condition == "smolder-lethal" else ["sporeling"]
		game.apply({"t": "startCombat", "enemies": enemies, "kind": "normal"})
		var enemy: EnemyCombatant = game.cb.enemies[0]
		for foe: EnemyCombatant in game.cb.enemies:
			foe.move_key = &"spit"
		if condition == "smolder-lethal":
			enemy.hp = 3
			enemy.statuses["poison"] = 4
			game.cb.enemies[1].hp = 3 # The remaining Smolder jumps and kills this foe too.
		else:
			enemy.staggered = true
		var forecast: int = Pilot._incoming(game)
		var hp_before: int = game.cb.player.hp
		game.apply({"t": "endTurn"})
		var actual: int = hp_before - game.cb.player.hp
		if forecast != actual:
			fails.append("balance pilot: %s forecast %d damage, enemy phase dealt %d" % [condition, forecast, actual])
