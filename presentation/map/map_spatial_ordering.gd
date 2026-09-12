extends RefCounted
## Exact bounded layered ordering. Game IDs/edges/columns are never mutated.
## Profile assignments place those IDs into the row's available presentation slots.
const VERSION: String = "layered-order-dp-v1"
const MAX_TRANSITIONS: int = 8000000

static func generate(nodes: Array, edges: Array) -> Dictionary:
	var rows: Dictionary = {}
	var records: Dictionary = {}
	for node: Dictionary in nodes:
		var id: String = str(node["id"])
		var row: int = int(MapLayoutCanonical.float_value(node["row"]))
		if records.has(id):
			return {"ok": false, "reason": "duplicate node"}
		records[id] = node
		if not rows.has(row):
			rows[row] = []
		rows[row].append(id)
	var row_ids: Array = rows.keys()
	row_ids.sort()
	if row_ids.is_empty():
		return {"ok": false, "reason": "empty graph"}
	for edge: Dictionary in edges:
		if not records.has(str(edge["from"])) or not records.has(str(edge["to"])):
			return {"ok": false, "reason": "edge endpoint absent"}
		if MapLayoutCanonical.float_value(records[str(edge["to"])]["row"]) - \
				MapLayoutCanonical.float_value(records[str(edge["from"])]["row"]) != 1.0:
			return {"ok": false, "reason": "ordering requires adjacent forward rows"}
	var permutations: Dictionary = {}
	var ranks: Dictionary = {}
	for row: int in row_ids:
		var ids: Array = rows[row]
		ids.sort_custom(func(a: String, b: String) -> bool:
			var ac: float = MapLayoutCanonical.float_value(records[a]["col"])
			var bc: float = MapLayoutCanonical.float_value(records[b]["col"])
			return ac < bc if ac != bc else a < b)
		if ids.size() > 7:
			return {"ok": false, "reason": "row exceeds seven-slot contract"}
		var variants: Array = []
		_permute(ids, [], variants)
		permutations[row] = variants
		var rank_rows: Array = []
		for variant: Array in variants:
			var rank: Dictionary = {}
			for index: int in range(variant.size()):
				rank[str(variant[index])] = index
			rank_rows.append(rank)
		ranks[row] = rank_rows
	var costs: Array[int] = []
	var initial: Array = permutations[row_ids[0]]
	costs.resize(initial.size())
	costs.fill(0)
	var backs: Dictionary = {}
	var transitions: int = 0
	for row_index: int in range(1, row_ids.size()):
		var row: int = row_ids[row_index]
		var previous_row: int = row_ids[row_index - 1]
		var boundary: Array[Dictionary] = []
		for edge: Dictionary in edges:
			if int(MapLayoutCanonical.float_value(records[str(edge["from"])]["row"])) == previous_row:
				boundary.append(edge)
		var pairs: Array = []
		for i: int in range(boundary.size()):
			for j: int in range(i + 1, boundary.size()):
				var a: Dictionary = boundary[i]
				var b: Dictionary = boundary[j]
				if a["from"] != b["from"] and a["to"] != b["to"]:
					pairs.append([a["from"], b["from"], a["to"], b["to"]])
		var source_signs: Array = []
		for rank: Dictionary in ranks[previous_row]:
			source_signs.append(_signs(rank, pairs, 0))
		var next_costs: Array[int] = []
		var back: Array[int] = []
		var lower_bound: int = costs.min()
		for target: Dictionary in ranks[row]:
			var signs: PackedInt32Array = _signs(target, pairs, 2)
			var best: int = 2147483647
			var winner: int = 0
			for index: int in range(source_signs.size()):
				if costs[index] > best:
					continue
				transitions += 1
				if transitions > MAX_TRANSITIONS:
					return {"ok": false, "reason": "ordering transition budget exceeded"}
				var source: PackedInt32Array = source_signs[index]
				var value: int = costs[index]
				for pair_index: int in range(signs.size()):
					value += int(source[pair_index] != signs[pair_index])
				if value < best:
					best = value
					winner = index
				if best == lower_bound:
					break
			next_costs.append(best)
			back.append(winner)
		costs = next_costs
		backs[row] = back
	var minimum: int = costs.min()
	var chosen: int = costs.find(minimum)
	var assignments: Dictionary = {}
	for row_index: int in range(row_ids.size() - 1, -1, -1):
		var row: int = row_ids[row_index]
		var ordered: Array = permutations[row][chosen]
		for index: int in range(ordered.size()):
			assignments[str(ordered[index])] = records[str(rows[row][index])]["col"]
		if row_index > 0:
			chosen = backs[row][chosen]
	return {"ok": true, "version": VERSION, "minimum_layered_crossings": minimum,
		"transitions": transitions, "assignments": MapLayoutCanonical.ordered_dictionary(assignments)}

static func _signs(rank: Dictionary, pairs: Array, offset: int) -> PackedInt32Array:
	var out: PackedInt32Array = []
	for pair: Array in pairs:
		out.append(1 if rank[str(pair[offset])] > rank[str(pair[offset + 1])] else -1)
	return out

static func _permute(remaining: Array, prefix: Array, out: Array) -> void:
	if remaining.is_empty():
		out.append(prefix)
		return
	for index: int in range(remaining.size()):
		var next: Array = remaining.duplicate()
		var value: Variant = next.pop_at(index)
		_permute(next, prefix + [value], out)
