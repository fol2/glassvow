extends SceneTree
## Headless test runner: discovers res://tests/test_*.gd and calls static run(fails).


func _initialize() -> void:
	var fails: Array[String] = []
	var scripts: Array[String] = _discover()
	if scripts.is_empty():
		print("run_all: no test_*.gd under res://tests/")
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
