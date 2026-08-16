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


## The cutout has to survive the frame it is composed into, not merely exist
## in it (#334 review). Three shape constraints, all measured off live code:
## the copy panel draws OVER the figure, the figure keeps its mass out of the
## panel and out of the letterbox band, and it is graded toward the hall.
static func _overlay_on_opening(fails: Array[String]) -> void:
	var opening: SceneScript = _script("opening")
	if opening == null:
		_check(fails, false, "opening did not load")
		return
	var view: Vector2 = Vector2(StageShape.REFERENCES[StageShape.IDENTITY])
	for cursor: int in [0, 2, 5, 7]:
		var player: ScenePlayer = _live(opening, cursor)
		var figure: HearthFigure = _figure(player) as HearthFigure
		_check(fails, figure != null,
			"opening cursor %d has no hearth figure" % cursor)
		if figure == null:
			player.free()
			continue
		# Dialogue over scenery, never a cutout pasted over the UI. Draw order
		# is tree order, so the copy branch must sit after the plate branch.
		_check(fails, _branch(player, figure) < _branch(player, player._copy),
			"cursor %d draws the hearth figure over the dialogue panel" % cursor)
		var grade: Color = figure.modulate
		_check(fails, not grade.is_equal_approx(Color.WHITE),
			"cursor %d ships the cutout ungraded against a warm-black hall" % cursor)
		_check(fails, grade.r > grade.g and grade.g > grade.b,
			"cursor %d grades the cutout cold; the hearth lights it warm" % cursor)
		_check(fails, grade.r <= 0.88 and minf(grade.g, grade.b) >= 0.32,
			"cursor %d grades the cutout out of the plate's ambient range" % cursor)
		var seat: Rect2 = _seat_rect(figure, view)
		_check(fails, seat.size.x > 1.0 and seat.size.y > 1.0,
			"cursor %d never laid the cutout out" % cursor)
		# `set_shape` letterboxes the bottom 8%; a hem below it is a robe cut
		# off by a black bar, not a figure sitting on the hearth platform.
		_check(fails, seat.end.y <= view.y * 0.92 and seat.end.y >= view.y * 0.70,
			"cursor %d seats the cutout off the hearth platform (hem at %.0f)"
				% [cursor, seat.end.y])
		# The panel is `_copy.custom_minimum_size.x` wide and centre-docked.
		var panel_right: float = (view.x + player._copy.custom_minimum_size.x) * 0.5
		var behind: float = clampf(panel_right - seat.position.x, 0.0, seat.size.x)
		_check(fails, behind <= seat.size.x * 0.25,
			"cursor %d hides %.0f%% of the cutout behind the panel"
				% [cursor, 100.0 * behind / maxf(seat.size.x, 1.0)])
		_check(fails, seat.end.x <= view.x,
			"cursor %d pushes the cutout off the right edge" % cursor)
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


## 窗中反影遲半拍 is a reflection IN THE ROSE WINDOW (`00-truth.md:177-178`).
## The first cut mirrored the whole hall and seated a second Keeper on it; the
## shape constraints below are what forbid that — one plate, one body, and a
## reflection region that is the rose, not the doorway and not the hall. The
## half-beat lag itself was correct and is re-pinned unchanged. James signed
## route A on #334; B and C are gone.
static func _departure_lags_the_figure(fails: Array[String]) -> void:
	var dark: DepartureStaging = DepartureStaging.new(
		"res://assets/art/scenes/__no_such_plate__.png")
	dark.instant = false
	dark._ready()
	_check(fails, dark.find_child(HearthFigure.NAME, true, false) == null,
		"a missing plate still seated the figure")
	_check(fails, dark.find_child(WindowReflection.NAME, true, false) == null,
		"a missing plate still staged a reflection")
	dark.free()
	_departure_linger(fails, Vector2(StageShape.REFERENCES[StageShape.IDENTITY]))


static func _departure_linger(fails: Array[String], view: Vector2) -> void:
	var lit: DepartureStaging = DepartureStaging.new()
	lit.instant = false
	lit.set_anchors_preset(Control.PRESET_TOP_LEFT)
	lit.size = view
	lit._ready()
	# The hall is painted once. A second full-bleed copy IS the mirror defect.
	_check(fails, _texture_copies(lit, "opening-hearth.png") == 1,
		"linger paints the hall %d times" % _texture_copies(lit, "opening-hearth.png"))
	_check(fails, _node_count(lit, HearthFigure.NAME) == 1,
		"linger puts %d bodies on screen; James ruled one"
			% _node_count(lit, HearthFigure.NAME))
	var reflection: WindowReflection = lit.find_child(
		WindowReflection.NAME, true, false) as WindowReflection
	_check(fails, reflection != null, "linger lost its reflection")
	if reflection == null:
		lit.free()
		return
	# The region is the rose, anchor-driven so it rides the plate.
	_check(fails, is_zero_approx(reflection.offset_left)
			and is_zero_approx(reflection.offset_right)
			and is_zero_approx(reflection.offset_top)
			and is_zero_approx(reflection.offset_bottom),
		"linger pins the reflection in pixels; it will drift off the plate")
	_check(fails, is_equal_approx(reflection.anchor_left, WindowReflection.ROSE.position.x)
			and is_equal_approx(reflection.anchor_top, WindowReflection.ROSE.position.y)
			and is_equal_approx(reflection.anchor_right, WindowReflection.ROSE.end.x)
			and is_equal_approx(reflection.anchor_bottom, WindowReflection.ROSE.end.y),
		"linger did not seat the reflection in the rose window")
	var region: Rect2 = _anchor_rect(reflection, view)
	_check(fails, region.get_area() > 0.0
			and region.get_area() <= view.x * view.y * 0.08,
		"linger reflects %.0f%% of the frame; that is the hall, not a window"
			% (100.0 * region.get_area() / (view.x * view.y)))
	_check(fails, Rect2(Vector2.ZERO, view).encloses(region),
		"linger hangs the reflection off the frame")
	var ghost: TextureRect = reflection.find_child("Ghost", true, false) as TextureRect
	_check(fails, ghost != null, "linger has no reflected figure")
	if ghost != null:
		_check(fails, ghost.flip_h, "linger reflects the figure unmirrored")
		_check(fails, not ghost.modulate.is_equal_approx(Color.WHITE)
				and ghost.modulate.b > ghost.modulate.r,
			"linger returns the figure at full warm chroma, not as dark glass")
	if Preferences.active.reduce_motion:
		_check(fails, is_equal_approx(reflection.modulate.a,
				DepartureStaging.REFLECT_ALPHA),
			"linger dropped the reflection under reduce_motion")
		lit.free()
		return
	_check(fails, is_equal_approx(reflection.modulate.a, 0.0),
		"linger showed the reflection before the lag")
	lit._tick_window(DepartureStaging.WINDOW_LAG / DepartureStaging.HEARTH_HOLD)
	_check(fails, is_equal_approx(reflection.modulate.a, 0.0),
		"linger showed the reflection at the lag boundary")
	lit._tick_window(0.75)
	_check(fails, is_equal_approx(reflection.modulate.a,
			DepartureStaging.REFLECT_ALPHA * 0.5),
		"linger steps the reflection in instead of ramping it")
	lit._tick_window(1.0)
	_check(fails, is_equal_approx(reflection.modulate.a,
			DepartureStaging.REFLECT_ALPHA),
		"linger did not reach the reflection's peak after the hold")
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
	var lit: ScenePlayer = _live(script, _first_of_beat(script, 1))
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
	var player: ScenePlayer = _live(script, _first_of_beat(script, 2))
	var rose: UnsealingStaging = _rose(player)
	_check(fails, rose != null and not rose.visible,
		"beat 3 kept the rose over the mirror plate")
	var plate: TextureRect = player.find_child("Plate", true, false) as TextureRect
	_check(fails, plate != null and plate.visible and plate.texture != null,
		"beat 3 did not bind the mirror plate")
	if plate != null and plate.texture != null:
		_check(fails, plate.texture.resource_path.ends_with("unsealing-mirror-queue.png"),
			"beat 3 bound a plate other than the one-queue mirror")
	var queue_file: String = "unsealing-mirror-queue.png"
	_check(fails, _texture_copies(player, queue_file) == 1,
		"beat 3 duplicated the queue (%d copies)" % _texture_copies(player, queue_file))
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
	var player: ScenePlayer = _live(script, _first_of_beat(script, 1))
	_check(fails, _text(player) == Locale.active.t("story.unsealing.b2.l1"),
		"resume at cursor 1 is not on beat 2's line")
	var rose: UnsealingStaging = _rose(player)
	_check(fails, rose != null and rose.visible,
		"resume at cursor 1 dropped the fully-lit rose")
	player.free()
	var mirror: ScenePlayer = _live(script, _first_of_beat(script, 2))
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


static func _first_of_beat(script: SceneScript, beat_i: int) -> int:
	for i: int in range(script.lines.size()):
		if int(float(str(script.lines[i].get("beat", -1)))) == beat_i:
			return i
	return 0


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


static func _texture_copies(root: Node, plate_file: String) -> int:
	var n: int = 0
	if root is TextureRect:
		var plate: TextureRect = root
		if plate.texture != null \
				and plate.texture.resource_path.ends_with(plate_file):
			n += 1
	for child: Node in root.get_children():
		n += _texture_copies(child, plate_file)
	return n


static func _node_count(root: Node, node_name: String) -> int:
	var n: int = 1 if root.name == node_name else 0
	for child: Node in root.get_children():
		n += _node_count(child, node_name)
	return n


## Index, under `root`, of the branch `node` draws in. CanvasItem draw order
## is tree order, so a smaller index draws first — i.e. underneath.
static func _branch(root: Node, node: Node) -> int:
	var walk: Node = node
	while walk != null and walk.get_parent() != root:
		walk = walk.get_parent()
	return walk.get_index() if walk != null else -1


static func _anchor_rect(node: Control, view: Vector2) -> Rect2:
	return Rect2(
		Vector2(node.anchor_left * view.x, node.anchor_top * view.y),
		Vector2((node.anchor_right - node.anchor_left) * view.x,
			(node.anchor_bottom - node.anchor_top) * view.y))


## The cutout's painted rect at the reference frame. Anchors do not resolve
## outside a SceneTree, so the seat box is read off them and then handed to
## the real `HearthFigure._layout` — a broken fit fails here too.
static func _seat_rect(figure: HearthFigure, view: Vector2) -> Rect2:
	var box: Rect2 = _anchor_rect(figure, view)
	figure.set_anchors_preset(Control.PRESET_TOP_LEFT)
	figure.size = box.size
	figure._layout()
	if figure._sprite == null:
		return Rect2()
	return Rect2(box.position + figure._sprite.position, figure._sprite.size)
