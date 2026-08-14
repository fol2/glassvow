extends RefCounted
## #234 slice 3: 15×7 lattice, pin projection, seed-717 agreement.


const SCREEN_EPS: float = 0.05
const VIEW: Vector2 = Vector2(1180.0, 820.0)


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_pins: %s" % what)


static func run(fails: Array[String]) -> void:
	_lattice(fails)
	_scene_api(fails)
	_pan_bounds(fails)
	_agreement(fails)


static func _lattice(fails: Array[String]) -> void:
	_check(fails, WorldMap.ROWS == 15 and WorldMap.COLS == 7,
			"lattice is the frozen 15×7")
	var origin: Vector3 = MapPinProjection.lattice_point(0, 0)
	_check(fails, origin.is_equal_approx(Vector3(-18.0, 0.0, 14.0)),
			"row 0 col 0 is the near-left vertex")
	_check(fails, MapPinProjection.lattice_point(0, 6).is_equal_approx(
			Vector3(18.0, 0.0, 14.0)),
			"row 0 col 6 is the near-right vertex")
	_check(fails, MapPinProjection.lattice_point(14, 3).is_equal_approx(
			Vector3(0.0, 0.0, -14.0)),
			"boss cell is far-centre, toward −Z")
	var mid: Vector3 = MapPinProjection.sample(0.5, 0.5)
	var avg: Vector3 = (
			MapPinProjection.lattice_point(0, 0)
			+ MapPinProjection.lattice_point(1, 0)
			+ MapPinProjection.lattice_point(0, 1)
			+ MapPinProjection.lattice_point(1, 1)) * 0.25
	_check(fails, mid.is_equal_approx(avg),
			"bilinear at a cell centre is the mean of its four vertices")
	var node: MapNode = MapNode.new()
	node.row = 4
	node.col = 2
	node.jx = 0.25
	node.jy = -0.20
	_check(fails, MapPinProjection.world_anchor(node).is_equal_approx(
			MapPinProjection.sample(3.80, 2.25)),
			"jy walks the row axis, jx the col axis")
	_check(fails, not MapPinProjection.world_anchor(node).is_equal_approx(
			MapPinProjection.lattice_point(4, 2)),
			"jittered sample is not the integer vertex")


static func _scene_api(fails: Array[String]) -> void:
	var scene: MapScene = MapScene.new()
	var empty: Array[MapNode] = []
	_check(fails, scene.project_pins(empty).is_empty(),
			"MapScene.new() projects an empty list without a WorldMap")
	scene.free()


static func _pan_bounds(fails: Array[String]) -> void:
	var rig: MapCameraRig = MapCameraRig.new()
	var derived: Rect2 = MapCameraRig.bounds_from_lattice()
	_check(fails, rig.pan_bounds.is_equal_approx(derived),
			"rig pan_bounds is the lattice-derived rect")
	_check(fails, derived.has_point(MapCameraRig.DEFAULT_XZ),
			"default pose sits inside the lattice pan bounds")
	var shifted: Vector2 = MapCameraRig.DEFAULT_XZ + Vector2(1.5, -2.0)
	_check(fails, derived.has_point(shifted),
			"slice-1 pan delta still fits the new bounds")
	rig.free()


static func _agreement(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_slice()
	var run: RunState = RunState.new_run(content, 717, "run-map-pins")
	var generated: WorldMap = WorldMap.benchmark(run)
	_check(fails, generated.nodes.size() == 65, "seed 717 still has 65 nodes")
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var scene: MapScene = MapScene.new()
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tree.root.add_child(scene)
	scene.size = VIEW
	scene._fit()
	_check(fails, scene.get_stage().size == Vector2i(int(VIEW.x), int(VIEW.y)),
			"stage matches the agreement view")
	var rig: MapCameraRig = scene.get_rig()
	var poses: Array[Vector3] = [
		Vector3(float(MapCameraRig.DEFAULT_STOP),
				MapCameraRig.DEFAULT_XZ.x, MapCameraRig.DEFAULT_XZ.y),
		Vector3(0.0, MapCameraRig.DEFAULT_XZ.x, MapCameraRig.DEFAULT_XZ.y),
		Vector3(3.0, MapCameraRig.DEFAULT_XZ.x, MapCameraRig.DEFAULT_XZ.y),
		Vector3(2.0, -12.0, 22.0),
		Vector3(1.0, 10.0, 4.0),
		Vector3(3.0, -7.0, 8.0),
	]
	for pose: Vector3 in poses:
		_pose(rig, int(pose.x), Vector2(pose.y, pose.z))
		var seats: PackedVector2Array = scene.project_pins(generated.nodes)
		_check(fails, seats.size() == 65,
				"pose stop=%d seats all 65 nodes" % int(pose.x))
		var drifted: int = 0
		var sample_id: String = ""
		var sample_err: float = 0.0
		for i: int in range(generated.nodes.size()):
			var hit: Vector2 = scene._projection().hit_screen(seats[i])
			var err: float = seats[i].distance_to(hit)
			if err > SCREEN_EPS:
				drifted += 1
				if sample_id.is_empty():
					sample_id = generated.nodes[i].id
					sample_err = err
		_check(fails, drifted == 0,
				"stop=%d pan=(%.1f,%.1f): %d/%d nodes disagree (e.g. %s err=%.4f)"
				% [int(pose.x), pose.y, pose.z, drifted, generated.nodes.size(),
					sample_id, sample_err])
	tree.root.remove_child(scene)
	scene.free()


static func _pose(rig: MapCameraRig, stop: int, xz: Vector2) -> void:
	rig.set_zoom_stop(stop)
	rig.pan_world(xz - rig.camera_xz())
