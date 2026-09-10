class_name MapNode
extends RefCounted
## One waystone on the world path (concept brief §4). Pure data: the eight
## frozen type keys, the encounter it holds, and its ordinal position along
## the journey. `world_x` is an ordinal — the screen multiplies it by a
## spacing constant, so tuning the look never touches the data.

var type: String = "monster"        # monster|elite|event|rest|shop|treasure|boss|monument
var enemies: Array[String] = []     # content ids the combat screen consumes
var id: String = ""
var row: int = 0
var col: int = 0
var next: Array[String] = []
var jx: float = 0.0
var jy: float = 0.0
var world_x: int = 0
var unlit: bool = false             # dark-lantern: type hidden until a bounty is paid
var bounty: int = 0
var affix: Variant = null           # elite affix id, or null to roll at start_combat
var quest_variant_id: Variant = null
var quest_marked: bool = false


static func make(type_key: String, enemy_ids: Array[String], wx: int) -> MapNode:
	var n: MapNode = MapNode.new()
	n.type = type_key
	n.enemies = enemy_ids
	n.world_x = wx
	n.id = "n%d" % wx
	n.row = wx
	n.col = 0
	return n


func to_dict() -> Dictionary:
	var out: Dictionary = {
		"id": id, "row": row, "col": col, "type": type, "next": next.duplicate(),
		"jx": jx, "jy": jy,
	}
	if not enemies.is_empty():
		out["enemies"] = enemies.duplicate()
	if unlit:
		out["unlit"] = true
		out["bounty"] = bounty
	if affix != null:
		out["affix"] = affix
	if quest_variant_id != null:
		out["questVariantId"] = quest_variant_id
		out["questMarked"] = quest_marked
	return out


static func from_dict(raw: Dictionary) -> MapNode:
	var n: MapNode = MapNode.new()
	n.id = str(raw.get("id", ""))
	n.row = int(float(str(raw.get("row", 0))))
	n.col = int(float(str(raw.get("col", 0))))
	n.world_x = n.col
	n.type = str(raw.get("type", "monster"))
	for next_v: Variant in raw.get("next", []):
		n.next.append(str(next_v))
	for enemy_v: Variant in raw.get("enemies", []):
		n.enemies.append(str(enemy_v))
	n.jx = float(str(raw.get("jx", 0)))
	n.jy = float(str(raw.get("jy", 0)))
	n.unlit = raw.get("unlit", false)
	n.bounty = int(float(str(raw.get("bounty", 0))))
	n.affix = raw.get("affix")
	n.quest_variant_id = raw.get("questVariantId")
	n.quest_marked = raw.get("questMarked", false)
	return n


## The combat `kind` this node starts — drives reward tier and affix rolls.
func combat_kind() -> String:
	return "boss" if type == "boss" else ("elite" if type == "elite" else "normal")


func is_combat() -> bool:
	return type == "monster" or type == "elite" or type == "boss"
