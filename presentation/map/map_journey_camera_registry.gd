extends RefCounted
## Only the current stop and its successors are selectable together. Overview
## chooses an inspection area; it never commits travel and is not a tiny menu.
const Contract = preload("res://presentation/map/map_journey_camera_contract.gd")
const Spatial = preload("res://presentation/map/map_spatial_profile.gd")

static func enabled(quality: Dictionary) -> bool:
	return quality.get("journey_camera","")==Contract.VERSION

static func quality(base: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	out["journey_camera"] = Contract.VERSION
	return out

static func build(nodes: Array, quality_data: Dictionary, edges: Array) -> Dictionary:
	var groups: Dictionary = {}
	var anchors: Dictionary = {}
	for node: Dictionary in nodes:
		var id: String = str(node["id"])
		groups[id] = [id]
		var at: Vector3 = Spatial.anchor(node,quality_data)
		anchors[id] = [at.x,at.y,at.z]
	for edge: Dictionary in edges:
		groups[str(edge["from"])].append(str(edge["to"]))
	var profiles: Array = []
	for id: String in MapLayoutCanonical.sorted_keys(groups):
		var members: Array = groups[id]
		members.sort()
		for shape: StringName in StageShape.SHIPPING:
			var stage: Vector2i = StageShape.REFERENCES[shape]
			var row: Dictionary = {"id":str(shape)+"/journey/"+id,"shape":str(shape),
				"stage":[stage.x,stage.y],"zoom":12.0,"tilt":-Contract.PITCH,"height":Contract.HEIGHT,
				"pose":[0.0,0.0],"kind":"journey","focus":id,"members":members.duplicate(),
				"flex_cap":StageShape.FLEX_CAP,"ink_gap":Contract.INK_GAP_PX,"ink_radius":Contract.INK_RADIUS_PX,"touch_size":Contract.touch_size(Vector2(stage))}
			row = resolve(row,anchors)
			# Feasibility is candidate-dependent. Record the pose proposal without
			# deleting candidates merely because the authored arrangement fails.
			row["digest"] = MapLayoutCanonical.digest(row)
			profiles.append(row)
	return {"schema_version":1,"version":Contract.VERSION,"profiles":profiles,"errors":[],"digest":MapLayoutCanonical.digest(profiles)}

static func resolve(profile: Dictionary, anchors: Dictionary) -> Dictionary:
	var out: Dictionary = profile.duplicate(true)
	var points: PackedVector3Array = []
	for id: String in profile["members"]:
		if anchors.has(id): points.append(MapLandscape.v3(anchors[id]))
	if points.is_empty():
		out["journey_empty"] = true
		return out
	var dimensions: Array = profile["stage"]
	var stage: Vector2 = Vector2(float(str(dimensions[0])),float(str(dimensions[1])))
	var checked: Dictionary = Contract.resolve(points,stage)
	out["journey_feasible"] = checked["ok"]
	# Keep measuring the actual fit even if separation is impossible. Failing
	# ink/touch metrics then carry named entities into the existing solver.
	if not checked["ok"]: checked = Contract.resolve(points,stage,true)
	if not checked["ok"]:
		out["journey_empty"] = true
		return out
	var at: Vector3 = checked["position"]
	out["pose"] = [at.x,at.z]
	out["zoom"] = checked["zoom"]
	return out

static func visible(nodes: Array, profile: Dictionary) -> Array:
	var out: Array = []
	for node: Dictionary in nodes:
		if str(node["id"]) in profile["members"]: out.append(node)
	return out
