extends RefCounted
const Union = preload("res://tools/map_workshop/common/walking_surface_union.gd")
static func run(fails: Array[String]) -> void:
	var merged: Dictionary = Union.resolve([_square(0,0,0),_square(1,1,0)])
	if absf(_area(merged)-7.0) > .0001:
		fails.append("walking union: overlapping squares must cover seven square metres once")
	var levels: Dictionary = Union.resolve([_square(0,0,0),_square(0,0,3)])
	if absf(_area(levels)-8.0) > .0001:
		fails.append("walking union: separate passage levels were removed")
	var duplicate: Dictionary = Union.resolve([_square(0,0,0),_square(0,0,0)])
	if absf(_area(duplicate)-4.0) > .0001:
		fails.append("walking union: duplicate surface retained")
static func _square(x: float,z: float,y: float) -> Dictionary:
	return {"ok":true,"tops":[PackedVector3Array([Vector3(x,y,z),Vector3(x+2,y,z),
		Vector3(x+2,y,z+2),Vector3(x,y,z+2)])],"walls":[],"risers":[]}
static func _area(plan: Dictionary) -> float:
	var area: float = 0.0
	for face: PackedVector3Array in plan["tops"]:
		area += (face[1]-face[0]).cross(face[2]-face[0]).length()*.5
	return area
