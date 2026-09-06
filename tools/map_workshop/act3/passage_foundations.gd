extends "res://tools/map_workshop/bridge_surfaces.gd"
## Broad solid terraces, excavated only where a lower ceremonial passage crosses.
var lower: RefCounted
var upper: RefCounted

func field(at: Vector2) -> Dictionary:
	var result: Dictionary = super.field(at)
	var distance: float = result["distance"]
	if not is_finite(distance):
		return result
	var paving: Dictionary = upper.field(at)
	var height: float = result["height"]-.30
	var paving_height: float = paving["height"]
	if paving["distance"]<=.1:
		height = minf(height,paving_height-.28)
	result["height"] = height
	var floor_sample: Dictionary = lower.field(at)
	var bottom: float = -1.8
	var lower_height: float = floor_sample["height"]
	var lower_distance: float = floor_sample["distance"]
	var gap: float = height-lower_height
	if lower_distance<1.1:
		if gap<.6:
			# Solid shared landings sit below the actual treads of both routes.
			result["height"] = minf(height,lower_height-.30)
		else:
			# A continuous cut boundary leaves the stair approach open to the sky.
			result["distance"] = maxf(distance,minf(1.1-lower_distance,(2.65-gap)*2.0))
			bottom = lerpf(-1.8,height-.16,1.0-smoothstep(0.0,.55,lower_distance))
	result["bottom"] = bottom
	return result
