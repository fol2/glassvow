extends RefCounted
const Crossing = preload("res://presentation/map/map_journey_crossing.gd")
static func run(fails: Array[String]) -> void:
	var upper: Dictionary = {"corridor_width":2.5,"centerline":[[0.0,1.8,-6.0],[40.0,1.8,6.0]]}
	var lower: Dictionary = {"corridor_width":2.5,"centerline":[[0.0,1.8,6.0],[40.0,1.8,-6.0]]}
	if not Crossing._chord(upper,lower,1.0,false):
		fails.append("An elevated level crossing cannot reserve its perpendicular span")
		return
	for p: Array in upper["centerline"]:
		if absf(MapLayoutCanonical.float_value(p[1])-1.8)>.00001:
			fails.append("Crossing repair drops an elevated court back to ground zero")
			break
