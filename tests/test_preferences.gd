extends RefCounted
## Preferences durable contract: settings.cfg round-trips every section, the
## legacy audio.cfg import happens exactly once, and the default in-memory
## `active` stand-in can never write the player's file. All paths here are
## test-owned so a suite run can never touch real settings.

const TEST_PATH: String = "user://test_p41_settings.cfg"
const TEST_LEGACY: String = "user://test_p41_audio.cfg"


static func run(fails: Array[String]) -> void:
	_cleanup()
	_fresh_boot_defaults(fails)
	_legacy_import_once(fails)
	_round_trip(fails)
	_default_instance_never_writes(fails)
	_cleanup()


static func _fresh_boot_defaults(fails: Array[String]) -> void:
	var prefs: Preferences = Preferences.read_from_disk(TEST_PATH, TEST_LEGACY)
	if prefs.master_volume != Preferences.DEFAULT_MASTER \
			or prefs.music_volume != Preferences.DEFAULT_MUSIC \
			or prefs.sfx_volume != Preferences.DEFAULT_SFX:
		fails.append("preferences: fresh boot did not hold the audio defaults")
	if not prefs.vsync or prefs.fullscreen:
		fails.append("preferences: fresh boot display defaults wrong")
	if not prefs.screen_shake or prefs.reduce_motion:
		fails.append("preferences: fresh boot motion defaults wrong")
	if not FileAccess.file_exists(TEST_PATH):
		fails.append("preferences: fresh boot did not create settings file")


static func _legacy_import_once(fails: Array[String]) -> void:
	_cleanup()
	var legacy: ConfigFile = ConfigFile.new()
	legacy.set_value("music", "volume", 0.8)
	legacy.set_value("music", "muted", true)
	legacy.set_value("sfx", "volume", 0.15)
	legacy.save(TEST_LEGACY)
	var prefs: Preferences = Preferences.read_from_disk(TEST_PATH, TEST_LEGACY)
	if prefs.music_volume != 0.8 or not prefs.music_muted or prefs.sfx_volume != 0.15:
		fails.append("preferences: legacy audio.cfg values were not imported")
	if prefs.master_volume != Preferences.DEFAULT_MASTER:
		fails.append("preferences: import invented a master value")
	# ONE-TIME is the contract: once settings.cfg exists, a later edit to the
	# old file must be invisible — settings.cfg owns every key from now on.
	legacy.set_value("music", "volume", 0.05)
	legacy.save(TEST_LEGACY)
	var again: Preferences = Preferences.read_from_disk(TEST_PATH, TEST_LEGACY)
	if again.music_volume != 0.8:
		fails.append("preferences: legacy file was re-imported on second boot")


static func _round_trip(fails: Array[String]) -> void:
	_cleanup()
	var prefs: Preferences = Preferences.read_from_disk(TEST_PATH, TEST_LEGACY)
	prefs.set_volume(Preferences.MASTER, 0.5)
	prefs.set_muted(Preferences.SFX, true)
	prefs.set_screen_shake(false)
	prefs.set_reduce_motion(true)
	var back: Preferences = Preferences.read_from_disk(TEST_PATH, TEST_LEGACY)
	if back.master_volume != 0.5 or not back.sfx_muted:
		fails.append("preferences: audio changes did not survive a reload")
	if back.screen_shake or not back.reduce_motion:
		fails.append("preferences: motion changes did not survive a reload")


static func _default_instance_never_writes(fails: Array[String]) -> void:
	var absolute: String = ProjectSettings.globalize_path(Preferences.PATH)
	var existed: bool = FileAccess.file_exists(absolute)
	var stamp: int = FileAccess.get_modified_time(absolute) if existed else 0
	var standin: Preferences = Preferences.new()
	standin.set_volume(Preferences.MUSIC, 0.9)
	standin.set_reduce_motion(true)
	if existed:
		if FileAccess.get_modified_time(absolute) != stamp:
			fails.append("preferences: in-memory stand-in wrote the real file")
	elif FileAccess.file_exists(absolute):
		fails.append("preferences: in-memory stand-in created the real file")


static func _cleanup() -> void:
	for path: String in [TEST_PATH, TEST_LEGACY]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
