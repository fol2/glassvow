extends RefCounted
## An opt-in priority cannot silently drop the complete ground fallback.
const Fixtures = preload("res://tests/test_map_layout_compiler.gd")
static func run(fails: Array[String]) -> void:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/map-quality-v2.json"))
	var assets: Dictionary = Fixtures._assets()
	var nodes: Array = [Fixtures._node("A",2,3),Fixtures._node("B",3,3)]
	var edges: Array = [Fixtures._edge("A","B")]
	var source: MapLayoutInput = Fixtures._input(nodes,edges,717,0,Fixtures._hero(),base,assets)
	var old: Dictionary = MapLayoutCompiler.compile(source,base,assets)
	if old["status"]!=MapLayoutCompiler.COMPILED:
		fails.append("routing strategy: baseline chain failed")
		return
	var quality: Dictionary = base.duplicate(true)
	quality["routing_strategy"] = "grade-priority-v1"
	var input: MapLayoutInput = Fixtures._input(nodes,edges,717,0,Fixtures._hero(),quality,assets)
	var compiled: Dictionary = MapLayoutCompiler.compile(input,quality,assets)
	if compiled["status"]!=MapLayoutCompiler.COMPILED:
		fails.append("routing strategy: rejected grade attempt lost the valid ground fallback")
		return
	var actual_result: MapLayoutResult = compiled["result"]
	var old_result: MapLayoutResult = old["result"]
	var actual: Dictionary = actual_result.identity_dict()
	var expected: Dictionary = old_result.identity_dict()
	if actual["node_anchors"]!=expected["node_anchors"] or actual["edges"]!=expected["edges"]:
		fails.append("routing strategy: fallback changed the ground geometry")
	var diagnostics: Dictionary = compiled["diagnostics"]
	if not diagnostics.has("priority_attempts") or diagnostics.has("ground_exhaustion"):
		fails.append("routing strategy: receipt hides the attempt or invents ground exhaustion")
	if diagnostics.get("selected_strategy")!="grade-priority-v1":
		fails.append("routing strategy: valid flat priority candidate discarded before quality evaluation")
	quality["routing_strategy"] = "unknown"
	input = Fixtures._input(nodes,edges,717,0,Fixtures._hero(),quality,assets)
	compiled = MapLayoutCompiler.compile(input,quality,assets)
	if compiled["status"]==MapLayoutCompiler.COMPILED or compiled["failure"].get("kind")!="routing_strategy":
		fails.append("routing strategy: unknown policy did not fail closed")
