extends RefCounted
## Reserve generated row spacing for stairs and unavoidable layered crossings.
static func apply(profile: Dictionary,nodes: Array,edges: Array) -> Dictionary:
	var out: Dictionary = profile.duplicate(true)
	var records: Dictionary = {}
	for node: Dictionary in nodes:
		records[str(node["id"])] = node
	var slots: Dictionary = profile["lane_assignments"]
	var crossings: Dictionary = {}
	var pairs: Dictionary = {}
	for i: int in range(edges.size()):
		var a: Dictionary = edges[i]
		var row: int = MapLayoutCanonical.int_value(records[str(a["from"])]["row"])
		for j: int in range(i+1,edges.size()):
			var b: Dictionary = edges[j]
			if MapLayoutCanonical.int_value(records[str(b["from"])]["row"]) != row:
				continue
			var start: float = MapLayoutCanonical.float_value(slots[str(a["from"])])-MapLayoutCanonical.float_value(slots[str(b["from"])])
			var end: float = MapLayoutCanonical.float_value(slots[str(a["to"])])-MapLayoutCanonical.float_value(slots[str(b["to"])])
			if start*end < 0:
				crossings[row] = true
				for side: String in ["from","to"]:
					var pair_row: int = row if side == "from" else row+1
					if not pairs.has(pair_row):
						pairs[pair_row] = []
					pairs[pair_row].append([MapLayoutCanonical.int_value(slots[str(a[side])]),MapLayoutCanonical.int_value(slots[str(b[side])])])
	var rows: Array = out["rows"]
	var original: Array = profile["rows"]
	var added: float = 0
	var passage: Dictionary = profile.get("passage",{})
	var deck_rise: float = MapLayoutCanonical.float_value(passage.get("headroom_m",2.45))+MapLayoutCanonical.float_value(passage.get("deck_depth_m",.65))
	var grade: float = MapLayoutCanonical.float_value(passage.get("maximum_grade",.55))
	var landing: float = MapLayoutCanonical.float_value(passage.get("landing_m",1.0))
	var crossing_lane: float = MapLayoutCanonical.float_value(passage.get("crossing_lane_spacing_m",0.0))
	var crossing_interval: float = MapLayoutCanonical.float_value(passage.get("crossing_interval_m",0.0))
	if crossing_lane > 0:
		for row: int in pairs:
			var gaps: Array[float] = []
			gaps.resize(6)
			gaps.fill(MapLayoutCanonical.float_value(rows[row]["lane_spacing_m"]))
			for pair: Array in pairs[row]:
				var low: int = mini(MapLayoutCanonical.int_value(pair[0]),MapLayoutCanonical.int_value(pair[1]))
				var high: int = maxi(MapLayoutCanonical.int_value(pair[0]),MapLayoutCanonical.int_value(pair[1]))
				var separation: float = 0
				for gap: int in range(low,high):
					separation += gaps[gap]
				var extra: float = maxf(0,crossing_lane-separation)/float(high-low)
				for gap: int in range(low,high):
					gaps[gap] += extra
			var positions: Array[float] = [0.0]
			for gap: float in gaps:
				positions.append(positions[-1]+gap)
			var centre: float = positions[3]
			for index: int in range(positions.size()):
				positions[index] -= centre
			rows[row]["lane_positions_m"] = positions
	for i: int in range(1,rows.size()):
		var gap: float = MapLayoutCanonical.float_value(original[i]["station_m"])-MapLayoutCanonical.float_value(original[i-1]["station_m"])
		var rise: float = absf(MapLayoutCanonical.float_value(rows[i]["height_m"])-MapLayoutCanonical.float_value(rows[i-1]["height_m"]))
		var required: float = gap
		if rise > .00001:
			# Two branch guides, two level approaches and a discrete stair run.
			required = maxf(required,10.0+2*landing+maxf(rise/grade,ceili(rise/.17)*.28))
		if crossings.has(i-1):
			required = maxf(maxf(required,crossing_interval),2*(deck_rise/grade+2*landing)+2*4.0+2*2.5+.8)
		added += required-gap
		rows[i]["station_m"] = MapLayoutCanonical.float_value(original[i]["station_m"])+added
	var bounds: Array = out["bounds_xz_m"]
	bounds[2] = MapLayoutCanonical.float_value(bounds[2])+added
	if crossing_lane > 0:
		for row: Dictionary in rows:
			var centre: float = MapLayoutCanonical.float_value(row["centre_z_m"])
			var extent: float = 3*MapLayoutCanonical.float_value(row["lane_spacing_m"])+12.0
			if row.has("lane_positions_m"):
				var positions: Array = row["lane_positions_m"]
				extent = maxf(absf(MapLayoutCanonical.float_value(positions[0])),
					absf(MapLayoutCanonical.float_value(positions[-1])))+12.0
			bounds[1] = minf(MapLayoutCanonical.float_value(bounds[1]),centre-extent)
			bounds[3] = maxf(MapLayoutCanonical.float_value(bounds[3]),centre+extent)
	return {"profile":out,"added_length_m":added,"crossing_rows":crossings.keys()}
