extends SceneTree
## Only the new per-world construction seam; prior384-case gate is not replayed.
const Obs: GDScript = preload("res://observed_game.gd")
const Cloner: GDScript = preload("res://public_rollout.gd")
const FLAGS: Array[String] = ["hand_preparation_enabled", "hand_surge_enabled", "hand_phantom_enabled"]

func masks(g: GlassvowGame) -> Array:
	var result: Array = []
	for flag: String in FLAGS:
		result.append(g.rules.get(flag))
	return result

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3:
		quit(2)
		return
	var world: String = args[0]
	var expected: Array = [world[0] == "1", world[0] == "1", world[1] == "1"]
	var db: ContentDB = BalanceCatalogue.load_prepared({"path": "res://content/full-content.json"})
	assert(db != null)
	var run: RunState = RunState.new_run(db, 73620010, "hand-world-entry", {"aspect": 1, "vow": 5, "reveals": db.reveal_ids.duplicate(), "unlocks": ["aspect2"], "quests": {}, "shards": []})
	run.omens = [null, null, null]
	run.player.relics.clear()
	var stream: FileAccess = FileAccess.open(args[2], FileAccess.WRITE)
	assert(stream != null)
	Obs.begin("entry", stream)
	var g: GlassvowGame = Obs.new(db, run)
	assert(masks(g) == expected, "ENTRY_ASSIGNMENT")
	g.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
	g.cb.affix = &""
	g.cb.queue.clear()
	g.cb.player.statuses = {}
	g.cb.player.energy = 6
	g.cb.player.hp = 60
	g.cb.player.max_hp = 100
	g.run.player.hp = 60
	g.run.player.max_hp = 100
	g.cb.hand.clear()
	g.cb.draw.clear()
	g.cb.discard.clear()
	g.cb.exhaust.clear()
	g.cb.enemies[0].hp = 1000
	g.cb.enemies[0].max_hp = 1000
	g.cb.enemies[0].block = 0
	g.cb.enemies[0].statuses = {}
	g.cb.hand.append(CardInst.new(91001, &"preparation"))
	g.cb.hand.append(CardInst.new(91002, &"surge"))
	g.cb.hand.append(CardInst.new(91003, &"phantomBlades"))
	for i: int in range(5):
		g.cb.draw.append(CardInst.new(92000 + i, &"defend"))
	var before: Dictionary = Obs.snapshot(g)
	var exact: GlassvowGame = g.call("clone_game")
	var public_model: GlassvowGame = Cloner.clone_public(g, 0)
	assert(masks(exact) == expected and masks(public_model) == expected, "CLONE_WORLD")
	var untouched: bool = Obs.snapshot(g) == before
	assert(untouched, "CLONE_MUTATION")
	var steps: Array = []
	for uid: int in [91001, 91002, 91003]:
		var cmd: Dictionary = {"t": "playCard", "uid": uid, "target": 0 if uid == 91003 else null}
		var events: Array[Dictionary] = g.apply(cmd)
		assert(g.last_ret == true, "ENTRY_COMMAND")
		assert(masks(g) == expected, "WORLD_DRIFT")
		steps.append({"command": cmd, "events": events, "after": Obs.snapshot(g)})
	var output: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify({"kind": "HAND_WORLD_ENTRY", "masks": expected, "clone_masks_preserved": true, "factual_untouched": untouched, "before": before, "steps": steps}))
	output.close()
	stream.close()
	quit(0)
