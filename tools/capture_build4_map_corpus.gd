extends SceneTree
## Reproducible TestFlight 1.0.0 (4) map-defect capture matrix (#462).
##
## This is evidence tooling only. It constructs the production WorldMapScreen,
## uses WorldMap.for_run for the graph, calls WorldMapScreen.refresh for the
## focused pose, and uses MapCameraRig.DEFAULT_XZ for the canonical opening
## pose. It does not pan, tune, or replace any production map input.

const BUILD4_SOURCE_COMMIT: String = "52a56e726da70c2dd57254e8c6618682c7558f90"
const MAP_MANIFEST_PATH: String = MapMaterials.MANIFEST_PATH
const LOCALE_CODE: StringName = &"en"
const GENERATED_ACTS: Array[int] = [0, 1, 2]
const GENERATED_SEEDS: Array[int] = [717, 17634]
const AUTHORED_ACT: int = 3
const AUTHORED_ACT_SEED: int = 717
const SETTLE_FRAMES: int = 4

var _output_dir: String = ""
var _capture_head: String = ""
var _expected_manifest_sha256: String = ""
var _frames: Array[Dictionary] = []
var _next_frame_number: int = 1


func _initialize() -> void:
	var parse_error: String = _parse_args()
	if not parse_error.is_empty():
		printerr("capture_build4_map_corpus: " + parse_error)
		quit(2)
		return

	var manifest_sha256: String = FileAccess.get_sha256(MAP_MANIFEST_PATH)
	if manifest_sha256.is_empty():
		printerr("capture_build4_map_corpus: cannot hash " + MAP_MANIFEST_PATH)
		quit(2)
		return
	if manifest_sha256 != _expected_manifest_sha256:
		printerr("capture_build4_map_corpus: asset manifest changed: expected %s, got %s" % [
			_expected_manifest_sha256, manifest_sha256])
		quit(2)
		return

	var make_error: Error = DirAccess.make_dir_recursive_absolute(_absolute(_output_dir.path_join("raw")))
	if make_error != OK:
		printerr("capture_build4_map_corpus: cannot create output: " + error_string(make_error))
		quit(2)
		return

	# The issue binds one locale rather than multiplying the matrix by locale.
	# Publish the handle before ContentDB hydration so every production label is
	# built from the same English catalogue.
	Locale.active = Locale.new(LOCALE_CODE)
	var content: ContentDB = ContentDB.load_full()
	Locale.active.hydrate_content(content)

	for act_index: int in GENERATED_ACTS:
		for seed: int in GENERATED_SEEDS:
			for shape: StringName in StageShape.SHIPPING:
				var generated_error: Error = await _capture_case_shape(
					content, act_index, act_index + 1, seed, true, shape)
				if generated_error != OK:
					quit(1)
					return
	for shape: StringName in StageShape.SHIPPING:
		var authored_error: Error = await _capture_case_shape(
			content, AUTHORED_ACT, AUTHORED_ACT + 1, AUTHORED_ACT_SEED, false, shape)
		if authored_error != OK:
			quit(1)
			return

	var manifest: Dictionary = _manifest(manifest_sha256)
	var manifest_path: String = _absolute(_output_dir.path_join("manifest.json"))
	var write_error: Error = _write_json(manifest_path, manifest)
	if write_error != OK:
		printerr("capture_build4_map_corpus: manifest write failed: " + error_string(write_error))
		quit(1)
		return
	print("capture_build4_map_corpus: %d frames -> %s" % [_frames.size(), manifest_path])
	quit(0)


func _parse_args() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			_output_dir = arg.trim_prefix("--output=")
		elif arg.begins_with("--capture-head="):
			_capture_head = arg.trim_prefix("--capture-head=").to_lower()
		elif arg.begins_with("--asset-manifest-sha256="):
			_expected_manifest_sha256 = arg.trim_prefix("--asset-manifest-sha256=").to_lower()
	if _output_dir.is_empty():
		return "missing --output=PATH"
	if not _is_sha256(_capture_head):
		return "--capture-head must be a 40-character Git commit SHA"
	if not _is_sha256(_expected_manifest_sha256, 64):
		return "--asset-manifest-sha256 must be a 64-character SHA-256 digest"
	return ""


func _capture_case_shape(
		content: ContentDB,
		act_index: int,
		act_number: int,
		seed: int,
		generated: bool,
		shape: StringName
) -> Error:
	var viewport_size: Vector2i = StageShape.REFERENCES[shape]
	DisplayServer.window_set_size(viewport_size)
	root.size = viewport_size
	root.content_scale_size = viewport_size
	await process_frame
	await process_frame

	var run: RunState = RunState.new_run(content, seed)
	run.act = act_index
	var world_map: WorldMap = WorldMap.for_run(run, content)
	var rng_after_map: int = run.rng_state()
	var screen: WorldMapScreen = WorldMapScreen.new(world_map, content, shape)
	root.add_child(screen)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.position = Vector2.ZERO
	screen.size = Vector2(viewport_size)
	screen.refresh(run)
	# PointerDrift and live-input state are intentionally absent from the corpus.
	# We manually ask the real screen to re-layout after each canonical camera
	# pose, so no hand-pan or timing-dependent pointer position enters the packet.
	screen.set_process(false)
	await process_frame
	await process_frame

	var map_scene: MapScene = screen._map_scene
	if map_scene == null:
		printerr("capture_build4_map_corpus: production map surface missing")
		root.remove_child(screen)
		screen.free()
		return ERR_DOES_NOT_EXIST
	map_scene._fit()

	var active_assets: Array[String] = []
	for path: String in map_scene.active_asset_paths():
		active_assets.append(path)
	active_assets.sort()

	for zoom_stop: int in range(MapCameraRig.ZOOM_STOPS.size()):
		for pose: String in ["opening", "focused"]:
			var capture_error: Error = await _capture_frame(
				screen, map_scene, run, world_map,
				act_index, act_number, seed, generated, shape, viewport_size,
				zoom_stop, pose, rng_after_map, active_assets)
			if capture_error != OK:
				root.remove_child(screen)
				screen.free()
				return capture_error

	root.remove_child(screen)
	screen.free()
	await process_frame
	return OK


func _capture_frame(
		screen: WorldMapScreen,
		map_scene: MapScene,
		run: RunState,
		world_map: WorldMap,
		act_index: int,
		act_number: int,
		seed: int,
		generated: bool,
		shape: StringName,
		viewport_size: Vector2i,
		zoom_stop: int,
		pose: String,
		rng_after_map: int,
		active_assets: Array[String]
) -> Error:
	var rig: MapCameraRig = map_scene.get_rig()
	rig.set_zoom_stop(zoom_stop)
	if pose == "focused":
		# refresh() calls the production _seat_marker -> _focus_xz path.
		screen.refresh(run)
	else:
		rig.set_camera_xz(MapCameraRig.DEFAULT_XZ)
	map_scene._fit()
	screen._layout_waystones()
	screen._push_bands(true)
	map_scene.set_live(true)
	for _frame: int in range(SETTLE_FRAMES):
		await process_frame

	var image: Image = root.get_texture().get_image()
	if image == null:
		printerr("capture_build4_map_corpus: viewport texture unavailable")
		return ERR_CANT_ACQUIRE_RESOURCE
	if image.get_width() != viewport_size.x or image.get_height() != viewport_size.y:
		printerr("capture_build4_map_corpus: frame size drift for %s: expected %s, got %dx%d" % [
			shape, viewport_size, image.get_width(), image.get_height()])
		return ERR_INVALID_DATA

	var zoom_size: int = int(MapCameraRig.ZOOM_STOPS[zoom_stop])
	var filename: String = _filename(act_number, seed, shape, zoom_stop, zoom_size, pose)
	var relative_path: String = "raw/" + filename
	var output_path: String = _absolute(_output_dir.path_join(relative_path))
	var save_error: Error = image.save_png(output_path)
	if save_error != OK:
		printerr("capture_build4_map_corpus: save failed for %s: %s" % [
			output_path, error_string(save_error)])
		return save_error

	var camera: Vector2 = rig.camera_xz()
	_frames.append({
		"frame_id": "F%03d" % _next_frame_number,
		"file": relative_path,
		"act": act_number,
		"act_index": act_index,
		"seed": seed,
		"generated_act": generated,
		"shape": String(shape),
		"viewport": {"width": viewport_size.x, "height": viewport_size.y},
		"zoom_stop": zoom_stop,
		"zoom_size": MapCameraRig.ZOOM_STOPS[zoom_stop],
		"pose": pose,
		"camera_xz": {"x": camera.x, "z": camera.y},
		"locale": String(LOCALE_CODE),
		"map_region": world_map.region,
		"map_at": world_map.at,
		"node_count": world_map.nodes.size(),
		"reachable_count": world_map.reachable().size(),
		"rng_state_after_map": rng_after_map,
		"active_asset_paths": active_assets.duplicate(),
	})
	_next_frame_number += 1
	map_scene.set_live(false)
	await process_frame
	print("capture_build4_map_corpus: " + filename)
	return OK


func _manifest(manifest_sha256: String) -> Dictionary:
	var shapes: Array[Dictionary] = []
	for shape: StringName in StageShape.SHIPPING:
		var size: Vector2i = StageShape.REFERENCES[shape]
		shapes.append({"name": String(shape), "width": size.x, "height": size.y})
	var zoom_stops: Array[Dictionary] = []
	for i: int in range(MapCameraRig.ZOOM_STOPS.size()):
		zoom_stops.append({"index": i, "size": MapCameraRig.ZOOM_STOPS[i]})
	return {
		"schema": 1,
		"issue": 462,
		"product": "TestFlight 1.0.0 (4)",
		"build4_source_commit": BUILD4_SOURCE_COMMIT,
		"capture_head": _capture_head,
		"godot": Engine.get_version_info()["string"],
		"display_server": DisplayServer.get_name(),
		"rendering_method": str(ProjectSettings.get_setting(
			"rendering/renderer/rendering_method", "gl_compatibility")),
		"asset_manifest": {
			"path": MAP_MANIFEST_PATH,
			"sha256": manifest_sha256,
		},
		"locale": String(LOCALE_CODE),
		"matrix": {
			"generated_acts": [1, 2, 3],
			"generated_seeds": GENERATED_SEEDS,
			"authored_act": 4,
			"authored_act_seed": AUTHORED_ACT_SEED,
			"shapes": shapes,
			"zoom_stops": zoom_stops,
			"poses": ["opening", "focused"],
			"expected_frames": 168,
		},
		"frame_count": _frames.size(),
		"frames": _frames,
	}


func _filename(
		act_number: int,
		seed: int,
		shape: StringName,
		zoom_stop: int,
		zoom_size: int,
		pose: String
) -> String:
	return "act-%02d_seed-%08d_shape-%s_zoom-%02d-%02d_pose-%s_locale-%s.png" % [
		act_number, seed, String(shape), zoom_stop, zoom_size, pose, String(LOCALE_CODE)]


func _write_json(path: String, value: Variant) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t", true, true) + "\n")
	file.close()
	return OK


func _absolute(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path


func _is_sha256(value: String, length: int = 40) -> bool:
	if value.length() != length:
		return false
	for i: int in range(value.length()):
		var character: String = value.substr(i, 1)
		if "0123456789abcdef".find(character) < 0:
			return false
	return true
