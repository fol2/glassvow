extends RefCounted
const Registry = preload("res://presentation/map/map_journey_camera_registry.gd")
const Contract = preload("res://presentation/map/map_journey_camera_contract.gd")
static func run(fails: Array[String]) -> void:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/map-quality-v2.json"))
	var before: String = MapLayoutCanonical.digest(base)
	var quality: Dictionary = Registry.quality(base)
	var nodes: Array = [
		{"id":"A","type":"monster","row":0,"col":0,"jitter":[0.0,0.0]},
		{"id":"B","type":"monster","row":1,"col":0,"jitter":[0.0,0.0]},
		{"id":"C","type":"monster","row":1,"col":1,"jitter":[0.0,0.0]}]
	var edges: Array = [{"id":MapLayoutInput.edge_id("A","B"),"from":"A","to":"B"}]
	var cameras: Dictionary = Registry.build(nodes,quality,edges)
	_check(fails,MapLayoutCanonical.digest(base)==before,"base quality mutated")
	_check(fails,str(cameras["digest"])==str(Registry.build(nodes,quality,edges)["digest"]),"camera replay differs")
	var anchors: Dictionary = {"A":[0.0,1.0,0.0],"B":[5.0,2.0,1.0],"C":[5.0,2.0,1.0]}
	var rules: Array = quality["hard"]
	var hard: Dictionary = MapQualityEvaluator._index(rules)
	for profile: Dictionary in cameras["profiles"]:
		if str(profile["focus"])!="A": continue
		var resolved: Dictionary = Registry.resolve(profile,anchors)
		var stage: Vector2 = MapQualityEvaluator._v2(profile["stage"])
		var points: PackedVector3Array = [Vector3(0,1,0),Vector3(5,2,1)]
		var pose: Dictionary = Contract.resolve(points,stage)
		for point: Vector3 in points:
			_check(fails,MapQualityEvaluator._project(point,resolved).distance_to(Contract.screen_point(point,pose,stage))<.001,"compiler/runtime projection differs")
		var checked: Dictionary = MapQualityEvaluator._selection_screen(profile,nodes,anchors,{},quality,hard,.25)
		var violations: Array = checked["violations"]
		_check(fails,violations.is_empty(),"an unrelated hidden stop blocks a local decision: "+str(violations))
		var joined: Dictionary = profile.duplicate(true)
		joined["members"].append("C")
		checked = MapQualityEvaluator._selection_screen(joined,nodes,anchors,{},quality,hard,.25)
		violations = checked["violations"]
		_check(fails,not violations.is_empty(),"coincident simultaneous choices passed")

static func _check(fails: Array[String], ok: bool, message: String) -> void:
	if not ok: fails.append("journey camera registry: "+message)
