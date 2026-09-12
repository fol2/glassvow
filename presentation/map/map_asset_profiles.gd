class_name MapAssetProfiles
extends RefCounted
## Pure map-mesh occupancy authority shared by runtime, compiler and probes (#465).
##
## The local footprint is a conservative rectangle projected from the mesh AABB.
## It stays elongated for walls, roots and arches; it is not collapsed to the
## build-4 circle. `directional_envelope` is the compatibility adapter for the
## current MapPinProjection contract. It deliberately preserves the existing
## symmetric max(X,Z) clearance until #466 consumes polygons directly. That is
## conservative around rotated long assets and is a named residual for #481.
##
## Construction reads metadata only. Meshes are supplied by the caller, so the
## runtime profiles only the active act while headless tools may choose a wider set.

const MANIFEST_PATH: String = "res://assets/art/map/map-assets.json"
const ASSET_ROOT: String = "res://assets/art/map/"
const PROFILE_SCHEMA_VERSION: int = 1
const HIDE_PER_HEIGHT: float = 1.19
const OCCLUSION_MODEL: String = "build4-symmetric-directional-v1"

const SEMANTIC_ROAD: String = "road"
const SEMANTIC_SCENERY: String = "scenery"
const SEMANTIC_HERO: String = "hero"
const SEMANTIC_ARCH_PASSABLE: String = "arch_passable"

const YAW_FREE: String = "free"
const YAW_ROAD_ALIGNED: String = "road_aligned"
const YAW_FIXED: String = "fixed"

var _rows: Dictionary[String, Dictionary] = {}
var _ordered_ids: PackedStringArray = PackedStringArray()
var _defaults: Dictionary[String, Dictionary] = {}
var _overrides: Dictionary[String, Dictionary] = {}
var _asset_root: String = ASSET_ROOT


func _init(manifest: Dictionary = {}, asset_root: String = ASSET_ROOT) -> void:
	_asset_root = asset_root
	var source: Dictionary = manifest.duplicate(true)
	if source.is_empty():
		source = _read_manifest()
	var raw_assets: Variant = source.get("assets", [])
	if raw_assets is Array:
		var assets: Array = raw_assets
		for raw_row: Variant in assets:
			if not (raw_row is Dictionary):
				continue
			var row: Dictionary = raw_row
			var asset_id: String = _string_value(row, "id")
			var kind: String = _string_value(row, "kind")
			if asset_id.is_empty() or not _is_mesh_kind(kind):
				continue
			_rows[asset_id] = row.duplicate(true)
			_ordered_ids.append(asset_id)
	var raw_defaults: Variant = source.get("profile_defaults", {})
	if raw_defaults is Dictionary:
		var defaults: Dictionary = raw_defaults
		for raw_id: Variant in defaults.keys():
			var asset_id: String = str(raw_id)
			var raw_default: Variant = defaults.get(raw_id)
			if raw_default is Dictionary:
				var value: Dictionary = raw_default
				_defaults[asset_id] = value.duplicate(true)
	var raw_overrides: Variant = source.get("profile_overrides", {})
	if raw_overrides is Dictionary:
		var overrides: Dictionary = raw_overrides
		for raw_id: Variant in overrides.keys():
			var asset_id: String = str(raw_id)
			var raw_override: Variant = overrides.get(raw_id)
			if raw_override is Dictionary:
				var value: Dictionary = raw_override
				_overrides[asset_id] = value.duplicate(true)


func all_ids() -> PackedStringArray:
	return _ordered_ids.duplicate()


func ids_for_act(act: int, kind_filter: String = "") -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for asset_id: String in _ordered_ids:
		var row: Dictionary = _rows[asset_id]
		var row_act: int = _int_value(row, "act", -99)
		var kind: String = _string_value(row, "kind")
		if row_act in [-1, act] and (kind_filter.is_empty() or kind == kind_filter):
			out.append(asset_id)
	return out


func resource_path(asset_id: String) -> String:
	if not _rows.has(asset_id):
		return ""
	var row: Dictionary = _rows[asset_id]
	return _asset_root + _string_value(row, "path")


func profile(asset_id: String, mesh: Mesh) -> Dictionary:
	if asset_id.is_empty() or mesh == null or not _rows.has(asset_id):
		return {}
	if not _defaults.has(asset_id):
		return {}
	var defaults: Dictionary = _defaults[asset_id]
	var scale: float = _float_value(defaults, "scale", 0.0)
	var semantic_class: String = _string_value(defaults, "semantic_class")
	var yaw_mode: String = _string_value(defaults, "yaw_mode")
	var yaw_degrees: float = _float_value(defaults, "yaw_degrees", 0.0)
	if not _valid_defaults(scale, semantic_class, yaw_mode, yaw_degrees):
		return {}
	var local_aabb: AABB = mesh.get_aabb()
	if not _finite_nonempty_aabb(local_aabb):
		return {}
	var footprint: PackedVector2Array = _aabb_footprint(local_aabb)
	var footprint_source: String = "mesh_aabb_obb"
	var override_reason: String = ""
	if _overrides.has(asset_id):
		var override: Dictionary = _overrides[asset_id]
		var canonical: Dictionary = canonical_polygon(override.get("footprint", null))
		override_reason = _string_value(override, "reason").strip_edges()
		var raw_points: Variant = canonical.get("points", PackedVector2Array())
		if not _bool_value(canonical, "ok", false) or override_reason.is_empty() \
				or not (raw_points is PackedVector2Array):
			return {}
		footprint = raw_points
		footprint_source = "manifest_override"
	var source_identity: String = _source_identity(asset_id, mesh, local_aabb)
	if source_identity.length() != 64:
		return {}
	return {
		"profile_schema_version": PROFILE_SCHEMA_VERSION,
		"asset_id": asset_id,
		"source_path": resource_path(asset_id),
		"source_mesh_identity": source_identity,
		"local_aabb": local_aabb,
		"grounded_height": local_aabb.size.y,
		"local_footprint": footprint,
		"footprint_source": footprint_source,
		"override_reason": override_reason,
		"default_scale": scale,
		"yaw_mode": yaw_mode,
		"yaw_degrees": yaw_degrees,
		"semantic_class": semantic_class,
		"occlusion_model": OCCLUSION_MODEL,
	}


## Rotate, translate and non-uniformly scale the canonical local-XZ polygon.
## Invalid or mirrored scale fails closed rather than silently changing winding.
func transformed_footprint(value: Dictionary, position: Vector3,
		yaw_degrees: float, scale: Vector3) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var raw_points: Variant = value.get("local_footprint", PackedVector2Array())
	if not (raw_points is PackedVector2Array):
		return out
	if not _finite_vector3(position) or not is_finite(yaw_degrees) \
			or not _positive_vector3(scale):
		return out
	var points: PackedVector2Array = raw_points
	var basis: Basis = Basis(Vector3.UP, deg_to_rad(yaw_degrees)).scaled_local(scale)
	var transform: Transform3D = Transform3D(basis, position)
	for point: Vector2 in points:
		var world: Vector3 = transform * Vector3(point.x, 0.0, point.y)
		out.append(Vector2(world.x, world.z))
	return out


## Build-4 compatibility envelope consumed by MapPinProjection: centre X/Z,
## symmetric footprint radius, then directional hide depth.
func directional_envelope(value: Dictionary, position: Vector3) -> Vector4:
	var raw_aabb: Variant = value.get("local_aabb", AABB())
	if not (raw_aabb is AABB) or not _finite_vector3(position):
		return Vector4.ZERO
	var local_aabb: AABB = raw_aabb
	var scale: float = default_scale(value)
	var height: float = _float_value(value, "grounded_height", 0.0)
	if not _finite_nonempty_aabb(local_aabb) or scale <= 0.0 \
			or not is_finite(scale) or height <= 0.0 or not is_finite(height):
		return Vector4.ZERO
	var radius: float = maxf(local_aabb.size.x, local_aabb.size.z) * 0.5 * scale
	return Vector4(position.x, position.z, radius, height * scale * HIDE_PER_HEIGHT)


func default_scale(value: Dictionary) -> float:
	return _float_value(value, "default_scale", 0.0)


func fixed_yaw(value: Dictionary, fallback: float = 0.0) -> float:
	if _string_value(value, "yaw_mode") != YAW_FIXED:
		return fallback
	return _float_value(value, "yaw_degrees", fallback)


## Digest is independent of caller order and never serialises a Dictionary.
func digest(values: Array[Dictionary]) -> String:
	var by_id: Dictionary[String, Dictionary] = {}
	var ids: PackedStringArray = PackedStringArray()
	for value: Dictionary in values:
		var asset_id: String = _string_value(value, "asset_id")
		if asset_id.is_empty() or by_id.has(asset_id):
			return ""
		by_id[asset_id] = value
		ids.append(asset_id)
	ids.sort()
	var canonical: Array = [PROFILE_SCHEMA_VERSION]
	for asset_id: String in ids:
		var row: Array = _digest_row(by_id[asset_id])
		if row.is_empty():
			return ""
		canonical.append(row)
	return _hash(canonical)


static func canonical_polygon(raw: Variant) -> Dictionary:
	var points: PackedVector2Array = PackedVector2Array()
	if raw is PackedVector2Array:
		var packed: PackedVector2Array = raw
		points = packed.duplicate()
	elif raw is Array:
		var rows: Array = raw
		for item: Variant in rows:
			if not (item is Array):
				return _polygon_error("point must be [x,z]")
			var pair: Array = item
			if pair.size() != 2 or not _is_number(pair[0]) or not _is_number(pair[1]):
				return _polygon_error("point must be two numbers")
			var point: Vector2 = Vector2(
					_number_to_float(pair[0]), _number_to_float(pair[1]))
			if not is_finite(point.x) or not is_finite(point.y):
				return _polygon_error("point must be finite")
			if points.is_empty() or not points[points.size() - 1].is_equal_approx(point):
				points.append(point)
	else:
		return _polygon_error("footprint must be an array")
	for point: Vector2 in points:
		if not is_finite(point.x) or not is_finite(point.y):
			return _polygon_error("point must be finite")
	if points.size() > 1 and points[0].is_equal_approx(points[points.size() - 1]):
		points.remove_at(points.size() - 1)
	if points.size() < 3:
		return _polygon_error("footprint needs at least three points")
	for i: int in range(points.size()):
		for j: int in range(i + 1, points.size()):
			if points[i].is_equal_approx(points[j]):
				return _polygon_error("footprint contains a duplicate point")
	var signed_area: float = 0.0
	var turn_sign: float = 0.0
	for i: int in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		var c: Vector2 = points[(i + 2) % points.size()]
		signed_area += a.cross(b)
		var turn: float = (b - a).cross(c - b)
		if absf(turn) <= 0.000001:
			continue
		if turn_sign != 0.0 and signf(turn) != signf(turn_sign):
			return _polygon_error("footprint must be convex")
		turn_sign = turn
	if absf(signed_area) <= 0.000001 or turn_sign == 0.0:
		return _polygon_error("footprint has zero area")
	if signed_area > 0.0:
		var reversed: PackedVector2Array = PackedVector2Array()
		for i: int in range(points.size() - 1, -1, -1):
			reversed.append(points[i])
		points = reversed
	var first: int = 0
	for i: int in range(1, points.size()):
		if points[i].x < points[first].x or (is_equal_approx(points[i].x, points[first].x) \
				and points[i].y < points[first].y):
			first = i
	var canonical: PackedVector2Array = PackedVector2Array()
	for i: int in range(points.size()):
		canonical.append(points[(first + i) % points.size()])
	return {"ok": true, "points": canonical, "error": ""}


func _digest_row(value: Dictionary) -> Array:
	var raw_aabb: Variant = value.get("local_aabb", AABB())
	var raw_points: Variant = value.get("local_footprint", PackedVector2Array())
	if not (raw_aabb is AABB) or not (raw_points is PackedVector2Array):
		return []
	var local_aabb: AABB = raw_aabb
	var points: PackedVector2Array = raw_points
	var scale: float = default_scale(value)
	var height: float = _float_value(value, "grounded_height", 0.0)
	var yaw_degrees: float = _float_value(value, "yaw_degrees", 0.0)
	if not _finite_nonempty_aabb(local_aabb) or points.size() < 3 \
			or scale <= 0.0 or height <= 0.0 or not is_finite(yaw_degrees):
		return []
	return [
		_string_value(value, "asset_id"),
		_string_value(value, "source_path"),
		_string_value(value, "source_mesh_identity"),
		local_aabb.position,
		local_aabb.size,
		points,
		height,
		scale,
		_string_value(value, "yaw_mode"),
		yaw_degrees,
		_string_value(value, "semantic_class"),
		_string_value(value, "footprint_source"),
		_string_value(value, "override_reason"),
		_string_value(value, "occlusion_model"),
	]


## Imported triangle faces, not engine instance IDs or raw-source availability,
## define identity. AABB and surface count remain in the canonical row, so runtime,
## primitive-mesh tests and headless tools hash the same grounded geometry.
func _source_identity(asset_id: String, mesh: Mesh, local_aabb: AABB) -> String:
	var canonical: Array = [
		resource_path(asset_id), local_aabb.position, local_aabb.size,
		mesh.get_surface_count(),
	]
	canonical.append(mesh.get_faces())
	return _hash(canonical)


static func _hash(value: Variant) -> String:
	var context: HashingContext = HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	var update_error: Error = context.update(var_to_bytes(value))
	if update_error != OK:
		return ""
	return context.finish().hex_encode()


static func _aabb_footprint(local_aabb: AABB) -> PackedVector2Array:
	var lo: Vector3 = local_aabb.position
	var hi: Vector3 = local_aabb.end
	return PackedVector2Array([
		Vector2(lo.x, lo.z),
		Vector2(lo.x, hi.z),
		Vector2(hi.x, hi.z),
		Vector2(hi.x, lo.z),
	])


static func _valid_defaults(scale: float, semantic_class: String,
		yaw_mode: String, yaw_degrees: float) -> bool:
	if scale <= 0.0 or not is_finite(scale) or not is_finite(yaw_degrees):
		return false
	if semantic_class not in [SEMANTIC_ROAD, SEMANTIC_SCENERY,
			SEMANTIC_HERO, SEMANTIC_ARCH_PASSABLE]:
		return false
	return yaw_mode in [YAW_FREE, YAW_ROAD_ALIGNED, YAW_FIXED]


static func _finite_nonempty_aabb(value: AABB) -> bool:
	return _finite_vector3(value.position) and _positive_vector3(value.size)


static func _finite_vector3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


static func _positive_vector3(value: Vector3) -> bool:
	return _finite_vector3(value) and value.x > 0.0 and value.y > 0.0 and value.z > 0.0


static func _is_mesh_kind(kind: String) -> bool:
	return kind in ["kit", "terminus", "threshold"]


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _number_to_float(value: Variant) -> float:
	if value is float:
		var decimal: float = value
		return decimal
	if value is int:
		var integer: int = value
		return float(integer)
	return NAN


static func _string_value(source: Dictionary, key: String) -> String:
	var raw: Variant = source.get(key, "")
	if raw is String:
		var value: String = raw
		return value
	return ""


static func _int_value(source: Dictionary, key: String, fallback: int) -> int:
	var raw: Variant = source.get(key, fallback)
	if raw is int:
		var integer: int = raw
		return integer
	if raw is float:
		var decimal: float = raw
		return int(decimal)
	return fallback


static func _float_value(source: Dictionary, key: String, fallback: float) -> float:
	var raw: Variant = source.get(key, fallback)
	if raw is float:
		var decimal: float = raw
		return decimal
	if raw is int:
		var integer: int = raw
		return float(integer)
	return fallback


static func _bool_value(source: Dictionary, key: String, fallback: bool) -> bool:
	var raw: Variant = source.get(key, fallback)
	if raw is bool:
		var value: bool = raw
		return value
	return fallback


static func _polygon_error(message: String) -> Dictionary:
	return {"ok": false, "points": PackedVector2Array(), "error": message}


static func _read_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary:
		var manifest: Dictionary = parsed
		return manifest
	return {}
