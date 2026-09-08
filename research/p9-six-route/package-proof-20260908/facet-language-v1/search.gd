extends SceneTree
## Bounded legal-word search, not a new policy cohort or the old 672-row exam.
const Probe = preload("res://causal_probe.gd")
const Health = preload("res://health_accounting.gd")
const Diagnostic = preload("res://diagnostic_rules.gd")
const MAX_DEPTH: int = 10
const MAX_TURN: int = 4
const MAX_NODES: int = 20000
var db: ContentDB
var out: FileAccess
var stored: Dictionary = {}
var node_serial: int = 0

func emit(record: Dictionary) -> void:
	out.store_line(JSON.stringify(record))
	out.flush()

func snapshot(g: GlassvowGame) -> String:
	var text: String = JSON.stringify(Probe.projection([g.run, g.cb, g.last_ret], {}))
	var h: String = text.sha256_text()
	if not stored.has(h):
		stored[h] = true
		emit({"kind":"state", "sha256":h, "serialized":text})
	return h

func clone(g: GlassvowGame) -> GlassvowGame:
	var memo: Dictionary = {}
	var r: RunState = Probe.duplicate_value(g.run, memo)
	var cb: CombatState = Probe.duplicate_value(g.cb, memo)
	var child := GlassvowGame.new(db, r)
	child.cb = cb
	child.last_ret = g.last_ret
	assert(snapshot(child) == snapshot(g), "CLONE_IDENTITY")
	return child

func make_fixture(vow: int, upgraded: bool) -> GlassvowGame:
	var run := RunState.new_run(db, 47080001, "command-fixture", {"aspect":0, "vow":vow, "reveals":db.reveal_ids.duplicate(), "unlocks":["aspect2"], "quests":{}, "shards":[]})
	run.omens = [null, null, null]
	run.player.relics.clear()
	var g := GlassvowGame.new(db, run)
	g.apply({"t":"startCombat", "enemies":["rootheart"], "kind":"boss", "affix":null})
	g.cb.player.statuses = {}
	g.cb.player.block = 0
	g.cb.enemies[0].statuses = {}
	g.cb.enemies[0].block = 0
	g.cb.hand.clear()
	g.cb.draw.clear()
	g.cb.discard.clear()
	g.cb.exhaust.clear()
	g.run.player.deck.clear()
	g.cb.queue.clear()
	for j in range(3):
		g.cb.hand.append(CardInst.new(900+j, &"chisel", upgraded))
	for j in range(3):
		g.cb.draw.append(CardInst.new(1100+j, &"defend", false))
	g.cb.draw.append(CardInst.new(1000, &"resonantLance", upgraded))
	if vow == 5:
		g.cb.draw.append(CardInst.new(903, &"chisel", upgraded))
	for c in g.cb.hand + g.cb.draw:
		g.run.player.deck.append(c.combat_copy())
	return g

func prefix_commands(g: GlassvowGame, depth: int) -> Array:
	var commands: Array = []
	if g.cb.over or depth >= MAX_DEPTH-1:
		return commands
	var uids: Array = []
	for c: CardInst in g.cb.hand:
		if c.id in [&"chisel", &"defend"]:
			uids.append(c.uid)
	uids.sort()
	for uid: int in uids:
		var c: CardInst = Probe.find_card(g, uid)
		var target: Variant = 0 if c.id == &"chisel" else null
		if g.rules.can_play(g.run, g.cb, c, target):
			commands.append({"t":"playCard", "uid":uid, "target":target})
	if g.cb.turn < MAX_TURN:
		commands.append({"t":"endTurn"})
	return commands

func enabled(g: GlassvowGame) -> bool:
	var c: CardInst = Probe.find_card(g, 1000)
	if c == null or g.cb.over or not g.rules.can_play(g.run, g.cb, c, 0):
		return false
	var e: EnemyCombatant = g.cb.enemies[0]
	return int(g.run.stats.get("shatters", 0)) > 0 and (e.staggered or int(e.statuses.get("vulnerable", 0)) > 0)

func terminal(g: GlassvowGame) -> Dictionary:
	var cmd := {"t":"playCard", "uid":1000, "target":0}
	var arms: Array = []
	for erase: bool in [false, true]:
		var child: GlassvowGame = clone(g)
		if erase:
			var rules := Diagnostic.new(db)
			rules.erased_consumer = "echo"
			child.rules = rules
		var hp: Dictionary = Health.snapshot(child.cb)
		var events: Array[Dictionary] = child.apply(cmd)
		var accounting: Dictionary = Health.fold(hp, events, Health.snapshot(child.cb))
		assert(child.last_ret == true and accounting.ok, "TERMINAL_EXECUTION")
		arms.append({"erase_echo":erase, "after":snapshot(child), "events":events, "accounting":accounting, "ret":child.last_ret})
	return {"cmd":cmd, "arms":arms, "extra_hp":int(arms[0].accounting.removed)-int(arms[1].accounting.removed)}

func replay(vow: int, up: bool, path: Array, final: String) -> Dictionary:
	var g := make_fixture(vow, up)
	var steps: Array = []
	for cmd: Dictionary in path:
		var before: String = snapshot(g)
		var events: Array[Dictionary] = g.apply(cmd)
		assert(cmd.t != "playCard" or g.last_ret == true, "REPLAY_LEGALITY")
		steps.append({"cmd":cmd, "before":before, "after":snapshot(g), "events":events, "ret":g.last_ret})
	assert(snapshot(g) == final, "REPLAY_FINAL_IDENTITY")
	return {"steps":steps, "final":snapshot(g)}

func search(vow: int, up: bool) -> void:
	var root := make_fixture(vow, up)
	var initial: String = snapshot(root)
	var cfg := {"vow":vow, "up":up, "initial":initial}
	var queue: Array = [{"game":root, "path":[], "state":initial, "id":node_serial}]
	node_serial += 1
	var seen: Dictionary = {initial:queue[0].id}
	var cursor: int = 0
	emit({"kind":"case", "case":cfg, "root_id":queue[0].id})
	while cursor < queue.size():
		if queue.size() > MAX_NODES:
			emit({"kind":"result", "case":cfg, "status":"INCONCLUSIVE_NODE_CAP", "expanded":cursor, "discovered":queue.size()})
			return
		var node: Dictionary = queue[cursor]
		var g: GlassvowGame = node.game
		var path: Array = node.path
		var commands: Array = prefix_commands(g, path.size())
		var probe: Dictionary = {}
		if enabled(g):
			probe = terminal(g)
		var edges: Array = []
		if not probe.is_empty() and probe.extra_hp > 0:
			var complete_path: Array = path.duplicate(true)
			complete_path.append(probe.cmd)
			var direct: Dictionary = replay(vow, up, complete_path, probe.arms[0].after)
			emit({"kind":"node", "case":cfg, "id":node.id, "state":node.state, "depth":path.size(), "terminal":probe, "commands":[], "edges":[], "winning":true})
			emit({"kind":"result", "case":cfg, "status":"BOUNDED_MINIMUM_WORD_FOUND", "minimum_commands":complete_path.size(), "expanded":cursor+1, "discovered":queue.size(), "path":complete_path, "direct_replay":direct, "extra_hp":probe.extra_hp, "winning_id":node.id})
			return
		for cmd: Dictionary in commands:
			var child := clone(g)
			var hp: Dictionary = Health.snapshot(child.cb)
			var events: Array[Dictionary] = child.apply(cmd)
			var accounting: Dictionary = Health.fold(hp, events, Health.snapshot(child.cb))
			assert((cmd.t != "playCard" or child.last_ret == true) and accounting.ok, "EDGE_EXECUTION")
			var child_hash: String = snapshot(child)
			var fresh: bool = not seen.has(child_hash)
			if fresh:
				seen[child_hash] = node_serial
				node_serial += 1
				var next_path: Array = path.duplicate(true)
				next_path.append(cmd)
				queue.append({"game":child, "path":next_path, "state":child_hash, "id":seen[child_hash]})
			edges.append({"cmd":cmd, "to":seen[child_hash], "state":child_hash, "fresh":fresh, "events":events, "accounting":accounting, "ret":child.last_ret})
		emit({"kind":"node", "case":cfg, "id":node.id, "state":node.state, "depth":path.size(), "terminal":probe, "commands":commands, "edges":edges, "winning":false})
		queue[cursor].game = null
		cursor += 1
	emit({"kind":"result", "case":cfg, "status":"NO_WORD_IN_BOUNDED_GRAMMAR", "expanded":cursor, "discovered":queue.size()})

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1 and not FileAccess.file_exists(args[0]), "FRESH_OUTPUT_REQUIRED")
	out = FileAccess.open(args[0], FileAccess.WRITE)
	assert(out != null, "OUTPUT_OPEN")
	db = ContentDB.load_full()
	assert(db.enemies.has("rootheart"), "CATALOGUE")
	emit({"kind":"header", "engine":Engine.get_version_info(), "content_sha256":FileAccess.get_sha256("res://content/full-content.json"), "script_sha256":FileAccess.get_sha256("res://facet_language.gd"), "max_depth":MAX_DEPTH, "max_turn":MAX_TURN, "max_nodes_per_case":MAX_NODES})
	for vow: int in [0, 5]:
		for up: bool in [false, true]:
			search(vow, up)
	emit({"kind":"summary", "cases":4, "states":stored.size(), "allocated_nodes":node_serial})
	out.close()
	quit(0)
