extends RefCounted
## Locks 1.0.0 marketing identity vs the current numeric iOS build, and the App Store
## Connect export options that must not rewrite either. Does not replace
## Sentry dist (#420) or iOS privacy-plist (#432) gates.

const MARKETING: String = "1.0.0"
const IOS_BUILD: String = "3"
const ANDROID_BUILD: String = "1"


static func run(fails: Array[String]) -> void:
	_project(fails)
	_ios_identity(fails)
	_shared_marketing(fails)
	_sentry_dist(fails)
	_export_options(fails)


static func _project(fails: Array[String]) -> void:
	var loaded: String = str(ProjectSettings.get_setting("application/config/version", ""))
	if loaded != MARKETING:
		fails.append("identity: ProjectSettings config/version is %s, not %s" % [loaded, MARKETING])
	var file_val: String = _godot_value(
			FileAccess.get_file_as_string("res://project.godot"), "config/version")
	if file_val != MARKETING:
		fails.append("identity: project.godot config/version is %s, not %s" % [file_val, MARKETING])
	if file_val == IOS_BUILD:
		fails.append("identity: marketing version equals numeric build")


static func _ios_identity(fails: Array[String]) -> void:
	var presets: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	for name: String in ["iOS", "iOS Dev Review"]:
		var opts: Dictionary = _preset_options(presets, name)
		if opts.is_empty():
			fails.append("identity: %s preset is missing" % name)
			continue
		if str(opts.get("application/short_version", "")) != MARKETING:
			fails.append("identity: %s short_version is not %s" % [name, MARKETING])
		if str(opts.get("application/version", "")) != IOS_BUILD:
			fails.append("identity: %s CFBundleVersion is not %s" % [name, IOS_BUILD])


static func _shared_marketing(fails: Array[String]) -> void:
	var presets: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	var macos: Dictionary = _preset_options(presets, "macOS")
	if str(macos.get("application/short_version", "")) != MARKETING:
		fails.append("identity: macOS short_version is not %s" % MARKETING)
	if str(macos.get("application/version", "")) != MARKETING:
		fails.append("identity: macOS CFBundleVersion is not marketing %s" % MARKETING)
	for name: String in ["Android (Play AAB)", "Android Dev Review"]:
		var opts: Dictionary = _preset_options(presets, name)
		if str(opts.get("version/name", "")) != MARKETING:
			fails.append("identity: %s version/name is not %s" % [name, MARKETING])
		if str(opts.get("version/code", "")) != ANDROID_BUILD:
			fails.append("identity: %s version/code is not %s" % [name, ANDROID_BUILD])


static func _sentry_dist(fails: Array[String]) -> void:
	var loop_src: String = FileAccess.get_file_as_string("res://application/sentry_loop.gd")
	if not loop_src.contains("const IOS_BUILD_NUMBER: String = \"%s\"" % IOS_BUILD):
		fails.append("identity: IOS_BUILD_NUMBER is not %s" % IOS_BUILD)
	var dist: String = _godot_value(
			FileAccess.get_file_as_string("res://project.godot"), "options/dist")
	if dist != IOS_BUILD:
		fails.append("identity: sentry options/dist is not %s" % IOS_BUILD)


static func _export_options(fails: Array[String]) -> void:
	var text: String = FileAccess.get_file_as_string("res://scripts/ios_export_options.plist")
	if text.is_empty():
		fails.append("identity: ios_export_options.plist is missing")
		return
	_expect_plist(fails, text, "method", "app-store-connect")
	_expect_plist(fails, text, "destination", "export")
	_expect_plist(fails, text, "teamID", "V45S7U2LZB")
	_expect_plist(fails, text, "signingStyle", "automatic")
	_expect_plist_bool(fails, text, "manageAppVersionAndBuildNumber", false)
	_expect_plist_bool(fails, text, "uploadSymbols", true)


static func _expect_plist(fails: Array[String], text: String, key: String, want: String) -> void:
	var got: String = _plist_value(text, key)
	if got != want:
		fails.append("identity: export option %s is %s, not %s" % [key, got, want])


static func _expect_plist_bool(
		fails: Array[String], text: String, key: String, want: bool) -> void:
	var needle: String = "<key>%s</key>" % key
	var at: int = text.find(needle)
	var rest: String = "" if at < 0 else text.substr(at + needle.length()).strip_edges()
	var expected: String = "<true" if want else "<false"
	if not rest.begins_with(expected):
		fails.append("identity: export option %s is not plist boolean %s" % [key, want])


static func _plist_value(text: String, key: String) -> String:
	var needle: String = "<key>%s</key>" % key
	var at: int = text.find(needle)
	if at < 0:
		return ""
	var rest: String = text.substr(at + needle.length()).strip_edges()
	if rest.begins_with("<string>"):
		var end: int = rest.find("</string>")
		if end < 0:
			return ""
		return rest.substr(8, end - 8)
	if rest.begins_with("<true"):
		return "true"
	if rest.begins_with("<false"):
		return "false"
	return ""


static func _godot_value(text: String, key: String) -> String:
	var needle: String = key + "="
	var at: int = text.find(needle)
	if at < 0:
		return ""
	var line_end: int = text.find("\n", at)
	var raw: String = text.substr(at + needle.length(),
			(text.length() if line_end < 0 else line_end) - at - needle.length())
	return raw.strip_edges().trim_prefix("\"").trim_suffix("\"")


static func _preset_options(text: String, want: String) -> Dictionary:
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
