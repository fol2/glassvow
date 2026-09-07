extends RefCounted
## Versioned, quality-digest-bound spatial authority. No global projection mutation.
## Absent profile deliberately executes the legacy arithmetic without interpolation.
const F = preload("res://domain/map_layout/map_layout_canonical.gd")

static func anchor(node: Dictionary, quality: Dictionary) -> Vector3:
	var jitter: Array = node["jitter"]
	if not quality.has("spatial_profile"):
		var stage: Dictionary = quality["calibration"]["stage_zoom_geometry"]
		var cell_parts: Array = stage["cell_m"]
		var origin_parts: Array = stage["origin_xz_m"]
		var cell: Vector2 = Vector2(F.float_value(cell_parts[0]), F.float_value(cell_parts[1]))
		var origin: Vector2 = Vector2(F.float_value(origin_parts[0]), F.float_value(origin_parts[1]))
		var offset: Vector2 = Vector2(F.float_value(jitter[0]), F.float_value(jitter[1]))
		return Vector3(origin.x + (F.float_value(node["row"]) + offset.y) * cell.x,
			0.0, origin.y + (F.float_value(node["col"]) + offset.x) * cell.y)
	var profile: Dictionary = quality["spatial_profile"]
	var jitter_scale: float = F.float_value(profile.get("jitter_scale", 1.0))
	var rows: Array = profile["rows"]
	var index: int = int(F.float_value(node["row"]))
	var assignments: Dictionary = profile.get("lane_assignments", {})
	var slot: float = F.float_value(assignments.get(str(node.get("id", "")), node["col"]))
	var row: Dictionary = rows[index]
	var next: Dictionary = rows[mini(index + 1, rows.size() - 1)]
	var previous: Dictionary = rows[maxi(index - 1, 0)]
	var dx: float = F.float_value(next["station_m"]) - F.float_value(row["station_m"])
	if index == rows.size() - 1 or F.float_value(jitter[1]) < 0.0:
		dx = F.float_value(row["station_m"]) - F.float_value(previous["station_m"])
		if index == 0:
			dx = F.float_value(next["station_m"]) - F.float_value(row["station_m"])
	var lateral: float = (slot-3.0)*F.float_value(row["lane_spacing_m"])
	if row.has("lane_positions_m"):
		lateral = F.float_value(row["lane_positions_m"][int(slot)])
	return Vector3(F.float_value(row["station_m"]) + F.float_value(jitter[1]) * jitter_scale * dx,
		F.float_value(row["height_m"]), F.float_value(row["centre_z_m"]) +
		lateral + F.float_value(jitter[0]) * jitter_scale * F.float_value(row["lane_spacing_m"]))

static func footprint(quality: Dictionary) -> Rect2:
	if not quality.has("spatial_profile"):
		return MapPinProjection.lattice_footprint()
	var bounds: Array = quality["spatial_profile"]["bounds_xz_m"]
	return Rect2(F.float_value(bounds[0]), F.float_value(bounds[1]),
		F.float_value(bounds[2]) - F.float_value(bounds[0]),
		F.float_value(bounds[3]) - F.float_value(bounds[1]))

static func validate(quality: Dictionary, act: int = -1) -> Array[String]:
	var errors: Array[String] = []
	if not quality.has("spatial_profile"):
		return errors
	var raw: Variant = quality["spatial_profile"]
	if not raw is Dictionary:
		return ["spatial_profile must be a Dictionary"]
	var profile: Dictionary = raw
	F.fields(profile, ["schema_version", "id", "act", "bounds_xz_m", "rows"], ["jitter_scale", "passage", "ordering_version", "lane_assignments", "spacing_version"],
		"spatial_profile", errors)
	F.validate(profile, "spatial_profile", errors)
	if not errors.is_empty():
		return errors
	if not F.number(profile["schema_version"]) or profile["schema_version"] != 1:
		errors.append("spatial_profile schema_version must be 1")
	if profile.has("jitter_scale") and (not F.number(profile["jitter_scale"]) or
			F.float_value(profile["jitter_scale"]) < 0.0 or F.float_value(profile["jitter_scale"]) > 1.0):
		errors.append("spatial_profile jitter_scale must be within 0..1")
	if profile.has("passage"):
		if not profile["passage"] is Dictionary:
			errors.append("spatial_profile passage must be a Dictionary")
		else:
			var passage: Dictionary = profile["passage"]
			F.fields(passage, ["headroom_m", "deck_depth_m", "maximum_grade", "landing_m"], ["crossing_lane_spacing_m", "crossing_interval_m"], "passage", errors)
			for field: String in ["headroom_m", "deck_depth_m", "maximum_grade", "landing_m"]:
				if not F.number(passage.get(field), true):
					errors.append("passage " + field + " must be finite and positive")
			for field: String in ["crossing_lane_spacing_m", "crossing_interval_m"]:
				if passage.has(field) and not F.number(passage[field], true):
					errors.append("passage " + field + " must be finite and positive")
			if errors.is_empty() and (F.float_value(passage["headroom_m"]) < 2.4 or
					F.float_value(passage["maximum_grade"]) > .17 / .28 or F.float_value(passage["landing_m"]) < .28):
				errors.append("passage must preserve headroom and stair rise/run limits")
	if profile.has("spacing_version") and profile["spacing_version"] != "physical-reservations-v1":
		errors.append("spatial_profile has unsupported spacing_version")
	if profile.has("ordering_version"):
		if profile["ordering_version"] != "layered-order-dp-v1":
			errors.append("unsupported spatial ordering version")
		if not profile.get("lane_assignments") is Dictionary:
			errors.append("spatial ordering requires generated lane assignments")
	if profile.has("lane_assignments"):
		if not profile["lane_assignments"] is Dictionary:
			errors.append("lane assignments must be a Dictionary")
		else:
			for id: String in profile["lane_assignments"]:
				var slot: Variant = profile["lane_assignments"][id]
				if not F.number(slot) or F.float_value(slot) < 0.0 or F.float_value(slot) > 6.0 or fmod(F.float_value(slot), 1.0) != 0:
					errors.append("lane assignment must be an integer within 0..6")
	if not F.nonempty(profile["id"]):
		errors.append("spatial_profile id must be non-empty")
	if not F.number(profile["act"]) or F.float_value(profile["act"]) < 0.0 or \
			F.float_value(profile["act"]) > 3.0 or fmod(F.float_value(profile["act"]), 1.0) != 0.0:
		errors.append("spatial_profile act must be 0..3")
	elif act >= 0 and profile["act"] != act:
		errors.append("spatial_profile act mismatch")
	if not F.vector(profile["bounds_xz_m"], 4):
		errors.append("spatial_profile bounds must be finite [min_x,min_z,max_x,max_z]")
	if not profile["rows"] is Array or profile["rows"].size() != 15:
		errors.append("spatial_profile requires 15 rows")
	if not errors.is_empty():
		return errors
	var bounds: Rect2 = footprint(quality)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		errors.append("spatial_profile bounds must have positive area")
	var previous: float = -INF
	var rows: Array = profile["rows"]
	for value: Variant in rows:
		if not value is Dictionary:
			errors.append("spatial_profile row must be a Dictionary")
			continue
		var row: Dictionary = value
		var row_errors: Array[String] = []
		F.fields(row, ["station_m", "height_m", "centre_z_m", "lane_spacing_m", "region"],
			["lane_positions_m"], "spatial_profile row", row_errors)
		for field: String in ["station_m", "height_m", "centre_z_m", "lane_spacing_m"]:
			if not F.number(row.get(field)):
				row_errors.append("spatial_profile row " + field + " must be finite")
		if row.has("lane_positions_m"):
			if not F.vector(row["lane_positions_m"],7):
				row_errors.append("lane positions must contain seven finite offsets")
			else:
				var positions: Array = row["lane_positions_m"]
				for index: int in range(1,7):
					if F.float_value(positions[index]) <= F.float_value(positions[index-1]):
						row_errors.append("lane positions must increase strictly")
				var centre: float = F.float_value(row["centre_z_m"])
				if centre+F.float_value(positions[0]) < bounds.position.y or centre+F.float_value(positions[-1]) > bounds.end.y:
					row_errors.append("lane positions lie outside bounds")
		if not F.nonempty(row.get("region")):
			row_errors.append("spatial_profile row region must be non-empty")
		errors.append_array(row_errors)
		if not row_errors.is_empty():
			continue
		var station: float = F.float_value(row["station_m"])
		var spacing: float = F.float_value(row["lane_spacing_m"])
		var centre: float = F.float_value(row["centre_z_m"])
		if station <= previous:
			errors.append("spatial_profile stations must increase strictly")
		previous = station
		if spacing <= 0.0:
			errors.append("spatial_profile lane spacing must be positive")
		if station < bounds.position.x or station > bounds.end.x or \
				centre - 3.0 * spacing < bounds.position.y or \
				centre + 3.0 * spacing > bounds.end.y:
			errors.append("spatial_profile row lies outside bounds")
	return errors

static func validate_nodes(quality: Dictionary, nodes: Array) -> Array[String]:
	var profile: Dictionary = quality.get("spatial_profile", {})
	if not profile.has("lane_assignments"):
		return []
	var assignments: Dictionary = profile["lane_assignments"]
	var errors: Array[String] = []
	var used: Dictionary = {}
	for node: Dictionary in nodes:
		var id: String = str(node["id"])
		if not assignments.has(id):
			errors.append("missing generated lane for " + id)
			continue
		var key: String = "%s:%s" % [node["row"], assignments[id]]
		if used.has(key):
			errors.append("duplicate generated row slot " + key)
		used[key] = true
	return errors
