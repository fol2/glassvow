extends SceneTree
## Finite distinguishing traces and loop-expansion regression; not P9 samples.
const FullState = preload("res://causal_probe.gd")
const Expanded = preload("res://expanded_rules.gd")
var db: ContentDB
var output: FileAccess
var rows: int = 0
var failed: bool = false

func emit(value: Dictionary) -> void:
	output.store_line(JSON.stringify(value))
	output.flush()

func require(ok: bool, reason: String) -> void:
	if not ok:
		failed = true
		push_error("COMPOSITION_PROBE " + reason)

func state(g: GlassvowGame) -> Dictionary:
	return {"future":FullState.projection([g.run, g.cb, g.last_ret], {}), "queue":g.cb.queue.duplicate(true)}

func view(g: GlassvowGame) -> Dictionary:
	var e: EnemyCombatant = g.cb.enemies[0]
	var hand: Array = []
	for card: CardInst in g.cb.hand:
		hand.append(card.uid)
	return {"hp":e.hp,"block":e.block,"chips":e.chips,"facet_max":e.facet_max,
		"staggered":e.staggered,"cracked":int(e.statuses.get("vulnerable",0)),
		"weak":int(e.statuses.get("weak",0)),"energy":g.cb.player.energy,
		"over":g.cb.over,"hand":hand,"rng":g.run.rng.get_state()}

func make_game(spec: Dictionary) -> GlassvowGame:
	var run := RunState.new_run(db, 48080001, "composition-fixture", {"aspect":spec.aspect,
		"vow":spec.vow,"reveals":db.reveal_ids.duplicate(),"unlocks":["aspect2"],"quests":{},"shards":[]})
	run.omens = [null,null,null]
	run.player.relics.clear()
	var g := GlassvowGame.new(db,run)
	g.apply({"t":"startCombat","enemies":["rootheart"],"kind":"boss","affix":null})
	# One declared initial boundary. No between-command mutation or Block reset.
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
	if spec.kind == "facet":
		var names: Array = ["chisel","eclipseSlash","warCry","resonantLance"]
		for i: int in range(names.size()):
			g.cb.hand.append(CardInst.new(900+i,StringName(names[i]),spec.up))
		if spec.environment == "two_short":
			g.cb.enemies[0].chips = g.cb.enemies[0].facet_max - 2
	else:
		var inst := CardInst.new(900,&"momentum",spec.up)
		if spec.environment in ["lethal","thorns"]:
			inst.bonus = 14
		g.cb.hand.append(inst)
		if spec.environment == "stock":
			g.cb.draw.append(CardInst.new(1000,&"defend",false))
		elif spec.environment == "reshuffle":
			g.cb.discard.append(CardInst.new(1000,&"defend",false))
			g.cb.discard.append(CardInst.new(1001,&"strike",false))
		elif spec.environment == "lethal":
			g.cb.enemies[0].hp = 1
			g.cb.draw.append(CardInst.new(1000,&"defend",false))
		elif spec.environment == "thorns":
			g.cb.player.hp = 1
			g.cb.enemies[0].statuses["thorns"] = 2
			g.cb.draw.append(CardInst.new(1000,&"defend",false))
	for c: CardInst in g.cb.hand + g.cb.draw + g.cb.discard:
		g.run.player.deck.append(c.combat_copy())
	return g

func step(g: GlassvowGame, cmd: Dictionary) -> Dictionary:
	var before: Dictionary = state(g)
	var q: Array = g.cb.queue.duplicate(true)
	var events: Array = g.apply(cmd)
	require(g.cb.queue.slice(0,q.size()) == q,"APPEND_ONLY_QUEUE")
	return {"cmd":cmd,"before":before,"after":state(g),"events":events,"ret":g.last_ret,"view":view(g)}

func facet(spec: Dictionary, index: int) -> void:
	var g := make_game(spec)
	var first := {"t":"playCard","uid":900+index,"target":null if index==2 else 0}
	var producer := step(g,first)
	require(producer.ret == true,"ILLEGAL_PRODUCER")
	var consumer := step(g,{"t":"playCard","uid":903,"target":0})
	require(consumer.ret == true,"ILLEGAL_CONSUMER")
	var reset := step(g,{"t":"endTurn"})
	rows += 1
	emit({"kind":"facet","spec":spec,"producer":index,"steps":[producer,consumer,reset]})

func cycle(spec: Dictionary, expanded: bool) -> void:
	var g := make_game(spec)
	if expanded:
		g.rules = Expanded.new(db)
	var first := step(g,{"t":"playCard","uid":900,"target":0})
	require(first.ret == true,"ILLEGAL_GROWTH")
	var steps: Array = [first]
	if not g.cb.over:
		steps.append(step(g,{"t":"endTurn"}))
	rows += 1
	emit({"kind":"cycle","spec":spec,"expanded":expanded,"steps":steps})

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or FileAccess.file_exists(args[0]):
		quit(2)
		return
	output = FileAccess.open(args[0],FileAccess.WRITE)
	if output == null:
		quit(2)
		return
	db = ContentDB.load_full()
	emit({"kind":"header","scope":"CONSTRUCTED_FORMAL_COUNTEREXAMPLES_NOT_POPULATION",
		"engine":Engine.get_version_info(),"content_sha256":FileAccess.get_sha256("res://content/full-content.json"),
		"probe_sha256":FileAccess.get_sha256("res://probe.gd"),"expanded_sha256":FileAccess.get_sha256("res://expanded_rules.gd")})
	for aspect: int in [0,1]:
		for vow: int in [0,5]:
			for up: bool in [false,true]:
				for environment: String in ["fresh","two_short"]:
					var spec := {"kind":"facet","aspect":aspect,"vow":vow,"up":up,"environment":environment}
					for index: int in range(3):
						facet(spec,index)
				for environment: String in ["empty","stock","reshuffle","lethal","thorns"]:
					var spec := {"kind":"cycle","aspect":aspect,"vow":vow,"up":up,"environment":environment}
					cycle(spec,false)
					cycle(spec,true)
	emit({"kind":"summary","rows":rows,"failed":failed})
	output.close()
	quit(0 if rows==128 and not failed else 3)
