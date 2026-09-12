extends SceneTree
const Audit = preload("res://tools/map_workshop/act4/audit.gd")
func _initialize() -> void:
	var path: String = "res://docs/map/studies/act4-step3/void-v1/sample-717.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sample="): path = arg.trim_prefix("--sample=")
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(Audit.source_errors(original).is_empty())
	var changed: Dictionary = original.duplicate(true)
	changed["nodes"][4]["type"] = "rest"
	assert(not Audit.source_errors(changed).is_empty())
	changed = original.duplicate(true)
	changed["nodes"].pop_back()
	assert(not Audit.source_errors(changed).is_empty())
	changed = original.duplicate(true)
	changed["hero_sources"]["act4-threshold-window"]["sha256"] = "stale"
	assert(not Audit.source_errors(changed).is_empty())
	changed = original.duplicate(true)
	changed["compiler_hard_pass"] = false
	assert(not Audit.source_errors(changed).is_empty())
	print("ACT4_SOURCE valid sample accepted; changed boss, missing stop, stale asset and compiler failure rejected")
	quit()
