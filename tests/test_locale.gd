extends RefCounted
## Locale catalogue: English seed resolves, fallback never blanks, params
## interpolate, and the default `active` stand-in needs no main.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("locale: %s" % what)


static func run(fails: Array[String]) -> void:
	_english_seed(fails)
	_derived_display_seed(fails)
	_fallback_chain(fails)
	_params(fails)
	_content_and_whisper(fails)
	_unknown_language_rejected(fails)
	_default_active(fails)
	_remaining_run_screen_call_sites(fails)
	_dialog_shells(fails)


static func _english_seed(fails: Array[String]) -> void:
	var locale: Locale = Locale.new()
	if locale.code != Locale.CODE_EN:
		fails.append("locale: default language is not en")
	if locale.t("ui.brand.title") != "GLASSVOW":
		fails.append("locale: ui.brand.title missing from en seed")
	if locale.t("ui.embark.title") != "THE CLIMB BEGINS":
		fails.append("locale: ui.embark.title missing from en seed")
	if locale.t("ui.keywords.kindle") == "ui.keywords.kindle":
		fails.append("locale: ui.keywords.kindle missing from en seed")
	if locale.t("ui.pilgrimage.survey") != "SCROLL OR DRAG TO SURVEY THE PILGRIMAGE":
		fails.append("locale: Glassvow pilgrimage keys missing from en seed")
	if locale.t("ui.embark.vowLevel", {"level": "I", "max": "III"}) != "VOW I  / III":
		fails.append("locale: ui.embark.vowLevel missing or mistyped")
	if locale.t("ui.settings.ledger") != "The Ledger":
		fails.append("locale: ui.settings.ledger missing from en seed")
	if locale.t("ui.credits.bodyGlass") != "Parallel-ported from roguecardv2.":
		fails.append("locale: player credits expose benchmark build identity")
	if locale.content("cards", "strike", "name") != "Edge":
		fails.append("locale: content.cards.strike.name missing from en seed")
	if not locale.content("cards", "strike", "text").contains("@6@"):
		fails.append("locale: card text lost @n@ markers")


## Mechanics IDs that are rendered as labels need catalogue-owned display copy.
## The English values deliberately match the current transforms byte for byte;
## I2 and the residual presentation follow-up consume these leaves separately.
static func _derived_display_seed(fails: Array[String]) -> void:
	var locale: Locale = Locale.new()
	var expected: Dictionary = {
		"ui.combat.encounterKind.monster": "Monster",
		"ui.combat.encounterKind.elite": "Elite",
		"ui.combat.encounterKind.boss": "Boss",
		"ui.card.type.attack": "attack",
		"ui.card.type.skill": "skill",
		"ui.card.type.power": "power",
		"ui.card.type.status": "status",
		"ui.card.type.curse": "curse",
		"ui.rarity.starter": "starter",
		"ui.rarity.common": "common",
		"ui.rarity.uncommon": "uncommon",
		"ui.rarity.rare": "rare",
		"ui.rarity.special": "special",
		"ui.rarity.boss": "boss",
	}
	for key: String in expected:
		if locale.t(key) != expected[key]:
			fails.append("locale derived display: %s is missing or mistyped" % key)


static func _fallback_chain(fails: Array[String]) -> void:
	var locale: Locale = Locale.new()
	var missing: String = locale.t("ui.does.not.exist")
	if missing != "ui.does.not.exist":
		fails.append("locale: missing key did not fall back to the key itself")
	# A bare catalogue with no en file still must not blank.
	var empty: Locale = Locale.new(Locale.CODE_EN, "res://locale/__missing__.json")
	if empty.t("ui.brand.title") != "ui.brand.title":
		fails.append("locale: empty catalogue blanked instead of returning the key")
	if empty.t("ui.brand.title") == "":
		fails.append("locale: empty catalogue returned a blank string")


static func _params(fails: Array[String]) -> void:
	var locale: Locale = Locale.new()
	var line: String = locale.t("ui.hud.actFloor", {"act": 2, "floor": 7})
	if line != "Act 2 · Floor 7":
		fails.append("locale: ui.hud.actFloor params failed (%s)" % line)


static func _content_and_whisper(fails: Array[String]) -> void:
	var locale: Locale = Locale.new()
	if locale.whisper(0) != "There is a colour the Spire refuses to name.":
		fails.append("locale: whisper 0 did not resolve")
	if locale.whisper(23) != "The climb continues.":
		fails.append("locale: whisper 23 did not resolve")
	if locale.whisper(99) != "content.whispers.99":
		fails.append("locale: out-of-range whisper did not fall back to the key")
	var status: String = locale.content("status", "poison", "name")
	if status != "Smolder":
		fails.append("locale: status.poison.name expected Smolder, got %s" % status)


static func _unknown_language_rejected(fails: Array[String]) -> void:
	var locale: Locale = Locale.new()
	if locale.set_language(&"xx-NOPE"):
		fails.append("locale: unknown language was accepted")
	if locale.code != Locale.CODE_EN:
		fails.append("locale: failed set_language drifted the code")
	if locale.t("ui.brand.title") != "GLASSVOW":
		fails.append("locale: failed set_language lost the en catalogue")


static func _default_active(fails: Array[String]) -> void:
	if Locale.active == null:
		fails.append("locale: static active is null")
	if Locale.active.t("ui.common.continue") != "Continue":
		fails.append("locale: static active does not serve English without main")


## Wave 4 I1 owns these exact presentation seams. Source assertions are
## deliberate here: an English runtime cannot distinguish a raw literal from
## the English catalogue value, while a changed locale must traverse every
## call site below.
static func _remaining_run_screen_call_sites(fails: Array[String]) -> void:
	var seams: Dictionary = {
		"res://presentation/run/credits_screen.gd": {
			"_init": ["ui.credits.title", "ui.credits.headingBrand",
				"ui.credits.bodyBrand", "ui.credits.headingGlass",
				"ui.credits.bodyGlass", "ui.credits.headingMusic",
				"ui.credits.headingSound", "ui.credits.headingType",
				"ui.credits.bodyCinzel", "ui.credits.bodyAlegreya",
				"ui.credits.bodyNoto", "ui.credits.headingEngine",
				"ui.credits.bodyEngine", "ui.credits.footer", "ui.credits.close"],
			"_add_music_attribution": ["ui.credits.musicAttribution",
				"ui.credits.musicAttributionCount"],
			"_add_music_rows": ["ui.credits.musicTracklistFallback"],
			"_add_sfx_rows": ["ui.credits.sfxAttribution",
				"ui.credits.sfxAttributionCount", "ui.credits.themeLine"],
			"_add_licence_fold": ["ui.credits.engineLicences"],
			"_add_font_licence_fold": ["ui.credits.fontLicences"],
			"_build_licence": ["ui.credits.components", "ui.credits.licenceTexts"],
		},
		"res://presentation/run/rose_window_view.gd": {
			"_pane_copy": ["ui.rose.shardRecoveredStack"],
			"_detail_copy": ["ui.rose.shardRecoveredStack", "ui.rose.paneDark"],
			"_pane_accessible_name": ["ui.rose.dormantPane", "ui.rose.unknownPane"],
		},
		"res://presentation/run/choice_screen.gd": {
			"_add_title_rose": ["ui.rose.openLabel"],
		},
		"res://presentation/run/dawn_screen.gd": {
			"_build": ["ui.dawn.inputHint"],
		},
		"res://presentation/run/lamplighter_screen.gd": {
			"_build": ["ui.lamp.title", "ui.lamp.sub", "ui.lamp.boonLabel",
				"ui.lamp.artLabel", "ui.lamp.artHint", "ui.menu.chooseBoon"],
			"_refresh": ["ui.menu.lightTheWay", "ui.menu.chooseBoon"],
		},
		"res://presentation/run/run_hud.gd": {
			"refresh": ["ui.hud.hpFraction"],
			"_rebuild_right": ["ui.hud.viewDeck", "ui.hud.menu"],
			"_potion_seat": ["ui.hud.emptyPhial"],
			"_location_text": ["ui.hud.location"],
		},
		"res://presentation/map/world_map_screen.gd": {
			"_act_line": ["ui.pilgrimage.awaits"],
		},
		"res://application/main.gd": {
			"_show_run_deck": ["ui.hud.deckOverlayTitle", "ui.hud.deckOverlayCount",
				"ui.menu.close"],
			"_show_potion_menu": ["ui.common.use", "ui.hud.tossPotion", "ui.menu.close"],
			"_bequest_choices": ["ui.end.bequestNote.relic", "ui.end.bequestNote.card",
				"ui.end.bequestNote.gold", "ui.end.bequestNote.goldCache"],
			"_on_terminal_commit": ["ui.dawn.shardGrantCopy", "ui.dawn.memoryTitle",
				"ui.dawn.memoryBody"],
			"_unlock_dawn_copy": ["ui.dawn.unlock.lamplighter", "ui.dawn.unlock.phials",
				"ui.dawn.unlock.omens", "ui.dawn.unlock.pool",
				"ui.dawn.unlock.emberglass", "ui.dawn.unlock.act4"],
			"_show_monument": ["ui.end.monument.body", "ui.end.monument.bodyWithBequest",
				"ui.end.monument.title", "ui.end.monument.claim", "ui.end.monument.leave"],
		},
	}
	for path_v: Variant in seams:
		var path: String = str(path_v)
		var source: String = FileAccess.get_file_as_string(path)
		var functions: Dictionary = seams[path_v]
		for function_v: Variant in functions:
			var function_name: String = str(function_v)
			var body: String = _function_body(source, function_name)
			for key_v: Variant in functions[function_v]:
				var key: String = str(key_v)
				if not body.contains('Locale.active.t("%s"' % key):
					fails.append("locale I1 call site: %s:%s misses %s" % [
						path, function_name, key])
	var map_source: String = FileAccess.get_file_as_string(
		"res://presentation/map/world_map_screen.gd")
	var node_caption: String = _function_body(map_source, "_node_caption")
	if not node_caption.contains('var node_key: String = "ui.map.node.%s"') \
			or not node_caption.contains("Locale.active.t(node_key)"):
		fails.append("locale I1 call site: map node captions bypass their dynamic locale key")


static func _function_body(source: String, name: String) -> String:
	var start: int = source.find("func %s(" % name)
	if start < 0:
		return ""
	var finish: int = source.find("\nfunc ", start + 1)
	return source.substr(start) if finish < 0 else source.substr(start, finish - start)


static func _dialog_shells(fails: Array[String]) -> void:
	var source: String = FileAccess.get_file_as_string("res://application/main.gd")
	var expected_keys: Array[String] = [
		"ui.menu.beginAnew", "ui.menu.beginAnewBody", "ui.menu.keepClimbing",
		"ui.menu.leaveSpireTitle", "ui.menu.leaveSpireBody",
		"ui.common.leave", "ui.common.stay", "ui.menu.abandonConfirmTitle",
		"ui.menu.abandonConfirmBody", "ui.menu.abandonRun",
	]
	for key: String in expected_keys:
		_check(fails, source.contains('Locale.active.t("%s")' % key),
			"Main dialog seam does not consume %s" % key)

	var previous: Locale = Locale.active
	Locale.active = Locale.new(Locale.CODE_EN)
	var main: Main = Main.new()
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	main._transitions = TransitionLayer.new()
	main.add_child(main._transitions)
	main._confirm_abandon()
	var abandon: ChoiceScreen = main._modal as ChoiceScreen
	_check(fails, abandon != null, "abandon confirmation did not open as an overlay")
	if abandon != null:
		_check_dialog(fails, abandon, "ABANDON RUN?",
			"This pilgrimage will end. The Vigil will keep what was earned.",
			["Abandon Run", "Keep Climbing"], "no", "Abandon Run", "abandon")
	main._close_overlay()
	main._show_run_menu()
	var menu: RunMenuPanel = main._modal as RunMenuPanel
	_check(fails, menu != null, "run menu did not open")
	if menu != null:
		menu.quit_requested.emit()
	var leave: ChoiceScreen = main._choice_screen as ChoiceScreen
	_check(fails, leave != null, "Leave Spire confirmation did not open")
	if leave != null:
		_check_dialog(fails, leave, "LEAVE THE SPIRE?", "The lantern keeps your place.",
			["Leave", "Stay"], "no", "Leave", "leave")
	Locale.active = previous


static func _check_dialog(fails: Array[String], screen: ChoiceScreen,
		title: String, body: String, actions: Array[String], cancel: String,
		first: String, label: String) -> void:
	var labels: Array[String] = []
	for node: Node in screen.find_children("", "Label", true, false):
		var text: String = str((node as Label).text)
		if not text.is_empty():
			labels.append(text)
	var buttons: Array[String] = []
	for node: Node in screen.find_children("", "Button", true, false):
		buttons.append(str((node as Button).text))
	_check(fails, labels.has(title), "%s title changed" % label)
	_check(fails, labels.has(body), "%s body changed" % label)
	_check(fails, buttons == actions, "%s action order changed: %s" % [label, buttons])
	_check(fails, screen._cancel_id == cancel, "%s cancel action changed" % label)
	_check(fails, screen._first_button != null and screen._first_button.text == first,
		"%s initial focus target changed" % label)
