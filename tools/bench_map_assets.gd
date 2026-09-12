extends Node
## Release-renderer active-act catalogue residency and unloading probe for #295.
## Hosted by application/main.gd because iOS ignores `-s` on a deployed app.
## Launch through Info.plist user args: --map-asset-bench. The JSONL report is
## flushed after every row so CoreDevice can pull a complete prefix at any time.

const REPORT_PATH: String = "user://map_asset_report.jsonl"
const ACTS: int = 4
const CYCLES: int = 4
const SETTLE_FRAMES: int = 90
const FINAL_FRAMES: int = 180

var _scene: MapScene
var _report: FileAccess
var _failures: Array[String] = []


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("bench_map_assets needs a real renderer")
		get_tree().quit(2)
		return
	_report = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if _report == null:
		push_error("bench_map_assets cannot open %s" % REPORT_PATH)
		get_tree().quit(2)
		return
	_scene = MapScene.new()
	_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_scene)
	_emit({
		"type": "start",
		"engine": str(Engine.get_version_info().get("string", "")),
		"model": OS.get_model_name(),
		"os": OS.get_version(),
		"locale": str(Locale.active.code),
		"manifest_sha256": _sha256(MapLandscapeAssets.ROOT + "provenance.json"),
		"screen": [get_viewport().size.x, get_viewport().size.y],
		"cycles": CYCLES,
		"settle_frames": SETTLE_FRAMES,
	})
	await _frames(SETTLE_FRAMES)
	await _run()


func _run() -> void:
	var previous: Dictionary[String, WeakRef] = {}
	var previous_paths: PackedStringArray = PackedStringArray()
	var samples: Array[Dictionary] = []
	for cycle: int in range(CYCLES):
		for act: int in range(ACTS):
			previous = _weak_resources(previous_paths, _scene.active_asset_resources())
			_scene.set_act(act)
			await _frames(SETTLE_FRAMES)
			var current_paths: PackedStringArray = _scene.active_asset_paths()
			var retained: PackedStringArray = _retained_old_only(previous, current_paths)
			if not retained.is_empty():
				_failures.append("cycle %d act %d retained %s" % [cycle, act, retained])
			var sample: Dictionary = {
				"type": "sample",
				"cycle": cycle,
				"act": act + 1,
				"paths": Array(current_paths),
				"resources": _scene.active_asset_resources().size(),
				"old_only_retained": Array(retained),
				"renderer_mib": _monitor_mib(Performance.RENDER_VIDEO_MEM_USED),
				"object_resources": int(Performance.get_monitor(
						Performance.OBJECT_RESOURCE_COUNT)),
				"process_static_mib": _monitor_mib(Performance.MEMORY_STATIC),
			}
			samples.append(sample)
			_emit(sample)
			previous_paths = current_paths
	await _frames(FINAL_FRAMES)
	var result: Dictionary = {
		"type": "complete",
		"ok": _failures.is_empty(),
		"failures": _failures,
		"samples": samples.size(),
		"renderer_mib": _monitor_mib(Performance.RENDER_VIDEO_MEM_USED),
		"process_static_mib": _monitor_mib(Performance.MEMORY_STATIC),
	}
	_emit(result)
	print("MAP_ASSET_BENCH_COMPLETE %s" % JSON.stringify(result))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _weak_resources(paths: PackedStringArray, resources: Array[Resource]) \
		-> Dictionary[String, WeakRef]:
	var refs: Dictionary[String, WeakRef] = {}
	for i: int in range(mini(paths.size(), resources.size())):
		refs[paths[i]] = weakref(resources[i])
	return refs


func _retained_old_only(previous: Dictionary[String, WeakRef],
		current: PackedStringArray) -> PackedStringArray:
	var retained: PackedStringArray = PackedStringArray()
	for path: String in previous:
		if path in current:
			continue
		var ref: WeakRef = previous[path]
		if ref.get_ref() != null:
			retained.append(path)
	return retained


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _monitor_mib(which: int) -> float:
	return snappedf(float(Performance.get_monitor(which)) / 1048576.0, 0.001)


func _sha256(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "missing"
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "unreadable"
	while file.get_position() < file.get_length():
		context.update(file.get_buffer(mini(1048576,
				file.get_length() - file.get_position())))
	return context.finish().hex_encode()


func _emit(row: Dictionary) -> void:
	var text: String = JSON.stringify(row)
	print("MAP_ASSET %s" % text)
	_report.store_line(text)
	_report.flush()
