extends RefCounted
class EmptyPlan extends RefCounted:
	var sites: Array = []
	var failure: String = ""
	func build(_sample: Dictionary,_anchors: Dictionary,_routes: Dictionary) -> void:
		pass
static func run(fails: Array[String]) -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/map_coping_fork.json"))
	var routes: Node3D = preload("res://presentation/map/chapters/act2/causeways.gd").new()
	routes.ruin_plan=EmptyPlan.new()
	routes.height_profile=preload("res://presentation/map/chapters/act2/generated_profile.gd").new()
	routes.build(source)
	var report: Dictionary = preload("res://tools/map_workshop/act2/bridge_walkway_audit.gd").measure(routes)
	if report["body_samples"]<1000 or report["decoration_hits"]!=0:
		fails.append("A narrow fork's coping enters the actual walking corridor: "+str(report["decoration_hits"]))
	routes.free()
