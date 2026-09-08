extends SceneTree
## Finite source-specific Hand measurement gate, not policy/population admission.
const Observe = preload("res://causal_probe.gd")
const HandRules = preload("res://hand_rules.gd")
const Health = preload("res://health_accounting.gd")
var db: ContentDB
var output: FileAccess
var emitted: Dictionary = {}
var rows: int = 0
var failed: bool = false

func emit(record: Dictionary) -> void:
	output.store_line(JSON.stringify(record))
	output.flush()

func require(ok: bool, why: String) -> void:
	if not ok:
		failed = true
		push_error("HAND_PREFLIGHT " + why)

func snap(g: GlassvowGame) -> String:
	var text: String = JSON.stringify({"future":Observe.projection([g.run,g.cb,g.last_ret],{}),
		"queue":g.cb.queue})
	var digest: String = text.sha256_text()
	if not emitted.has(digest):
		emitted[digest] = true
		emit({"kind":"state","sha256":digest,"serialized":text})
	return digest

func hand_uids(g: GlassvowGame) -> Array:
	var result: Array = []
	for card: CardInst in g.cb.hand:
		result.append(card.uid)
	return result

func view(g: GlassvowGame) -> Dictionary:
	return {"hand":hand_uids(g),"energy":g.cb.player.energy,"turn":g.cb.turn,
		"hp":g.cb.enemies[0].hp,"block":g.cb.enemies[0].block,"over":g.cb.over,
		"rng":g.run.rng.get_state(),"player_hp":g.cb.player.hp}

func setup(spec: Dictionary, mask: int) -> GlassvowGame:
	var run := RunState.new_run(db,49080001,"hand-admission-preflight",{
		"aspect":spec.aspect,"vow":spec.vow,"reveals":db.reveal_ids.duplicate(),
		"unlocks":["aspect2"],"quests":{},"shards":[]})
	run.omens = [null,null,null]
	run.player.relics.clear()
	var g := GlassvowGame.new(db,run)
	g.apply({"t":"startCombat","enemies":["rootheart"],"kind":"boss","affix":null})
	# One declared constructed initial boundary; no edits between commands.
	g.cb.player.statuses = {}
	g.cb.player.block = 0
	g.cb.enemies[0].statuses = {}
	g.cb.enemies[0].block = 0
	g.cb.hand.clear(); g.cb.draw.clear(); g.cb.discard.clear(); g.cb.exhaust.clear()
	g.run.player.deck.clear(); g.cb.queue.clear()
	g.cb.player.energy = int(spec.energy)
	var access: bool = spec.label == "surge_access"
	if spec.producer != "":
		g.cb.hand.append(CardInst.new(900,StringName(spec.producer),spec.up))
	if not access:
		g.cb.hand.append(CardInst.new(901,&"phantomBlades",spec.up))
	var next_uid: int = 1000
	while g.cb.hand.size() < int(spec.hand):
		g.cb.hand.append(CardInst.new(next_uid,&"defend",false)); next_uid += 1
	for i: int in range(int(spec.draw)):
		g.cb.draw.append(CardInst.new(next_uid,&"defend",false)); next_uid += 1
	if access:
		g.cb.draw.append(CardInst.new(901,&"phantomBlades",spec.up))
	if spec.label.ends_with("branch"):
		g.run.player.relics.append(&"verdantBranch")
	if spec.label == "prep_modifiers":
		g.cb.player.statuses = {"str":2,"weak":1}
		g.cb.enemies[0].statuses = {"vulnerable":2,"thorns":2}
		g.cb.enemies[0].block = 5
	if spec.label == "prep_lethal":
		g.cb.enemies[0].hp = 3
	for card: CardInst in g.cb.hand + g.cb.draw:
		g.run.player.deck.append(card.combat_copy())
	if mask >= 0:
		g.rules = HandRules.new(db)
		g.rules.intervention_mask = mask
	return g

func step(g: GlassvowGame, command: Dictionary, mask: int) -> Dictionary:
	var before: String = snap(g)
	var before_view: Dictionary = view(g)
	var queue: Array = g.cb.queue.duplicate(true)
	var health_before: Dictionary = Health.snapshot(g.cb)
	var events: Array = []
	var observations: Array = []
	var permitted: bool = not g.cb.over
	if command.t == "playCard":
		var card: CardInst = Observe.find_card(g,int(command.uid))
		permitted = permitted and card != null
		if permitted:
			permitted = g.rules.can_play(g.run,g.cb,card,command.get("target"))
	if permitted:
		if mask >= 0:
			g.rules.effect_observations.clear()
		events = g.apply(command)
		if mask >= 0:
			observations = g.rules.effect_observations.duplicate(true)
		if command.t == "playCard":
			require(g.last_ret == true,"LEGALITY_MISMATCH")
	else:
		# An unavailable consumer is a measured blocked opportunity, not a fake play.
		require(snap(g) == before,"BLOCKED_ATTEMPT_MUTATED_STATE")
	var folded: Dictionary = Health.fold(health_before,events,Health.snapshot(g.cb))
	require(folded.get("ok",false),"HEALTH_ACCOUNTING")
	require(g.cb.queue.slice(0,queue.size()) == queue,"PAST_QUEUE_CHANGED")
	return {"command":command,"permitted":permitted,"before":before,"after":snap(g),
		"before_view":before_view,"after_view":view(g),"events":events,
		"last_ret":g.last_ret,"health":folded,"observations":observations}

func capture(spec: Dictionary, mask: int) -> void:
	var g: GlassvowGame = setup(spec,mask)
	var initial: String = snap(g)
	var steps: Array = []
	if spec.producer != "":
		steps.append(step(g,{"t":"playCard","uid":900,"target":null},mask))
	steps.append(step(g,{"t":"playCard","uid":901,"target":0},mask))
	steps.append(step(g,{"t":"endTurn"},mask))
	var previous: String = initial
	for item: Dictionary in steps:
		require(item.before == previous,"HIDDEN_INTERSTEP_MUTATION")
		previous = item.after
	rows += 1
	emit({"kind":"row","spec":spec,"mask":mask,"initial":initial,"steps":steps})

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or FileAccess.file_exists(args[0]):
		quit(2); return
	output = FileAccess.open(args[0],FileAccess.WRITE)
	if output == null:
		quit(2); return
	db = ContentDB.load_full()
	emit({"kind":"header","engine":Engine.get_version_info(),
		"content_sha256":FileAccess.get_sha256("res://content/full-content.json"),
		"combat_sha256":FileAccess.get_sha256("res://domain/rules/combat.gd"),
		"rules_sha256":FileAccess.get_sha256("res://hand_rules.gd"),
		"probe_sha256":FileAccess.get_sha256("res://preflight.gd"),
		"scope":"HAND_MEASUREMENT_PREFLIGHT_NOT_POPULATION_OR_PACKAGE_PASS"})
	var cases: Array = [
		["prep_stock","preparation",5,3,12], ["prep_empty","preparation",5,3,0],
		["prep_cap","preparation",10,3,12], ["prep_branch","preparation",5,3,12],
		["prep_modifiers","preparation",5,3,12], ["prep_lethal","preparation",5,3,12],
		["surge_energy","surge",6,0,12], ["surge_access","surge",6,0,12],
		["surge_empty","surge",6,0,0], ["surge_branch","surge",6,0,12],
		["surge_spare","surge",6,3,12]]
	for aspect: int in [0,1]:
		for vow: int in [0,5]:
			for up: bool in [false,true]:
				for item: Array in cases:
					var spec := {"aspect":aspect,"vow":vow,"up":up,"label":item[0],
						"producer":item[1],"hand":item[2],"energy":item[3],"draw":item[4]}
					for mask: int in range(-1,8):
						capture(spec,mask)
						if failed:
							quit(3); return
				for q: int in range(10):
					var spec := {"aspect":aspect,"vow":vow,"up":up,"label":"q_"+str(q),
						"producer":"","hand":q+1,"energy":3,"draw":12}
					for mask: int in [-1,0,4]:
						capture(spec,mask)
						if failed:
							quit(3); return
	emit({"kind":"summary","rows":rows,"states":emitted.size(),"execution_failures":int(failed)})
	output.close()
	quit(0 if rows == 1032 and not failed else 3)
