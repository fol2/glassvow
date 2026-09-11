extends "res://causal_probe.gd"
## Finite instrument qualification, not a build/combat policy or value campaign.
const SCENARIOS: Array[String] = ["spend_one", "unrelated_play", "wait_turn", "repeat_consumer"]

func temporal_game(aspect: int, vow: int, up: bool, scenario: String, arm: int) -> GlassvowGame:
	var g: GlassvowGame = make_game(aspect, vow, up, "available", -1 if arm < 0 else arm + 4)
	g.cb.draw.clear()
	for i: int in range(16):
		g.cb.draw.append(CardInst.new(950 + i, &"defend", false))
	if scenario == "wait_turn":
		g.cb.hand.remove_at(1)
		# In all worlds the next normal five-card draw includes this consumer.
		g.cb.draw[13] = CardInst.new(901, &"phantomBlades", up)
	if scenario == "repeat_consumer":
		g.cb.hand.append(CardInst.new(902, &"phantomBlades", up))
	g.run.player.deck.clear()
	for pile: Array[CardInst] in [g.cb.hand, g.cb.draw]:
		for inst: CardInst in pile:
			g.run.player.deck.append(CardInst.new(inst.uid, inst.id, inst.up))
	g.cb.enemies[0].hp = 500
	g.cb.enemies[0].max_hp = 500
	g.cb.enemies[0].facet_max = 500
	return g

func temporal_case(aspect: int, vow: int, up: bool, scenario: String, arm: int) -> void:
	var g: GlassvowGame = temporal_game(aspect, vow, up, scenario, arm)
	var start: Dictionary = snapshot(g)
	var steps: Array = [execute(g, {"t":"playCard", "uid":900, "target":null})]
	var drawn: Array[int] = []
	for event: Dictionary in steps[0]["events"]:
		if event.get("t") == "draw":
			drawn.append(int(event["uid"]))
	# The legal adaptive rule is declared before observations. An absent card is
	# not played or replaced. These are not fixed-command cross-world contrasts.
	if scenario == "spend_one" and not drawn.is_empty():
		steps.append(execute(g, {"t":"playCard", "uid":drawn[0], "target":null}))
	elif scenario == "spend_all":
		for uid: int in drawn:
			steps.append(execute(g, {"t":"playCard", "uid":uid, "target":null}))
	elif scenario == "unrelated_play":
		steps.append(execute(g, {"t":"playCard", "uid":920, "target":0}))
	elif scenario == "wait_turn":
		steps.append(execute(g, {"t":"endTurn"}))
	var consumers: Array[int] = [901, 902] if scenario == "repeat_consumer" else [901]
	for uid: int in consumers:
		if arm >= 0:
			g.rules.set("consumer_uid", uid)
		steps.append(execute(g, {"t":"playCard", "uid":uid, "target":0}))
	emit({"kind":"temporal", "source":source, "aspect":aspect, "vow":vow,
		"up":up, "scenario":scenario, "arm":arm, "start":start, "steps":steps,
		"end":snapshot(g)})

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2);return
	db = ContentDB.load_full(true)
	output = FileAccess.open(args[0], FileAccess.WRITE)
	if db == null or output == null:
		quit(2);return
	output.store_line(JSON.stringify({"kind":"header", "engine":Engine.get_version_info()["string"],
		"content_sha256":FileAccess.get_sha256("res://content/full-content.json"),
		"combat_sha256":FileAccess.get_sha256("res://domain/rules/combat.gd"),
		"instrument_sha256":FileAccess.get_sha256("res://causal_rules.gd"),
		"probe_sha256":FileAccess.get_sha256("res://temporal_probe.gd"),
		"base_probe_sha256":FileAccess.get_sha256("res://causal_probe.gd"),
		"is_constructed":true, "new_population_runs":0}))
	for id: String in ["preparation", "surge"]:
		source = id
		var scenarios: Array[String] = SCENARIOS.duplicate()
		if source == "preparation":
			scenarios.append("spend_all")
		for aspect: int in [0, 1]:
			for vow: int in [0, 5]:
				for up: bool in [false, true]:
					for scenario: String in scenarios:
						for arm: int in [-1, 0, 1, 2, 3]:
							temporal_case(aspect, vow, up, scenario, arm)
	output.store_line(JSON.stringify({"kind":"terminal", "rows":records}))
	output.close()
	quit(0)
