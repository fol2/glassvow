class_name SaveService
extends RefCounted
## user://glassvow_save_v1.json persistence. Validation lives in
## RunState.from_save_dict (pure domain); this layer only does file IO.
## Schema freezes when M4 ships — a breaking change needs a version bump and
## a migration handler here (SKILL §8).


const SAVE_PATH: String = "user://glassvow_save_v1.json"


static func store(run: RunState) -> bool:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(run.to_save_dict()))
	f.close()
	return true


## null when there is no save or it fails validation (the player starts fresh).
static func load_run(content: ContentDB) -> RunState:
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var text: String = FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var save: Dictionary = parsed
	return RunState.from_save_dict(save, content)


static func clear() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
