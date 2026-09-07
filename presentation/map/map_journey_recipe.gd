extends RefCounted
## Production woodland inputs: actual imported kit, physical space and local view.
const VERSION: String = "woodland-journey-v5"
const Fingerprints: JSON = preload("res://assets/art/map-journey/runtime-fingerprints.json")
const Cache = preload("res://presentation/map/map_journey_cache.gd")
const Registry = preload("res://presentation/map/map_journey_camera_registry.gd")
const Assets = preload("res://presentation/map/map_journey_assets.gd")
const Kit = preload("res://presentation/map/landscape/kit.gd")
const Spatial = preload("res://presentation/map/map_spatial_profile.gd")
const Ordering = preload("res://presentation/map/map_spatial_ordering.gd")
const Spacing = preload("res://presentation/map/map_spatial_spacing.gd")
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
	var order: Dictionary = Ordering.generate(nodes,edges)
	if order.get("ok")!=true: return {"ok":false,"reason":"Cannot order the woodland graph","details":order}
	var road: Dictionary = quality["geometry"]["road_corridor"]
	var half: float = F.float_value(road["physical_half_width_m"])
	var radius: float = half+F.float_value(road["world_clearance_m"])
	var stub: float = minf(F.float_value(quality["calibration"]["shipping_touch_waystone"]["node_pair_half_extent_m"][0]),F.float_value(quality["geometry"]["branch_fanout"]["common_departure_max_m"]))
	var row_move: float = .6
	var lane_move: float = .8
	var jitter: float = .3
	var row_gap: float = (2*(stub+half+radius)+2*row_move*.94)/(1-2*jitter*.4)
	var lane_gap: float = (2*(half+radius)+2*lane_move*.94)/(1-2*jitter*.5)
	var rise: float = 2.45+.65
	var grade: float = .34
	var landing: float = 1.0
	var reserve: float = landing+half
	var flight: float = maxf(rise/grade,ceili(rise/.17)*.28)
	var crossing: float = (2*(flight+2*reserve)+8+2*stub+.01+2*row_move*.94)/(1-2*jitter*.4)
	var rows: Array = []
	for i: int in range(15):
		rows.append({"station_m":-36+i*row_gap,"height_m":0.0,"centre_z_m":0.0,"lane_spacing_m":lane_gap,"region":"woodland"})
	var profile: Dictionary = {"schema_version":1,"id":VERSION,"act":0,
		"bounds_xz_m":[-48.0,-3*lane_gap-12,-36+14*row_gap+16,3*lane_gap+12],
		"ordering_version":"layered-order-dp-v1","lane_assignments":order["assignments"],
		"spacing_version":"physical-reservations-v1","jitter_scale":jitter,"rows":rows,
		"passage":{"headroom_m":2.45,"deck_depth_m":.65,"maximum_grade":grade,"landing_m":landing,
			"crossing_lane_spacing_m":10.0,"crossing_interval_m":crossing}}
	quality["spatial_profile"] = Spacing.apply(profile,nodes,edges)["profile"]
	quality["geometry"]["row_lane_envelope"]["row_half_extent_m"] = row_move
	quality["geometry"]["row_lane_envelope"]["lane_half_extent_m"] = lane_move
	var errors: Array[String] = Spatial.validate(quality,0)
	if not errors.is_empty(): return {"ok":false,"reason":"Invalid woodland spatial recipe","details":errors}
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
