extends RefCounted
const Occupancy = preload("res://presentation/map/chapters/common/architectural_occupancy.gd")
static func run(fails: Array[String]) -> void:
	var box: AABB = AABB(Vector3(0,0,0),Vector3(2,5,2))
	var routes: Dictionary = {
		"cross":{"corridor_width":2.0,"centerline":[[-10,0,1],[10,0,1]]},
		"clear":{"corridor_width":2.0,"centerline":[[-10,0,5],[10,0,5]]},
		"near":{"corridor_width":2.0,"centerline":[[-10,0,-1],[10,0,-1]]}}
	var result: Array[String] = Occupancy.conflicts(box,routes,0.0)
	if result != ["cross","near"]:
		fails.append("occupancy: swept width, tangency or long-segment crossing missed")

	var first: AABB = AABB(Vector3.ZERO,Vector3.ONE)
	var second: AABB = AABB(Vector3(1,0,0),Vector3.ONE)
	if Occupancy.boxes_overlap(first,second):
		fails.append("occupancy: shared building boundary rejected")
	second.position.x = .85
	if not Occupancy.boxes_overlap(first,second):
		fails.append("occupancy: 15 cm building overlap missed")
