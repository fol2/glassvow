extends RefCounted
## Wave 4 I2: frozen locale keys are consumed at the combat and adjacent UI seams.

static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_i2_combat_chrome_locale: %s" % what)

static func _source(path: String) -> String:
	return FileAccess.get_file_as_string(path)

static func _has_all(source: String, keys: Array[String]) -> bool:
	for key: String in keys:
		if not source.contains('"%s"' % key):
			return false
	return true

static func _ordered(source: String, needles: Array[String]) -> bool:
	var cursor: int = 0
	for needle: String in needles:
		var found: int = source.find(needle, cursor)
		if found < 0:
			return false
		cursor = found + needle.length()
	return true

static func run(fails: Array[String]) -> void:
	_runtime_hydrated_combat_chrome(fails)
	_runtime_encounter_headers(fails)
	var hud: String = _source("res://presentation/combat/hud_bar.gd")
	_check(fails, _has_all(hud, ["ui.hud.hpFraction", "ui.hud.deckAria",
		"ui.hud.menuAria", "ui.hud.emptyPhial", "ui.combat.lanternAria",
		"ui.combat.draw", "ui.combat.ashes", "ui.combat.discard", "ui.combat.end",
		"ui.combat.drawPileAria", "ui.combat.discardPileAria",
		"ui.combat.ashesPileAria"]),
		"combat HUD consumes its frozen chrome keys")
	var combat: String = _source("res://presentation/combat/combat_screen.gd")
	_check(fails, _has_all(combat, ["ui.combat.deckInspectorTitle",
		"ui.combat.inspectorCardCountOne", "ui.combat.inspectorCardCountMany",
		"ui.combat.inspectorEmpty", "ui.combat.adamant", "ui.combat.turn",
		"ui.combat.intent.attackFor", "ui.combat.intent.summary"]),
		"combat inspector, event and intent seams consume locale keys")
	var reward: String = _source("res://presentation/reward/reward_screen.gd")
	_check(fails, _has_all(reward, ["ui.reward.victory", "ui.reward.continue",
		"ui.reward.goldRow", "ui.reward.chooseCardTitle",
		"ui.reward.leaveConfirmNo"]), "live reward shell consumes locale keys")
	var adjacent: String = "\n".join([
		_source("res://presentation/run/rest_screen.gd"),
		_source("res://presentation/run/shop_screen.gd"),
		_source("res://presentation/run/event_screen.gd"),
		_source("res://presentation/run/treasure_screen.gd"),
		_source("res://presentation/run/hollow_screen.gd"),
	])
	_check(fails, _has_all(adjacent, ["ui.rest.restHealBtn", "ui.rest.smithBtn",
		"ui.shop.greeting", "ui.shop.cardRemoval.title", "ui.event.continue",
		"ui.treasure.title", "ui.treasure.coinsOnly", "ui.hollow.kicker",
		"ui.hollow.payPrice", "ui.hollow.pricePaid"]),
		"adjacent live surfaces consume locale keys")
	var main: String = _source("res://application/main.gd")
	_check(fails, _has_all(main, ["ui.hud.usePotionOn", "ui.common.use",
		"ui.rest.temperCardTitle", "ui.event.chooseCardBody",
		"ui.shop.cardRemoval.confirmBody", "ui.combat.encounterHeader",
		"ui.combat.encounterKind.%s",
		"ui.reward.replacePotion", "ui.reward.bossCrownTitle"]),
		"owned Main choice seams consume locale keys")
	var potion_menu: String = main.substr(main.find("func _show_combat_potion_menu"),
		main.find("func _on_combat_potion_choice") - main.find("func _show_combat_potion_menu"))
	_check(fails, _ordered(potion_menu, ["ui.hud.usePotionOn", "ui.common.use",
		"ui.hud.tossPotion", "ui.menu.close", "ChoiceScreenType.new"]),
		"combat phial target/use/toss/close order remains unchanged")
	var adamant: int = combat.find('Locale.active.t("ui.combat.adamant")')
	_check(fails, adamant >= 0 and combat.find("_sync_actors()", adamant) > adamant
		and combat.find("await _wait(0.18)", adamant) > adamant,
		"Adamant locale lookup stays ahead of the existing sync and await")
	var relic_proc: int = combat.find("EventTypes.RELIC_PROC:")
	var relic_end: int = combat.find('&"addCard":', relic_proc)
	var relic_branch: String = combat.substr(relic_proc, relic_end - relic_proc)
	var relic_wait: int = relic_branch.find("await _wait(0.09)")
	_check(fails, relic_proc >= 0 and relic_end > relic_proc and relic_wait >= 0
		and relic_branch.find("_relic_proc_text") < relic_wait
		and relic_branch.find("_hero_centre() + Vector2(0.0, -110.0)") < relic_wait,
		"hydrated relic proc keeps its exact floater position before the 0.09 wait")


static func _runtime_hydrated_combat_chrome(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	content.potions["healing"]["name"] = "Hydrated Draught"
	content.relics["emberHeart"]["name"] = "Hydrated Heart"
	var run: RunState = RunState.new_run(content, 101101, "i2-runtime")
	run.player.potions[0] = "healing"
	run.reveals_all = true
	var game: GlassvowGame = GlassvowGame.new(content, run)
	var screen: CombatScreen = CombatScreen.new(game)
	screen.seq.instant = true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.start_encounter(["sporeling"], "normal", "runtime")
	_check(fails, screen._hud._potion_slots[0].tooltip_text == "Hydrated Draught",
		"combat chrome passes the hydrated phial display name into the HUD")
	screen._show_deck()
	_check(fails, screen._inspector_title.text == "DECK",
		"deck inspector keeps its exact English casing")
	screen._show_pile(&"draw")
	_check(fails, screen._inspector_title.text == "DRAW PILE",
		"draw inspector keeps its exact English casing")
	screen._show_pile(&"discard")
	_check(fails, screen._inspector_title.text == "DISCARD PILE",
		"discard inspector keeps its exact English casing")
	screen._show_pile(&"ashes")
	_check(fails, screen._inspector_title.text == "ASHES",
		"ashes inspector keeps its exact English casing")
	_check(fails, screen._relic_proc_text("emberHeart") == "HYDRATED HEART",
		"relic proc floater seam reads the hydrated ContentDB display name")
	_check(fails, screen._relic_proc_text("unknownRelic") == "UNKNOWNRELIC",
		"relic proc floater keeps the unknown-ID diagnostic fallback")
	var intent_tip: Dictionary = screen._intent_tip(0)
	_check(fails, intent_tip == {
		"title": "Spore Spit", "body": "Intends to attack for [b]4[/b]."},
		"intent tooltip keeps exact hydrated English and BBCode")
	var requested: Dictionary = Locale.active.get("_requested")
	var ui_locale: Dictionary = requested["ui"]
	var combat_locale: Dictionary = ui_locale["combat"]
	var intent_locale: Dictionary = combat_locale["intent"]
	var attack_before: String = intent_locale["attackFor"]
	var summary_before: String = intent_locale["summary"]
	intent_locale["attackFor"] = "MARK [b]{amount}[/b]"
	intent_locale["summary"] = "PLAN {intent}"
	_check(fails, str(screen._intent_tip(0)["body"]) == "PLAN MARK [b]4[/b]",
		"intent tooltip resolves its composed body through the catalogue")
	intent_locale["attackFor"] = attack_before
	intent_locale["summary"] = summary_before
	var draw_before: String = combat_locale["drawPileTitle"]
	combat_locale["drawPileTitle"] = "MiXeD catalogue marker"
	screen._show_pile(&"draw")
	_check(fails, screen._inspector_title.text == "MIXED CATALOGUE MARKER",
		"inspector visually transforms a distinctive catalogue title")
	combat_locale["drawPileTitle"] = draw_before
	tree.root.remove_child(screen)
	screen.free()


static func _runtime_encounter_headers(fails: Array[String]) -> void:
	var previous: Locale = Locale.active
	Locale.active = Locale.new(Locale.CODE_EN)
	var expected: Dictionary[String, String] = {
		"monster": "Monster  ·  act 1",
		"elite": "Elite  ·  act 2",
		"boss": "Boss  ·  act 3",
	}
	var act_number: int = 1
	for kind: String in expected:
		_check(fails, Main._combat_encounter_header(kind, act_number) == expected[kind],
			"%s encounter header keeps exact English and spacing" % kind)
		act_number += 1
	var requested: Dictionary = Locale.active.get("_requested")
	var ui: Dictionary = requested["ui"]
	var combat: Dictionary = ui["combat"]
	var encounter_kind: Dictionary = combat["encounterKind"]
	encounter_kind["monster"] = "CATALOGUE MARKER"
	_check(fails, Main._combat_encounter_header("monster", 4)
		== "CATALOGUE MARKER  ·  act 4",
		"encounter header resolves the route kind through its catalogue leaf")
	Locale.active = previous
