extends SceneTree
var db: ContentDB
var output: FileAccess
var mode: String
const CONTEXTS: Array[String] = ["plain", "block", "weak_vulnerable", "thorns", "lethal_enemy", "source_lethal"]

func view(v: Variant) -> Variant:
	if v is Object:
		var d: Dictionary = {}
		for prop: Dictionary in v.get_property_list():
			if (int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
				d[str(prop.name)] = view(v.get(str(prop.name)))
		return d
	if v is Dictionary:
		var d: Dictionary = {}
		for k: Variant in v:
			d[str(k)] = view(v[k])
		return d
	if v is Array:
		var a: Array = []
		for item: Variant in v:
			a.append(view(item))
		return a
	if typeof(v) == TYPE_STRING_NAME:
		return str(v)
	return v

func snapshot(g: GlassvowGame) -> Dictionary:
	return {"run": view(g.run), "combat": view(g.cb), "return": g.last_ret, "save": g.run.to_dict()}

func emit(row: Dictionary) -> void:
	output.store_line(JSON.stringify(row))
	output.flush()

func make_game(aspect: int, vow: int, context: String) -> GlassvowGame:
	var run: RunState = RunState.new_run(db, 73309001, "bloodfire-preflight", {"aspect": aspect, "vow": vow, "reveals": db.reveal_ids.duplicate(), "unlocks": ["aspect2"], "quests": {}, "shards": []})
	run.omens = [null, null, null]
	run.player.relics.clear()
	var g: GlassvowGame = GlassvowGame.new(db, run)
	if mode != "baseline":
		g.rules.set("bloodfire_enabled", mode != "off")
		g.rules.set("bloodfire_producer_enabled", mode != "producer_off")
		g.rules.set("bloodfire_consumer_enabled", mode != "consumer_off")
	g.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
	g.cb.affix = &""
	g.cb.player.statuses = {}
	g.cb.player.energy = 3
	g.cb.player.hp = 60
	g.cb.player.max_hp = 100
	g.cb.player.block = 0
	g.run.player.hp = 60
	g.run.player.max_hp = 100
	g.cb.hand.clear()
	g.cb.draw.clear()
	g.cb.discard.clear()
	g.cb.exhaust.clear()
	var e: EnemyCombatant = g.cb.enemies[0]
	e.hp = 100
	e.max_hp = 100
	e.block = 12 if context == "block" else 0
	e.chips = 0
	e.facet_max = 100
	e.statuses = {}
	e.flags = {}
	e.staggered = false
	if context == "weak_vulnerable":
		g.cb.player.statuses["weak"] = 1
		e.statuses["vulnerable"] = 1
	if context == "thorns":
		e.statuses["thorns"] = 2
	if context == "lethal_enemy":
		e.hp = 5
	if context == "source_lethal":
		g.cb.player.hp = 2
	g.cb.queue.clear()
	return g

func step(g: GlassvowGame, cmd: Dictionary) -> Dictionary:
	var before: Dictionary = snapshot(g)
	var preview: Variant = null
	if cmd.t == "playCard":
		for inst: CardInst in g.cb.hand:
			if inst.uid == int(cmd.uid):
				preview = g.rules.preview_play(g.cb, inst, cmd.get("target"), g.run)
	var after_preview: Dictionary = snapshot(g)
	var events: Array[Dictionary] = g.apply(cmd)
	return {"command": cmd, "before": before, "preview": preview, "preview_readonly": before == after_preview, "events": events, "after": snapshot(g)}

func pair(aspect: int, vow: int, up: bool, context: String) -> void:
	var g: GlassvowGame = make_game(aspect, vow, context)
	g.cb.hand.append(CardInst.new(900, &"bloodRite", up))
	g.cb.hand.append(CardInst.new(901, &"leechBlade", up))
	var a: Dictionary = step(g, {"t": "playCard", "uid": 900, "target": null})
	var erased: int = 0
	if mode == "erase_mediator":
		erased = int(g.cb.player.statuses.get("bloodfire", 0))
		g.cb.player.statuses.erase("bloodfire")
	var b: Dictionary = step(g, {"t": "playCard", "uid": 901, "target": 0})
	emit({"kind": "pair", "mode": mode, "aspect": aspect, "vow": vow, "up": up, "context": context, "erased_mediator": erased, "steps": [a, b]})

func lifecycle(aspect: int, vow: int, up: bool) -> void:
	var g: GlassvowGame = make_game(aspect, vow, "plain")
	g.cb.hand.append(CardInst.new(900, &"bloodRite", up))
	g.cb.hand.append(CardInst.new(901, &"bloodRite", up))
	g.cb.hand.append(CardInst.new(902, &"leechBlade", up))
	g.cb.hand.append(CardInst.new(903, &"leechBlade", up))
	var steps: Array = []
	steps.append(step(g, {"t": "playCard", "uid": 900, "target": null}))
	steps.append(step(g, {"t": "playCard", "uid": 901, "target": null}))
	steps.append(step(g, {"t": "playCard", "uid": 902, "target": 0}))
	steps.append(step(g, {"t": "playCard", "uid": 903, "target": 0}))
	# Explicit stock tests expiry only; it is not a natural producer witness.
	g.cb.player.statuses["bloodfire"] = 1
	steps.append(step(g, {"t": "endTurn"}))
	steps.append(step(g, {"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"}))
	emit({"kind": "lifecycle", "mode": mode, "aspect": aspect, "vow": vow, "up": up, "steps": steps})

func legality(aspect: int, vow: int) -> void:
	var g: GlassvowGame = make_game(aspect, vow, "plain")
	g.cb.hand.append(CardInst.new(900, &"leechBlade"))
	g.cb.player.energy = 1
	g.cb.player.statuses["bloodfire"] = 1
	var a: Dictionary = step(g, {"t": "playCard", "uid": 900, "target": 0})
	g.cb.player.energy = 2
	var b: Dictionary = step(g, {"t": "playCard", "uid": 900, "target": 0})
	emit({"kind": "legality", "mode": mode, "aspect": aspect, "vow": vow, "steps": [a, b]})

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	mode = args[0]
	db = ContentDB.load_full(true)
	if db == null:
		quit(2)
		return
	output = FileAccess.open(args[1], FileAccess.WRITE)
	if output == null:
		quit(2)
		return
	emit({"kind": "manifest", "mode": mode, "engine": Engine.get_version_info()["string"], "content_sha256": FileAccess.get_sha256("res://content/full-content.json"), "combat_sha256": FileAccess.get_sha256("res://domain/rules/combat.gd"), "probe_sha256": FileAccess.get_sha256("res://probe.gd"), "constructed_not_independent": true})
	for aspect: int in [0, 1]:
		for vow: int in [0, 5]:
			for up: bool in [false, true]:
				for context: String in CONTEXTS:
					pair(aspect, vow, up, context)
				lifecycle(aspect, vow, up)
			legality(aspect, vow)
	emit({"kind": "terminal", "cases": 60})
	output.close()
	quit(0)
