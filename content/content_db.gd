class_name ContentDB
extends RefCounted
## Loads the vertical-slice content projection (port_fixtures/content/slice-content.json)
## into id-validated registries. Lives OUTSIDE domain/ so it may touch FileAccess —
## the pure domain rules receive already-resolved data, never file paths.

const SLICE_PATH: String = "res://port_fixtures/content/slice-content.json"

var id: String = ""
var cards: Dictionary = {}
var enemies: Dictionary = {}
var potions: Dictionary = {}
var relics: Dictionary = {}
var arts: Dictionary = {}
var affixes: Dictionary = {}
var statuses: Dictionary = {}


static func load_slice() -> ContentDB:
	var db: ContentDB = ContentDB.new()
	db._load(SLICE_PATH)
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
