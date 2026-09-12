extends SceneTree
## Headless test runner: discovers res://tests/test_*.gd and calls static run(fails).
## Pass -- --tests=res://tests/test_a.gd,res://tests/test_b.gd for a fail-closed subset.


func _initialize() -> void:
	var fails: Array[String] = []
	var scripts: Array[String] = _select_scripts(fails)
	if scripts.is_empty():
		print("run_all: no test_*.gd selected under res://tests/")
	for path: String in scripts:
		var script: Script = load(path) as Script
		if script == null:
			fails.append("%s: failed to load" % path)
			continue
		var before: int = fails.size()
		script.call("run", fails)
		if fails.size() == before:
			print("ok   %s" % path)
		else:
			print("FAIL %s" % path)
	if fails.is_empty():
		print("PASS (%d tests)" % scripts.size())
		quit(0)
	else:
		print("FAIL (%d)" % fails.size())
		for msg: String in fails:
			print("  - %s" % msg)
		quit(1)


func _select_scripts(fails: Array[String]) -> Array[String]:
	var requested: Array[String] = []
	var saw_filter: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--tests="):
			continue
		if saw_filter:
			fails.append("run_all: --tests may be supplied only once")
			continue
		saw_filter = true
		var raw: String = arg.substr("--tests=".length())
		if raw.is_empty():
			fails.append("run_all: --tests requires at least one path")
			continue
		var parts: PackedStringArray = raw.split(",", true)
		for entry: String in parts:
			var path: String = entry.strip_edges()
			if path.is_empty():
				fails.append("run_all: requested test path may not be empty")
				continue
			if not path.begins_with("res://tests/test_") or not path.ends_with(".gd") or path.contains(".."):
				fails.append("run_all: invalid requested test path %s" % path)
				continue
			if not FileAccess.file_exists(path):
				fails.append("run_all: requested test does not exist: %s" % path)
				continue
			if requested.has(path):
				fails.append("run_all: duplicate requested test: %s" % path)
				continue
			requested.append(path)
	if not saw_filter:
		return _discover()
	requested.sort()
	return requested


func _discover() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open("res://tests")
	if dir == null:
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.begins_with("test_") and name.ends_with(".gd"):
			out.append("res://tests/%s" % name)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out
