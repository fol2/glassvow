extends RefCounted
## Shared physical reservations. Chapter identity and materials remain caller-owned.
const Spatial = preload("res://presentation/map/map_spatial_profile.gd")
const Ordering = preload("res://presentation/map/map_spatial_ordering.gd")
const Spacing = preload("res://presentation/map/map_spatial_spacing.gd")
const F = preload("res://domain/map_layout/map_layout_canonical.gd")
static func configure(nodes: Array, edges: Array, quality: Dictionary, act: int, version: String, region: String) -> Dictionary:
	var order: Dictionary = Ordering.generate(nodes,edges)
	if order.get("ok")!=true: return {"ok":false,"reason":"Cannot order the chapter graph","details":order}
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
		rows.append({"station_m":-36+i*row_gap,"height_m":0.0,"centre_z_m":0.0,"lane_spacing_m":lane_gap,"region":region})
	var profile: Dictionary = {"schema_version":1,"id":version,"act":act,
		"bounds_xz_m":[-48.0,-3*lane_gap-12,-36+14*row_gap+16,3*lane_gap+12],
		"ordering_version":"layered-order-dp-v1","lane_assignments":order["assignments"],
		"spacing_version":"physical-reservations-v1","jitter_scale":jitter,"rows":rows,
		"passage":{"headroom_m":2.45,"deck_depth_m":.65,"maximum_grade":grade,"landing_m":landing,
			"crossing_lane_spacing_m":10.0,"crossing_interval_m":crossing}}
	quality["spatial_profile"] = Spacing.apply(profile,nodes,edges)["profile"]
	quality["geometry"]["row_lane_envelope"]["row_half_extent_m"] = row_move
	quality["geometry"]["row_lane_envelope"]["lane_half_extent_m"] = lane_move
	var errors: Array[String] = Spatial.validate(quality,act)
	if not errors.is_empty(): return {"ok":false,"reason":"Invalid chapter spatial recipe","details":errors}
	return {"ok":true,"quality":quality}
