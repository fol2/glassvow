class_name WorldMap
extends RefCounted
## The benchmark pilgrimage graph: 15 rows of joined waystones across seven
## columns. Pure state — the screen reads and animates it, never the reverse.
##
## `benchmark()` is the frozen reference's 15×7, six-path generator. `slice()`
## remains only until every generated node type has a live route. `act4()` is
## the authored Mirrored Road: five nodes in a line, not a short `benchmark()`.

const ROWS: int = 15
const COLS: int = 7
const PATHS: int = 6
## Half-width of each node's authored wander, as a fraction of the lane/step it
## sits in: `jx` spans ±0.25 and `jy` ±0.20. Named because presentation reads
## them as bounds — `tests/test_map.gd` asserts the terminus arch fits at the
## worst realisation, and a spread edited here without that gate seeing it would
## be a screen defect no test could catch (PR #79 DL R3).
const JITTER_SPREAD: Vector2 = Vector2(0.5, 0.4)
## 鏡中歸途 / The Mirrored Road — monster → monster → elite → rest → boss.
const ACT4_TYPES: PackedStringArray = ["monster", "monster", "elite", "rest", "boss"]
const ACT4_MOTIFS: PackedStringArray = [
	"threshold-prime", "III-prime", "II-prime", "I-prime", "hearth-prime",
]

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
	for i: int in range(m.nodes.size() - 1):
		m.nodes[i].next.append(m.nodes[i + 1].id)
	return m


## Acts I–III stay generated. Act IV is the authored five-node line.
static func for_run(run: RunState, content: ContentDB) -> WorldMap:
	if run.act == 3:
		return act4(run, content)
	return benchmark(run)


## First clear pins motif-matched landed selves (and `encounters[3]` when
## present). Later runs redraw the two monsters and the elite from that pool;
## types, order and the boss stay fixed.
static func act4(run: RunState, content: ContentDB) -> WorldMap:
	var m: WorldMap = WorldMap.new()
	m.region = "rose_window"
	m.at = -1
	var first_clear: bool = not run.unlocks.has(RunState.MIRRORED_ROAD)
	for i: int in range(ACT4_TYPES.size()):
		var type_key: String = ACT4_TYPES[i]
		var occupants: Array[String] = []
		if type_key != "rest":
			occupants = _act4_occupants(run, content, type_key, i, first_clear)
		m.nodes.append(MapNode.make(type_key, occupants, i))
	m.edges = {0: [1], 1: [2], 2: [3], 3: [4]}
	for i: int in range(m.nodes.size() - 1):
		m.nodes[i].next.append(m.nodes[i + 1].id)
	return m


static func _act4_occupants(
	run: RunState, content: ContentDB, type_key: String, index: int, first_clear: bool
) -> Array[String]:
	var pool: Array = _act4_pool(content, type_key)
	if not pool.is_empty():
		if type_key == "boss" or first_clear:
			var group_i: int = 0
			if type_key == "monster" and index == 1 and pool.size() > 1:
				group_i = 1
			return _copy_group(pool, group_i)
		return _copy_group(pool, run.rng.pick_index(pool.size()))
	return _act4_motif_pin(content, index)


static func _act4_pool(content: ContentDB, type_key: String) -> Array:
	if content == null or content.encounters.size() <= 3:
		return []
	var row_v: Variant = content.encounters[3]
	if typeof(row_v) != TYPE_DICTIONARY:
		return []
	var row: Dictionary = row_v
	var key: String = "boss" if type_key == "boss" else (
		"elite" if type_key == "elite" else "normal"
	)
	var pool_v: Variant = row.get(key, [])
	return pool_v if typeof(pool_v) == TYPE_ARRAY else []


static func _act4_motif_pin(content: ContentDB, index: int) -> Array[String]:
	var out: Array[String] = []
	if content == null or index < 0 or index >= ACT4_MOTIFS.size():
		return out
	var wanted: String = ACT4_MOTIFS[index]
	for id_v: Variant in content.enemies.keys():
		var id: String = str(id_v)
		var def_v: Variant = content.enemies.get(id, {})
		if typeof(def_v) != TYPE_DICTIONARY:
			continue
		var def: Dictionary = def_v
		var spec_v: Variant = def.get("counterfactual", {})
		if typeof(spec_v) != TYPE_DICTIONARY:
			continue
		var spec: Dictionary = spec_v
		if str(spec.get("node", "")) == wanted:
			out.append(id)
	return out


static func _copy_group(pool: Array, index: int) -> Array[String]:
	var out: Array[String] = []
	if pool.is_empty():
		return out
	var pick_v: Variant = pool[clampi(index, 0, pool.size() - 1)]
	if typeof(pick_v) != TYPE_ARRAY:
		return out
	for id_v: Variant in pick_v:
		var id: String = str(id_v)
		if not id.is_empty():
			out.append(id)
	return out


static func act4_entrance() -> WorldMap:
	var m: WorldMap = WorldMap.new()
	m.region = "rose_window"
	m.at = -1
	var entrance: MapNode = MapNode.new()
	entrance.id = "act4"
	entrance.row = 0
	entrance.col = 3
	entrance.type = "act4"
	m.nodes.append(entrance)
	return m


## Byte-order port of engine.js genMap at roguecardv2-benchmark@6e06911.
static func benchmark(run: RunState) -> WorldMap:
	var m: WorldMap = WorldMap.new()
	var regions: Array[String] = ["ashen_woods", "sunken_city", "obsidian_court", "rose_window"]
	m.region = regions[clampi(run.act, 0, regions.size() - 1)]
	m.at = -1
	var grid: Dictionary = {}
	var used_start: Dictionary = {}
	for path: int in range(PATHS):
		var col: int = 0
		while true:
			col = run.rng.pick_index(COLS)
			if path >= 2 or not used_start.has(col):
				break
		used_start[col] = true
		var current: MapNode = _node_at(m, grid, run.rng, 0, col)
		for row: int in range(1, ROWS - 1):
			var dc: int = clampi(current.col + run.rng.pick_index(3) - 1, 0, COLS - 1)
			var following: MapNode = _node_at(m, grid, run.rng, row, dc)
			if not current.next.has(following.id):
				current.next.append(following.id)
			current = following
		var boss: MapNode = _node_at(m, grid, run.rng, ROWS - 1, 3)
		if not current.next.has(boss.id):
			current.next.append(boss.id)

	var has_shop: bool = false
	for n: MapNode in m.nodes:
		if n.row == 0:
			n.type = "monster"
		elif n.row == ROWS - 1:
			n.type = "boss"
		elif n.row == ROWS - 2:
			n.type = "rest"
		elif n.row == 8:
			n.type = "treasure"
		else:
			var roll: float = run.rng.next()
			if roll < 0.46:
				n.type = "monster"
			elif roll < 0.68:
				n.type = "event"
			elif roll < 0.81 and n.row >= 5:
				n.type = "elite"
			elif roll < 0.91 and n.row >= 4 and n.row < ROWS - 3:
				n.type = "rest"
			elif n.row >= 4:
				n.type = "shop"
			else:
				n.type = "monster"
		has_shop = has_shop or n.type == "shop"
	if not has_shop:
		var candidates: Array[MapNode] = []
		for n: MapNode in m.nodes:
			if n.type == "monster" and n.row >= 5 and n.row <= 11:
				candidates.append(n)
		if not candidates.is_empty():
			candidates[run.rng.pick_index(candidates.size())].type = "shop"
	for n: MapNode in m.nodes:
		if n.row == 0 or n.row == 8 or n.row >= ROWS - 2:
			continue
		if run.rng.next() < 0.15:
			n.unlit = true
			n.bounty = run.rng.irange(12, 22) + run.act * 6
	_place_monument(m, run)
	m._rebuild_edges()
	return m


static func _node_at(
	m: WorldMap, grid: Dictionary, rng: Rng, row: int, col: int
) -> MapNode:
	var key: String = "%d,%d" % [row, col]
	if grid.has(key):
		return grid[key]
	var n: MapNode = MapNode.new()
	n.id = key
	n.row = row
	n.col = col
	n.world_x = col
	n.jx = (rng.next() - 0.5) * JITTER_SPREAD.x
	n.jy = (rng.next() - 0.5) * JITTER_SPREAD.y
	grid[key] = n
	m.nodes.append(n)
	return n


static func _place_monument(m: WorldMap, run: RunState) -> void:
	if typeof(run.monument) != TYPE_DICTIONARY:
		return
	var monument: Dictionary = run.monument
	if monument.get("claimed", false) or int(float(str(monument.get("act", -1)))) != run.act:
		return
	var shops: int = 0
	for n: MapNode in m.nodes:
		if n.type == "shop":
			shops += 1
	var target_row: int = clampi(int(float(str(monument.get("row", 5)))), 1, ROWS - 3)
	var best: MapNode = null
	for n: MapNode in m.nodes:
		if n.row <= 0 or n.row >= ROWS - 2 or n.row == 8 or n.type == "boss":
			continue
		if shops == 1 and n.type == "shop":
			continue
		if best == null or absi(n.row - target_row) < absi(best.row - target_row):
			best = n
	if best != null:
		best.type = "monument"
		best.unlit = false
		best.bounty = 0


func to_dict() -> Dictionary:
	var node_rows: Array = []
	for n: MapNode in nodes:
		node_rows.append(n.to_dict())
	var cleared_ids: Array[String] = []
	for index_v: Variant in cleared:
		var index: int = index_v
		if index >= 0 and index < nodes.size():
			cleared_ids.append(nodes[index].id)
	return {"region": region, "nodes": node_rows, "at": at, "cleared": cleared_ids}


static func from_dict(raw: Dictionary) -> WorldMap:
	var m: WorldMap = WorldMap.new()
	m.region = str(raw.get("region", "ashen_woods"))
	m.at = int(float(str(raw.get("at", -1))))
	var by_id: Dictionary = {}
	for node_v: Variant in raw.get("nodes", []):
		if typeof(node_v) != TYPE_DICTIONARY:
			return null
		var node_row: Dictionary = node_v
		var n: MapNode = MapNode.from_dict(node_row)
		if n.id.is_empty() or by_id.has(n.id):
			return null
		by_id[n.id] = m.nodes.size()
		m.nodes.append(n)
	for id_v: Variant in raw.get("cleared", []):
		var id: String = str(id_v)
		if by_id.has(id):
			m.cleared[by_id[id]] = true
	m._rebuild_edges()
	return m


func _rebuild_edges() -> void:
	edges.clear()
	var by_id: Dictionary = {}
	for i: int in range(nodes.size()):
		by_id[nodes[i].id] = i
	for i: int in range(nodes.size()):
		var out: Array[int] = []
		for id: String in nodes[i].next:
			if by_id.has(id):
				out.append(by_id[id])
		if not out.is_empty():
			edges[i] = out


func current() -> MapNode:
	return nodes[at] if at >= 0 and at < nodes.size() else null


func is_cleared(i: int) -> bool:
	return cleared.has(i)


## Selectable right now: the node under the marker while it is unresolved,
## otherwise its uncleared out-edges. Everything else draws dim and inert.
func reachable() -> Array[int]:
	var out: Array[int] = []
	if at < 0:
		for i: int in range(nodes.size()):
			if nodes[i].row == 0 and not cleared.has(i):
				out.append(i)
		return out
	if at >= nodes.size():
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
