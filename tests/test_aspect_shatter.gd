extends RefCounted
## H10: shatter/stagger is Dusk-only. Ash connecting attacks do not chip.


static func run(fails: Array[String]) -> void:
	_connecting_strike(fails, 0, true)
	_connecting_strike(fails, 1, false)


static func _connecting_strike(fails: Array[String], aspect: int, expect_chip: bool) -> void:
	var who: String = "Dusk" if aspect == 0 else "Ash"
	var content: ContentDB = ContentDB.load_full(false)
	var run: RunState = RunState.new_run(content, 42110, "h10-%d" % aspect, {"aspect": aspect})
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("aspect shatter: %s fight did not start" % who)
		return
	var enemy: EnemyCombatant = game.cb.enemies[0]
	enemy.block = 0
	enemy.chips = enemy.facet_max - 1
	enemy.staggered = false
	enemy.hp = maxi(enemy.hp, 20)
	var strike: CardInst = CardInst.new(game.run.next_uid(), &"strike", false)
	game.cb.hand.append(strike)
	game.cb.player.energy = maxi(game.cb.player.energy, 1)
	var preview: Variant = game.rules.preview_play(game.cb, strike, 0, game.run)
	game.apply({"t": "playCard", "uid": strike.uid, "target": 0})
	if typeof(preview) != TYPE_DICTIONARY:
		fails.append("aspect shatter: %s preview missing" % who)
		return
	var pv: Dictionary = preview
	var preview_chips: int = int(float(str(pv["chips"])))
	var will: bool = pv["willShatter"] == true
	if expect_chip:
		if not enemy.staggered:
			fails.append("aspect shatter: Dusk connecting strike did not stagger")
		if preview_chips <= 0 or not will:
			fails.append("aspect shatter: Dusk preview must chip and willShatter")
	else:
		if enemy.chips != enemy.facet_max - 1:
			fails.append("aspect shatter: Ash connecting strike chipped (%d)" % enemy.chips)
		if enemy.staggered:
			fails.append("aspect shatter: Ash connecting strike staggered")
		if preview_chips != 0 or will:
			fails.append("aspect shatter: Ash preview must report chips=0")
