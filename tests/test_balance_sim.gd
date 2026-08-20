extends RefCounted
## One fixed whole-run digest catches drift in real routing, pilot and content.

const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const Policy: GDScript = preload("res://tools/balance_policy.gd")
const EXPECTED: String = "b02bca98709f70ddc5e1b163bd580f54bece86ece2e6fd2b364784245ec8fecf"


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	_check_incoming(content, fails)
	_check_valuation(content, fails)
	_check_sampler(content, fails)
	var first: Dictionary = Sim.simulate(content, "duskblade", 1000, 0)
	var second: Dictionary = Sim.simulate(content, "duskblade", 1000, 0)
	var digest: String = Sim.outcome_digest(first)
	if digest != Sim.outcome_digest(second):
		fails.append("balance sim: seed 1000 is not deterministic")
	if digest != EXPECTED:
		fails.append("balance sim: seed 1000 outcome digest expected %s got %s" % [EXPECTED, digest])
	var random_first: Dictionary = Sim.simulate(content, "duskblade", 1000, 0,
		PackedStringArray(), {}, true, true)
	var random_second: Dictionary = Sim.simulate(content, "duskblade", 1000, 0,
		PackedStringArray(), {}, true, true)
	if Sim.outcome_digest(random_first) != Sim.outcome_digest(random_second):
		fails.append("balance sim: seeded random-build/random-play arm is not deterministic")


static func _check_sampler(content: ContentDB, fails: Array[String]) -> void:
	var all: Array[Dictionary] = Policy.sample_range(215, 0, 3)
	var tail: Array[Dictionary] = Policy.sample_range(215, 2, 1)
	if all[2] != tail[0]:
		fails.append("balance policy: sampled policy must be shard-independent")
	var sampled: Dictionary = all[0]
	var decline: float = float(str(sampled["cardDecline"]))
	if decline < 0.0 or decline > 40.0 \
			or int(float(str(sampled["removalMinCopies"]))) not in [1, 2, 3]:
		fails.append("balance policy: sampled thresholds outside documented ranges")


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
	if Pilot.VERSION != "p8-d0-v1":
		fails.append("balance pilot: VERSION expected p8-d0-v1 got %s" % Pilot.VERSION)
	_check_grammar(content, fails)
	_check_default_vector(content, fails)
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
	var appetite: float = float(str(Policy.default()["removalAppetite"]))
	if remove_score != Pilot.remove_value(wscore) or remove_score != appetite - wscore:
		fails.append("balance sim: pickRemove must be appetite - worst, got %s vs %s" %
			[remove_score, appetite - wscore])
	print("event-score library[0]=%s [1]=%s  forgottenShrine[0]=%s [1]=%s" %
		[lib0, lib1, remove_score, gold_score])


static func _check_grammar(content: ContentDB, fails: Array[String]) -> void:
	Pilot.apply_policy({})
	var appetite: float = float(str(Policy.default()["removalAppetite"]))
	var copies: int = int(float(str(Policy.default()["removalMinCopies"])))
	var ceiling: float = appetite - Pilot.REMOVAL_SHOP_MARGIN
	if not Pilot.wants_shop_remove(copies, ceiling) or Pilot.wants_shop_remove(copies, ceiling + 0.1) \
			or Pilot.wants_shop_remove(copies - 1, 0.0):
		fails.append("balance pilot: default shop remove must track appetite and min copies")
	if Pilot.remove_value(2.5) != appetite - 2.5:
		fails.append("balance pilot: default pickRemove must be appetite - wscore")
	var run_state: RunState = RunState.new_run(content, 7, "t1a")
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	var before: int = game.run.player.deck.size()
	var strike_score: float = Pilot.card_score(content.cards["strike"], game.run.aspect, "strike")
	var takes_strike: bool = Pilot.accepts_card_reward(strike_score)
	Sim._claim_rewards(game, {"gold": 0, "cards": ["strike"]})
	var grew: bool = game.run.player.deck.size() == before + 1
	if grew != takes_strike:
		fails.append("balance sim: default decline must match accepts_card_reward on strike")
	Pilot.apply_policy({"cardDecline": 100.0})
	run_state = RunState.new_run(content, 7, "t1a-high")
	game = GlassvowGame.new(content, run_state)
	before = game.run.player.deck.size()
	Sim._claim_rewards(game, {"gold": 0, "cards": ["strike"]})
	if game.run.player.deck.size() != before:
		fails.append("balance sim: high cardDecline must skip strike")
	Pilot.apply_policy({"removalAppetite": 20.0})
	if not Pilot.wants_shop_remove(3, 18.0) or Pilot.wants_shop_remove(3, 18.1):
		fails.append("balance pilot: shop ceiling must track removalAppetite - 2")
	if Pilot.remove_value(2.5) != 17.5:
		fails.append("balance pilot: pickRemove must track removalAppetite")
	Pilot.apply_policy({"removalMinCopies": 1})
	var open_ceiling: float = float(str(Policy.default()["removalAppetite"])) - Pilot.REMOVAL_SHOP_MARGIN
	if not Pilot.wants_shop_remove(1, open_ceiling) or Pilot.wants_shop_remove(1, open_ceiling + 0.1):
		fails.append("balance pilot: removalMinCopies must open singleton shop remove")
	Pilot.apply_policy({})


static func _check_default_vector(content: ContentDB, fails: Array[String]) -> void:
	Pilot.apply_policy({})
	if Pilot.policy_snapshot() != Policy.default():
		fails.append("balance policy: empty override must resolve to default()")
	Pilot.apply_policy(Policy.default())
	var dusk_run: RunState = RunState.new_run(content, 7, "vector-events")
	var game: GlassvowGame = GlassvowGame.new(content, dusk_run)
	var lib: Array = content.events["library"]["choices"]
	var lib0_row: Dictionary = lib[0]
	var lib1_row: Dictionary = lib[1]
	var lib0: float = Sim._event_choice_score(game, lib0_row)
	var lib1: float = Sim._event_choice_score(game, lib1_row)
	if lib0 <= lib1:
		fails.append("balance policy: default vector library must choose [0], %s vs %s" % [lib0, lib1])
	var shrine: Array = content.events["forgottenShrine"]["choices"]
	var shrine0: Dictionary = shrine[0]
	var shrine1: Dictionary = shrine[1]
	var remove_score: float = Sim._event_choice_score(game, shrine0)
	var gold_score: float = Sim._event_choice_score(game, shrine1)
	if remove_score <= gold_score:
		fails.append("balance policy: default vector forgottenShrine must choose [0], %s vs %s" %
			[remove_score, gold_score])
	var empty: Dictionary = Sim.simulate(content, "duskblade", 1000, 0)
	var full: Dictionary = Sim.simulate(content, "duskblade", 1000, 0, PackedStringArray(),
		Policy.default())
	empty.erase("policy")
	full.erase("policy")
	if Sim.outcome_digest(empty) != Sim.outcome_digest(full):
		fails.append("balance policy: default() run must match empty-override run")
	Pilot.apply_policy({})
