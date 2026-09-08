extends RefCounted
const Groups = preload("res://tools/map_workshop/common/overview_groups.gd")
static func run(fails: Array[String]) -> void:
	var points: Array[Dictionary] = []
	for index: int in range(65):
		points.append({"id":str(index),"at":Vector2((index%15)*24,(index/15)*27)})
	var groups: Array[Dictionary] = Groups.build(points)
	var seen: Dictionary = {}
	for i: int in range(groups.size()):
		var centre: Vector2 = groups[i]["at"]
		for id: String in groups[i]["ids"]:
			if seen.has(id):
				fails.append("overview: duplicate node")
			seen[id] = true
		for j: int in range(i+1,groups.size()):
			var other: Vector2 = groups[j]["at"]
			if Rect2(centre-Vector2(22,22),Vector2(44,44)).intersects(Rect2(other-Vector2(22,22),Vector2(44,44))):
				fails.append("overview: overlapping 44 px targets")
	if seen.size() != points.size():
		fails.append("overview: lost node IDs")
	points.reverse()
	if Groups.build(points) != groups:
		fails.append("overview: depends on input dictionary order")
