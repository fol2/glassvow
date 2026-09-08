extends SceneTree
const Legacy: GDScript = preload("res://diagnostic_legacy.gd")
const Selective: GDScript = preload("res://selective_fervor.gd")
var db: ContentDB
var checks: int = 0
var failures: int = 0
var output: FileAccess
var legacy_mismatches: int = 0
var fixed_mismatches: int = 0
const ROLE_CARDS: Dictionary = {"multihit":"flurry", "growth":"momentum", "handstock":"phantomBlades", "catalyst":"catalyst", "echo":"resonantLance"}

func ck(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("PACKAGE_NULL " + note)

func emit(row: Dictionary) -> void:
	output.store_line(JSON.stringify(row))
	output.flush()

func make_game(aspect: int) -> GlassvowGame:
	var run: RunState = RunState.new_run(db, 46000001, "null-fixture", {"aspect":aspect,"vow":0,"reveals":db.reveal_ids.duplicate(),"unlocks":["aspect2"],"quests":{},"shards":[]})
	run.omens = [null, null, null]
	run.player.relics.clear()
	var g: GlassvowGame = GlassvowGame.new(db, run)
	g.apply({"t":"startCombat","enemies":["sporeling"],"kind":"normal","affix":null})
	g.cb.affix = &""
	g.cb.player.statuses = {}
	g.cb.player.energy = 10
	g.cb.player.block = 0
	g.cb.player.hp = 1000
	g.cb.player.max_hp = 1000
	g.cb.hand.clear()
	g.cb.draw.clear()
	g.cb.discard.clear()
	g.cb.exhaust.clear()
	var e: EnemyCombatant = g.cb.enemies[0]
	e.hp = 1000
	e.max_hp = 1000
	e.block = 0
	e.chips = 0
	e.facet_max = 1000
	e.statuses = {}
	e.flags = {}
	e.staggered = false
	g.cb.queue.clear()
	return g

func measure(role: String, aspect: int, up: bool, environment: String, intervention: String, strength: int = 0) -> Dictionary:
	var g: GlassvowGame = make_game(aspect)
	if intervention == "legacy":
		g.rules = Legacy.new(db)
		g.rules.erased_consumer = role
	elif intervention == "selective":
		g.rules = Selective.new(db)
		g.rules.remove_amplification = true
	elif intervention == "selective_off":
		g.rules = Selective.new(db)
	var inst: CardInst = CardInst.new(900, StringName(ROLE_CARDS[role]), up)
	g.cb.hand.append(inst)
	if role == "handstock":
		for j: int in range(4):
			g.cb.hand.append(CardInst.new(1000 + j, &"defend"))
	if strength != 0:
		g.cb.player.statuses["str"] = strength
	if environment in ["weak", "weak_thorns"]:
		g.cb.player.statuses["weak"] = 1
	if environment in ["thorns", "weak_thorns"]:
		g.cb.enemies[0].statuses["thorns"] = 2
	if environment == "block":
		g.cb.enemies[0].block = 3
	if environment == "vulnerable":
		g.cb.enemies[0].statuses["vulnerable"] = 1
	var events: Array[Dictionary] = g.apply({"t":"playCard","uid":900,"target":0})
	ck(g.last_ret == true, "legal " + role)
	var state: String = JSON.stringify([g.run.to_dict(), g.cb.to_dict(), g.last_ret])
	var nhit: int = 0
	for event: Dictionary in events:
		if event.get("t") == EventTypes.HIT_ENEMY:
			nhit += 1
	return {"state_sha256":state.sha256_text(),"events_sha256":JSON.stringify(events).sha256_text(),"enemy_loss":1000-g.cb.enemies[0].hp,"player_loss":1000-g.cb.player.hp,"hit_events":nhit,"events":events}

func equal(a: Dictionary, b: Dictionary) -> bool:
	return a.state_sha256 == b.state_sha256 and a.events_sha256 == b.events_sha256

func dormant_panel() -> void:
	for role: String in ROLE_CARDS:
		for aspect: int in [0, 1]:
			for up: bool in [false, true]:
				var environments: Array[String] = ["plain", "weak", "thorns", "weak_thorns", "block"]
				if role != "echo":
					environments.append("vulnerable")
				for environment: String in environments:
					var baseline: Dictionary = measure(role, aspect, up, environment, "baseline")
					var legacy: Dictionary = measure(role, aspect, up, environment, "legacy")
					var same: bool = equal(baseline, legacy)
					if not same:
						legacy_mismatches += 1
					if role != "multihit":
						ck(same, "dormant other-role null " + role)
					var row: Dictionary = {"kind":"dormant","role":role,"aspect":aspect,"up":up,"environment":environment,"legacy_equal":same,"baseline":baseline,"legacy":legacy}
					if role == "multihit":
						var selective: Dictionary = measure(role, aspect, up, environment, "selective")
						row["selective"] = selective
						row["selective_equal"] = equal(baseline, selective)
						if not row.selective_equal:
							fixed_mismatches += 1
						ck(row.selective_equal, "topology-preserving dormant null")
					emit(row)

func active_panel() -> void:
	for aspect: int in [0, 1]:
		for up: bool in [false, true]:
			for environment: String in ["plain", "weak", "thorns", "weak_thorns", "block", "vulnerable"]:
				for strength: int in [1, 3]:
					var baseline: Dictionary = measure("multihit", aspect, up, environment, "baseline", strength)
					var off: Dictionary = measure("multihit", aspect, up, environment, "selective_off", strength)
					var selective: Dictionary = measure("multihit", aspect, up, environment, "selective", strength)
					ck(equal(baseline, off), "off exact full-state/events null")
					ck(baseline.hit_events == selective.hit_events, "hit topology retained")
					ck(baseline.player_loss == selective.player_loss, "thorns retained")
					if environment == "plain":
						ck(baseline.enemy_loss - selective.enemy_loss == 4 * strength, "per-additional-hit strength interaction")
					emit({"kind":"active","aspect":aspect,"up":up,"environment":environment,"strength":strength,"baseline":baseline,"selective_off":off,"selective":selective})

func structural_witnesses() -> void:
	for aspect: int in [0, 1]:
		var g: GlassvowGame = make_game(aspect)
		var a: CardInst = CardInst.new(901, &"momentum")
		var b: CardInst = CardInst.new(902, &"momentum")
		g.cb.hand.append(a)
		g.cb.hand.append(b)
		var events: Array[Dictionary] = g.apply({"t":"playCard","uid":901,"target":0})
		ck(g.last_ret == true and a.bonus == 14 and b.bonus == 0, "growth is instance scoped")
		ck(a.combat_copy().bonus == 0, "growth resets on new combat copy")
		emit({"kind":"card_memory","aspect":aspect,"played_bonus":a.bonus,"other_copy_bonus":b.bonus,"next_combat_bonus":a.combat_copy().bonus,"events":events})
		g = make_game(aspect)
		g.cb.hand.append(CardInst.new(903, &"empower"))
		g.cb.hand.append(CardInst.new(904, &"flurry"))
		g.cb.hand.append(CardInst.new(905, &"flurry"))
		g.apply({"t":"playCard","uid":903,"target":null})
		var hp: int = g.cb.enemies[0].hp
		g.apply({"t":"playCard","uid":904,"target":0})
		var first: int = hp - g.cb.enemies[0].hp
		hp = g.cb.enemies[0].hp
		g.apply({"t":"playCard","uid":905,"target":0})
		var second: int = hp - g.cb.enemies[0].hp
		ck(first == 15 and second == 15, "Fervor affects both instances without being spent")
		emit({"kind":"player_memory","aspect":aspect,"first":first,"second":second,"str_remaining":g.cb.player.statuses.get("str",0),"events":g.cb.queue})
		g = make_game(aspect)
		g.cb.enemies[0].statuses["vulnerable"] = 1
		g.cb.hand.append(CardInst.new(906, &"resonantLance"))
		g.apply({"t":"playCard","uid":906,"target":0})
		ck(1000 - g.cb.enemies[0].hp == 21, "Cracked alone enables echo, including Ash")
		emit({"kind":"echo_disjunction","aspect":aspect,"staggered":g.cb.enemies[0].staggered,"damage":1000-g.cb.enemies[0].hp,"events":g.cb.queue})

func pool_witnesses() -> void:
	for aspect: int in [0, 1]:
		var g: GlassvowGame = make_game(aspect)
		var pools: Dictionary = {}
		for tier: String in ["common", "uncommon", "rare"]:
			pools[tier] = g.rewards.card_pool(g.run, tier)
		var cards: Dictionary = {}
		for cid: String in ["quakeblow", "resonantLance", "nightSight", "momentum", "catalyst"]:
			var d: Dictionary = db.cards[cid]
			cards[cid] = {"locked_metadata":d.get("locked",null),"in_pool_without_deed_unlock":pools[str(d.rarity)].has(cid)}
		emit({"kind":"reward_pool","aspect":aspect,"unlocks":g.run.unlocks,"reveals_all":g.run.reveals_all,"reveals":g.run.reveals,"cards":cards})

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	db = ContentDB.load_from(args[0], true)
	if db == null:
		quit(2)
		return
	output = FileAccess.open(args[1], FileAccess.WRITE)
	if output == null:
		quit(2)
		return
	emit({"kind":"manifest","engine":Engine.get_version_info()["string"],"content_sha256":FileAccess.get_sha256(args[0]),"test_sha256":FileAccess.get_sha256("res://test_package_nulls.gd"),"legacy_sha256":FileAccess.get_sha256("res://diagnostic_legacy.gd"),"selective_sha256":FileAccess.get_sha256("res://selective_fervor.gd"),"combat_sha256":FileAccess.get_sha256("res://domain/rules/combat.gd"),"scope":"constructed-fixture audit; no cohort, model refit or P9 admission"})
	dormant_panel()
	active_panel()
	structural_witnesses()
	pool_witnesses()
	ck(legacy_mismatches > 0, "legacy hit-collapse counterexample observed")
	emit({"kind":"summary","checks":checks,"failures":failures,"legacy_dormant_mismatches":legacy_mismatches,"selective_dormant_mismatches":fixed_mismatches})
	output.close()
	print("PACKAGE_NULL_CHECKS %d FAILURES %d" % [checks,failures])
	quit(0 if failures == 0 else 3)
