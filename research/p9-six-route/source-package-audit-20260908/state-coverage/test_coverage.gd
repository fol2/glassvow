extends "res://test_package_nulls.gd"
const Full: GDScript = preload("res://causal_probe.gd")
const OMITTED_CB: Array[String] = ["ember_cap","art_used_turn","kindled_turn","kindles_this_turn","pending_chips_active","counters_played","counters_attacks","first_card_played","hp_lost","prism_procd","finale_handoff"]

func fixture_state(g: GlassvowGame) -> String:
	return JSON.stringify([g.run.to_dict(),g.cb.to_dict(),g.last_ret])

func complete_fields(g: GlassvowGame) -> String:
	return JSON.stringify(Full.projection([g.run,g.cb,g.last_ret],{}))

func coverage() -> void:
	for name: String in OMITTED_CB + ["enemy.staggered","enemy.elite","enemy.boss","enemy.flags","enemy.last_moves","pending_chips"]:
		var g: GlassvowGame = make_game(0)
		var old: String = fixture_state(g)
		var full: String = complete_fields(g)
		if name == "enemy.flags":
			g.cb.enemies[0].flags["coverage_marker"] = 1
		elif name == "enemy.last_moves":
			g.cb.enemies[0].last_moves.append("spit")
		elif name == "pending_chips":
			g.cb.pending_chips[0] = {"hit":true,"extra":1}
		elif name.begins_with("enemy."):
			g.cb.enemies[0].set(name.substr(6),true)
		else:
			var v: Variant = g.cb.get(name)
			g.cb.set(name,not v if v is bool else int(v)+1)
		var omitted: bool = old == fixture_state(g)
		var observed: bool = full != complete_fields(g)
		ck(omitted and observed,"field mutation " + name)
		emit({"kind":"coverage","field":name,"fixture_omits_change":omitted,"full_observes_change":observed,"before_sha256":full.sha256_text(),"after_sha256":complete_fields(g).sha256_text()})
	var g: GlassvowGame = make_game(0)
	var inventory: Dictionary = {}
	for value: RefCounted in [g.run,g.cb,g.cb.player,g.cb.enemies[0],g.run.player,g.run.player.deck[0]]:
		inventory[value.get_script().resource_path] = Full.fields(value)
	emit({"kind":"inventory","script_fields":inventory,"rng_binding":"causal_probe.projection calls Rng.get_state; queue compared separately as command events"})

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
	emit({"kind":"manifest","test_sha256":FileAccess.get_sha256("res://test_coverage.gd"),"projection_sha256":FileAccess.get_sha256("res://causal_probe.gd"),"content_sha256":FileAccess.get_sha256(args[0])})
	coverage()
	emit({"kind":"summary","checks":checks,"failures":failures})
	output.close()
	print("STATE_COVERAGE_CHECKS %d FAILURES %d" % [checks,failures])
	quit(0 if failures == 0 else 3)
