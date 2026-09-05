extends SceneTree
## Headed production map preview without the opening-boon screen.
## godot --path . -s res://tools/preview_map.gd -- --act-index=0 --seed=7 --output=/tmp/map.png
## Omit --output to explore the real map with drag, wheel and keyboard input.

var _output: String = ""
var _pose: String = "focused"
var _cache: String = ""
var _no_shadows: bool = false
var _continuous: bool = false
var _steps: int = 0
var _compile_only: bool = false
var _zoom: int = 2
var _quality_path: String = ""
var _input: MapLayoutInput
var _quality: Dictionary
var _assets: Dictionary

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var act: int = 0
	var seed_value: int = 717
	var shape: StringName = &"pad-landscape"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--act-index="):
			act = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.get_slice("=", 1))
		elif arg.begins_with("--shape="):
			shape = StringName(arg.get_slice("=", 1))
		elif arg.begins_with("--pose="):
			_pose = arg.get_slice("=", 1)
		elif arg.begins_with("--output="):
			_output = arg.trim_prefix("--output=")
		elif arg == "--compile-only":
			_compile_only = true
		elif arg.begins_with("--zoom-stop="):
			_zoom = int(arg.get_slice("=", 1))
		elif arg == "--continuous":
			_continuous = true
		elif arg == "--no-shadows":
			_no_shadows = true
		elif arg.begins_with("--steps="):
			_steps = int(arg.get_slice("=", 1))
		elif arg.begins_with("--cache="):
			_cache = arg.trim_prefix("--cache=")
		elif arg.begins_with("--quality="):
			_quality_path = arg.trim_prefix("--quality=")
		else:
			push_error("Unknown preview argument: " + arg)
			quit(2)
			return
	if act < 0 or act > 3 or not StageShape.SHIPPING.has(shape) \
			or _pose not in ["focused", "opening", "middle", "terminus"] \
			or (DisplayServer.get_name() == "headless" and not _compile_only) or _zoom not in range(4):
		push_error("Preview needs a headed renderer, act index 0–3 and a shipping shape/pose")
		quit(2)
		return
	var dimensions: Vector2i = StageShape.REFERENCES[shape]
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(dimensions)
	root.size = dimensions
	root.content_scale_size = dimensions
	Locale.active = Locale.new(&"en")
	var content: ContentDB = ContentDB.load_full()
	Locale.active.hydrate_content(content)
	var run: RunState = RunState.new_run(content, seed_value)
	run.act = act
	var world_map: WorldMap = WorldMap.for_run(run, content)
	for step: int in range(clampi(_steps, 0, 14)):
		var next: Array[int] = world_map.reachable()
		if not next.is_empty():
			world_map.enter(next[0])
			world_map.clear_current()
	var screen: WorldMapScreen = WorldMapScreen.new(world_map, content, shape)
	screen._layout_compile = _compile
	root.add_child(screen)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(dimensions)
	var start: int = Time.get_ticks_msec()
	screen.refresh(run)
	if screen.layout_result() == null:
		printerr(JSON.stringify(screen.layout_failure()))
		quit(1)
		return
	if not _quality_path.is_empty():
		var report: Dictionary = MapQualityEvaluator.evaluate(_input, screen.layout_result(), _assets, _quality)
		var receipt: FileAccess = FileAccess.open(_quality_path, FileAccess.WRITE)
		if receipt == null:
			push_error("Cannot write map quality result: " + _quality_path)
			quit(2)
			return
		receipt.store_string(JSON.stringify(report))
		receipt.close()
		print("MAP_QUALITY ", report["hard_pass"], " ", report["report_digest"])
		if report["hard_pass"] != true:
			quit(1)
			return
	if _compile_only:
		print("MAP_COMPILE_OK ", screen.layout_input_digest(), " ", screen.layout_digest())
		quit(0)
		return
	root.add_child(RunHud.new(run, content, shape))
	if _no_shadows:
		screen._map_scene.get_key().shadow_enabled = false
	var rig: MapCameraRig = screen._map_scene.get_rig()
	rig.set_zoom_stop(_zoom)
	if _pose == "opening":
		rig.set_camera_xz(MapCameraRig.DEFAULT_XZ)
	elif _pose == "middle":
		rig.set_camera_xz(MapCameraRig.pose_for_world(Vector3.ZERO))
	elif _pose == "terminus":
		rig.set_camera_xz(MapCameraRig.pose_for_world(Vector3(33.0, 0.0, 0.0)))
	screen._layout_waystones()
	screen._push_bands(true)
	if not _output.is_empty():
		if _continuous:
			screen.set_process(false)
		for stone: GlassWaystone in screen._waystones:
			stone.set_process(false)
	screen._map_scene.set_live(_continuous)
	for frame: int in range(12):
		await process_frame
	print("MAP_PREVIEW ", JSON.stringify({"act_index": act, "seed": seed_value,
		"input_digest": screen.layout_input_digest(), "layout_digest": screen.layout_digest(),
		"bind_ms": Time.get_ticks_msec() - start,
		"scenery": screen._map_scene.layout_diagnostics().get("accepted_count", 0)}))
	if _output.is_empty():
		return
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(_output)
	if error != OK:
		printerr(error_string(error))
	quit(0 if error == OK else 1)

## Preview-only reuse of a pure compiler result. The input digest includes all
## geometry authorities; runtime production never reads or writes this cache.
func _compile(input: MapLayoutInput, quality: Dictionary, assets: Dictionary) -> Dictionary:
	_input = input
	_quality = quality
	_assets = assets
	if _cache.is_empty():
		return MapLayoutCompiler.compile(input, quality, assets)
	var path: String = _cache.path_join(input.digest() + ".bin")
	if FileAccess.file_exists(path):
		var cached: FileAccess = FileAccess.open(path, FileAccess.READ)
		var data: Variant = cached.get_var(false) if cached != null else null
		if data is Dictionary and str(data.get("input_digest", "")) == input.digest():
			var record: Dictionary = data
			var result: MapLayoutResult = MapLayoutResult.from_dict(record)
			if result != null:
				print("MAP_PREVIEW_CACHE ", result.digest())
				return {"status": MapLayoutCompiler.COMPILED, "result": result,
					"diagnostics": {"preview_cache": path}}
	print("MAP_PREVIEW_COMPILE ", input.digest())
	var compiled: Dictionary = MapLayoutCompiler.compile(input, quality, assets)
	if compiled.get("result") is MapLayoutResult:
		DirAccess.make_dir_recursive_absolute(_cache)
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_var(compiled["result"].to_dict(), false)
	return compiled
