extends RefCounted
## Generated city corridors reserve the measured library, not a woodland proxy.
const VERSION: String = "drowned-city-journey-v1"
const Library = preload("res://presentation/map/chapters/act2/library.gd")
const Spatial = preload("res://presentation/map/map_spatial_profile.gd")
var measured: Dictionary = {}

func build(nodes: Array, edges: Array, base: Dictionary) -> Dictionary:
	var quality: Dictionary = preload("res://presentation/map/map_journey_camera_registry.gd").quality(base)
	quality["routing_strategy"]="grade-priority-v1"
	var spatial: Dictionary = preload("res://presentation/map/map_journey_spatial.gd").configure(nodes,edges,quality,1,VERSION,"drowned-city")
	if spatial.get("ok")!=true: return spatial
	if measured.is_empty():
		var library: Library = Library.new()
		library.connected_forecourt=true
		library.build()
		measured=preload("res://presentation/map/map_procedural_assets.gd").measure("drowned-library",library,"res://presentation/map/chapters/act2/library.gd",1)
		library.free()
	if measured.is_empty(): return {"ok":false,"reason":"Cannot measure the drowned library"}
	var boss: Dictionary = {}
	for node: Dictionary in nodes:
		if str(node["type"])=="boss": boss=node
	if boss.is_empty(): return {"ok":false,"reason":"The drowned city requires its generated boss"}
	var at: Vector3 = Spatial.anchor(boss,quality)+Vector3(18,0,0)
	var registry: MapAssetProfiles = measured["registry"]
	var profile: Dictionary = measured["profile"]
	var polygon: Array = []
	for p: Vector2 in registry.transformed_footprint(profile,at,-PI*.5,Vector3.ONE): polygon.append([p.x,p.y])
	var heroes: Dictionary = {"schema_version":1,"anchors":{"terminus":{
		"asset_id":"drowned-library","profile_id":"drowned-library","position":[at.x,at.y,at.z],"yaw_radians":-PI*.5,"scale":[1.0,1.0,1.0]}},
		"protected_zones":{"terminus-zone":{"role":"terminus","polygon":polygon}}}
	var profiles: Array[Dictionary] = [profile]
	return {"ok":true,"quality":quality,"assets":{"profiles":{"drowned-library":profile},"digest":registry.digest(profiles)},"heroes":heroes,"version":VERSION}
