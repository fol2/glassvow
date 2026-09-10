extends SceneTree
## New question: separate existing source-card Energy utility from mediator payoff.
## This is not a re-execution or extension of a prior population/preflight panel.
const Instrument: GDScript = preload("res://causal_rules.gd")
const CONTEXTS: Array[String] = ["available", "no_energy", "hand_cap", "empty_draw",
	"shuffle", "blocked", "already_lethal", "source_fatal"]
var db: ContentDB
var output: FileAccess
var source: String
var records: int = 0

func view(v: Variant) -> Variant:
	if v is Object:
		var d: Dictionary = {}
		for prop: Dictionary in v.get_property_list():
			if (int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
				d[str(prop.name)] = view(v.get(str(prop.name)))
		return d
	if v is Dictionary:
		var d: Dictionary = {}
		for key: Variant in v:
			d[str(key)] = view(v[key])
		return d
	if v is Array:
		var a: Array = []
		for item: Variant in v:
			a.append(view(item))
		return a
	return str(v) if typeof(v) == TYPE_STRING_NAME else v

func snapshot(g: GlassvowGame) -> Dictionary:
	return {"run":view(g.run), "combat":view(g.cb), "return":view(g.last_ret),
		"save":g.run.to_dict()}

func make_game(aspect: int, vow: int, up: bool, context: String,
		arm: int) -> GlassvowGame:
	var run: RunState = RunState.new_run(db, 73416010, "p9-utility-mediated-factorial",
		{"aspect":aspect, "vow":vow, "reveals":db.reveal_ids.duplicate(),
		 "unlocks":["aspect2"], "quests":{}, "shards":[]})
	run.omens = [null, null, null]
	run.player.relics.clear()
	var g: GlassvowGame = GlassvowGame.new(db, run)
	if arm >= 0:
		g.rules = Instrument.new(db)
		g.rules.configure(source, (arm & 4) != 0, (arm & 2) != 0, (arm & 1) != 0)
	g.apply({"t":"startCombat", "enemies":["sporeling"], "kind":"normal"})
	g.cb.affix = &""
	g.cb.player.statuses = {}
	g.cb.player.energy = 0 if context == "no_energy" else 3
	g.cb.player.hp = 2 if context == "source_fatal" else 60
	g.cb.player.max_hp = 100
	g.cb.player.block = 0
	g.run.player.hp = g.cb.player.hp
	g.run.player.max_hp = 100
	g.cb.hand.clear()
	g.cb.draw.clear()
	g.cb.discard.clear()
	g.cb.exhaust.clear()
	g.run.player.deck.clear()
	g.cb.hand.append(CardInst.new(900, StringName(source), up))
	g.cb.hand.append(CardInst.new(901, &"leechBlade" if source == "bloodRite" else &"phantomBlades", up))
	var fillers: int = 8 if context == "hand_cap" else 2
	for i: int in range(fillers):
		g.cb.hand.append(CardInst.new(920+i, &"strike", false))
	if context != "empty_draw":
		for i: int in range(6):
			var inst: CardInst = CardInst.new(950+i, &"defend", false)
			if context == "shuffle":g.cb.discard.append(inst)
			else:g.cb.draw.append(inst)
	for pile: Array[CardInst] in [g.cb.hand, g.cb.draw, g.cb.discard]:
		for inst: CardInst in pile:
			g.run.player.deck.append(CardInst.new(inst.uid, inst.id, inst.up))
	var e: EnemyCombatant = g.cb.enemies[0]
	e.hp = 5 if context == "already_lethal" else 100
	e.max_hp = 100
	e.block = 50 if context == "blocked" else 0
	e.chips = 0
	e.facet_max = 100
	e.statuses = {}
	e.flags = {}
	e.staggered = false
	g.cb.queue.clear()
	return g

func execute(g: GlassvowGame, cmd: Dictionary) -> Dictionary:
	var before: Dictionary = snapshot(g)
	var events: Array[Dictionary] = g.apply(cmd)
	return {"command":cmd, "before":before, "events":events,
		"after":snapshot(g), "ret":g.last_ret}

func emit(row: Dictionary) -> void:
	output.store_line(JSON.stringify(row))
	records += 1

func run_case(aspect: int, vow: int, up: bool, context: String, arm: int) -> void:
	var g: GlassvowGame = make_game(aspect, vow, up, context, arm)
	var before: Dictionary = snapshot(g)
	var source_step: Dictionary = execute(g, {"t":"playCard", "uid":900, "target":null})
	var consumer_step: Dictionary = execute(g, {"t":"playCard", "uid":901, "target":0})
	emit({"kind":"sequence", "source":source, "aspect":aspect, "vow":vow,
		"up":up, "context":context, "arm":arm, "start":before,
		"steps":[source_step,consumer_step], "end":snapshot(g)})

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["bloodRite", "preparation", "surge"]:
		quit(2);return
	source = args[0]
	db = ContentDB.load_full(true)
	output = FileAccess.open(args[1], FileAccess.WRITE)
	if db == null or output == null:
		quit(2);return
	output.store_line(JSON.stringify({"kind":"header", "source":source,
		"engine":Engine.get_version_info()["string"],
		"content_sha256":FileAccess.get_sha256("res://content/full-content.json"),
		"combat_sha256":FileAccess.get_sha256("res://domain/rules/combat.gd"),
		"instrument_sha256":FileAccess.get_sha256("res://causal_rules.gd"),
		"probe_sha256":FileAccess.get_sha256("res://causal_probe.gd"),
		"native_population_runs":0, "is_constructed":true}))
	for aspect: int in [0,1]:
		for vow: int in [0,5]:
			for up: bool in [false,true]:
				for context: String in CONTEXTS:
					# -1 is the original minimum runtime, not the intervention subclass.
					for arm: int in [-1,0,1,2,3,4,5,6,7]:
						run_case(aspect,vow,up,context,arm)
	output.store_line(JSON.stringify({"kind":"terminal", "rows":records}))
	output.close()
	quit(0)
