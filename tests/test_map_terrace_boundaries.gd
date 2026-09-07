extends RefCounted
const Boundaries = preload("res://presentation/map/chapters/common/terrace_boundaries.gd")
static func run(fails: Array[String]) -> void:
	var nodes: Array = [{"id":"a","row":9},{"id":"b","row":9},{"id":"c","row":10},{"id":"d","row":10}]
	var edges: Array = [{"from":"a","to":"d"},{"from":"b","to":"c"}]
	var assignments: Dictionary = {"a":0,"b":1,"c":0,"d":1}
	var targets: Array[int] = [3,9,12]
	var result: Dictionary = Boundaries.resolve(nodes,edges,assignments,targets,15)
	if result.get("ok")!=true or result["cuts"]!=[3,8,12] or result["displacement_rows"]!=1:
		fails.append("terrace boundaries: did not move only the crossed boundary to its nearest legal cut")
	var clear: Dictionary = Boundaries.resolve(nodes,[],assignments,targets,15)
	if clear.get("ok")!=true or clear["cuts"]!=[3,9,12]:
		fails.append("terrace boundaries: changed an already compatible composition")
