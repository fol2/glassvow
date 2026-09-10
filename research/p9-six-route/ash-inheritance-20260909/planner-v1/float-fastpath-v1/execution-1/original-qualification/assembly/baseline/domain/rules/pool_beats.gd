class_name PoolBeats
extends RefCounted
## Run-scoped LineTable staging. Select once per beat key; presentation only
## resolves the stored id. Replay of the same key must not roll again.

const SLOT_WAYSTONE: String = "waystone"
const SLOT_HEARTH: String = "hearth"
const KEY_START: String = "hearth:start"
const KEY_USURPER: String = "hearth:usurper"
const RESUME_MAP: String = "map"
const RESUME_NODE: String = "node"
const RESUME_LEAVE: String = "leave"
const RESUMES: Array[String] = [RESUME_MAP, RESUME_NODE, RESUME_LEAVE]


static func waystone_key(node_id: Variant) -> String:
	return "waystone:%s" % str(node_id)


static func pending_of(run: RunState) -> Dictionary:
	if typeof(run.pending_pool) != TYPE_DICTIONARY:
		return {}
	return run.pending_pool


static func row_of(rows: Array, run: RunState) -> Dictionary:
	var pending: Dictionary = pending_of(run)
	if pending.is_empty():
		return {}
	return LineTable.row_by_id(rows, str(pending.get("id", "")))


static func context_of(run: RunState) -> Dictionary:
	return LineTable.context(run, LineTable.projected_shard_count(run))


static func memory(vigil: VigilState, run: RunState) -> Dictionary:
	var once: Array = vigil.line_once.duplicate()
	for id: String in run.pool_draws:
		if not once.has(id):
			once.append(id)
	var last_id: String = ""
	if not run.pool_draws.is_empty():
		last_id = run.pool_draws[run.pool_draws.size() - 1]
	return {
		"recent": vigil.line_recent,
		"once": once,
		"last_id": last_id,
	}


## Empty dict = no matching row. A prior draw for `key` is replayed without
## consuming RNG.
static func stage(
		run: RunState, vigil: VigilState, content: ContentDB,
		slot: String, key: String, resume: String
) -> Dictionary:
	if key.is_empty() or slot.is_empty() or resume not in RESUMES:
		return {}
	if run.pool_beats.has(key):
		var replay_id: String = str(run.pool_beats[key])
		var replay: Dictionary = LineTable.row_by_id(content.line_table, replay_id)
		if replay.is_empty():
			return {}
		run.pending_pool = _pending(slot, replay_id, key, resume)
		return replay
	var row: Dictionary = LineTable.select(
		content.line_table, slot, context_of(run), run.rng, memory(vigil, run))
	var id: String = str(row.get("id", ""))
	if id.is_empty():
		return {}
	run.pool_beats[key] = id
	run.pool_draws.append(id)
	run.pending_pool = _pending(slot, id, key, resume)
	return row


static func clear_pending(run: RunState) -> void:
	run.pending_pool = null


static func _pending(slot: String, id: String, key: String, resume: String) -> Dictionary:
	return {"slot": slot, "id": id, "key": key, "resume": resume}
