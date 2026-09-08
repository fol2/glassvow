extends RefCounted
const Openings = preload("res://presentation/map/chapters/common/court_landscape_openings.gd")
const Envelope = preload("res://presentation/map/chapters/common/precinct_envelope.gd")
static func run(fails: Array[String]) -> void:
	var holes: Array[Rect2] = [Rect2(3,2,4,6)]
	var pieces: Array[Rect2] = Openings.subtract(Rect2(0,0,10,10),holes)
	var area: float = 0
	for piece: Rect2 in pieces:
		area += piece.get_area()
		if piece.intersects(holes[0]):
			fails.append("landscape opening: foundation still covers opening")
	if not is_equal_approx(area,76.0):
		fails.append("landscape opening: lost or duplicated foundation area")
	var regions: Array[Dictionary] = [{"west":0.0,"east":10.0,"near":0.0,"far":10.0}]
	if Envelope.supports(AABB(Vector3(4,0,3),Vector3(1,3,1)),regions,holes):
		fails.append("landscape opening: unsupported building accepted")
	if not Envelope.supports(AABB(Vector3(0,0,0),Vector3(2,3,2)),regions,holes):
		fails.append("landscape opening: supported building rejected")
