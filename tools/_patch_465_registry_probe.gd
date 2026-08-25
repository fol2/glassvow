extends SceneTree


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		print("registry probe expects one phase")
		quit(2)
		return
	var phase: String = args[0]
	var registry: MapAssetProfiles = MapAssetProfiles.new()
	var profiles: Array[Dictionary] = []
	var by_id: Dictionary[String, Dictionary] = {}
	var generation_failures: PackedStringArray = PackedStringArray()
	for asset_id: String in registry.all_ids():
		var resource: Resource = load(registry.resource_path(asset_id))
		var mesh: Mesh = _mesh(resource)
		var value: Dictionary = registry.profile(asset_id, mesh)
		if value.is_empty():
			generation_failures.append(asset_id)
			continue
		profiles.append(value)
		by_id[asset_id] = value

	var failures: PackedStringArray = PackedStringArray()
	match phase:
		"manifest-count":
			if registry.all_ids().size() != 28:
				failures.append("manifest mesh registry count is %d, expected 28"
						% registry.all_ids().size())
		"generation-count":
			if not generation_failures.is_empty():
				failures.append("failed profile IDs: %s"
						% ", ".join(generation_failures))
			if profiles.size() != 28:
				failures.append("generated profile count is %d, expected 28"
						% profiles.size())
		"required-fields":
			_check_required_fields(profiles, failures)
		"act-residency":
			var act_one_ids: PackedStringArray = registry.ids_for_act(0)
			if act_one_ids.size() != 10:
				failures.append("act-one residency count is %d, expected 10"
						% act_one_ids.size())
			for required_id: String in [
				"shared-road-slab-a", "shared-road-slab-b",
				"shared-standing-monument", "act1-vigil", "act1-terminus",
			]:
				if required_id not in act_one_ids:
					failures.append("act-one residency misses %s" % required_id)
		"semantics":
			_check_semantics(by_id, failures)
		"digest":
			var first: String = registry.digest(profiles)
			var second: String = registry.digest(profiles)
			if first.length() != 64:
				failures.append("registry digest length is %d, expected 64"
						% first.length())
			if first != second:
				failures.append("registry digest is not deterministic")
		_:
			failures.append("unknown phase %s" % phase)

	if failures.is_empty():
		print("PASS registry %s" % phase)
		quit(0)
		return
	print("FAIL registry %s (%d)" % [phase, failures.size()])
	for message: String in failures:
		print("  - %s" % message)
	quit(1)


func _check_required_fields(
		profiles: Array[Dictionary], failures: PackedStringArray) -> void:
	for value: Dictionary in profiles:
		var asset_id: String = str(value.get("asset_id", ""))
		var raw_points: Variant = value.get(
				"local_footprint", PackedVector2Array())
		if not (raw_points is PackedVector2Array):
			failures.append("%s footprint is not PackedVector2Array" % asset_id)
			continue
		var points: PackedVector2Array = raw_points
		if points.size() < 3:
			failures.append("%s footprint has fewer than three points" % asset_id)
		elif not _all_finite(points):
			failures.append("%s footprint contains a non-finite point" % asset_id)
		elif _signed_area(points) >= 0.0:
			failures.append("%s footprint is not clockwise" % asset_id)
		if _float_value(value, "grounded_height", 0.0) <= 0.0:
			failures.append("%s grounded height is not positive" % asset_id)
		if str(value.get("source_mesh_identity", "")).length() != 64:
			failures.append("%s source identity is not SHA-256 length" % asset_id)


func _check_semantics(
		by_id: Dictionary[String, Dictionary],
		failures: PackedStringArray) -> void:
	var expected: Dictionary[String, String] = {
		"shared-road-slab-a": MapAssetProfiles.SEMANTIC_ROAD,
		"shared-road-slab-b": MapAssetProfiles.SEMANTIC_ROAD,
		"act1-charred-stump": MapAssetProfiles.SEMANTIC_SCENERY,
		"act1-vigil": MapAssetProfiles.SEMANTIC_HERO,
		"act1-terminus": MapAssetProfiles.SEMANTIC_HERO,
	}
	for asset_id: String in expected:
		if not by_id.has(asset_id):
			failures.append("semantic registry misses %s" % asset_id)
			continue
		var actual: String = str(by_id[asset_id].get("semantic_class", ""))
		if actual != expected[asset_id]:
			failures.append("%s semantic is %s, expected %s"
					% [asset_id, actual, expected[asset_id]])


func _all_finite(points: PackedVector2Array) -> bool:
	for point: Vector2 in points:
		if not is_finite(point.x) or not is_finite(point.y):
			return false
	return true


func _signed_area(points: PackedVector2Array) -> float:
	var area: float = 0.0
	for i: int in range(points.size()):
		area += points[i].cross(points[(i + 1) % points.size()])
	return area


func _mesh(resource: Resource) -> Mesh:
	if resource is Mesh:
		return resource as Mesh
	if not (resource is PackedScene):
		return null
	var root: Node = (resource as PackedScene).instantiate()
	var mesh: Mesh = _first_mesh(root)
	root.free()
	return mesh


func _first_mesh(root: Node) -> Mesh:
	if root is MeshInstance3D:
		return (root as MeshInstance3D).mesh
	for child: Node in root.get_children():
		var found: Mesh = _first_mesh(child)
		if found != null:
			return found
	return null


func _float_value(source: Dictionary, key: String, fallback: float) -> float:
	var raw: Variant = source.get(key, fallback)
	if raw is float:
		var decimal: float = raw
		return decimal
	if raw is int:
		var integer: int = raw
		return float(integer)
	return fallback
