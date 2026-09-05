extends RefCounted
## Assets, real route geometry and projection safety of the rebuilt map.

static func run(fails: Array[String]) -> void:
	for act: int in range(4):
		var assets: MapLandscapeAssets = MapLandscapeAssets.new(act)
		_check(fails, assets.failure.is_empty() and not assets.bundle().is_empty(),
			"act %d has complete profiled assets: %s" % [act, assets.failure])
		if not assets.failure.is_empty():
			return
		_check(fails, assets.profiles.has(MapLandscapeAssets.GATES[act])
			and assets.profiles.has("vigil") == (act == 0), "act landmarks and residency")
		for id: String in assets.meshes:
			var bounds: AABB = assets.meshes[id].get_aabb()
			_check(fails, bounds.size.x > 0 and bounds.size.y > 0 and bounds.size.z > 0,
				id + " carries its real three-dimensional silhouette")
			_check(fails, absf(bounds.position.y) <= 0.001, id + " is grounded")
	_check_concave_shore(fails)
	var scene: MapScene = MapScene.new()
	var quality: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://docs/map/map-quality-v2.json"))
	var heroes: Dictionary = {}
	var contract: Dictionary = scene.layout_hero_contract()
	for id: String in contract["anchors"]:
		var anchor: Dictionary = contract["anchors"][id]
		heroes[id] = {"asset_id": anchor["asset_id"], "profile_id": anchor["profile_id"],
			"transform": {"origin": anchor["position"], "scale": anchor["scale"],
				"yaw_radians": anchor["yaw_radians"]}}
	var edge_id: String = MapLayoutInput.edge_id("A", "B")
	var edges: Dictionary = {edge_id: {"from": "A", "to": "B", "corridor_width": 2.5,
		"centerline": [[-28.0, 0.0, 0.0], [-23.0, 0.0, 2.0], [-18.0, 0.0, 2.0], [-12.0, 0.0, 0.0]]}}
	var result: MapLayoutResult = MapLayoutResult.create({
		"schema_version": MapLayoutResult.SCHEMA_VERSION,
		"generator_version": MapLayoutCompiler.VERSION,
		"node_anchors": {"A": [-28.0, 0.0, 0.0], "B": [-12.0, 0.0, 0.0]},
		"edges": edges, "hero_placements": heroes, "scenery_instances": {},
		"hard_measurements": {}, "soft_scores": {}, "selected_restart_id": 0,
		"selected_candidate_id": "landscape/check", "input_digest": "a".repeat(64)})
	_check(fails, result != null, "route fixture obeys the compiler result schema")
	var final: MapLayoutResult = scene.bind_layout(result, quality)
	_check(fails, final != null, "bind a valid generator result")
	if final != null:
		var final_edges: Dictionary = final.identity_dict()["edges"]
		_check(fails, final_edges == edges,
			"all route bends and elevation remain the generator's exact centreline")
		_check(fails, scene.road_segments().size() == 6, "three physical route legs")
		var bridge: MeshInstance3D = scene.find_child("Bridge masonry", true, false) as MeshInstance3D
		_check(fails, bridge != null and bridge.mesh.get_faces().size() > 0,
			"a real deck and parapets span the ravine")
		var plinths: MultiMeshInstance3D = scene.find_child("Waystone plinths", true, false) as MultiMeshInstance3D
		_check(fails, plinths != null and plinths.multimesh.instance_count == 2,
			"one physical plinth per canonical node")
		_check(fails, MapLayoutCanonical.int_value(scene.layout_diagnostics()["accepted_count"]) > 0,
			"safe scenery survives the full projection reserve")
		_check_projection(fails, scene)
		var layout_digest: String = scene.layout_digest()
		scene.set_node_states({"A": "current", "B": "open"})
		_check(fails, scene.layout_digest() == layout_digest,
			"presentation states do not change the generator's geometry identity")
	scene.set_live(false)
	_check(fails, not scene.is_live() and scene.get_stage().render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"logical rest allows a bounded texture and shadow warm-up")
	for frame: int in range(3):
		scene._process(0.0)
	_check(fails, not scene.is_live() and scene.get_stage().render_target_update_mode == SubViewport.UPDATE_ONCE,
		"the final warm-up frame freezes, rather than rendering forever")
	scene.set_live(true)
	scene._repaint()
	_check(fails, scene.is_live(), "content changes cannot freeze an active pan")
	scene.bind_layout(null, quality)
	_check(fails, scene.layout_digest().is_empty(),
		"failed binding clears geometry identity")
	_check(fails, scene.find_child("Waystone plinths", true, false) == null,
		"failed binding does not retain a navigable old landscape")
	scene.free()


static func _check_concave_shore(fails: Array[String]) -> void:
	var land: MapLandscape = MapLandscape.new()
	land.prepare({"node_anchors": {"pier": [-20.5, 0.0, 0.0]}, "edges": {}},
		MapLandscapeAssets.new(0), 1)
	var shore: PackedVector2Array = PackedVector2Array([
		Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(2, 3),
		Vector2(2, -2), Vector2(-2, -2), Vector2(-2, 3), Vector2(-3, 3)])
	land.land(shore)
	var terrain: MeshInstance3D = land.get_node("Slate heath") as MeshInstance3D
	var faces: PackedVector3Array = terrain.mesh.get_faces()
	var contained: bool = not faces.is_empty()
	for i: int in range(0, faces.size(), 3):
		var triangle: PackedVector2Array = []
		for corner: int in range(3):
			triangle.append(Vector2(faces[i + corner].x, faces[i + corner].z))
		contained = contained and Geometry2D.clip_polygons(triangle, shore).is_empty()
	_check(fails, contained, "no ground triangle crosses a concave shoreline")
	# The dummy renderer returns identity from MultiMesh readback. Measure the
	# exact transform supplied to the batch, and inspect the headed pier too.
	var pier: Transform3D = land.plinth_transform(Vector3(-20.5, 0, 0))
	var top: Vector3 = pier * (Vector3.UP * MapLandscape.PLINTH_HEIGHT * 0.5)
	var bottom: Vector3 = pier * (Vector3.DOWN * MapLandscape.PLINTH_HEIGHT * 0.5)
	_check(fails, is_equal_approx(top.y, 0.045) and bottom.y < -6.0,
		"a ravine waystone keeps its deck height and extends a pier to the basin")
	land.free()


static func _check_projection(fails: Array[String], scene: MapScene) -> void:
	var candidate: Dictionary = {"placement": {"profile_id": "ash-tree", "transform": {
		"origin": [0.0, 0.0, 8.0], "scale": [1.0, 1.0, 1.0], "yaw_radians": 0.0}}}
	var physical: PackedVector2Array = scene._placement_footprint(candidate)
	var selection: PackedVector2Array = scene._selection_footprint(candidate, physical)
	var profile: Dictionary = scene.layout_asset_bundle()["profiles"]["ash-tree"]
	var bounds: AABB = profile["local_aabb"]
	var high: Vector3 = Vector3(0, bounds.end.y, bounds.position.z) + Vector3(0, 0, 8)
	var projected: Vector2 = Vector2(high.x, high.z - high.y / tan(deg_to_rad(40.0)))
	_check(fails, not Geometry2D.is_point_in_polygon(projected + Vector2(0, 0.01), physical),
		"the test canopy projects beyond its ground footprint")
	_check(fails, Geometry2D.is_point_in_polygon(projected + Vector2(0, 0.01), selection),
		"the screen reserve contains the canopy that a ground-only check misses")


static func _check(fails: Array[String], ok: bool, message: String) -> void:
	if not ok:
		fails.append("test_map_landscape: " + message)
