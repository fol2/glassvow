class_name MapQualityEvaluator
extends RefCounted
## Pure governed camera registry and geometric evaluator for Map Compiler v2 (#466).
const VERSION: String = "map-quality-evaluator-v1"
const EMPTY_MANIFEST: Dictionary = {"assets": [], "profile_defaults": {}, "profile_overrides": {}}
const _Grade = preload("res://presentation/map/map_grade_separation.gd")
const SELECTION_SCREEN_METRICS: PackedStringArray = [
	"node_ink_clearance_px",
	"node_touch_target_min_px",
	"node_touch_overlap_area_px2",
	"node_touch_hero_silhouette_overlap_area_px2",
	"node_node_ink_overlap_area_px2",
	"node_hero_silhouette_overlap_area_px2",
	"focused_node_safe_frame_margin_px",
]
## Candidate-independent touch size and zero-area exclusions remain hard gates,
## but cannot provide positive ordering slack between passing candidates.
const SELECTION_PRIORITY_METRICS: PackedStringArray = [
	"node_ink_clearance_px",
	"focused_node_safe_frame_margin_px",
]
@warning_ignore_start("unsafe_call_argument")
static func camera_registry(nodes: Array, quality: Dictionary,
		edges: Array = []) -> Dictionary:
	var chosen: Dictionary = {}
	for value: Variant in nodes:
		var node: Dictionary = value
		var row: int = _i(node.get("row", -1))
		if row >= 0 and (not chosen.has(row) or str(node["id"]) < str(chosen[row]["id"])):
			chosen[row] = node
	var poses: Array = [{"id": "opening", "kind": "opening", "focus": "", "xz": MapCameraRig.DEFAULT_XZ}]
	var rows: Array = chosen.keys(); rows.sort()
	for row_v: Variant in rows:
		var row: int = int(row_v)
		poses.append({"id": "row-%02d" % row, "kind": "focus", "focus": str(chosen[row]["id"]), "world": _a3(_authored(chosen[row], quality))})
	var bounds: Rect2 = MapCameraRig.bounds_from_lattice()
	var lo: Vector2 = bounds.position; var hi: Vector2 = bounds.end; var mid: Vector2 = (lo + hi) * 0.5
	for pair: Array in [["pan-left", Vector2(lo.x, mid.y)], ["pan-right", Vector2(hi.x, mid.y)], ["pan-near", Vector2(mid.x, lo.y)], ["pan-far", Vector2(mid.x, hi.y)], ["pan-near-left", lo], ["pan-near-right", Vector2(hi.x, lo.y)], ["pan-far-left", Vector2(lo.x, hi.y)], ["pan-far-right", hi]]:
		poses.append({"id": pair[0], "kind": "pan", "focus": "", "xz": pair[1]})
	var profiles: Array = []
	var errors: Array = []
	var focus_inset: float = focused_touch_inset_px(quality)
	var focus_envelopes: Dictionary = node_candidate_bounds(
		nodes, edges, quality)
	for shape: StringName in StageShape.SHIPPING:
		var stage: Vector2i = StageShape.REFERENCES[shape]
		for zoom_i: int in range(MapCameraRig.ZOOM_STOPS.size()):
			var zoom: float = MapCameraRig.ZOOM_STOPS[zoom_i]
			for value: Variant in poses:
				var pose: Dictionary = value
				var xz: Vector2 = _v2(pose.get("xz", Vector2.ZERO))
				var profile_id: String = "%s/z%d/%s" % [shape, zoom_i, pose["id"]]
				if str(pose["kind"]) == "focus":
					var world: Vector3 = _v3(pose["world"])
					var resolved: Dictionary = MapCameraRig.resolve_leading(world,
						Vector2(stage), zoom, focus_inset,
						focused_anchor_envelope(str(pose["focus"]), focus_envelopes))
					var resolved_pose_v: Variant = resolved.get("pose", null)
					if resolved.get("ok", false) != true or not resolved_pose_v is Vector2:
						var failure: Dictionary = resolved.get("failure", {}).duplicate(true)
						failure["profile_id"] = profile_id
						failure["focus_node_id"] = pose["focus"]
						errors.append(failure)
						continue
					xz = resolved_pose_v
				xz = Vector2(clampf(xz.x, lo.x, hi.x), clampf(xz.y, lo.y, hi.y))
				var entry: Dictionary = {"id": profile_id, "shape": str(shape), "stage": [stage.x, stage.y], "zoom": zoom, "tilt": MapCameraRig.TILT_DEGREES, "height": MapCameraRig.CAM_HEIGHT, "flex_cap": StageShape.FLEX_CAP, "pose": _a2(xz), "kind": pose["kind"], "focus": pose["focus"]}
				entry["digest"] = MapLayoutCanonical.digest(entry)
				profiles.append(entry)
	return {"schema_version": 1, "version": "map-camera-profiles-v2", "profiles": profiles,
		"errors": errors, "digest": MapLayoutCanonical.digest(profiles)}


static func focused_touch_inset_px(quality: Dictionary) -> float:
	return _touch_size_px(quality) * 0.5 \
		+ _limit(_index(quality["hard"]), "focused_node_safe_frame_margin_px")


## Shared #467 legal bounds used by candidate generation and camera identity.
static func node_candidate_bounds(nodes: Array, edges: Array,
		quality: Dictionary) -> Dictionary:
	var governed: Dictionary = quality["geometry"]["row_lane_envelope"]
	var row_half: float = _f(governed["row_half_extent_m"])
	var lane_half: float = _f(governed["lane_half_extent_m"])
	var stage: Rect2 = MapPinProjection.lattice_footprint()
	var initial: Dictionary = {}
	for node: Dictionary in nodes:
		var node_id: String = str(node["id"])
		var base: Vector3 = _authored(node, quality)
		var fixed: bool = str(node["type"]) in ["boss", "act4", "entrance"]
		initial[node_id] = {
			"base": base,
			"min_x": base.x if fixed else maxf(stage.position.x, base.x - row_half),
			"max_x": base.x if fixed else minf(stage.end.x, base.x + row_half),
			"min_z": base.z if fixed else maxf(stage.position.y, base.z - lane_half),
			"max_z": base.z if fixed else minf(stage.end.y, base.z + lane_half),
		}
	var out: Dictionary = initial.duplicate(true)
	var progress: float = _f(governed["minimum_forward_progress_m"])
	for edge: Dictionary in edges:
		var from_id: String = str(edge["from"])
		var to_id: String = str(edge["to"])
		var from: Dictionary = out[from_id]
		var to: Dictionary = out[to_id]
		from["max_x"] = minf(_f(from["max_x"]),
			_f(initial[to_id]["min_x"]) - progress)
		to["min_x"] = maxf(_f(to["min_x"]),
			_f(initial[from_id]["max_x"]) + progress)
		out[from_id] = from
		out[to_id] = to
	return out


static func focused_anchor_envelope(node_id: String,
		envelopes: Dictionary) -> Rect2:
	var limit: Dictionary = envelopes[node_id]
	return Rect2(Vector2(_f(limit["min_x"]), _f(limit["min_z"])), Vector2(
		_f(limit["max_x"]) - _f(limit["min_x"]),
		_f(limit["max_z"]) - _f(limit["min_z"])))


static func is_selection_screen_metric(metric_id: String) -> bool:
	return metric_id in SELECTION_SCREEN_METRICS


static func selection_screen_context(nodes: Array, edges: Array,
		heroes: Dictionary, assets: Dictionary, quality: Dictionary) -> Dictionary:
	var camera: Dictionary = camera_registry(nodes, quality, edges)
	var obstacles: Dictionary = _obstacles({
		"hero_placements": heroes,
		"scenery_instances": {},
	}, assets.get("profiles", {}))
	var projected: Dictionary = {}
	for profile_v: Variant in camera["profiles"]:
		var profile: Dictionary = profile_v
		var rows: Dictionary = {}
		for obstacle_id: String in MapLayoutCanonical.sorted_keys(obstacles):
			rows[obstacle_id] = _project_obstacle(obstacles[obstacle_id], profile)
		projected[str(profile["id"])] = rows
	return {
		"camera": camera,
		"hard": _index(quality["hard"]),
		"epsilon": _f(quality["epsilon"]["screen_px"]),
		"obstacles": obstacles,
		"projected_obstacles": projected,
	}


static func selection_screen_feasibility(nodes: Array, edges: Array,
		anchors: Dictionary, heroes: Dictionary, assets: Dictionary,
		quality: Dictionary, local_node_ids: Array,
		shared_context: Dictionary = {}) -> Dictionary:
	var selected_ids: Array[String] = []
	for node_id_v: Variant in local_node_ids:
		var node_id: String = str(node_id_v)
		if not node_id.is_empty() and node_id not in selected_ids:
			selected_ids.append(node_id)
	selected_ids.sort()
	var local_nodes: Array = []
	var local_anchors: Dictionary = {}
	for node_v: Variant in nodes:
		var node: Dictionary = node_v
		var node_id: String = str(node["id"])
		if node_id in selected_ids and anchors.has(node_id):
			local_nodes.append(node)
			local_anchors[node_id] = anchors[node_id]
	if local_nodes.size() != selected_ids.size():
		return {"hard_pass": false, "hard_values": {}, "hard_margins": {},
			"weakest_signed_hard_margin": -1.0,
			"rejection_reason": {"metric_id": "selection_screen_input",
				"reason": "named local node or anchor is missing"},
			"violations": []}
	var context: Dictionary = shared_context
	if context.is_empty():
		context = selection_screen_context(nodes, edges, heroes, assets, quality)
	var camera: Dictionary = context["camera"]
	var hard: Dictionary = context["hard"]
	var epsilon: float = _f(context["epsilon"])
	if not shared_context.is_empty() and selected_ids.size() == 2:
		return _cached_pair_feasibility(local_nodes, local_anchors,
			selected_ids, quality, context)
	var profiles: Dictionary = {}
	var violations: Array = []
	if shared_context.is_empty():
		for profile_v: Variant in camera["profiles"]:
			var profile: Dictionary = profile_v
			var checked: Dictionary = _selection_screen(
				profile, local_nodes, local_anchors, {}, quality, hard, epsilon,
				context["projected_obstacles"][str(profile["id"])]
			)
			profiles[str(profile["id"])] = checked["values"]
			violations.append_array(checked["violations"])
	else:
		var cached: Dictionary = _cached_selection_profiles(local_nodes,
			local_anchors, selected_ids, quality, context)
		profiles = cached["profiles"]
		violations.assign(cached["violations"])
	return _selection_screen_summary(
		selected_ids, camera, hard, epsilon, profiles, violations)


static func _selection_screen_summary(selected_ids: Array[String],
		camera: Dictionary, hard: Dictionary, epsilon: float,
		profiles: Dictionary, profile_violations: Array) -> Dictionary:
	var violations: Array = profile_violations.duplicate(true)
	for error_v: Variant in camera.get("errors", []):
		var error: Dictionary = error_v
		if str(error.get("focus_node_id", "")) in selected_ids:
			violations.append(_violation("focused_node_safe_frame_margin_px",
				str(error.get("profile_id", "camera-resolution")),
				[str(error.get("focus_node_id", ""))], -1.0,
				{"camera_resolution_failure": error}, {}))
	var values: Dictionary = {}
	var margins: Dictionary = {}
	var weakest: float = INF
	for metric_id: String in SELECTION_SCREEN_METRICS:
		var value: float = _aggregate(metric_id, profiles)
		if not is_finite(value):
			continue
		values[metric_id] = value
		var row: Dictionary = hard[metric_id]
		var margin: float = value - _f(row["limit"]) \
			if str(row["op"]) == "gte" else _f(row["limit"]) - value
		margins[metric_id] = margin
		if metric_id in SELECTION_PRIORITY_METRICS:
			weakest = minf(weakest, margin)
		if not _passes(value, row, epsilon):
			var already_named: bool = false
			for violation: Dictionary in violations:
				already_named = already_named \
					or str(violation.get("metric_id", "")) == metric_id
			if not already_named:
				violations.append(_violation(metric_id, "selection", selected_ids,
					value, {}, {}))
	violations.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return MapLayoutCanonical.canonical_text(a) \
			< MapLayoutCanonical.canonical_text(b)
	)
	return MapLayoutCanonical.ordered_dictionary({
		"hard_pass": violations.is_empty(),
		"local_node_ids": selected_ids,
		"hard_values": MapLayoutCanonical.ordered_dictionary(values),
		"hard_margins": MapLayoutCanonical.ordered_dictionary(margins),
		"priority_metric_ids": SELECTION_PRIORITY_METRICS,
		"weakest_signed_hard_margin": 0.0 if not is_finite(weakest) else weakest,
		"rejection_reason": {} if violations.is_empty() else violations[0],
		"violations": violations,
	})


static func _cached_selection_profiles(local_nodes: Array,
		local_anchors: Dictionary, selected_ids: Array[String],
		quality: Dictionary, context: Dictionary) -> Dictionary:
	var rows: Array[Dictionary] = []
	for node_id: String in selected_ids:
		var node: Dictionary = {}
		for node_v: Variant in local_nodes:
			var candidate_node: Dictionary = node_v
			if str(candidate_node["id"]) == node_id:
				node = candidate_node
				break
		rows.append(_cached_candidate_profiles(
			node, local_anchors[node_id], quality, context))
	if rows.size() == 1:
		var unary_profiles: Dictionary = {}
		for profile_id: String in MapLayoutCanonical.sorted_keys(
				rows[0]["profiles"]):
			unary_profiles[profile_id] = rows[0]["profiles"][profile_id]["values"]
		return {"profiles": unary_profiles,
			"violations": rows[0]["violations"]}
	var profiles: Dictionary = {}
	var violations: Array = []
	var calibration: Dictionary = quality["calibration"]["shipping_touch_waystone"]
	var radius: float = _f(calibration["ink_radius_px"]) \
		* _f(calibration["default_layout_scale"])
	var touch: float = _touch_size_px(quality)
	var hard: Dictionary = context["hard"]
	var epsilon: float = _f(context["epsilon"])
	for profile_v: Variant in context["camera"]["profiles"]:
		var profile: Dictionary = profile_v
		var profile_id: String = str(profile["id"])
		var first: Dictionary = rows[0]["profiles"][profile_id]
		var second: Dictionary = rows[1]["profiles"][profile_id]
		var values: Dictionary = {}
		for metric_id: String in SELECTION_SCREEN_METRICS:
			values[metric_id] = _aggregate(metric_id, {
				"first": first["values"], "second": second["values"]})
		var a: Vector2 = first["point"]
		var b: Vector2 = second["point"]
		var gap: float = a.distance_to(b) - radius * 2.0
		values["node_ink_clearance_px"] = minf(
			_f(values["node_ink_clearance_px"]), gap)
		var pair_violations: Array = []
		if gap + epsilon < _limit(hard, "node_ink_clearance_px"):
			pair_violations.append(_violation("node_ink_clearance_px",
				profile_id, selected_ids, gap,
				{"a": local_anchors[selected_ids[0]],
					"b": local_anchors[selected_ids[1]]},
				{"a": _a2(a), "b": _a2(b), "radius": radius}))
		if a.distance_squared_to(b) < pow(radius * 2.0, 2.0):
			_overlap("node_node_ink_overlap_area_px2", _circle(a, radius),
				_circle(b, radius), profile, selected_ids, values,
				pair_violations, epsilon)
		if absf(a.x - b.x) < touch and absf(a.y - b.y) < touch:
			_overlap("node_touch_overlap_area_px2",
				_rect(a, Vector2.ONE * touch * 0.5),
				_rect(b, Vector2.ONE * touch * 0.5), profile, selected_ids,
				values, pair_violations, epsilon)
		profiles[profile_id] = values
		violations.append_array(first["violations"])
		violations.append_array(second["violations"])
		violations.append_array(pair_violations)
	return {"profiles": profiles, "violations": violations}


static func _cached_pair_feasibility(local_nodes: Array,
		local_anchors: Dictionary, selected_ids: Array[String],
		quality: Dictionary, context: Dictionary) -> Dictionary:
	var rows: Array[Dictionary] = []
	for node_id: String in selected_ids:
		var node: Dictionary = {}
		for node_v: Variant in local_nodes:
			var candidate_node: Dictionary = node_v
			if str(candidate_node["id"]) == node_id:
				node = candidate_node
				break
		rows.append(_cached_candidate_profiles(
			node, local_anchors[node_id], quality, context))
	var values: Dictionary = {}
	for metric_id: String in SELECTION_SCREEN_METRICS:
		var minimum: bool = metric_id in ["node_ink_clearance_px",
			"node_touch_target_min_px", "focused_node_safe_frame_margin_px"]
		var first_value: float = _f(rows[0]["summary"]["hard_values"].get(
			metric_id, INF if minimum else 0.0))
		var second_value: float = _f(rows[1]["summary"]["hard_values"].get(
			metric_id, INF if minimum else 0.0))
		values[metric_id] = minf(first_value, second_value) \
			if minimum else maxf(first_value, second_value)
	var rejection: Dictionary = _first_reason([
		rows[0]["summary"].get("rejection_reason", {}),
		rows[1]["summary"].get("rejection_reason", {}),
	])
	var calibration: Dictionary = quality["calibration"]["shipping_touch_waystone"]
	var radius: float = _f(calibration["ink_radius_px"]) \
		* _f(calibration["default_layout_scale"])
	var diameter: float = radius * 2.0
	var touch: float = _touch_size_px(quality)
	var hard: Dictionary = context["hard"]
	var epsilon: float = _f(context["epsilon"])
	for profile_v: Variant in context["camera"]["profiles"]:
		var profile: Dictionary = profile_v
		var profile_id: String = str(profile["id"])
		var a: Vector2 = rows[0]["profiles"][profile_id]["point"]
		var b: Vector2 = rows[1]["profiles"][profile_id]["point"]
		var gap: float = a.distance_to(b) - diameter
		values["node_ink_clearance_px"] = minf(
			_f(values["node_ink_clearance_px"]), gap)
		if gap + epsilon < _limit(hard, "node_ink_clearance_px"):
			rejection = _first_reason([rejection, _violation(
				"node_ink_clearance_px", profile_id, selected_ids, gap,
				{"a": local_anchors[selected_ids[0]],
					"b": local_anchors[selected_ids[1]]},
				{"a": _a2(a), "b": _a2(b), "radius": radius})])
		var pair_violations: Array = []
		if a.distance_squared_to(b) < diameter * diameter:
			_overlap("node_node_ink_overlap_area_px2", _circle(a, radius),
				_circle(b, radius), profile, selected_ids, values,
				pair_violations, epsilon)
		if absf(a.x - b.x) < touch and absf(a.y - b.y) < touch:
			_overlap("node_touch_overlap_area_px2",
				_rect(a, Vector2.ONE * touch * 0.5),
				_rect(b, Vector2.ONE * touch * 0.5), profile, selected_ids,
				values, pair_violations, epsilon)
		if not pair_violations.is_empty():
			rejection = _first_reason([rejection, pair_violations[0]])
	var margins: Dictionary = {}
	var finite_values: Dictionary = {}
	var weakest: float = INF
	for metric_id: String in SELECTION_SCREEN_METRICS:
		var value: float = _f(values[metric_id])
		if not is_finite(value):
			continue
		finite_values[metric_id] = value
		var row: Dictionary = hard[metric_id]
		var margin: float = value - _f(row["limit"]) \
			if str(row["op"]) == "gte" else _f(row["limit"]) - value
		margins[metric_id] = margin
		if metric_id in SELECTION_PRIORITY_METRICS:
			weakest = minf(weakest, margin)
		if not _passes(value, row, epsilon) and rejection.is_empty():
			rejection = _violation(metric_id, "selection", selected_ids,
				value, {}, {})
	return MapLayoutCanonical.ordered_dictionary({
		"hard_pass": rejection.is_empty(),
		"local_node_ids": selected_ids,
		"hard_values": MapLayoutCanonical.ordered_dictionary(finite_values),
		"hard_margins": MapLayoutCanonical.ordered_dictionary(margins),
		"priority_metric_ids": SELECTION_PRIORITY_METRICS,
		"weakest_signed_hard_margin": 0.0 if not is_finite(weakest) else weakest,
		"rejection_reason": rejection,
		"violations": [] if rejection.is_empty() else [rejection],
	})


static func _first_reason(rows: Array) -> Dictionary:
	var out: Dictionary = {}
	for row_v: Variant in rows:
		var row: Dictionary = row_v
		if row.is_empty():
			continue
		if out.is_empty() or MapLayoutCanonical.canonical_text(row) \
				< MapLayoutCanonical.canonical_text(out):
			out = row
	return out


static func _cached_candidate_profiles(node: Dictionary, anchor: Variant,
		quality: Dictionary, context: Dictionary) -> Dictionary:
	var node_id: String = str(node["id"])
	var key: String = MapLayoutCanonical.canonical_text(
		{"node_id": node_id, "anchor": anchor})
	var cache: Dictionary = context.get("candidate_cache", {})
	if cache.has(key):
		return cache[key]
	var profiles: Dictionary = {}
	var violations: Array = []
	var anchors: Dictionary = {node_id: anchor}
	var hard: Dictionary = context["hard"]
	var epsilon: float = _f(context["epsilon"])
	for profile_v: Variant in context["camera"]["profiles"]:
		var profile: Dictionary = profile_v
		var profile_id: String = str(profile["id"])
		var checked: Dictionary = _selection_screen(profile, [node], anchors,
			context["obstacles"],
			quality, hard, epsilon, context["projected_obstacles"][profile_id])
		profiles[profile_id] = {
			"values": checked["values"],
			"violations": checked["violations"],
			"point": _project(_v3(anchor), profile),
		}
		violations.append_array(checked["violations"])
	var result: Dictionary = {"profiles": profiles, "violations": violations}
	var profile_values: Dictionary = {}
	for profile_id: String in MapLayoutCanonical.sorted_keys(profiles):
		profile_values[profile_id] = profiles[profile_id]["values"]
	result["summary"] = _selection_screen_summary([node_id], context["camera"],
		hard, epsilon, profile_values, violations)
	cache[key] = result
	context["candidate_cache"] = cache
	return result


## Conservative #466 broad-phase for candidate pairs that can violate any
## selection-only node/node screen rule in at least one governed profile.
static func selection_screen_local_pairs(node_sets: Dictionary,
		quality: Dictionary, shared_context: Dictionary) -> Array[Array]:
	var calibration: Dictionary = quality["calibration"]["shipping_touch_waystone"]
	var radius: float = _f(calibration["ink_radius_px"]) \
		* _f(calibration["default_layout_scale"])
	var touch: float = _touch_size_px(quality)
	var hard: Dictionary = shared_context["hard"]
	var reach: float = maxf(
		radius * 2.0 + _limit(hard, "node_ink_clearance_px"),
		touch * sqrt(2.0)
	) + _f(shared_context["epsilon"])
	var found: Dictionary = {}
	for profile_v: Variant in shared_context["camera"]["profiles"]:
		var profile: Dictionary = profile_v
		var buckets: Dictionary = {}
		for node_id: String in MapLayoutCanonical.sorted_keys(node_sets):
			for candidate_v: Variant in node_sets[node_id]["candidates"]:
				var candidate: Dictionary = candidate_v
				var point: Vector2 = _project(_v3(candidate["anchor"]), profile)
				var cell: Vector2i = Vector2i(floori(point.x / reach),
					floori(point.y / reach))
				for dx: int in range(-1, 2):
					for dy: int in range(-1, 2):
						for other_v: Variant in buckets.get(
								cell + Vector2i(dx, dy), []):
							var other: Dictionary = other_v
							var other_id: String = str(other["node_id"])
							if other_id == node_id:
								continue
							var other_point: Vector2 = other["point"]
							var delta: Vector2 = point - other_point
							var ink_fails: bool = delta.length() - radius * 2.0 \
								+ _f(shared_context["epsilon"]) \
								< _limit(hard, "node_ink_clearance_px")
							var touch_overlap: float = maxf(0.0,
								touch - absf(delta.x)) * maxf(0.0,
								touch - absf(delta.y))
							if not ink_fails and touch_overlap \
									<= _f(shared_context["epsilon"]):
								continue
							var pair: Array[String] = [node_id, other_id]
							pair.sort()
							found[MapLayoutCanonical.canonical_text(pair)] = pair
				var rows: Array = buckets.get(cell, [])
				rows.append({"node_id": node_id, "point": point})
				buckets[cell] = rows
	var out: Array[Array] = []
	for key: String in MapLayoutCanonical.sorted_keys(found):
		out.append(found[key])
	return out


static func evaluate(input: MapLayoutInput, result: MapLayoutResult, assets: Dictionary, quality: Dictionary) -> Dictionary:
	var source: Dictionary = input.to_dict()
	var layout: Dictionary = result.identity_dict()
	var nodes: Array = input.node_records()
	var topology: Array = input.edge_records()
	var anchors: Dictionary = layout["node_anchors"]
	var edges: Dictionary = layout["edges"]
	var cameras: Dictionary = camera_registry(nodes, quality, topology)
	var hard_rows: Dictionary = _index(quality["hard"])
	var ew: float = _f(quality["epsilon"]["world_m"])
	var ep: float = _f(quality["epsilon"]["screen_px"])
	var geometry: Dictionary = quality["geometry"]
	var road_radius: float = _f(geometry["road_corridor"]["physical_half_width_m"]) + _f(geometry["road_corridor"]["world_clearance_m"])
	var obstacles: Dictionary = _obstacles(layout, assets.get("profiles", {}))
	var values: Dictionary = {"row_lane_envelope_excess_m": 0.0, "journey_order_reversal_count": 0, "edge_scenery_corridor_penetration_m": 0.0, "edge_nonendpoint_node_penetration_m": 0.0, "unrelated_edge_intersection_count": 0, "vigil_protected_zone_intrusion_count": 0, "terminus_protected_zone_intrusion_count": 0}
	var violations: Array = []
	var camera_errors: Array = cameras.get("errors", [])
	for error_v: Variant in camera_errors:
		var error: Dictionary = error_v
		violations.append(_violation("focused_node_safe_frame_margin_px",
			str(error.get("profile_id", "camera-resolution")),
			[str(error.get("focus_node_id", ""))], -1.0,
			{"camera_resolution_failure": error}, {}))
	var raw: Array = []
	var soft: Dictionary = {}
	var envelope: Dictionary = geometry["row_lane_envelope"]
	var displacement: float = 0.0
	for value: Variant in nodes:
		var node: Dictionary = value
		var id: String = str(node["id"])
		var anchor: Vector3 = _v3(anchors[id])
		var authored: Vector3 = _authored(node, quality)
		var excess: float = maxf(absf(anchor.x - authored.x) - _f(envelope["row_half_extent_m"]), absf(anchor.z - authored.z) - _f(envelope["lane_half_extent_m"]))
		values["row_lane_envelope_excess_m"] = maxf(_f(values["row_lane_envelope_excess_m"]), maxf(0.0, excess))
		displacement += Vector2(anchor.x - authored.x, anchor.z - authored.z).length_squared()
		if excess > ew:
			violations.append(_violation("row_lane_envelope_excess_m", "world", [id], excess, {"anchor": _a3(anchor), "authored": _a3(authored)}, {}))
	soft["node_displacement_rms_m"] = sqrt(displacement / maxf(1.0, float(nodes.size())))
	for value: Variant in topology:
		var edge: Dictionary = value
		var a: Vector3 = _v3(anchors[str(edge["from"])])
		var b: Vector3 = _v3(anchors[str(edge["to"])])
		if b.x - a.x < _f(envelope["minimum_forward_progress_m"]) - ew:
			values["journey_order_reversal_count"] = _i(values["journey_order_reversal_count"]) + 1
			violations.append(_violation("journey_order_reversal_count", "world", [str(edge["id"])], 1.0, {"from": _a3(a), "to": _a3(b)}, {}))
	var routed: float = 0.0
	var direct: float = 0.0
	var bends: float = 0.0
	for edge_id: String in MapLayoutCanonical.sorted_keys(edges):
		var edge: Dictionary = edges[edge_id]
		var points: Array = edge["centerline"]
		var radius: float = maxf(road_radius, _f(edge["corridor_width"]) * 0.5)
		direct += _xz(_v3(points[0])).distance_to(_xz(_v3(points[-1])))
		for i: int in range(points.size() - 1):
			var a: Vector2 = _xz(_v3(points[i]))
			var b: Vector2 = _xz(_v3(points[i + 1]))
			routed += a.distance_to(b)
			for obstacle_id: String in MapLayoutCanonical.sorted_keys(obstacles):
				var penetration: float = radius - _segment_polygon(a, b, obstacles[obstacle_id]["world"])
				if penetration > ew:
					values["edge_scenery_corridor_penetration_m"] = maxf(_f(values["edge_scenery_corridor_penetration_m"]), penetration)
					violations.append(_violation("edge_scenery_corridor_penetration_m", "world", [edge_id, obstacle_id], penetration, {"segment": [_a2(a), _a2(b)], "obstacle": _plain(obstacles[obstacle_id]["world"])}, {}))
			for node_v: Variant in nodes:
				var node: Dictionary = node_v
				var node_id: String = str(node["id"])
				if node_id in [str(edge["from"]), str(edge["to"])]:
					continue
				var penetration: float = radius - _segment_polygon(a, b, _node_world(_v3(anchors[node_id]), quality))
				if penetration > ew:
					values["edge_nonendpoint_node_penetration_m"] = maxf(_f(values["edge_nonendpoint_node_penetration_m"]), penetration)
					violations.append(_violation("edge_nonendpoint_node_penetration_m", "world", [edge_id, node_id], penetration, {"segment": [_a2(a), _a2(b)]}, {}))
		for i: int in range(1, points.size() - 1):
			var u: Vector2 = (_xz(_v3(points[i])) - _xz(_v3(points[i - 1]))).normalized()
			var v: Vector2 = (_xz(_v3(points[i + 1])) - _xz(_v3(points[i]))).normalized()
			bends += 0.0 if u.is_zero_approx() or v.is_zero_approx() else rad_to_deg(acos(clampf(u.dot(v), -1.0, 1.0)))
	soft["route_length_ratio"] = routed / maxf(direct, ew)
	soft["bend_angle_deg_per_edge"] = bends / maxf(1.0, float(edges.size()))
	var crossing: Dictionary = _Grade.evaluate(edges, quality)
	values.merge(crossing["hard_values"], true)
	var minimum_xz: float = INF
	for conflict: Dictionary in crossing["conflicts"]:
		minimum_xz = minf(minimum_xz, _f(conflict["minimum_xz_m"]))
	raw.append({"metric_id": "minimum_edge_separation_m", "profile_id": "world",
		"value": 0.0 if minimum_xz == INF else minimum_xz,
		"status": "not_applicable" if minimum_xz == INF else "measured"})
	raw.append({"metric_id": "minimum_vertical_clearance_m", "profile_id": "world",
		"value": values["minimum_vertical_clearance_m"],
		"status": "not_applicable" if crossing["conflicts"].is_empty() else "measured"})
	raw.append({"metric_id": "maximum_ramp_grade", "profile_id": "world",
		"value": values["maximum_ramp_grade"], "status": "measured"})
	violations.append_array(crossing["violations"])
	var protected: Dictionary = _protected(source, obstacles, geometry, ew)
	values.merge(protected["values"], true)
	violations.append_array(protected["violations"])
	var profile_values: Dictionary = {}
	for profile_v: Variant in cameras["profiles"]:
		var profile: Dictionary = profile_v
		var checked: Dictionary = _screen(profile, nodes, topology, anchors, edges, obstacles, quality, hard_rows, ep)
		profile_values[str(profile["id"])] = checked["values"]
		raw.append_array(checked["raw"])
		violations.append_array(checked["violations"])
	for metric: String in ["node_ink_clearance_px", "node_touch_target_min_px", "node_touch_overlap_area_px2", "node_touch_scenery_silhouette_overlap_area_px2", "node_touch_hero_silhouette_overlap_area_px2", "node_node_ink_overlap_area_px2", "node_scenery_silhouette_overlap_area_px2", "node_hero_silhouette_overlap_area_px2", "branch_fanout_separation_px", "focused_node_safe_frame_margin_px"]:
		values[metric] = _aggregate(metric, profile_values)
	soft["route_state_exposure_ratio"] = _aggregate("route_state_exposure_ratio", profile_values)
	soft["branch_separation_margin_px"] = _f(values["branch_fanout_separation_px"]) - _limit(hard_rows, "branch_fanout_separation_px")
	soft["camera_profile_consistency_ratio"] = _consistency(profile_values, hard_rows)
	var identity_bad: bool = str(layout["input_digest"]) != input.digest() or str(cameras["digest"]) != str(source["camera_profile_digest"]) or MapLayoutCanonical.digest(quality) != str(source["quality_registry_digest"]) or str(assets.get("digest", "")) != str(source["asset_profile_digest"])
	values["deterministic_identity_mismatch_count"] = 1 if identity_bad else 0
	if identity_bad:
		violations.append(_violation("deterministic_identity_mismatch_count", "identity", [], 1.0, {"input": input.digest(), "layout_input": layout["input_digest"]}, {"camera": cameras["digest"], "quality": MapLayoutCanonical.digest(quality), "assets": assets.get("digest", "")}))
	var hard_pass: bool = camera_errors.is_empty() \
		and crossing.get("hard_pass", false) == true
	for value: Variant in quality["hard"]:
		var hard: Dictionary = value
		var id: String = str(hard["id"])
		if not values.has(id) or not _passes(_f(values[id]), hard, ew if str(hard["unit"]) == "m" else ep):
			hard_pass = false
	var report: Dictionary = {"schema_version": 1, "version": VERSION, "input_digest": input.digest(), "layout_digest": result.digest(), "camera_profile_digest": cameras["digest"], "quality_registry_digest": MapLayoutCanonical.digest(quality), "asset_profile_digest": assets.get("digest", ""), "profiles": cameras["profiles"], "grade_profile": crossing["profile"], "hard_values": values, "raw_measurements": raw, "soft_raw": soft, "violations": violations, "renderer_only": quality["renderer"], "hard_pass": hard_pass}
	report["report_digest"] = MapLayoutCanonical.digest(report)
	return MapLayoutCanonical.ordered_dictionary(report)
static func _screen(profile: Dictionary, nodes: Array, topology: Array, anchors: Dictionary, edges: Dictionary, obstacles: Dictionary, quality: Dictionary, hard: Dictionary, epsilon: float) -> Dictionary:
	var selection: Dictionary = _selection_screen(
		profile, nodes, anchors, obstacles, quality, hard, epsilon
	)
	var values: Dictionary = selection["values"]
	var violations: Array = selection["violations"].duplicate(true)
	var projected_obstacles: Dictionary = selection["projected_obstacles"]
	var focus: String = str(profile["focus"])
	var fanout: Dictionary = _fanout(profile, topology, edges, quality, hard)
	values["branch_fanout_separation_px"] = fanout["minimum"]
	violations.append_array(fanout["violations"])
	var exposure: Dictionary = _exposure(profile, edges, projected_obstacles)
	values["route_state_exposure_ratio"] = exposure["ratio"]
	var focus_row: Dictionary = {"metric_id": "focused_node_safe_frame_margin_px",
		"profile_id": profile["id"], "value": 0.0, "focus_node_id": focus,
		"status": "not_applicable"}
	if not focus.is_empty():
		focus_row["value"] = values["focused_node_safe_frame_margin_px"]
		focus_row["status"] = "measured"
	return {"values": values, "violations": violations, "raw": [
		{"metric_id": "route_state_exposure_ratio", "profile_id": profile["id"],
			"value": exposure["ratio"], "visible_length_px": exposure["visible"],
			"total_length_px": exposure["total"],
			"status": "not_applicable" if _f(exposure["total"]) <= 0.0 else "measured"},
			{"metric_id": "branch_fanout_separation_px", "profile_id": profile["id"],
				"value": fanout["minimum"], "status": fanout["status"]}, focus_row]}


static func _selection_screen(profile: Dictionary, nodes: Array,
		anchors: Dictionary, obstacles: Dictionary, quality: Dictionary,
		hard: Dictionary, epsilon: float,
		shared_projected_obstacles: Dictionary = {}) -> Dictionary:
	var calibration: Dictionary = quality["calibration"]["shipping_touch_waystone"]
	var radius: float = _f(calibration["ink_radius_px"]) * _f(calibration["default_layout_scale"])
	var touch: float = _touch_size_px(quality)
	var values: Dictionary = {"node_ink_clearance_px": INF, "node_touch_target_min_px": touch, "node_touch_overlap_area_px2": 0.0, "node_touch_scenery_silhouette_overlap_area_px2": 0.0, "node_touch_hero_silhouette_overlap_area_px2": 0.0, "node_node_ink_overlap_area_px2": 0.0, "node_scenery_silhouette_overlap_area_px2": 0.0, "node_hero_silhouette_overlap_area_px2": 0.0, "branch_fanout_separation_px": INF, "focused_node_safe_frame_margin_px": INF, "route_state_exposure_ratio": 1.0}
	var violations: Array = []
	var projected_nodes: Dictionary = {}
	for value: Variant in nodes:
		var node: Dictionary = value
		projected_nodes[str(node["id"])] = _project(_v3(anchors[str(node["id"])]), profile)
	var projected_obstacles: Dictionary = shared_projected_obstacles
	if projected_obstacles.is_empty():
		for id: String in MapLayoutCanonical.sorted_keys(obstacles):
			projected_obstacles[id] = _project_obstacle(obstacles[id], profile)
	var ids: Array[String] = MapLayoutCanonical.sorted_keys(projected_nodes)
	for i: int in range(ids.size()):
		var a_id: String = ids[i]
		var a: Vector2 = projected_nodes[a_id]
		var ink: PackedVector2Array = _circle(a, radius)
		var hit: PackedVector2Array = _rect(a, Vector2.ONE * touch * 0.5)
		for j: int in range(i + 1, ids.size()):
			var b_id: String = ids[j]
			var b: Vector2 = projected_nodes[b_id]
			var gap: float = a.distance_to(b) - radius * 2.0
			values["node_ink_clearance_px"] = minf(_f(values["node_ink_clearance_px"]), gap)
			if gap + epsilon < _limit(hard, "node_ink_clearance_px"):
				violations.append(_violation("node_ink_clearance_px", str(profile["id"]), [a_id, b_id], gap,
					{"a": anchors[a_id], "b": anchors[b_id]}, {"a": _a2(a), "b": _a2(b), "radius": radius}))
			_overlap("node_node_ink_overlap_area_px2", ink, _circle(b, radius), profile, [a_id, b_id], values, violations, epsilon)
			_overlap("node_touch_overlap_area_px2", hit, _rect(b, Vector2.ONE * touch * 0.5), profile, [a_id, b_id], values, violations, epsilon)
		for obstacle_id: String in MapLayoutCanonical.sorted_keys(projected_obstacles):
			var obstacle: Dictionary = projected_obstacles[obstacle_id]
			var hero: bool = str(obstacle["group"]) == "hero_placements"
			var gap: float = _signed_gap(a, obstacle["clipped"]) - radius
			values["node_ink_clearance_px"] = minf(_f(values["node_ink_clearance_px"]), gap)
			if gap + epsilon < _limit(hard, "node_ink_clearance_px"):
				violations.append(_violation("node_ink_clearance_px", str(profile["id"]), [a_id, obstacle_id], gap,
					{"node": anchors[a_id], "obstacle": _plain(obstacles[obstacle_id]["world"])},
					{"node": _a2(a), "obstacle": _plain(obstacle["clipped"])}))
			_overlap("node_hero_silhouette_overlap_area_px2" if hero else "node_scenery_silhouette_overlap_area_px2", ink, obstacle["clipped"], profile, [a_id, obstacle_id], values, violations, epsilon, obstacle)
			_overlap("node_touch_hero_silhouette_overlap_area_px2" if hero else "node_touch_scenery_silhouette_overlap_area_px2", hit, obstacle["clipped"], profile, [a_id, obstacle_id], values, violations, epsilon, obstacle)
	var focus: String = str(profile["focus"])
	if not focus.is_empty() and projected_nodes.has(focus):
		var c: Vector2 = projected_nodes[focus]
		var stage: Vector2 = _v2(profile["stage"])
		values["focused_node_safe_frame_margin_px"] = minf(minf(c.x, stage.x - c.x), minf(c.y, stage.y - c.y)) - touch * 0.5
		if _f(values["focused_node_safe_frame_margin_px"]) + epsilon < _limit(hard, "focused_node_safe_frame_margin_px"):
			violations.append(_violation("focused_node_safe_frame_margin_px", str(profile["id"]), [focus],
				_f(values["focused_node_safe_frame_margin_px"]), {"node": anchors[focus]},
				{"touch": _plain(_rect(c, Vector2.ONE * touch * 0.5)), "stage": profile["stage"]}))
	return {"values": values, "violations": violations,
		"projected_obstacles": projected_obstacles}
static func _touch_size_px(quality: Dictionary) -> float:
	var calibration: Dictionary = quality["calibration"]["shipping_touch_waystone"]
	var diameter: float = _f(calibration["ink_radius_px"]) \
		* _f(calibration["default_layout_scale"]) * 2.0
	return maxf(_f(calibration["phone_touch_floor_px"]), diameter)
static func _obstacles(data: Dictionary, profiles: Dictionary) -> Dictionary:
	var helper: MapAssetProfiles = MapAssetProfiles.new(EMPTY_MANIFEST)
	var out: Dictionary = {}
	for group: String in ["hero_placements", "scenery_instances"]:
		for id: String in MapLayoutCanonical.sorted_keys(data[group]):
			var row: Dictionary = data[group][id]
			var transform: Dictionary = row["transform"]
			var profile: Dictionary = profiles.get(str(row["profile_id"]), {})
			var origin: Vector3 = _v3(transform["origin"])
			var scale: Vector3 = _v3(transform["scale"])
			out["%s:%s" % [group, id]] = {"group": group, "world": helper.transformed_footprint(profile, origin, rad_to_deg(_f(transform["yaw_radians"])), scale), "y": origin.y, "height": _f(profile.get("grounded_height", 0.0)) * scale.y}
	return out
static func _project_obstacle(obstacle: Dictionary, profile: Dictionary) -> Dictionary:
	var points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in obstacle["world"]:
		points.append(_project(Vector3(point.x, _f(obstacle["y"]), point.y), profile))
		points.append(_project(Vector3(point.x, _f(obstacle["y"]) + _f(obstacle["height"]), point.y), profile))
	var hull: PackedVector2Array = Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[-1]):
		hull.remove_at(hull.size() - 1)
	var parts: Array[PackedVector2Array] = Geometry2D.intersect_polygons(hull, _frame(_v2(profile["stage"])))
	return {"group": obstacle["group"], "preclip": hull, "clipped": parts[0] if not parts.is_empty() else PackedVector2Array(), "preclip_area": _area(hull), "clipped_area": _area(parts[0]) if not parts.is_empty() else 0.0}
static func _crossings(edges: Dictionary, epsilon: float) -> Dictionary:
	var ids: Array[String] = MapLayoutCanonical.sorted_keys(edges)
	var count: int = 0
	var minimum: float = INF
	var violations: Array = []
	for i: int in range(ids.size()):
		var a: Dictionary = edges[ids[i]]
		for j: int in range(i + 1, ids.size()):
			var b: Dictionary = edges[ids[j]]
			if str(a["from"]) in [str(b["from"]), str(b["to"])] or str(a["to"]) in [str(b["from"]), str(b["to"])]:
				continue
			var distance: float = _polyline_distance(a["centerline"], b["centerline"])
			minimum = minf(minimum, distance)
			if distance < (_f(a["corridor_width"]) + _f(b["corridor_width"])) * 0.5 - epsilon:
				count += 1
				violations.append(_violation("unrelated_edge_intersection_count", "world", [ids[i], ids[j]], 1.0, {"minimum_separation_m": distance}, {}))
	return {"count": count, "minimum": minimum, "violations": violations}
static func _protected(input: Dictionary, obstacles: Dictionary, geometry: Dictionary, epsilon: float) -> Dictionary:
	var values: Dictionary = {"vigil_protected_zone_intrusion_count": 0, "terminus_protected_zone_intrusion_count": 0}
	var violations: Array = []
	for zone_id: String in MapLayoutCanonical.sorted_keys(input["hero_anchor_contract"]["protected_zones"]):
		var zone: Dictionary = input["hero_anchor_contract"]["protected_zones"][zone_id]
		var role: String = str(zone["role"])
		var metric: String = "%s_protected_zone_intrusion_count" % role
		if not values.has(metric):
			continue
		var poly: PackedVector2Array = _poly(zone["polygon"])
		var padding: float = _f(geometry["%s_protected_zone" % role]["padding_m"])
		for obstacle_id: String in MapLayoutCanonical.sorted_keys(obstacles):
			var obstacle: Dictionary = obstacles[obstacle_id]
			if str(obstacle["group"]) == "scenery_instances" and _polygon_distance(poly, obstacle["world"]) < padding - epsilon:
				values[metric] = _i(values[metric]) + 1
				violations.append(_violation(metric, "world", [zone_id, obstacle_id], 1.0, {"zone": _plain(poly), "obstacle": _plain(obstacle["world"])}, {}))
	return {"values": values, "violations": violations}
static func _fanout(profile: Dictionary, topology: Array, edges: Dictionary, quality: Dictionary, hard: Dictionary) -> Dictionary:
	var by_source: Dictionary = {}
	for value: Variant in topology:
		var edge: Dictionary = value
		var source: String = str(edge["from"])
		if not by_source.has(source):
			by_source[source] = []
		by_source[source].append(str(edge["id"]))
	var minimum: float = INF
	var violations: Array = []
	var sample: float = _f(quality["geometry"]["branch_fanout"]["sample_distance_m"])
	var limit: float = _limit(hard, "branch_fanout_separation_px")
	var applicable: bool = false
	for source: String in MapLayoutCanonical.sorted_keys(by_source):
		var ids: Array = by_source[source]
		if ids.size() > 1:
			applicable = true
		for i: int in range(ids.size()):
			for j: int in range(i + 1, ids.size()):
				var a: Vector2 = _project(_point_at(edges[ids[i]]["centerline"], sample), profile)
				var b: Vector2 = _project(_point_at(edges[ids[j]]["centerline"], sample), profile)
				var gap: float = a.distance_to(b)
				minimum = minf(minimum, gap)
				if gap + _f(quality["epsilon"]["screen_px"]) < limit:
					violations.append(_violation("branch_fanout_separation_px", str(profile["id"]), [source, ids[i], ids[j]], gap, {}, {"a": _a2(a), "b": _a2(b)}))
	return {"minimum": minimum if applicable else limit,
		"status": "measured" if applicable else "not_applicable",
		"violations": violations}
static func _exposure(profile: Dictionary, edges: Dictionary, obstacles: Dictionary) -> Dictionary:
	var total: float = 0.0; var visible: float = 0.0
	var frame: PackedVector2Array = _frame(_v2(profile["stage"]))
	for edge_id: String in MapLayoutCanonical.sorted_keys(edges):
		var line: PackedVector2Array = PackedVector2Array()
		for point: Variant in edges[edge_id]["centerline"]:
			line.append(_project(_v3(point), profile))
		for part: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(line, frame):
			total += _line_length(part)
			var visible_parts: Array[PackedVector2Array] = [part]
			for obstacle_id: String in MapLayoutCanonical.sorted_keys(obstacles):
				var next: Array[PackedVector2Array] = []
				for current: PackedVector2Array in visible_parts:
					next.append_array(Geometry2D.clip_polyline_with_polygon(current, obstacles[obstacle_id]["clipped"]))
				visible_parts = next
			for current: PackedVector2Array in visible_parts:
				visible += _line_length(current)
	return {"visible": visible, "total": total, "ratio": visible / maxf(total, 0.000001)}
static func _overlap(metric: String, a: PackedVector2Array, b: PackedVector2Array, profile: Dictionary, entities: Array, values: Dictionary, violations: Array, epsilon: float, obstacle: Dictionary = {}) -> void:
	var area: float = _intersection_area(a, b)
	values[metric] = maxf(_f(values[metric]), area)
	if area > epsilon:
		var projected: Dictionary = {"a": _plain(a), "b": _plain(b)}
		if not obstacle.is_empty():
			projected.merge({"preclip": _plain(obstacle["preclip"]), "preclip_area": obstacle["preclip_area"], "clipped_area": obstacle["clipped_area"]})
		violations.append(_violation(metric, str(profile["id"]), entities, area, {}, projected))
static func _project(world: Vector3, profile: Dictionary) -> Vector2:
	var pose: Vector2 = _v2(profile["pose"])
	var eye: Vector3 = Transform3D(Basis.from_euler(Vector3(deg_to_rad(_f(profile["tilt"])), 0.0, 0.0)), Vector3(pose.x, _f(profile["height"]), pose.y)).affine_inverse() * world
	var stage: Vector2 = _v2(profile["stage"])
	var half_y: float = _f(profile["zoom"]) * 0.5
	var half_x: float = half_y * stage.x / stage.y
	return Vector2((eye.x / half_x * 0.5 + 0.5) * stage.x, (-eye.y / half_y * 0.5 + 0.5) * stage.y)
static func _segment_polygon(a: Vector2, b: Vector2, poly: PackedVector2Array) -> float:
	return _path_distance(PackedVector2Array([a, b]), poly, false, true)
static func _polyline_distance(a: Array, b: Array) -> float:
	var pa: PackedVector2Array = PackedVector2Array()
	var pb: PackedVector2Array = PackedVector2Array()
	for value: Variant in a:
		pa.append(_xz(_v3(value)))
	for value: Variant in b:
		pb.append(_xz(_v3(value)))
	return _path_distance(pa, pb)
static func _polygon_distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
	return _path_distance(a, b, true, true)
static func _path_distance(a: PackedVector2Array, b: PackedVector2Array, close_a: bool = false, close_b: bool = false) -> float:
	if a.is_empty() or b.is_empty() or (close_a and Geometry2D.is_point_in_polygon(b[0], a)) or (close_b and Geometry2D.is_point_in_polygon(a[0], b)):
		return 0.0
	var best: float = INF
	for i: int in range(a.size() if close_a else a.size() - 1):
		for j: int in range(b.size() if close_b else b.size() - 1):
			var closest: PackedVector2Array = Geometry2D.get_closest_points_between_segments(a[i], a[(i + 1) % a.size()], b[j], b[(j + 1) % b.size()])
			best = minf(best, closest[0].distance_to(closest[1]))
	return best
static func _signed_gap(point: Vector2, poly: PackedVector2Array) -> float:
	if poly.size() < 3:
		return INF
	var best: float = INF
	for i: int in range(poly.size()):
		var edge: Vector2 = poly[(i + 1) % poly.size()] - poly[i]
		var t: float = clampf((point - poly[i]).dot(edge) / maxf(edge.length_squared(), 0.000001), 0.0, 1.0)
		best = minf(best, point.distance_to(poly[i] + edge * t))
	return -best if Geometry2D.is_point_in_polygon(point, poly) else best
static func _point_at(points: Array, distance: float) -> Vector3:
	for i: int in range(points.size() - 1):
		var a: Vector3 = _v3(points[i])
		var b: Vector3 = _v3(points[i + 1])
		var length: float = _xz(a).distance_to(_xz(b))
		if distance <= length:
			return a.lerp(b, distance / maxf(length, 0.000001))
		distance -= length
	return _v3(points[-1])
static func _authored(node: Dictionary, quality: Dictionary) -> Vector3:
	var stage: Dictionary = quality["calibration"]["stage_zoom_geometry"]
	var cell: Vector2 = _v2(stage["cell_m"])
	var origin: Vector2 = _v2(stage["origin_xz_m"])
	var jitter: Vector2 = _v2(node["jitter"])
	return Vector3(origin.x + (_f(node["row"]) + jitter.y) * cell.x, 0.0, origin.y + (_f(node["col"]) + jitter.x) * cell.y)
static func _node_world(center: Vector3, quality: Dictionary) -> PackedVector2Array:
	return _rect(_xz(center), _v2(quality["calibration"]["shipping_touch_waystone"]["node_pair_half_extent_m"]))
static func _circle(center: Vector2, radius: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(16):
		out.append(center + Vector2.from_angle(TAU * float(i) / 16.0) * radius)
	return out
static func _rect(center: Vector2, half: Vector2) -> PackedVector2Array:
	return PackedVector2Array([center - half, center + Vector2(-half.x, half.y), center + half, center + Vector2(half.x, -half.y)])
static func _frame(stage: Vector2) -> PackedVector2Array:
	return PackedVector2Array([Vector2.ZERO, Vector2(0.0, stage.y), stage, Vector2(stage.x, 0.0)])
static func _intersection_area(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var total: float = 0.0
	if a.size() >= 3 and b.size() >= 3:
		for part: PackedVector2Array in Geometry2D.intersect_polygons(a, b):
			total += _area(part)
	return total
static func _area(poly: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in range(poly.size()):
		total += poly[i].cross(poly[(i + 1) % poly.size()])
	return absf(total) * 0.5
static func _line_length(line: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in range(line.size() - 1):
		total += line[i].distance_to(line[i + 1])
	return total
static func _aggregate(metric: String, profiles: Dictionary) -> float:
	var minimum: bool = metric in ["node_ink_clearance_px", "node_touch_target_min_px", "branch_fanout_separation_px", "focused_node_safe_frame_margin_px", "route_state_exposure_ratio"]
	var out: float = INF if minimum else 0.0
	for id: String in MapLayoutCanonical.sorted_keys(profiles):
		out = minf(out, _f(profiles[id].get(metric, out))) if minimum else maxf(out, _f(profiles[id].get(metric, out)))
	return out
static func _consistency(profiles: Dictionary, hard: Dictionary) -> float:
	var lo: float = INF; var hi: float = 0.0
	for id: String in MapLayoutCanonical.sorted_keys(profiles):
		var row: Dictionary = profiles[id]
		var score: float = (clampf(_f(row["route_state_exposure_ratio"]), 0.0, 1.0)
			+ clampf(_f(row["node_ink_clearance_px"]) / maxf(_limit(hard, "node_ink_clearance_px"), 0.000001), 0.0, 1.0)) * 0.5
		lo = minf(lo, score)
		hi = maxf(hi, score)
	return 1.0 if hi <= 0.0 else lo / hi
static func _passes(value: float, hard: Dictionary, epsilon: float) -> bool:
	return value + epsilon >= _f(hard["limit"]) if str(hard["op"]) == "gte" else value <= _f(hard["limit"]) + epsilon
static func _index(rows: Array) -> Dictionary:
	var out: Dictionary = {}
	for value: Variant in rows:
		var row: Dictionary = value
		out[str(row["id"])] = row
	return out
static func _limit(rows: Dictionary, id: String) -> float:
	return _f(rows[id]["limit"])
static func _violation(metric: String, profile: String, entities: Array, value: float, world: Dictionary, projected: Dictionary) -> Dictionary:
	return {"metric_id": metric, "profile_id": profile, "entities": entities, "value": value, "world": world, "projected": projected}
static func _poly(value: Variant) -> PackedVector2Array:
	if value is PackedVector2Array:
		return value
	var out: PackedVector2Array = PackedVector2Array()
	for point: Variant in value:
		out.append(_v2(point))
	return out
static func _plain(poly: PackedVector2Array) -> Array:
	var out: Array = []
	for point: Vector2 in poly:
		out.append(_a2(point))
	return out
static func _a2(value: Vector2) -> Array[float]:
	return [value.x, value.y]
static func _a3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
static func _v2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	var row: Array = value
	return Vector2(MapLayoutCanonical.float_value(row[0]), MapLayoutCanonical.float_value(row[1]))
static func _v3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	var row: Array = value
	return Vector3(MapLayoutCanonical.float_value(row[0]), MapLayoutCanonical.float_value(row[1]), MapLayoutCanonical.float_value(row[2]))
static func _xz(value: Vector3) -> Vector2:
	return Vector2(value.x, value.z)
static func _f(value: Variant) -> float:
	return MapLayoutCanonical.float_value(value)
static func _i(value: Variant) -> int:
	return MapLayoutCanonical.int_value(value)
