class_name ContentDB
extends RefCounted
## Loads either the frozen fixture slice or the complete port-owned catalogue.
## File access stays outside the pure domain.

const SLICE_PATH: String = "res://port_fixtures/content/slice-content.json"
const FULL_PATH: String = "res://content/full-content.json"
const LINE_TABLE_PATH: String = "res://content/line-table.json"
const MOB_OVERRIDES_PATH: String = "res://content/mob-overrides.json"
const CORE_MECHANICS_PATH: String = "res://port_fixtures/content/core-mechanics.json"
const ENEMY_INTENTS: Array[String] = [
	"attack", "attack_block", "attack_buff", "attack_debuff", "block", "buff", "debuff", "heal",
]

var id: String = ""
var cards: Dictionary = {}
var enemies: Dictionary = {}
var potions: Dictionary = {}
var relics: Dictionary = {}
var arts: Dictionary = {}
var affixes: Dictionary = {}
var statuses: Dictionary = {}
var events: Dictionary = {}
var omens: Dictionary = {}
var deeds: Dictionary = {}
var themes: Dictionary = {}
var quests: Dictionary = {}
var variants: Dictionary = {}
var boons: Dictionary = {}
var progression: Dictionary = {}
var shop: Dictionary = {}
var shade_kits: Dictionary = {}
var aspects: Array = []
var vows: Array = []
var quest_ids: Array[String] = []
var theme_order: Array[String] = []
var acts: Array = []
var encounters: Array = []
var card_pools: Dictionary = {}
var relic_pools: Dictionary = {}
var pool_gate_cards: Dictionary = {}
var pool_gate_relics: Dictionary = {}
var reward_gold: Array = []  # per act: {"normal": [a,b], "elite": [a,b], "boss": [a,b]}
var player: Dictionary = {}
var reveal_ids: Array[String] = []
var line_table: Array = []


static func load_slice() -> ContentDB:
	var db: ContentDB = ContentDB.new()
	db._load(SLICE_PATH)
	db._load_reveal_ids(CORE_MECHANICS_PATH)
	return db


static func load_full(with_mob_overrides: bool = true) -> ContentDB:
	var db: ContentDB = ContentDB.new()
	db._load(FULL_PATH)
	db._load_line_table()
	if with_mob_overrides:
		db._load_mob_overrides()
	return db

func _load_mob_overrides() -> void:
	var text: String = FileAccess.get_file_as_string(MOB_OVERRIDES_PATH)
	if text.is_empty():
		push_error("ContentDB: cannot read %s" % MOB_OVERRIDES_PATH)
		return
	var raw: Variant = JSON.parse_string(text)
	var faults: PackedStringArray = apply_enemy_overrides(raw)
	if not faults.is_empty():
		push_error("ContentDB: refusing %s — %s" % [MOB_OVERRIDES_PATH, faults[0]])

func apply_enemy_overrides(raw: Variant) -> PackedStringArray:
	var faults: PackedStringArray = enemy_override_faults(raw)
	if not faults.is_empty():
		return faults
	var overrides: Dictionary = raw
	for id_v: Variant in overrides:
		var id_key: String = str(id_v)
		var definition: Dictionary = overrides[id_v]
		enemies[id_key] = definition.duplicate(true)
	return faults

func enemy_override_faults(raw: Variant) -> PackedStringArray:
	var faults: PackedStringArray = []
	if typeof(raw) != TYPE_DICTIONARY:
		faults.append("mob overrides must be a dictionary")
		return faults
	var overrides: Dictionary = raw
	for id_v: Variant in overrides:
		var id_key: String = str(id_v)
		if not enemies.has(id_key):
			faults.append("unknown mob id %s" % id_key)
			continue
		faults.append_array(enemy_faults(id_key, overrides[id_v]))
	return faults


func enemy_faults(id_key: String, value: Variant) -> PackedStringArray:
	var faults: PackedStringArray = []
	if typeof(value) != TYPE_DICTIONARY:
		faults.append("%s must be a dictionary" % id_key)
		return faults
	var definition: Dictionary = value
	var baseline: Dictionary = enemies.get(id_key, {})
	if str(definition.get("name", "")) != str(baseline.get("name", "")):
		faults.append("%s.name is locale-owned and read-only" % id_key)
	var hp_v: Variant = definition.get("hp")
	if typeof(hp_v) != TYPE_ARRAY:
		faults.append("%s.hp must be [minimum, maximum]" % id_key)
	else:
		var hp: Array = hp_v
		if hp.size() != 2 or not _whole_at_least(hp[0] if hp.size() > 0 else null, 1) \
				or not _whole_at_least(hp[1] if hp.size() > 1 else null, 1):
			faults.append("%s.hp must contain two positive whole numbers" % id_key)
		elif float(str(hp[0])) > float(str(hp[1])):
			faults.append("%s.hp minimum exceeds maximum" % id_key)
	for flag: String in ["elite", "boss"]:
		if definition.has(flag) and typeof(definition[flag]) != TYPE_BOOL:
			faults.append("%s.%s must be a boolean" % [id_key, flag])
	if definition.get("elite", false) and definition.get("boss", false):
		faults.append("%s cannot be both elite and boss" % id_key)
	if definition.has("facets") and not _whole_at_least(definition["facets"], 2):
		faults.append("%s.facets must be a whole number of at least 2" % id_key)
	_validate_enemy_art(id_key, definition.get("art"), faults)
	_validate_start_status(id_key, definition.get("startStatus", {}), faults)
	_validate_enemy_moves(id_key, definition.get("moves"), baseline.get("moves", {}), faults)
	return faults


func _validate_enemy_art(id_key: String, value: Variant, faults: PackedStringArray) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		faults.append("%s.art must be a dictionary" % id_key)
		return
	var art: Dictionary = value
	var kind: String = str(art.get("kind", ""))
	var known_kind: bool = kind == "humanoid"
	for enemy: Dictionary in enemies.values():
		known_kind = known_kind or str(enemy.get("art", {}).get("kind", "")) == kind
	if not known_kind:
		faults.append("%s.art.kind is not recognised" % id_key)
	if not _number_between(art.get("hue"), 0.0, 360.0):
		faults.append("%s.art.hue must be between 0 and 360" % id_key)
	if not _number_between(art.get("size"), 0.01, 20.0):
		faults.append("%s.art.size must be between 0.01 and 20" % id_key)


func _validate_start_status(id_key: String, value: Variant,
		faults: PackedStringArray) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		faults.append("%s.startStatus must be a dictionary" % id_key)
		return
	var start: Dictionary = value
	for status_v: Variant in start:
		var status_id: String = str(status_v)
		if not statuses.has(status_id):
			faults.append("%s.startStatus has unknown status %s" % [id_key, status_id])
		elif not _whole_at_least(start[status_v], 0):
			faults.append("%s.startStatus.%s must be a non-negative whole number"
				% [id_key, status_id])


func _validate_enemy_moves(id_key: String, value: Variant, baseline_v: Variant,
		faults: PackedStringArray) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		faults.append("%s.moves must be a dictionary" % id_key)
		return
	var moves: Dictionary = value
	var baseline: Dictionary = baseline_v if typeof(baseline_v) == TYPE_DICTIONARY else {}
	for move_v: Variant in baseline:
		if not moves.has(move_v):
			faults.append("%s.moves cannot remove AI move %s" % [id_key, str(move_v)])
	for move_v: Variant in moves:
		var move_id: String = str(move_v)
		if not baseline.has(move_v):
			faults.append("%s.moves cannot add unused move %s" % [id_key, move_id])
			continue
		var move_value: Variant = moves[move_v]
		if typeof(move_value) != TYPE_DICTIONARY:
			faults.append("%s.moves.%s must be a dictionary" % [id_key, move_id])
			continue
		var move: Dictionary = move_value
		var base_move: Dictionary = baseline[move_v]
		if str(move.get("name", "")) != str(base_move.get("name", "")):
			faults.append("%s.moves.%s.name is locale-owned and read-only" % [id_key, move_id])
		if not ENEMY_INTENTS.has(str(move.get("intent", ""))):
			faults.append("%s.moves.%s.intent is not recognised" % [id_key, move_id])
		for field: String in ["dmg", "block", "heal", "ramp"]:
			if move.has(field) and not _whole_at_least(move[field], 0):
				faults.append("%s.moves.%s.%s must be a non-negative whole number"
					% [id_key, move_id, field])
		if move.has("times") and not _whole_at_least(move["times"], 1):
			faults.append("%s.moves.%s.times must be a positive whole number" % [id_key, move_id])
		_validate_move_fx(id_key, move_id, move.get("fx", []), faults)
		if move.has("addCards"):
			var adds_v: Variant = move["addCards"]
			if typeof(adds_v) != TYPE_DICTIONARY:
				faults.append("%s.moves.%s.addCards must be a dictionary" % [id_key, move_id])
			else:
				var adds: Dictionary = adds_v
				var card_id: String = str(adds.get("id", ""))
				if not cards.has(card_id) or not _whole_at_least(adds.get("n"), 1):
					faults.append("%s.moves.%s.addCards needs a known card and positive count"
						% [id_key, move_id])


func _validate_move_fx(id_key: String, move_id: String, value: Variant,
		faults: PackedStringArray) -> void:
	if typeof(value) != TYPE_ARRAY:
		faults.append("%s.moves.%s.fx must be an array" % [id_key, move_id])
		return
	var effects: Array = value
	for i: int in range(effects.size()):
		var effect_v: Variant = effects[i]
		if typeof(effect_v) != TYPE_DICTIONARY:
			faults.append("%s.moves.%s.fx[%d] must be a dictionary" % [id_key, move_id, i])
			continue
		var effect: Dictionary = effect_v
		var who: String = str(effect.get("who", ""))
		var status_id: String = str(effect.get("id", ""))
		if not ["self", "player", "allies"].has(who) or not statuses.has(status_id) \
				or not _whole_at_least(effect.get("n"), 0):
			faults.append("%s.moves.%s.fx[%d] has an invalid target, status, or amount"
				% [id_key, move_id, i])


static func _whole_at_least(value: Variant, minimum: int) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number: float = float(str(value))
	return is_equal_approx(number, roundf(number)) and number >= float(minimum)


static func _number_between(value: Variant, minimum: float, maximum: float) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return float(str(value)) >= minimum and float(str(value)) <= maximum


func _load_line_table() -> void:
	var text: String = FileAccess.get_file_as_string(LINE_TABLE_PATH)
	if text.is_empty():
		push_error("ContentDB: cannot read %s" % LINE_TABLE_PATH)
		return
	var raw: Variant = JSON.parse_string(text)
	var faults: PackedStringArray = apply_line_table(raw)
	if not faults.is_empty():
		line_table = []
		push_error("ContentDB: refusing %s — %s" % [LINE_TABLE_PATH, faults[0]])


func apply_line_table(raw: Variant) -> PackedStringArray:
	var faults: PackedStringArray = line_table_faults(raw)
	if not faults.is_empty():
		return faults
	var rows: Array = raw
	var parsed: Array = []
	for row_v: Variant in rows:
		var row: Dictionary = row_v
		var copy: Dictionary = row.duplicate(true)
		var parsed_conditions: Dictionary = LineTable.parse_conditions(row.get("conditions", {}))
		copy["conditions"] = parsed_conditions["conditions"]
		parsed.append(copy)
	line_table = parsed
	return PackedStringArray()


func line_table_faults(raw: Variant) -> PackedStringArray:
	var faults: PackedStringArray = PackedStringArray()
	if typeof(raw) != TYPE_ARRAY:
		faults.append("line table must be an array")
		return faults
	var rows: Array = raw
	var ids: Dictionary = {}
	var empty_by_slot: Dictionary = {}
	var pool_slots: Dictionary = {}
	for i: int in range(rows.size()):
		var row_v: Variant = rows[i]
		if typeof(row_v) != TYPE_DICTIONARY:
			faults.append("row %d must be a dictionary" % i)
			continue
		var row: Dictionary = row_v
		var id: String = str(row.get("id", "")).strip_edges()
		var slot: String = str(row.get("slot", "")).strip_edges()
		var zh: String = str(row.get("zh", ""))
		var en: String = str(row.get("en", ""))
		if id.is_empty() or slot.is_empty() or zh.is_empty() or en.is_empty():
			faults.append("row %d missing required field {id, slot, zh, en}" % i)
			continue
		if not row.has("id") or not row.has("slot") or not row.has("zh") or not row.has("en"):
			faults.append("%s missing required field {id, slot, zh, en}" % id)
			continue
		if ids.has(id):
			faults.append("duplicate line id %s" % id)
			continue
		ids[id] = true
		if en == zh:
			faults.append("%s en must differ from zh" % id)
		if not _en_latin_only(en):
			faults.append("%s en must be Latin-only" % id)
		var parsed: Dictionary = LineTable.parse_conditions(row.get("conditions", {}))
		if parsed["ok"] != true:
			faults.append("%s: %s" % [id, str(parsed["error"])])
			continue
		var conditions_v: Variant = parsed["conditions"]
		var conditions: Dictionary = conditions_v if typeof(conditions_v) == TYPE_DICTIONARY else {}
		if not empty_by_slot.has(slot):
			empty_by_slot[slot] = 0
		if conditions.is_empty():
			empty_by_slot[slot] = int(float(str(empty_by_slot[slot]))) + 1
		var cooldown: int = int(float(str(row.get("cooldown_runs", LineTable.DEFAULT_COOLDOWN_RUNS))))
		if cooldown > 0:
			pool_slots[slot] = true
	for slot_v: Variant in pool_slots:
		var slot: String = str(slot_v)
		if int(float(str(empty_by_slot.get(slot, 0)))) < 2:
			faults.append("pool %s needs ≥2 empty-condition fallbacks" % slot)
	return faults


static func _en_latin_only(en: String) -> bool:
	var has_letter: bool = false
	for i: int in range(en.length()):
		var c: int = en.unicode_at(i)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
			has_letter = true
		elif _is_non_latin_letter(c):
			return false
	return has_letter


static func _is_non_latin_letter(c: int) -> bool:
	if c <= 127:
		return false
	if c >= 0x00C0 and c <= 0x024F:
		return true
	if c >= 0x2E80 and c <= 0x9FFF:
		return true
	if c >= 0xAC00 and c <= 0xD7AF:
		return true
	if c >= 0xF900 and c <= 0xFAFF:
		return true
	return false


func _load(path: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("ContentDB: cannot read %s" % path)
		return
	var raw: Variant = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY:
		push_error("ContentDB: %s did not parse to a dictionary" % path)
		return
	var root: Dictionary = raw
	apply_catalogue(root)


func apply_catalogue(root: Dictionary) -> void:
	quest_ids = []
	theme_order = []
	reveal_ids = []
	id = str(root.get("id", ""))
	cards = _section(root, "cards")
	enemies = _section(root, "enemies")
	potions = _section(root, "potions")
	relics = _section(root, "relics")
	arts = _section(root, "arts")
	affixes = _section(root, "affixes")
	statuses = _section(root, "statuses")
	events = _section(root, "events")
	omens = _section(root, "omens")
	deeds = _section(root, "deeds")
	themes = _section(root, "themes")
	quests = _section(root, "quests")
	variants = _section(root, "variants")
	boons = _section(root, "boons")
	progression = _section(root, "progression")
	shop = _section(root, "shop")
	shade_kits = _section(root, "shadeKits")
	card_pools = _section(root, "cardPools")
	relic_pools = _section(root, "relicPools")
	var gate: Dictionary = _section(root, "poolGate")
	pool_gate_cards = gate.get("cards", {})
	pool_gate_relics = gate.get("relics", {})
	var gold_v: Variant = root.get("rewardGold", [])
	if typeof(gold_v) == TYPE_ARRAY:
		reward_gold = gold_v
	else:
		push_error("ContentDB: rewardGold is not an array")
	player = _section(root, "player")
	aspects = _array(root, "aspects")
	vows = _array(root, "vows")
	acts = _array(root, "acts")
	encounters = _array(root, "encounters")
	for id_v: Variant in _array(root, "questIds"):
		quest_ids.append(str(id_v))
	for id_v: Variant in _array(root, "themeOrder"):
		theme_order.append(str(id_v))
	var reveal_rows: Array = _array(root, "reveals")
	for reveal_v: Variant in reveal_rows:
		if typeof(reveal_v) == TYPE_DICTIONARY:
			reveal_ids.append(str(reveal_v.get("id", "")))


## The REVEALS registry ids (save-loader reveal validation) live in the
## core-mechanics fixture, not the slice content projection.
func _load_reveal_ids(path: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	var raw: Variant = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY:
		push_error("ContentDB: cannot parse %s" % path)
		return
	var root: Dictionary = raw
	var mechanics: Dictionary = root.get("mechanics", {})
	var reveals_v: Variant = mechanics.get("REVEALS", [])
	if typeof(reveals_v) != TYPE_ARRAY:
		push_error("ContentDB: mechanics.REVEALS is not an array")
		return
	var reveals_list: Array = reveals_v
	for entry_v: Variant in reveals_list:
		var entry: Dictionary = entry_v
		reveal_ids.append(str(entry.get("id", "")))


func _section(root: Dictionary, key: String) -> Dictionary:
	var v: Variant = root.get(key, {})
	if typeof(v) != TYPE_DICTIONARY:
		push_error("ContentDB: section %s is not a dictionary" % key)
		return {}
	return v


func _array(root: Dictionary, key: String) -> Array:
	var value: Variant = root.get(key, [])
	if typeof(value) != TYPE_ARRAY:
		push_error("ContentDB: section %s is not an array" % key)
		return []
	return value


func _lookup(registry: Dictionary, id_key: StringName, kind: String) -> Dictionary:
	var key: String = String(id_key)
	if not registry.has(key):
		push_error("ContentDB: unknown %s id %s" % [kind, key])
		return {}
	var entry: Dictionary = registry[key]
	return entry


func card(cid: StringName) -> Dictionary:
	return _lookup(cards, cid, "card")


func enemy(eid: StringName) -> Dictionary:
	return _lookup(enemies, eid, "enemy")


func potion(pid: StringName) -> Dictionary:
	return _lookup(potions, pid, "potion")


func relic(rid: StringName) -> Dictionary:
	return _lookup(relics, rid, "relic")


func _ids(registry: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for k: Variant in registry.keys():
		var ks: String = k
		out.append(StringName(ks))
	out.sort()
	return out


func card_ids() -> Array[StringName]:
	return _ids(cards)


func enemy_ids() -> Array[StringName]:
	return _ids(enemies)


## Every enemy this content ships must have an implemented AI handler — the M2
## slice of the broader "every in-scope dispatch-inventory id has a handler" rule.
func validate(fails: Array[String]) -> void:
	for eid: StringName in enemy_ids():
		if not EnemyAi.handles(eid):
			fails.append("ContentDB: enemy %s has no AI handler" % eid)
		for fault: String in enemy_faults(String(eid), enemy(eid)):
			fails.append("ContentDB: %s" % fault)
	for card_v: Variant in cards.values():
		var card_def: Dictionary = card_v
		_validate_effects(card_def.get("effects", []), fails)
		var upgraded_v: Variant = card_def.get("up")
		if typeof(upgraded_v) == TYPE_DICTIONARY:
			var upgraded: Dictionary = upgraded_v
			_validate_effects(upgraded.get("effects", []), fails)
	for potion_id: String in potions:
		if not CombatRules.handles_potion(potion_id):
			fails.append("ContentDB: potion %s has no handler" % potion_id)


func _validate_effects(effects_v: Variant, fails: Array[String]) -> void:
	if typeof(effects_v) != TYPE_ARRAY:
		return
	for effect_v: Variant in effects_v:
		if typeof(effect_v) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_v
		if str(effect.get("kind")) == "special":
			var id_key: String = str(effect.get("id"))
			if not CombatRules.handles_special(id_key):
				fails.append("ContentDB: card special %s has no handler" % id_key)
