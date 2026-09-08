extends RefCounted
const Threshold = preload("res://presentation/map/chapters/common/precinct_threshold.gd")
static func run(fails: Array[String]) -> void:
	var routes: Dictionary = {"a":{"corridor_width":2.5,"centerline":[[-10,.9,-4],[10,.9,4]]}}
	var result: Dictionary = Threshold.plan(routes,0,-20,20)
	var openings: Array = result["openings"]
	if openings.size() != 1:
		fails.append("threshold: transverse road opening missing")
		return
	var opening: Dictionary = openings[0]
	if MapLayoutCanonical.float_value(opening["near"]) > -2.63 or MapLayoutCanonical.float_value(opening["far"]) < 2.63:
		fails.append("threshold: angled route swept width truncated")
	if MapLayoutCanonical.float_value(opening["spring"]) < 3.899:
		fails.append("threshold: raised approach lacks headroom")
	if Threshold.plan(routes,0,-1,1).get("ok") == true:
		fails.append("threshold: route outside threshold domain accepted")
