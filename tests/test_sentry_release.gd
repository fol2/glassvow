extends RefCounted
## Locks the Sentry 2.1.1 pin, privacy-minimal Project Settings, and iOS
## store/Dev Review exports that must carry the addon.

## sentry-cocoa 9.24.0 Sources/Resources/PrivacyInfo.xcprivacy (exact bytes).
## Pins Linked=false, Tracking=false, AppFunctionality per collected type
## without a plist parser.
const COCOA_PRIVACY_SHA256: String = "118b16e0e97ffe8b6f1f01b7e04f68e5da764474a4d39d2933b0eeaef3cdc0ca"


static func run(fails: Array[String]) -> void:
	_pin(fails)
	_privacy(fails)
	_ios_exports(fails)
	_dist(fails)
	_cocoa_privacy_manifest(fails)
	_redact(fails)


static func _pin(fails: Array[String]) -> void:
	if not FileAccess.file_exists("res://addons/sentry/sentry.gdextension"):
		fails.append("sentry: addons/sentry is missing")
	var cfg: String = FileAccess.get_file_as_string("res://addons/sentry/plugin.cfg")
	if not cfg.contains("version=\"2.1.1\""):
		fails.append("sentry: plugin.cfg version is not 2.1.1")
	var project: String = FileAccess.get_file_as_string("res://project.godot")
	if not project.contains("run/main_loop_type=\"GlassvowMainLoop\""):
		fails.append("sentry: main loop is not GlassvowMainLoop")
	if not project.contains("options/auto_init=false"):
		fails.append("sentry: auto_init must be false so before_send can attach")


static func _privacy(fails: Array[String]) -> void:
	var project: String = FileAccess.get_file_as_string("res://project.godot")
	var dsn: String = _sentry_value(project, "options/dsn")
	if dsn.is_empty() or not dsn.begins_with("https://") or dsn.find("@") < 0:
		fails.append("sentry: DSN-like setting is empty")
	if _sentry_value(project, "options/attach_log") != "false":
		fails.append("sentry: attach_log is not false")
	if _sentry_value(project, "options/send_default_pii") != "false":
		fails.append("sentry: send_default_pii is not false")
	if _sentry_value(project, "options/attach_scene_tree") != "false":
		fails.append("sentry: attach_scene_tree is not false")
	if _sentry_value(project, "experimental/attach_screenshot") != "false":
		fails.append("sentry: attach_screenshot is not false")
	if _sentry_value(project, "godot_logger/include_variables") != "false":
		fails.append("sentry: include_variables is not false")
	if _sentry_value(project, "options/app_hang/tracking") != "true":
		fails.append("sentry: Apple hang capture is not on")
	var release: String = _sentry_value(project, "options/release")
	if not release.begins_with("io.fol2.glassvow@"):
		fails.append("sentry: release is not application id + version")


static func _ios_exports(fails: Array[String]) -> void:
	var presets: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	var store: Dictionary = _preset(presets, "iOS")
	var review: Dictionary = _preset(presets, "iOS Dev Review")
	if store.is_empty() or review.is_empty():
		fails.append("sentry: iOS store or Dev Review preset is missing")
		return
	if str(store.get("custom_features", "")).contains("dev_tools"):
		fails.append("sentry: iOS store preset still has dev_tools")
	if not str(review.get("custom_features", "")).contains("dev_tools"):
		fails.append("sentry: iOS Dev Review must keep dev_tools")
	for row: Dictionary in [store, review]:
		var name: String = str(row.get("name", ""))
		if _exclude_hits(str(row.get("exclude_filter", "")), "addons/sentry/sentry.gdextension"):
			fails.append("sentry: %s exclude_filter drops Sentry" % name)


static func _dist(fails: Array[String]) -> void:
	var loop_src: String = FileAccess.get_file_as_string("res://application/sentry_loop.gd")
	if loop_src.contains("get_setting(\"application/config/version\")"):
		fails.append("sentry: dist is still sourced from marketing version")
	if not loop_src.contains("const IOS_BUILD_NUMBER: String = \"4\""):
		fails.append("sentry: IOS_BUILD_NUMBER is not the numeric iOS build")
	if not loop_src.contains("options.dist = IOS_BUILD_NUMBER"):
		fails.append("sentry: dist is not assigned from IOS_BUILD_NUMBER")
	var project: String = FileAccess.get_file_as_string("res://project.godot")
	if _sentry_value(project, "options/dist") != GlassvowMainLoop.IOS_BUILD_NUMBER:
		fails.append("sentry: project options/dist is not the iOS build number")
	if _sentry_value(project, "config/version") == GlassvowMainLoop.IOS_BUILD_NUMBER:
		fails.append("sentry: marketing config/version collides with dist")
	var rx: RegEx = RegEx.new()
	if rx.compile("^[0-9]+$") != OK or rx.search(GlassvowMainLoop.IOS_BUILD_NUMBER) == null:
		fails.append("sentry: IOS_BUILD_NUMBER is not numeric")
	var presets: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	var store: Dictionary = _preset(presets, "iOS")
	var review: Dictionary = _preset(presets, "iOS Dev Review")
	for row: Dictionary in [store, review]:
		var name: String = str(row.get("name", ""))
		if str(row.get("application/version", "")) != GlassvowMainLoop.IOS_BUILD_NUMBER:
			fails.append("sentry: %s CFBundleVersion is not the numeric build" % name)
		if str(row.get("application/short_version", "")) == GlassvowMainLoop.IOS_BUILD_NUMBER:
			fails.append("sentry: %s marketing version equals dist" % name)


static func _cocoa_privacy_manifest(fails: Array[String]) -> void:
	var device: String = "res://addons/sentry/bin/ios/Sentry.xcframework/ios-arm64/SentryObjC.framework/PrivacyInfo.xcprivacy"
	var sim: String = "res://addons/sentry/bin/ios/Sentry.xcframework/ios-arm64_x86_64-simulator/SentryObjC.framework/PrivacyInfo.xcprivacy"
	if not FileAccess.file_exists(device) or not FileAccess.file_exists(sim):
		fails.append("sentry: Sentry Cocoa PrivacyInfo.xcprivacy is missing")
		return
	var device_sha: String = FileAccess.get_sha256(device)
	var sim_sha: String = FileAccess.get_sha256(sim)
	if device_sha != COCOA_PRIVACY_SHA256:
		fails.append("sentry: Cocoa PrivacyInfo is not sentry-cocoa 9.24.0 (%s)" % device_sha)
	if sim_sha != COCOA_PRIVACY_SHA256:
		fails.append("sentry: Cocoa PrivacyInfo simulator slice drifted (%s)" % sim_sha)


static func _redact(fails: Array[String]) -> void:
	if SentryPrivacy.redact("boom user://glassvow_run_v2.json") == "boom user://glassvow_run_v2.json":
		fails.append("sentry: redact left a user:// path")
	if SentryPrivacy.redact("{\"seed\": 12, \"deck\": []}") != "[redacted]":
		fails.append("sentry: redact left a save-shaped payload")
	var gate: SentryPrivacy = SentryPrivacy.new()
	var i: int = 0
	while i < SentryPrivacy.NONFATAL_CAP:
		if not gate.allow_nonfatal("same"):
			fails.append("sentry: nonfatal cap fired too early")
			break
		i += 1
	if gate.allow_nonfatal("same"):
		fails.append("sentry: noisy nonfatals were not bounded")


static func _sentry_value(project: String, key: String) -> String:
	var needle: String = key + "="
	var at: int = project.find(needle)
	if at < 0:
		return ""
	var line_end: int = project.find("\n", at)
	var raw: String = project.substr(at + needle.length(),
			(project.length() if line_end < 0 else line_end) - at - needle.length())
	return raw.strip_edges().trim_prefix("\"").trim_suffix("\"")


static func _preset(text: String, want: String) -> Dictionary:
	var current: Dictionary = {}
	var in_options: bool = false
	for line: String in text.split("\n"):
		if line.begins_with("[preset.") and line.ends_with(".options]"):
			in_options = true
			continue
		if line.begins_with("[preset.") and line.ends_with("]"):
			if str(current.get("name", "")) == want:
				return current
			current = {"name": ""}
			in_options = false
			continue
		if current.is_empty():
			continue
		if in_options:
			if line.begins_with("application/version=") \
					or line.begins_with("application/short_version="):
				var opt_eq: int = line.find("=")
				current[line.substr(0, opt_eq)] = line.substr(opt_eq + 1) \
						.trim_prefix("\"").trim_suffix("\"")
			continue
		if line.begins_with("name=") or line.begins_with("custom_features=") \
				or line.begins_with("exclude_filter="):
			var eq: int = line.find("=")
			current[line.substr(0, eq)] = line.substr(eq + 1).trim_prefix("\"").trim_suffix("\"")
	if str(current.get("name", "")) == want:
		return current
	return {}


static func _exclude_hits(filter: String, path: String) -> bool:
	for part: String in filter.split(","):
		var glob: String = part.strip_edges()
		if glob.is_empty():
			continue
		var escaped: String = glob.replace(".", "\\.").replace("*", ".*")
		var rx: RegEx = RegEx.new()
		if rx.compile("^" + escaped + "$") != OK:
			continue
		if rx.search(path) != null:
			return true
	return false
