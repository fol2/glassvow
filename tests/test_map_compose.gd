extends RefCounted
## #234 slice 7b: WorldMapScreen seats pins on the lattice projection; MapScene
## owns world input. Seed-717 projection↔hit-test agreement stays in test_map_pins.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_compose: %s" % what)


static func run(fails: Array[String]) -> void:
	_five_shapes(fails)
	_surface_rects(fails)
	_act_and_live(fails)
	_seats(fails)
	_pin_select(fails)
	_projection_cache(fails)


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
		_check(fails, screen._path_band != null and screen._veil_band != null
				and screen._chip_band != null
				and screen._path_band.get_index() > 0,
				"%s: path overlay + chips + veil stay in front" % shape_name)
		var extra: int = 0
		for child: Node in screen.get_children():
			if child is MapBand and not (
					child is MapBand.PathBand
					or child is MapBand.ChipBand
					or child is MapBand.VeilBand):
				extra += 1
		_check(fails, extra == 0,
				"%s: only path/chip/veil MapBand children remain" % shape_name)
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
