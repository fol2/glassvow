class_name MapGradeSeparation
extends RefCounted
## Governed ground-plus-one-level physical grade separation for #469.

const MINIMUM_VERTICAL_CLEARANCE_M: float = 0.384
const MAXIMUM_RAMP_GRADE: float = 0.353
const PHYSICAL_PRECISION_M: float = 0.001
const MAX_ORIENTATION_CONFLICTS: int = 8


static func physical_profile() -> Dictionary:
	return {
		"minimum_vertical_clearance_m": MINIMUM_VERTICAL_CLEARANCE_M,
		"maximum_ramp_grade": MAXIMUM_RAMP_GRADE,
		"physical_precision_m": PHYSICAL_PRECISION_M,
		"levels": 2,
	}


static func apply(routes: Dictionary, quality: Dictionary) -> Dictionary:
	var epsilon: float = MapLayoutCanonical.float_value(
		quality["epsilon"]["world_m"]
	)
	var conflicts: Array[Dictionary] = _xz_conflicts(routes, epsilon)
	if conflicts.is_empty():
		return {"ok": true, "routes": routes.duplicate(true), "receipt": _receipt(
			conflicts, [], 0, 0.0, 0.0, routes
		)}
	if conflicts.size() > MAX_ORIENTATION_CONFLICTS:
		return _failure("orientation_bound",
			"%d XZ conflicts exceed the bounded two-orientation proof" \
				% conflicts.size(), {"conflicts": conflicts})
	var options: Array[Array] = []
	for conflict: Dictionary in conflicts:
		if MapLayoutCanonical.int_value(conflict["proper_crossing_count"]) != 1:
			return _failure("ambiguous_xz_overlap",
				"only one proper transverse crossing is gradeable", conflict)
		var edge_ids: Array = conflict["edge_ids"]
		var first_route: Dictionary = routes[str(edge_ids[0])]
		var second_route: Dictionary = routes[str(edge_ids[1])]
		options.append([
			_span_option(str(edge_ids[0]), first_route,
				str(edge_ids[1]), second_route),
			_span_option(str(edge_ids[1]), second_route,
				str(edge_ids[0]), first_route),
		])
	var best: Dictionary = {}
	var combination_count: int = 1 << conflicts.size()
	for mask: int in range(combination_count):
		var spans_by_edge: Dictionary = {}
		var orientations: Array[Dictionary] = []
		var feasible: bool = true
		for conflict_index: int in range(conflicts.size()):
			var option: Dictionary = options[conflict_index][
				(mask >> conflict_index) & 1
			]
			if option.get("ok", false) != true:
				feasible = false
				break
			var elevated_id: String = str(option["elevated_edge_id"])
			if not spans_by_edge.has(elevated_id):
				spans_by_edge[elevated_id] = []
			spans_by_edge[elevated_id].append(option["span"])
			orientations.append(option["receipt"])
		if not feasible:
			continue
		var merged: Dictionary = _merged_spans(spans_by_edge)
		if merged.get("ok", false) != true:
			continue
		var merged_rows: Dictionary = merged["spans"]
		var graded_routes: Dictionary = _apply_spans(routes, merged_rows)
		var evaluation: Dictionary = evaluate(graded_routes, quality)
		if evaluation.get("hard_pass", false) != true:
			continue
		var elevated_length: float = 0.0
		var ramp_burden: float = 0.0
		var span_count: int = 0
		for edge_id: String in MapLayoutCanonical.sorted_keys(merged_rows):
			for span_v: Variant in merged_rows[edge_id]:
				var span: Dictionary = span_v
				span_count += 1
				elevated_length += MapLayoutCanonical.float_value(span["ramp_end_m"]) \
					- MapLayoutCanonical.float_value(span["ramp_start_m"])
				ramp_burden += MapLayoutCanonical.float_value(span["ramp_grade"]) * 2.0
		var candidate: Dictionary = {
			"routes": graded_routes,
			"spans": merged_rows,
			"orientations": orientations,
			"span_count": span_count,
			"elevated_length_m": elevated_length,
			"ramp_burden": ramp_burden,
			"evaluation": evaluation,
		}
		if best.is_empty() or _better(candidate, best):
			best = candidate
	if best.is_empty():
		return _failure("two_level_infeasible",
			"neither bounded orientation yields a governed two-level result",
			{"conflicts": conflicts, "options": options})
	var best_routes: Dictionary = best["routes"]
	var best_orientations: Array = best["orientations"]
	return {"ok": true, "routes": best_routes, "receipt": _receipt(
		conflicts, best_orientations, MapLayoutCanonical.int_value(
			best["span_count"]),
		MapLayoutCanonical.float_value(best["elevated_length_m"]),
		MapLayoutCanonical.float_value(best["ramp_burden"]), best_routes
	)}


static func evaluate(routes: Dictionary, quality: Dictionary) -> Dictionary:
	var epsilon: float = MapLayoutCanonical.float_value(
		quality["epsilon"]["world_m"]
	)
	var maximum_grade: float = 0.0
	var grade_violations: Array[Dictionary] = []
	for edge_id: String in MapLayoutCanonical.sorted_keys(routes):
		var line: Array = routes[edge_id]["centerline"]
		for index: int in range(line.size() - 1):
			var a: Vector3 = _v3(line[index])
			var b: Vector3 = _v3(line[index + 1])
			var run: float = _xz(a).distance_to(_xz(b))
			var rise: float = absf(b.y - a.y)
			var grade: float = INF if run <= epsilon and rise > epsilon else \
				(0.0 if run <= epsilon else rise / run)
			maximum_grade = maxf(maximum_grade, grade)
			if grade > MAXIMUM_RAMP_GRADE + epsilon:
				grade_violations.append({
					"metric_id": "maximum_ramp_grade",
					"profile_id": "world",
					"entities": [edge_id],
					"value": grade,
					"world": {"segment_index": index,
						"limit": MAXIMUM_RAMP_GRADE},
					"projected": {},
				})
	var conflicts: Array[Dictionary] = _xz_conflicts(routes, epsilon)
	var minimum_clearance: float = MINIMUM_VERTICAL_CLEARANCE_M
	var invalid: int = 0
	var crossing_violations: Array[Dictionary] = []
	if not conflicts.is_empty():
		minimum_clearance = INF
	for conflict: Dictionary in conflicts:
		var edge_ids: Array = conflict["edge_ids"]
		var first_route: Dictionary = routes[str(edge_ids[0])]
		var second_route: Dictionary = routes[str(edge_ids[1])]
		var clearance: float = _minimum_vertical_clearance(
			first_route, second_route,
			MapLayoutCanonical.float_value(conflict["required_xz_m"]), epsilon
		)
		minimum_clearance = minf(minimum_clearance, clearance)
		var proper: bool = MapLayoutCanonical.int_value(
			conflict["proper_crossing_count"]) == 1
		if proper and clearance + epsilon >= MINIMUM_VERTICAL_CLEARANCE_M:
			continue
		invalid += 1
		var reason: String = "insufficient_vertical_clearance" if proper else \
			"ambiguous_or_positive_length_xz_overlap"
		crossing_violations.append({
			"metric_id": "unrelated_edge_intersection_count",
			"profile_id": "world",
			"entities": edge_ids,
			"value": 1.0,
			"world": {
				"minimum_separation_m": conflict["minimum_xz_m"],
				"minimum_vertical_clearance_m": clearance,
				"required_vertical_clearance_m": MINIMUM_VERTICAL_CLEARANCE_M,
				"reason": reason,
			},
			"projected": {},
		})
		if proper:
			crossing_violations.append({
				"metric_id": "minimum_vertical_clearance_m",
				"profile_id": "world",
				"entities": edge_ids,
				"value": clearance,
				"world": {"limit": MINIMUM_VERTICAL_CLEARANCE_M},
				"projected": {},
			})
	var violations: Array = grade_violations.duplicate(true)
	violations.append_array(crossing_violations)
	return {
		"hard_pass": violations.is_empty(),
		"hard_values": {
			"unrelated_edge_intersection_count": invalid,
			"minimum_vertical_clearance_m": minimum_clearance,
			"maximum_ramp_grade": maximum_grade,
		},
		"violations": violations,
		"conflicts": conflicts,
		"profile": physical_profile(),
	}


static func _span_option(elevated_id: String, elevated: Dictionary,
		ground_id: String, ground: Dictionary) -> Dictionary:
	var line: Array = elevated["centerline"]
	var ground_line: Array = ground["centerline"]
	for point_v: Variant in line:
		if absf(_v3(point_v).y) > PHYSICAL_PRECISION_M:
			return {"ok": false, "reason": "input route is not all-ground"}
	var length: float = _path_length(line)
	var limit: float = (
		MapLayoutCanonical.float_value(elevated["corridor_width"])
		+ MapLayoutCanonical.float_value(ground["corridor_width"])
	) * 0.5
	var overlap: Vector2 = _overlap_envelope(line, ground_line, limit)
	if not is_finite(overlap.x):
		return {"ok": false, "reason": "no swept XZ overlap envelope"}
	var deck_start: float = maxf(0.0,
		overlap.x - PHYSICAL_PRECISION_M)
	var deck_end: float = minf(length,
		overlap.y + PHYSICAL_PRECISION_M)
	var ramp_length: float = MINIMUM_VERTICAL_CLEARANCE_M / MAXIMUM_RAMP_GRADE
	if deck_start + PHYSICAL_PRECISION_M < ramp_length \
			or length - deck_end + PHYSICAL_PRECISION_M < ramp_length:
		return {"ok": false, "reason": "bounded ramps do not fit",
			"required_ramp_length_m": ramp_length,
			"available_m": [deck_start, length - deck_end]}
	var span: Dictionary = {
		"ramp_start_m": maxf(0.0, deck_start - ramp_length),
		"deck_start_m": deck_start,
		"deck_end_m": deck_end,
		"ramp_end_m": minf(length, deck_end + ramp_length),
		"ramp_grade": MINIMUM_VERTICAL_CLEARANCE_M / ramp_length,
	}
	return {"ok": true, "elevated_edge_id": elevated_id,
		"ground_edge_id": ground_id, "span": span,
		"receipt": {"elevated_edge_id": elevated_id,
			"ground_edge_id": ground_id, "span": span}}


static func _merged_spans(spans_by_edge: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for edge_id: String in MapLayoutCanonical.sorted_keys(spans_by_edge):
		var spans: Array = spans_by_edge[edge_id].duplicate(true)
		spans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return MapLayoutCanonical.float_value(a["deck_start_m"]) \
				< MapLayoutCanonical.float_value(b["deck_start_m"])
		)
		var merged: Array[Dictionary] = []
		for span_v: Variant in spans:
			var span: Dictionary = span_v
			if merged.is_empty() or MapLayoutCanonical.float_value(
					merged[-1]["ramp_end_m"]) + PHYSICAL_PRECISION_M \
					< MapLayoutCanonical.float_value(span["ramp_start_m"]):
				merged.append(span.duplicate(true))
				continue
			var previous: Dictionary = merged[-1]
			var deck_start: float = minf(
				MapLayoutCanonical.float_value(previous["deck_start_m"]),
				MapLayoutCanonical.float_value(span["deck_start_m"]))
			var deck_end: float = maxf(
				MapLayoutCanonical.float_value(previous["deck_end_m"]),
				MapLayoutCanonical.float_value(span["deck_end_m"]))
			var ramp_length: float = MINIMUM_VERTICAL_CLEARANCE_M \
				/ MAXIMUM_RAMP_GRADE
			previous["ramp_start_m"] = maxf(0.0, deck_start - ramp_length)
			previous["deck_start_m"] = deck_start
			previous["deck_end_m"] = deck_end
			previous["ramp_end_m"] = deck_end + ramp_length
			previous["ramp_grade"] = MAXIMUM_RAMP_GRADE
			merged[-1] = previous
		out[edge_id] = merged
	return {"ok": true, "spans": MapLayoutCanonical.ordered_dictionary(out)}


static func _apply_spans(routes: Dictionary, spans_by_edge: Dictionary) -> Dictionary:
	var out: Dictionary = routes.duplicate(true)
	for edge_id: String in MapLayoutCanonical.sorted_keys(spans_by_edge):
		var edge: Dictionary = out[edge_id]
		var line: Array = edge["centerline"]
		var positions: Array[float] = [0.0]
		var arc: float = 0.0
		for index: int in range(line.size() - 1):
			arc += _xz(_v3(line[index])).distance_to(_xz(_v3(line[index + 1])))
			positions.append(arc)
		for span_v: Variant in spans_by_edge[edge_id]:
			var span: Dictionary = span_v
			for key: String in [
				"ramp_start_m", "deck_start_m", "deck_end_m", "ramp_end_m",
			]:
				positions.append(MapLayoutCanonical.float_value(span[key]))
		positions.sort()
		var unique: Array[float] = []
		for position: float in positions:
			if unique.is_empty() or absf(position - unique[-1]) \
					> PHYSICAL_PRECISION_M * 0.5:
				unique.append(position)
		var graded: Array = []
		var edge_spans: Array = spans_by_edge[edge_id]
		for position: float in unique:
			var point: Vector3 = _point3_at_arc(line, position)
			point.y = _height(position, edge_spans)
			graded.append(_a3(point))
		graded[0] = line[0]
		graded[-1] = line[-1]
		edge["centerline"] = graded
		out[edge_id] = edge
	return MapLayoutCanonical.ordered_dictionary(out)


static func _height(arc: float, spans: Array) -> float:
	var height: float = 0.0
	for span_v: Variant in spans:
		var span: Dictionary = span_v
		var ramp_start: float = MapLayoutCanonical.float_value(span["ramp_start_m"])
		var deck_start: float = MapLayoutCanonical.float_value(span["deck_start_m"])
		var deck_end: float = MapLayoutCanonical.float_value(span["deck_end_m"])
		var ramp_end: float = MapLayoutCanonical.float_value(span["ramp_end_m"])
		if arc < ramp_start or arc > ramp_end:
			continue
		if arc < deck_start:
			height = maxf(height, MINIMUM_VERTICAL_CLEARANCE_M \
				* (arc - ramp_start) / maxf(deck_start - ramp_start,
					PHYSICAL_PRECISION_M))
		elif arc <= deck_end:
			height = maxf(height, MINIMUM_VERTICAL_CLEARANCE_M)
		else:
			height = maxf(height, MINIMUM_VERTICAL_CLEARANCE_M \
				* (ramp_end - arc) / maxf(ramp_end - deck_end,
					PHYSICAL_PRECISION_M))
	return height


static func _better(a: Dictionary, b: Dictionary) -> bool:
	var a_spans: int = MapLayoutCanonical.int_value(a["span_count"])
	var b_spans: int = MapLayoutCanonical.int_value(b["span_count"])
	if a_spans != b_spans:
		return a_spans < b_spans
	for key: String in ["elevated_length_m", "ramp_burden"]:
		var av: float = MapLayoutCanonical.float_value(a[key])
		var bv: float = MapLayoutCanonical.float_value(b[key])
		if not is_equal_approx(av, bv):
			return av < bv
	return MapLayoutCanonical.canonical_text(a["spans"]) \
		< MapLayoutCanonical.canonical_text(b["spans"])


static func _xz_conflicts(routes: Dictionary, epsilon: float) -> Array[Dictionary]:
	var ids: Array[String] = MapLayoutCanonical.sorted_keys(routes)
	var out: Array[Dictionary] = []
	for first_index: int in range(ids.size()):
		var first: Dictionary = routes[ids[first_index]]
		for second_index: int in range(first_index + 1, ids.size()):
			var second: Dictionary = routes[ids[second_index]]
			if str(first["from"]) in [str(second["from"]), str(second["to"])] \
					or str(first["to"]) in [str(second["from"]), str(second["to"])]:
				continue
			var first_line: Array = first["centerline"]
			var second_line: Array = second["centerline"]
			var minimum: float = _polyline_xz_distance(
				first_line, second_line)
			var required: float = (
				MapLayoutCanonical.float_value(first["corridor_width"])
				+ MapLayoutCanonical.float_value(second["corridor_width"])
			) * 0.5
			if minimum >= required - epsilon:
				continue
			out.append({
				"edge_ids": [ids[first_index], ids[second_index]],
				"minimum_xz_m": minimum,
				"required_xz_m": required,
				"proper_crossing_count": _proper_crossing_count(
					first_line, second_line, epsilon),
			})
	return out


static func _proper_crossing_count(first: Array, second: Array,
		epsilon: float) -> int:
	var count: int = 0
	for first_index: int in range(first.size() - 1):
		var a: Vector2 = _xz(_v3(first[first_index]))
		var b: Vector2 = _xz(_v3(first[first_index + 1]))
		var r: Vector2 = b - a
		for second_index: int in range(second.size() - 1):
			var c: Vector2 = _xz(_v3(second[second_index]))
			var d: Vector2 = _xz(_v3(second[second_index + 1]))
			var s: Vector2 = d - c
			var denominator: float = r.cross(s)
			if absf(denominator) <= epsilon:
				continue
			var t: float = (c - a).cross(s) / denominator
			var u: float = (c - a).cross(r) / denominator
			if t > epsilon and t < 1.0 - epsilon \
					and u > epsilon and u < 1.0 - epsilon:
				count += 1
	return count


static func _minimum_vertical_clearance(first: Dictionary, second: Dictionary,
		required_xz: float, epsilon: float) -> float:
	var minimum: float = INF
	var first_line: Array = first["centerline"]
	var second_line: Array = second["centerline"]
	for first_index: int in range(first_line.size() - 1):
		var a3: Vector3 = _v3(first_line[first_index])
		var b3: Vector3 = _v3(first_line[first_index + 1])
		var segment_length: float = _xz(a3).distance_to(_xz(b3))
		if segment_length <= epsilon:
			continue
		for second_index: int in range(second_line.size() - 1):
			var c3: Vector3 = _v3(second_line[second_index])
			var d3: Vector3 = _v3(second_line[second_index + 1])
			var interval: Vector2 = _segment_capsule_interval(
				_xz(a3), _xz(b3), _xz(c3), _xz(d3), required_xz
			)
			if not _valid_interval(interval):
				continue
			var samples: int = maxi(1, ceili(
				(interval.y - interval.x) * segment_length \
					/ PHYSICAL_PRECISION_M))
			for sample_index: int in range(samples + 1):
				var t: float = lerpf(interval.x, interval.y,
					float(sample_index) / float(samples))
				var point: Vector2 = _xz(a3).lerp(_xz(b3), t)
				var other_interval: Vector2 = _circle_interval(
					_xz(c3), _xz(d3), point, required_xz
				)
				if not _valid_interval(other_interval):
					continue
				var y: float = lerpf(a3.y, b3.y, t)
				var first_y: float = lerpf(c3.y, d3.y, other_interval.x)
				var last_y: float = lerpf(c3.y, d3.y, other_interval.y)
				var low: float = minf(first_y, last_y)
				var high: float = maxf(first_y, last_y)
				minimum = minf(minimum, 0.0 if y >= low and y <= high else \
					minf(absf(y - low), absf(y - high)))
	return 0.0 if not is_finite(minimum) else minimum


static func _overlap_envelope(first: Array, second: Array,
		radius: float) -> Vector2:
	var out: Vector2 = Vector2(INF, -INF)
	var arc: float = 0.0
	for first_index: int in range(first.size() - 1):
		var a: Vector2 = _xz(_v3(first[first_index]))
		var b: Vector2 = _xz(_v3(first[first_index + 1]))
		var segment_length: float = a.distance_to(b)
		for second_index: int in range(second.size() - 1):
			var interval: Vector2 = _segment_capsule_interval(
				a, b, _xz(_v3(second[second_index])),
				_xz(_v3(second[second_index + 1])), radius
			)
			if _valid_interval(interval):
				out.x = minf(out.x, arc + interval.x * segment_length)
				out.y = maxf(out.y, arc + interval.y * segment_length)
		arc += segment_length
	return out


## Exact interval on AB whose XZ points lie inside the radius capsule of CD.
static func _segment_capsule_interval(a: Vector2, b: Vector2,
		c: Vector2, d: Vector2, radius: float) -> Vector2:
	var intervals: Array[Vector2] = [
		_circle_interval(a, b, c, radius),
		_circle_interval(a, b, d, radius),
	]
	var direction: Vector2 = d - c
	var length_squared: float = direction.length_squared()
	if length_squared > PHYSICAL_PRECISION_M ** 2:
		var travel: Vector2 = b - a
		var projection: Vector2 = _linear_interval(
			(a - c).dot(direction) / length_squared,
			travel.dot(direction) / length_squared, 0.0, 1.0
		)
		var direction_length: float = sqrt(length_squared)
		var strip: Vector2 = _linear_interval(
			(a - c).cross(direction) / direction_length,
			travel.cross(direction) / direction_length, -radius, radius
		)
		var body: Vector2 = Vector2(maxf(projection.x, strip.x),
			minf(projection.y, strip.y))
		if _valid_interval(body):
			intervals.append(body)
	var out: Vector2 = Vector2(INF, -INF)
	for interval: Vector2 in intervals:
		if _valid_interval(interval):
			out.x = minf(out.x, interval.x)
			out.y = maxf(out.y, interval.y)
	return out


static func _circle_interval(a: Vector2, b: Vector2,
		center: Vector2, radius: float) -> Vector2:
	var travel: Vector2 = b - a
	var coefficient: float = travel.length_squared()
	if coefficient <= PHYSICAL_PRECISION_M ** 2:
		return Vector2(0.0, 1.0) if a.distance_to(center) <= radius else \
			Vector2(INF, -INF)
	var offset: Vector2 = a - center
	var linear: float = 2.0 * offset.dot(travel)
	var constant: float = offset.length_squared() - radius * radius
	var discriminant: float = linear * linear - 4.0 * coefficient * constant
	if discriminant < 0.0:
		return Vector2(INF, -INF)
	var root: float = sqrt(maxf(0.0, discriminant))
	var low: float = maxf(0.0, (-linear - root) / (2.0 * coefficient))
	var high: float = minf(1.0, (-linear + root) / (2.0 * coefficient))
	return Vector2(low, high) if low <= high else Vector2(INF, -INF)


static func _linear_interval(base: float, delta: float,
		minimum: float, maximum: float) -> Vector2:
	if absf(delta) <= PHYSICAL_PRECISION_M:
		return Vector2(0.0, 1.0) \
			if base >= minimum and base <= maximum else Vector2(INF, -INF)
	var first: float = (minimum - base) / delta
	var second: float = (maximum - base) / delta
	var low: float = maxf(0.0, minf(first, second))
	var high: float = minf(1.0, maxf(first, second))
	return Vector2(low, high) if low <= high else Vector2(INF, -INF)


static func _valid_interval(interval: Vector2) -> bool:
	return is_finite(interval.x) and interval.x <= interval.y


static func _polyline_xz_distance(first: Array, second: Array) -> float:
	var minimum: float = INF
	for first_index: int in range(first.size() - 1):
		for second_index: int in range(second.size() - 1):
			var closest: PackedVector2Array = Geometry2D.get_closest_points_between_segments(
				_xz(_v3(first[first_index])), _xz(_v3(first[first_index + 1])),
				_xz(_v3(second[second_index])), _xz(_v3(second[second_index + 1])))
			minimum = minf(minimum, closest[0].distance_to(closest[1]))
	return minimum


static func _path_length(line: Array) -> float:
	var length: float = 0.0
	for index: int in range(line.size() - 1):
		length += _xz(_v3(line[index])).distance_to(_xz(_v3(line[index + 1])))
	return length


static func _point3_at_arc(line: Array, requested_arc: float) -> Vector3:
	var remaining: float = requested_arc
	for index: int in range(line.size() - 1):
		var start: Vector3 = _v3(line[index])
		var finish: Vector3 = _v3(line[index + 1])
		var segment_length: float = _xz(start).distance_to(_xz(finish))
		if remaining <= segment_length or index == line.size() - 2:
			return start.lerp(finish, 0.0 if segment_length <= 0.0 else \
				clampf(remaining / segment_length, 0.0, 1.0))
		remaining -= segment_length
	return _v3(line[-1])


static func _receipt(conflicts: Array, orientations: Array,
		span_count: int, elevated_length: float, ramp_burden: float,
		routes: Dictionary) -> Dictionary:
	return MapLayoutCanonical.ordered_dictionary({
		"status": "GRADED" if span_count > 0 else "ALL_GROUND",
		"profile": physical_profile(),
		"conflicts": conflicts,
		"orientations": orientations,
		"bridge_span_count": span_count,
		"elevated_length_m": elevated_length,
		"ramp_burden": ramp_burden,
		"edge_digest": MapLayoutCanonical.digest(routes),
	})


static func _failure(id: String, reason: String,
		details: Dictionary) -> Dictionary:
	return {"ok": false, "binding": {
		"kind": "grade_separation",
		"id": id,
		"node_id": "",
		"edge_id": "",
		"profile_id": "world",
		"reason": reason,
		"details": details,
	}}


static func _a3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func _v3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	var row: Array = value
	return Vector3(
		MapLayoutCanonical.float_value(row[0]),
		MapLayoutCanonical.float_value(row[1]),
		MapLayoutCanonical.float_value(row[2])
	)


static func _xz(value: Vector3) -> Vector2:
	return Vector2(value.x, value.z)
