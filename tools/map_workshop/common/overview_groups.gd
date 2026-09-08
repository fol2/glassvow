extends RefCounted
## Deterministic screen clusters retain every represented ID and 44 px targets.
static func build(points: Array[Dictionary], spacing: float = 48.0) -> Array[Dictionary]:
	var ordered: Array[Dictionary] = points.duplicate()
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var x: Vector2 = a["at"]
		var y: Vector2 = b["at"]
		return x.x < y.x if x.x != y.x else str(a["id"]) < str(b["id"]))
	var groups: Array[Dictionary] = []
	for point: Dictionary in ordered:
		var at: Vector2 = point["at"]
		var chosen: int = -1
		var distance: float = INF
		for index: int in range(groups.size()):
			var centre: Vector2 = groups[index]["at"]
			var delta: Vector2 = (at-centre).abs()
			if delta.x < spacing and delta.y < spacing and delta.length_squared() < distance:
				chosen = index
				distance = delta.length_squared()
		if chosen < 0:
			groups.append({"at":at,"ids":[str(point["id"])]})
		else:
			groups[chosen]["ids"].append(str(point["id"]))
	return groups
