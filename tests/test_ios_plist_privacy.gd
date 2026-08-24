extends RefCounted
## Pins empty iOS usage-description export options and the strip that omits them.

const Privacy: GDScript = preload("res://addons/glassvow_ios_export/ios_plist_privacy.gd")

const SAMPLE_PLIST: String = """<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>ITSAppUsesNonExemptEncryption</key>
	<false />
	<key>NSCameraUsageDescription</key>
	<string></string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string></string>
	<key>NSMicrophoneUsageDescription</key>
	<string></string>
	<key>UIRequiresFullScreen</key>
	<true/>
</dict>
</plist>
"""


static func run(fails: Array[String]) -> void:
	_plugin_enabled(fails)
	_presets(fails)
	_strip_empty(fails)
	_strip_keeps_filled(fails)
	_strip_export_nested_plist(fails)


static func _plugin_enabled(fails: Array[String]) -> void:
	if not FileAccess.file_exists("res://addons/glassvow_ios_export/plugin.cfg"):
		fails.append("ios-privacy: glassvow_ios_export plugin.cfg is missing")
	var project: String = FileAccess.get_file_as_string("res://project.godot")
	if not project.contains("res://addons/glassvow_ios_export/plugin.cfg"):
		fails.append("ios-privacy: editor plugin is not enabled")


static func _presets(fails: Array[String]) -> void:
	var text: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	for name: String in ["iOS", "iOS Dev Review"]:
		var opts: Dictionary = _ios_preset_options(text, name)
		if opts.is_empty():
			fails.append("ios-privacy: %s preset is missing" % name)
			continue
		if str(opts.get("modules/camera", "")) != "false":
			fails.append("ios-privacy: %s must pin modules/camera=false" % name)
		for key: String in [
			"privacy/camera_usage_description",
			"privacy/microphone_usage_description",
			"privacy/photolibrary_usage_description",
		]:
			if not opts.has(key):
				fails.append("ios-privacy: %s is missing %s" % [name, key])
			elif str(opts[key]) != "":
				fails.append("ios-privacy: %s %s must stay empty" % [name, key])


static func _strip_empty(fails: Array[String]) -> void:
	var out: String = Privacy.strip_empty_usage_descriptions(SAMPLE_PLIST)
	for key: String in Privacy.USAGE_KEYS:
		if out.contains(key):
			fails.append("ios-privacy: strip left %s" % key)
	if not out.contains("ITSAppUsesNonExemptEncryption"):
		fails.append("ios-privacy: strip dropped ITSAppUsesNonExemptEncryption")
	if not out.contains("<false />"):
		fails.append("ios-privacy: strip dropped encryption=false")
	if not out.contains("\t<key>UIRequiresFullScreen</key>"):
		fails.append("ios-privacy: strip ate the next key's indent")


static func _strip_keeps_filled(fails: Array[String]) -> void:
	var filled: String = SAMPLE_PLIST.replace(
			"<key>NSCameraUsageDescription</key>\n\t<string></string>",
			"<key>NSCameraUsageDescription</key>\n\t<string>needed</string>")
	var out: String = Privacy.strip_empty_usage_descriptions(filled)
	if not out.contains("NSCameraUsageDescription") or not out.contains("needed"):
		fails.append("ios-privacy: strip dropped a filled camera description")
	if out.contains("NSMicrophoneUsageDescription") \
			or out.contains("NSPhotoLibraryUsageDescription"):
		fails.append("ios-privacy: strip left a sibling empty usage key")


static func _strip_export_nested_plist(fails: Array[String]) -> void:
	var root: String = OS.get_temp_dir().path_join("glassvow_ios_plist_privacy")
	var nested: String = root.path_join("glassvow")
	var plist_path: String = nested.path_join("glassvow-Info.plist")
	DirAccess.make_dir_recursive_absolute(nested)
	var fh: FileAccess = FileAccess.open(plist_path, FileAccess.WRITE)
	if fh == null:
		fails.append("ios-privacy: could not write fixture plist")
		return
	fh.store_string(SAMPLE_PLIST)
	fh = null
	if not Privacy.strip_export(root.path_join("glassvow.ipa")):
		fails.append("ios-privacy: strip_export did not rewrite the nested plist")
	var updated: String = FileAccess.get_file_as_string(plist_path)
	if updated.contains("NSCameraUsageDescription"):
		fails.append("ios-privacy: nested export plist still has usage keys")
	if not updated.contains("ITSAppUsesNonExemptEncryption"):
		fails.append("ios-privacy: nested export plist lost encryption key")
	DirAccess.remove_absolute(plist_path)
	DirAccess.remove_absolute(nested)
	DirAccess.remove_absolute(root)


static func _ios_preset_options(text: String, want: String) -> Dictionary:
	var current_name: String = ""
	var current_opts: Dictionary = {}
	var in_options: bool = false
	for line: String in text.split("\n"):
		if line.begins_with("[preset.") and line.ends_with(".options]"):
			in_options = true
			continue
		if line.begins_with("[preset.") and line.ends_with("]"):
			if current_name == want:
				return current_opts
			in_options = false
			current_name = ""
			current_opts = {}
			continue
		if not in_options:
			if line.begins_with("name="):
				current_name = line.substr(5).trim_prefix("\"").trim_suffix("\"")
				current_opts = {}
			continue
		if current_name != want or line.begins_with(";") or line.strip_edges().is_empty():
			continue
		var eq: int = line.find("=")
		if eq < 0:
			continue
		var raw: String = line.substr(eq + 1)
		current_opts[line.substr(0, eq)] = raw.trim_prefix("\"").trim_suffix("\"")
	if current_name == want:
		return current_opts
	return {}
