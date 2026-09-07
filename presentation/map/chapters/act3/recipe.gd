extends RefCounted
## The approved four court levels bind to the live graph and measured hall.
const VERSION: String = "obsidian-court-journey-v2"
const Cache = preload("res://presentation/map/map_journey_cache.gd")
const Kit = preload("res://presentation/map/chapters/act3/kit.gd")
const Spatial = preload("res://presentation/map/map_spatial_profile.gd")
var measured: Dictionary = {}

func build(nodes: Array, edges: Array, base: Dictionary) -> Dictionary:
	var quality: Dictionary = preload("res://presentation/map/map_journey_camera_registry.gd").quality(base)
	quality["routing_strategy"]="grade-priority-v1"
	var key: String = MapLayoutCanonical.digest({"recipe":VERSION,"cache":Cache.VERSION,
		"surface":preload("res://presentation/map/chapters/act3/realisation.gd").VERSION,
		"engine":Engine.get_version_info()["string"],"app":ProjectSettings.get_setting("application/config/version"),
		"nodes":nodes,"edges":edges,"quality":quality})
	var stored: Cache = Cache.read(key) as Cache
	if stored!=null and not stored.quality.is_empty() and not stored.heroes.is_empty() and not stored.recipe_assets.is_empty():
		return {"ok":true,"quality":stored.quality,"assets":stored.recipe_assets,"heroes":stored.heroes,"version":VERSION,"cache":stored}
	var configured: Dictionary = preload("res://presentation/map/map_journey_spatial.gd").configure(nodes,edges,quality,2,VERSION,"obsidian-court")
	if configured.get("ok")!=true: return configured
	var spatial: Dictionary = quality["spatial_profile"]
	var approved: Dictionary = preload("res://presentation/map/chapters/act3/spatial-profile.json").data
	for index: int in range(spatial["rows"].size()):
		spatial["rows"][index]["height_m"]=approved["rows"][index]["height_m"]
		spatial["rows"][index]["region"]=approved["rows"][index]["region"]
	spatial["stair_version"]="transverse-court-v1"
	# Court stairs retain their approved physical grade; shared spacing remains conservative.
	spatial["passage"]["maximum_grade"]=approved["passage"]["maximum_grade"]
	quality["spatial_profile"]=preload("res://presentation/map/map_spatial_spacing.gd").apply(spatial,nodes,edges)["profile"]
	var errors: Array[String] = Spatial.validate(quality,2)
	if not errors.is_empty(): return {"ok":false,"reason":"Invalid court profile","details":errors}
	if measured.is_empty():
		var packed: PackedScene = Kit.SOURCES["obsidian-great-hall"]
		var hall: Node3D = packed.instantiate()
		measured=preload("res://presentation/map/map_procedural_assets.gd").measure("obsidian-great-hall",hall,"res://assets/map/act3/obsidian-great-hall.glb",2)
		hall.free()
	if measured.is_empty(): return {"ok":false,"reason":"Cannot measure the sovereign hall"}
	var boss: Dictionary = {}
	for node: Dictionary in nodes:
		if str(node["type"])=="boss": boss=node
	if boss.is_empty(): return {"ok":false,"reason":"The court requires its generated boss"}
	var at: Vector3 = Spatial.anchor(boss,quality)+Vector3(18,0,0)
	var registry: MapAssetProfiles = measured["registry"]
	var profile: Dictionary = measured["profile"]
	var polygon: Array = []
	for p: Vector2 in registry.transformed_footprint(profile,at,-PI*.5,Vector3.ONE): polygon.append([p.x,p.y])
	var heroes: Dictionary = {"schema_version":1,"anchors":{"terminus":{
		"asset_id":"obsidian-great-hall","profile_id":"obsidian-great-hall","position":[at.x,at.y,at.z],"yaw_radians":-PI*.5,"scale":[1.0,1.0,1.0]}},
		"protected_zones":{"terminus-zone":{"role":"terminus","polygon":polygon}}}
	var profiles: Array[Dictionary] = [profile]
	stored=Cache.new()
	stored.cache_key=key
	stored.quality=quality
	stored.heroes=heroes
	stored.recipe_assets={"profiles":{"obsidian-great-hall":profile},"digest":registry.digest(profiles)}
	return {"ok":true,"quality":quality,"assets":stored.recipe_assets,"heroes":heroes,"version":VERSION,"cache":stored}
