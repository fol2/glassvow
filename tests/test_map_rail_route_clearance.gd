extends RefCounted
static func run(fails: Array[String]) -> void:
	var rail: GDScript = preload("res://presentation/map/chapters/stone_bridge/edges.gd")
	if not rail._rail_obstructs(5.77,4.822,{}): fails.append("A raised approach can still hit the lower coping")
	if not rail._rail_obstructs(4.822,4.822,{}): fails.append("Shared landings retain a blocking rail")
	if rail._rail_obstructs(1.78,5.77,{}) or rail._rail_obstructs(5.77,1.78,{}):
		fails.append("Properly separated bridge crossings incorrectly lose their parapets")
