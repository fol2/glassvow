extends RefCounted
## #234 slice 7a: WorldMapScreen hosts MapScene behind the live band stack.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_compose: %s" % what)


static func run(fails: Array[String]) -> void:
	_five_shapes(fails)
	_act_and_live(fails)
	_seats(fails)


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
				and scene.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"%s: MapScene is input-transparent" % shape_name)
		_check(fails, screen._sky_band != null and screen._path_band != null
				and screen._veil_band != null
				and screen._sky_band.get_index() > 0,
				"%s: band stack remains in front" % shape_name)
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
	screen._dragging = true
	screen._process(0.016)
	_check(fails, scene.is_live(), "pan unfreezes the world surface")
	screen._dragging = false
	screen._cam_velocity = 0.0
	screen._cam_x = screen._cam_target
	screen._process(0.016)
	_check(fails, not scene.is_live(), "pan end re-arms freeze")
	screen._travelling = true
	screen._process(0.016)
	_check(fails, scene.is_live(), "travel unfreezes the world surface")
	screen._travelling = false
	screen._process(0.016)
	_check(fails, not scene.is_live(), "travel end re-arms freeze")
	screen.size = Vector2(StageShape.REFERENCES[StageShape.IDENTITY])
	screen._cam_target = screen._cam_x + 80.0
	screen._process(0.016)
	_check(fails, scene.is_live(), "wheel-scroll gap unfreezes the world surface")
	screen._cam_x = screen._cam_target
	screen._process(0.016)
	_check(fails, not scene.is_live(), "scroll settle re-arms freeze")
	screen.free()


static func _seats(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_slice()
	var run: RunState = RunState.new_run(content, 717, "run-map-compose")
	var screen: WorldMapScreen = WorldMapScreen.new(WorldMap.benchmark(run), content)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	for shape_name: StringName in StageShape.REFERENCES:
		_mount(screen, shape_name)
		screen._layout_waystones()
		var live: PackedVector2Array = PackedVector2Array()
		live.resize(screen.map.nodes.size())
		for i: int in range(screen.map.nodes.size()):
			live[i] = screen._node_pos(screen.map.nodes[i])
		var projected: PackedVector2Array = screen.projected_seats()
		_check(fails, live.size() == screen.map.nodes.size()
				and projected.size() == screen.map.nodes.size(),
				"%s: live and projected seat sets both exist" % shape_name)
		var reachable: Array[int] = screen.map.reachable()
		var frame: Rect2 = Rect2(Vector2.ZERO, screen.size)
		for i: int in reachable:
			_check(fails, projected[i].is_finite(),
					"%s: reachable %d projected seat is finite" % [shape_name, i])
			if shape_name == StageShape.IDENTITY:
				_check(fails, frame.has_point(live[i]),
						"%s: reachable %d live seat is on-screen" % [shape_name, i])
				_check(fails, frame.has_point(projected[i]),
						"%s: reachable %d projected seat is on-screen" % [
							shape_name, i])
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
	scene._fit()
