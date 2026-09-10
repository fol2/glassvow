class_name QuestRules
extends RefCounted
## The six Emberglass journeys share one small state machine. Screens reveal
## decisions; this class owns progress, completion and shard laws.

const ACTIVE: Array[String] = ["armed", "revealed"]
const PALE_VARIANTS: Array[String] = ["paleDuskfang", "paleDrownedOne", "paleVoidWisp"]
const EMBERGLASS_ACT: int = 2

var content: ContentDB


func _init(content_db: ContentDB) -> void:
	content = content_db


static func _ji(value: Variant) -> int:
	return int(float(str(value)))


func record(run: RunState, id: String) -> Dictionary:
	var value: Variant = run.quests.get(id)
	return value if typeof(value) == TYPE_DICTIONARY else {}


func active(run: RunState, id: String) -> bool:
	return str(record(run, id).get("state", "dormant")) in ACTIVE


func advance(run: RunState, id: String, amount: int = 1) -> bool:
	var quest: Dictionary = record(run, id)
	if quest.is_empty() or not active(run, id):
		return false
	quest["state"] = "revealed"
	var target: int = _ji(content.quests[id].get("target", 1))
	quest["progress"] = mini(target, _ji(quest.get("progress", 0)) + amount)
	if _ji(quest["progress"]) < target:
		return false
	quest["state"] = "complete"
	if not run.quest_completions.has(id):
		run.quest_completions.append(id)
	return true


func prepare_run(run: RunState) -> void:
	if active(run, "paleOnes"):
		run.quest_scratch["paleOnes"] = {"hiddenRemaining": 1}
	var eighth: Dictionary = record(run, "eighthOmen")
	if active(run, "eighthOmen"):
		var memory: Dictionary = eighth.get("memory", {})
		var due: int = _ji(memory.get("dueIn", 0))
		var active_now: bool = due == 1 or (due > 1 and run.rng.next() < 1.0 / 3.0)
		if active_now:
			run.quest_scratch["eighthOmen"] = {"active": true}
			if run.omens.is_empty():
				run.omens.append("eighthOmen")
			else:
				run.omens[0] = "eighthOmen"
			memory.erase("dueIn")
			memory["seen"] = true
		elif due > 1:
			memory["dueIn"] = due - 1
	if active(run, "hollowLamplighter"):
		var hollow: Dictionary = record(run, "hollowLamplighter")
		var memory: Dictionary = hollow.get("memory", {})
		var debt: int = _ji(memory.get("emberDebt", 0))
		if debt > 0:
			run.quest_scratch["hollowLamplighter"] = {
				"due": false, "met": false, "meetings": 0,
				"debtActive": true, "emberDebt": debt,
			}
		else:
			var rules: Dictionary = content.progression["emberglass"]["hollowLamplighter"]
			var misses: int = _ji(memory.get("eligibleMisses", 0))
			var due: bool = misses >= _ji(rules["pityEligibleRuns"]) - 1 \
				or run.rng.next() < float(str(rules["appearanceChance"]))
			run.quest_scratch["hollowLamplighter"] = {
				"due": due, "met": false, "meetings": 0, "debtActive": false,
			}


func stage_hollow_meeting(run: RunState, node: MapNode, was_unlit: bool) -> bool:
	if not was_unlit or not active(run, "hollowLamplighter"):
		return false
	var scratch_v: Variant = run.quest_scratch.get("hollowLamplighter")
	if typeof(scratch_v) != TYPE_DICTIONARY:
		return false
	var scratch: Dictionary = scratch_v
	var max_meetings: int = _ji(
		content.progression["emberglass"]["hollowLamplighter"]["maxMeetingsPerRun"])
	if not scratch.get("due", false) or scratch.get("debtActive", false) \
			or _ji(scratch.get("meetings", 0)) >= max_meetings:
		return false
	scratch["meetings"] = _ji(scratch.get("meetings", 0)) + 1
	scratch["met"] = true
	var quest: Dictionary = record(run, "hollowLamplighter")
	quest["state"] = "revealed"
	run.pending_hollow = {
		"nodeId": node.id, "type": node.type,
		"meeting": _ji(quest.get("progress", 0)),
		"paid": false, "deferred": false, "answer": "",
	}
	return true


func decorate_map(run: RunState, map: WorldMap) -> void:
	if not active(run, "paleOnes"):
		return
	var progress: int = _ji(record(run, "paleOnes").get("progress", 0))
	var lens: bool = run.unlocks.has("insight:witchlightLens")
	if not lens and progress < 3:
		return
	for node: MapNode in map.nodes:
		if node.type == "monster" and node.row == 0:
			node.quest_variant_id = PALE_VARIANTS[clampi(run.act, 0, 2)]
			node.quest_marked = true
			return


func encounter_override(run: RunState, type: String, node: MapNode) -> Array[String]:
	if type == "boss" and run.act == EMBERGLASS_ACT \
			and run.quest_scratch.get("usurper", {}).get("bought", false):
		return ["usurpedSovereign"]
	if node.quest_variant_id != null:
		return [str(node.quest_variant_id)]
	var pale_v: Variant = run.quest_scratch.get("paleOnes")
	if type == "monster" and typeof(pale_v) == TYPE_DICTIONARY:
		var pale: Dictionary = pale_v
		var remaining: int = _ji(pale.get("hiddenRemaining", 0))
		if remaining > 0:
			pale["hiddenRemaining"] = remaining - 1
			return [PALE_VARIANTS[clampi(run.act, 0, 2)]]
	return []


func on_enemy_death(run: RunState, definition: Dictionary) -> void:
	var drop_v: Variant = definition.get("drop")
	if typeof(drop_v) != TYPE_DICTIONARY:
		return
	var drop: Dictionary = drop_v
	var id: String = str(drop.get("quest", ""))
	if not content.quest_ids.has(id):
		return
	advance(run, id, _ji(drop.get("n", 1)))
	if id == "paleOnes" and _ji(record(run, id).get("progress", 0)) >= 3 \
			and not run.unlocks.has("insight:witchlightLens"):
		run.unlocks.append("insight:witchlightLens")


func on_combat_win(run: RunState, cb: CombatState) -> void:
	if cb.kind != &"boss" or run.act != EMBERGLASS_ACT:
		return
	var eighth_v: Variant = run.quest_scratch.get("eighthOmen")
	if typeof(eighth_v) == TYPE_DICTIONARY and eighth_v.get("active", false):
		advance(run, "eighthOmen")
	var page: Dictionary = record(run, "unreadablePage")
	if active(run, "unreadablePage") and _ji(page.get("progress", 0)) < 5:
		for card: CardInst in run.player.deck:
			if card.id == &"unreadablePage":
				advance(run, "unreadablePage")
				break


func adjust_reward_cards(run: RunState, kind: String, cards: Array) -> void:
	if kind == "boss" and (run.act == EMBERGLASS_ACT or run.is_final_act()) \
			or not active(run, "unreadablePage") or cards.is_empty():
		return
	var scratch: Dictionary = run.quest_scratch.get("unreadablePage", {})
	scratch["rewardOrdinal"] = _ji(scratch.get("rewardOrdinal", 0)) + 1
	if _ji(scratch["rewardOrdinal"]) == 2 and not scratch.get("offered", false):
		cards[cards.size() - 1] = "unreadablePage"
		scratch["offered"] = true
		record(run, "unreadablePage")["state"] = "revealed"
	run.quest_scratch["unreadablePage"] = scratch


func usurper_offer(run: RunState) -> Dictionary:
	if not active(run, "usurper") or run.act < 1 \
			or run.quest_scratch.get("usurper", {}).get("bought", false):
		return {}
	return {
		"id": "flamelessLantern",
		"name": str(content.quests["usurper"].get("itemName", "A Lantern with No Flame")),
		"price": 650,
	}


func buy_usurper(run: RunState) -> bool:
	if usurper_offer(run).is_empty() or run.player.gold < 650:
		return false
	run.player.gold -= 650
	run.quest_scratch["usurper"] = {"bought": true}
	record(run, "usurper")["state"] = "revealed"
	return true


func pay_lamplighter(run: RunState) -> Dictionary:
	var quest: Dictionary = record(run, "hollowLamplighter")
	if not active(run, "hollowLamplighter"):
		return {"ok": false, "message": "ui.hollow.message.inactive"}
	var step: int = _ji(quest.get("progress", 0))
	match step:
		0:
			var scratch: Dictionary = run.quest_scratch.get("hollowLamplighter", {})
			scratch["emberDebt"] = 3
			scratch["debtActive"] = true
			run.quest_scratch["hollowLamplighter"] = scratch
			var memory: Dictionary = quest.get("memory", {})
			memory["emberDebt"] = 3
			quest["memory"] = memory
			quest["state"] = "revealed"
			return {"ok": true, "message": "ui.hollow.message.emberDebt"}
		1:
			if run.player.gold < 160:
				return {"ok": false, "message": "ui.hollow.message.needGold"}
			run.player.gold -= 160
		2:
			if run.player.max_hp - 12 < 30:
				return {"ok": false, "message": "ui.hollow.message.vesselTooFragile"}
			run.player.max_hp -= 12
			run.player.hp = mini(run.player.hp, run.player.max_hp)
		3:
			if not RewardRules.new(content).reverse_boon(run):
				return {"ok": false, "message": "ui.hollow.message.needBoon"}
		4:
			run.player.hp = 1
	advance(run, "hollowLamplighter")
	return {"ok": true, "message": "ui.hollow.message.paneLit"}


func pay_hollow_price(run: RunState) -> Dictionary:
	if typeof(run.pending_hollow) != TYPE_DICTIONARY:
		return {"ok": false, "message": "ui.hollow.message.noPriceWaiting"}
	var pending: Dictionary = run.pending_hollow
	if pending.get("paid", false):
		return {"ok": true, "message": str(pending.get("answer", ""))}
	var deferred: bool = _ji(record(run, "hollowLamplighter").get("progress", 0)) == 0
	var result: Dictionary = pay_lamplighter(run)
	if not result.get("ok", false):
		return result
	pending["paid"] = true
	pending["deferred"] = deferred
	pending["answer"] = str(result.get("message", ""))
	return result


func tithe_embers(run: RunState, amount: int) -> int:
	if amount <= 0:
		return amount
	var scratch_v: Variant = run.quest_scratch.get("hollowLamplighter")
	if typeof(scratch_v) != TYPE_DICTIONARY:
		return amount
	var scratch: Dictionary = scratch_v
	var debt: int = _ji(scratch.get("emberDebt", 0))
	var paid: int = mini(amount, debt)
	if paid == 0:
		return amount
	debt -= paid
	var quest: Dictionary = record(run, "hollowLamplighter")
	var memory: Dictionary = quest.get("memory", {})
	if debt == 0:
		scratch.erase("emberDebt")
		scratch["debtActive"] = false
		memory.erase("emberDebt")
		advance(run, "hollowLamplighter")
	else:
		scratch["emberDebt"] = debt
		memory["emberDebt"] = debt
	quest["memory"] = memory
	return amount - paid
