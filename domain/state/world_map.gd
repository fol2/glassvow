class_name WorldMap
extends RefCounted
## The pilgrimage graph (concept brief §1/§4): waystones laid west-to-east
## across one region, joined by directed edges. Pure state — the screen reads
## it and animates, never the reverse.
##
## M6 ships one hand-authored linear strip matching the M5 encounter ladder.
## The generator (branching, ~15-row acts, weighted pools, unlit placement) is
## a later milestone; the adjacency model already expresses it — a node with
## two out-edges is a fork, no shape change needed here.

var region: String = "ashen_woods"
var nodes: Array[MapNode] = []
var edges: Dictionary = {}       # int index -> Array of out-edge indices
var at: int = 0                  # index the lantern marker sits on
var cleared: Dictionary = {}     # int index -> true once resolved


## The vertical-slice strip: sporeling pair → duskfang → waylayer → rest →
## gravewarden elite. `affix` stays null so live play rolls it in start_combat
## (the elite trace passed it explicitly only to skip that draw).
static func slice() -> WorldMap:
	var m: WorldMap = WorldMap.new()
	m.region = "ashen_woods"
	var pair: Array[String] = ["sporeling", "sporeling"]
	var dusk: Array[String] = ["duskfang"]
	var way: Array[String] = ["waylayer"]
	var none: Array[String] = []
	var grave: Array[String] = ["gravewarden"]
	m.nodes.append(MapNode.make("monster", pair, 0))
	m.nodes.append(MapNode.make("monster", dusk, 1))
	m.nodes.append(MapNode.make("monster", way, 2))
	m.nodes.append(MapNode.make("rest", none, 3))
	m.nodes.append(MapNode.make("elite", grave, 4))
	m.edges = {0: [1], 1: [2], 2: [3], 3: [4]}
	return m


func current() -> MapNode:
	return nodes[at] if at >= 0 and at < nodes.size() else null


func is_cleared(i: int) -> bool:
	return cleared.has(i)


## Selectable right now: the node under the marker while it is unresolved,
## otherwise its uncleared out-edges. Everything else draws dim and inert.
func reachable() -> Array[int]:
	var out: Array[int] = []
	if at < 0 or at >= nodes.size():
		return out
	if not cleared.has(at):
		out.append(at)
		return out
	var outs: Array = edges.get(at, [])
	for v: Variant in outs:
		var i: int = v
		if i >= 0 and i < nodes.size() and not cleared.has(i):
			out.append(i)
	return out


## Seat the marker on a reachable node; false leaves the map untouched.
func enter(i: int) -> bool:
	if not reachable().has(i):
		return false
	at = i
	return true


func clear_current() -> void:
	cleared[at] = true


func is_finished() -> bool:
	return reachable().is_empty()
