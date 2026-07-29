class_name DataFile
extends RefCounted
## Writing an authored JSON file back to disk, safely.
##
## Two benches in this build write their own data — the enemy bench writes
## `assets/art/enemies/char-meta.json`, the layout bench writes
## `assets/layout/combat-layout.json`. The writer they would otherwise share by
## copy-paste has two defects, and both are the kind that shows up exactly once:
##
##   1. `FileAccess.open(path, WRITE)` TRUNCATES on open. The existing writer
##      opens first and serialises second, so anything going wrong between those
##      two lines leaves an empty file where the data used to be — and the data
##      is the only copy, because these files are authored, not generated.
##   2. No trailing newline. Every save then reads as `\ No newline at end of
##      file` in a diff, and every POSIX tool treats the last line as truncated.
##
## So the order here is serialise, check, THEN open. The check itself belongs to
## the caller: `LayoutBook.validate()` knows what a good book is and this does
## not. What this owns is the guarantee that a refused save leaves the file
## exactly as it was.
##
## It sits at the top of `presentation/` rather than inside a topic folder
## because it belongs to no one screen — it is used from `stage/` and `combat/`.

## Canonical text for a value: Godot's own two-space form, with the trailing
## newline it omits. Keys are sorted, which is `JSON.stringify`'s default and is
## deliberately kept — a checked-in file and a saved one are then byte-identical,
## so opening an editor and saving without touching anything is a zero diff.
static func to_text(data: Variant) -> String:
	return JSON.stringify(data, "  ") + "\n"


## Write `text` to `path`. Returns why it did not, or "" when it did.
##
## Refuses empty text outright. A serialiser that failed hands back "" or "null",
## and truncating an authored file to nothing is the one outcome no editor should
## ever be able to reach by accident.
static func write(path: String, text: String) -> String:
	if OS.has_feature("web"):
		return "a Web build cannot write %s — copy the text out instead" % path
	var body: String = text.strip_edges()
	if body.is_empty() or body == "null":
		return "refusing to write an empty %s" % path
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "cannot open %s for writing (error %d)" % [path, FileAccess.get_open_error()]
	f.store_string(text)
	f.close()
	return ""
