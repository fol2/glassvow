class_name ContentDB
extends RefCounted
## Loads the vertical-slice content projection (port_fixtures/content/slice-content.json)
## into id-validated registries. Lives OUTSIDE domain/ so it may touch FileAccess —
## the pure domain rules receive already-resolved data, never file paths.

const SLICE_PATH: String = "res://port_fixtures/content/slice-content.json"
const CORE_MECHANICS_PATH: String = "res://port_fixtures/content/core-mechanics.json"

var id: String = ""
var cards: Dictionary = {}
var enemies: Dictionary = {}
var potions: Dictionary = {}
var relics: Dictionary = {}
var arts: Dictionary = {}
var affixes: Dictionary = {}
var statuses: Dictionary = {}
var card_pools: Dictionary = {}
var relic_pools: Dictionary = {}
var pool_gate_cards: Dictionary = {}
var pool_gate_relics: Dictionary = {}
var reward_gold: Array = []  # per act: {"normal": [a,b], "elite": [a,b], "boss": [a,b]}
var player: Dictionary = {}
var reveal_ids: Array[String] = []


static func load_slice() -> ContentDB:
	var db: ContentDB = ContentDB.new()
	db._load(SLICE_PATH)
	db._load_reveal_ids(CORE_MECHANICS_PATH)
	return db


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
	id = str(root.get("id", ""))
	cards = _section(root, "cards")
	enemies = _section(root, "enemies")
	potions = _section(root, "potions")
	relics = _section(root, "relics")
	arts = _section(root, "arts")
	affixes = _section(root, "affixes")
	statuses = _section(root, "statuses")
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
