extends RefCounted
## Bespoke scene presentation (#334): the unsealing's pane-lighting and
## one-queue mirror, the hearth cutout on the beats that need it, and the
## L0 linger's lagging reflection of that figure. Staging hooks in as
## per-scene presentation; the player's persistence grammar is untouched.

static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("bespoke_staging: %s" % what)


static func run(fails: Array[String]) -> void:
	_keeper_art(fails)
	_overlay_on_opening(fails)
	_overlay_absent_elsewhere(fails)
	_departure_lags_the_figure(fails)
	_unsealing_pane_lighting(fails)
	_unsealing_mirror_is_one_queue(fails)
	_unsealing_does_not_break_the_player(fails)
	_resume_keeps_staging(fails)


static func _keeper_art(fails: Array[String]) -> void:
	_check(fails, ResourceLoader.exists(HearthFigure.ART),
		"keeper overlay path does not resolve")
	_check(fails, ResourceLoader.exists(RoseWindowView.MURAL)
			and ResourceLoader.exists(RoseWindowView.FRAME),
		"unsealing rose mural/frame do not resolve")
	for id: String in RoseWindowView.IDS:
		_check(fails, ResourceLoader.exists(RoseWindowView.MASK % id),
			"rose mask missing for %s" % id)


static func _overlay_on_opening(fails: Array[String]) -> void:
	var opening: SceneScript = _script("opening")
	if opening == null:
		_check(fails, false, "opening did not load")
		return
	for cursor: int in [0, 2, 5, 7]:
		var player: ScenePlayer = _live(opening, cursor)
		var figure: Node = _figure(player)
		_check(fails, figure != null,
			"opening cursor %d has no hearth figure" % cursor)
		player.free()


static func _overlay_absent_elsewhere(fails: Array[String]) -> void:
	for scene_id: String in ["unsealing", "lamplighter-m1-pre", "act4-node5",
			"finale", "unsealing-short"]:
		var script: SceneScript = _script(scene_id)
		if script == null:
			_check(fails, false, "%s did not load" % scene_id)
			continue
		var player: ScenePlayer = _live(script, 0)
		_check(fails, _figure(player) == null,
			"%s grew a hearth figure" % scene_id)
		player.free()


static func _departure_lags_the_figure(fails: Array[String]) -> void:
	var dark: DepartureStaging = DepartureStaging.new(
		"res://assets/art/scenes/__no_such_plate__.png")
	dark.instant = false
	dark._ready()
	_check(fails, dark.find_child(HearthFigure.NAME, true, false) == null,
		"a missing plate still seated the figure")
	dark.free()
	var lit: DepartureStaging = DepartureStaging.new()
	lit.instant = false
	lit._ready()
	var plant: TextureRect = lit.find_child("HearthPlant", true, false) as TextureRect
	var window: TextureRect = lit.find_child("HearthWindow", true, false) as TextureRect
	_check(fails, plant != null and window != null, "linger lost its plates")
	if plant == null or window == null:
		lit.free()
		return
	var plant_figure: HearthFigure = plant.find_child(HearthFigure.NAME, false, false) as HearthFigure
	var window_figure: HearthFigure = window.find_child(HearthFigure.NAME, false, false) as HearthFigure
	_check(fails, plant_figure != null, "plant has no hearth figure")
	_check(fails, window_figure != null, "window reflection has no hearth figure")
	if window_figure != null:
		_check(fails, window_figure._sprite != null and window_figure._sprite.flip_h,
			"window figure is not flipped with the room")
	_check(fails, is_equal_approx(window.modulate.a, 0.0),
		"window reflection was visible before the lag")
	lit._tick_window(DepartureStaging.WINDOW_LAG / DepartureStaging.HEARTH_HOLD)
	_check(fails, is_equal_approx(window.modulate.a, 0.0),
		"window reflection appeared at the lag boundary")
	lit._tick_window(1.0)
	_check(fails, is_equal_approx(window.modulate.a, 0.45),
		"window reflection did not reach 0.45 after the hold")
	if window_figure != null:
		_check(fails, is_equal_approx(window_figure.modulate.a * window.modulate.a, 0.45),
			"figure in the reflection did not lag with the window")
	lit.free()


static func _unsealing_pane_lighting(fails: Array[String]) -> void:
	var script: SceneScript = _script("unsealing")
	if script == null:
		_check(fails, false, "unsealing did not load")
		return
	var player: ScenePlayer = _live(script, 0)
	var rose: UnsealingStaging = _rose(player)
	_check(fails, rose != null and rose.visible, "beat 1 has no rose staging")
	if rose != null:
		_check(fails, rose.mural_is_emberglass(),
			"beat 1 sampled something other than the emberglass mural")
		_check(fails, rose.mural_on_count() == RoseWindowView.IDS.size(),
			"beat 1 is not lighting the shipped panes")
		_check(fails, is_equal_approx(rose.sixth_alpha(), 1.0),
			"instant beat 1 did not land the sixth pane lit")
	var plate: TextureRect = player.find_child("Plate", true, false) as TextureRect
	_check(fails, plate != null and not plate.visible,
		"beat 1 bound a plate the beat does not name")
	player.free()
	var lit: ScenePlayer = _live(script, 1)
	var all_lit: UnsealingStaging = _rose(lit)
	_check(fails, all_lit != null and all_lit.visible,
		"beat 2 (窗全亮) has no rose staging")
	if all_lit != null:
		_check(fails, is_equal_approx(all_lit.sixth_alpha(), 1.0),
			"beat 2 did not keep the sixth pane lit")
	lit.free()


static func _unsealing_mirror_is_one_queue(fails: Array[String]) -> void:
	var script: SceneScript = _script("unsealing")
	if script == null:
		_check(fails, false, "unsealing did not load")
		return
	var player: ScenePlayer = _live(script, 2)
	var rose: UnsealingStaging = _rose(player)
	_check(fails, rose != null and not rose.visible,
		"beat 3 kept the rose over the mirror plate")
	var plate: TextureRect = player.find_child("Plate", true, false) as TextureRect
	_check(fails, plate != null and plate.visible and plate.texture != null,
		"beat 3 did not bind the mirror plate")
	if plate != null and plate.texture != null:
		_check(fails, plate.texture.resource_path.ends_with("unsealing-mirror-queue.png"),
			"beat 3 bound a plate other than the one-queue mirror")
	_check(fails, _queue_copies(player) == 1,
		"beat 3 duplicated the queue (%d copies)" % _queue_copies(player))
	if rose != null:
		_check(fails, rose.mural_is_emberglass(),
			"the rose sampled the queue plate as a per-pane mural")
	player.free()


static func _unsealing_does_not_break_the_player(fails: Array[String]) -> void:
	var script: SceneScript = _script("unsealing")
	if script == null:
		_check(fails, false, "unsealing did not load")
		return
	var asked: Array[int] = [0]
	var done: Array[int] = [0]
	var player: ScenePlayer = _live(script, 0, asked, done)
	_check(fails, asked[0] == 1, "unsealing beat 1 did not ask once")
	var steps: int = 0
	while done[0] == 0 and steps < script.line_count() + 1:
		player.advance_confirmed()
		player._process(0.016)
		steps += 1
	_check(fails, done[0] == 1, "unsealing with staging did not finish")
	_check(fails, asked[0] == script.line_count(),
		"unsealing staging changed the ask count (got %d)" % asked[0])
	player.advance_confirmed()
	_check(fails, done[0] == 1, "unsealing finished more than once")
	player.free()


static func _resume_keeps_staging(fails: Array[String]) -> void:
	var script: SceneScript = _script("unsealing")
	if script == null:
		_check(fails, false, "unsealing did not load")
		return
	var player: ScenePlayer = _live(script, 1)
	_check(fails, _text(player) == Locale.active.t("story.unsealing.b2.l1"),
		"resume at cursor 1 is not on beat 2's line")
	var rose: UnsealingStaging = _rose(player)
	_check(fails, rose != null and rose.visible,
		"resume at cursor 1 dropped the fully-lit rose")
	player.free()
	var mirror: ScenePlayer = _live(script, 2)
	_check(fails, _text(mirror) == Locale.active.t("story.unsealing.b3.l1"),
		"resume at cursor 2 is not on the mirror line")
	var hidden: UnsealingStaging = _rose(mirror)
	_check(fails, hidden != null and not hidden.visible,
		"resume at cursor 2 did not yield to the one-queue plate")
	mirror.free()


static func _live(script: SceneScript, cursor: int, asked: Array[int] = [],
		done: Array[int] = []) -> ScenePlayer:
	var player: ScenePlayer = ScenePlayer.new(script, cursor)
	player.instant = true
	if not asked.is_empty():
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


static func _figure(player: ScenePlayer) -> Node:
	return player.find_child(HearthFigure.NAME, true, false)


static func _rose(player: ScenePlayer) -> UnsealingStaging:
	return player.find_child(UnsealingStaging.NAME, true, false) as UnsealingStaging


static func _text(player: ScenePlayer) -> String:
	var line: Label = player.find_child("Line", true, false) as Label
	return line.text if line != null else ""


static func _queue_copies(root: Node) -> int:
	var n: int = 0
	if root is TextureRect:
		var plate: TextureRect = root
		if plate.texture != null \
				and plate.texture.resource_path.ends_with("unsealing-mirror-queue.png"):
			n += 1
	for child: Node in root.get_children():
		n += _queue_copies(child)
	return n
