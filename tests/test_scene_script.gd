extends RefCounted
## Scene-script data: every authored scene loads, every line key resolves in
## both catalogues, the flat cursor maps back to its beat, and each validation
## failure is actually detected.

const SCENE_IDS: Array[String] = [
	"opening", "unsealing", "unsealing-short", "act4-entry",
	"act4-node1", "act4-node2", "act4-node3", "act4-node4", "act4-node5",
	"finale",
	"lamplighter-m1-pre", "lamplighter-m1-post",
	"lamplighter-m2-pre", "lamplighter-m2-post",
	"lamplighter-m3-pre", "lamplighter-m3-post",
	"lamplighter-m4-pre", "lamplighter-m4-post",
	"lamplighter-m5-pre", "lamplighter-m5-post",
]


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("scene_script: %s" % what)


static func run(fails: Array[String]) -> void:
	_loads(fails)
	_keys_resolve(fails)
	_art_resolves(fails)
	_flat_cursor(fails)
	_validation(fails)


## Every art path a beat names must be a real importable resource. The plates
## are addressed by string, so a renamed or dropped file fails silently at
## runtime — the player degrades to an empty plate by design (see
## test_scene_player), which means nothing would ever surface the typo.
static func _art_resolves(fails: Array[String]) -> void:
	var loaded: Variant = SceneScript.load_all()
	if typeof(loaded) != TYPE_DICTIONARY:
		return
	var scenes: Dictionary = loaded
	var seen: int = 0
	for scene_id: String in SCENE_IDS:
		var script: SceneScript = _script(scenes, scene_id)
		if script == null:
			continue
		for i: int in range(script.line_count()):
			var art: String = str(script.beat_at(i).get("art", ""))
			if art.is_empty():
				continue
			seen += 1
			_check(fails, ResourceLoader.exists(art),
				"%s names art that does not resolve: %s" % [scene_id, art])
	_check(fails, seen > 0, "no beat named any art at all")


static func _loads(fails: Array[String]) -> void:
	var loaded: Variant = SceneScript.load_all()
	_check(fails, typeof(loaded) == TYPE_DICTIONARY, "load_all did not return a dictionary")
	if typeof(loaded) != TYPE_DICTIONARY:
		return
	var scenes: Dictionary = loaded
	for scene_id: String in SCENE_IDS:
		var script: SceneScript = _script(scenes, scene_id)
		_check(fails, script != null, "%s did not load" % scene_id)
		if script == null:
			continue
		_check(fails, script.line_count() > 0, "%s has no flat lines" % scene_id)
		_check(fails, not script.beats.is_empty(), "%s has no beats" % scene_id)


static func _keys_resolve(fails: Array[String]) -> void:
	var loaded: Variant = SceneScript.load_all()
	if typeof(loaded) != TYPE_DICTIONARY:
		return
	var scenes: Dictionary = loaded
	var en: Locale = Locale.new(Locale.CODE_EN)
	var zh: Locale = Locale.new(Locale.CODE_ZH_HANT)
	_check(fails, zh.set_language(Locale.CODE_ZH_HANT), "zh-Hant catalogue did not load")
	for scene_id: String in SCENE_IDS:
		var script: SceneScript = _script(scenes, scene_id)
		if script == null:
			continue
		for line: Dictionary in script.lines:
			var key: String = str(line["key"])
			_check(fails, en.t(key) != key, "en did not resolve %s" % key)
			_check(fails, zh.t(key) != key, "zh-Hant did not resolve %s" % key)
			var speaker: String = str(line.get("speaker", "")).strip_edges()
			if speaker.is_empty():
				continue
			var speaker_key: String = "ui.scene.speaker.%s" % speaker
			_check(fails, en.t(speaker_key) != speaker_key,
				"en did not resolve %s" % speaker_key)
			_check(fails, zh.t(speaker_key) != speaker_key,
				"zh-Hant did not resolve %s" % speaker_key)


static func _flat_cursor(fails: Array[String]) -> void:
	var loaded: Variant = SceneScript.load_all()
	if typeof(loaded) != TYPE_DICTIONARY:
		return
	var scenes: Dictionary = loaded
	var opening: SceneScript = _script(scenes, "opening")
	if opening == null:
		_check(fails, false, "opening missing for cursor check")
		return
	_check(fails, opening.line_count() == 8, "opening is not 8 flat lines")
	_check(fails, opening.beats.size() == 4, "opening is not 4 beats")
	var m4_pre: SceneScript = _script(scenes, "lamplighter-m4-pre")
	_check(fails, m4_pre != null and m4_pre.line_count() == 4
			and m4_pre.beats.size() == 1,
		"lamplighter-m4-pre is not one hold beat of 4 lines")
	var m5_post: SceneScript = _script(scenes, "lamplighter-m5-post")
	_check(fails, m5_post != null and m5_post.line_count() == 3,
		"lamplighter-m5-post is not 3 flat lines")
	_check(fails, str(m4_pre.beat_at(0).get("art", "")) == "",
		"lamplighter meetings grew an art plate")
	var expected: Array[int] = [0, 0, 1, 1, 1, 2, 2, 3]
	for i: int in range(expected.size()):
		var beat: Dictionary = opening.beat_at(i)
		var beat_i: int = opening.lines[i]["beat"]
		_check(fails, beat_i == expected[i],
			"opening line %d is not beat %d" % [i, expected[i]])
		_check(fails, beat == opening.beats[expected[i]],
			"opening beat_at(%d) is not beat %d" % [i, expected[i]])
	_check(fails, str(opening.beat_at(0).get("art", "")).ends_with("opening-hearth.png"),
		"opening beat 0 lost its plate")
	_check(fails, str(opening.beat_at(2).get("art", "")) == "",
		"opening beat 1 (lines 2–4) should keep the previous plate")
	_check(fails, str(opening.beat_at(7).get("motion", "")) == "linger",
		"opening last line is not the linger beat")
	_check(fails, opening.beat_at(-1).is_empty() and opening.beat_at(8).is_empty(),
		"out-of-range beat_at did not return empty")


static func _validation(fails: Array[String]) -> void:
	_rejects(fails, "empty", {"beats": []}, "has no beats")
	_rejects(fails, "mute", {"beats": [{"motion": "hold", "lines": []}]}, "has no lines")
	_rejects(fails, "zoom", {"beats": [{"motion": "zoom", "lines": [{"key": "k"}]}]},
		"unknown motion")
	_rejects(fails, "blank", {"beats": [{"motion": "hold", "lines": [{}]}]}, "has no key")
	_rejects(fails, "empty-key", {"beats": [{"motion": "hold", "lines": [{"key": ""}]}]},
		"has no key")


static func _script(scenes: Dictionary, scene_id: String) -> SceneScript:
	var found: Variant = scenes.get(scene_id)
	if found is SceneScript:
		return found
	return null


static func _rejects(fails: Array[String], scene_id: String, raw: Dictionary,
		needle: String) -> void:
	var result: Variant = SceneScript.parse_scene(scene_id, raw)
	_check(fails, typeof(result) == TYPE_STRING, "%s was accepted" % scene_id)
	if typeof(result) == TYPE_STRING:
		_check(fails, str(result).contains(needle),
			"%s error missed '%s': %s" % [scene_id, needle, result])
