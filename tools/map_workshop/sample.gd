extends RefCounted
## Read a declared generated sample; never substitute a different seed on failure.
const DEFAULT: String = "res://docs/map/studies/camera-composition/act1-seed717.json"
static func read(path: String = "") -> Dictionary:
	if path.is_empty():
		path = DEFAULT
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--sample="):
				path = argument.trim_prefix("--sample=")
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary:
		push_error("Cannot read generated workshop sample: "+path)
		return {}
	var data: Dictionary = value
	for key: String in ["nodes","anchors","edges","seed","act","input_digest","layout_digest"]:
		if not data.has(key):
			push_error("Generated sample is missing "+key)
			return {}
	if data.get("compiler_hard_pass")!=true:
		push_error("Generated sample has no passing compiler receipt")
		return {}
	return data

static func visit(map: WorldMap, destination: String) -> bool:
	# Replay a legal route to a named inspection location; never move the game
	# cursor directly or pretend a selected edge was reachable.
	var by_id: Dictionary = {}
	for i: int in range(map.nodes.size()):
		by_id[map.nodes[i].id] = i
	if not by_id.has(destination):
		return false
	var parents: Dictionary = {}
	var queue: Array[int] = map.reachable()
	for index: int in queue:
		parents[index] = -1
	var cursor: int = 0
	while cursor<queue.size():
		var index: int = queue[cursor]
		cursor += 1
		for next_id: String in map.nodes[index].next:
			var target: int = by_id[next_id]
			if not parents.has(target):
				parents[target] = index
				queue.append(target)
	var current: int = by_id[destination]
	if not parents.has(current):
		return false
	var history: Array[int] = []
	while current>=0:
		history.append(current)
		current = parents[current]
	history.reverse()
	for index: int in history:
		if not map.enter(index):
			return false
		map.clear_current()
	return map.nodes[map.at].id==destination
