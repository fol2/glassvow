extends "res://presentation/map/chapters/common/profile.gd"
## Use current generated route heights; never read a saved study optimisation.
func load_candidate(_sample: Dictionary) -> void:
	pass

func apply(key: String, original: PackedVector3Array) -> PackedVector3Array:
	var recorded: Array = []
	for p: Vector3 in original: recorded.append([p.x,p.y,p.z])
	routes[key]=recorded
	return original
