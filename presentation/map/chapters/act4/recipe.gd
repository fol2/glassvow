extends RefCounted
## The generated five-node final procession retains the approved void composition.
const VERSION: String = "mirrored-procession-journey-v1"
const Cache = preload("res://presentation/map/map_journey_cache.gd")
const Kit = preload("res://presentation/map/chapters/act4/kit.gd")
const Spatial = preload("res://presentation/map/map_spatial_profile.gd")
func build(nodes: Array,edges: Array,base: Dictionary) -> Dictionary:
	var quality: Dictionary = preload("res://presentation/map/map_journey_camera_registry.gd").quality(base)
	var approved: Dictionary = preload("res://presentation/map/chapters/act4/spatial-recipe.json").data
	quality["spatial_profile"]=approved["spatial_profile"].duplicate(true)
	var errors: Array[String] = Spatial.validate(quality,3)
	if not errors.is_empty(): return {"ok":false,"reason":"Invalid procession profile","details":errors}
	var key: String = MapLayoutCanonical.digest({"recipe":VERSION,"cache":Cache.VERSION,"surface":"mirrored-procession-surface-v2",
		"engine":Engine.get_version_info()["string"],"app":ProjectSettings.get_setting("application/config/version"),
		"nodes":nodes,"edges":edges,"quality":quality})
	var stored: Cache = Cache.read(key) as Cache
	if stored!=null and not stored.recipe_assets.is_empty():
		return {"ok":true,"quality":stored.quality,"assets":stored.recipe_assets,"heroes":stored.heroes,"version":VERSION,"cache":stored}
	var profiles: Dictionary = {}
	var heroes: Dictionary = {"schema_version":1,"anchors":{},"protected_zones":{}}
	var registry: MapAssetProfiles
	for role: String in approved["hero_assets"]:
		var specification: Dictionary = approved["hero_assets"][role]
		var label: String = str(specification["path"]).get_file().get_basename()
		var packed: PackedScene = Kit.SOURCES[label]
		var model: Node3D = packed.instantiate()
		var measured: Dictionary = preload("res://presentation/map/map_procedural_assets.gd").measure(label,model,"res://assets/map/act4/"+label+".glb",3)
		model.free()
		if measured.is_empty(): return {"ok":false,"reason":"Cannot measure procession model: "+label}
		registry=measured["registry"]
		var profile: Dictionary = measured["profile"]
		profiles[label]=profile
		var bound: Dictionary = {}
		for node: Dictionary in nodes:
			if node["id"]==specification["node_id"]: bound=node
		if bound.is_empty(): return {"ok":false,"reason":"Missing generated procession hero node"}
		var at: Vector3 = Spatial.anchor(bound,quality)+MapLandscape.v3(specification["offset"])
		var polygon: Array = []
		for p: Vector2 in registry.transformed_footprint(profile,at,0,Vector3.ONE): polygon.append([p.x,p.y])
		heroes["anchors"][role]={"asset_id":label,"profile_id":label,"position":[at.x,at.y,at.z],"yaw_radians":0.0,"scale":[1.0,1.0,1.0]}
		heroes["protected_zones"][role+"-zone"]={"role":role,"polygon":polygon}
	var values: Array[Dictionary] = []
	for id: String in MapLayoutCanonical.sorted_keys(profiles): values.append(profiles[id])
	stored=Cache.new()
	stored.cache_key=key
	stored.quality=quality
	stored.heroes=heroes
	stored.recipe_assets={"profiles":profiles,"digest":registry.digest(values)}
	return {"ok":true,"quality":quality,"assets":stored.recipe_assets,"heroes":heroes,"version":VERSION,"cache":stored}
