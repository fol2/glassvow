extends SceneTree
## Research fixture only. No product rule, candidate or protected cohort is changed.
const Probe = preload("res://causal_probe.gd")
const Health = preload("res://health_accounting.gd")
const PRODUCERS = {"facet":"chisel", "fervor":"empower", "cycle":"momentum", "smolder":"venomStrike", "hand":"nightSight"}
const CONSUMERS = {"facet":"resonantLance", "fervor":"flurry", "cycle":"momentum", "smolder":"catalyst", "hand":"phantomBlades"}
var db: ContentDB
var out: FileAccess
var seen: Dictionary = {}
var rows: int = 0
var fixtures: int = 0
var failed: bool = false

func emit(value: Dictionary) -> void:
	out.store_line(JSON.stringify(value))
	out.flush()

func require(ok: bool, reason: String) -> bool:
	if not ok:
		failed = true
		push_error("COMMAND_CHAIN " + reason)
	return ok

func snapshot(g: GlassvowGame) -> String:
	var fields: Array = Probe.projection([g.run, g.cb, g.last_ret], {})
	var text: String = JSON.stringify(fields)
	var key: String = text.sha256_text()
	if not seen.has(key):
		seen[key] = true
		emit({"kind":"state", "sha256":key, "serialized":text})
	return key

func instance(uid: int, cid: String, upgraded: bool) -> CardInst:
	return CardInst.new(uid, StringName(cid), upgraded)

func make_game(spec: Dictionary) -> GlassvowGame:
	var run := RunState.new_run(db, 47080001, "command-fixture", {"aspect":spec.aspect, "vow":spec.vow, "reveals":db.reveal_ids.duplicate(), "unlocks":["aspect2"], "quests":{}, "shards":[]})
	run.omens = [null, null, null]
	run.player.relics.clear()
	var g := GlassvowGame.new(db, run)
	g.apply({"t":"startCombat", "enemies":["rootheart"], "kind":"boss", "affix":null})
	# One declared initial fixture boundary. Native HP, Energy, facets and AI remain.
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
	var role: String = spec.role
	var n: int = spec.producers
	if role == "facet":
		for j in range(mini(3, n)):
			g.cb.hand.append(instance(900+j, "chisel", spec.up))
		# draw.pop_back(): fourth Chisel (V5), then Lance, then ordinary fillers.
		for j in range(3):
			g.cb.draw.append(instance(1100+j, "defend", false))
		g.cb.draw.append(instance(1000, "resonantLance", spec.up))
		if n == 4:
			g.cb.draw.append(instance(903, "chisel", spec.up))
		if spec.control:
			g.cb.enemies[0].statuses["vulnerable"] = 2
	elif role == "cycle":
		g.cb.hand.append(instance(900, "momentum", spec.up))
		g.cb.draw.append(instance(1000, "momentum", spec.up))
		g.cb.draw.append(instance(1100, "defend", false))
	elif role == "hand":
		g.cb.hand.append(instance(900, "nightSight", spec.up))
		for j in range(11):
			g.cb.draw.append(instance(1100+j, "defend", false))
		g.cb.draw.append(instance(1000, "phantomBlades", spec.up))
		if spec.control:
			g.cb.player.statuses["nightsight"] = 5
	else:
		g.cb.hand.append(instance(900, PRODUCERS[role], spec.up))
		var consumer: String = "strike" if role == "fervor" and spec.control else CONSUMERS[role]
		g.cb.hand.append(instance(1000, consumer, spec.up))
		if role == "smolder" and spec.control:
			g.cb.enemies[0].statuses["poison"] = 2
	for card in g.cb.hand + g.cb.draw:
		g.run.player.deck.append(card.combat_copy())
	return g

func play(uid: int, role: String, is_producer: bool) -> Dictionary:
	var target: Variant = null if is_producer and role in ["fervor", "hand"] else 0
	return {"t":"playCard", "uid":uid, "target":target}

func commands(spec: Dictionary, mask: int, consumer: bool, reverse: bool) -> Array:
	var plan: Array = []
	var role: String = spec.role
	var consumer_uid: int = 900 if role == "cycle" and not spec.control else 1000
	if reverse:
		plan.append(play(consumer_uid, role, false))
		plan.append(play(900, role, true))
		return plan
	for j in range(spec.producers):
		if mask & (1 << j):
			plan.append(play(900+j, role, true))
		if role == "facet" and j == 2:
			plan.append({"t":"endTurn"})
	if role in ["cycle", "hand"]:
		plan.append({"t":"endTurn"})
	if consumer:
		plan.append(play(consumer_uid, role, false))
	return plan

func observe(spec: Dictionary, mask: int, consumer: bool, reverse: bool, initial: String) -> void:
	var g := make_game(spec)
	if not require(snapshot(g) == initial, "INITIAL_STATE_DIFF"):
		return
	var steps: Array = []
	var removed: int = 0
	var nominal: int = 0
	var energy: int = 0
	var hp0: int = g.cb.enemies[0].hp
	var player0: int = g.cb.player.hp
	var poison0: int = Probe.poison(g.cb)
	var previous: String = initial
	for cmd in commands(spec, mask, consumer, reverse):
		var before: String = snapshot(g)
		if not require(before == previous, "HIDDEN_STATE_MUTATION"):
			return
		var hp: Dictionary = Health.snapshot(g.cb)
		var energy0: int = g.cb.player.energy
		var q: Array = g.cb.queue.duplicate(true)
		var events: Array = g.apply(cmd)
		if not require(g.cb.queue.slice(0, q.size()) == q, "PAST_EVENTS_MUTATED"):
			return
		if cmd.t == "playCard" and not require(g.last_ret == true, "ILLEGAL_COMMAND"):
			return
		var folded: Dictionary = Health.fold(hp, events, Health.snapshot(g.cb))
		if not require(folded.get("ok", false), "HEALTH_FOLD"):
			return
		if cmd.t == "playCard":
			energy += energy0-g.cb.player.energy
		removed += folded.removed
		nominal += folded.nominal
		previous = snapshot(g)
		steps.append({"cmd":cmd, "before":before, "after":previous, "ret":g.last_ret, "events":events})
	rows += 1
	emit({"kind":"row", "fixture":spec, "mask":mask, "consumer":consumer, "reverse":reverse, "initial":initial, "final":previous, "steps":steps, "metrics":{"hp_removed":removed, "nominal_damage":nominal, "enemy_hp_net":hp0-g.cb.enemies[0].hp, "poison_delta":Probe.poison(g.cb)-poison0, "player_hp_net":player0-g.cb.player.hp, "energy_spent":energy}})

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Expected a fresh output path")
		quit(2)
		return
	if FileAccess.file_exists(args[0]):
		push_error("Refuse overwrite")
		quit(2)
		return
	out = FileAccess.open(args[0], FileAccess.WRITE)
	if out == null:
		quit(2)
		return
	db = ContentDB.load_full()
	if not require(db.enemies.has("rootheart"), "CATALOGUE_MISSING"):
		quit(2)
		return
	for cid in ["chisel", "resonantLance", "empower", "flurry", "momentum", "strike", "venomStrike", "catalyst", "nightSight", "phantomBlades", "defend"]:
		if not require(db.cards.has(cid), "CARD_MISSING:" + cid):
			quit(2)
			return
	emit({"kind":"header", "engine":Engine.get_version_info(), "probe_sha256":FileAccess.get_sha256("res://command_probe.gd"), "candidate_sha256":FileAccess.get_sha256("res://content/full-content.json"), "scope":"CONSTRUCTED_COMMAND_FIXTURES_NOT_P9"})
	for role in PRODUCERS:
		for aspect in [0, 1]:
			for vow in [0, 5]:
				for up in [false, true]:
					for control in [false, true]:
						var n: int = (3 if vow == 0 else 4) if role == "facet" else 1
						var spec := {"role":role, "aspect":aspect, "vow":vow, "up":up, "control":control, "producers":n}
						var initial := snapshot(make_game(spec))
						fixtures += 1
						for mask in range(1 << n):
							for consumer in [false, true]:
								observe(spec, mask, consumer, false, initial)
								if failed:
									quit(3)
									return
						if role in ["fervor", "smolder"]:
							observe(spec, 1, true, true, initial)
							if failed:
								quit(3)
								return
	emit({"kind":"summary", "fixtures":fixtures, "rows":rows, "states":seen.size(), "execution_failures":int(failed)})
	out.close()
	quit(0 if not failed and fixtures == 80 and rows == 672 else 3)
