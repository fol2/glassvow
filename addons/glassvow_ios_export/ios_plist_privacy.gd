extends RefCounted
## Strips unused empty iOS usage-description keys from a Godot-exported Info.plist.
## Godot 4.7.2 always substitutes privacy/*_usage_description into the template,
## even when the strings are empty.

const USAGE_KEYS: PackedStringArray = [
	"NSCameraUsageDescription",
	"NSMicrophoneUsageDescription",
	"NSPhotoLibraryUsageDescription",
]


static func strip_empty_usage_descriptions(plist: String) -> String:
	var rx: RegEx = RegEx.new()
	var updated: String = plist
	for key: String in USAGE_KEYS:
		var err: Error = rx.compile(
				"(?m)^[\\t ]*<key>" + key + "</key>\\r?\\n[\\t ]*<string>\\s*</string>\\r?\\n")
		if err != OK:
			continue
		updated = rx.sub(updated, "", true)
	return updated


static func app_info_plist_path(export_path: String) -> String:
	var stem: String = export_path.get_file().get_basename()
	var nested: String = export_path.get_base_dir().path_join(stem).path_join(
			"%s-Info.plist" % stem)
	if FileAccess.file_exists(nested):
		return nested
	var flat: String = export_path.get_base_dir().path_join("%s-Info.plist" % stem)
	if FileAccess.file_exists(flat):
		return flat
	return ""


static func strip_export(export_path: String) -> bool:
	var path: String = app_info_plist_path(export_path)
	if path.is_empty():
		return false
	var original: String = FileAccess.get_file_as_string(path)
	var updated: String = strip_empty_usage_descriptions(original)
	if updated == original:
		return false
	var out: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		return false
	out.store_string(updated)
	return true
