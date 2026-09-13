extends RefCounted
## One accelerated programme check: each journey completes through its shared
## domain law, the Vigil lights six unique panes, and the Act IV threshold is
## a reachable map node.

const EIGHTH_RUN_PATH: String = "user://test_quests_eighth_run_v2.json"
const EIGHTH_VIGIL_PATH: String = "user://test_quests_eighth_vigil_v2.json"

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
	"ui.hollow.message.paneLit": "又一片空燈窗片燃起。",
	"ui.hollow.message.noPriceWaiting": "目前沒有空燈代價等候支付。",
}


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_quests: %s" % what)


static func _flag(value: Variant) -> bool:
	return value == true


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
	_eighth_matrix(fails)
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

	run_state.act = QuestRules.EMBERGLASS_ACT
	run_state.quest_scratch["eighthOmen"] = {"active": true}
	var boss: CombatState = CombatState.new()
	boss.kind = &"boss"
	rules.on_combat_win(run_state, boss)

	run_state.player.deck.append(CardInst.new(run_state.next_uid(), &"unreadablePage"))
	for _i: int in range(5):
		rules.on_combat_win(run_state, boss)
	var final_run: RunState = RunState.new_run(content, 819, "run-final-page-guard", {
		"shards": VigilState.QUEST_IDS.duplicate(),
		"quests": vigil.quests,
	})
	final_run.act = final_run.final_act()
	for guarded_act: int in [QuestRules.EMBERGLASS_ACT, final_run.final_act()]:
		final_run.act = guarded_act
		final_run.quest_scratch.erase("unreadablePage")
		var guarded_cards: Array = ["strike", "defend", "cleave"]
		rules.adjust_reward_cards(final_run, "boss", guarded_cards)
		_check(fails, guarded_cards == ["strike", "defend", "cleave"]
			and not final_run.quest_scratch.has("unreadablePage"),
			"boss rewards suppress unreadablePage in guarded act %d" % guarded_act)

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
	_check(fails, vigil.shards.size() == 6,
		"accelerated six-shard fixture: six unique Emberglass panes are lit")
	_check(fails, vigil.unlocks.has("act4"),
		"accelerated six-shard fixture: six panes reveal Act IV")
	var next_run: RunState = RunState.new_run(content, 820, "run-act-four", {
		"shards": vigil.shards,
	})
	_check(fails, next_run.final_act() == 3,
		"accelerated six-shard fixture: the six carried panes open the next run's fourth-act seam")


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


static func _eighth_rules(content: ContentDB) -> Dictionary:
	var ember_v: Variant = content.progression.get("emberglass", {})
	if typeof(ember_v) != TYPE_DICTIONARY:
		return {}
	var ember: Dictionary = ember_v
	var eighth_v: Variant = ember.get("eighthOmen", {})
	return eighth_v if typeof(eighth_v) == TYPE_DICTIONARY else {}


static func _eighth_chance(content: ContentDB) -> float:
	return float(str(_eighth_rules(content).get("recurrenceChance", 0)))


static func _first_roll_seed(want_hit: bool, chance: float) -> int:
	for seed: int in range(1, 100000):
		var rng: Rng = Rng.new(seed)
		var roll: float = rng.next()
		if want_hit and roll < chance:
			return seed
		if not want_hit and roll >= chance:
			return seed
	return 1


static func _eighth_scheduled(run: RunState) -> bool:
	if run.omens.is_empty() or str(run.omens[0]) != "eighthOmen":
		return false
	var scratch_v: Variant = run.quest_scratch.get("eighthOmen")
	if typeof(scratch_v) != TYPE_DICTIONARY:
		return false
	return scratch_v.get("active", false) == true


static func _eighth_memory(run: RunState) -> Dictionary:
	var quest_v: Variant = run.quests.get("eighthOmen")
	if typeof(quest_v) != TYPE_DICTIONARY:
		return {}
	var quest: Dictionary = quest_v
	var memory_v: Variant = quest.get("memory")
	return memory_v if typeof(memory_v) == TYPE_DICTIONARY else {}


static func _armed_eighth(
	content: ContentDB, seed: int, run_id: String, memory: Dictionary, state: String = "armed"
) -> RunState:
	var quests: Dictionary = {}
	for id: String in VigilState.QUEST_IDS:
		quests[id] = {"state": "dormant", "progress": 0, "memory": {}}
	quests["eighthOmen"] = {
		"state": state,
		"progress": 1 if state == "complete" else 0,
		"memory": memory.duplicate(true),
	}
	return RunState.new_run(content, seed, run_id, {"quests": quests})


static func _eighth_matrix(fails: Array[String]) -> void:
	var production: Variant = _file_snapshot(SaveService.RUN_PATH)
	var production_vigil: Variant = _file_snapshot(SaveService.VIGIL_PATH)
	SaveService.clear(EIGHTH_RUN_PATH)
	SaveService.clear_vigil(EIGHTH_VIGIL_PATH)
	var content: ContentDB = ContentDB.load_full()
	var rules: QuestRules = QuestRules.new(content)
	var eighth: Dictionary = _eighth_rules(content)
	_check(fails, _flag(int(float(str(eighth.get("guaranteeRuns", 0)))) == 2
			and int(float(str(eighth.get("saveDueInMax", 0)))) == 2
			and int(float(str(eighth.get("completeAt", 0)))) == 1
			and abs(float(str(eighth.get("recurrenceChance", 0))) - 1.0 / 3.0) < 0.0000001),
		"authored eighthOmen contract is guaranteeRuns=2, saveDueInMax=2, completeAt=1, chance=1/3")
	var chance: float = _eighth_chance(content)
	var hit: int = _first_roll_seed(true, chance)
	var miss: int = _first_roll_seed(false, chance)
	_check(fails, hit != miss and hit > 0 and miss > 0,
		"could not find distinct recurrence hit/miss seeds")

	var due_one: RunState = _armed_eighth(
		content, 55101, "run-eighth-due-1", {"dueIn": 1})
	rules.prepare_run(due_one)
	_check(fails, _eighth_scheduled(due_one), "due=1 did not schedule Eighth Omen")
	_check(fails, _flag(not _eighth_memory(due_one).has("dueIn")
			and _eighth_memory(due_one).get("seen") == true),
		"due=1 activation did not fold seen=true and erase dueIn")

	var due_two_miss: RunState = _armed_eighth(
		content, miss, "run-eighth-due-2-miss", {"dueIn": 2})
	rules.prepare_run(due_two_miss)
	_check(fails, _flag(not _eighth_scheduled(due_two_miss)
			and int(float(str(_eighth_memory(due_two_miss).get("dueIn", 0)))) == 1),
		"due=2 miss did not retain due=1 scheduling")

	var due_two_hit: RunState = _armed_eighth(
		content, hit, "run-eighth-due-2-hit", {"dueIn": 2})
	rules.prepare_run(due_two_hit)
	_check(fails, _flag(_eighth_scheduled(due_two_hit)
			and not _eighth_memory(due_two_hit).has("dueIn")
			and _eighth_memory(due_two_hit).get("seen") == true),
		"due=2 hit did not schedule Eighth Omen")

	var dormant: RunState = _armed_eighth(
		content, hit, "run-eighth-dormant", {"dueIn": 1, "seen": true}, "dormant")
	rules.prepare_run(dormant)
	_check(fails, not _eighth_scheduled(dormant), "dormant Eighth Omen scheduled")

	var completed: RunState = _armed_eighth(
		content, hit, "run-eighth-complete", {"seen": true}, "complete")
	rules.prepare_run(completed)
	_check(fails, not _eighth_scheduled(completed), "completed Eighth Omen scheduled")

	_f3_terminal_fold(fails, content, rules, "death", hit)
	_f3_terminal_fold(fails, content, rules, "abandon", hit)

	var miss_after: VigilState = _activated_incomplete_vigil(
		content, rules, "death", "run-eighth-recurrence-miss")
	var miss_run: RunState = RunState.new_run(content, miss, "run-eighth-next-miss", {
		"quests": miss_after.quests,
	})
	rules.prepare_run(miss_run)
	_check(fails, not _eighth_scheduled(miss_run),
		"seen/incomplete recurrence miss still scheduled Eighth Omen")

	var legacy_hit: RunState = _armed_eighth(
		content, hit, "run-eighth-legacy-hit", {"seen": true})
	rules.prepare_run(legacy_hit)
	_check(fails, _eighth_scheduled(legacy_hit),
		"legacy {seen:true} without due was not treated as recurrence")
	var legacy_miss: RunState = _armed_eighth(
		content, miss, "run-eighth-legacy-miss", {"seen": true})
	rules.prepare_run(legacy_miss)
	_check(fails, not _eighth_scheduled(legacy_miss),
		"legacy {seen:true} recurrence miss still scheduled")

	_eighth_same_run_reload(fails, content, rules)
	_eighth_completion_once(fails, content, rules)
	_eighth_corrupt_rejected(fails, content, rules, hit)
	_eighth_uses_content_chance(fails, content, hit, miss)
	_eighth_act3_complete_is_not_clear(fails, content, rules)

	SaveService.clear(EIGHTH_RUN_PATH)
	SaveService.clear_vigil(EIGHTH_VIGIL_PATH)
	if _file_snapshot(SaveService.RUN_PATH) != production \
			or _file_snapshot(SaveService.VIGIL_PATH) != production_vigil:
		fails.append("test_quests: eighth matrix touched the default save")


static func _f3_terminal_fold(
	fails: Array[String], content: ContentDB, rules: QuestRules, outcome: String, hit_seed: int
) -> void:
	var tag: String = "F3-%s" % outcome
	var vigil: VigilState = _activated_incomplete_vigil(
		content, rules, outcome, "run-eighth-%s" % outcome)
	var folded_v: Variant = vigil.quests.get("eighthOmen", {})
	var folded: Dictionary = folded_v if typeof(folded_v) == TYPE_DICTIONARY else {}
	var memory_v: Variant = folded.get("memory")
	var folded_memory: Dictionary = memory_v if typeof(memory_v) == TYPE_DICTIONARY else {}
	_check(fails, _flag(str(folded.get("state", "")) in QuestRules.ACTIVE
			and folded_memory.get("seen") == true
			and not folded_memory.has("dueIn")
			and not vigil.shards.has("eighthOmen")),
		"%s: incomplete terminal did not persist seen/missing-due memory" % tag)
	var next: RunState = RunState.new_run(content, hit_seed, "run-eighth-next-%s" % outcome, {
		"quests": vigil.quests,
	})
	rules.prepare_run(next)
	_check(fails, _eighth_scheduled(next),
		"%s: next prepare_run did not reschedule Eighth Omen" % tag)


static func _activated_incomplete_vigil(
	content: ContentDB, rules: QuestRules, outcome: String, run_id: String
) -> VigilState:
	var vigil: VigilState = VigilState.blank()
	vigil.quests["eighthOmen"]["state"] = "armed"
	vigil.quests["eighthOmen"]["memory"]["dueIn"] = 1
	SaveService.store_vigil(vigil, EIGHTH_VIGIL_PATH)
	var loaded_vigil: VigilState = SaveService.load_vigil(EIGHTH_VIGIL_PATH)
	var run: RunState = RunState.new_run(content, 55110, run_id, {
		"quests": loaded_vigil.quests,
	})
	rules.prepare_run(run)
	SaveService.store(run, EIGHTH_RUN_PATH)
	var disk: RunState = SaveService.load_run(content, EIGHTH_RUN_PATH)
	if disk != null:
		loaded_vigil.commit_run(disk, outcome, content)
	SaveService.store_vigil(loaded_vigil, EIGHTH_VIGIL_PATH)
	var folded: VigilState = SaveService.load_vigil(EIGHTH_VIGIL_PATH)
	return folded if folded != null else loaded_vigil


static func _eighth_same_run_reload(
	fails: Array[String], content: ContentDB, rules: QuestRules
) -> void:
	var run: RunState = _armed_eighth(
		content, 55111, "run-eighth-reload", {"dueIn": 1})
	rules.prepare_run(run)
	var omens_before: Array = run.omens.duplicate(true)
	var scratch_before: Dictionary = run.quest_scratch.duplicate(true)
	var rng_before: int = run.rng_state()
	var memory_before: Dictionary = _eighth_memory(run).duplicate(true)
	SaveService.store(run, EIGHTH_RUN_PATH)
	var loaded: RunState = SaveService.load_run(content, EIGHTH_RUN_PATH)
	_check(fails, loaded != null, "existing-run Eighth save was rejected")
	if loaded == null:
		return
	_check(fails, _flag(loaded.omens == omens_before
			and loaded.quest_scratch == scratch_before
			and loaded.rng_state() == rng_before
			and loaded.quests["eighthOmen"].get("memory") == memory_before),
		"existing-run save/reload re-rolled Eighth Omen or RNG identity")


static func _eighth_completion_once(
	fails: Array[String], content: ContentDB, rules: QuestRules
) -> void:
	var run: RunState = _armed_eighth(
		content, 55112, "run-eighth-complete-once", {"dueIn": 1})
	rules.prepare_run(run)
	run.act = QuestRules.EMBERGLASS_ACT
	var boss: CombatState = CombatState.new()
	boss.kind = &"boss"
	rules.on_combat_win(run, boss)
	_check(fails, _flag(str(run.quests["eighthOmen"].get("state", "")) == "complete"
			and run.quest_completions.has("eighthOmen")),
		"Act III boss under Eighth Omen did not complete the quest")
	rules.on_combat_win(run, boss)
	_check(fails, run.quest_completions.count("eighthOmen") == 1,
		"duplicate Eighth completion receipt double-granted")
	var vigil: VigilState = VigilState.blank()
	vigil.quests["eighthOmen"]["state"] = "armed"
	_check(fails, vigil.commit_run(run, "win", content), "Eighth completion commit rejected")
	_check(fails, vigil.shards.count("eighthOmen") == 1,
		"Eighth shard was not granted once")
	_check(fails, vigil.commit_run(run, "win", content), "duplicate terminal receipt rejected")
	_check(fails, vigil.shards.count("eighthOmen") == 1,
		"duplicate terminal receipt double-granted Eighth shard")
	_check(fails, _flag(not run.unlocks.has(RunState.MIRRORED_ROAD)
			and not vigil.unlocks.has(RunState.MIRRORED_ROAD)),
		"Eighth completion on the Act III boss recorded mirroredRoad")


static func _eighth_corrupt_rejected(
	fails: Array[String], content: ContentDB, rules: QuestRules, hit: int
) -> void:
	var over: RunState = _armed_eighth(
		content, hit, "run-eighth-corrupt-due", {"dueIn": 9})
	rules.prepare_run(over)
	_check(fails, _flag(not _eighth_scheduled(over)
			and str(over.quests["eighthOmen"].get("state", "")) == "armed"
			and int(float(str(over.quests["eighthOmen"].get("progress", -1)))) == 0
			and not over.quest_completions.has("eighthOmen")),
		"corrupt dueIn silently granted Eighth progress")
	var zero: RunState = _armed_eighth(
		content, hit, "run-eighth-corrupt-zero", {"dueIn": 0, "seen": true})
	rules.prepare_run(zero)
	_check(fails, _flag(not _eighth_scheduled(zero)
			and str(zero.quests["eighthOmen"].get("state", "")) == "armed"),
		"dueIn=0 with seen silently granted Eighth progress")
	var bare: RunState = _armed_eighth(
		content, hit, "run-eighth-corrupt-bare", {})
	rules.prepare_run(bare)
	_check(fails, _flag(not _eighth_scheduled(bare)
			and str(bare.quests["eighthOmen"].get("state", "")) == "armed"),
		"armed Eighth without due or seen silently granted progress")


static func _eighth_uses_content_chance(
	fails: Array[String], content: ContentDB, hit: int, miss: int
) -> void:
	var never: ContentDB = ContentDB.load_full()
	var never_eighth: Dictionary = never.progression["emberglass"]["eighthOmen"]
	never_eighth["recurrenceChance"] = 0.0
	var never_rules: QuestRules = QuestRules.new(never)
	var due_never: RunState = _armed_eighth(
		never, hit, "run-eighth-chance-0-due", {"dueIn": 2})
	never_rules.prepare_run(due_never)
	_check(fails, _flag(not _eighth_scheduled(due_never)
			and int(float(str(_eighth_memory(due_never).get("dueIn", 0)))) == 1),
		"due=2 ignored content recurrenceChance=0")
	var seen_never: RunState = _armed_eighth(
		never, hit, "run-eighth-chance-0-seen", {"seen": true})
	never_rules.prepare_run(seen_never)
	_check(fails, not _eighth_scheduled(seen_never),
		"recurrence ignored content recurrenceChance=0")
	var always: ContentDB = ContentDB.load_full()
	var always_eighth: Dictionary = always.progression["emberglass"]["eighthOmen"]
	always_eighth["recurrenceChance"] = 1.0
	var always_rules: QuestRules = QuestRules.new(always)
	var due_always: RunState = _armed_eighth(
		always, miss, "run-eighth-chance-1-due", {"dueIn": 2})
	always_rules.prepare_run(due_always)
	_check(fails, _eighth_scheduled(due_always),
		"due=2 ignored content recurrenceChance=1")
	var seen_always: RunState = _armed_eighth(
		always, miss, "run-eighth-chance-1-seen", {"seen": true})
	always_rules.prepare_run(seen_always)
	_check(fails, _eighth_scheduled(seen_always),
		"recurrence ignored content recurrenceChance=1")


static func _eighth_act3_complete_is_not_clear(
	fails: Array[String], content: ContentDB, rules: QuestRules
) -> void:
	var run: RunState = _armed_eighth(
		content, 55113, "run-eighth-not-clear", {"dueIn": 1})
	rules.prepare_run(run)
	run.act = QuestRules.EMBERGLASS_ACT
	var boss: CombatState = CombatState.new()
	boss.kind = &"boss"
	rules.on_combat_win(run, boss)
	var vigil: VigilState = VigilState.blank()
	vigil.quests["eighthOmen"]["state"] = "armed"
	vigil.commit_run(run, "win", content)
	_check(fails, _flag(vigil.shards.has("eighthOmen")
			and not vigil.unlocks.has(RunState.MIRRORED_ROAD)
			and not run.unlocks.has(RunState.MIRRORED_ROAD)
			and vigil.shards.size() == 1),
		"Eighth Act III completion was not distinct from an Act IV clear")


static func _file_snapshot(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return FileAccess.get_file_as_string(path)
