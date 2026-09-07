extends RefCounted
const Envelope = preload("res://presentation/map/chapters/common/precinct_envelope.gd")
static func run(fails: Array[String]) -> void:
	var regions: Array[Dictionary] = [{"west":0.0,"east":10.0,"near":-10.0,"far":10.0},
		{"west":10.0,"east":20.0,"near":-5.0,"far":5.0}]
	if Envelope.supports(AABB(Vector3(9,0,6),Vector3(2,4,2)),regions):
		fails.append("support: accepted overhang across a narrowing court")
	if not Envelope.supports(AABB(Vector3(9,0,0),Vector3(2,4,2)),regions):
		fails.append("support: rejected footprint fully supported across court seam")
	if Envelope.supports(AABB(Vector3(-1,0,0),Vector3(2,4,2)),regions):
		fails.append("support: accepted footprint beyond first court")
