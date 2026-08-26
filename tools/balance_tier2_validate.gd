extends SceneTree
## Actual ContentDB.enemy_override_faults gate for generated #508 bundles.
func _initialize() -> void:
	var bundle: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--bundle="):
			bundle = arg.trim_prefix("--bundle=")
	if bundle.is_empty():
		_fail("--bundle is required")
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(bundle.path_join("manifest.json")))
	if typeof(raw) != TYPE_DICTIONARY:
		_fail("manifest did not parse")
		return
	var manifest: Dictionary = raw
	var candidates_v: Variant = manifest.get("candidates", [])
	if typeof(candidates_v) != TYPE_ARRAY or candidates_v.size() != 81:
		_fail("manifest must contain 81 candidates")
		return
	var count: int = 0
	for candidate_v: Variant in candidates_v:
		var candidate: Dictionary = candidate_v
		var directory: String = bundle.path_join(str(candidate.get("id", "")))
		var content: ContentDB = ContentDB.load_from(directory.path_join("full-content.json"), false)
		var mobs_v: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("mob-overrides.json")))
		if content == null or typeof(mobs_v) != TYPE_DICTIONARY:
			_fail("%s candidate files did not load" % candidate.get("id", ""))
			return
		var mobs: Dictionary = mobs_v
		var faults: PackedStringArray = content.enemy_override_faults(mobs)
		for enemy_v: Variant in mobs:
			if not EnemyAi.handles(StringName(str(enemy_v))):
				faults.append("%s has no EnemyAi path" % str(enemy_v))
		if not faults.is_empty() or not content.apply_enemy_overrides(mobs).is_empty():
			_fail("%s failed enemy_override_faults: %s" % [candidate.get("id", ""), faults[0] if not faults.is_empty() else "apply rejected prevalidated overrides"])
			return
		count += 1
	print(JSON.stringify({"validated": count, "method": "ContentDB.enemy_override_faults"}))
	quit(0)
func _fail(message: String) -> void:
	push_error("balance_tier2_validate: %s" % message)
	quit(2)
