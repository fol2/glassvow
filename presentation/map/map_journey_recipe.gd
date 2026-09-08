extends RefCounted
## Production woodland inputs: actual imported kit, physical space and local view.
const VERSION: String = "woodland-journey-v9"
const Fingerprints: JSON = preload("res://assets/art/map-journey/runtime-fingerprints.json")
const Cache = preload("res://presentation/map/map_journey_cache.gd")
const Registry = preload("res://presentation/map/map_journey_camera_registry.gd")
const Assets = preload("res://presentation/map/map_journey_assets.gd")
const Kit = preload("res://presentation/map/landscape/kit.gd")
const Spatial = preload("res://presentation/map/map_spatial_profile.gd")
const F = preload("res://domain/map_layout/map_layout_canonical.gd")

static func build(nodes: Array, edges: Array, base: Dictionary) -> Dictionary:
	var quality: Dictionary = Registry.quality(base)
	quality["routing_strategy"] = "grade-priority-v1"
	var kinds: Array[String] = []
	kinds.assign(Kit.PROFILES.keys())
	kinds.sort()
	var library: Assets = Assets.new(kinds)
	if not library.failure.is_empty(): return {"ok":false,"reason":library.failure}
	var key: String = F.digest({"recipe":VERSION,"surface":preload("res://presentation/map/map_journey_realisation.gd").VERSION,
		"cache":Cache.VERSION,"engine":Engine.get_version_info()["string"],"app":ProjectSettings.get_setting("application/config/version"),
		"nodes":nodes,"edges":edges,"quality":quality,"assets":library.digest,"appearance":Fingerprints.data})
	var stored: Cache = Cache.read(key) as Cache
	if stored != null and not stored.quality.is_empty() and not stored.heroes.is_empty():
		return {"ok":true,"quality":stored.quality,"assets":library.bundle(),"heroes":stored.heroes,"version":VERSION,"cache":stored}
	var spatial: Dictionary = preload("res://presentation/map/map_journey_spatial.gd").configure(nodes,edges,quality,0,VERSION,"woodland")
	if spatial.get("ok")!=true: return spatial
	var boss: Dictionary = {}
	for node: Dictionary in nodes:
		if str(node["type"])=="boss": boss = node
	if boss.is_empty(): return {"ok":false,"reason":"Woodland graph has no terminus"}
	# A larger memorial in the final grove uses the approved woodland kit.
	# The early arch remains a route-dependent placement in the surface stage.
	var at: Vector3 = Spatial.anchor(boss,quality)+Vector3(8,0,0)
	var scale_value: float = 1.6
	var memorial: Dictionary = library.profiles["memorial"]
	var shape: PackedVector2Array = library.registry.transformed_footprint(memorial,at,0.0,Vector3.ONE*scale_value)
	var polygon: Array = []
	for point: Vector2 in shape: polygon.append([point.x,point.y])
	var heroes: Dictionary = {"schema_version":1,"anchors":{"terminus":{
		"asset_id":"memorial","profile_id":"memorial","position":[at.x,at.y,at.z],"yaw_radians":0.0,
		"scale":[scale_value,scale_value,scale_value]}},"protected_zones":{"terminus-zone":{"role":"terminus","polygon":polygon}}}
	stored = Cache.new()
	stored.cache_key = key
	stored.quality = quality
	stored.heroes = heroes
	return {"ok":true,"quality":quality,"assets":library.bundle(),"heroes":heroes,"version":VERSION,"cache":stored}
