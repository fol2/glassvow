class_name ScenarioKernel
extends RefCounted
## Development-only Scenario kernel. Builds a checkpoint from a clean RunState
## through GlassvowGame, RewardRules and WorldMap, then validates it on the
## real save encode/decode path. Lives above domain/. No presentation UI.

const RUN_PATH: String = "user://glassvow_dev_run_v2.json"
const VIGIL_PATH: String = "user://glassvow_dev_vigil_v2.json"
const REF_PATH: String = "user://glassvow_dev_scenario.json"
const COMBAT_KINDS: PackedStringArray = ["monster", "elite", "boss"]

var last_error: String = ""
var content: ContentDB
var run_path: String
var vigil_path: String
var ref_path: String


func _init(
	content_db: ContentDB,
	run: String = RUN_PATH,
	vigil: String = VIGIL_PATH,
	reference: String = REF_PATH
) -> void:
	content = content_db
	run_path = run
	vigil_path = vigil
	ref_path = reference


static func fingerprint(run: RunState) -> String:
	return JSON.stringify(run.to_save_dict()).sha256_text()


func construct(ref: ScenarioReference) -> RunState:
	last_error = ""
	if not ref.error.is_empty():
		return _fail(ref.error)
	var aspect: int = _ji(ref.overrides.get("aspect", 0))
	var vow: int = _ji(ref.overrides.get("vow", 0))
	if aspect < 0 or aspect >= content.aspects.size():
		return _fail("unknown aspect %d" % aspect)
	if vow < 0 or vow > content.vows.size():
		return _fail("unknown vow %d" % vow)
	var act: int = _ji(ref.overrides.get("act", 0))
	if act < 0 or act > 3:
		return _fail("act %d is out of range" % act)
	var ov: Dictionary = ref.overrides
	var shard_ids: Array = []
	if ov.has("shards"):
		shard_ids = _shard_ids(ov["shards"])
		if not last_error.is_empty():
			return null
	# Act 3 exists only past the sixth Shard (#218): with fewer, final_act()
	# stays 2 and the checkpoint could never finish a run (PR #246 note).
	if act == 3 and shard_ids.size() < VigilState.QUEST_IDS.size():
		return _fail("act 3 requires six shards")
	var run_id: String = "scn-%s-%d" % [ref.identity().replace("@", "-"), ref.seed]
	var profile: Dictionary = {"aspect": aspect, "vow": vow}
	if ov.has("shards"):
		profile["shards"] = shard_ids.duplicate()
		profile["quests"] = _quest_profile(shard_ids)
	var run: RunState = RunState.new_run(content, ref.seed, run_id, profile)
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.quests.prepare_run(run)
	if not _synthesise(game, act, ov.get("node")):
		return null
	if not _apply_custom(game, ov):
		return null
	var checked: RunState = _validate_checkpoint(run)
	if checked == null:
		return null
	if not _store_ref(ref) or not _persist_vigil(run, ov.has("shards"), ov.get("scenes_seen", [])):
		return _fail("Development profile could not persist")
	return checked


func load_scenario(ref: ScenarioReference) -> RunState:
	return construct(ref)


func reset() -> RunState:
	var ref: ScenarioReference = load_reference()
	if ref == null:
		return _fail("no Scenario to reset")
	return construct(ref)


func reset_scenario() -> RunState:
	return reset()


func switch_to(ref: ScenarioReference) -> RunState:
	clear_profile()
	return construct(ref)


func switch_scenario(ref: ScenarioReference) -> RunState:
	return switch_to(ref)


func load_checkpoint() -> RunState:
	return SaveService.load_run(content, run_path)


func load_reference() -> ScenarioReference:
	if not FileAccess.file_exists(ref_path):
		last_error = "no stored Scenario reference"
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ref_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = "stored Scenario reference is unreadable"
		return null
	var raw: Dictionary = parsed
	var ref: ScenarioReference = ScenarioReference.new()
	if not ref.load_from(raw):
		last_error = ref.error
		return null
	return ref


func clear_profile() -> void:
	SaveService.clear(run_path)
	SaveService.clear_vigil(vigil_path)
	if FileAccess.file_exists(ref_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ref_path))


func clear_dev_profile() -> void:
	clear_profile()


func _synthesise(game: GlassvowGame, target_act: int, node_v: Variant) -> bool:
	var run: RunState = game.run
	while run.act < target_act:
		var prior: WorldMap = _new_map(game)
		var boss_i: int = _boss_index(prior)
		if boss_i < 0 or not _walk(run, prior, _path_to(prior, boss_i), true):
			return _bad("Synthesised history could not leave act %d" % run.act)
		run.map = prior.to_dict()
		run.start_next_act(content)
	var map: WorldMap = _new_map(game)
	if node_v == null:
		run.node_id = null
		run.map = map.to_dict()
		return true
	var idx: int = _resolve_node(map, node_v)
	if idx < 0:
		return _bad("unknown map node %s" % node_v)
	if not _walk(run, map, _path_to(map, idx), false):
		return false
	run.map = map.to_dict()
	return true


func _new_map(game: GlassvowGame) -> WorldMap:
	var map: WorldMap = WorldMap.for_run(game.run, content)
	game.quests.decorate_map(game.run, map)
	return map


func _walk(run: RunState, map: WorldMap, path: Array[int], clear_last: bool) -> bool:
	if path.is_empty():
		return _bad("Synthesised history has no route to the requested node")
	for step: int in range(path.size()):
		var i: int = path[step]
		if not map.enter(i):
			return _bad("Synthesised history could not enter node %d" % i)
		var n: MapNode = map.current()
		run.node_id = n.id
		run.waystones_lit = n.row + 1
		if n.unlit:
			var bounty: int = n.bounty * (2 if run.has_relic("thiefOfWicks") else 1)
			run.player.gold += bounty
			run.stats["goldEarned"] = _ji(run.stats.get("goldEarned", 0)) + bounty
			run.stats["unlitVisited"] = _ji(run.stats.get("unlitVisited", 0)) + 1
			n.unlit = false
			n.bounty = 0
		if step < path.size() - 1 or clear_last:
			map.clear_current()
	return true


func _apply_custom(game: GlassvowGame, ov: Dictionary) -> bool:
	var run: RunState = game.run
	for id_v: Variant in ov.get("add_relics", []):
		if not game.rewards.gain_relic(run, str(id_v)):
			return _bad("cannot add relic %s" % id_v)
	for id_v: Variant in ov.get("remove_relics", []):
		var rid: String = str(id_v)
		if not run.player.relics.has(rid):
			return _bad("cannot remove relic %s" % rid)
		run.player.relics.erase(rid)
	for id_v: Variant in ov.get("add_cards", []):
		var cid: String = str(id_v)
		if not content.cards.has(cid):
			return _bad("unknown card %s" % cid)
		game.apply({"t": "addCardToDeck", "cardId": cid})
	for id_v: Variant in ov.get("remove_cards", []):
		if not _edit_card(run, str(id_v), false):
			return _bad("cannot remove card %s" % id_v)
	for id_v: Variant in ov.get("upgrade_cards", []):
		if not _edit_card(run, str(id_v), true):
			return _bad("cannot upgrade card %s" % id_v)
	if ov.has("max_hp"):
		var max_hp: int = _ji(ov["max_hp"])
		if max_hp < 1:
			return _bad("max HP must be at least 1")
		run.player.max_hp = max_hp
		run.player.hp = mini(run.player.hp, max_hp)
	if ov.has("hp"):
		var hp: int = _ji(ov["hp"])
		if hp < 0 or hp > run.player.max_hp:
			return _bad("HP %d is incoherent against max %d" % [hp, run.player.max_hp])
		run.player.hp = hp
	if ov.has("gold"):
		var gold: int = _ji(ov["gold"])
		if gold < 0:
			return _bad("gold cannot be negative")
		run.player.gold = gold
	if ov.has("potions") and not _apply_potions(run, ov["potions"]):
		return false
	return _apply_encounter(game, ov)


func _apply_encounter(game: GlassvowGame, ov: Dictionary) -> bool:
	var map: WorldMap = WorldMap.from_dict(game.run.map)
	var n: MapNode = map.current() if map != null else null
	if not ov.has("kind") and not ov.has("enemies"):
		if n != null and n.is_combat():
			return _freeze_encounter(game, n, n.type, [])
		return true
	if n == null or not n.is_combat():
		return _bad("encounter overrides require a combat node")
	var kind: String = str(ov.get("kind", n.type))
	if kind == "normal":
		kind = "monster"
	if not COMBAT_KINDS.has(kind):
		return _bad("unknown encounter kind %s" % kind)
	var enemies_v: Variant = ov.get("enemies", [])
	if typeof(enemies_v) != TYPE_ARRAY:
		return _bad("enemies must be an array")
	var enemies: Array = enemies_v
	return _freeze_encounter(game, n, kind, enemies)


func _freeze_encounter(
	game: GlassvowGame, n: MapNode, kind: String, forced: Array
) -> bool:
	var enemies: Array = []
	if not forced.is_empty():
		for id_v: Variant in forced:
			var id: String = str(id_v)
			if not content.enemies.has(id):
				return _bad("unknown enemy %s" % id)
			enemies.append(id)
	else:
		for id: String in n.enemies:
			enemies.append(id)
		if enemies.is_empty():
			for id: String in game.quests.encounter_override(game.run, kind, n):
				enemies.append(id)
		if enemies.is_empty():
			for id: String in game.rewards.roll_encounter(game.run, kind, n.row, n):
				enemies.append(id)
	if enemies.is_empty():
		return _bad("encounter has no enemies")
	game.run.pending_combat = kind
	game.run.pending_enemy_ids = enemies
	return true


func _apply_potions(run: RunState, value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return _bad("potions must be an array")
	var pots: Array = value
	if pots.size() != run.player.potions.size():
		return _bad("potion count must match the run's slots")
	for i: int in range(pots.size()):
		var id: String = "" if pots[i] == null else str(pots[i])
		if not id.is_empty() and not content.potions.has(id):
			return _bad("unknown potion %s" % id)
		run.player.potions[i] = id
	return true


func _edit_card(run: RunState, id: String, upgrade: bool) -> bool:
	for card: CardInst in run.player.deck:
		if String(card.id) != id:
			continue
		if upgrade:
			var def_v: Variant = content.cards.get(id, {})
			if card.up or typeof(def_v) != TYPE_DICTIONARY:
				return false
			var def: Dictionary = def_v
			if not def.has("up"):
				return false
			card.up = true
		else:
			run.player.deck.erase(card)
		return true
	return false


func _validate_checkpoint(run: RunState) -> RunState:
	var parsed: Variant = JSON.parse_string(JSON.stringify(run.to_save_dict()))
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail("checkpoint did not encode")
	var encoded: Dictionary = parsed
	if RunState.from_save_dict(encoded, content) == null:
		return _fail("checkpoint rejected by save decoder")
	if not SaveService.store(run, run_path):
		return _fail("Development profile run store failed")
	var loaded: RunState = SaveService.load_run(content, run_path)
	if loaded == null:
		return _fail("Development profile rejected its own checkpoint")
	return loaded


func _persist_vigil(run: RunState, apply_shards: bool, scenes: Variant = []) -> bool:
	var vigil: VigilState = VigilState.blank()
	if apply_shards and not run.shards.is_empty():
		if not vigil.commit_run(run, "win", content):
			last_error = "Vigil could not record the Scenario"
			return false
	if typeof(scenes) == TYPE_ARRAY:
		for id_v: Variant in scenes:
			var seen: String = str(id_v)
			if not seen.is_empty() and not vigil.scenes_seen.has(seen):
				vigil.scenes_seen.append(seen)
	return SaveService.store_vigil(vigil, vigil_path)


func _shard_ids(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) == TYPE_ARRAY:
		var seen: Dictionary = {}
		var wanted: Dictionary = {}
		var rows: Array = value
		for id_v: Variant in rows:
			var id: String = str(id_v)
			if not VigilState.QUEST_IDS.has(id):
				last_error = "unknown shard %s" % id
				return out
			if seen.has(id):
				last_error = "duplicate shard %s" % id
				return out
			seen[id] = true
			wanted[id] = true
		for id: String in VigilState.QUEST_IDS:
			if wanted.has(id):
				out.append(id)
		return out
	var raw: String = str(value).strip_edges()
	if not raw.is_valid_int():
		last_error = "shards must be 0..%d or quest ids" % VigilState.QUEST_IDS.size()
		return out
	var n: int = int(raw)
	if n < 0 or n > VigilState.QUEST_IDS.size():
		last_error = "shards %d is out of range" % n
		return out
	for i: int in range(n):
		out.append(VigilState.QUEST_IDS[i])
	return out


func _quest_profile(shard_ids: Array) -> Dictionary:
	var lit: Dictionary = {}
	for id_v: Variant in shard_ids:
		lit[str(id_v)] = true
	var quests: Dictionary = {}
	for id: String in VigilState.QUEST_IDS:
		var def_v: Variant = content.quests.get(id, {})
		var target: int = 0
		if typeof(def_v) == TYPE_DICTIONARY:
			var def: Dictionary = def_v
			target = _ji(def.get("target", 0))
		var done: bool = lit.has(id)
		quests[id] = {
			"state": "complete" if done else "dormant",
			"progress": target if done else 0,
			"memory": {},
		}
	return quests


func _store_ref(ref: ScenarioReference) -> bool:
	var tmp: String = ref_path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(ref.encode()))
	f.flush()
	f.close()
	if DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp),
		ProjectSettings.globalize_path(ref_path)
	) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return false
	return true


func _resolve_node(map: WorldMap, node_v: Variant) -> int:
	if typeof(node_v) == TYPE_STRING:
		var token: String = str(node_v)
		if token.find(",") < 0 and token.is_valid_int():
			return _resolve_node(map, int(token))
		for i: int in range(map.nodes.size()):
			if map.nodes[i].id == token:
				return i
		return -1
	var idx: int = _ji(node_v)
	return idx if idx >= 0 and idx < map.nodes.size() else -1


func _boss_index(map: WorldMap) -> int:
	for i: int in range(map.nodes.size()):
		if map.nodes[i].type == "boss":
			return i
	return -1


func _path_to(map: WorldMap, target: int) -> Array[int]:
	var parent: Dictionary = {}
	var q: Array[int] = []
	for i: int in range(map.nodes.size()):
		if map.nodes[i].row == 0:
			parent[i] = -1
			q.append(i)
	var head: int = 0
	while head < q.size():
		var i: int = q[head]
		head += 1
		if i == target:
			break
		var outs: Array = map.edges.get(i, [])
		for v: Variant in outs:
			var n: int = _ji(v)
			if not parent.has(n):
				parent[n] = i
				q.append(n)
	if not parent.has(target):
		return []
	var path: Array[int] = []
	var cur: int = target
	while cur >= 0:
		path.insert(0, cur)
		cur = _ji(parent.get(cur, -1))
	return path


func _fail(message: String) -> RunState:
	last_error = message
	return null


func _bad(message: String) -> bool:
	last_error = message
	return false


static func _ji(v: Variant) -> int:
	return int(float(str(v)))
