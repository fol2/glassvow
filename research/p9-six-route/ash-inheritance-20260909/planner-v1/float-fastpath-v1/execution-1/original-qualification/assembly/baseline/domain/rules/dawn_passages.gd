class_name DawnPassages
extends RefCounted
## Batch 4 dawn-ceremony leaves. Selection is the signed milestone, never a
## roll. Ids are locale keys (`story.dawn.*`).

const PROGRESS: Dictionary = {
	"paleOnes": {1: "story.dawn.paleOnes.p1", 5: "story.dawn.paleOnes.p2"},
	"ownShade": {1: "story.dawn.ownShade.p1", 2: "story.dawn.ownShade.p2"},
	"unreadablePage": {
		1: "story.dawn.unreadablePage.p1", 2: "story.dawn.unreadablePage.p2",
		3: "story.dawn.unreadablePage.p3", 4: "story.dawn.unreadablePage.p4",
	},
	"hollowLamplighter": {
		1: "story.dawn.hollowLamplighter.p1", 2: "story.dawn.hollowLamplighter.p2",
		3: "story.dawn.hollowLamplighter.p3", 4: "story.dawn.hollowLamplighter.p4",
	},
}
const DONE: Dictionary = {
	"paleOnes": "story.dawn.paleOnes.done",
	"ownShade": "story.dawn.ownShade.done",
	"usurper": "story.dawn.usurper.done",
	"eighthOmen": "story.dawn.eighthOmen.done",
	"unreadablePage": "story.dawn.unreadablePage.done",
	"hollowLamplighter": "story.dawn.hollowLamplighter.done",
}
const USURPER_LANTERN: String = "story.dawn.usurper.p1"
const OMEN_RISES: String = "story.dawn.eighthOmen.p1"


static func _ji(value: Variant) -> int:
	return int(float(str(value)))


static func pane_leaf(n: int) -> String:
	return "story.dawn.pane.%d" % n


static func quest_of(leaf: String) -> String:
	if not leaf.begins_with("story.dawn.") or leaf.begins_with("story.dawn.pane."):
		return ""
	var rest: String = leaf.substr("story.dawn.".length())
	var dot: int = rest.find(".")
	return rest.substr(0, dot) if dot > 0 else ""


static func earned(
		before_quests: Dictionary, after_quests: Dictionary,
		before_shards: int, after_shards: int
) -> Array[String]:
	var out: Array[String] = []
	for id: String in VigilState.QUEST_IDS:
		var before: Dictionary = _quest(before_quests, id)
		var after: Dictionary = _quest(after_quests, id)
		_cross_progress(id, _ji(before.get("progress", 0)), _ji(after.get("progress", 0)), out)
		_cross_special(id, before, after, out)
		if str(after.get("state", "")) == "complete" \
				and str(before.get("state", "")) != "complete":
			var done: String = str(DONE.get(id, ""))
			if not done.is_empty():
				out.append(done)
	for n: int in range(1, 6):
		if before_shards < n and after_shards >= n:
			out.append(pane_leaf(n))
	return out


static func archive(vigil: VigilState, leaves: Array[String]) -> Array[String]:
	var fresh: Array[String] = []
	for leaf: String in leaves:
		if leaf.is_empty() or vigil.dawn_leaves.has(leaf):
			continue
		vigil.dawn_leaves.append(leaf)
		fresh.append(leaf)
		var id: String = quest_of(leaf)
		if id.is_empty() or not vigil.quests.has(id):
			continue
		var quest: Dictionary = vigil.quests[id]
		var memory_v: Variant = quest.get("memory", {})
		var memory: Dictionary = memory_v if typeof(memory_v) == TYPE_DICTIONARY else {}
		var dawn_v: Variant = memory.get("dawn", [])
		var dawn: Array = dawn_v if typeof(dawn_v) == TYPE_ARRAY else []
		if not dawn.has(leaf):
			dawn.append(leaf)
		memory["dawn"] = dawn
		quest["memory"] = memory
	return fresh


static func attach_leaf(quest_id: String, kind: String, leaves: Array[String]) -> String:
	if kind == "shard":
		var done: String = str(DONE.get(quest_id, ""))
		return done if leaves.has(done) else ""
	var progress: String = highest_progress_leaf(quest_id, leaves)
	if not progress.is_empty():
		return progress
	if quest_id == "usurper" and leaves.has(USURPER_LANTERN):
		return USURPER_LANTERN
	if quest_id == "eighthOmen" and leaves.has(OMEN_RISES):
		return OMEN_RISES
	return ""


static func highest_progress_leaf(quest_id: String, leaves: Array[String]) -> String:
	var row_v: Variant = PROGRESS.get(quest_id, {})
	if typeof(row_v) != TYPE_DICTIONARY:
		return ""
	var row: Dictionary = row_v
	var best: String = ""
	var best_at: int = -1
	for at_v: Variant in row:
		var at: int = _ji(at_v)
		var leaf: String = str(row[at_v])
		if at >= best_at and leaves.has(leaf):
			best_at = at
			best = leaf
	return best


static func _cross_progress(
		id: String, before: int, after: int, out: Array[String]
) -> void:
	var row_v: Variant = PROGRESS.get(id, {})
	if typeof(row_v) != TYPE_DICTIONARY or after <= before:
		return
	var row: Dictionary = row_v
	var ats: Array = row.keys()
	ats.sort()
	for at_v: Variant in ats:
		var at: int = _ji(at_v)
		if before < at and after >= at:
			out.append(str(row[at_v]))


static func _cross_special(
		id: String, before: Dictionary, after: Dictionary, out: Array[String]
) -> void:
	if id == "usurper" and _has_lantern(after) and not _has_lantern(before):
		out.append(USURPER_LANTERN)
	if id == "eighthOmen" and _omen_up(after) and not _omen_up(before):
		out.append(OMEN_RISES)


static func _has_lantern(quest: Dictionary) -> bool:
	var state: String = str(quest.get("state", "dormant"))
	return state == "revealed" or state == "complete"


static func _omen_up(quest: Dictionary) -> bool:
	if _has_lantern(quest) or str(quest.get("state", "")) == "complete":
		return true
	var memory_v: Variant = quest.get("memory", {})
	return typeof(memory_v) == TYPE_DICTIONARY and memory_v.get("seen", false) == true


static func _quest(quests: Dictionary, id: String) -> Dictionary:
	var value: Variant = quests.get(id, {})
	return value if typeof(value) == TYPE_DICTIONARY else {}
