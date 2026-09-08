extends RefCounted
const Audit = preload("res://tools/map_workshop/common/threshold_mesh_audit.gd")
static func run(fails: Array[String]) -> void:
	var triangle: Dictionary = {"a":Vector3(0,1,0),"b":Vector3(2,1,0),
		"c":Vector3(0,1,2),"bounds":Rect2(0,0,2,2)}
	if not is_finite(Audit._height(Vector3(-.00005,1,.5),triangle,.0001)):
		fails.append("mesh probe: measured contour quantisation not resolved")
	if is_finite(Audit._height(Vector3(-.002,1,.5),triangle,.0001)):
		fails.append("mesh probe: real two-millimetre gap hidden by edge tolerance")
