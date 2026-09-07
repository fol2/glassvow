extends RefCounted
## Final surface stage of map compilation. Preserve topology and X/Z anchors,
## but record the real supported heights, paths and imported scenery transforms.
const VERSION: String = "woodland-surface-v2"
const Assets = preload("res://presentation/map/map_journey_assets.gd")
const Paths = preload("res://presentation/map/landscape/road_paths.gd")

static func finish(source: MapLayoutResult, landscape: Node3D) -> Dictionary:
	var part_started: int = Time.get_ticks_usec()
	var timings: Dictionary = {}
	var data: Dictionary = source.identity_dict()
	var kinds: Array[String] = []
	for item: Dictionary in landscape.kit.placed:
		var kind: String = item["kind"]
		if not kinds.has(kind): kinds.append(kind)
	kinds.sort()
	var bundle: Dictionary = landscape.asset_bundle
	if bundle.is_empty():
		var assets: Assets = Assets.new(kinds)
		if not assets.failure.is_empty(): return {"ok":false,"reason":assets.failure}
		bundle = assets.bundle()
	for kind: String in kinds:
		if not bundle["profiles"].has(kind): return {"ok":false,"reason":"Unqualified journey asset: "+kind}
	timings["inputs"]=(Time.get_ticks_usec()-part_started)/1000.0
	part_started=Time.get_ticks_usec()
	for id: String in data["node_anchors"]:
		var at: Vector3 = landscape.resolved_anchor(MapLandscape.v3(data["node_anchors"][id]))
		data["node_anchors"][id] = [at.x,at.y,at.z]
	for id: String in data["edges"]:
		var edge: Dictionary = data["edges"][id]
		var source_line: PackedVector3Array = []
		for raw: Array in edge["centerline"]: source_line.append(MapLandscape.v3(raw))
		var line: Array = []
		for point: Vector3 in Paths.sample(source_line):
			var at: Vector3 = landscape.terrain.present(point)
			line.append([at.x,at.y,at.z])
		line[0] = data["node_anchors"][edge["from"]].duplicate()
		line[-1] = data["node_anchors"][edge["to"]].duplicate()
		edge["centerline"] = line
	timings["routes"]=(Time.get_ticks_usec()-part_started)/1000.0
	part_started=Time.get_ticks_usec()
	data["hero_placements"] = {}
	data["scenery_instances"] = {}
	for i: int in range(landscape.kit.placed.size()):
		var item: Dictionary = landscape.kit.placed[i]
		var kind: String = item["kind"]
		var placed: Node3D = landscape.kit.placed_nodes[i]
		var at: Vector3 = placed.position
		var size: Vector3 = placed.transform.basis.get_scale()
		var row: Dictionary = {"asset_id":kind,"profile_id":kind,"transform":{
			"origin":[at.x,at.y,at.z],"scale":[size.x,size.y,size.z],"yaw_radians":placed.transform.basis.get_euler().y}}
		if placed.has_meta("hero_role"):
			data["hero_placements"][str(placed.get_meta("hero_role"))] = row
		elif kind == "amber-arch":
			data["hero_placements"]["woodland-gateway"] = row
		else:
			row["semantic_zone"] = "woodland-surround"
			data["scenery_instances"]["woodland-%04d"%i] = row
	# Upstream measurements qualify the source proposal. They cannot be carried
	# forward as if they measured the newly realised three-dimensional surface.
	timings["scenery"]=(Time.get_ticks_usec()-part_started)/1000.0
	part_started=Time.get_ticks_usec()
	var surface_anchors: Dictionary = data["node_anchors"]
	var surface_edges: Dictionary = data["edges"]
	var camera: Dictionary = preload("res://presentation/map/map_journey_camera_contract.gd").audit_surface(surface_anchors,surface_edges)
	if not camera["ok"]:
		return {"ok":false,"reason":"Surface camera cannot frame its legal choices: "+JSON.stringify(camera["failures"])}
	data["hard_measurements"] = {"journey_camera":camera}
	data["soft_scores"] = {}
	data["generator_version"] += "/"+VERSION
	timings["camera"]=(Time.get_ticks_usec()-part_started)/1000.0
	part_started=Time.get_ticks_usec()
	var result: MapLayoutResult = MapLayoutResult.create(data)
	timings["record"]=(Time.get_ticks_usec()-part_started)/1000.0
	return {"ok":result!=null,"reason":"Invalid realised surface record" if result==null else "",
		"result":result,"assets":bundle,"source_layout_digest":source.digest(),"version":VERSION,"timings_ms":timings}
