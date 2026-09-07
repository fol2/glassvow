extends RefCounted
## Publish measured chapter contacts and model transforms after native assembly.
static func finish(source: MapLayoutResult, landscape: Node3D,version: String,zone: String) -> Dictionary:
	var data: Dictionary = source.identity_dict()
	for id: String in data["node_anchors"]:
		var p: Vector3 = landscape.resolved_anchor(MapLandscape.v3(data["node_anchors"][id]))
		data["node_anchors"][id]=[p.x,p.y,p.z]
	for edge: Dictionary in data["edges"].values():
		var raw: PackedVector3Array = []
		for p: Array in edge["centerline"]: raw.append(MapLandscape.v3(p))
		var points: Array = []
		for p: Vector3 in preload("res://presentation/map/landscape/road_paths.gd").sample(raw):
			var at: Vector3 = landscape.terrain.present(p)
			points.append([at.x,at.y,at.z])
		points[0]=data["node_anchors"][edge["from"]].duplicate()
		points[-1]=data["node_anchors"][edge["to"]].duplicate()
		edge["centerline"]=points
	data["hero_placements"]={}
	data["scenery_instances"]={}
	for measured: Dictionary in landscape.measured_placements:
		var item: Node3D = measured["node"]
		var pose: Transform3D = landscape.global_transform.affine_inverse()*item.global_transform
		var size: Vector3 = pose.basis.get_scale()
		var row: Dictionary = {"asset_id":measured["asset_id"],"profile_id":measured["asset_id"],"transform":{
			"origin":[pose.origin.x,pose.origin.y,pose.origin.z],"scale":[size.x,size.y,size.z],"yaw_radians":pose.basis.get_euler().y}}
		if measured["terminal"]: data["hero_placements"]["terminus"]=row
		else:
			row["semantic_zone"]=zone
			data["scenery_instances"][measured["id"]]=row
	var profiles: Dictionary = landscape.measured_profiles
	var values: Array[Dictionary] = []
	for id: String in MapLayoutCanonical.sorted_keys(profiles): values.append(profiles[id])
	var registry: MapAssetProfiles = landscape.profile_registry
	var assets: Dictionary = {"profiles":profiles,"digest":registry.digest(values)}
	var framing: Dictionary = preload("res://presentation/map/map_journey_framing.gd").terminals(data,assets)
	var anchors: Dictionary = data["node_anchors"]
	var edges: Dictionary = data["edges"]
	var camera: Dictionary = preload("res://presentation/map/map_journey_camera_contract.gd").audit_surface(anchors,edges,framing)
	if not camera["ok"]: return {"ok":false,"reason":"Chapter surface cannot frame legal choices: "+JSON.stringify(camera["failures"])}
	data["hard_measurements"]={"journey_camera":camera}
	data["soft_scores"]={}
	data["generator_version"]+="/"+version
	var result: MapLayoutResult = MapLayoutResult.create(data)
	return {"ok":result!=null,"reason":"Invalid chapter surface record" if result==null else "","result":result,"assets":assets,"framing":framing,"version":version}
