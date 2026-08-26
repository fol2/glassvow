extends RefCounted


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_asset_profiles: %s" % what)


static func run(fails: Array[String]) -> void:
	_live_profiles(fails)
	_geometry_contract(fails)
	_runtime_digest(fails)


static func _live_profiles(fails: Array[String]) -> void:
	var registry: MapAssetProfiles = MapAssetProfiles.new()
	var profiles: Array[Dictionary] = []
	var by_id: Dictionary[String, Dictionary] = {}
	for asset_id: String in registry.all_ids():
		var resource: Resource = load(registry.resource_path(asset_id))
		var mesh: Mesh = _mesh(resource)
		var value: Dictionary = registry.profile(asset_id, mesh)
		if value.is_empty():
			_check(fails, false, "%s yields a profile" % asset_id)
			continue
		profiles.append(value)
		by_id[asset_id] = value
		var raw_points: Variant = value.get("local_footprint", PackedVector2Array())
		var points: PackedVector2Array = PackedVector2Array()
		if raw_points is PackedVector2Array:
			points = raw_points
		_check(fails, points.size() >= 3 and _signed_area(points) < 0.0,
				"%s footprint is finite, non-empty and clockwise" % asset_id)
		_check(fails, _float_value(value, "grounded_height", 0.0) > 0.0,
				"%s has positive grounded height" % asset_id)
		_check(fails, str(value.get("source_mesh_identity", "")).length() == 64,
				"%s has a stable source identity" % asset_id)
	_check(fails, profiles.size() == 28,
			"all 23 kits, four termini and the Vigil are profiled")
	for fixture: String in [
		"act2-drowned-wall-corner",
		"act1-charred-stump",
		"act1-vigil",
		"act1-terminus",
	]:
		_check(fails, by_id.has(fixture), "%s fixture is present" % fixture)
	if by_id.has("shared-road-slab-a") and by_id.has("act1-charred-stump"):
		_check(fails,
				str(by_id["shared-road-slab-a"].get("semantic_class", ""))
						== MapAssetProfiles.SEMANTIC_ROAD
				and str(by_id["act1-charred-stump"].get("semantic_class", ""))
						== MapAssetProfiles.SEMANTIC_SCENERY,
				"road kits remain classified separately from scenery")
	if by_id.has("act1-vigil") and by_id.has("act1-terminus"):
		_check(fails,
				str(by_id["act1-vigil"].get("semantic_class", ""))
						== MapAssetProfiles.SEMANTIC_HERO
				and str(by_id["act1-terminus"].get("semantic_class", ""))
						== MapAssetProfiles.SEMANTIC_HERO,
				"the Vigil and terminus are hero fixtures")


static func _geometry_contract(fails: Array[String]) -> void:
	var fixture_manifest: Dictionary = _fixture_manifest()
	var registry: MapAssetProfiles = MapAssetProfiles.new(fixture_manifest)
	var long_mesh: BoxMesh = BoxMesh.new()
	long_mesh.size = Vector3(8.0, 2.0, 1.0)
	var compact_mesh: BoxMesh = BoxMesh.new()
	compact_mesh.size = Vector3(1.5, 1.0, 1.2)
	var changed_mesh: BoxMesh = BoxMesh.new()
	changed_mesh.size = Vector3(7.0, 2.0, 1.0)
	var long_value: Dictionary = registry.profile("long-wall", long_mesh)
	var compact_value: Dictionary = registry.profile("compact", compact_mesh)
	var changed_value: Dictionary = registry.profile("long-wall", changed_mesh)
	var raw_long_points: Variant = long_value.get(
			"local_footprint", PackedVector2Array())
	var long_points: PackedVector2Array = PackedVector2Array()
	if raw_long_points is PackedVector2Array:
		long_points = raw_long_points
	_check(fails, long_points.size() == 4,
			"mesh AABB produces one conservative oriented rectangle")
	if long_points.size() == 4:
		var width: float = absf(long_points[2].x - long_points[0].x)
		var depth: float = absf(long_points[2].y - long_points[0].y)
		_check(fails, width > depth * 4.0,
				"elongated wall remains elongated rather than becoming a disc")

	var position: Vector3 = Vector3(4.0, 0.0, -3.0)
	var transformed: PackedVector2Array = registry.transformed_footprint(
			long_value, position, 0.0, Vector3(2.0, 1.0, 3.0))
	var transformed_bounds: Rect2 = _bounds(transformed)
	_check(fails, transformed_bounds.position.is_equal_approx(Vector2(-4.0, -4.5))
			and transformed_bounds.size.is_equal_approx(Vector2(16.0, 3.0)),
			"known translation and non-uniform scale produce the governed bounds")
	var rotated: PackedVector2Array = registry.transformed_footprint(
			long_value, Vector3.ZERO, 90.0, Vector3.ONE)
	var rotated_bounds: Rect2 = _bounds(rotated)
	_check(fails, rotated_bounds.size.is_equal_approx(Vector2(1.0, 8.0)),
			"a 90-degree yaw swaps the elongated footprint axes")
	var rotated_scaled: PackedVector2Array = registry.transformed_footprint(
			long_value, Vector3.ZERO, 90.0, Vector3(2.0, 1.0, 3.0))
	_check(fails, _bounds(rotated_scaled).size.is_equal_approx(Vector2(3.0, 16.0)),
			"rotation preserves supplied scale in asset-local axes")
	_check(fails, transformed == registry.transformed_footprint(
			long_value, position, 0.0, Vector3(2.0, 1.0, 3.0)),
			"footprint transform is deterministic")
	_check(fails, registry.transformed_footprint(long_value, position, 0.0,
			Vector3(-1.0, 1.0, 1.0)).is_empty(),
			"negative transformed scale fails closed")

	var clockwise: Array = [[0, 0], [0, 1], [2, 1], [2, 0]]
	var counter_with_duplicates: Array = [
		[0, 0], [2, 0], [2, 1], [2, 1], [0, 1], [0, 0],
	]
	var canonical_clockwise: Dictionary = MapAssetProfiles.canonical_polygon(clockwise)
	var canonical_counter: Dictionary = MapAssetProfiles.canonical_polygon(
			counter_with_duplicates)
	_check(fails, _packed_vector2_value(canonical_clockwise, "points")
			== _packed_vector2_value(canonical_counter, "points"),
			"clockwise, counter-clockwise and closing/consecutive duplicates canonicalise")
	var duplicate_result: Dictionary = MapAssetProfiles.canonical_polygon(
			[[0, 0], [1, 0], [0, 0], [0, 1]])
	_check(fails, not _bool_value(duplicate_result, "ok", false),
			"non-consecutive duplicate hull input fails explicitly")
	var concave_result: Dictionary = MapAssetProfiles.canonical_polygon(
			[[0, 0], [2, 0], [1, 0.5], [2, 1], [0, 1]])
	_check(fails, not _bool_value(concave_result, "ok", false),
			"concave hull input fails explicitly")
	var nonfinite_result: Dictionary = MapAssetProfiles.canonical_polygon(
			PackedVector2Array([
				Vector2.ZERO, Vector2(NAN, 1.0), Vector2(1.0, 0.0),
			]))
	_check(fails, not _bool_value(nonfinite_result, "ok", false),
			"non-finite packed hull input fails explicitly")

	_check(fails, registry.digest([long_value, compact_value])
			== registry.digest([compact_value, long_value]),
			"profile digest is independent of caller order")
	_check(fails, registry.digest([long_value]) != registry.digest([changed_value]),
			"changing source AABB changes the digest")

	var override_manifest: Dictionary = fixture_manifest.duplicate(true)
	override_manifest["profile_overrides"] = {
		"long-wall": {
			"footprint": [[0, 0], [0, 2], [3, 2], [3, 0]],
			"reason": "test fixture narrows an over-conservative mesh AABB",
		},
	}
	var override_registry: MapAssetProfiles = MapAssetProfiles.new(override_manifest)
	var overridden: Dictionary = override_registry.profile("long-wall", long_mesh)
	_check(fails, registry.digest([long_value])
			!= override_registry.digest([overridden]),
			"changing an authored footprint override changes the digest")

	var negative_manifest: Dictionary = fixture_manifest.duplicate(true)
	var negative_defaults: Dictionary = _dictionary_value(
			negative_manifest, "profile_defaults")
	var negative_long: Dictionary = _dictionary_value(negative_defaults, "long-wall")
	negative_long["scale"] = -1.0
	negative_defaults["long-wall"] = negative_long
	negative_manifest["profile_defaults"] = negative_defaults
	_check(fails, MapAssetProfiles.new(negative_manifest).profile(
			"long-wall", long_mesh).is_empty(),
			"negative default scale fails closed")

	var missing_default_manifest: Dictionary = fixture_manifest.duplicate(true)
	var missing_defaults: Dictionary = _dictionary_value(
			missing_default_manifest, "profile_defaults")
	missing_defaults.erase("long-wall")
	missing_default_manifest["profile_defaults"] = missing_defaults
	_check(fails, MapAssetProfiles.new(missing_default_manifest).profile(
			"long-wall", long_mesh).is_empty(),
			"missing asset profile defaults fail closed")
	var empty_mesh: ArrayMesh = ArrayMesh.new()
	_check(fails, registry.profile("long-wall", empty_mesh).is_empty(),
			"non-positive mesh height fails closed")
	_check(fails, registry.profile("missing-id", long_mesh).is_empty(),
			"missing asset ID fails closed")


static func _runtime_digest(fails: Array[String]) -> void:
	var registry: MapAssetProfiles = MapAssetProfiles.new()
	var active: Array[Dictionary] = []
	for asset_id: String in registry.ids_for_act(0):
		var resource: Resource = load(registry.resource_path(asset_id))
		var value: Dictionary = registry.profile(asset_id, _mesh(resource))
		if not value.is_empty():
			active.append(value)
	var headless_digest: String = registry.digest(active)
	var scene: MapScene = MapScene.new()
	_check(fails, not headless_digest.is_empty()
			and scene.asset_profile_digest() == headless_digest,
			"runtime and headless tools read the same active profile digest")
	scene.free()


static func _fixture_manifest() -> Dictionary:
	return {
		"assets": [
			{"id": "long-wall", "kind": "kit", "act": -1,
				"path": "missing-long.glb"},
			{"id": "compact", "kind": "kit", "act": -1,
				"path": "missing-compact.glb"},
		],
		"profile_defaults": {
			"long-wall": {
				"scale": 1.0,
				"semantic_class": MapAssetProfiles.SEMANTIC_SCENERY,
				"yaw_mode": MapAssetProfiles.YAW_FREE,
			},
			"compact": {
				"scale": 1.0,
				"semantic_class": MapAssetProfiles.SEMANTIC_SCENERY,
				"yaw_mode": MapAssetProfiles.YAW_FREE,
			},
		},
		"profile_overrides": {},
	}


static func _bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var bounds: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		bounds = bounds.expand(point)
	return bounds


static func _signed_area(points: PackedVector2Array) -> float:
	var area: float = 0.0
	for i: int in range(points.size()):
		area += points[i].cross(points[(i + 1) % points.size()])
	return area


static func _mesh(resource: Resource) -> Mesh:
	if resource is Mesh:
		return resource as Mesh
	if not (resource is PackedScene):
		return null
	var root: Node = (resource as PackedScene).instantiate()
	var mesh: Mesh = _first_mesh(root)
	root.free()
	return mesh


static func _first_mesh(root: Node) -> Mesh:
	if root is MeshInstance3D:
		return (root as MeshInstance3D).mesh
	for child: Node in root.get_children():
		var found: Mesh = _first_mesh(child)
		if found != null:
			return found
	return null


static func _dictionary_value(source: Dictionary, key: String) -> Dictionary:
	var raw: Variant = source.get(key, {})
	if raw is Dictionary:
		var value: Dictionary = raw
		return value.duplicate(true)
	return {}


static func _float_value(source: Dictionary, key: String, fallback: float) -> float:
	var raw: Variant = source.get(key, fallback)
	if raw is float:
		var decimal: float = raw
		return decimal
	if raw is int:
		var integer: int = raw
		return float(integer)
	return fallback


static func _packed_vector2_value(
		source: Dictionary, key: String) -> PackedVector2Array:
	var raw: Variant = source.get(key, PackedVector2Array())
	if raw is PackedVector2Array:
		var value: PackedVector2Array = raw
		return value
	return PackedVector2Array()


static func _bool_value(source: Dictionary, key: String, fallback: bool) -> bool:
	var raw: Variant = source.get(key, fallback)
	if raw is bool:
		var value: bool = raw
		return value
	return fallback
