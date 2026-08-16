class_name LineTable
extends RefCounted
## One flat narrative table. Reveal-ladder enforcement is the `conditions`
## column — there is no parallel gate. Phase-1 vocabulary: shard-count, act,
## quest-state. Pools draw here; the whisper queue only asks whether its
## channel is open.

const L1_SHARDS: int = 1
const L2_SHARDS: int = 4
const L3_SHARDS: int = 6
const DEFAULT_COOLDOWN_RUNS: int = 3
const RECENT_CAP: int = 8


static func _ji(value: Variant) -> int:
	return int(float(str(value)))


static func context(run: RunState, shard_count: int = -1) -> Dictionary:
	var quests: Dictionary = {}
	for id_v: Variant in run.quests:
		var rec_v: Variant = run.quests[id_v]
		if typeof(rec_v) == TYPE_DICTIONARY:
			quests[str(id_v)] = str(rec_v.get("state", "dormant"))
	return {
		"shards": shard_count if shard_count >= 0 else run.shards.size(),
		"act": run.act,
		"quests": quests,
	}


## Current-run completions count: a fourth pane earned this journey opens L2
## before VigilState folds the receipt.
static func projected_shard_count(run: RunState, variant_id: StringName = &"") -> int:
	var seen: Dictionary = {}
	for shard_v: Variant in run.shards:
		seen[str(shard_v)] = true
	for completion_v: Variant in run.quest_completions:
		seen[str(completion_v)] = true
	if variant_id != &"ownShade3" or seen.has("ownShade"):
		return seen.size()
	var quest_v: Variant = run.quests.get("ownShade")
	if typeof(quest_v) != TYPE_DICTIONARY:
		return seen.size()
	var quest: Dictionary = quest_v
	if str(quest.get("state", "dormant")) not in ["armed", "revealed"]:
		return seen.size()
	var progress: int = _ji(quest.get("progress", 0))
	if progress + 1 >= 3:
		seen["ownShade"] = true
	return seen.size()


static func conditions_match(conditions_v: Variant, ctx: Dictionary) -> bool:
	if typeof(conditions_v) != TYPE_DICTIONARY:
		return true
	var conditions: Dictionary = conditions_v
	if conditions.has("shards_gte") and _ji(ctx.get("shards", 0)) < _ji(conditions["shards_gte"]):
		return false
	if conditions.has("act") and _ji(ctx.get("act", -1)) != _ji(conditions["act"]):
		return false
	if typeof(conditions.get("quest_state")) == TYPE_DICTIONARY:
		var wanted: Dictionary = conditions["quest_state"]
		var quests_v: Variant = ctx.get("quests", {})
		var quests: Dictionary = quests_v if typeof(quests_v) == TYPE_DICTIONARY else {}
		for id_v: Variant in wanted:
			if str(quests.get(str(id_v), "")) != str(wanted[id_v]):
				return false
	return true


static func specificity(conditions_v: Variant) -> int:
	if typeof(conditions_v) != TYPE_DICTIONARY:
		return 0
	var conditions: Dictionary = conditions_v
	return conditions.size()


static func has_slot(rows: Array, slot: String) -> bool:
	for row_v: Variant in rows:
		if typeof(row_v) == TYPE_DICTIONARY and str(row_v.get("slot", "")) == slot:
			return true
	return false


static func slot_open(rows: Array, slot: String, ctx: Dictionary) -> bool:
	for row_v: Variant in rows:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		if str(row.get("slot", "")) == slot and conditions_match(row.get("conditions", {}), ctx):
			return true
	return false


static func row_by_id(rows: Array, id: String) -> Dictionary:
	for row_v: Variant in rows:
		if typeof(row_v) == TYPE_DICTIONARY and str(row_v.get("id", "")) == id:
			return row_v
	return {}


static func text(row: Dictionary, zh: bool) -> String:
	return str(row.get("zh" if zh else "en", ""))


static func ladder_of(row: Dictionary) -> int:
	var conditions_v: Variant = row.get("conditions", {})
	if typeof(conditions_v) != TYPE_DICTIONARY:
		return 0
	var n: int = _ji(conditions_v.get("shards_gte", 0))
	if n >= L3_SHARDS:
		return 3
	if n >= L2_SHARDS:
		return 2
	if n >= L1_SHARDS:
		return 1
	return 0


## `memory` is `{recent: Array, once: Array, last_id: String}`. `recent` is
## oldest-first runs of drawn ids. Empty dict = no line this slot this context.
static func select(
		rows: Array, slot: String, ctx: Dictionary, rng: Rng, memory: Dictionary
) -> Dictionary:
	var pool: Array[Dictionary] = _slot_rows(rows, slot)
	if pool.is_empty():
		return {}
	var once: Dictionary = _id_set(memory.get("once", []))
	var last_id: String = str(memory.get("last_id", ""))
	var recent_v: Variant = memory.get("recent", [])
	var recent: Array = recent_v if typeof(recent_v) == TYPE_ARRAY else []
	var matching: Array[Dictionary] = []
	for row: Dictionary in pool:
		if conditions_match(row.get("conditions", {}), ctx) \
				and not once.has(str(row.get("id", ""))):
			matching.append(row)
	var picked: Dictionary = _pick(matching, rng, recent, last_id, false)
	if not picked.is_empty():
		return picked
	picked = _pick(matching, rng, recent, last_id, true)
	if not picked.is_empty():
		return picked
	return _pick(matching, rng, [], "", true)


static func _slot_rows(rows: Array, slot: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row_v: Variant in rows:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		if str(row.get("slot", "")) == slot and not str(row.get("id", "")).is_empty():
			out.append(row)
	return out


static func _id_set(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(value) != TYPE_ARRAY:
		return out
	for id_v: Variant in value:
		var id: String = str(id_v)
		if not id.is_empty():
			out[id] = true
	return out


static func _used_in(recent: Array, id: String, cooldown_runs: int) -> bool:
	if cooldown_runs <= 0 or id.is_empty():
		return false
	var from: int = maxi(0, recent.size() - cooldown_runs)
	for i: int in range(from, recent.size()):
		var run_v: Variant = recent[i]
		if typeof(run_v) != TYPE_ARRAY:
			continue
		for drawn_v: Variant in run_v:
			if str(drawn_v) == id:
				return true
	return false


static func _pick(
		matching: Array[Dictionary], rng: Rng, recent: Array, last_id: String,
		recycle: bool
) -> Dictionary:
	var eligible: Array[Dictionary] = []
	var best_spec: int = -1
	var best_pri: int = -2147483648
	for row: Dictionary in matching:
		var id: String = str(row.get("id", ""))
		if not recycle and _used_in(recent, id, _ji(row.get("cooldown_runs", DEFAULT_COOLDOWN_RUNS))):
			continue
		if recycle and id == last_id and matching.size() > 1:
			continue
		var spec: int = specificity(row.get("conditions", {}))
		var pri: int = _ji(row.get("priority", 0))
		if spec > best_spec or (spec == best_spec and pri > best_pri):
			best_spec = spec
			best_pri = pri
			eligible = [row]
		elif spec == best_spec and pri == best_pri:
			eligible.append(row)
	if eligible.is_empty():
		return {}
	if eligible.size() == 1 or rng == null:
		return eligible[0]
	var total: int = 0
	for row: Dictionary in eligible:
		total += maxi(1, _ji(row.get("weight", 1)))
	var ticket: int = rng.pick_index(total)
	var cursor: int = 0
	for row: Dictionary in eligible:
		cursor += maxi(1, _ji(row.get("weight", 1)))
		if ticket < cursor:
			return row
	return eligible[0]


static func remember(recent: Array, ids: Array) -> Array:
	var bucket: Array = []
	for id_v: Variant in ids:
		var id: String = str(id_v)
		if not id.is_empty():
			bucket.append(id)
	if bucket.is_empty():
		return recent
	var next: Array = recent.duplicate()
	next.append(bucket)
	while next.size() > RECENT_CAP:
		next.pop_front()
	return next
