extends RefCounted
## Conservative broad phase only. The caller keeps its exact overlap rules.
const CELL: float = 8.0
var cells: Dictionary = {}
var maximum_radius: float = 0.0

func add(item: Dictionary) -> void:
	var at: Vector3 = item["position"]
	var key: Vector2i = Vector2i(floori(at.x/CELL),floori(at.z/CELL))
	if not cells.has(key): cells[key] = []
	cells[key].append(item)
	maximum_radius = maxf(maximum_radius,float(str(item["radius"])))

func query(at: Vector3, radius: float) -> Array[Dictionary]:
	var extent: float = radius+maximum_radius
	var result: Array[Dictionary] = []
	for x: int in range(floori((at.x-extent)/CELL),floori((at.x+extent)/CELL)+1):
		for z: int in range(floori((at.z-extent)/CELL),floori((at.z+extent)/CELL)+1):
			var key: Vector2i = Vector2i(x,z)
			if cells.has(key):
				var bucket: Array = cells[key]
				result.append_array(bucket)
	return result
