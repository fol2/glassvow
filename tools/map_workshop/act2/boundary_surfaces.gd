extends "res://tools/map_workshop/bridge_surfaces.gd"
## Evaluate clipped boundaries on their actual route, not an outside grid sample.
func _position(item: Dictionary) -> Vector3:
	var result: Vector3 = super._position(item)
	var distance: float = item["distance"]
	if absf(distance)<.00000001:
		var sampled: Dictionary = field(Vector2(result.x,result.z))
		result.y = sampled["height"]
	return result
