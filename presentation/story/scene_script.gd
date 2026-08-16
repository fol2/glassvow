class_name SceneScript
extends RefCounted
## Authored scene beat list. Copy lives in locale; this file is structure.

const PATH: String = "res://content/scenes.json"
const MOTIONS: Dictionary = {"hold": true, "push-in": true, "linger": true}

var id: String = ""
var beats: Array[Dictionary] = []
var lines: Array[Dictionary] = []


static func load_all(path: String = PATH) -> Variant:
	if not FileAccess.file_exists(path):
		return _fail("scenes: missing %s" % path)
	return parse_bundle(JSON.parse_string(FileAccess.get_file_as_string(path)))


static func parse_bundle(raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail("scenes: root is not an object")
	var root: Dictionary = raw
	var scenes_v: Variant = root.get("scenes")
	if typeof(scenes_v) != TYPE_DICTIONARY:
		return _fail("scenes: missing scenes object")
	var scenes: Dictionary = scenes_v
	var out: Dictionary = {}
	for id_v: Variant in scenes:
		var scene_id: String = str(id_v)
		var parsed: Variant = parse_scene(scene_id, scenes[id_v])
		if typeof(parsed) == TYPE_STRING:
			return parsed
		out[scene_id] = parsed
	return out


static func parse_scene(scene_id: String, raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail("scenes: %s is not an object" % scene_id)
	var scene: Dictionary = raw
	var beats_v: Variant = scene.get("beats")
	if typeof(beats_v) != TYPE_ARRAY:
		return _fail("scenes: %s has no beats" % scene_id)
	var beats_raw: Array = beats_v
	if beats_raw.is_empty():
		return _fail("scenes: %s has no beats" % scene_id)
	var script: SceneScript = SceneScript.new()
	script.id = scene_id
	for beat_i: int in range(beats_raw.size()):
		var built: Variant = _beat(scene_id, beat_i, beats_raw[beat_i])
		if typeof(built) == TYPE_STRING:
			return built
		var beat: Dictionary = built
		script.beats.append(beat)
		var beat_lines: Array = beat["lines"]
		for line_v: Variant in beat_lines:
			var line: Dictionary = line_v
			var flat: Dictionary = line.duplicate()
			flat["beat"] = beat_i
			script.lines.append(flat)
	return script


func line_count() -> int:
	return lines.size()


## One-beat script for a LineTable row. Copy stays on the row; the dummy key
## is never resolved when ScenePlayer is given the pool row.
static func pool_beat(art: String) -> SceneScript:
	var script: SceneScript = SceneScript.new()
	script.id = "pool"
	var line: Dictionary = {"key": "pool.inline", "beat": 0}
	var beat_lines: Array[Dictionary] = [line]
	script.beats.append({
		"art": art,
		"motion": "hold",
		"lines": beat_lines,
		"skip_dwell": 0.0,
	})
	script.lines.append(line)
	return script


func beat_at(index: int) -> Dictionary:
	if index < 0 or index >= lines.size():
		return {}
	var beat_i: int = lines[index]["beat"]
	if beat_i < 0 or beat_i >= beats.size():
		return {}
	return beats[beat_i]


static func _beat(scene_id: String, beat_i: int, raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail("scenes: %s beat %d is not an object" % [scene_id, beat_i])
	var row: Dictionary = raw
	var motion: String = str(row.get("motion", ""))
	if not MOTIONS.has(motion):
		return _fail("scenes: %s beat %d has unknown motion '%s'" % [scene_id, beat_i, motion])
	var lines_v: Variant = row.get("lines")
	if typeof(lines_v) != TYPE_ARRAY:
		return _fail("scenes: %s beat %d has no lines" % [scene_id, beat_i])
	var lines_raw: Array = lines_v
	if lines_raw.is_empty():
		return _fail("scenes: %s beat %d has no lines" % [scene_id, beat_i])
	var cleaned_lines: Array[Dictionary] = []
	for line_i: int in range(lines_raw.size()):
		var built: Variant = _line(scene_id, beat_i, line_i, lines_raw[line_i])
		if typeof(built) == TYPE_STRING:
			return built
		var line: Dictionary = built
		cleaned_lines.append(line)
	var skip_dwell: float = float(str(row.get("skipDwell", 0.0)))
	if skip_dwell < 0.0:
		return _fail("scenes: %s beat %d has negative skipDwell" % [scene_id, beat_i])
	return {
		"art": str(row.get("art", "")),
		"motion": motion,
		"lines": cleaned_lines,
		"skip_dwell": skip_dwell,
	}


static func _line(scene_id: String, beat_i: int, line_i: int, raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail("scenes: %s beat %d line %d is not an object" % [scene_id, beat_i, line_i])
	var row: Dictionary = raw
	var key: String = str(row.get("key", "")).strip_edges()
	if key.is_empty():
		return _fail("scenes: %s beat %d line %d has no key" % [scene_id, beat_i, line_i])
	var line: Dictionary = {"key": key}
	var speaker: String = str(row.get("speaker", "")).strip_edges()
	if not speaker.is_empty():
		line["speaker"] = speaker
	return line


static func _fail(message: String) -> String:
	push_error(message)
	return message
