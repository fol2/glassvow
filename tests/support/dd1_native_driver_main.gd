extends Main
## Headless Main for DD1 recovery: same game/quest/save seams, no WorldMapScreen
## or CombatScreen. Presentation skip only — GlassvowGame and SaveService remain
## the truth.


func _show_map() -> void:
	_clear_route()


func _show_pending_reward() -> void:
	_clear_route()


func _show_run_end() -> void:
	_clear_route()


func _show_boss_relic() -> void:
	var offer_v: Variant = game.run.quest_scratch.get("bossRelicOffer")
	if typeof(offer_v) != TYPE_ARRAY:
		game.run.quest_scratch["bossRelicOffer"] = game.rewards.roll_boss_relics(game.run)
		_store_run()
	_clear_route()


func _show_shop() -> void:
	var stock_v: Variant = game.run.quest_scratch.get("shopStock")
	if typeof(stock_v) != TYPE_DICTIONARY:
		game.run.quest_scratch["shopStock"] = game.rewards.gen_shop(game.run)
		_store_run()
	_clear_route()


func _show_rest() -> void:
	_clear_route()


func _show_treasure() -> void:
	var claim_v: Variant = game.run.quest_scratch.get("treasureClaim")
	if typeof(claim_v) != TYPE_DICTIONARY:
		game.run.quest_scratch["treasureClaim"] = game.rewards.claim_treasure(game.run)
		_store_run()
	_clear_route()


func _show_event() -> void:
	var event_id: String = str(game.run.quest_scratch.get("eventNode", ""))
	if event_id.is_empty():
		event_id = game.rewards.roll_event(game.run)
		game.run.quest_scratch["eventNode"] = event_id
		_store_run()
	_clear_route()


func _resume_pending_combat() -> void:
	if game == null or game.run == null:
		return
	if typeof(game.run.pending_enemy_ids) != TYPE_ARRAY:
		return
	var enemies: Array = []
	for id_v: Variant in game.run.pending_enemy_ids:
		enemies.append(str(id_v))
	var route_kind: String = str(game.run.pending_combat)
	var combat_kind: String = "normal" if route_kind == "monster" else route_kind
	game.apply({"t": "startCombat", "enemies": enemies, "kind": combat_kind})


func _show_save_error(_key: String) -> void:
	pass
