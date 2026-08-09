extends RefCounted
## Composition-root contract: combat defers content hydration until its next
## route boundary, and real CardViews never mix languages within that fight.

const MAIN_PATH: String = "res://application/main.gd"


static func run(fails: Array[String]) -> void:
	_main_source_seams(fails)
	_combat_defer_and_card_consumer(fails)


## These are integration seams, not implementation trivia: removing any one
## makes boot, the Settings signal, or the next route bypass the atomic switch.
static func _main_source_seams(fails: Array[String]) -> void:
	var source: String = FileAccess.get_file_as_string(MAIN_PATH)
	var ready: String = _function_body(source, "_ready")
	var language: String = _function_body(source, "_on_language_changed")
	var route: String = _function_body(source, "_route_run")
	var title: String = _function_body(source, "_show_title")
	var map: String = _function_body(source, "_show_map")
	if not ready.contains("_apply_content_hydration()"):
		fails.append("Main hydration seam: boot does not apply the active content catalogue")
	var pending_at: int = language.find("_content_hydration_pending = true")
	var combat_guard_at: int = language.find("if _screen != null")
	if pending_at < 0 or combat_guard_at < 0 or pending_at > combat_guard_at:
		fails.append("Main hydration seam: language change is not deferred before the combat guard")
	if language.contains(".hydrate_content("):
		fails.append("Main hydration seam: language handler hydrates ContentDB directly")
	if not _before(route, "_apply_pending_content_hydration()", "if game == null"):
		fails.append("Main hydration seam: run route constructs before applying pending content")
	if not _before(title, "_apply_pending_content_hydration()", "SaveService.load_run"):
		fails.append("Main hydration seam: title constructs before applying pending content")
	if not _before(map, "_apply_pending_content_hydration()", "WorldMapScreen.new"):
		fails.append("Main hydration seam: direct map route constructs before applying pending content")


static func _combat_defer_and_card_consumer(fails: Array[String]) -> void:
	var baked: ContentDB = ContentDB.load_full()
	var baked_fingerprint: String = _catalogue_fingerprint(baked)
	var baked_ids: String = _id_fingerprint(baked)
	var english_cards: Dictionary = baked.cards.duplicate(true)
	Locale.active = Locale.new(Locale.CODE_EN)
	var run: RunState = RunState.new_run(baked, 125125, "hydration-main")
	var game: GlassvowGame = GlassvowGame.new(baked, run)
	var main: Main = Main.new()
	main.content = baked
	main.game = game
	var screen: CombatScreen = CombatScreen.new(game)
	screen.seq.instant = true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.start_encounter(["sporeling"], "normal", "locale integration")
	main._screen = screen
	var old_uids: Array[int] = screen._hand.uids()
	var existing: CardView = screen._hand.card_view(old_uids[0])
	var existing_inst: CardInst = _card_by_uid(game.cb.hand, old_uids[0])
	var existing_en: Dictionary = english_cards[String(existing_inst.id)]
	if not _card_shows(existing, str(existing_en["name"]), str(existing_en["text"])):
		fails.append("Main hydration integration: opening CardView missed baked name/text")

	Locale.active.set_language(Locale.CODE_ZH_HANT)
	main._on_language_changed(Locale.CODE_ZH_HANT)
	if str(baked.cards["strike"]["name"]) != "Edge":
		fails.append("Main hydration integration: combat language toggle changed live ContentDB early")
	if not _card_shows(existing, str(existing_en["name"]), str(existing_en["text"])):
		fails.append("Main hydration integration: existing CardView changed during combat")
	if not _has_property(main, "_content_hydration_pending") \
			or main.get("_content_hydration_pending") != true:
		fails.append("Main hydration integration: combat toggle did not retain a pending switch")

	# The actual combat event path draws the next hand from live ContentDB.
	screen._on_end_turn_pressed()
	var drawn_uid: int = _first_new_uid(screen._hand.uids(), old_uids)
	if drawn_uid < 0:
		fails.append("Main hydration integration: combat produced no new draw to inspect")
	else:
		var drawn: CardInst = _card_by_uid(game.cb.hand, drawn_uid)
		var drawn_data: Dictionary = game.rules.card_data(drawn)
		var drawn_en: Dictionary = english_cards[String(drawn.id)]
		var drawn_view: CardView = screen._hand.card_view(drawn_uid)
		if not _card_shows(drawn_view, str(drawn_en["name"]), str(drawn_en["text"])) \
				or str(drawn_data["name"]) != str(drawn_en["name"]):
			fails.append("Main hydration integration: a new combat draw mixed in zh-Hant early")

	var save_before_route: String = JSON.stringify(run.to_save_dict())
	main._screen = null
	if not main.has_method("_apply_pending_content_hydration"):
		fails.append("Main hydration integration: route has no pending-content apply seam")
		_cleanup(main, screen, tree)
		Locale.active = Locale.new()
		return
	var route_writes_v: Variant = main.call("_apply_pending_content_hydration")
	var route_writes: int = route_writes_v if typeof(route_writes_v) == TYPE_INT else -1
	if route_writes != 642 or main.get("_content_hydration_pending") != false:
		fails.append("Main hydration integration: route boundary did not apply zh-Hant once")
	if JSON.stringify(run.to_save_dict()) != save_before_route:
		fails.append("Main hydration integration: display overlay changed the v2 run/save dictionary")
	var translated: CardView = screen._hand.add_card(
		CardInst.new(999, &"strike"), baked.card(&"strike"), 1)
	if not _card_shows(translated, "刃鋒", "造成 @6@ 點傷害。"):
		fails.append("Main hydration integration: production CardView missed hydrated name/text")

	Locale.active.set_language(Locale.CODE_EN)
	main.set("_content_hydration_pending", true)
	main.call("_apply_pending_content_hydration")
	if _catalogue_fingerprint(baked) != baked_fingerprint or _id_fingerprint(baked) != baked_ids:
		fails.append("Main hydration integration: route zh-Hant -> en did not restore catalogue/IDs")
	_cleanup(main, screen, tree)
	Locale.active = Locale.new()


static func _card_shows(view: CardView, expected_name: String, expected_text: String) -> bool:
	if view == null or view._body == null:
		return false
	var name_found: bool = false
	for node: Node in view.find_children("", "Label", true, false):
		var label: Label = node
		name_found = name_found or label.text == expected_name
	var plain: String = ""
	for token_v: Variant in view._body._tokens:
		var token: Dictionary = token_v
		plain += str(token["text"])
	return name_found and plain == expected_text.replace("@", "").replace("#", "")


static func _card_by_uid(cards: Array[CardInst], uid: int) -> CardInst:
	for card: CardInst in cards:
		if card.uid == uid:
			return card
	return null


static func _first_new_uid(now: Array[int], before: Array[int]) -> int:
	for uid: int in now:
		if not before.has(uid):
			return uid
	return -1


static func _has_property(object: Object, property: String) -> bool:
	for row: Dictionary in object.get_property_list():
		if str(row.get("name")) == property:
			return true
	return false


static func _cleanup(main: Main, screen: CombatScreen, tree: SceneTree) -> void:
	main._screen = null
	if screen.get_parent() == tree.root:
		tree.root.remove_child(screen)
	screen.free()
	main.free()


static func _function_body(source: String, name: String) -> String:
	var start: int = source.find("func %s(" % name)
	if start < 0:
		return ""
	var finish: int = source.find("\nfunc ", start + 1)
	return source.substr(start) if finish < 0 else source.substr(start, finish - start)


static func _before(body: String, first: String, second: String) -> bool:
	var first_at: int = body.find(first)
	var second_at: int = body.find(second)
	return first_at >= 0 and second_at >= 0 and first_at < second_at


static func _catalogue_fingerprint(db: ContentDB) -> String:
	return JSON.stringify([
		db.cards, db.relics, db.enemies, db.statuses, db.events, db.quests,
		db.aspects, db.vows, db.acts, db.variants, db.shade_kits, db.potions,
		db.boons, db.omens, db.affixes, db.arts, db.deeds,
	])


static func _id_fingerprint(db: ContentDB) -> String:
	var out: Array = []
	for registry: Variant in [
		db.cards, db.relics, db.enemies, db.statuses, db.events, db.quests,
		db.aspects, db.vows, db.acts, db.variants, db.shade_kits, db.potions,
		db.boons, db.omens, db.affixes, db.arts, db.deeds,
	]:
		var ids: PackedStringArray = []
		if typeof(registry) == TYPE_DICTIONARY:
			var table: Dictionary = registry
			for key: Variant in table:
				ids.append(str(key))
		elif typeof(registry) == TYPE_ARRAY:
			var rows: Array = registry
			for i: int in range(rows.size()):
				var row: Dictionary = rows[i]
				ids.append(str(row.get("id", i)))
		ids.sort()
		out.append(ids)
	return JSON.stringify(out)
