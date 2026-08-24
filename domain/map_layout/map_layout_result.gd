class_name MapLayoutResult
extends RefCounted
## Immutable plain-data output for Map Compiler v2. `layout_digest` hashes every
## identity field except itself. Optional runtime metadata is validated then
## dropped, so timing and engine instance identity cannot affect replay.

const SCHEMA_VERSION: int = 1
const RUNTIME_METADATA_FIELD: String = "runtime_metadata"
const _NONE: PackedStringArray = []
const _OPTIONAL: PackedStringArray = [RUNTIME_METADATA_FIELD]
const _IDENTITY_FIELDS: PackedStringArray = [
	"schema_version", "generator_version", "node_anchors", "edges",
	"hero_placements", "scenery_instances", "hard_measurements", "soft_scores",
	"selected_restart_id", "selected_candidate_id", "input_digest",
]
const _SERIAL_FIELDS: PackedStringArray = [
	"schema_version", "generator_version", "node_anchors", "edges",
	"hero_placements", "scenery_instances", "hard_measurements", "soft_scores",
	"selected_restart_id", "selected_candidate_id", "input_digest", "layout_digest",
]
const _EDGE_FIELDS: PackedStringArray = ["from", "to", "centerline", "corridor_width"]
const _HERO_FIELDS: PackedStringArray = ["asset_id", "profile_id", "transform"]
const _SCENERY_FIELDS: PackedStringArray = [
	"asset_id", "profile_id", "transform", "semantic_zone",
]
const _TRANSFORM_FIELDS: PackedStringArray = ["origin", "yaw_radians", "scale"]
const _PLACEMENT_ID_FIELDS: PackedStringArray = ["asset_id", "profile_id"]

var _data: Dictionary = {}
var _layout_digest: String = ""


func _init(data: Dictionary = {}, layout_digest: String = "") -> void:
	_data = data.duplicate(true)
	_layout_digest = layout_digest


static func create(raw: Dictionary) -> MapLayoutResult:
	if not validate_identity(raw).is_empty():
		return null
	var data: Dictionary = MapLayoutCanonical.ordered_dictionary(raw)
	return MapLayoutResult.new(data, MapLayoutCanonical.digest(data))


static func from_dict(raw: Dictionary) -> MapLayoutResult:
	if not validate_dict(raw).is_empty():
		return null
	var identity: Dictionary = _identity(raw)
	return MapLayoutResult.new(
		MapLayoutCanonical.ordered_dictionary(identity), str(raw.get("layout_digest", ""))
	)


static func validate_identity(raw: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	MapLayoutCanonical.validate(raw, "result", errors)
	MapLayoutCanonical.fields(raw, _IDENTITY_FIELDS, _NONE, "result", errors)
	_validate_payload(raw, errors)
	return errors


static func validate_dict(raw: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	MapLayoutCanonical.validate(raw, "result", errors)
	MapLayoutCanonical.fields(raw, _SERIAL_FIELDS, _OPTIONAL, "result", errors)
	if raw.has(RUNTIME_METADATA_FIELD) and typeof(raw[RUNTIME_METADATA_FIELD]) != TYPE_DICTIONARY:
		errors.append("result.runtime_metadata must be a Dictionary")
	var identity: Dictionary = _identity(raw)
	_validate_payload(identity, errors)
	if not MapLayoutCanonical.sha256_text(raw.get("layout_digest", null)):
		errors.append("result.layout_digest must be lowercase SHA-256")
	elif errors.is_empty():
		var expected_digest: String = MapLayoutCanonical.digest(
			MapLayoutCanonical.ordered_dictionary(identity)
		)
		if str(raw["layout_digest"]) != expected_digest:
			errors.append("result.layout_digest does not match canonical content")
	return errors


func to_dict() -> Dictionary:
	var out: Dictionary = _data.duplicate(true)
	out["layout_digest"] = _layout_digest
	return MapLayoutCanonical.ordered_dictionary(out)


func identity_dict() -> Dictionary:
	return _data.duplicate(true)


func identity_bytes() -> PackedByteArray:
	return MapLayoutCanonical.canonical_bytes(_data)


func canonical_bytes() -> PackedByteArray:
	return MapLayoutCanonical.canonical_bytes(to_dict())


func digest() -> String:
	return _layout_digest


static func _validate_payload(raw: Dictionary, errors: Array[String]) -> void:
	if raw.get("schema_version", null) != SCHEMA_VERSION:
		errors.append("result.schema_version is unsupported")
	if not MapLayoutCanonical.nonempty(raw.get("generator_version", null)):
		errors.append("result.generator_version must be non-empty")
	var anchors: Dictionary = _dict(raw.get("node_anchors", null), "node_anchors", errors)
	if anchors.is_empty():
		errors.append("result.node_anchors must not be empty")
	for id: String in _ids(anchors, "node_anchors", errors):
		if not MapLayoutCanonical.vector(anchors[id], 3):
			errors.append("result.node_anchors.%s must be a finite Array[3]" % id)
	_validate_edges(raw.get("edges", null), anchors, errors)
	_validate_placements(raw.get("hero_placements", null), false, errors)
	_validate_placements(raw.get("scenery_instances", null), true, errors)
	var hard: Dictionary = _dict(raw.get("hard_measurements", null), "hard_measurements", errors)
	_ids(hard, "hard_measurements", errors)
	var scores: Dictionary = _dict(raw.get("soft_scores", null), "soft_scores", errors)
	for id: String in _ids(scores, "soft_scores", errors):
		if not MapLayoutCanonical.number(scores[id]):
			errors.append("result.soft_scores.%s must be finite and numeric" % id)
	if typeof(raw.get("selected_restart_id", null)) != TYPE_INT \
			or int(raw.get("selected_restart_id", -1)) < 0:
		errors.append("result.selected_restart_id must be a non-negative int")
	if not MapLayoutCanonical.nonempty(raw.get("selected_candidate_id", null)):
		errors.append("result.selected_candidate_id must be non-empty")
	if not MapLayoutCanonical.sha256_text(raw.get("input_digest", null)):
		errors.append("result.input_digest must be lowercase SHA-256")


static func _validate_edges(value: Variant, anchors: Dictionary, errors: Array[String]) -> void:
	var edges: Dictionary = _dict(value, "edges", errors)
	if edges.is_empty():
		errors.append("result.edges must not be empty")
	for id: String in _ids(edges, "edges", errors):
		if typeof(edges[id]) != TYPE_DICTIONARY:
			errors.append("result.edges.%s must be a Dictionary" % id)
			continue
		var edge: Dictionary = edges[id]
		var path: String = "result.edges.%s" % id
		MapLayoutCanonical.fields(edge, _EDGE_FIELDS, _NONE, path, errors)
		var from_id: String = str(edge.get("from", ""))
		var to_id: String = str(edge.get("to", ""))
		if from_id.is_empty() or to_id.is_empty() or from_id == to_id:
			errors.append("%s endpoints must be non-empty and distinct" % path)
		if not anchors.has(from_id) or not anchors.has(to_id):
			errors.append("%s has an unknown endpoint" % path)
		if id != MapLayoutInput.edge_id(from_id, to_id):
			errors.append("%s ID is not canonical" % path)
		var points_v: Variant = edge.get("centerline", null)
		if typeof(points_v) != TYPE_ARRAY:
			errors.append("%s.centerline needs at least two points" % path)
		else:
			var points: Array = points_v
			if points.size() < 2:
				errors.append("%s.centerline needs at least two points" % path)
				continue
			for point_v: Variant in points:
				if not MapLayoutCanonical.vector(point_v, 3):
					errors.append("%s.centerline points must be finite Array[3]" % path)
			if anchors.has(from_id) and not MapLayoutCanonical.same_vector(points[0], anchors[from_id], 3):
				errors.append("%s.centerline source does not match its anchor" % path)
			if anchors.has(to_id) and not MapLayoutCanonical.same_vector(points[-1], anchors[to_id], 3):
				errors.append("%s.centerline target does not match its anchor" % path)
		if not MapLayoutCanonical.number(edge.get("corridor_width", null), true):
			errors.append("%s.corridor_width must be finite and positive" % path)


static func _validate_placements(value: Variant, scenery: bool, errors: Array[String]) -> void:
	var label: String = "scenery_instances" if scenery else "hero_placements"
	var rows: Dictionary = _dict(value, label, errors)
	if not scenery and rows.is_empty():
		errors.append("result.hero_placements must not be empty")
	var expected: PackedStringArray = _SCENERY_FIELDS if scenery else _HERO_FIELDS
	for id: String in _ids(rows, label, errors):
		if typeof(rows[id]) != TYPE_DICTIONARY:
			errors.append("result.%s.%s must be a Dictionary" % [label, id])
			continue
		var row: Dictionary = rows[id]
		var path: String = "result.%s.%s" % [label, id]
		MapLayoutCanonical.fields(row, expected, _NONE, path, errors)
		for field: String in _PLACEMENT_ID_FIELDS:
			if not MapLayoutCanonical.nonempty(row.get(field, null)):
				errors.append("%s.%s must be non-empty" % [path, field])
		if scenery and not MapLayoutCanonical.nonempty(row.get("semantic_zone", null)):
			errors.append("%s.semantic_zone must be non-empty" % path)
		_validate_transform(row.get("transform", null), "%s.transform" % path, errors)


static func _validate_transform(value: Variant, path: String, errors: Array[String]) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("%s must be a Dictionary" % path)
		return
	var transform: Dictionary = value
	MapLayoutCanonical.fields(transform, _TRANSFORM_FIELDS, _NONE, path, errors)
	if not MapLayoutCanonical.vector(transform.get("origin", null), 3):
		errors.append("%s.origin must be a finite Array[3]" % path)
	if not MapLayoutCanonical.vector(transform.get("scale", null), 3, true):
		errors.append("%s.scale must be a positive finite Array[3]" % path)
	if not MapLayoutCanonical.number(transform.get("yaw_radians", null)):
		errors.append("%s.yaw_radians must be finite and numeric" % path)


static func _dict(value: Variant, label: String, errors: Array[String]) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("result.%s must be a Dictionary" % label)
		return {}
	return value


static func _ids(rows: Dictionary, label: String, errors: Array[String]) -> Array[String]:
	var ids: Array[String] = []
	for id_v: Variant in rows.keys():
		if typeof(id_v) != TYPE_STRING or str(id_v).is_empty():
			errors.append("result.%s has an empty or non-string ID" % label)
			continue
		ids.append(str(id_v))
	ids.sort()
	return ids


static func _identity(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for field: String in _IDENTITY_FIELDS:
		if raw.has(field):
			out[field] = raw[field]
	return out
