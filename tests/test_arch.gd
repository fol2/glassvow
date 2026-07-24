extends RefCounted
## Architecture gate: domain/ must stay pure (no Node/IO/presentation).
## When domain/ is absent (M0 scaffold), this test passes trivially.


const _BANNED_WORDS: PackedStringArray = [
	"Node",
	"SceneTree",
	"FileAccess",
	"DirAccess",
	"Input",
	"DisplayServer",
	"OS",
	"get_tree",
]

const _BANNED_SUBSTRINGS: PackedStringArray = [
	"res://presentation",
	"res://application",
]


static func run(fails: Array[String]) -> void:
	var domain_dir: DirAccess = DirAccess.open("res://domain")
	if domain_dir == null:
		return
	var files: Array[String] = []
	_collect_gd(domain_dir, "res://domain", files)
	files.sort()
	for path: String in files:
		var text: String = FileAccess.get_file_as_string(path)
		if text.is_empty() and FileAccess.get_open_error() != OK:
			fails.append("%s: unreadable" % path)
			continue
		_scan_file(path, text, fails)


static func _collect_gd(dir: DirAccess, base: String, out: Array[String]) -> void:
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var child_path: String = base.path_join(name)
		if dir.current_is_dir():
			var child: DirAccess = DirAccess.open(child_path)
			if child != null:
				_collect_gd(child, child_path, out)
		elif name.ends_with(".gd"):
			out.append(child_path)
		name = dir.get_next()
	dir.list_dir_end()


static func _scan_file(path: String, text: String, fails: Array[String]) -> void:
	for sub: String in _BANNED_SUBSTRINGS:
		if text.find(sub) >= 0:
			fails.append("%s: banned substring %s" % [path, sub])
	for word: String in _BANNED_WORDS:
		if _has_whole_word(text, word):
			fails.append("%s: banned token %s" % [path, word])


static func _has_whole_word(text: String, word: String) -> bool:
	var from: int = 0
	while true:
		var idx: int = text.find(word, from)
		if idx < 0:
			return false
		var before_ok: bool = idx == 0 or not _is_ident_char(text.unicode_at(idx - 1))
		var after_i: int = idx + word.length()
		var after_ok: bool = after_i >= text.length() or not _is_ident_char(text.unicode_at(after_i))
		if before_ok and after_ok:
			return true
		from = idx + word.length()
	return false


static func _is_ident_char(code: int) -> bool:
	return (
		(code >= 65 and code <= 90)
		or (code >= 97 and code <= 122)
		or (code >= 48 and code <= 57)
		or code == 95
	)
