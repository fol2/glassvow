extends RefCounted
## One fixed whole-run digest catches drift in real routing, pilot and content.

const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const EXPECTED: String = "b38410ee207c477b1f0048dec350d1488a100937750150b2a4fd04d69eae6710"


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	_check_incoming(content, fails)
	_check_valuation(content, fails)
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


static func _check_valuation(content: ContentDB, fails: Array[String]) -> void:
	var catalyst: Dictionary = content.cards["catalyst"]
	var strike: Dictionary = content.cards["strike"]
	var eclipse: Dictionary = content.cards["eclipseSlash"]
	var ash_cat: float = Pilot.card_score(catalyst, 1, "catalyst")
	var ash_strike: float = Pilot.card_score(strike, 1, "strike")
	if ash_cat <= ash_strike:
		fails.append("balance pilot: Ash catalyst score %s should beat strike %s" % [ash_cat, ash_strike])
	var dusk_eclipse: float = Pilot.card_score(eclipse, 0, "eclipseSlash")
	var dusk_strike: float = Pilot.card_score(strike, 0, "strike")
	if dusk_eclipse <= dusk_strike:
		fails.append("balance pilot: Dusk eclipseSlash score %s should beat strike %s" % [dusk_eclipse, dusk_strike])
	if Pilot.VERSION != "p7-d2-v1":
		fails.append("balance pilot: VERSION expected p7-d2-v1 got %s" % Pilot.VERSION)
	var dusk_run: RunState = RunState.new_run(content, 7, "best-card")
	var strongest: CardInst = Pilot.best_card(dusk_run, content, dusk_run.player.deck)
	if strongest == null or String(strongest.id) == "strike":
		fails.append("balance pilot: best_card must not copy startDeck[0] strike")
	var game: GlassvowGame = GlassvowGame.new(content, dusk_run)
	var library: Dictionary = content.events["library"]
	var lib_choices: Array = library["choices"]
	var lib0_row: Dictionary = lib_choices[0]
	var lib1_row: Dictionary = lib_choices[1]
	var lib0: float = Sim._event_choice_score(game, lib0_row)
	var lib1: float = Sim._event_choice_score(game, lib1_row)
	if lib0 <= lib1:
		fails.append("balance sim: library must choose [0] {pickCard: 5}, scores %s vs %s" % [lib0, lib1])
	var shrine: Dictionary = content.events["forgottenShrine"]
	var shrine_choices: Array = shrine["choices"]
	var shrine0: Dictionary = shrine_choices[0]
	var shrine1: Dictionary = shrine_choices[1]
	var remove_score: float = Sim._event_choice_score(game, shrine0)
	var gold_score: float = Sim._event_choice_score(game, shrine1)
	var worst: CardInst = Pilot.worst_card(dusk_run, content, dusk_run.player.deck)
	var worst_def: Dictionary = content.cards.get(String(worst.id), {})
	var wscore: float = Pilot.card_score(worst_def, dusk_run.aspect, String(worst.id))
	if remove_score != 8.5 - wscore:
		fails.append("balance sim: pickRemove must be 8.5 - worst, got %s vs %s" %
			[remove_score, 8.5 - wscore])
	print("event-score library[0]=%s [1]=%s  forgottenShrine[0]=%s [1]=%s" %
		[lib0, lib1, remove_score, gold_score])
