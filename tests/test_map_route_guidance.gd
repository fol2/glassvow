extends RefCounted
const Guide = preload("res://tools/map_workshop/common/route_guidance.gd")
static func run(fails: Array[String]) -> void:
	var data: Dictionary = {"current":"B","reachable":["C","D"],"history":["A","B"],"edges":{
		"ab":{"from":"A","to":"B"},"bc":{"from":"B","to":"C"},"bd":{"from":"B","to":"D"},"ce":{"from":"C","to":"E"}}}
	var before: String = JSON.stringify(data)
	if Guide.classify(data,"ab")!="visited" or Guide.classify(data,"bc")!="available" or Guide.classify(data,"ce")!="future":
		fails.append("Guidance confused visited, available and future graph edges")
	if Guide.selection(data,"C")!="bc" or Guide.selection(data,"D")!="bd":
		fails.append("Guidance did not resolve the exact chosen outgoing edge")
	for unavailable: String in ["A","B","E","missing"]:
		if not Guide.selection(data,unavailable).is_empty(): fails.append("Guidance promoted an unavailable destination: "+unavailable)
	if JSON.stringify(data)!=before: fails.append("Guidance mutated its snapshot")
