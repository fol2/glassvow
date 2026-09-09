extends SceneTree
const Roles = preload("res://roles.gd")
var db: ContentDB
var output: FileAccess
var contract: Dictionary

func projection(v: Variant, memo: Dictionary) -> Variant:
	if v is Rng:
		return {"rng_state":v.get_state()}
	if v is RefCounted:
		var id: int = v.get_instance_id()
		if memo.has(id):
			return {"ref":memo[id]}
		var d: Dictionary = {"object":memo.size()}
		memo[id] = memo.size()
		for p: Dictionary in v.get_property_list():
			if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				d[str(p.name)] = projection(v.get(p.name), memo)
		return d
	if v is Array:
		var arr: Array = []
		for x: Variant in v:
			arr.append(projection(x, memo))
		return arr
	if v is Dictionary:
		var d: Dictionary = {}
		for k: Variant in v:
			d[k] = projection(v[k], memo)
		return d
	return v

func state(g: GlassvowGame) -> Dictionary:
	var targets: Array = []
	for e: EnemyCombatant in g.cb.enemies:
		targets.append({"idx":e.idx,"hp":e.hp,"block":e.block,"statuses":e.statuses.duplicate(),"chips":e.chips,"staggered":e.staggered,"facet_max":e.facet_max})
	var hand: Array = []
	for c: CardInst in g.cb.hand:
		hand.append({"uid":c.uid,"id":String(c.id),"up":c.up})
	return {"full":projection([g.run,g.cb,g.last_ret],{}),"view":{"energy":g.cb.player.energy,"player_hp":g.cb.player.hp,"statuses":g.cb.player.statuses.duplicate(),"hand":hand,"targets":targets,"turn":g.cb.turn,"over":g.cb.over,"embers":g.cb.embers,"attacks":g.cb.counters_attacks,"played":g.cb.counters_played,"exhaust_uids":g.cb.exhaust.map(func(c: CardInst) -> int: return c.uid),"discard_uids":g.cb.discard.map(func(c: CardInst) -> int: return c.uid)}}

func construct(cfg: Dictionary) -> GlassvowGame:
	var run: RunState = RunState.new_run(db, 73109001, "minimal-native-contract", {"aspect":cfg.aspect,"vow":cfg.vow,"reveals":db.reveal_ids.duplicate(),"unlocks":["aspect2"],"quests":{},"shards":[]})
	run.omens = [null,null,null]
	run.player.relics.clear()
	if cfg.context == "exhaust_hook":
		run.player.relics.append("verdantBranch")
	var g: GlassvowGame = GlassvowGame.new(db,run)
	g.apply({"t":"startCombat","enemies":["sporeling","sporeling"],"kind":"normal"})
	g.cb.player.statuses = {}
	g.cb.player.energy = 8
	g.cb.player.hp = 100
	g.cb.player.max_hp = 100
	g.cb.player.block = 0
	g.cb.hand.clear(); g.cb.draw.clear(); g.cb.discard.clear(); g.cb.exhaust.clear()
	g.cb.embers = 0
	g.cb.counters_attacks = 0; g.cb.counters_played = 0; g.cb.first_card_played = false
	for e: EnemyCombatant in g.cb.enemies:
		e.hp = 100; e.max_hp = 100; e.block = 0; e.statuses = {}; e.chips = 0; e.staggered = false
		e.facet_max = 100; e.flags = {}
	var source: StringName = &"empower" if cfg.family == "fervor" else &"venomStrike"
	var sink: StringName = &"flurry" if cfg.family == "fervor" else &"catalyst"
	g.cb.hand.append(CardInst.new(900,source,cfg.up))
	g.cb.hand.append(CardInst.new(901,sink,cfg.up))
	g.cb.hand.append(CardInst.new(902,sink,cfg.up))
	g.cb.hand.append(CardInst.new(903,source,cfg.up))
	g.cb.draw.append(CardInst.new(904,&"defend",false))
	if cfg.context == "block": g.cb.enemies[0].block = 9
	if cfg.context == "rounding":
		g.cb.player.statuses["weak"] = 1; g.cb.enemies[0].statuses["vulnerable"] = 1
	if cfg.context == "thorns": g.cb.enemies[0].statuses["thorns"] = 2
	if cfg.context == "lethal": g.cb.enemies[0].hp = 3
	if cfg.context == "background":
		g.cb.player.statuses["str"] = 3; g.cb.enemies[0].statuses["poison"] = 3
	if cfg.context == "energy_blocked": g.cb.player.energy = 1
	if cfg.context == "shatter": g.cb.enemies[0].facet_max = 1
	g.cb.queue.clear()
	if cfg.mask >= 0:
		g.rules = Roles.new(db); g.rules.family = cfg.family; g.rules.mask = cfg.mask
	return g

func sequence(cfg: Dictionary) -> Array:
	var src_target: Variant = null if cfg.family == "fervor" else 0
	var commands: Array = []
	if cfg.context != "dormant": commands.append({"t":"playCard","uid":900,"target":src_target})
	if cfg.context == "stacked": commands.append({"t":"playCard","uid":903,"target":src_target})
	commands.append({"t":"playCard","uid":901,"target":1 if cfg.context == "retarget" else 0})
	if cfg.context == "repeat": commands.append({"t":"playCard","uid":902,"target":0})
	commands.append({"t":"endTurn"})
	return commands

func capture(cfg: Dictionary) -> void:
	var g: GlassvowGame = construct(cfg)
	var start: Dictionary = state(g)
	var steps: Array = []
	var complete: bool = true
	for cmd: Dictionary in sequence(cfg):
		var before: Dictionary = state(g)
		var permitted: bool = not g.cb.over
		if cmd.t == "playCard":
			var found: CardInst = null
			for c: CardInst in g.cb.hand:
				if c.uid == cmd.uid: found = c
			permitted = permitted and found != null and g.rules.can_play(g.run,g.cb,found,cmd.target)
		if not permitted:
			steps.append({"command":cmd,"permitted":false,"before":before,"after":before,"events":[]})
			complete = false
			break
		var events: Array[Dictionary] = g.apply(cmd)
		steps.append({"command":cmd,"permitted":true,"before":before,"after":state(g),"events":events,"ret":g.last_ret})
	var pool: Dictionary = {}
	for tier: String in ["common","uncommon","rare"]: pool[tier] = g.rewards.card_pool(g.run,tier)
	var before_reset: Dictionary = state(g)
	g.apply({"t":"startCombat","enemies":["sporeling"],"kind":"normal"})
	output.store_line(JSON.stringify({"kind":"case","config":cfg,"initial":start,"steps":steps,"complete":complete,"before_reset":before_reset,"after_reset":state(g),"pools":pool}))
	output.flush()

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or FileAccess.file_exists(args[1]): quit(2); return
	contract = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	db = ContentDB.load_from("res://content/full-content.json",true)
	output = FileAccess.open(args[1],FileAccess.WRITE)
	if db == null or output == null: quit(2); return
	output.store_line(JSON.stringify({"kind":"header","engine":Engine.get_version_info()["string"],"content_sha256":FileAccess.get_sha256("res://content/full-content.json"),"combat_sha256":FileAccess.get_sha256("res://domain/rules/combat.gd"),"probe_sha256":FileAccess.get_sha256("res://probe.gd"),"roles_sha256":FileAccess.get_sha256("res://roles.gd"),"contract_sha256":FileAccess.get_sha256(args[0])}))
	for family: String in contract.families:
		for aspect: int in [0,1]:
			for vow: int in [0,5]:
				for up: bool in [false,true]:
					for context: String in contract.contexts:
						for mask: int in [-1,0,1,2,3]:
							capture({"family":family,"aspect":aspect,"vow":vow,"up":up,"context":context,"mask":mask})
	output.close(); quit(0)
