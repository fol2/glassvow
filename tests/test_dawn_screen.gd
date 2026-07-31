extends RefCounted
## The Dawn feed's durable contract, held from the presentation side: what a
## resumed cursor shows, what the one-shots do NOT replay, and when the
## terminal buttons may be pressed. The domain half (cursor persisted per
## advance) lives in main's drive; this pins the screen's answers to it.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_dawn_screen: %s" % what)


static func _events() -> Array:
	return [
		{"kind": "whisper", "title": "", "body": "A test whisper."},
		{"kind": "quest", "title": "The Pale Ones", "body": "An inscription."},
		{"kind": "progress", "title": "The Pale Ones", "body": "2/3"},
		{"kind": "shard", "title": "The Shade That Fell", "body": "One pane answers."},
	]


static func _grid_of(screen: DawnScreen) -> GridContainer:
	# The feed grid is the one GridContainer with 8px separations under a
	# ScrollContainer; walking the tree keeps the test off private fields.
	var stack: Array[Node] = [screen]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is GridContainer and node.get_parent() is ScrollContainer:
			return node
		for child: Node in node.get_children():
			stack.append(child)
	return null


static func _buttons_of(screen: DawnScreen) -> Array[Button]:
	var out: Array[Button] = []
	var stack: Array[Node] = [screen]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button:
			out.append(node)
		for child: Node in node.get_children():
			stack.append(child)
	return out


static func _has_confetti(screen: DawnScreen) -> bool:
	for child: Node in screen.get_children():
		if child is DawnScreen.Confetti:
			return true
	return false


static func run(fails: Array[String]) -> void:
	# A resumed dawn: cursor 2 of 4. Exactly the two persisted memories stand,
	# nothing replays, the buttons stay sealed. `_ready` has not run (the
	# screen is never added to a tree here), so the dressing check reads the
	# _init-time truth: no confetti child is minted at build.
	var resumed: DawnScreen = DawnScreen.new(_events(), 2)
	var grid: GridContainer = _grid_of(resumed)
	_check(fails, grid != null, "the feed grid is discoverable")
	if grid != null:
		_check(fails, grid.get_child_count() == 2,
			"a cursor of 2 stands exactly 2 memories (got %d)" % grid.get_child_count())
	_check(fails, not _has_confetti(resumed), "a resumed dawn does not replay confetti")
	for button: Button in _buttons_of(resumed):
		_check(fails, button.disabled, "buttons stay sealed while memories are owed")
	resumed.free()

	# The feed's handshake: advance_confirmed is the ONLY way forward, and the
	# last confirmation opens the doors. This is the screen-side half of the
	# durable-cursor contract — main only confirms after SaveService held.
	# (Standing the arriving card is _begin_beat's job and _begin_beat fires
	# from _ready — a tree-less test sees only the built state, 3 standing.)
	var live: DawnScreen = DawnScreen.new(_events(), 3)
	live.advance_confirmed()
	for button: Button in _buttons_of(live):
		_check(fails, not button.disabled, "the settled ceremony unseals the buttons")
	var live_grid: GridContainer = _grid_of(live)
	if live_grid != null:
		_check(fails, live_grid.get_child_count() == 3,
			"a tree-less confirm advances state, not scenery (got %d)" % live_grid.get_child_count())
	live.free()

	# A completed dawn rebuilt from its save (kill after the last persist):
	# everything stands, nothing owed, doors open.
	var done: DawnScreen = DawnScreen.new(_events(), 4)
	var done_grid: GridContainer = _grid_of(done)
	if done_grid != null:
		_check(fails, done_grid.get_child_count() == 4,
			"a completed dawn stands every memory (got %d)" % done_grid.get_child_count())
	for button: Button in _buttons_of(done):
		_check(fails, not button.disabled, "a completed dawn arrives with the doors open")
	done.free()
