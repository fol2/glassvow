extends RefCounted
## ScenePlayer: DawnScreen's handshake, lifted. A line is never shown before
## it is owed, skip is distinct from tap, and missing plates still play.

static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("scene_player: %s" % what)


static func run(fails: Array[String]) -> void:
	var opening: SceneScript = _script("opening")
	if opening == null:
		_check(fails, false, "opening did not load")
		return
	_fresh_asks_once(fails, opening)
	_holds_without_confirm(fails, opening)
	_resume(fails, opening)
	_skip_distinct_from_tap(fails, opening)
	_finished_once(fails)
	_missing_plates(fails, opening)


static func _fresh_asks_once(fails: Array[String], opening: SceneScript) -> void:
	var asked: Array[int] = [0]
	var player: ScenePlayer = _live(opening, 0, asked)
	_check(fails, _text(player, "Line") == Locale.active.t("story.opening.b1.l1"),
		"fresh player is not on line 0")
	_check(fails, _text(player, "Speaker") == Locale.active.t("ui.scene.speaker.keeper"),
		"line 0 lost its speaker")
	_check(fails, asked[0] == 1, "fresh player did not ask once (got %d)" % asked[0])
	player.free()


static func _holds_without_confirm(fails: Array[String], opening: SceneScript) -> void:
	var asked: Array[int] = [0]
	var player: ScenePlayer = _live(opening, 0, asked)
	player._process(10.0)
	_check(fails, asked[0] == 1, "unconfirmed wait asked again (got %d)" % asked[0])
	_check(fails, _text(player, "Line") == Locale.active.t("story.opening.b1.l1"),
		"cursor advanced without confirm")
	player.advance_confirmed()
	_check(fails, _text(player, "Line") == Locale.active.t("story.opening.b1.l2"),
		"confirm did not reveal the next owed line")
	player._process(0.016)
	_check(fails, asked[0] == 2, "confirm did not ask for the next line")
	player.free()


static func _resume(fails: Array[String], opening: SceneScript) -> void:
	var asked: Array[int] = [0]
	var done: Array[int] = [0]
	var player: ScenePlayer = _live(opening, 5, asked, done)
	_check(fails, _text(player, "Line") == Locale.active.t("story.opening.b3.l1"),
		"resumed cursor is not on the owed line")
	_check(fails, _text(player, "Speaker") == "", "resumed narration grew a speaker")
	_check(fails, done[0] == 0, "a mid-scene resume fired finished")
	player.free()


static func _skip_distinct_from_tap(fails: Array[String], opening: SceneScript) -> void:
	var tapped: Array[int] = [0]
	var tap: ScenePlayer = ScenePlayer.new(opening, 0)
	tap.advance_requested.connect(func() -> void: tapped[0] += 1)
	tap._ready()
	tap._press(true)
	tap._process(0.05)
	tap._press(false)
	_check(fails, tapped[0] == 1, "a tap mid-reveal did not ask")
	_check(fails, is_equal_approx(tap._copy.modulate.a, 1.0), "a tap did not land the line")
	tap.advance_confirmed()
	_check(fails, tap._beat == ScenePlayer.BEAT_REVEAL,
		"a tap left skip armed (next line was instant)")
	tap.free()
	var skipped: Array[int] = [0]
	var hold: ScenePlayer = ScenePlayer.new(opening, 0)
	hold.advance_requested.connect(func() -> void: skipped[0] += 1)
	hold._ready()
	hold._process(ScenePlayer.REVEAL_TIME + 0.01)
	hold._press(true)
	hold._process(ScenePlayer.SKIP_HOLD)
	_check(fails, skipped[0] == 1, "a skip hold did not ask")
	_check(fails, hold._skipping, "a skip hold did not arm skip")
	hold._press(false)
	hold.advance_confirmed()
	_check(fails, hold._beat == ScenePlayer.BEAT_WAIT,
		"skip did not land the next line standing")
	hold.free()


static func _finished_once(fails: Array[String]) -> void:
	var short: SceneScript = _script("unsealing-short")
	if short == null:
		_check(fails, false, "unsealing-short did not load")
		return
	var asked: Array[int] = [0]
	var done: Array[int] = [0]
	var player: ScenePlayer = _live(short, 0, asked, done)
	_check(fails, done[0] == 0, "finished fired before the last confirm")
	player.advance_confirmed()
	_check(fails, done[0] == 1, "finished did not fire on the last confirm")
	player.advance_confirmed()
	_check(fails, done[0] == 1, "finished fired more than once")
	player.free()


static func _missing_plates(fails: Array[String], opening: SceneScript) -> void:
	var asked: Array[int] = [0]
	var done: Array[int] = [0]
	var player: ScenePlayer = _live(opening, 0, asked, done)
	var plate: TextureRect = player.find_child("Plate", true, false) as TextureRect
	_check(fails, plate != null and plate.texture == null,
		"absent plates did not degrade to an empty plate")
	var steps: int = 0
	while done[0] == 0 and steps < opening.line_count() + 1:
		player.advance_confirmed()
		player._process(0.016)
		steps += 1
	_check(fails, done[0] == 1, "a no-plate opening did not finish")
	player.free()


static func _live(script: SceneScript, cursor: int, asked: Array[int],
		done: Array[int] = []) -> ScenePlayer:
	var player: ScenePlayer = ScenePlayer.new(script, cursor)
	player.instant = true
	player.advance_requested.connect(func() -> void: asked[0] += 1)
	if not done.is_empty():
		player.finished.connect(func() -> void: done[0] += 1)
	player._ready()
	player._process(0.016)
	return player


static func _script(scene_id: String) -> SceneScript:
	var loaded: Variant = SceneScript.load_all()
	if typeof(loaded) != TYPE_DICTIONARY:
		return null
	var scenes: Dictionary = loaded
	var found: Variant = scenes.get(scene_id)
	if found is SceneScript:
		return found
	return null


static func _text(player: ScenePlayer, node_name: String) -> String:
	var node: Label = player.find_child(node_name, true, false) as Label
	return node.text if node != null else ""
