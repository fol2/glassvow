extends "res://presentation/map/chapters/common/smooth_surfaces.gd"
## Exact-height landing ownership. Unlike the rejected experiment, never warps heights.
var lower: RefCounted
var pads: PackedVector2Array = []

func field(at: Vector2) -> Dictionary:
	var result: Dictionary = super.field(at)
	# No upper surface exists here, so it cannot delegate a landing.
	if result["distance"]==INF: return result
	var landing: Dictionary = lower.field(at)
	var height: float = result["height"]
	var landing_height: float = landing["height"]
	if absf(height-landing_height)>.00001:
		return result
	var distance: float = result["distance"]
	var landing_distance: float = landing["distance"]
	result["distance"] = maxf(distance,-landing_distance)
	result["delegated"] = distance<=0 and landing_distance<=0
	return result
