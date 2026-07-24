extends RefCounted
## M5a smoke: the combat screen plays a real encounter headless through the
## instant sequencer (no suspension), exercising the same input paths the
## player uses — new_run, start_encounter sync, targeted play, end turn.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_presentation: %s" % what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_slice()

	# ---- new_run builds a fresh core-only profile from content.player
	var rs: RunState = RunState.new_run(content, 12345)
	_check(fails, rs.player.deck.size() == 10, "new_run deck has 10 cards")
	_check(fails, rs.player.hp == 72 and rs.player.max_hp == 72, "new_run hp 72/72")
	_check(fails, rs.player.gold == 99, "new_run gold 99")
	_check(fails, rs.player.energy_max == 3, "new_run energy 3")
	_check(fails, rs.player.relics.size() == 1 and rs.player.relics[0] == "emberHeart", "new_run start relic")
	_check(fails, rs.player.potions.size() == 3, "new_run 3 empty potion slots")
	_check(fails, not rs.reveals_all and rs.reveals.is_empty(), "new_run fresh reveals []")
	_check(fails, rs.omens.size() == 1 and rs.omens[0] == null, "new_run act-0 omen null")
	_check(fails, rs.uid == 11, "new_run uid cursor after deck")

	# ---- screen drives a real fight headless (instant drain)
	var game: GlassvowGame = GlassvowGame.new(content, rs)
	var screen: CombatScreen = CombatScreen.new(game)
	screen.seq.instant = true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)

	screen.start_encounter(["sporeling", "sporeling"], "normal", "smoke")
	_check(fails, game.cb != null and game.cb.turn == 1, "combat started turn 1")
	_check(fails, screen._enemy_views.size() == 2, "two enemy views")
	_check(fails, screen._hand.uids().size() == 5, "hand renders 5 cards")

	# Play the first enemy-target card through the real input path (arm → click).
	var target_uid: int = -1
	for c: CardInst in game.cb.hand:
		var d: Dictionary = game.rules.card_data(c)
		if str(d.get("target", "")) == "enemy" and game.rules.can_play(game.cb, c, 0):
			target_uid = c.uid
			break
	_check(fails, target_uid >= 0, "an enemy-target card is in the opening hand")
	if target_uid >= 0:
		var hand_before: int = game.cb.hand.size()
		screen._on_card_pressed(target_uid)
		_check(fails, screen._armed_uid == target_uid, "card arms for targeting")
		screen._on_enemy_clicked(0)
		_check(fails, not screen.seq.is_busy(), "instant drain completes synchronously")
		_check(fails, game.cb.hand.size() == hand_before - 1, "card left the hand")
		_check(fails, screen._hand.uids().size() == game.cb.hand.size(), "hand view tracks state")

	# End the turn: enemy phase runs, next turn draws back to 5.
	screen._on_end_turn_pressed()
	_check(fails, not screen.seq.is_busy(), "end-turn drain completes")
	if not game.cb.over:
		_check(fails, game.cb.turn == 2, "turn advanced to 2")
		_check(fails, game.cb.hand.size() == 5, "redrew to 5")
		_check(fails, screen._hand.uids().size() == 5, "hand view redrew to 5")

	tree.root.remove_child(screen)
	screen.free()
