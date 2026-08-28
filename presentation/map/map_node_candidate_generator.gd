class_name MapNodeCandidateGenerator
extends RefCounted
## #467 pure, bounded per-node alternatives. It never selects a map combination.
@warning_ignore_start("unsafe_call_argument")
const SCHEMA_VERSION: int = 1
const VERSION: String = "map-node-candidates-v1"
const MAX_CANDIDATES_PER_NODE: int = 9
const _SLOTS: Array[Vector2] = [
	Vector2.ZERO, Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP,
	Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1),
]

static func generate(input: MapLayoutInput, quality: Dictionary, restart_id: int) -> Dictionary:
	var report: Dictionary = {"schema_version": SCHEMA_VERSION, "version": VERSION,
		"input_digest": "" if input == null else input.digest(), "graph_digest": "",
		"asset_profile_digest": "", "camera_profile_digest": "",
		"quality_registry_digest": MapLayoutCanonical.digest(quality), "restart_id": restart_id,
		"seed_stream_scope": "run+scenery+restart+node; graph-local identity excluded",
		"limits": {"proposals_per_node": _SLOTS.size(),
			"max_candidates_per_node": MAX_CANDIDATES_PER_NODE},
		"node_sets": {}, "impossibilities": [], "errors": []}
	var errors: Array = report["errors"]
	if input == null:
		errors.append("input is null")
		return _finish(report)
	var source: Dictionary = input.to_dict()
	var nodes: Array = input.node_records()
	var edges: Array = input.edge_records()
	report["graph_digest"] = MapLayoutCanonical.digest({"nodes": nodes, "edges": edges})
	report["asset_profile_digest"] = source["asset_profile_digest"]
	report["camera_profile_digest"] = source["camera_profile_digest"]
	if restart_id < 0:
		errors.append("restart_id must be non-negative")
	if str(source["quality_registry_digest"]) != str(report["quality_registry_digest"]):
		errors.append("quality_registry_digest mismatch")
	var calibration: Dictionary = quality["calibration"]["stage_zoom_geometry"]
	if not _v2(calibration["cell_m"]).is_equal_approx(MapPinProjection.CELL):
		errors.append("quality cell_m disagrees with MapPinProjection")
	if not _v2(calibration["origin_xz_m"]).is_equal_approx(MapPinProjection.ORIGIN_XZ):
		errors.append("quality origin_xz_m disagrees with MapPinProjection")
	if not _v2(calibration["authored_jitter_fraction"]).is_equal_approx(WorldMap.JITTER_SPREAD):
		errors.append("quality jitter bounds disagree with WorldMap")
	if not errors.is_empty():
		return _finish(report)
	var stage: Rect2 = MapPinProjection.lattice_footprint()
	var bounds: Dictionary = _bounds(nodes, edges, quality)
	var sets: Dictionary = {}
	var impossible: Array = report["impossibilities"]
	for node: Dictionary in nodes:
		var row: Dictionary = _node_set(node, source, quality, restart_id, stage, bounds)
		sets[str(node["id"])] = row
		var candidates: Array = row["candidates"]
		if candidates.is_empty():
			var rejections: Array = row["rejections"]
			impossible.append({"node_id": node["id"], "attempted": rejections.size(),
				"reason_ids": _reason_ids(rejections)})
	report["node_sets"] = sets
	return _finish(report)

static func _bounds(nodes: Array, edges: Array,
		quality: Dictionary) -> Dictionary:
	return MapQualityEvaluator.node_candidate_bounds(nodes, edges, quality)

static func _node_set(node: Dictionary, source: Dictionary, quality: Dictionary,
		restart_id: int, stage: Rect2, bounds: Dictionary) -> Dictionary:
	var id: String = str(node["id"])
	var limit: Dictionary = bounds[id]
	var base: Vector3 = limit["base"]
	var envelope: Dictionary = quality["geometry"]["row_lane_envelope"]
	var row_half: float = _f(envelope["row_half_extent_m"])
	var lane_half: float = _f(envelope["lane_half_extent_m"])
	var fixed: String = _fixed(str(node["type"]))
	var stream: String = MapLayoutCanonical.digest({"version": VERSION,
		"run_seed": source["run_seed"], "scenery_seed": source["scenery_seed"],
		"restart_id": restart_id, "node": node})
	var candidates: Array = []
	var rejections: Array = []
	for slot: int in range(_SLOTS.size()):
		var offset: Vector2 = Vector2.ZERO
		if slot > 0:
			var scale: float = lerpf(0.58, 0.94, _unit(stream, slot))
			offset = Vector2(_SLOTS[slot].x * row_half * scale,
				_SLOTS[slot].y * lane_half * scale)
		var anchor: Vector3 = base + Vector3(offset.x, 0.0, offset.y)
		var record: Dictionary = _record(id, slot, anchor, base)
		var reasons: Array = _reasons(node, anchor, base, limit, source, quality, stage)
		if reasons.is_empty():
			candidates.append(record)
		else:
			record["reasons"] = reasons
			rejections.append(record)
	return {"node_id": id, "node_type": node["type"], "row": node["row"],
		"col": node["col"], "fixed_contract": fixed, "authored_anchor": _a3(base),
		"envelope": {"id": "row-%02d/lane-%02d" % [node["row"], node["col"]],
			"row_x_m": [base.x - row_half, base.x + row_half],
			"lane_z_m": [base.z - lane_half, base.z + lane_half],
			"legal_x_m": [limit["min_x"], limit["max_x"]],
			"legal_z_m": [limit["min_z"], limit["max_z"]],
			"minimum_forward_progress_m": envelope["minimum_forward_progress_m"]},
		"stream_digest": stream, "candidates": candidates, "rejections": rejections}

static func _reasons(node: Dictionary, anchor: Vector3, base: Vector3, limit: Dictionary,
		source: Dictionary, quality: Dictionary, stage: Rect2) -> Array:
	var out: Array = []
	var epsilon: float = _f(quality["epsilon"]["world_m"])
	if not is_finite(anchor.x) or not is_finite(anchor.y) or not is_finite(anchor.z):
		return [{"id": "non_finite_geometry"}]
	var fixed: String = _fixed(str(node["type"]))
	if not fixed.is_empty() and not anchor.is_equal_approx(base):
		out.append({"id": "immutable_anchor", "contract": fixed})
	var jitter: Vector2 = _v2(node["jitter"])
	if absf(jitter.x) > WorldMap.JITTER_SPREAD.x * 0.5 + epsilon \
			or absf(jitter.y) > WorldMap.JITTER_SPREAD.y * 0.5 + epsilon:
		out.append({"id": "authored_jitter_out_of_bounds", "jitter": _a2(jitter)})
	if anchor.x < stage.position.x - epsilon or anchor.x > stage.end.x + epsilon \
			or anchor.z < stage.position.y - epsilon or anchor.z > stage.end.y + epsilon:
		out.append({"id": "stage_lattice_bounds"})
	var envelope: Dictionary = quality["geometry"]["row_lane_envelope"]
	if absf(anchor.x - base.x) > _f(envelope["row_half_extent_m"]) + epsilon \
			or absf(anchor.z - base.z) > _f(envelope["lane_half_extent_m"]) + epsilon:
		out.append({"id": "row_lane_envelope"})
	if anchor.x < _f(limit["min_x"]) - epsilon or anchor.x > _f(limit["max_x"]) + epsilon:
		out.append({"id": "journey_order", "legal_x_m": [limit["min_x"], limit["max_x"]]})
	if anchor.z < _f(limit["min_z"]) - epsilon or anchor.z > _f(limit["max_z"]) + epsilon:
		out.append({"id": "lane_stage_bounds", "legal_z_m": [limit["min_z"], limit["max_z"]]})
	var footprint: PackedVector2Array = MapQualityEvaluator._node_world(anchor, quality)
	var zones: Dictionary = source["hero_anchor_contract"]["protected_zones"]
	for zone_id: String in MapLayoutCanonical.sorted_keys(zones):
		var zone: Dictionary = zones[zone_id]
		var role: String = str(zone.get("role", "no-go"))
		if _exempt(str(node["type"]), role):
			continue
		var polygon: PackedVector2Array = MapQualityEvaluator._poly(zone["polygon"])
		var key: String = "%s_protected_zone" % role
		var padding: float = (_f(quality["geometry"][key]["padding_m"])
			if quality["geometry"].has(key) else maxf(0.0, _f(zone.get("padding_m", 0.0))))
		var distance: float = MapQualityEvaluator._polygon_distance(polygon, footprint)
		if distance + epsilon < padding or (padding <= epsilon and distance <= epsilon):
			out.append({"id": "hero_no_go_region", "zone_id": zone_id, "role": role,
				"distance_m": distance, "required_clearance_m": padding})
	return out

static func _fixed(node_type: String) -> String:
	return "boss" if node_type == "boss" else ("entrance" if node_type in ["act4", "entrance"] else "")
static func _exempt(node_type: String, role: String) -> bool:
	return (node_type == "boss" and role == "terminus") \
		or (node_type in ["act4", "entrance"] and role == "vigil")
static func _record(id: String, slot: int, anchor: Vector3, base: Vector3) -> Dictionary:
	var delta: Vector2 = Vector2(anchor.x - base.x, anchor.z - base.z)
	return {"id": "%d:%s/c%02d" % [id.to_utf8_buffer().size(), id, slot],
		"proposal_index": slot, "anchor": _a3(anchor), "delta_xz_m": _a2(delta),
		"displacement_m": delta.length(), "displacement_cost_m2": delta.length_squared()}
static func _unit(stream: String, slot: int) -> float:
	var digest: String = MapLayoutCanonical.digest({"stream": stream, "slot": slot})
	return float(digest.substr(0, 8).hex_to_int()) / 4294967295.0
static func _reason_ids(rejections: Array) -> Array[String]:
	var seen: Dictionary = {}
	for rejection: Dictionary in rejections:
		for reason: Dictionary in rejection["reasons"]:
			seen[str(reason["id"])] = true
	return MapLayoutCanonical.sorted_keys(seen)
static func _finish(report: Dictionary) -> Dictionary:
	report["candidate_digest"] = MapLayoutCanonical.digest(report)
	return MapLayoutCanonical.ordered_dictionary(report)
static func _v2(value: Variant) -> Vector2:
	var row: Array = value
	return Vector2(_f(row[0]), _f(row[1]))
static func _a2(value: Vector2) -> Array[float]: return [value.x, value.y]
static func _a3(value: Vector3) -> Array[float]: return [value.x, value.y, value.z]
static func _f(value: Variant) -> float: return MapLayoutCanonical.float_value(value)
