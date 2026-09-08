extends RefCounted
@warning_ignore_start("unsafe_call_argument")
const Ordering = preload("res://presentation/map/map_spatial_ordering.gd")
static func run(fails: Array[String]) -> void:
	var nodes: Array = [{"id":"a","row":0,"col":0},{"id":"b","row":0,"col":1},
		{"id":"c","row":1,"col":0},{"id":"d","row":1,"col":1}]
	var edges: Array = [{"from":"a","to":"d"},{"from":"b","to":"c"}]
	var before: String = MapLayoutCanonical.digest([nodes, edges])
	var result: Dictionary = Ordering.generate(nodes, edges)
	if result.get("ok") != true or result.get("minimum_layered_crossings") != 0:
		fails.append("test_map_spatial_ordering: solvable crossing remains")
	if before != MapLayoutCanonical.digest([nodes, edges]):
		fails.append("test_map_spatial_ordering: game graph mutated")
	if result != Ordering.generate(nodes, edges):
		fails.append("test_map_spatial_ordering: ordering is not deterministic")
	var assigned: Dictionary = result["assignments"]
	if assigned["a"] == assigned["b"] or assigned["c"] == assigned["d"]:
		fails.append("test_map_spatial_ordering: row slots overlap")
	edges.append({"from":"missing","to":"c"})
	if Ordering.generate(nodes, edges).get("ok") == true:
		fails.append("test_map_spatial_ordering: missing endpoint accepted")
