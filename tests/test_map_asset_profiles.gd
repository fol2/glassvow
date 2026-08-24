extends RefCounted

static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok: fails.append("test_map_asset_profiles: %s" % what)

static func run(fails: Array[String]) -> void:
	var registry: MapAssetProfiles = MapAssetProfiles.new(); var profiles: Array[Dictionary] = []; var by_id: Dictionary[String, Dictionary] = {}
	for asset_id: String in registry.all_ids():
		var resource: Resource = load(registry.resource_path(asset_id)); var mesh: Mesh = _mesh(resource)
		var value: Dictionary = registry.profile(asset_id, mesh); var footprint_v: Variant = value.get("local_footprint", PackedVector2Array())
		var footprint_size: int = footprint_v.size() if footprint_v is PackedVector2Array else 0
		_check(fails, not value.is_empty() and footprint_size >= 3 and float(value.get("grounded_height", 0.0)) > 0.0
				and str(value.get("source_mesh_identity", "")).length() == 64, "%s yields one finite non-empty profile" % asset_id)
		profiles.append(value); by_id[asset_id] = value
	_check(fails, profiles.size() == 28, "all 23 kits, four termini and the Vigil are profiled")
	for fixture: String in ["act2-drowned-wall-corner", "act1-charred-stump", "act1-vigil", "act1-terminus"]:
		_check(fails, by_id.has(fixture) and not by_id[fixture].is_empty(), "%s fixture is present" % fixture)
	_check(fails, by_id["shared-road-slab-a"].get("semantic_class") == "road"
			and by_id["act1-charred-stump"].get("semantic_class") == "scenery", "road kits are not scenery")

	var policy: Dictionary = {"kit_scales": [1.0, 1.0], "road_ids": [], "arch_passable_ids": [], "overrides": {}}
	var fixture_manifest: Dictionary = {"profile_policy": policy, "assets": [
		{"id": "long-wall", "kind": "kit", "act": -1, "path": "missing-long.glb"},
		{"id": "compact", "kind": "kit", "act": -1, "path": "missing-compact.glb"}]}
	var fixtures: MapAssetProfiles = MapAssetProfiles.new(fixture_manifest)
	var long_mesh: BoxMesh = BoxMesh.new(); long_mesh.size = Vector3(8.0, 2.0, 1.0)
	var changed_mesh: BoxMesh = BoxMesh.new(); changed_mesh.size = Vector3(7.0, 2.0, 1.0)
	var long_value: Dictionary = fixtures.profile("long-wall", long_mesh); var changed_value: Dictionary = fixtures.profile("long-wall", changed_mesh)
	var long_points_v: Variant = long_value.get("local_footprint", PackedVector2Array())
	var long_points: PackedVector2Array = long_points_v if long_points_v is PackedVector2Array else PackedVector2Array()
	_check(fails, absf(long_points[2].x - long_points[0].x) > absf(long_points[2].y - long_points[0].y) * 4.0,
			"elongated wall remains elongated, not an equal-radius disc")
	var transform: Transform3D = Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3(1.2, 1.0, 0.8)), Vector3(4.0, 0.0, -3.0))
	_check(fails, fixtures.world_footprint(long_value, transform) == fixtures.world_footprint(long_value, transform), "world footprint transform is deterministic")
	var clockwise: Array = [[0, 0], [0, 1], [2, 1], [2, 0]]; var counter: Array = [[0, 0], [2, 0], [2, 1], [0, 1], [0, 0]]
	_check(fails, MapAssetProfiles.canonical_polygon(clockwise).get("points") == MapAssetProfiles.canonical_polygon(counter).get("points"),
			"clockwise/counter-clockwise and closing duplicate canonicalise")
	_check(fails, not bool(MapAssetProfiles.canonical_polygon([[0, 0], [1, 0], [0, 0], [0, 1]]).get("ok")), "non-closing duplicate hull fails explicitly")
	_check(fails, fixtures.digest([long_value]) != fixtures.digest([changed_value]), "source AABB changes profile digest")
	var bad_policy: Dictionary = policy.duplicate(true); bad_policy["kit_scales"] = [-1.0, 1.0]
	var bad_manifest: Dictionary = fixture_manifest.duplicate(true); bad_manifest["profile_policy"] = bad_policy
	_check(fails, MapAssetProfiles.new(bad_manifest).profile("long-wall", long_mesh).is_empty(), "negative scale fails closed")
	policy["overrides"] = {"long-wall": {"footprint": [[0, 0], [0, 2], [3, 2], [3, 0]], "reason": "fixture"}}
	fixture_manifest["profile_policy"] = policy
	var overridden: Dictionary = MapAssetProfiles.new(fixture_manifest).profile("long-wall", long_mesh)
	_check(fails, fixtures.digest([long_value]) != fixtures.digest([overridden]), "profile override changes digest")
	var empty_mesh: ArrayMesh = ArrayMesh.new(); _check(fails, fixtures.profile("long-wall", empty_mesh).is_empty(), "non-positive grounded height fails closed")
	_check(fails, fixtures.profile("missing-id", long_mesh).is_empty(), "missing asset ID fails closed")

	var scene: MapScene = MapScene.new(); var active: Array[Dictionary] = []
	for asset_id: String in registry.ids_for_act(0): active.append(by_id[asset_id])
	_check(fails, not scene.asset_profile_digest().is_empty() and scene.asset_profile_digest() == registry.digest(active),
			"runtime and headless profile digests agree")
	scene.free()

static func _mesh(resource: Resource) -> Mesh:
	if resource is Mesh: return resource as Mesh
	if not (resource is PackedScene): return null
	var root: Node = (resource as PackedScene).instantiate(); var out: Mesh = _first_mesh(root); root.free(); return out
static func _first_mesh(root: Node) -> Mesh:
	if root is MeshInstance3D: return (root as MeshInstance3D).mesh
	for child: Node in root.get_children():
		var found: Mesh = _first_mesh(child)
		if found != null: return found
	return null
