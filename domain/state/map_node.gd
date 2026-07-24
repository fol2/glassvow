class_name MapNode
extends RefCounted
## One waystone on the world path (concept brief §4). Pure data: the eight
## frozen type keys, the encounter it holds, and its ordinal position along
## the journey. `world_x` is an ordinal — the screen multiplies it by a
## spacing constant, so tuning the look never touches the data.

var type: String = "monster"        # monster|elite|event|rest|shop|treasure|boss|monument
var enemies: Array[String] = []     # content ids the combat screen consumes
var world_x: int = 0
var unlit: bool = false             # dark-lantern: type hidden until a bounty is paid
var affix: Variant = null           # elite affix id, or null to roll at start_combat


static func make(type_key: String, enemy_ids: Array[String], wx: int) -> MapNode:
	var n: MapNode = MapNode.new()
	n.type = type_key
	n.enemies = enemy_ids
	n.world_x = wx
	return n


## The combat `kind` this node starts — drives reward tier and affix rolls.
func combat_kind() -> String:
	return "elite" if type == "elite" else "normal"


func is_combat() -> bool:
	return type == "monster" or type == "elite" or type == "boss"
