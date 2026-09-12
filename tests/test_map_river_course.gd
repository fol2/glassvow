extends RefCounted
const Course = preload("res://presentation/map/landscape/river_course.gd")
const River = preload("res://presentation/map/landscape/river.gd")
const Landform = preload("res://presentation/map/landscape/landform.gd")

static func run(fails: Array[String]) -> void:
	var bounds: Rect2 = Rect2(-48,-35,260,70)
	var empty: Array[Dictionary] = []
	if Course.choose(empty,bounds)["centre_x"]!=-5.0:
		fails.append("river course moved an unobstructed approved river")
	var cuts: Array[Dictionary] = [{"at":Vector2(-1.675261,-25.18247),"direction":Vector2(1,-.2).normalized()}]
	var chosen: Dictionary = Course.choose(cuts,bounds)
	if chosen["ok"]!=true or chosen!=Course.choose(cuts,bounds):
		fails.append("river course is unavailable or non-deterministic")
		return
	var centre: float = chosen["centre_x"]
	var form: Landform = Landform.new()
	form.river_centre_x=centre
	for z: float in [-30.0,-25.18247,0.0,30.0]:
		var x: float = River.centre(z,centre)
		if not River.contains(x,z,35,centre) or form.natural_height(x,z)>River.LEVEL:
			fails.append("river mesh and carved riverbed disagree")
	var at: Vector2 = cuts[0]["at"]
	if absf(at.x-River.centre(at.y,centre))<15:
		fails.append("river still occupies the retained dry underpass")
	if Course.choose(cuts,Rect2(-5,-35,10,70))["ok"]==true:
		fails.append("river course accepted a footprint with no safe corridor")
