class_name ContentDB
extends RefCounted
## Loads either the frozen fixture slice or the complete 6e06911 catalogue into
## id-validated registries. File access stays outside the pure domain.

const SLICE_PATH: String = "res://port_fixtures/content/slice-content.json"
const FULL_PATH: String = "res://content/full-content.json"
const CORE_MECHANICS_PATH: String = "res://port_fixtures/content/core-mechanics.json"

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


static func load_slice() -> ContentDB:
	var db: ContentDB = ContentDB.new()
	db._load(SLICE_PATH)
	db._load_reveal_ids(CORE_MECHANICS_PATH)
	return db


static func load_full() -> ContentDB:
	var db: ContentDB = ContentDB.new()
	db._load(FULL_PATH)
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
