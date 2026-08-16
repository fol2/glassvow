class_name VigilState
extends RefCounted
## Cross-run v2 ledger. The runId receipts make terminal effects safe to retry:
## a crash may leave the run checkpoint behind, but it cannot count deeds,
## shards, or a standing bequest twice.

const VERSION: int = 2
const QUEST_IDS: Array[String] = [
	"paleOnes", "ownShade", "usurper", "eighthOmen", "unreadablePage",
	"hollowLamplighter",
]
const OUTCOMES: Array[String] = ["win", "death", "abandon"]
const DEFAULT_DEEDS: Dictionary = {
	"runs": 0, "wins": 0, "slain": 0, "shatters": 0, "kindles": 0,
	"perfects": 0, "smolderKills": 0, "unlitVisited": 0, "embersSpent": 0,
	"bestVow": 0, "bestWaystone": 0,
}

var deeds: Dictionary = DEFAULT_DEEDS.duplicate()
var unlocks: Array[String] = []
var vow_unlocked: int = 0
var last_fall: Variant = null
var runs_played: int = 0
var quests: Dictionary = {}
var shards: Array[String] = []
var whispers: int = 0
var news: bool = false
var receipts: Dictionary = {"deeds": null, "runEnd": null}
## Once-flags for scripted scenes. Not `unlocks`: that set is the title
## "secrets" count and the Dawn reveal feed.
var scenes_seen: Array[String] = []
## Profile-wide hint suppression, written when the opening's skip-guidance
## offer is accepted. Not `unlocks` — same secrets/dawn-card side effects.
var guidance_skipped: bool = false
## Once-flags for the six first-run hints. Adjacent to `scenes_seen`, never
## `unlocks` — a hint key in unlocks would inflate the title secrets count.
var hints_seen: Array[String] = []
## Vigil-scoped scene cursor. The unsealing plays after the run save is gone.
var pending_scene: Variant = null
## Additive v2: defeat epitaphs are line-table ids, never prose. Missing on
## load defaults empty — no envelope bump.
var defeat_epitaphs: Array[String] = []
var line_recent: Array = []
var line_once: Array[String] = []


static func _ji(value: Variant) -> int:
	return int(float(str(value)))


static func blank() -> VigilState:
	var vigil: VigilState = VigilState.new()
	for id: String in QUEST_IDS:
		vigil.quests[id] = {"state": "dormant", "progress": 0, "memory": {}}
	return vigil


func to_dict() -> Dictionary:
	return {
		"v": VERSION,
		"deeds": deeds.duplicate(true),
		"unlocks": unlocks.duplicate(),
		"vowUnlocked": vow_unlocked,
		"lastFall": last_fall,
		"runsPlayed": runs_played,
		"quests": quests.duplicate(true),
		"shards": shards.duplicate(),
		"whispers": whispers,
		"news": news,
		"receipts": receipts.duplicate(true),
		"scenesSeen": scenes_seen.duplicate(),
		"guidanceSkipped": guidance_skipped,
		"hintsSeen": hints_seen.duplicate(),
		"pendingScene": pending_scene.duplicate(true) \
			if typeof(pending_scene) == TYPE_DICTIONARY else pending_scene,
		"defeatEpitaphs": defeat_epitaphs.duplicate(),
		"lineRecent": line_recent.duplicate(true),
		"lineOnce": line_once.duplicate(),
	}


static func from_dict(raw: Dictionary) -> VigilState:
	if int(float(str(raw.get("v", -1)))) != VERSION:
		return null
	if typeof(raw.get("deeds")) != TYPE_DICTIONARY \
			or typeof(raw.get("quests")) != TYPE_DICTIONARY \
			or typeof(raw.get("receipts")) != TYPE_DICTIONARY:
		return null
	var vigil: VigilState = blank()
	var raw_deeds: Dictionary = raw["deeds"]
	for key: String in DEFAULT_DEEDS:
		var n: int = int(float(str(raw_deeds.get(key, 0))))
		if n < 0:
			return null
		vigil.deeds[key] = n
	for unlock_v: Variant in raw.get("unlocks", []):
		vigil.unlocks.append(str(unlock_v))
	vigil.vow_unlocked = maxi(0, int(float(str(raw.get("vowUnlocked", 0)))))
	vigil.last_fall = raw.get("lastFall")
	vigil.runs_played = maxi(0, int(float(str(raw.get("runsPlayed", 0)))))
	var raw_quests: Dictionary = raw["quests"]
	for id: String in QUEST_IDS:
		var q_v: Variant = raw_quests.get(id)
		if typeof(q_v) != TYPE_DICTIONARY:
			return null
		var q: Dictionary = q_v
		if str(q.get("state")) not in ["dormant", "armed", "revealed", "complete"] \
				or int(float(str(q.get("progress", -1)))) < 0 \
				or typeof(q.get("memory")) != TYPE_DICTIONARY:
			return null
		vigil.quests[id] = q.duplicate(true)
	var seen_shards: Dictionary = {}
	for shard_v: Variant in raw.get("shards", []):
		var shard: String = str(shard_v)
		if shard not in QUEST_IDS or seen_shards.has(shard):
			return null
		seen_shards[shard] = true
		vigil.shards.append(shard)
	vigil.whispers = maxi(0, int(float(str(raw.get("whispers", 0)))))
	vigil.news = raw.get("news", false)
	var seen_v: Variant = raw.get("scenesSeen", [])
	if typeof(seen_v) == TYPE_ARRAY:
		for id_v: Variant in seen_v:
			var seen: String = str(id_v)
			if not seen.is_empty() and not vigil.scenes_seen.has(seen):
				vigil.scenes_seen.append(seen)
	vigil.guidance_skipped = raw.get("guidanceSkipped", false) == true
	_read_ids(raw.get("hintsSeen", []), vigil.hints_seen, true)
	var scene_v: Variant = raw.get("pendingScene")
	if typeof(scene_v) == TYPE_DICTIONARY:
		var scene: Dictionary = scene_v
		if not str(scene.get("id", "")).is_empty() and _ji(scene.get("cursor", -1)) >= 0:
			vigil.pending_scene = scene.duplicate(true)
	_read_ids(raw.get("defeatEpitaphs", []), vigil.defeat_epitaphs, false)
	_read_ids(raw.get("lineOnce", []), vigil.line_once, true)
	var recent_v: Variant = raw.get("lineRecent", [])
	if typeof(recent_v) == TYPE_ARRAY:
		for run_v: Variant in recent_v:
			if typeof(run_v) != TYPE_ARRAY:
				continue
			var bucket: Array = []
			for id_v: Variant in run_v:
				var drawn: String = str(id_v)
				if not drawn.is_empty():
					bucket.append(drawn)
			vigil.line_recent.append(bucket)
	var raw_receipts: Dictionary = raw["receipts"]
	for key: String in ["deeds", "runEnd"]:
		var receipt_v: Variant = raw_receipts.get(key)
		if receipt_v != null and not _valid_receipt(receipt_v):
			return null
		vigil.receipts[key] = receipt_v
	return vigil


static func _read_ids(value: Variant, into: Array[String], unique: bool) -> void:
	if typeof(value) != TYPE_ARRAY:
		return
	for id_v: Variant in value:
		var id: String = str(id_v)
		if id.is_empty() or (unique and into.has(id)):
			continue
		into.append(id)


static func _valid_receipt(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var receipt: Dictionary = value
	return not str(receipt.get("runId", "")).is_empty()


## Fold one terminal run into this ledger. Repeating the same runId/outcome is
## a successful no-op; changing the outcome for that runId is rejected.
func commit_run(run: RunState, outcome: String, content: ContentDB) -> bool:
	if outcome not in OUTCOMES or run.run_id.is_empty():
		return false
	var prior_v: Variant = receipts.get("runEnd")
	if prior_v != null:
		var prior: Dictionary = prior_v
		if str(prior.get("runId")) == run.run_id:
			return str(prior.get("outcome")) == outcome

	if outcome != "abandon":
		deeds["runs"] = _ji(deeds["runs"]) + 1
		if outcome == "win":
			deeds["wins"] = _ji(deeds["wins"]) + 1
			deeds["bestVow"] = maxi(_ji(deeds["bestVow"]), run.vow)
			vow_unlocked = maxi(vow_unlocked, mini(5, run.vow + 1))
		deeds["bestWaystone"] = maxi(_ji(deeds["bestWaystone"]), run.act * 15 + run.waystones_lit)
		for key: String in [
			"slain", "shatters", "kindles", "perfects", "smolderKills",
			"unlitVisited", "embersSpent",
		]:
			deeds[key] = _ji(deeds[key]) + _ji(run.stats.get(key, 0))
		receipts["deeds"] = {"runId": run.run_id, "won": outcome == "win"}

	var completed: Array[String] = []
	for unlock_v: Variant in run.unlocks:
		var unlock: String = str(unlock_v)
		if not unlocks.has(unlock):
			unlocks.append(unlock)
	for id: String in QUEST_IDS:
		var run_q_v: Variant = run.quests.get(id)
		if typeof(run_q_v) != TYPE_DICTIONARY:
			continue
		var run_q: Dictionary = run_q_v
		var vigil_q: Dictionary = quests[id]
		vigil_q["progress"] = maxi(_ji(vigil_q["progress"]), _ji(run_q.get("progress", 0)))
		var memory_v: Variant = run_q.get("memory")
		if typeof(memory_v) == TYPE_DICTIONARY:
			var memory: Dictionary = memory_v
			vigil_q["memory"] = memory.duplicate(true)
			if str(run_q.get("state")) == "complete":
				vigil_q["state"] = "complete"
				if not shards.has(id):
					shards.append(id)
					completed.append(id)
	var hollow_scratch_v: Variant = run.quest_scratch.get("hollowLamplighter")
	var persisted_hollow: Dictionary = quests["hollowLamplighter"]
	if typeof(hollow_scratch_v) == TYPE_DICTIONARY \
			and str(persisted_hollow["state"]) in ["armed", "revealed"] \
			and not hollow_scratch_v.get("debtActive", false):
		var hollow_scratch: Dictionary = hollow_scratch_v
		var memory: Dictionary = persisted_hollow["memory"]
		memory["eligibleMisses"] = 0 if hollow_scratch.get("met", false) \
			else _ji(memory.get("eligibleMisses", 0)) + 1
	if str(persisted_hollow["state"]) == "complete":
		persisted_hollow["memory"].erase("eligibleMisses")
	# Count this run's new shards first so a win that earns the first pane
	# may speak immediately, while shard-zero wins stay inside L0.
	var drawn: Array = []
	if outcome == "win":
		_hear_whisper(run, content)
	runs_played += 1
	if outcome == "death":
		var own_shade_v: Variant = run.quest_scratch.get("ownShade")
		if typeof(own_shade_v) == TYPE_DICTIONARY:
			var own_shade: Dictionary = own_shade_v
			var fall_v: Variant = own_shade.get("fall")
			if typeof(fall_v) == TYPE_DICTIONARY:
				last_fall = fall_v.duplicate(true)
				last_fall["standing"] = true
		drawn = _write_epitaph(run, content)
	line_recent = LineTable.remember(line_recent, drawn)
	receipts["runEnd"] = {
		"runId": run.run_id,
		"outcome": outcome,
		"completed": completed,
	}
	_refresh_unlocks(content, outcome)
	news = news or not completed.is_empty() or outcome != "abandon"
	return true


func _line_ctx(run: RunState) -> Dictionary:
	var ctx: Dictionary = LineTable.context(run, shards.size())
	return ctx


func _hear_whisper(run: RunState, content: ContentDB) -> void:
	if LineTable.slot_open(content.line_table, "whisper", _line_ctx(run)):
		whispers += 1


func _write_epitaph(run: RunState, content: ContentDB) -> Array:
	var last_id: String = defeat_epitaphs[defeat_epitaphs.size() - 1] \
		if not defeat_epitaphs.is_empty() else ""
	var row: Dictionary = LineTable.select(
		content.line_table, "loss", _line_ctx(run), run.rng, {
			"recent": line_recent,
			"once": line_once,
			"last_id": last_id,
		})
	var id: String = str(row.get("id", ""))
	if id.is_empty():
		return []
	defeat_epitaphs.append(id)
	if row.get("once", false) and not line_once.has(id):
		line_once.append(id)
	return [id]


func _refresh_unlocks(content: ContentDB, outcome: String) -> void:
	var thresholds: Dictionary = content.progression.get("revealThresholds", {})
	for id: String in thresholds:
		var trigger: Dictionary = thresholds[id]
		var reached: bool = (
			runs_played >= _ji(trigger["runsPlayed"]) if trigger.has("runsPlayed")
			else (_ji(deeds["wins"]) >= _ji(trigger["wins"]) if trigger.has("wins")
				else shards.size() >= _ji(trigger.get("shards", 999)))
		)
		if reached and not unlocks.has(id):
			unlocks.append(id)
	for deed_v: Variant in content.deeds.values():
		var deed: Dictionary = deed_v
		if _ji(deeds.get(str(deed.get("stat")), 0)) < _ji(deed.get("n", 0)):
			continue
		for unlock_v: Variant in deed.get("unlocks", []):
			var unlock: String = str(unlock_v)
			if not unlocks.has(unlock):
				unlocks.append(unlock)
	if _ji(deeds["wins"]) >= 1 and str(quests["paleOnes"]["state"]) == "dormant":
		quests["paleOnes"]["state"] = "armed"
	if outcome != "win":
		return
	var arm_wins: Array = content.progression.get("emberglass", {}).get("armWins", [])
	if not arm_wins.has(_ji(deeds["wins"])):
		return
	for id: String in QUEST_IDS:
		if id != "paleOnes" and str(quests[id]["state"]) == "dormant":
			quests[id]["state"] = "armed"
			if id == "eighthOmen":
				quests[id]["memory"]["dueIn"] = 2
			break
