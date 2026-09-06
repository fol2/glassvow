extends "res://tools/map_workshop/bridge_surfaces.gd"
## An upper deck delegates shared bridgehead pavement to the lower landing.
## Genuine grade-separated crossings remain two independent surfaces.
var landing: RefCounted
var pads: PackedVector2Array = []

func field(at: Vector2) -> Dictionary:
	var result: Dictionary = super.field(at)
	if not is_instance_valid(landing):
		return result
	var nearest: float = INF
	for pad: Vector2 in pads:
		nearest = minf(nearest,at.distance_to(pad))
	if nearest>3.0:
		return result
	var lower: Dictionary = landing.field(at)
	var distance: float = lower["distance"]
	var original: float = result["distance"]
	var floor_height: float = lower["height"]
	var upper_height: float = result["height"]
	if distance>1.2 or absf(upper_height-floor_height)>1.5:
		return result
	var blend: float = 1.0-smoothstep(0,1.2,distance)
	var joined_height: float = lerpf(upper_height,floor_height,blend)
	result["height"] = joined_height
	var bottom: float = result["bottom"]
	result["bottom"] = minf(bottom,joined_height-.3)
	# Subtraction produces one owner at the landing, rather than coplanar decks.
	result["distance"] = maxf(original,-distance)
	result["delegated"] = distance<=0 and original<=0
	return result
