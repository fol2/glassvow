extends RefCounted
## Composition-root contract: combat defers content hydration until its next
## route boundary, and real CardViews never mix languages within that fight.

const MAIN_PATH: String = "res://application/main.gd"


static func run(fails: Array[String]) -> void:
	_main_source_seams(fails)
	_combat_latest_request_wins(fails)
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
	var run_end: String = _function_body(source, "_show_run_end")
	if not ready.contains("_apply_content_hydration()"):
		fails.append("Main hydration seam: boot does not apply the active content catalogue")
	var pending_at: int = language.find("_pending_language = code")
	var combat_guard_at: int = language.find("if _screen != null")
	if pending_at < 0 or combat_guard_at < 0 or pending_at > combat_guard_at:
		fails.append("Main hydration seam: language change is not deferred before the combat guard")
	if language.contains(".hydrate_content("):
		fails.append("Main hydration seam: language handler hydrates ContentDB directly")
	if not _before(route, "_apply_pending_content_hydration()", "if game == null"):
		fails.append("Main hydration seam: run route constructs before applying pending content")
	if not _before(title, "_apply_pending_content_hydration()", "_load_run()"):
		fails.append("Main hydration seam: title constructs before applying pending content")
	if not _before(map, "_apply_pending_content_hydration()", "WorldMapScreen.new"):
		fails.append("Main hydration seam: direct map route constructs before applying pending content")
	if not _before(run_end, "_apply_pending_content_hydration()", "var pending: Dictionary"):
		fails.append("Main hydration seam: run end reads content before applying pending content")


## A player can change their mind while the same fight is still alive. The
## second Settings request cancels the first pending catalogue; the route seam
## must therefore remain wholly English rather than applying stale zh-Hant.
static func _combat_latest_request_wins(fails: Array[String]) -> void:
	var previous_locale: Locale = Locale.active
	var previous_preferences: Preferences = Preferences.active
	Preferences.active = Preferences.new()
	Preferences.active.language = "en"
	Locale.active = Locale.new(Locale.CODE_EN)
	var content: ContentDB = ContentDB.load_full()
	var baked: String = _catalogue_fingerprint(content)
	var ids: String = _id_fingerprint(content)
	var run: RunState = RunState.new_run(content, 104125, "latest-language-request")
	run.player.deck.append(CardInst.new(run.next_uid(), &"aegis"))
	run.player.relics.append("duskmirror")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	var main: Main = Main.new()
	main.content = content
	main.game = game
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	var screen: CombatScreen = CombatScreen.new(game)
	screen.seq.instant = true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.start_encounter(["sporeling"], "normal", "latest language request")
	main._screen = screen
	run.pending_run_end = {"outcome": "abandon", "bequestAnswered": true}
	var save_before: String = JSON.stringify(run.to_save_dict())
	var rng_before: int = run.rng_state()
	var english_act: String = str(content.acts[run.act].get("name", ""))

	main._show_settings()
	var first: Button = _button_with_text(main._modal, "English")
	if first == null:
		fails.append("Main hydration latest request: English control was not reachable")
		_cleanup(main, screen, tree)
		Locale.active = previous_locale
		Preferences.active = previous_preferences
		return
	first.pressed.emit()
	if Preferences.active.language != "zh-Hant" \
			or Locale.active.code != Locale.CODE_EN \
			or main.get("_content_hydration_pending") != true \
			or not _node_has_text(main._modal, "Takes effect on the next screen."):
		fails.append("Main hydration latest request: first combat request was not deferred")
	var second: Button = _button_with_text(main._modal, "繁體中文")
	if second == null:
		fails.append("Main hydration latest request: pending zh-Hant control was not reachable")
	else:
		second.pressed.emit()

	if Preferences.active.language != "en" \
			or Locale.active.code != Locale.CODE_EN \
			or main.get("_content_hydration_pending") != false:
		fails.append("Main hydration latest request: second request did not cancel the first")
	if not main._modal is SettingsPanel \
			or _button_with_text(main._modal, "English") == null \
			or _node_has_text(main._modal, "Takes effect on the next screen."):
		fails.append("Main hydration latest request: cancelled request still shows defer copy")
	if _catalogue_fingerprint(content) != baked \
			or JSON.stringify(run.to_save_dict()) != save_before \
			or run.rng_state() != rng_before \
			or _id_fingerprint(content) != ids:
		fails.append("Main hydration latest request: combat cancellation changed state or content")

	main._close_overlay()
	main._show_run_end()
	var run_end: RunEndScreen = main._route_screen as RunEndScreen
	var bequests: Array[Dictionary] = main._bequest_choices()
	if Locale.active.code != Locale.CODE_EN \
			or _catalogue_fingerprint(content) != baked \
			or run_end == null \
			or str(run_end._stats.get("act_name", "")) != english_act \
			or not _choice_has_name(bequests, "card", "Cathedral Glass") \
			or not _choice_has_name(bequests, "relic", "Duskmirror"):
		fails.append("Main hydration latest request: next route applied the stale first request")
	if JSON.stringify(run.to_save_dict()) != save_before \
			or run.rng_state() != rng_before \
			or _id_fingerprint(content) != ids:
		fails.append("Main hydration latest request: next route changed save, RNG, or IDs")
	_cleanup(main, screen, tree)
	Locale.active = previous_locale
	Preferences.active = previous_preferences


static func _combat_defer_and_card_consumer(fails: Array[String]) -> void:
	var previous_preferences: Preferences = Preferences.active
	Preferences.active = Preferences.new()
	Preferences.active.language = "en"
	var baked: ContentDB = ContentDB.load_full()
	var baked_fingerprint: String = _catalogue_fingerprint(baked)
	var baked_ids: String = _id_fingerprint(baked)
	var english_cards: Dictionary = baked.cards.duplicate(true)
	Locale.active = Locale.new(Locale.CODE_EN)
	var run: RunState = RunState.new_run(baked, 125125, "hydration-main")
	run.player.deck.append(CardInst.new(run.next_uid(), &"aegis"))
	run.player.relics.append("duskmirror")
	var game: GlassvowGame = GlassvowGame.new(baked, run)
	var main: Main = Main.new()
	main.content = baked
	main.game = game
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
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

	main._show_settings()
	var settings: SettingsPanel = main._modal as SettingsPanel
	var language_toggle: Button = _button_with_text(settings, "English")
	if language_toggle == null:
		fails.append("Main hydration integration: combat language control was not reachable")
	else:
		language_toggle.pressed.emit()
	if Locale.active.code != Locale.CODE_EN:
		fails.append("Main hydration integration: combat switched dynamic chrome early")
	if Preferences.active.language != "zh-Hant":
		fails.append("Main hydration integration: combat request was not persisted")
	if not main._modal is SettingsPanel \
			or not _node_has_text(main._modal, "Takes effect on the next screen.") \
			or _button_with_text(main._modal, "繁體中文") == null:
		fails.append("Main hydration integration: deferred Settings copy was not honest")
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

	# Abandon is the direct combat exit that does not pass through `_route_run`.
	# Drive its run-end constructor without writing the production save path.
	run.pending_run_end = {"outcome": "abandon", "bequestAnswered": true}
	var save_before_route: String = JSON.stringify(run.to_save_dict())
	main._show_run_end()
	var undo_v: Variant = Locale.active.get("_overlaid")
	var undo: Array = undo_v if typeof(undo_v) == TYPE_ARRAY else []
	if undo.size() != 646 or main.get("_content_hydration_pending") != false:
		fails.append("Main hydration integration: combat abandon did not apply zh-Hant once")
	if JSON.stringify(run.to_save_dict()) != save_before_route:
		fails.append("Main hydration integration: display overlay changed the v2 run/save dictionary")
	var run_end: RunEndScreen = main._route_screen as RunEndScreen
	if run_end == null or str(run_end._stats.get("act_name", "")) != "灰燼樹林":
		fails.append("Main hydration integration: abandon run-end copied the old English act name")
	var bequests: Array[Dictionary] = main._bequest_choices()
	if not _choice_has_name(bequests, "card", "聖堂琉璃"):
		fails.append("Main hydration integration: run-end card copy stayed English")
	if not _choice_has_name(bequests, "relic", "暮色鏡"):
		fails.append("Main hydration integration: run-end relic copy stayed English")
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
	Preferences.active = previous_preferences


static func _choice_has_name(choices: Array[Dictionary], kind: String, name: String) -> bool:
	for choice: Dictionary in choices:
		if str(choice.get("kind", "")) == kind and str(choice.get("name", "")) == name:
			return true
	return false


static func _button_with_text(root: Node, text: String) -> Button:
	if root == null:
		return null
	for node: Node in root.find_children("", "Button", true, false):
		var button: Button = node
		if button.text == text:
			return button
	return null


static func _node_has_text(root: Node, text: String) -> bool:
	if root == null:
		return false
	for node: Node in root.find_children("", "Label", true, false):
		if (node as Label).text == text:
			return true
	return false


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
