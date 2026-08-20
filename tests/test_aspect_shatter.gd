extends RefCounted
## H10: shatter/stagger is Dusk-only. H11: enemy Smolder from the player is Ash-only.
## H19: connecting attacks earn 0 + card.chip + Beacon, not a free leading 1.


static func run(fails: Array[String]) -> void:
	_connecting_attack(fails, 0, &"strike", false)
	_connecting_attack(fails, 1, &"strike", false)
	_connecting_attack(fails, 0, &"chisel", true)
	_connecting_attack(fails, 1, &"chisel", false)
	_dusk_emberbite_no_poison(fails)
	_dusk_flare_no_poison(fails)
	_ash_ashbite_applies_poison(fails)
	_dusk_cinder_veined_still_hits_player(fails)


static func _connecting_attack(
	fails: Array[String], aspect: int, card_id: StringName, expect_chip: bool
) -> void:
	var who: String = "Dusk" if aspect == 0 else "Ash"
	var card_name: String = String(card_id)
	var tag: String = "%s %s" % [who, card_name]
	var content: ContentDB = ContentDB.load_full(false)
	var run: RunState = RunState.new_run(content, 42110, "h19-%d-%s" % [aspect, card_name],
		{"aspect": aspect})
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("aspect shatter: %s fight did not start" % tag)
		return
	var enemy: EnemyCombatant = game.cb.enemies[0]
	enemy.block = 0
	enemy.chips = enemy.facet_max - 1
	var chips_before: int = enemy.chips
	enemy.staggered = false
	enemy.hp = maxi(enemy.hp, 20)
	var card: CardInst = CardInst.new(game.run.next_uid(), card_id, false)
	game.cb.hand.append(card)
	game.cb.player.energy = maxi(game.cb.player.energy, 1)
	var preview: Variant = game.rules.preview_play(game.cb, card, 0, game.run)
	game.apply({"t": "playCard", "uid": card.uid, "target": 0})
	if typeof(preview) != TYPE_DICTIONARY:
		fails.append("aspect shatter: %s preview missing" % tag)
		return
	var pv: Dictionary = preview
	var preview_chips: int = int(float(str(pv["chips"])))
	var will: bool = pv["willShatter"] == true
	if expect_chip:
		if not enemy.staggered:
			fails.append("aspect shatter: %s connecting did not stagger" % tag)
		if preview_chips != 1 or not will:
			fails.append("aspect shatter: %s preview must chip 1 extra and willShatter (chips=%d)"
				% [tag, preview_chips])
	else:
		if enemy.chips != chips_before:
			fails.append("aspect shatter: %s connecting chipped (%d)" % [tag, enemy.chips])
		if enemy.staggered:
			fails.append("aspect shatter: %s connecting staggered" % tag)
		if preview_chips != 0 or will:
			fails.append("aspect shatter: %s preview must report chips=0" % tag)


static func _stacks(statuses: Dictionary, id: String) -> int:
	return int(float(str(statuses.get(id, 0))))


static func _fight(aspect: int, tag: String) -> GlassvowGame:
	var content: ContentDB = ContentDB.load_full(false)
	var run: RunState = RunState.new_run(content, 42111, tag, {"aspect": aspect})
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
	return game


static func _play(game: GlassvowGame, card_id: StringName) -> EnemyCombatant:
	var enemy: EnemyCombatant = game.cb.enemies[0]
	enemy.block = 0
	enemy.statuses.erase("poison")
	var card: CardInst = CardInst.new(game.run.next_uid(), card_id, false)
	game.cb.hand.append(card)
	game.cb.player.energy = maxi(game.cb.player.energy, 3)
	game.apply({"t": "playCard", "uid": card.uid, "target": 0})
	return enemy


static func _dusk_emberbite_no_poison(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(0, "h11-emberbite")
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("aspect smolder: Dusk Emberbite fight did not start")
		return
	var enemy: EnemyCombatant = _play(game, &"venomStrike")
	if _stacks(game.cb.player.statuses, "poison") != 0:
		fails.append("aspect smolder: Dusk Emberbite applied Smolder to the player")
	if _stacks(enemy.statuses, "poison") != 0:
		fails.append("aspect smolder: Dusk Emberbite applied Smolder (%d)" % _stacks(enemy.statuses, "poison"))


static func _dusk_flare_no_poison(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(0, "h11-flare")
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("aspect smolder: Dusk Flare fight did not start")
		return
	var enemy: EnemyCombatant = game.cb.enemies[0]
	enemy.block = 0
	enemy.statuses.erase("poison")
	var hp_before: int = enemy.hp
	game.cb.embers = maxi(game.cb.embers, 3)
	game.apply({"t": "useArt"})
	if _stacks(enemy.statuses, "poison") != 0:
		fails.append("aspect smolder: Dusk Flare applied Smolder (%d)" % _stacks(enemy.statuses, "poison"))
	if hp_before - enemy.hp != 7:
		fails.append("aspect smolder: Dusk Flare should deal 7, dealt %d" % (hp_before - enemy.hp))


static func _ash_ashbite_applies_poison(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(1, "h11-ashbite")
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("aspect smolder: Ash Ashbite fight did not start")
		return
	var enemy: EnemyCombatant = _play(game, &"ashBite")
	if _stacks(enemy.statuses, "poison") < 2:
		fails.append("aspect smolder: Ash Ashbite did not apply Smolder (%d)"
			% _stacks(enemy.statuses, "poison"))


static func _dusk_cinder_veined_still_hits_player(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var run: RunState = RunState.new_run(content, 42111, "h11-cinder", {"aspect": 0})
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "elite", "affix": "cinderVeined"})
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("aspect smolder: Dusk cinderVeined fight did not start")
		return
	var enemy: EnemyCombatant = game.cb.enemies[0]
	enemy.block = 0
	enemy.staggered = false
	enemy.move_key = &"spit"
	game.cb.player.block = 0
	game.apply({"t": "endTurn"})
	var saw_player_smolder: bool = false
	for ev: Dictionary in game.cb.queue:
		if str(ev.get("t", "")) == "status" and str(ev.get("id", "")) == "poison" \
				and str(ev.get("who", "")) == "player":
			saw_player_smolder = true
			break
	if not saw_player_smolder:
		fails.append("aspect smolder: cinderVeined must still leave Smolder on Dusk")
