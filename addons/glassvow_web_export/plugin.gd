@tool
extends EditorPlugin


class WebDataExporter:
	extends EditorExportPlugin

	const DATA_FILES: PackedStringArray = [
		"res://port_fixtures/content/slice-content.json",
		"res://port_fixtures/content/core-mechanics.json",
		"res://port_fixtures/content/card-catalog.json",
		"res://port_fixtures/content/locale-en.json",
		"res://assets/art/enemies/char-meta.json",
		"res://assets/layout/combat-layout.json",
	]

	func _get_name() -> String:
		return "glassvow_web_data"

	func _export_begin(features: PackedStringArray, _is_debug: bool,
			_path: String, _flags: int) -> void:
		if not features.has("web_dev"):
			return
		for file_path: String in DATA_FILES:
			add_file(file_path, FileAccess.get_file_as_bytes(file_path), false)


var _exporter: WebDataExporter


func _enter_tree() -> void:
	_exporter = WebDataExporter.new()
	add_export_plugin(_exporter)


func _exit_tree() -> void:
	remove_export_plugin(_exporter)
	_exporter = null
