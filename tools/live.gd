extends Node
## Long-lived capture host: one process that stays up, so repeated captures cost
## no window activation — and reloads its own code, so a source change does not
## cost one either.
##
## macOS hands the desktop to Godot the moment a window appears, and no
## engine-side flag declines it (tools/shot.sh records everything measured and
## lost). A process per capture therefore interrupts you every time; so does a
## host that must be restarted after every edit. This host boots once and then
## rebuilds the game in place: scripts are re-parsed through the resource cache
## and the scene is re-instantiated from disk, all inside the process that
## already owns its window.
##
## It adds nothing to the game — the real main scene is instantiated as-is, with
## funplay's runtime bridge beside it serving capture_view / send_input /
## query_node over user:// command files. Drive all of it with tools/live.sh.
##
## Limits worth knowing: a reload re-parses scripts and rebuilds the scene, so
## run state is discarded by design (that is what makes a capture reproducible).
## Adding or renaming a `class_name`, or editing this host or the autoload set,
## still needs a restart — the global class registry is built at boot. Do not
## pass --shot here; that hook captures once and quits.

const GAME_SCENE_PATH: String = "res://application/main.tscn"
const BRIDGE_SCRIPT_PATH: String = "res://addons/funplay_mcp/runtime/funplay_mcp_runtime_bridge.gd"
const REQUEST_PATH: String = "user://glassvow_live_request.json"
const RESULT_PATH: String = "user://glassvow_live_result.json"
const READY_PATH: String = "user://glassvow_live_ready"
## A viewport texture read before the rebuilt screen has painted comes back
## black, so nothing is announced as ready until it has settled. Thirty frames
## is what main.gd's own --shot hook waits for, and it holds here too.
const SETTLE_FRAMES: int = 30
## Scripts are re-parsed in two passes: a dependency compiled after its
## dependent leaves the first pass holding the older copy, and the second pass
## settles it. Deeper chains than that are rare enough to restart for.
const RELOAD_PASSES: int = 2

var _game: Node = null
var _last_request_id: String = ""


func _ready() -> void:
	var bridge: Node = Node.new()
	bridge.name = "FunplayRuntimeBridge"
	bridge.set_script(load(BRIDGE_SCRIPT_PATH))
	add_child(bridge)
	_build_game()
	_announce_ready()


func _process(_delta: float) -> void:
	if not FileAccess.file_exists(REQUEST_PATH):
		return
	var raw: String = FileAccess.get_file_as_string(REQUEST_PATH).strip_edges()
	if raw == "":
		return
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return
	var request: Dictionary = parsed
	var request_id: String = str(request.get("id", "")).strip_edges()
	if request_id == "" or request_id == _last_request_id:
		return
	_last_request_id = request_id
	_answer(request_id, str(request.get("command", "")).strip_edges())


func _answer(request_id: String, command: String) -> void:
	var started_usec: int = Time.get_ticks_usec()
	var result: Dictionary = {"id": request_id, "command": command}
	match command:
		"reload":
			result.merge(await _reload())
		_:
			result["success"] = false
			result["error"] = "Unknown live host command '%s'." % command
	result["elapsed_msec"] = float(Time.get_ticks_usec() - started_usec) / 1000.0
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t") + "\n")


## Re-parse every project script, then rebuild the game from the scene on disk.
## Errors are reported rather than raised: a half-typed edit should leave the
## host answering commands, not take it down.
func _reload() -> Dictionary:
	# A screen being rebuilt calls grab_focus(), which makes this window key
	# again and drags the macOS desktop over with it. Key status is declined
	# for the length of the rebuild only — left on permanently the desktop
	# never comes back, because a window that can never be key is never the one
	# the system hands focus to next (measured).
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	# Order matters and the engine is strict about it: GDScript refuses to
	# reload a script while any instance of it is alive, and queue_free() only
	# takes effect at the end of the frame. So the game is freed outright,
	# before a single script is touched.
	_teardown_game()
	var paths: PackedStringArray = PackedStringArray()
	_collect_scripts("res://", paths)
	var failed: PackedStringArray = PackedStringArray()
	for pass_index: int in RELOAD_PASSES:
		failed = PackedStringArray()
		for path: String in paths:
			var resource: Resource = ResourceLoader.load(
				path, "GDScript", ResourceLoader.CACHE_MODE_REPLACE)
			if resource == null:
				failed.append(path)
				continue
			var script: GDScript = resource as GDScript
			if script == null:
				failed.append(path)
				continue
			# reload() re-compiles the source the object is already holding, so
			# without re-reading the file first it is a no-op that still
			# reports OK. This is the step that makes an edit take effect.
			script.source_code = FileAccess.get_file_as_string(path)
			if script.reload(false) != OK:
				failed.append(path)
	if not _build_game():
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, false)
		return {
			"success": false,
			"error": "Scripts reloaded but the scene failed to rebuild — see the host log.",
			"scripts": paths.size(),
			"failed_scripts": failed,
		}
	# The reply doubles as "safe to capture now", so it waits for the paint.
	await _settle()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, false)
	# A script that refused to re-parse leaves the old copy running, so the
	# capture that follows would show stale code while the reply claimed
	# success. Reporting the refusal is the difference between a reload and a
	# lie. The usual cause is a `class_name` that did not exist at boot: the
	# global class registry is built once, so a script referring to a new one
	# cannot compile until the host is restarted (measured, not assumed).
	if not failed.is_empty():
		return {
			"success": false,
			"error": "%d script(s) kept their old code — restart the host if you added or renamed a class_name." % failed.size(),
			"scripts": paths.size(),
			"failed_scripts": failed,
		}
	return {
		"success": true,
		"scripts": paths.size(),
		"failed_scripts": failed,
	}


func _announce_ready() -> void:
	await _settle()
	var file: FileAccess = FileAccess.open(READY_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("ready\n")


func _settle() -> void:
	for frame: int in SETTLE_FRAMES:
		await get_tree().process_frame


func _teardown_game() -> void:
	if _game == null:
		return
	remove_child(_game)
	_game.free()
	_game = null


func _build_game() -> bool:
	_teardown_game()
	var scene: Resource = ResourceLoader.load(
		GAME_SCENE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	var packed: PackedScene = scene as PackedScene
	if packed == null:
		push_error("Live host could not load %s" % GAME_SCENE_PATH)
		return false
	_game = packed.instantiate()
	if _game == null:
		push_error("Live host could not instantiate %s" % GAME_SCENE_PATH)
		return false
	add_child(_game)
	return true


func _collect_scripts(dir_path: String, out: PackedStringArray) -> void:
	# Skip the two trees that are the host rather than the game: addons holds
	# the bridge answering this very command, and tools holds this script —
	# reloading either would pull the channel out from under the reply.
	if dir_path.begins_with("res://addons") or dir_path.begins_with("res://tools"):
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for name: String in dir.get_files():
		if name.ends_with(".gd"):
			out.append(dir_path.path_join(name))
	for name: String in dir.get_directories():
		if name.begins_with("."):
			continue
		_collect_scripts(dir_path.path_join(name), out)
