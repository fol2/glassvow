class_name SaveService
extends RefCounted
## user://glassvow_run_v2.json persistence. Validation lives in
## RunState.from_save_dict (pure domain); this layer only does file IO.
## v1 is not read or migrated: the full-game programme starts a clean v2 run.


const RUN_PATH: String = "user://glassvow_run_v2.json"
const VIGIL_PATH: String = "user://glassvow_vigil_v2.json"


static func store(run: RunState, path: String = RUN_PATH) -> bool:
	return _store_json_atomic(path, run.to_save_dict())


## Write beside the target, flush, then replace it. A failed write or rename
## leaves the last accepted checkpoint readable.
static func _store_json_atomic(path: String, value: Dictionary) -> bool:
	var tmp_path: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(value))
	f.flush()
	f.close()
	var absolute_tmp: String = ProjectSettings.globalize_path(tmp_path)
	var absolute_target: String = ProjectSettings.globalize_path(path)
	if DirAccess.rename_absolute(absolute_tmp, absolute_target) != OK:
		DirAccess.remove_absolute(absolute_tmp)
		return false
	return true


## null when there is no save or it fails validation (the player starts fresh).
static func load_run(content: ContentDB, path: String = RUN_PATH) -> RunState:
	if not FileAccess.file_exists(path):
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var save: Dictionary = parsed
	return RunState.from_save_dict(save, content)


static func store_vigil(vigil: VigilState, path: String = VIGIL_PATH) -> bool:
	return _store_json_atomic(path, vigil.to_dict())


static func load_vigil(path: String = VIGIL_PATH) -> VigilState:
	if not FileAccess.file_exists(path):
		return VigilState.blank()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return VigilState.blank()
	var raw: Dictionary = parsed
	var loaded: VigilState = VigilState.from_dict(raw)
	return loaded if loaded != null else VigilState.blank()


## Refuse to erase a newer run accidentally; terminal receipts pass the run id
## they durably committed.
static func clear_run(expected_run_id: String = "", path: String = RUN_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return true
	if not expected_run_id.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY or str(parsed.get("runId", "")) != expected_run_id:
			return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


## Compatibility for existing callers while this packet lands.
static func clear(path: String = RUN_PATH) -> void:
	clear_run("", path)


static func clear_vigil(path: String = VIGIL_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
