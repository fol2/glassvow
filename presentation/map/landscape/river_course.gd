extends RefCounted
## Keep the complete river/bank envelope clear of excavated dry passages.
static func choose(cuts: Array[Dictionary], bounds: Rect2) -> Dictionary:
	var intervals: Array[Vector2] = []
	for cut: Dictionary in cuts:
		var at: Vector2 = cut["at"]
		var direction: Vector2 = cut["direction"]
		# Dry excavation is 11m along / 4.5m across. Add 2.2m meander,
		# 4m river half-width and a half-metre terrain-cell separation.
		var radius: float = absf(direction.x)*11+absf(direction.y)*4.5+6.7
		intervals.append(Vector2(at.x-radius,at.x+radius))
	var candidates: PackedFloat64Array = [-5.0]
	for interval: Vector2 in intervals:
		candidates.append(interval.x-.01)
		candidates.append(interval.y+.01)
	var best: float = INF
	for candidate: float in candidates:
		if candidate<bounds.position.x+6.7 or candidate>bounds.end.x-6.7: continue
		var free: bool = true
		for interval: Vector2 in intervals:
			if candidate>=interval.x and candidate<=interval.y:
				free=false
				break
		if free and absf(candidate+5)<absf(best+5): best=candidate
	return {"ok":is_finite(best),"centre_x":best}
