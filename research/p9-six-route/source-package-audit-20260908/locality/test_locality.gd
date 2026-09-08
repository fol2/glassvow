extends "res://test_package_nulls.gd"
## Finite controlled state-dependency witnesses. No population inference.
const CASES: Array[Dictionary] = [
	{"aspect":0,"route":"facet","card":"resonantLance"},
	{"aspect":0,"route":"fervor","card":"flurry"},
	{"aspect":0,"route":"cycle","card":"momentum"},
	{"aspect":1,"route":"smolder","card":"catalyst"},
	{"aspect":1,"route":"hand","card":"phantomBlades"},
	{"aspect":1,"route":"cycle","card":"momentum"}
]
const OPS: Array[String] = ["baseline","target_reset","copy_reset","hand_trim","strength_reset"]

func locality_measure(spec: Dictionary, up: bool, op: String) -> Dictionary:
	var g: GlassvowGame = make_game(int(spec.aspect))
	var inst: CardInst = CardInst.new(900, StringName(spec.card), up)
	inst.bonus = 17 if up else 14
	if op == "copy_reset":
		inst = inst.combat_copy()
	g.cb.hand.append(inst)
	for j: int in range(4 if op == "hand_trim" else 6):
		g.cb.hand.append(CardInst.new(1000+j, &"defend"))
	g.cb.player.statuses["str"] = 0 if op == "strength_reset" else 3
	g.cb.enemies[0].staggered = op != "target_reset"
	g.cb.enemies[0].statuses["poison"] = 0 if op == "target_reset" else 4
	# These are controlled states, not claims of legal acquisition/history.
	var before: Array = [g.run.to_dict(),g.cb.to_dict()]
	var hp: int = g.cb.enemies[0].hp
	var poison: int = int(g.cb.enemies[0].statuses.get("poison",0))
	var events: Array[Dictionary] = g.apply({"t":"playCard","uid":900,"target":0})
	ck(g.last_ret == true, "controlled consumer legal")
	return {"kind":"locality","aspect":spec.aspect,"route":spec.route,"up":up,"op":op,
		"before":before,"after":[g.run.to_dict(),g.cb.to_dict()],"ret":g.last_ret,"events":events,
		"hp_removed":hp-g.cb.enemies[0].hp,"poison_added":int(g.cb.enemies[0].statuses.get("poison",0))-poison}

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	db = ContentDB.load_from(args[0],true)
	if db == null:
		quit(2)
		return
	output = FileAccess.open(args[1],FileAccess.WRITE)
	if output == null:
		quit(2)
		return
	emit({"kind":"manifest","engine":Engine.get_version_info()["string"],
		"content_sha256":FileAccess.get_sha256(args[0]),
		"script_sha256":FileAccess.get_sha256("res://test_locality.gd"),
		"fixture_sha256":FileAccess.get_sha256("res://test_package_nulls.gd"),
		"combat_sha256":FileAccess.get_sha256("res://domain/rules/combat.gd"),
		"scope":"60 fixed constructed state edits; not independent trials or canonical admission"})
	for spec: Dictionary in CASES:
		for up: bool in [false,true]:
			for op: String in OPS:
				emit(locality_measure(spec,up,op))
	emit({"kind":"summary","checks":checks,"failures":failures})
	output.close()
	print("LOCALITY_CHECKS %d FAILURES %d" % [checks,failures])
	quit(0 if failures == 0 else 3)
