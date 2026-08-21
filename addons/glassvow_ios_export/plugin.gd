@tool
extends EditorPlugin
## Omits empty camera/microphone/photo-library usage keys from iOS Info.plist.


class IosEmptyUsageStripper:
	extends EditorExportPlugin

	const Privacy: GDScript = preload("res://addons/glassvow_ios_export/ios_plist_privacy.gd")

	var _ios: bool = false
	var _export_path: String = ""

	func _get_name() -> String:
		return "glassvow_ios_empty_usage"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform.get_os_name() == "iOS"

	func _export_begin(features: PackedStringArray, _is_debug: bool,
			path: String, _flags: int) -> void:
		_ios = features.has("ios")
		_export_path = path

	func _export_end() -> void:
		if _ios and not _export_path.is_empty():
			Privacy.strip_export(_export_path)
		_ios = false
		_export_path = ""


var _exporter: IosEmptyUsageStripper


func _enter_tree() -> void:
	_exporter = IosEmptyUsageStripper.new()
	add_export_plugin(_exporter)


func _exit_tree() -> void:
	remove_export_plugin(_exporter)
	_exporter = null
