extends SceneTree
## Immutable input for the bounded bridgehead-profile experiment.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/studies/camera-composition/act2-seed717.json"))
	var map: Node3D = preload("res://presentation/map/chapters/act2/causeways.gd").new()
	root.add_child(map)
	map.build(source)
	var routes: Dictionary = {}
	for key: String in map.sampled_routes:
		var points: PackedVector3Array = map.sampled_routes[key]
		var encoded: Array[Array] = []
		for p: Vector3 in points:
			encoded.append([p.x,p.y,p.z])
		var edge: Dictionary = source["edges"][key]
		var raised: bool = false
		for raw: Array in edge["centerline"]:
			raised = raised or float(str(raw[1]))>.3
		routes[key] = {"points":encoded,"from":edge["from"],"to":edge["to"],"raised":raised}
	var file: FileAccess = FileAccess.open("/tmp/act2-profile-input.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"routes":routes,"source_digest":source["layout_digest"]}))
	print("ACT_II_PROFILE_EXPORTED /tmp/act2-profile-input.json")
	quit()
