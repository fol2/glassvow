class_name MapAssetProfiles
extends RefCounted
## Pure map-mesh occupancy authority shared by runtime, compiler and probes (#465).
const MANIFEST_PATH: String = "res://assets/art/map/map-assets.json"
const ASSET_ROOT: String = "res://assets/art/map/"
const PROFILE_SCHEMA: int = 1
## MapPinProjection still consumes build-4's symmetric envelope. The polygon is
## the compiler fact; #466/#481 own replacing this conservative compatibility adapter.
const HIDE_PER_HEIGHT: float = 1.19
const MESH_KINDS: PackedStringArray = ["kit", "terminus", "threshold"]
var _rows: Dictionary[String, Dictionary] = {}
var _order: PackedStringArray = []
var _slots: Dictionary[String, int] = {}
var _policy: Dictionary = {}

func _init(manifest: Dictionary = {}) -> void:
	var source: Dictionary = manifest if not manifest.is_empty() else _read_manifest()
	var policy_v: Variant = source.get("profile_policy", {})
	if policy_v is Dictionary:
		_policy = (policy_v as Dictionary).duplicate(true)
	var raw: Variant = source.get("assets", [])
	if not (raw is Array): return
	var rows: Array = raw
	var next_slot: Dictionary[int, int] = {-1: 0, 0: 3, 1: 3, 2: 3, 3: 3}
	for item: Variant in rows:
		if not (item is Dictionary): continue
		var row: Dictionary = item
		var asset_id: String = str(row.get("id", "")); var kind: String = str(row.get("kind", ""))
		if asset_id.is_empty() or kind not in MESH_KINDS: continue
		_rows[asset_id] = row.duplicate(true); _order.append(asset_id)
		if kind == "kit":
			var act: int = int(row.get("act", -99)); _slots[asset_id] = next_slot.get(act, -1)
			next_slot[act] = _slots[asset_id] + 1

func all_ids() -> PackedStringArray: return _order.duplicate()
func ids_for_act(act: int, kind: String = "") -> PackedStringArray:
	var out: PackedStringArray = []
	for asset_id: String in _order:
		var row: Dictionary = _rows[asset_id]
		if int(row.get("act", -99)) in [-1, act] and (kind.is_empty() or str(row.get("kind", "")) == kind): out.append(asset_id)
	return out
func resource_path(asset_id: String) -> String: return ASSET_ROOT + str(_rows.get(asset_id, {}).get("path", ""))

func profile(asset_id: String, mesh: Mesh) -> Dictionary:
	if asset_id.is_empty() or mesh == null or not _rows.has(asset_id): return {}
	var box: AABB = mesh.get_aabb(); var authored: Dictionary = _authored(asset_id, _rows[asset_id])
	var scale: float = float(authored.get("default_scale", 0.0))
	if not _finite_aabb(box) or scale <= 0.0 or not is_finite(scale): return {}
	var footprint: PackedVector2Array = _box_footprint(box); var source: String = "mesh_aabb_obb"; var reason: String = ""
	var overrides_v: Variant = _policy.get("overrides", {})
	if overrides_v is Dictionary:
		var overrides: Dictionary = overrides_v
		if overrides.has(asset_id):
			var override_v: Variant = overrides.get(asset_id)
			if not (override_v is Dictionary): return {}
			var override: Dictionary = override_v; var canonical: Dictionary = canonical_polygon(override.get("footprint"))
			reason = str(override.get("reason", "")).strip_edges(); var points_v: Variant = canonical.get("points", PackedVector2Array())
			if not bool(canonical.get("ok", false)) or reason.is_empty() or not (points_v is PackedVector2Array): return {}
			footprint = points_v; source = "manifest_override"
	return {"asset_id": asset_id, "source_path": resource_path(asset_id),
		"source_mesh_identity": _source_identity(asset_id, box), "local_aabb": box,
		"grounded_height": box.size.y, "local_footprint": footprint, "footprint_source": source,
		"override_reason": reason, "default_scale": scale, "yaw_policy": authored.get("yaw_policy", {}),
		"semantic_class": authored.get("semantic_class", ""), "occlusion_model": "build4_symmetric_directional_v1"}

func world_footprint(value: Dictionary, transform: Transform3D) -> PackedVector2Array:
	var raw: Variant = value.get("local_footprint", PackedVector2Array()); var out: PackedVector2Array = []
	if not (raw is PackedVector2Array): return out
	for point: Vector2 in raw:
		var world: Vector3 = transform * Vector3(point.x, 0.0, point.y); out.append(Vector2(world.x, world.z))
	return out
func occlusion_piece(value: Dictionary, position: Vector3) -> Vector4:
	var box_v: Variant = value.get("local_aabb", AABB())
	if not (box_v is AABB): return Vector4.ZERO
	var box: AABB = box_v; var scale: float = default_scale(value)
	return Vector4(position.x, position.z, maxf(box.size.x, box.size.z) * 0.5 * scale, box.size.y * scale * HIDE_PER_HEIGHT)
func default_scale(value: Dictionary) -> float: return float(value.get("default_scale", 0.0))
func fixed_yaw(value: Dictionary, fallback: float = 0.0) -> float:
	var policy_v: Variant = value.get("yaw_policy", {})
	if policy_v is Dictionary:
		var policy: Dictionary = policy_v
		if str(policy.get("mode", "")) == "fixed": return float(policy.get("degrees", fallback))
	return fallback

func digest(values: Array[Dictionary]) -> String:
	var by_id: Dictionary[String, Dictionary] = {}; var ids: PackedStringArray = []
	for value: Dictionary in values:
		var asset_id: String = str(value.get("asset_id", ""))
		if asset_id.is_empty() or by_id.has(asset_id): return ""
		by_id[asset_id] = value; ids.append(asset_id)
	ids.sort(); var canonical: Array[Variant] = [PROFILE_SCHEMA]
	for asset_id: String in ids:
		var value: Dictionary = by_id[asset_id]; var box_v: Variant = value.get("local_aabb", AABB())
		if not (box_v is AABB): return ""
		var box: AABB = box_v
		canonical.append([asset_id, value.get("source_path", ""), value.get("source_mesh_identity", ""),
			box.position, box.size, value.get("local_footprint", PackedVector2Array()), value.get("grounded_height", 0.0),
			value.get("default_scale", 0.0), value.get("yaw_policy", {}), value.get("semantic_class", ""),
			value.get("footprint_source", ""), value.get("override_reason", ""), value.get("occlusion_model", "")])
	return _hash(canonical)

static func canonical_polygon(raw: Variant) -> Dictionary:
	if not (raw is Array): return _polygon_error("not an array")
	var points: PackedVector2Array = []
	for item: Variant in raw:
		if not (item is Array): return _polygon_error("invalid point")
		var pair: Array = item
		if pair.size() != 2 or not (pair[0] is int or pair[0] is float) or not (pair[1] is int or pair[1] is float): return _polygon_error("invalid point")
		var point: Vector2 = Vector2(float(pair[0]), float(pair[1]))
		if not is_finite(point.x) or not is_finite(point.y): return _polygon_error("non-finite point")
		if points.is_empty() or not points[-1].is_equal_approx(point): points.append(point)
	if points.size() > 1 and points[0].is_equal_approx(points[-1]): points.remove_at(points.size() - 1)
	if points.size() < 3: return _polygon_error("fewer than 3 points")
	for i: int in range(points.size()):
		for j: int in range(i + 1, points.size()):
			if points[i].is_equal_approx(points[j]): return _polygon_error("duplicate point")
	var area: float = 0.0; var turn: float = 0.0
	for i: int in range(points.size()):
		var a: Vector2 = points[i]; var b: Vector2 = points[(i + 1) % points.size()]
		var cross: float = (b - a).cross(points[(i + 2) % points.size()] - b); area += a.cross(b)
		if absf(cross) > 0.000001:
			if turn != 0.0 and signf(cross) != signf(turn): return _polygon_error("not convex")
			turn = cross
	if absf(area) <= 0.000001 or turn == 0.0: return _polygon_error("zero area")
	if area > 0.0: points.reverse()
	var first: int = 0
	for i: int in range(1, points.size()):
		if points[i].x < points[first].x or (is_equal_approx(points[i].x, points[first].x) and points[i].y < points[first].y): first = i
	var out: PackedVector2Array = []
	for i: int in range(points.size()): out.append(points[(first + i) % points.size()])
	return {"ok": true, "points": out, "error": ""}

func _authored(asset_id: String, row: Dictionary) -> Dictionary:
	var kind: String = str(row.get("kind", "")); var roads_v: Variant = _policy.get("road_ids", []); var arches_v: Variant = _policy.get("arch_passable_ids", [])
	var roads: Array = []; var arches: Array = []
	if roads_v is Array: roads = roads_v
	if arches_v is Array: arches = arches_v
	var road: bool = asset_id in roads; var arch: bool = asset_id in arches
	var semantic: String = "road" if road else ("hero" if kind != "kit" else ("arch_passable" if arch else "scenery"))
	var scale: float = float(_policy.get("terminus_scale" if kind == "terminus" else ("threshold_scale" if kind == "threshold" else "missing"), 0.0))
	if kind == "kit":
		var scales_v: Variant = _policy.get("kit_scales", []); var slot: int = _slots.get(asset_id, -1)
		if scales_v is Array:
			var scales: Array = scales_v
			if slot >= 0 and slot < scales.size(): scale = float(scales[slot])
	var yaw: Dictionary = {"mode": "road_aligned" if road else "free"}
	if kind in ["terminus", "threshold"]: yaw = {"mode": "fixed", "degrees": float(_policy.get("threshold_yaw_degrees", 0.0)) if kind == "threshold" else 0.0}
	return {"default_scale": scale, "yaw_policy": yaw, "semantic_class": semantic}

static func _box_footprint(box: AABB) -> PackedVector2Array:
	var lo: Vector3 = box.position; var hi: Vector3 = box.end
	return PackedVector2Array([Vector2(lo.x, lo.z), Vector2(lo.x, hi.z), Vector2(hi.x, hi.z), Vector2(hi.x, lo.z)])
static func _finite_aabb(box: AABB) -> bool:
	return box.size.x > 0.0 and box.size.y > 0.0 and box.size.z > 0.0 and is_finite(box.position.x) and is_finite(box.position.y) and is_finite(box.position.z) and is_finite(box.size.x) and is_finite(box.size.y) and is_finite(box.size.z)
func _source_identity(asset_id: String, box: AABB) -> String:
	var path: String = resource_path(asset_id)
	if FileAccess.file_exists(path): return _hash(FileAccess.get_file_as_bytes(path))
	var shape: Array[Variant] = [path, box.position, box.size]
	return _hash(shape)
static func _hash(value: Variant) -> String:
	var context: HashingContext = HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(var_to_bytes(value)); return context.finish().hex_encode()
static func _polygon_error(error: String) -> Dictionary: return {"ok": false, "points": PackedVector2Array(), "error": error}
static func _read_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary: return parsed
	return {}
