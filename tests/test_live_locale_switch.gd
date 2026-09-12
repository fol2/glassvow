extends RefCounted
## P7.7 language switching is one main-owned transaction: a non-combat route
## is rebuilt from the hydrated catalogue without touching run state, while a
## fight keeps one language until its next route boundary.

const MAIN_PATH: String = "res://application/main.gd"
const SETTINGS_PATH: String = "res://presentation/run/settings_panel.gd"
const RUN_STYLE_PATH: String = "res://presentation/run/run_style.gd"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")


static func run(fails: Array[String]) -> void:
	_source_contract(fails)
	_map_round_trip(fails)


static func _source_contract(fails: Array[String]) -> void:
	var main: String = FileAccess.get_file_as_string(MAIN_PATH)
	var settings: String = FileAccess.get_file_as_string(SETTINGS_PATH)
	var language: String = _function_body(main, "_on_language_changed")
	if settings.contains("_preferences.set_language(") \
			or settings.contains("Locale.active.set_language("):
		fails.append("live locale owner: SettingsPanel still mutates language state")
	if not settings.contains('Locale.active.t("ui.language.deferNote")'):
		fails.append("live locale settings: combat defer note is not rendered")
	if not settings.contains("func focus_language()") \
			or not _function_body(settings, "_small_button").contains(
				"RunStyle.hit_floor(26.0)"):
		fails.append("live locale settings: language control misses focus or touch sizing")
	var run_style: Script = load(RUN_STYLE_PATH) as Script
	if run_style == null or not run_style.has_method("hit_floor_for"):
		fails.append("live locale settings: touch target floor has no testable device seam")
	elif run_style.call("hit_floor_for", 26.0, true) != 44.0 \
			or run_style.call("hit_floor_for", 26.0, false) != 26.0:
		fails.append("live locale settings: touch target floor is not 44 px")
	if not language.contains("Preferences.active.set_language(") \
			or not language.contains("_pending_language"):
		fails.append("live locale owner: Main does not persist the requested catalogue")
	var routes: Dictionary = {
		"_show_title": "_remember_route(_show_title)",
		"_show_embark": "_remember_route(_show_embark)",
		"_show_vigil": "_remember_route(_show_vigil.bind(open_rose))",
		"_show_map": "_remember_route(_show_map)",
		"_show_rest": "_remember_route(_show_rest)",
		"_show_event": "_remember_route(_show_event)",
		"_show_treasure": "_remember_route(_show_treasure)",
		"_show_act4_entrance": "_remember_route(_show_act4_entrance)",
		"_show_shop": "_remember_route(_show_shop)",
		"_show_pending_reward": "_remember_route(_show_pending_reward)",
		"_show_boss_relic": "_remember_route(_show_boss_relic)",
		"_show_run_end": "_remember_route(_show_run_end)",
		"_show_dawn": "_remember_route(_show_dawn)",
		"_show_scene": "_remember_route(_show_scene)",
		"_show_departure_staging": "_remember_route(_show_departure_staging)",
		"_show_pending_pool": "_remember_route(_show_pending_pool)",
		"_show_monument": "_remember_route(_show_monument)",
		"_show_hollow": "_remember_route(_show_hollow)",
		"_show_lamplighter": "_remember_route(_show_lamplighter)",
	}
	for route_v: Variant in routes:
		var route: String = str(route_v)
		if not _function_body(main, route).contains(str(routes[route_v])):
			fails.append("live locale route rebuild: %s remembers the wrong route" % route)


static func _map_round_trip(fails: Array[String]) -> void:
	var previous_locale: Locale = Locale.active
	var previous_preferences: Preferences = Preferences.active
	Locale.active = Locale.new(Locale.CODE_EN)
	Preferences.active = Preferences.new()
	Preferences.active.language = "en"
	var content: ContentDB = ContentDB.load_full()
	var baked: String = _catalogue_fingerprint(content)
	var ids: String = _id_fingerprint(content)
	var run: RunState = RunState.new_run(content, 104104, "live-locale-map")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	var map: WorldMap = WorldMap.benchmark(run)
	run.map = map.to_dict()
	var main: Main = Main.new()
	var compiler: MapCompose.FakeLayoutCompiler = MapCompose.FakeLayoutCompiler.new()
	main._map_layout_compile = Callable(compiler, "compile")
	main.content = content
	main.game = game
	main._map = map
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	main._show_map()
	var english_map: WorldMapScreen = main._map_screen
	var layout: MapLayoutResult = english_map.layout_result()
	var input_digest: String = english_map.layout_input_digest()
	if layout == null or str(layout.to_dict().get("selected_candidate_id", "")) \
			!= "test/live-binding":
		fails.append("live locale map: Main bypassed the injected layout compiler")
	var english_hud: RunHud = main._run_hud
	var run_before: String = JSON.stringify(run.to_save_dict())
	var map_before: String = JSON.stringify(map.to_dict())
	var rng_before: int = run.rng_state()
	main._show_settings()
	var english_settings: SettingsPanel = main._modal as SettingsPanel
	var english_toggle: Button = _button_with_text(english_settings, "English")
	if english_toggle == null:
		fails.append("live locale map: English language control was not reachable")
		_cleanup(main, previous_locale, previous_preferences)
		return
	english_toggle.pressed.emit()
	if Locale.active.code != Locale.CODE_ZH_HANT:
		fails.append("live locale map: non-combat switch did not activate zh-Hant")
	if main._map_screen == english_map or main._run_hud == english_hud:
		fails.append("live locale map: map and RunHud were not rebuilt together")
	if main._map_screen.layout_input_digest() != input_digest:
		fails.append("live locale map: locale rebuild changed layout identity")
	elif compiler.calls != 1:
		fails.append("live locale map: unchanged layout recompiled across screen lifecycles")
	if not _has_waystone_tip(main._map_screen, "爐火") \
			or not main._run_hud._title.text.contains("灰燼樹林"):
		fails.append("live locale map: rebuilt waystones or RunHud stayed English")
	if not main._modal is SettingsPanel:
		fails.append("live locale map: Settings did not reopen after the rebuild")
	elif not _node_has_text(main._modal, "設定") \
			or not _node_has_text(main._modal, "語言"):
		fails.append("live locale map: rebuilt Settings did not relabel itself")
	_assert_state_unchanged(fails, run, map, run_before, map_before, rng_before, ids,
		"en -> zh-Hant", content)

	if not main._modal is SettingsPanel:
		main._show_settings()
	var zh_settings: SettingsPanel = main._modal as SettingsPanel
	var zh_toggle: Button = _button_with_text(zh_settings, "繁體中文")
	if zh_toggle == null:
		fails.append("live locale map: zh-Hant language control was not reachable")
	else:
		zh_toggle.pressed.emit()
		if Locale.active.code != Locale.CODE_EN:
			fails.append("live locale map: zh-Hant -> English did not activate English")
		if _catalogue_fingerprint(content) != baked:
			fails.append("live locale map: English bake was not restored exactly")
		_assert_state_unchanged(fails, run, map, run_before, map_before, rng_before,
			ids, "zh-Hant -> en", content)

	# A non-map route proves the stored callable is used instead of guessing via
	# `_route_run()`, which would fall back to the map for an unresolved rest node.
	main._close_overlay()
	main._show_rest()
	var english_rest: Control = main._route_screen
	var rest_hud: RunHud = main._run_hud
	main._show_settings()
	var rest_toggle: Button = _button_with_text(main._modal, "English")
	if rest_toggle != null:
		rest_toggle.pressed.emit()
	if main._route_screen == english_rest or not main._route_screen is RestScreen \
			or main._run_hud == rest_hud:
		fails.append("live locale route rebuild: Rest route did not preserve its class")
	_assert_state_unchanged(fails, run, map, run_before, map_before, rng_before, ids,
		"rest rebuild", content)
	_cleanup(main, previous_locale, previous_preferences)


static func _assert_state_unchanged(fails: Array[String], run: RunState,
		map: WorldMap, run_before: String, map_before: String, rng_before: int,
		ids: String, label: String, content: ContentDB) -> void:
	if JSON.stringify(run.to_save_dict()) != run_before \
			or JSON.stringify(map.to_dict()) != map_before \
			or run.rng_state() != rng_before:
		fails.append("live locale state: %s changed run, map, or RNG" % label)
	if _id_fingerprint(content) != ids:
		fails.append("live locale state: %s changed catalogue IDs" % label)


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


static func _has_waystone_tip(screen: WorldMapScreen, text: String) -> bool:
	if screen == null:
		return false
	for waystone: GlassWaystone in screen._waystones:
		if waystone.tooltip_text == text:
			return true
	return false


static func _cleanup(main: Main, previous_locale: Locale,
		previous_preferences: Preferences) -> void:
	main.free()
	Locale.active = previous_locale
	Preferences.active = previous_preferences


static func _function_body(source: String, name: String) -> String:
	var start: int = source.find("func %s(" % name)
	if start < 0:
		return ""
	var finish: int = source.find("\nfunc ", start + 1)
	return source.substr(start) if finish < 0 else source.substr(start, finish - start)


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
		var keys: PackedStringArray = []
		if typeof(registry) == TYPE_DICTIONARY:
			var table: Dictionary = registry
			for key: Variant in table:
				keys.append(str(key))
		elif typeof(registry) == TYPE_ARRAY:
			var rows: Array = registry
			for i: int in range(rows.size()):
				var row: Dictionary = rows[i]
				keys.append(str(row.get("id", i)))
		keys.sort()
		out.append(keys)
	return JSON.stringify(out)
