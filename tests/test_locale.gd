extends RefCounted
## Locale catalogue: English seed resolves, fallback never blanks, params
## interpolate, and the default `active` stand-in needs no main.

const PERSISTENCE_DETAILS: Dictionary = {
	"ui.persistence.detail.currentPilgrimageClose": "The current pilgrimage could not be closed.",
	"ui.persistence.detail.currentPilgrimageClear": "The current pilgrimage could not be cleared.",
	"ui.persistence.detail.pilgrimageStart": "The pilgrimage could not be started.",
	"ui.persistence.detail.savedPilgrimageMapUnreadable": "The saved pilgrimage map is unreadable.",
	"ui.persistence.detail.abandonmentHold": "The abandonment could not be held.",
	"ui.persistence.detail.phialChoiceHold": "The phial choice could not be held.",
	"ui.persistence.detail.chosenWaystoneHold": "The chosen waystone could not be held.",
	"ui.persistence.detail.clearedWaystoneHold": "The cleared waystone could not be held.",
	"ui.persistence.detail.eventHold": "The event could not be held.",
	"ui.persistence.detail.eventChoiceHold": "The event choice could not be held.",
	"ui.persistence.detail.treasureHold": "The treasure could not be held.",
	"ui.persistence.detail.merchantStockHold": "The merchant's stock could not be held.",
	"ui.persistence.detail.emptyLanternPurchaseHold": "The empty lantern purchase could not be held.",
	"ui.persistence.detail.purchaseHold": "The purchase could not be held.",
	"ui.persistence.detail.removedCardHold": "The removed card could not be held.",
	"ui.persistence.detail.encounterFreeze": "The encounter could not be frozen.",
	"ui.persistence.detail.standingBequestClear": "The standing bequest could not be cleared.",
	"ui.persistence.detail.fallHold": "The fall could not be held.",
	"ui.persistence.detail.shadeVictoryHold": "The shade victory could not be held.",
	"ui.persistence.detail.finalVictoryHold": "The final victory could not be held.",
	"ui.persistence.detail.victoryRewardsHold": "The victory rewards could not be held.",
	"ui.persistence.detail.claimedRewardHold": "The claimed reward could not be held.",
	"ui.persistence.detail.crownRelicsHold": "The crown relics could not be held.",
	"ui.persistence.detail.nextActHold": "The next act could not be held.",
	"ui.persistence.detail.bequestHold": "The bequest could not be held.",
	"ui.persistence.detail.vigilRecord": "The Vigil could not record this pilgrimage.",
	"ui.persistence.detail.completedRunClose": "The completed run could not be closed.",
	"ui.persistence.detail.dawnHold": "Dawn could not be held.",
	"ui.persistence.detail.dawnCursorHold": "The Dawn cursor could not be held.",
	"ui.persistence.detail.shadeDuelHold": "The shade duel could not be held.",
	"ui.persistence.detail.hollowPriceHold": "The Hollow price could not be held.",
	"ui.persistence.detail.heldHollowDestinationUnreadable": "The held Hollow destination is unreadable.",
	"ui.persistence.detail.hollowDestinationHold": "The Hollow destination could not be held.",
	"ui.persistence.detail.lamplighterGiftsHold": "The Lamplighter's gifts could not be held.",
	"ui.persistence.detail.lamplighterGiftHold": "The Lamplighter's gift could not be held.",
}

## Deliberately identical player-facing values. Technical font and licence
## names are embedded in otherwise localised credit lines, so they do not need
## an exemption here.
const ZH_HANT_ENGLISH_ALLOWLIST: Array[String] = [
	# Language selectors display each language in its own script.
	"ui.language.en",
	"ui.language.zhHant",
	# This value contains only a decorative glyph and an interpolation marker;
	# there is no English lexical copy to translate.
	"ui.end.unlock.header",
]

## Every visible Latin-script remainder is deliberate: genre/credit proper
## names, the A key, or the status catalogue's literal N magnitude token.
const ZH_HANT_LATIN_PATH_ALLOWLIST: Array[String] = [
	"ui.brand.tagline", "ui.combat.lanternSub", "ui.help.lanternBody",
	"ui.lamp.artHint", "ui.credits.bodyBrand", "ui.credits.bodyGlass",
	"ui.credits.bodyCinzel", "ui.credits.bodyAlegreya", "ui.credits.bodyNoto",
	"ui.credits.bodyEngine", "ui.credits.fontLicences", "ui.credits.footer",
	"ui.credits.musicAttribution", "ui.credits.musicAttributionCount",
	"ui.credits.sfxAttribution", "ui.credits.sfxAttributionCount", "ui.language.en",
	"content.status.beacon.desc", "content.status.dex.desc",
	"content.status.emberflow.desc", "content.status.energized.desc",
	"content.status.metallicize.desc", "content.status.nightsight.desc",
	"content.status.poison.desc", "content.status.regen.desc",
	"content.status.ritual.desc", "content.status.str.desc",
	"content.status.thorns.desc", "content.status.venomous.desc",
]

const ZH_HANT_GLOSSARY_SAMPLES: Dictionary = {
	"ui.brand.title": "琉璃誓言",
	"ui.vigil.title": "守夜",
	"ui.pilgrimage.survey": "滾動或拖曳以巡視朝聖之路",
	"ui.combat.lanternTitle": "提燈",
	"ui.combat.affixTitle": "{name} — 菁英封號",
	"ui.persistence.detail.chosenWaystoneHold": "所選引路石未能保存。",
	"content.cards.defend.name": "護光",
	"content.status.poison.name": "陰燃",
	"content.aspects.duskblade.name": "暮刃",
	"content.omens.eighthOmen.name": "第八凶兆",
	"content.variants.ownShade1.name": "墜落之影",
}


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
	_persistence_calls_and_shell(fails)
	_zh_hant_catalogue_contract(fails)


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


static func _persistence_calls_and_shell(fails: Array[String]) -> void:
	var source: String = FileAccess.get_file_as_string("res://application/main.gd")
	var call_keys: Array[String] = []
	var marker: String = '_show_save_error("'
	var at: int = source.find(marker)
	while at >= 0:
		var start: int = at + marker.length()
		var finish: int = source.find('")', start)
		if finish < 0:
			break
		call_keys.append(source.substr(start, finish - start))
		at = source.find(marker, finish + 2)
	_check(fails, call_keys.size() == 40,
		"expected 40 save-error call sites, found %d" % call_keys.size())
	var distinct: Array[String] = []
	var locale: Locale = Locale.new(Locale.CODE_EN)
	for key: String in call_keys:
		_check(fails, PERSISTENCE_DETAILS.has(key), "save-error call uses non-frozen key %s" % key)
		if PERSISTENCE_DETAILS.has(key):
			_check(fails, locale.t(key) == str(PERSISTENCE_DETAILS[key]),
				"save-error key %s does not preserve its English detail" % key)
		if not distinct.has(key):
			distinct.append(key)
	_check(fails, distinct.size() == 35,
		"expected 35 distinct save-error details, found %d" % distinct.size())
	for key: String in PERSISTENCE_DETAILS:
		_check(fails, distinct.has(key), "save-error details do not cover %s" % key)

	var previous: Locale = Locale.active
	Locale.active = Locale.new(Locale.CODE_EN)
	var main: Main = Main.new()
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	main._transitions = TransitionLayer.new()
	main.add_child(main._transitions)
	main._show_save_error("ui.persistence.detail.eventHold")
	var shell: ChoiceScreen = main._choice_screen as ChoiceScreen
	_check(fails, shell != null, "save-error shell did not open")
	if shell != null:
		_check_dialog(fails, shell, "THE LIGHT WOULD NOT HOLD",
			"The event could not be held.\nNo progress was discarded.",
			["Retry", "Title"], "", "Retry", "save error")
		_check(fails, not shell._has_cancel, "save-error shell gained a cancel action")
	Locale.active = previous


## P7.6's authored catalogue is a strict peer of English: the same keys, no
## accidental blanks, and no English seed copy left behind except the named
## language label. Markers are compared as multisets, not mere containment, so
## duplicate parameters and paired rich-text tags cannot disappear unnoticed.
static func _zh_hant_catalogue_contract(fails: Array[String]) -> void:
	var en: Dictionary = _read_catalogue("res://locale/en.json", fails)
	var zh: Dictionary = _read_catalogue("res://locale/zh-Hant.json", fails)
	if en.is_empty() or zh.is_empty():
		return
	var en_leaves: Dictionary = {}
	var zh_leaves: Dictionary = {}
	_flatten_strings(en, "", en_leaves)
	_flatten_strings(zh, "", zh_leaves)
	var missing: Array[String] = []
	var extra: Array[String] = []
	var blank: Array[String] = []
	var untranslated: Array[String] = []
	var marker_drift: Array[String] = []
	for key_v: Variant in en_leaves:
		var key: String = str(key_v)
		if not zh_leaves.has(key):
			missing.append(key)
			continue
		var en_value: String = str(en_leaves[key])
		var zh_value: String = str(zh_leaves[key])
		if not en_value.is_empty() and zh_value.strip_edges().is_empty():
			blank.append(key)
		if en_value == zh_value and not en_value.is_empty() \
				and not ZH_HANT_ENGLISH_ALLOWLIST.has(key):
			untranslated.append(key)
		if _marker_multiset(en_value) != _marker_multiset(zh_value):
			marker_drift.append(key)
	for key_v: Variant in zh_leaves:
		var key: String = str(key_v)
		if not en_leaves.has(key):
			extra.append(key)
	missing.sort()
	extra.sort()
	blank.sort()
	untranslated.sort()
	marker_drift.sort()
	_check(fails, missing.is_empty(), "zh-Hant missing %d keys: %s" % [
		missing.size(), _first_paths(missing)])
	_check(fails, extra.is_empty(), "zh-Hant has %d extra keys: %s" % [
		extra.size(), _first_paths(extra)])
	_check(fails, blank.is_empty(), "zh-Hant has %d unexpected blanks: %s" % [
		blank.size(), _first_paths(blank)])
	_check(fails, untranslated.is_empty(), "zh-Hant leaves %d English values: %s" % [
		untranslated.size(), _first_paths(untranslated)])
	_check(fails, marker_drift.is_empty(), "zh-Hant marker drift in %d values: %s" % [
		marker_drift.size(), _first_paths(marker_drift)])
	for key_v: Variant in ZH_HANT_ENGLISH_ALLOWLIST:
		var key: String = str(key_v)
		_check(fails, en_leaves.has(key) and zh_leaves.has(key)
			and str(en_leaves[key]) == str(zh_leaves[key]),
			"zh-Hant English allowlist entry is stale: %s" % key)
	for key_v: Variant in ZH_HANT_GLOSSARY_SAMPLES:
		var key: String = str(key_v)
		_check(fails, str(zh_leaves.get(key, "")) == str(ZH_HANT_GLOSSARY_SAMPLES[key]),
			"zh-Hant glossary drift at %s" % key)
	var latin_paths: Array[String] = []
	for key_v: Variant in zh_leaves:
		var key: String = str(key_v)
		if _visible_ascii(str(zh_leaves[key])):
			latin_paths.append(key)
	latin_paths.sort()
	var expected_latin: Array[String] = ZH_HANT_LATIN_PATH_ALLOWLIST.duplicate()
	expected_latin.sort()
	_check(fails, latin_paths == expected_latin,
		"zh-Hant visible Latin allowlist drift: %s" % _first_paths(latin_paths))


static func _read_catalogue(path: String, fails: Array[String]) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		fails.append("locale: could not parse catalogue %s" % path)
		return {}
	return parsed


static func _flatten_strings(value: Variant, path: String, out: Dictionary) -> void:
	if typeof(value) == TYPE_STRING:
		out[path] = value
	elif typeof(value) == TYPE_DICTIONARY:
		var table: Dictionary = value
		for key_v: Variant in table:
			var key: String = str(key_v)
			_flatten_strings(table[key_v], key if path.is_empty() else "%s.%s" % [path, key], out)
	elif typeof(value) == TYPE_ARRAY:
		var rows: Array = value
		for index: int in range(rows.size()):
			_flatten_strings(rows[index], str(index) if path.is_empty()
				else "%s.%d" % [path, index], out)


static func _marker_multiset(value: String) -> Array[String]:
	var pattern: RegEx = RegEx.new()
	pattern.compile("(@[^@]+@|#[^#]+#|\\{[^{}]+\\}|<[^>]+>|\\[[^]\\n]+\\])")
	var markers: Array[String] = []
	for found: RegExMatch in pattern.search_all(value):
		markers.append(found.get_string())
	markers.sort()
	return markers


static func _visible_ascii(value: String) -> bool:
	var structural: RegEx = RegEx.new()
	structural.compile("(@[^@]+@|#[^#]+#|\\{[^{}]+\\}|<[^>]+>|\\[[^]\\n]+\\])")
	var words: RegEx = RegEx.new()
	words.compile("[A-Za-z]")
	return words.search(structural.sub(value, "", true)) != null


static func _first_paths(paths: Array[String]) -> String:
	var shown: Array[String] = []
	for index: int in range(mini(paths.size(), 8)):
		shown.append(paths[index])
	return ", ".join(shown)
