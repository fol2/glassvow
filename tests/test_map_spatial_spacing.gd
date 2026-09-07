extends RefCounted
const Spacing = preload("res://presentation/map/map_spatial_spacing.gd")
static func run(fails: Array[String]) -> void:
	var profile: Dictionary = {"lane_assignments":{"a":0,"b":1,"c":0,"d":1},
		"rows":[{"station_m":0.0,"height_m":0.0},{"station_m":10.5,"height_m":.9}],
		"bounds_xz_m":[-5,-20,20,20]}
	var nodes: Array = [{"id":"a","row":0},{"id":"b","row":0},{"id":"c","row":1},{"id":"d","row":1}]
	var edges: Array = [{"from":"a","to":"d"},{"from":"b","to":"c"}]
	var result: Dictionary = Spacing.apply(profile,nodes,edges)
	var changed: Dictionary = result["profile"]
	if MapLayoutCanonical.float_value(changed["rows"][1]["station_m"]) < 25:
		fails.append("spacing: unavoidable crossing lacks physical approach reservation")
	if MapLayoutCanonical.float_value(profile["rows"][1]["station_m"]) != 10.5:
		fails.append("spacing: mutated input recipe")
	if changed["lane_assignments"] != profile["lane_assignments"]:
		fails.append("spacing: changed generated lane assignments")

	var local: Dictionary = profile.duplicate(true)
	local["rows"].append({"station_m":21.0,"height_m":.9})
	for row: Dictionary in local["rows"]:
		row["lane_spacing_m"] = 8.0
		row["centre_z_m"] = 0.0
	local["passage"] = {"crossing_lane_spacing_m":20.0,"crossing_interval_m":45.0}
	var reserved: Dictionary = Spacing.apply(local,nodes,edges)["profile"]
	if reserved["rows"][0]["lane_positions_m"][1]-reserved["rows"][0]["lane_positions_m"][0] != 20.0 or reserved["rows"][1]["station_m"] != 45.0:
		fails.append("spacing: crossing reservation was not applied")
	if reserved["rows"][2]["lane_spacing_m"] != 8.0:
		fails.append("spacing: widened a row without a crossing")

	var positions: Array = reserved["rows"][0]["lane_positions_m"]
	if MapLayoutCanonical.float_value(positions[3])-MapLayoutCanonical.float_value(positions[2]) != 8.0:
		fails.append("spacing: expanded unrelated gap")
