class_name MapLayoutInput
extends RefCounted
## Immutable plain-data input for Map Compiler v2. Construction validates and
## canonicalises; every accessor returns a deep copy.

const SCHEMA_VERSION: int = 1
const HERO_ANCHOR_SCHEMA_VERSION: int = 1
const _NONE: PackedStringArray = []
const _FIELDS: PackedStringArray = [
	"schema_version", "generator_schema", "generator_version", "nodes", "edges",
	"act", "run_seed", "scenery_seed", "asset_profile_digest",
	"camera_profile_digest", "hero_anchor_contract", "quality_registry_digest",
]
const _NODE_FIELDS: PackedStringArray = ["id", "row", "col", "type", "jitter"]
const _EDGE_FIELDS: PackedStringArray = ["id", "from", "to"]
const _DIGEST_FIELDS: PackedStringArray = [
	"asset_profile_digest", "camera_profile_digest", "quality_registry_digest",
]
const _GENERATOR_FIELDS: PackedStringArray = ["generator_schema", "generator_version"]
const _SEED_FIELDS: PackedStringArray = ["run_seed", "scenery_seed"]
const _HERO_CONTAINER_FIELDS: PackedStringArray = ["anchors", "protected_zones"]

var _data: Dictionary = {}


func _init(data: Dictionary = {}) -> void:
	_data = data.duplicate(true)


static func from_dict(raw: Dictionary) -> MapLayoutInput:
	if not validate_dict(raw).is_empty():
		return null
	return MapLayoutInput.new(_normalise(raw))


static func validate_dict(raw: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	MapLayoutCanonical.validate(raw, "input", errors)
	MapLayoutCanonical.fields(raw, _FIELDS, _NONE, "input", errors)
	if raw.get("schema_version", null) != SCHEMA_VERSION:
		errors.append("input.schema_version is unsupported")
	for field: String in _GENERATOR_FIELDS:
		if not MapLayoutCanonical.nonempty(raw.get(field, null)):
			errors.append("input.%s must be non-empty" % field)
	_validate_nodes(raw.get("nodes", null), errors)
	_validate_edges(raw.get("edges", null), raw.get("nodes", null), errors)
	if typeof(raw.get("act", null)) != TYPE_INT or int(raw.get("act", -1)) < 0:
		errors.append("input.act must be a non-negative int")
	for field: String in _SEED_FIELDS:
		if typeof(raw.get(field, null)) != TYPE_INT:
			errors.append("input.%s must be an int" % field)
	for field: String in _DIGEST_FIELDS:
		if not MapLayoutCanonical.sha256_text(raw.get(field, null)):
			errors.append("input.%s must be lowercase SHA-256" % field)
	_validate_hero_contract(raw.get("hero_anchor_contract", null), errors)
	return errors


static func edge_id(from_id: String, to_id: String) -> String:
	return "%d:%s>%d:%s" % [
		from_id.to_utf8_buffer().size(), from_id,
		to_id.to_utf8_buffer().size(), to_id,
	]


func to_dict() -> Dictionary:
	return _data.duplicate(true)


func canonical_bytes() -> PackedByteArray:
	return MapLayoutCanonical.canonical_bytes(_data)


func digest() -> String:
	return MapLayoutCanonical.digest(_data)


func node_records() -> Array:
	var rows: Array = _data.get("nodes", [])
	return rows.duplicate(true)


func edge_records() -> Array:
	var rows: Array = _data.get("edges", [])
	return rows.duplicate(true)


static func _validate_nodes(value: Variant, errors: Array[String]) -> void:
	if typeof(value) != TYPE_ARRAY:
		errors.append("input.nodes must be a non-empty Array")
		return
	var rows: Array = value
	if rows.is_empty():
		errors.append("input.nodes must be a non-empty Array")
		return
	var seen: Dictionary = {}
	for i: int in range(rows.size()):
		if typeof(rows[i]) != TYPE_DICTIONARY:
			errors.append("input.nodes[%d] must be a Dictionary" % i)
			continue
		var row: Dictionary = rows[i]
		var path: String = "input.nodes[%d]" % i
		MapLayoutCanonical.fields(row, _NODE_FIELDS, _NONE, path, errors)
		var id: String = str(row.get("id", ""))
		if id.is_empty() or seen.has(id):
			errors.append("%s.id must be non-empty and unique" % path)
		seen[id] = true
		if typeof(row.get("row", null)) != TYPE_INT or int(row.get("row", -1)) < 0:
			errors.append("%s.row must be a non-negative int" % path)
		if typeof(row.get("col", null)) != TYPE_INT or int(row.get("col", -1)) < 0:
			errors.append("%s.col must be a non-negative int" % path)
		if not MapLayoutCanonical.nonempty(row.get("type", null)):
			errors.append("%s.type must be non-empty" % path)
		if not MapLayoutCanonical.vector(row.get("jitter", null), 2):
			errors.append("%s.jitter must be a finite numeric Array[2]" % path)


static func _validate_edges(
	value: Variant, nodes_v: Variant, errors: Array[String]
) -> void:
	if typeof(value) != TYPE_ARRAY:
		errors.append("input.edges must be a non-empty Array")
		return
	var rows: Array = value
	if rows.is_empty():
		errors.append("input.edges must be a non-empty Array")
		return
	var node_ids: Dictionary = {}
	if typeof(nodes_v) == TYPE_ARRAY:
		var node_rows: Array = nodes_v
		for node_v: Variant in node_rows:
			if typeof(node_v) == TYPE_DICTIONARY:
				var node: Dictionary = node_v
				node_ids[str(node.get("id", ""))] = true
	var seen: Dictionary = {}
	for i: int in range(rows.size()):
		if typeof(rows[i]) != TYPE_DICTIONARY:
			errors.append("input.edges[%d] must be a Dictionary" % i)
			continue
		var edge: Dictionary = rows[i]
		var path: String = "input.edges[%d]" % i
		MapLayoutCanonical.fields(edge, _EDGE_FIELDS, _NONE, path, errors)
		var id: String = str(edge.get("id", ""))
		var from_id: String = str(edge.get("from", ""))
		var to_id: String = str(edge.get("to", ""))
		if id.is_empty() or seen.has(id):
			errors.append("%s.id must be non-empty and unique" % path)
		seen[id] = true
		if from_id.is_empty() or to_id.is_empty() or from_id == to_id:
			errors.append("%s endpoints must be non-empty and distinct" % path)
		if not node_ids.has(from_id) or not node_ids.has(to_id):
			errors.append("%s has an unknown endpoint" % path)
		if id != edge_id(from_id, to_id):
			errors.append("%s.id is not canonical" % path)


static func _validate_hero_contract(value: Variant, errors: Array[String]) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("input.hero_anchor_contract must be a Dictionary")
		return
	var contract: Dictionary = value
	if contract.get("schema_version", null) != HERO_ANCHOR_SCHEMA_VERSION:
		errors.append("input.hero_anchor_contract.schema_version is unsupported")
	for field: String in _HERO_CONTAINER_FIELDS:
		if typeof(contract.get(field, null)) != TYPE_DICTIONARY:
			errors.append("input.hero_anchor_contract.%s must be a Dictionary" % field)
		else:
			var rows: Dictionary = contract[field]
			if rows.is_empty():
				errors.append("input.hero_anchor_contract.%s must not be empty" % field)


static func _normalise(raw: Dictionary) -> Dictionary:
	var out: Dictionary = raw.duplicate(true)
	out["nodes"] = _sorted_records(raw.get("nodes", []))
	out["edges"] = _sorted_records(raw.get("edges", []))
	return MapLayoutCanonical.ordered_dictionary(out)


static func _sorted_records(value: Variant) -> Array:
	var raw: Array = value
	var by_id: Dictionary = {}
	for row_v: Variant in raw:
		var row: Dictionary = row_v
		by_id[str(row.get("id", ""))] = row.duplicate(true)
	var out: Array = []
	for id: String in MapLayoutCanonical.sorted_keys(by_id):
		out.append(by_id[id])
	return out
