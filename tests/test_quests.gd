extends RefCounted
## One accelerated programme check: each journey completes through its shared
## domain law, the Vigil lights six unique panes, and the Act IV threshold is
## a reachable map node.

const HOLLOW_MESSAGES: Dictionary = {
	"ui.hollow.message.inactive": "The empty lantern does not answer.",
	"ui.hollow.message.emberDebt": "The next three Embers belong to the hollow lantern.",
	"ui.hollow.message.needGold": "Bring 160 gold.",
	"ui.hollow.message.vesselTooFragile": "Your vessel cannot survive the price.",
	"ui.hollow.message.needBoon": "Bring an unspent boon.",
	"ui.hollow.message.paneLit": "Another hollow pane catches fire.",
	"ui.hollow.message.noPriceWaiting": "No hollow price is waiting.",
}

const ZH_HOLLOW_MESSAGES: Dictionary = {
	"ui.hollow.message.inactive": "空燈沒有回應。",
	"ui.hollow.message.emberDebt": "接下來三點餘燼歸於空燈。",
	"ui.hollow.message.needGold": "帶來 160 金幣。",
	"ui.hollow.message.vesselTooFragile": "你的容器承受不起這代價。",
	"ui.hollow.message.needBoon": "帶來一份尚未花掉的恩賜。",
	"ui.hollow.message.paneLit": "又一片空燈璃面燃起。",
	"ui.hollow.message.noPriceWaiting": "目前沒有空燈代價等候支付。",
}


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_quests: %s" % what)


static func _paid(result: Dictionary) -> bool:
	var value: Variant = result.get("ok")
	if typeof(value) != TYPE_BOOL:
		return false
	var paid: bool = value
	return paid


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	_hollow_domain_tokens(fails)
	_hollow_locale_fallback(fails)
	_hollow_save_boundary(fails)
	var vigil: VigilState = VigilState.blank()
	for id: String in VigilState.QUEST_IDS:
		vigil.quests[id]["state"] = "armed"
	var run_state: RunState = RunState.new_run(content, 818, "run-six-shards", {
		"reveals": null,
		"quests": vigil.quests,
	})
	var rules: QuestRules = QuestRules.new(content)
	run_state.quest_scratch["hollowLamplighter"] = {
		"due": true, "met": false, "meetings": 0, "debtActive": false,
	}
	var unlit: MapNode = MapNode.make("event", [], 1)
	_check(fails, rules.stage_hollow_meeting(run_state, unlit, true),
		"Hollow Lamplighter interrupts an eligible unlit node")
	run_state.pending_hollow = null

	var pale: Dictionary = content.variants["paleDuskfang"]
	for _i: int in range(9):
		rules.on_enemy_death(run_state, pale)
	for tier: int in range(1, 4):
		var shade: Dictionary = content.variants["ownShade%d" % tier]
		rules.on_enemy_death(run_state, shade)

	run_state.act = 1
	run_state.player.gold = 1000
	_check(fails, rules.buy_usurper(run_state), "Usurper lantern can be bought")
	var usurper: Dictionary = content.variants["usurpedSovereign"]
	rules.on_enemy_death(run_state, usurper)

	run_state.act = 2
	run_state.quest_scratch["eighthOmen"] = {"active": true}
	var boss: CombatState = CombatState.new()
	boss.kind = &"boss"
	rules.on_combat_win(run_state, boss)

	run_state.player.deck.append(CardInst.new(run_state.next_uid(), &"unreadablePage"))
	for _i: int in range(5):
		rules.on_combat_win(run_state, boss)

	var payment: Dictionary = rules.pay_lamplighter(run_state)
	_check(fails, _paid(payment), "Lamplighter accepts Ember debt")
	_check(fails, rules.tithe_embers(run_state, 3) == 0, "three caught Embers pay the first price")
	run_state.player.gold = 1000
	payment = rules.pay_lamplighter(run_state)
	_check(fails, _paid(payment), "Lamplighter accepts gold")
	payment = rules.pay_lamplighter(run_state)
	_check(fails, _paid(payment), "Lamplighter accepts Max HP")
	var boon_rules: RewardRules = RewardRules.new(content)
	_check(fails, boon_rules.apply_boon(run_state, "fullPurse"), "a reversible boon is received")
	var boon_reload: RunState = RunState.from_save_dict(run_state.to_save_dict(), content)
	_check(fails, boon_reload != null, "the boon receipt survives a run checkpoint")
	if boon_reload != null:
		run_state = boon_reload
	payment = rules.pay_lamplighter(run_state)
	_check(fails, _paid(payment) and run_state.boon == null,
		"Lamplighter returns a boon without duplicating it")
	payment = rules.pay_lamplighter(run_state)
	_check(fails, _paid(payment), "Lamplighter accepts the last heartbeat")

	for id: String in VigilState.QUEST_IDS:
		_check(fails, str(run_state.quests[id]["state"]) == "complete", "%s completes" % id)
	_check(fails, vigil.commit_run(run_state, "win", content), "completed run commits")
	_check(fails, vigil.shards.size() == 6, "six unique Emberglass panes are lit")
	_check(fails, vigil.unlocks.has("act4"), "six panes reveal Act IV")
	var threshold: WorldMap = WorldMap.act4_entrance()
	_check(fails, threshold.reachable() == [0] and threshold.nodes[0].type == "act4",
		"Act IV threshold is clickable")


static func _hollow_run(content: ContentDB, progress: int) -> RunState:
	var run_state: RunState = RunState.new_run(content, 102, "run-i3-hollow")
	run_state.quests["hollowLamplighter"] = {
		"state": "armed", "progress": progress, "memory": {},
	}
	return run_state


static func _hollow_domain_tokens(fails: Array[String]) -> void:
	var source: String = FileAccess.get_file_as_string("res://domain/rules/quests.gd")
	_check(fails, not source.contains("Locale"), "domain/rules/quests.gd contains Locale")
	for token: String in HOLLOW_MESSAGES:
		_check(fails, source.contains('"message": "%s"' % token),
			"domain does not return %s" % token)
		_check(fails, not source.contains('"message": "%s"' % HOLLOW_MESSAGES[token]),
			"domain still returns English for %s" % token)

	var content: ContentDB = ContentDB.load_full()
	var rules: QuestRules = QuestRules.new(content)
	var inactive: RunState = RunState.new_run(content, 102, "run-i3-inactive")
	_check(fails, str(rules.pay_lamplighter(inactive).get("message")) \
		== "ui.hollow.message.inactive", "inactive result is not the stable token")
	var ember: RunState = _hollow_run(content, 0)
	_check(fails, str(rules.pay_lamplighter(ember).get("message")) \
		== "ui.hollow.message.emberDebt", "Ember result is not the stable token")
	var gold: RunState = _hollow_run(content, 1)
	gold.player.gold = 159
	_check(fails, str(rules.pay_lamplighter(gold).get("message")) \
		== "ui.hollow.message.needGold", "gold result is not the stable token")
	var fragile: RunState = _hollow_run(content, 2)
	fragile.player.max_hp = 41
	_check(fails, str(rules.pay_lamplighter(fragile).get("message")) \
		== "ui.hollow.message.vesselTooFragile", "Max HP result is not the stable token")
	var boon: RunState = _hollow_run(content, 3)
	_check(fails, str(rules.pay_lamplighter(boon).get("message")) \
		== "ui.hollow.message.needBoon", "boon result is not the stable token")
	var pane: RunState = _hollow_run(content, 4)
	_check(fails, str(rules.pay_lamplighter(pane).get("message")) \
		== "ui.hollow.message.paneLit", "lit-pane result is not the stable token")
	var waiting: RunState = _hollow_run(content, 0)
	_check(fails, str(rules.pay_hollow_price(waiting).get("message")) \
		== "ui.hollow.message.noPriceWaiting", "missing-price result is not the stable token")


static func _hollow_locale_fallback(fails: Array[String]) -> void:
	for code: StringName in [Locale.CODE_EN, Locale.CODE_ZH_HANT]:
		var locale: Locale = Locale.new(code)
		for token: String in HOLLOW_MESSAGES:
			var expected: String = str(ZH_HOLLOW_MESSAGES[token]) \
				if code == Locale.CODE_ZH_HANT else str(HOLLOW_MESSAGES[token])
			_check(fails, locale.t(token) == expected,
				"%s did not resolve %s through exact English fallback" % [code, token])


static func _hollow_save_boundary(fails: Array[String]) -> void:
	var previous: Locale = Locale.active
	Locale.active = Locale.new(Locale.CODE_ZH_HANT)
	var content: ContentDB = ContentDB.load_full()
	var run_state: RunState = _hollow_run(content, 4)
	run_state.pending_hollow = {
		"nodeId": "0", "type": "event", "meeting": 4,
		"paid": false, "deferred": false, "answer": "",
	}
	var result: Dictionary = QuestRules.new(content).pay_hollow_price(run_state)
	_check(fails, str(result.get("ok", false)) == "true", "paid Hollow fixture was rejected")
	var before: Dictionary = run_state.to_save_dict().duplicate(true)
	var meeting: Dictionary = {"ask": "A fixture question."}
	var pending: Dictionary = run_state.pending_hollow
	var screen: HollowScreen = HollowScreen.new(pending, meeting, 5, 5)
	_check(fails, screen._answer.text == str(ZH_HOLLOW_MESSAGES["ui.hollow.message.paneLit"]),
		"new token did not resolve at the Hollow presentation boundary")
	_check(fails, run_state.to_save_dict() == before,
		"rendering translated the token or otherwise changed the v2 save dictionary")

	var legacy: RunState = _hollow_run(content, 4)
	legacy.pending_hollow = {
		"nodeId": "0", "type": "event", "meeting": 4,
		"paid": true, "deferred": false,
		"answer": HOLLOW_MESSAGES["ui.hollow.message.paneLit"],
	}
	var legacy_before: Dictionary = legacy.to_save_dict().duplicate(true)
	var legacy_pending: Dictionary = legacy.pending_hollow
	var legacy_screen: HollowScreen = HollowScreen.new(
		legacy_pending, meeting, 5, 5)
	_check(fails, legacy_screen._answer.text == str(HOLLOW_MESSAGES["ui.hollow.message.paneLit"]),
		"persisted v2 English answer is no longer readable")
	_check(fails, legacy.to_save_dict() == legacy_before,
		"rendering changed the legacy v2 save dictionary")
	Locale.active = previous
