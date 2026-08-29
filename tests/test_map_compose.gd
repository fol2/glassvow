extends RefCounted
## #234 slice 7b: WorldMapScreen seats pins on the lattice projection; MapScene
## owns world input. Seed-717 projection↔hit-test agreement stays in test_map_pins.


class FakeLayoutCompiler:
	extends RefCounted
	var calls: int = 0
	var input_digests: Array[String] = []
	var fail_next: bool = false

	func compile(input: MapLayoutInput, _quality: Dictionary,
			_assets: Dictionary) -> Dictionary:
		calls += 1
		input_digests.append(input.digest())
		if fail_next:
			fail_next = false
			return {
				"status": MapLayoutCompiler.NO_FEASIBLE_NODE_ROUTE_LAYOUT,
				"result": null,
				"diagnostics": {"input_digest": input.digest()},
				"failure": {
					"kind": "test", "id": "invalid", "reason": "forced failure",
				},
			}
		var source: Dictionary = input.to_dict()
		var anchors: Dictionary = {}
		for node: Dictionary in input.node_records():
			var anchor: Vector3 = MapPinProjection.lattice_point(
				MapLayoutCanonical.int_value(node["row"]),
				MapLayoutCanonical.int_value(node["col"]))
			anchor.y = float(MapLayoutCanonical.int_value(node["row"]) % 3)
			anchor.z += 2.75
			anchors[str(node["id"])] = _a3(anchor)
		var edges: Dictionary = {}
		for edge: Dictionary in input.edge_records():
			var from: Vector3 = _v3(anchors[str(edge["from"])])
			var to: Vector3 = _v3(anchors[str(edge["to"])])
			var bend: Vector3 = from.lerp(to, 0.5) + Vector3(0.0, 0.5, 1.0)
			edges[str(edge["id"])] = {
				"from": edge["from"], "to": edge["to"],
				"centerline": [_a3(from), _a3(bend), _a3(to)],
				"corridor_width": 2.5,
			}
		var heroes: Dictionary = {}
		var contract: Dictionary = source["hero_anchor_contract"]
		var contract_anchors: Dictionary = contract["anchors"]
		for id: String in MapLayoutCanonical.sorted_keys(contract_anchors):
			var anchor: Dictionary = contract_anchors[id]
			heroes[id] = {
				"asset_id": anchor["asset_id"], "profile_id": anchor["profile_id"],
				"transform": {
					"origin": anchor["position"],
					"yaw_radians": anchor["yaw_radians"], "scale": anchor["scale"],
				},
			}
		var result: MapLayoutResult = MapLayoutResult.create({
			"schema_version": MapLayoutResult.SCHEMA_VERSION,
			"generator_version": MapLayoutCompiler.VERSION,
			"node_anchors": MapLayoutCanonical.ordered_dictionary(anchors),
			"edges": MapLayoutCanonical.ordered_dictionary(edges),
			"hero_placements": MapLayoutCanonical.ordered_dictionary(heroes),
			"scenery_instances": {}, "hard_measurements": {}, "soft_scores": {},
			"selected_restart_id": 0, "selected_candidate_id": "test/live-binding",
			"input_digest": input.digest(),
		})
		return {
			"status": MapLayoutCompiler.COMPILED, "result": result,
			"diagnostics": {"input_digest": input.digest()},
			"report": {"hard_pass": true},
		}

	func _a3(value: Vector3) -> Array[float]:
		return [value.x, value.y, value.z]

	func _v3(value: Variant) -> Vector3:
		var row: Array = value
		return Vector3(MapLayoutCanonical.float_value(row[0]),
			MapLayoutCanonical.float_value(row[1]),
			MapLayoutCanonical.float_value(row[2]))


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_compose: %s" % what)


static func run(fails: Array[String]) -> void:
	_compiled_result_binding(fails)
	_five_shapes(fails)
	_surface_rects(fails)
	_act_and_live(fails)
	_seats(fails)
	_pin_select(fails)
	_projection_cache(fails)


static func _compiled_result_binding(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var run: RunState = RunState.new_run(content, 717, "run-map-live-layout")
	var screen: WorldMapScreen = WorldMapScreen.new(WorldMap.benchmark(run), content)
	if not screen.has_method(&"layout_result"):
		_check(fails, false, "WorldMapScreen exposes the final compiled result")
		screen.free()
		return
	var compiler: FakeLayoutCompiler = FakeLayoutCompiler.new()
	screen.set("_layout_compile", Callable(compiler, "compile"))
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	_mount(screen, StageShape.IDENTITY)
	screen.refresh(run)
	var result_v: Variant = screen.call(&"layout_result")
	var result: MapLayoutResult = result_v if result_v is MapLayoutResult else null
	_check(fails, compiler.calls == 1 and result != null,
		"refresh compiles and binds exactly one final live result")
	if result == null:
		tree.root.remove_child(screen)
		screen.free()
		return
	var anchors: PackedVector3Array = PackedVector3Array()
	var data: Dictionary = result.to_dict()
	_check(fails, screen.layout_digest() == screen._map_scene.layout_digest()
			and screen.layout_input_digest() == screen._map_scene.layout_input_digest(),
		"screen and renderer expose the same input and layout digests")
	for node: MapNode in screen.map.nodes:
		anchors.append(compiler._v3(data["node_anchors"][node.id]))
	var seats: PackedVector2Array = screen.projected_seats()
	var direct: PackedVector2Array = screen._map_scene.project_anchors(anchors)
	var legacy: PackedVector2Array = screen._map_scene.project_pins(screen.map.nodes)
	_check(fails, seats == direct and not seats.is_empty()
			and not seats[0].is_equal_approx(legacy[0]),
		"waystones project the compiled anchors rather than the legacy lattice")
	var reachable: Array[int] = screen.map.reachable()
	for i: int in reachable:
		_check(fails, screen.pick_node_at(seats[i]) == i,
			"compiled anchor %d agrees with its hit test" % i)
	if not reachable.is_empty():
		var i: int = reachable[0]
		var quality: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://docs/map/map-quality-v2.json"))
		var bound: Dictionary = MapLayoutInputBinding.bind(screen.map, run.act)
		var bound_nodes: Array = bound["nodes"]
		var bound_edges: Array = bound["edges"]
		var envelopes: Dictionary = MapQualityEvaluator.node_candidate_bounds(
			bound_nodes, bound_edges, quality)
		var expected: Vector2 = screen._map_scene.get_rig().pose_leading(
			anchors[i], Vector2(StageShape.REFERENCES[StageShape.IDENTITY]),
			MapQualityEvaluator.focused_touch_inset_px(quality),
			MapQualityEvaluator.focused_anchor_envelope(
				screen.map.nodes[i].id, envelopes))
		_check(fails, screen._focus_xz(i).is_equal_approx(expected),
			"focus uses the same compiled anchor as projection and hit testing")
	var first_digest: String = result.digest()
	screen.map.at = 0
	screen.map.cleared[0] = true
	screen.refresh(run)
	screen.set_shape(&"phone-landscape")
	var reused_v: Variant = screen.call(&"layout_result")
	var reused: MapLayoutResult = reused_v if reused_v is MapLayoutResult else null
	_check(fails, compiler.calls == 1
			and reused != null and reused.digest() == first_digest,
		"semantic and stage-shape changes reuse the same layout")
	run.seed += 1
	screen.refresh(run)
	var after_seed: int = compiler.calls
	screen.map.nodes[0].jx += 0.01
	screen.refresh(run)
	var after_graph: int = compiler.calls
	run.act = 1
	screen.refresh(run)
	var after_act: int = compiler.calls
	screen.set_act_scenery(2)
	_check(fails, after_seed == 2 and after_graph == 3 and after_act == 4
			and compiler.calls == 5,
		"seed, graph, act and active-profile changes each regenerate once")
	compiler.fail_next = true
	run.seed += 1
	screen.call(&"_bind_compiled_layout")
	_check(fails, screen.layout_result() == null
			and not screen.layout_failure().is_empty()
			and screen._map_scene.road_segments().is_empty()
			and screen.projected_seats().is_empty(),
		"an invalid compile fails explicitly without legacy pin or road fallback")
	tree.root.remove_child(screen)
	screen.free()


static func _five_shapes(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_slice()
	var walk: WorldMap = WorldMap.slice()
	var screen: WorldMapScreen = WorldMapScreen.new(walk, content)
	screen.instant = true
	var seen: Array[int] = []
	screen.node_chosen.connect(func(i: int) -> void: seen.append(i))
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	for shape_name: StringName in StageShape.REFERENCES:
		_mount(screen, shape_name)
		var scene: MapScene = screen._map_scene
		_check(fails, scene != null and screen.get_child(0) == scene,
				"%s: MapScene is the lowest child" % shape_name)
		_check(fails, scene != null
				and scene.mouse_filter == Control.MOUSE_FILTER_STOP,
				"%s: MapScene owns world-surface input" % shape_name)
		_check(fails, screen._path_band != null
				and screen._chip_band != null
				and screen._path_band.get_index() > 0,
				"%s: path overlay + chips stay in front" % shape_name)
		var extra: int = 0
		for child: Node in screen.get_children():
			if child is MapBand and not (
					child is MapBand.PathBand
					or child is MapBand.ChipBand):
				extra += 1
		# VeilBand was retired in #156 round 2; the falling ash read as snow.
		# Two bands is now the whole overlay set, and this is the check that
		# fails if a third ever creeps back in unannounced.
		_check(fails, extra == 0,
				"%s: only path/chip MapBand children remain" % shape_name)
		_check(fails, not screen.choose(2),
				"%s: screen refuses an unreachable waystone" % shape_name)
		_check(fails, screen.choose(0),
				"%s: screen accepts the open waystone" % shape_name)
	_check(fails, seen.size() == StageShape.REFERENCES.size(),
			"arrival hands off at every shape")
	tree.root.remove_child(screen)
	screen.free()


static func _act_and_live(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_slice()
	var screen: WorldMapScreen = WorldMapScreen.new(WorldMap.slice(), content)
	var scene: MapScene = screen._map_scene
	_check(fails, scene != null and scene.get_act() == 0,
			"composed MapScene starts on act 0")
	screen.set_act_scenery(2)
	_check(fails, scene.get_act() == 2, "set_act_theme pushes act 2 onto MapScene")
	screen.set_act_scenery(0)
	_check(fails, scene.get_act() == 0, "set_act_theme pushes act 0 onto MapScene")
	_check(fails, not scene.is_live(), "rest is frozen")
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	scene._gui_input(press)
	_check(fails, scene.is_live(), "pan unfreezes the world surface")
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(40.0, 0.0)
	scene._gui_input(motion)
	press.pressed = false
	scene._gui_input(press)
	_check(fails, not scene.is_live(), "pan end re-arms freeze")
	screen._travelling = true
	screen._process(0.016)
	_check(fails, scene.is_live(), "travel unfreezes the world surface")
	screen._travelling = false
	screen._process(0.016)
	_check(fails, not scene.is_live(), "travel end re-arms freeze")
	screen.free()


static func _surface_rects(fails: Array[String]) -> void:
	var scene: MapScene = MapScene.new()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	var targets: Array[Vector2] = []
	for shape_name: StringName in StageShape.REFERENCES:
		var reference: Vector2i = StageShape.REFERENCES[shape_name]
		targets.append(Vector2(reference))
	targets.append(Vector2(918.0, 1180.0))  # pad letterbox stage at 800²
	targets.append(Vector2(2800.0, 2200.0))  # VP_MAX first resize
	targets.append(Vector2(3000.0, 2400.0))  # VP_MAX second resize
	for target: Vector2 in targets:
		scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
		scene.size = target
		scene._fit()
		var frame: Rect2 = Rect2(Vector2.ZERO, target)
		var display: Rect2 = Rect2(scene._display.position, scene._display.size)
		_check(fails, display.is_equal_approx(frame),
				"display covers %s: got %s" % [target, display])
	tree.root.remove_child(scene)
	scene.free()


static func _seats(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_slice()
	var run: RunState = RunState.new_run(content, 717, "run-map-compose")
	var screen: WorldMapScreen = WorldMapScreen.new(WorldMap.benchmark(run), content)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	for shape_name: StringName in StageShape.REFERENCES:
		_mount(screen, shape_name)
		screen._layout_waystones()
		var projected: PackedVector2Array = screen.projected_seats()
		_check(fails, projected.size() == screen.map.nodes.size()
				and screen._waystones.size() == screen.map.nodes.size(),
				"%s: projected seats match the node list" % shape_name)
		var reachable: Array[int] = screen.map.reachable()
		var frame: Rect2 = Rect2(Vector2.ZERO, screen.size)
		for i: int in reachable:
			_check(fails, projected[i].is_finite(),
					"%s: reachable %d projected seat is finite" % [shape_name, i])
			var k: float = screen._waystones[i].scale.x
			var centre: Vector2 = screen._waystones[i].position \
					+ screen._waystones[i].size * k * 0.5
			_check(fails, centre.distance_to(projected[i]) < 0.6,
					"%s: waystone %d sits on its projected seat" % [shape_name, i])
		if shape_name == StageShape.IDENTITY and not reachable.is_empty():
			var focus: int = screen.map.at if reachable.has(screen.map.at) \
					else reachable[0]
			_check(fails, frame.has_point(projected[focus]),
					"%s: the focused waystone is on-screen" % shape_name)
			_check(fails, projected[focus].distance_to(Vector2.ZERO) > 8.0,
					"%s: the open waystone is not seated at the origin" % shape_name)
	tree.root.remove_child(screen)
	screen.free()


static func _pin_select(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_slice()
	var run: RunState = RunState.new_run(content, 717, "run-map-pin-select")
	var screen: WorldMapScreen = WorldMapScreen.new(WorldMap.benchmark(run), content)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	_mount(screen, StageShape.IDENTITY)
	screen._layout_waystones()
	var seats: PackedVector2Array = screen.projected_seats()
	var reachable: Array[int] = screen.map.reachable()
	_check(fails, not reachable.is_empty(), "seed 717 opens at least one node")
	if reachable.size() >= 2:
		_check(fails, seats[reachable[0]].distance_to(
				seats[reachable[reachable.size() - 1]]) > 16.0,
				"reachable seats are spread, not piled")
	for i: int in reachable:
		var picked: int = screen.pick_node_at(seats[i])
		_check(fails, picked == i,
				"tap at projected seat %d chooses node %d (got %d, seat=%s, radius=%.1f)"
				% [i, i, picked, str(seats[i]), screen._pin_hit()])
	if not reachable.is_empty():
		var miss: Vector2 = Vector2(-80.0, -80.0)
		_check(fails, screen.pick_node_at(miss) == -1,
				"a tap off every pin rect chooses nothing")
	tree.root.remove_child(screen)
	screen.free()


## Production graph paint asks for both endpoints of every edge. All readers at
## one camera pose must share one whole-map projection rather than multiplying
## it by the edge count (#447).
static func _projection_cache(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_slice()
	var run: RunState = RunState.new_run(content, 717, "run-map-projection-cache")
	var screen: WorldMapScreen = WorldMapScreen.new(WorldMap.benchmark(run), content)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	_mount(screen, StageShape.IDENTITY)
	var before: int = screen._seat_projection_passes
	var first: PackedVector2Array = screen.projected_seats()
	var after_first: int = screen._seat_projection_passes
	for node: MapNode in screen.map.nodes:
		screen._node_pos(node)
	screen._layout_waystones()
	var after_readers: int = screen._seat_projection_passes
	_check(fails, first.size() == screen.map.nodes.size()
			and after_first == before + 1,
			"first reader performs one whole-map projection")
	_check(fails, after_readers == after_first,
			"same-pose layout and graph readers reuse the projection")
	screen._map_scene.get_rig().pan_world(Vector2(1.0, 0.0))
	var moved: PackedVector2Array = screen.projected_seats()
	_check(fails, screen._seat_projection_passes == after_first + 1,
			"camera movement performs exactly one new projection")
	_check(fails, not moved.is_empty() and not first.is_empty()
			and not moved[0].is_equal_approx(first[0]),
			"camera movement changes the cached seats")
	var after_move: int = screen._seat_projection_passes
	screen.projected_seats()
	_check(fails, screen._seat_projection_passes == after_move,
			"repeated reader at the moved pose reuses the projection")
	tree.root.remove_child(screen)
	screen.free()


static func _mount(screen: WorldMapScreen, shape_name: StringName) -> void:
	var reference: Vector2i = StageShape.REFERENCES[shape_name]
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(reference)
	screen.set_shape(shape_name)
	var scene: MapScene = screen._map_scene
	if scene == null:
		return
	scene.size = screen.size
	scene._fit()
