extends SceneTree
## Production-runtime black-box channel for #421 V5 Gate O.
##
## This script lives outside the product worktree. It loads the exact project,
## injects one deterministic conformance-only card definition into an in-memory
## ContentDB, constructs state from the frozen DTO, and invokes only
## GlassvowGame.apply. It does not know the synthesis projection or expected
## observations.

const SCHEMA: String = "glassvow.p9-independent-source-oracle-v5.runtime-black-box.v1"
const SOURCE_SHA: String = "c7b4c8280e95cb8b925477b82450dd8b927a64f5"

const OBSERVATION_CLOSURE: Dictionary = {
	"apply": ["returned_events", "last_ret", "queue_before", "queue_after", "command"],
	"run": [
		"seed", "run_id", "rng_state", "act", "node_id", "waystones_lit", "aspect", "vow",
		"art", "uid", "reveals_all", "reveals", "player", "unlocks", "omens", "boon",
		"boon_receipt", "boss_relic_act", "shards", "monument", "quests", "quest_scratch",
		"quest_completions", "stats", "map", "pending_combat", "pending_enemy_ids",
		"pending_quest_id", "pending_reward", "pending_run_end", "pending_dawn",
		"pending_scene", "pending_hollow", "pending_hollow_route", "pending_lamplighter",
		"pending_pool", "pool_beats", "pool_draws",
	],
	"run_player": ["hp", "max_hp", "gold", "energy_max", "relics", "potions", "deck"],
	"combat": [
		"kind", "affix", "turn", "over", "result", "queue", "player", "enemies", "draw",
		"hand", "discard", "exhaust", "embers", "ember_cap", "art_used_turn", "kindled_turn",
		"kindles_this_turn", "pending_chips_active", "pending_chips", "counters_played",
		"counters_attacks", "first_card_played", "hp_lost", "prism_procd", "finale_handoff",
	],
	"combat_player": ["hp", "max_hp", "block", "energy", "energy_max", "statuses"],
	"enemy": [
		"key", "variant_id", "def", "idx", "name", "hp", "max_hp", "block", "statuses",
		"staggered", "last_moves", "move_key", "elite", "boss", "facet_max", "chips", "flags",
	],
	"card": ["uid", "id", "up", "bonus"],
	"dictionary_encoding": "ordered list of typed key/value records; integer and string keys remain distinct",
}


func _initialize() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var output_path: String = str(args.get("output", ""))
	if output_path.is_empty():
		_finish(3, "missing --output")
		return
	if args.get("schema-only", false):
		var written: bool = _write_json(output_path, {
			"schema": "%s.observation-closure" % SCHEMA,
			"sourceSha": SOURCE_SHA,
			"observationClosure": OBSERVATION_CLOSURE,
			"construction": "explicit complete script-variable snapshot; typed dictionary encoding",
		})
		quit(0 if written else 3)
		return
	if args.get("self-test", false):
		var smoke: Dictionary = _smoke_corpus()
		var result: Dictionary = _execute_index(smoke, 0)
		var written: bool = _write_json(output_path, result)
		quit(0 if written and result.get("status") == "COMPLETE" else 3)
		return
	var input_path: String = str(args.get("input", ""))
	if input_path.is_empty():
		_finish(3, "missing --input")
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(input_path))
	if typeof(raw) != TYPE_DICTIONARY:
		_finish(3, "input corpus is not a JSON object")
		return
	if not args.has("index"):
		_finish(3, "missing --index")
		return
	var index: int = str(args.get("index", -1)).to_int()
	var corpus: Dictionary = raw
	var result: Dictionary = _execute_index(corpus, index)
	var written: bool = _write_json(output_path, result)
	quit(0 if written and result.get("status") == "COMPLETE" else 3)


func _parse_args(values: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	var index: int = 0
	while index < values.size():
		var token: String = values[index]
		if token.begins_with("--"):
			var key: String = token.substr(2)
			if index + 1 < values.size() and not values[index + 1].begins_with("--"):
				out[key] = values[index + 1]
				index += 2
				continue
			out[key] = true
		index += 1
	return out


func _finish(code: int, reason: String) -> void:
	printerr("V5_RUNTIME_INCONCLUSIVE: %s" % reason)
	quit(code)


func _write_json(path: String, value: Variant) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("V5_RUNTIME_INCONCLUSIVE: cannot open output %s" % path)
		return false
	file.store_string(JSON.stringify(value, "  ", true, true) + "\n")
	return true


func _smoke_corpus() -> Dictionary:
	var shell: Dictionary = {
		"base": {"type": "skill", "target": "self", "cost": 1, "exhaust": false, "chip": 0, "rarity": "common", "unplayable": false},
		"upgrade": {"type": "skill", "target": "self", "cost": 1, "exhaust": false, "chip": 0, "rarity": "common", "unplayable": false},
	}
	var atom: Dictionary = {
		"base": {"kind": "block", "n": 5},
		"upgrade": {"kind": "block", "n": 8},
	}
	return {
		"schema": "smoke",
		"sourceSha": SOURCE_SHA,
		"inventory": {"shells": [shell], "effectAtoms": [atom]},
		"profiles": [{
			"id": "smoke",
			"profile": {"invalid": false},
			"representative": {"shellIndex": 0, "effectAtomIndices": [0]},
			"contexts": ["plain_valid"],
			"versions": ["base", "upgrade"],
		}],
		"branchCases": [],
	}


func _execute_index(corpus: Dictionary, requested_index: int) -> Dictionary:
	if str(corpus.get("sourceSha", "")) != SOURCE_SHA:
		return {"schema": SCHEMA, "status": "INCONCLUSIVE", "reason": "source SHA mismatch"}
	var inventory_v: Variant = corpus.get("inventory")
	if typeof(inventory_v) != TYPE_DICTIONARY:
		return {"schema": SCHEMA, "status": "INCONCLUSIVE", "reason": "missing inventory"}
	var inventory: Dictionary = inventory_v
	if not _valid_inventory(inventory):
		return {"schema": SCHEMA, "status": "INCONCLUSIVE", "reason": "invalid inventory"}
	var expected_count: int = str(corpus.get("counts", {}).get("runtimeExecutions", -1)).to_int()
	if expected_count <= 0 or requested_index < 0 or requested_index >= expected_count:
		return {"schema": SCHEMA, "status": "INCONCLUSIVE", "reason": "execution index outside frozen corpus"}
	var selected: Dictionary = _case_at(corpus, requested_index)
	if selected.is_empty():
		return {"schema": SCHEMA, "status": "INCONCLUSIVE", "reason": "corpus count/index mismatch"}
	var content: ContentDB = ContentDB.load_full(true)
	if content == null:
		return {"schema": SCHEMA, "status": "INCONCLUSIVE", "reason": "ContentDB.load_full failed"}
	var profile: Dictionary = selected["profile"]
	var row: Dictionary = _execute_one(
		content, inventory, profile, str(selected["version"]), str(selected["context"]), requested_index
	)
	if selected.has("branchCaseId"):
		row["branchCaseId"] = selected["branchCaseId"]
	return {
		"schema": SCHEMA,
		"status": "COMPLETE",
		"sourceSha": SOURCE_SHA,
		"engineVersion": Engine.get_version_info(),
		"contentSha256": FileAccess.get_sha256("res://content/full-content.json"),
		"mobOverridesSha256": FileAccess.get_sha256("res://content/mob-overrides.json"),
		"lineTableSha256": FileAccess.get_sha256("res://content/line-table.json"),
		"observationClosure": OBSERVATION_CLOSURE,
		"executionIndex": requested_index,
		"expectedExecutionCount": expected_count,
		"freshProcessRequiredByParent": true,
		"syntheticConformanceDefinitionOnly": true,
		"observation": row,
	}


func _valid_inventory(inventory: Dictionary) -> bool:
	return typeof(inventory.get("shells")) == TYPE_ARRAY \
		and typeof(inventory.get("effectAtoms")) == TYPE_ARRAY \
		and str(inventory.get("shellCount", -1)).to_int() == inventory["shells"].size() \
		and str(inventory.get("effectAtomCount", -1)).to_int() == inventory["effectAtoms"].size()


func _case_at(corpus: Dictionary, requested_index: int) -> Dictionary:
	var profiles_v: Variant = corpus.get("profiles")
	var branches_v: Variant = corpus.get("branchCases")
	if typeof(profiles_v) != TYPE_ARRAY or typeof(branches_v) != TYPE_ARRAY:
		return {}
	var profiles: Array = profiles_v
	var branches: Array = branches_v
	var profile_by_id: Dictionary = {}
	var cursor: int = 0
	for profile_v: Variant in profiles:
		if typeof(profile_v) != TYPE_DICTIONARY:
			return {}
		var profile: Dictionary = profile_v
		var profile_id: String = str(profile.get("id", ""))
		if profile_id.is_empty() or profile_by_id.has(profile_id):
			return {}
		profile_by_id[profile_id] = profile
		var contexts_v: Variant = profile.get("contexts")
		var versions_v: Variant = profile.get("versions")
		if typeof(contexts_v) != TYPE_ARRAY or typeof(versions_v) != TYPE_ARRAY:
			return {}
		var contexts: Array = contexts_v
		var versions: Array = versions_v
		for context_v: Variant in contexts:
			for version_v: Variant in versions:
				if cursor == requested_index:
					return {"profile": profile, "context": str(context_v), "version": str(version_v)}
				cursor += 1
	for branch_v: Variant in branches:
		if typeof(branch_v) != TYPE_DICTIONARY:
			return {}
		var branch: Dictionary = branch_v
		var profile_id: String = str(branch.get("profileId", ""))
		if not profile_by_id.has(profile_id):
			return {}
		if cursor == requested_index:
			var branch_profile: Dictionary = profile_by_id[profile_id]
			return {
				"profile": branch_profile,
				"context": str(branch.get("context", "")),
				"version": str(branch.get("version", "")),
				"branchCaseId": str(branch.get("id", "")),
			}
		cursor += 1
	return {}


func _execute_one(
	content: ContentDB, inventory: Dictionary, profile: Dictionary,
	version: String, context_id: String, ordinal: int
) -> Dictionary:
	var representative: Dictionary = profile["representative"]
	var shell_index: int = str(representative["shellIndex"]).to_int()
	var atom_indices: Array = representative["effectAtomIndices"]
	var shell_pair: Dictionary = inventory["shells"][shell_index]
	var atoms: Array = inventory["effectAtoms"]
	var card_def: Dictionary = _card_definition(shell_pair, atom_indices, atoms)
	var safe_profile_id: String = str(profile["id"]).replace("-", "_")
	var card_id: String = "__p9_v5_%s_%s_%d" % [safe_profile_id, version, ordinal]
	content.cards[card_id] = card_def
	var run: RunState = _run_state()
	var cb: CombatState = _combat_state(content, card_id, version == "upgrade")
	var target: Variant = _target_for(card_def, version)
	_apply_context(content, run, cb, context_id, card_def, version)
	if context_id == "missing_target":
		target = null
	elif context_id == "dead_target":
		cb.enemies[0].hp = 0
		target = 0
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.cb = cb
	var command: Dictionary = {"t": "playCard", "uid": 700000, "target": target}
	var before: Dictionary = _snapshot(run, cb)
	var queue_before: Variant = _encode(cb.queue)
	var returned_events: Array[Dictionary] = game.apply(command)
	var after: Dictionary = _snapshot(run, cb)
	var row: Dictionary = {
		"executionId": "%s:%s:%s" % [profile["id"], version, context_id],
		"profileId": profile["id"],
		"version": version,
		"context": context_id,
		"conformanceIdentity": card_id,
		"command": _encode(command),
		"before": before,
		"after": after,
		"queueBefore": queue_before,
		"queueAfter": _encode(cb.queue),
		"returnedEvents": _encode(returned_events),
		"lastRet": _encode(game.last_ret),
		"rngBefore": before["run"]["rng_state"],
		"rngAfter": after["run"]["rng_state"],
	}
	content.cards.erase(card_id)
	return row


func _card_definition(shell_pair: Dictionary, atom_indices: Array, atoms: Array) -> Dictionary:
	var base: Dictionary = shell_pair["base"].duplicate(true)
	var upgrade: Dictionary = shell_pair["upgrade"].duplicate(true)
	var base_effects: Array = []
	var upgrade_effects: Array = []
	for index_v: Variant in atom_indices:
		var atom: Dictionary = atoms[str(index_v).to_int()]
		base_effects.append(atom["base"].duplicate(true))
		upgrade_effects.append(atom["upgrade"].duplicate(true))
	base["effects"] = base_effects
	base["name"] = "V5 conformance"
	base["text"] = "V5 conformance"
	upgrade["effects"] = upgrade_effects
	upgrade["text"] = "V5 conformance"
	base["up"] = upgrade
	return base


func _run_state() -> RunState:
	var run: RunState = RunState.new()
	run.seed = 920421
	run.run_id = "p9-v5-source-conformance"
	run.rng = Rng.new(920421)
	run.act = 0
	run.aspect = 0
	run.vow = 0
	run.art = &"flare"
	run.uid = 900000
	run.omens = [null]
	run.player.hp = 100
	run.player.max_hp = 100
	run.player.gold = 0
	run.player.energy_max = 10
	run.player.potions = ["", "", ""]
	return run


func _enemy(content: ContentDB, index: int) -> EnemyCombatant:
	var enemy: EnemyCombatant = EnemyCombatant.new()
	enemy.key = &"duskfang"
	enemy.def = content.enemy(&"duskfang").duplicate(true)
	enemy.idx = index
	enemy.name = str(enemy.def.get("name", "Duskfang"))
	enemy.hp = 500
	enemy.max_hp = 500
	enemy.block = 0
	enemy.facet_max = 4
	enemy.chips = 0
	enemy.move_key = &""
	return enemy


func _combat_state(content: ContentDB, card_id: String, upgraded: bool) -> CombatState:
	var cb: CombatState = CombatState.new()
	cb.kind = &"normal"
	cb.turn = 1
	cb.player.hp = 100
	cb.player.max_hp = 100
	cb.player.energy = 10
	cb.player.energy_max = 10
	cb.enemies = [_enemy(content, 0), _enemy(content, 1)]
	cb.hand = [CardInst.new(700000, StringName(card_id), upgraded)]
	cb.draw = [CardInst.new(700001, &"strike"), CardInst.new(700002, &"defend")]
	cb.discard = [CardInst.new(700003, &"chisel")]
	return cb


func _target_for(card_def: Dictionary, version: String) -> Variant:
	var definition: Dictionary = card_def
	if version == "upgrade":
		definition = card_def.duplicate(true)
		var upgrade: Dictionary = card_def.get("up", {})
		definition.merge(upgrade, true)
	return 0 if str(definition.get("target", "")) == "enemy" else null


func _apply_context(
	content: ContentDB, run: RunState, cb: CombatState, context_id: String,
	card_def: Dictionary, version: String
) -> void:
	match context_id:
		"plain_valid", "valid_target", "all_enemies_two_live":
			pass
		"invalid_composition":
			cb.over = true
		"insufficient_energy":
			cb.player.energy = 0
		"duskmirror_first":
			run.player.relics.append("duskmirror")
		"omen_discount_first":
			run.omens = ["waningMoon"]
		"not_first_card":
			cb.first_card_played = true
		"iron_talisman_threshold":
			run.player.relics.append("ironTalisman")
			cb.counters_attacks = 2
		"executioners_seal_threshold":
			run.player.relics.append("executionersSeal")
			cb.counters_attacks = 9
		"facet_below_threshold":
			cb.enemies[0].chips = maxi(0, cb.enemies[0].facet_max - 2)
		"ash_venomous":
			run.aspect = 1
			cb.player.statuses["venomous"] = 2
		"dusk_venomous_null":
			run.aspect = 0
			cb.player.statuses["venomous"] = 2
		"silk_fan_threshold":
			run.player.relics.append("silkFan")
			cb.counters_played = 2
		"exhaust_ember_room":
			cb.embers = 0
		"exhaust_ember_cap":
			cb.embers = cb.ember_cap
		"hollow_lamplighter_debt":
			run.quests["hollowLamplighter"] = {"state": "armed", "progress": 0, "memory": {"emberDebt": 3}}
			run.quest_scratch["hollowLamplighter"] = {"emberDebt": 3, "debtActive": true}
		"verdant_draw":
			run.player.relics.append("verdantBranch")
			cb.draw = [CardInst.new(700010, &"strike")]
			cb.discard = []
		"verdant_reshuffle", "rng_reshuffle":
			run.player.relics.append("verdantBranch")
			cb.draw = []
			cb.discard = [CardInst.new(700010, &"strike"), CardInst.new(700011, &"defend"), CardInst.new(700012, &"chisel")]
		"rng_no_reshuffle":
			cb.draw = [CardInst.new(700010, &"strike"), CardInst.new(700011, &"defend")]
		"dusk_shatter":
			run.aspect = 0
			cb.enemies[0].chips = cb.enemies[0].facet_max - 1
		"ash_chip_no_shatter":
			run.aspect = 1
			cb.enemies[0].chips = cb.enemies[0].facet_max - 1
		"special_execute_active":
			cb.enemies[0].statuses["vulnerable"] = 1
		"special_execute_inactive":
			cb.enemies[0].statuses.erase("vulnerable")
		"special_devour_active":
			cb.enemies[0].hp = 1
		"special_devour_inactive":
			cb.enemies[0].hp = 500
		"special_catalyst_active":
			cb.enemies[0].statuses["poison"] = 3
		"special_catalyst_inactive":
			cb.enemies[0].statuses.erase("poison")
		"special_shatterEcho_active":
			cb.enemies[0].staggered = true
		"special_shatterEcho_inactive":
			cb.enemies[0].staggered = false
			cb.enemies[0].statuses.erase("vulnerable")
		"special_flawless_active":
			cb.hp_lost = 0
		"special_flawless_inactive":
			cb.hp_lost = 1
		"special_emberdance_active", "special_emberNova_active":
			cb.embers = 3
		"special_emberdance_inactive":
			cb.embers = 0
		"special_momentum_active":
			cb.hand[0].bonus = 3
		"special_phantom_active":
			cb.hand.append(CardInst.new(700020, &"defend"))
		"special_pyreTithe_active":
			cb.hand.append(CardInst.new(700020, &"defend"))
			cb.hand.append(CardInst.new(700021, &"strike"))
		_:
			# Remaining active special contexts use the complete plain state;
			# their distinct handler is selected by the frozen card effect.
			pass


func _snapshot(run: RunState, cb: CombatState) -> Dictionary:
	return {"run": _snapshot_run(run), "combat": _snapshot_combat(cb)}


func _snapshot_run(run: RunState) -> Dictionary:
	return {
		"seed": run.seed,
		"run_id": run.run_id,
		"rng_state": run.rng_state(),
		"act": run.act,
		"node_id": _encode(run.node_id),
		"waystones_lit": run.waystones_lit,
		"aspect": run.aspect,
		"vow": run.vow,
		"art": String(run.art),
		"uid": run.uid,
		"reveals_all": run.reveals_all,
		"reveals": _encode(run.reveals),
		"player": {
			"hp": run.player.hp,
			"max_hp": run.player.max_hp,
			"gold": run.player.gold,
			"energy_max": run.player.energy_max,
			"relics": _encode(run.player.relics),
			"potions": _encode(run.player.potions),
			"deck": _cards(run.player.deck),
		},
		"unlocks": _encode(run.unlocks),
		"omens": _encode(run.omens),
		"boon": _encode(run.boon),
		"boon_receipt": _encode(run.boon_receipt),
		"boss_relic_act": run.boss_relic_act,
		"shards": _encode(run.shards),
		"monument": _encode(run.monument),
		"quests": _encode(run.quests),
		"quest_scratch": _encode(run.quest_scratch),
		"quest_completions": _encode(run.quest_completions),
		"stats": _encode(run.stats),
		"map": _encode(run.map),
		"pending_combat": _encode(run.pending_combat),
		"pending_enemy_ids": _encode(run.pending_enemy_ids),
		"pending_quest_id": _encode(run.pending_quest_id),
		"pending_reward": _encode(run.pending_reward),
		"pending_run_end": _encode(run.pending_run_end),
		"pending_dawn": _encode(run.pending_dawn),
		"pending_scene": _encode(run.pending_scene),
		"pending_hollow": _encode(run.pending_hollow),
		"pending_hollow_route": _encode(run.pending_hollow_route),
		"pending_lamplighter": run.pending_lamplighter,
		"pending_pool": _encode(run.pending_pool),
		"pool_beats": _encode(run.pool_beats),
		"pool_draws": _encode(run.pool_draws),
	}


func _snapshot_combat(cb: CombatState) -> Dictionary:
	var enemies: Array = []
	for enemy: EnemyCombatant in cb.enemies:
		enemies.append({
			"key": String(enemy.key), "variant_id": String(enemy.variant_id), "def": _encode(enemy.def),
			"idx": enemy.idx, "name": enemy.name, "hp": enemy.hp, "max_hp": enemy.max_hp,
			"block": enemy.block, "statuses": _encode(enemy.statuses), "staggered": enemy.staggered,
			"last_moves": _encode(enemy.last_moves), "move_key": String(enemy.move_key),
			"elite": enemy.elite, "boss": enemy.boss, "facet_max": enemy.facet_max,
			"chips": enemy.chips, "flags": _encode(enemy.flags),
		})
	return {
		"kind": String(cb.kind), "affix": String(cb.affix), "turn": cb.turn, "over": cb.over,
		"result": cb.result, "queue": _encode(cb.queue),
		"player": {
			"hp": cb.player.hp, "max_hp": cb.player.max_hp, "block": cb.player.block,
			"energy": cb.player.energy, "energy_max": cb.player.energy_max,
			"statuses": _encode(cb.player.statuses),
		},
		"enemies": enemies,
		"draw": _cards(cb.draw), "hand": _cards(cb.hand), "discard": _cards(cb.discard),
		"exhaust": _cards(cb.exhaust), "embers": cb.embers, "ember_cap": cb.ember_cap,
		"art_used_turn": cb.art_used_turn, "kindled_turn": cb.kindled_turn,
		"kindles_this_turn": cb.kindles_this_turn, "pending_chips_active": cb.pending_chips_active,
		"pending_chips": _encode(cb.pending_chips), "counters_played": cb.counters_played,
		"counters_attacks": cb.counters_attacks, "first_card_played": cb.first_card_played,
		"hp_lost": cb.hp_lost, "prism_procd": cb.prism_procd,
		"finale_handoff": cb.finale_handoff,
	}


func _cards(cards: Array) -> Array:
	var out: Array = []
	for card_v: Variant in cards:
		var card: CardInst = card_v
		out.append({"uid": card.uid, "id": String(card.id), "up": card.up, "bonus": card.bonus})
	return out


func _encode(value: Variant) -> Variant:
	var kind: int = typeof(value)
	if kind == TYPE_NIL or kind == TYPE_BOOL or kind == TYPE_INT or kind == TYPE_FLOAT or kind == TYPE_STRING:
		return value
	if kind == TYPE_STRING_NAME:
		return {"$type": "StringName", "value": str(value)}
	if kind == TYPE_ARRAY or kind == TYPE_PACKED_STRING_ARRAY or kind == TYPE_PACKED_INT32_ARRAY:
		var array: Array = []
		for item: Variant in value:
			array.append(_encode(item))
		return array
	if kind == TYPE_DICTIONARY:
		var entries: Array = []
		var dictionary: Dictionary = value
		for key: Variant in dictionary.keys():
			entries.append({"key": _encode_key(key), "value": _encode(dictionary[key])})
		return {"$dict": entries}
	return {"$type": type_string(kind), "value": str(value)}


func _encode_key(value: Variant) -> Dictionary:
	return {"type": type_string(typeof(value)), "value": str(value)}
