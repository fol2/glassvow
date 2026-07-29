extends RefCounted
## One accelerated programme check: each journey completes through its shared
## domain law, the Vigil lights six unique panes, and the Act IV threshold is
## a reachable map node.


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
