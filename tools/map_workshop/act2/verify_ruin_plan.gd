extends SceneTree
## Exact sample contract: one owner per ruin; the largest belongs to the boss.
func _initialize() -> void:
	var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/studies/camera-composition/act2-seed717.json"))
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/studies/act2-step3/profile-library-waterline.json"))
	var before: String = JSON.stringify(sample)
	var routes: Dictionary = {}
	var anchors: Dictionary = {}
	for key: String in profile["routes"]:
		var points: PackedVector3Array = []
		for raw: Array in profile["routes"][key]:
			points.append(preload("res://presentation/map/landscape/mesh_tools.gd").v3(raw))
		routes[key] = points
		anchors[sample["edges"][key]["from"]] = points[0]+Vector3.UP*.022
		anchors[sample["edges"][key]["to"]] = points[-1]+Vector3.UP*.022
	var plan: RefCounted = preload("res://tools/map_workshop/act2/ruin_plan.gd").new()
	plan.build(sample,anchors,routes)
	if not plan.failure.is_empty():
		push_error(plan.failure)
		quit(1)
		return
	assert(plan.sites.size()==8)
	var owners: Dictionary = {}
	var evidence: Array[Dictionary] = []
	for site: Dictionary in plan.sites:
		var id: String = site["node"]
		assert(anchors.has(id) and not owners.has(id))
		owners[id] = true
		var doorway: Vector3 = site["door"]
		if site["kind"]!="library":
			assert(doorway.y<1.18 and site["centre"].y==0.0)
		if site["kind"]=="library":
			var boss: bool = false
			for node: Dictionary in sample["nodes"]:
				boss = boss or (node["id"]==id and node["type"]=="boss")
			assert(boss)
		evidence.append({"ruin":site["ordinal"],"kind":site["kind"],"node":id,"centre":str(site["centre"]),"door":str(site["door"])})
	assert(before==JSON.stringify(sample))
	print("PASS: eight single-node ruins, seven submerged decorative arrivals, largest assigned to generated boss, unchanged source graph ",JSON.stringify(evidence))
	quit()
