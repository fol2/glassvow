extends RefCounted
## DD1-NATIVE-1 PROMOTION §3 / C mandatory rows that were unmapped at E.
## Constructed fixtures are labelled. P_v uses ordinary Vigil commit_run.


const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")
const M_PENDING_PATH: String = "res://research/p9-six-route/dusk-design-1-20260916/native-qualification/m-pending-run-v2.json"
const PV_VIGIL_PATH: String = "user://dd1_native_pv_vigil_v2.json"
const PV_RUN_PATH: String = "user://dd1_native_pv_run_v2.json"
const ABANDON_RUN_PATH: String = "user://dd1_native_abandon_run_v2.json"
const ABANDON_VIGIL_PATH: String = "user://dd1_native_abandon_vigil_v2.json"
const M_LOAD_PATH: String = "user://dd1_native_m_pending_load.json"
const DEFAULT_RUN_PATH: String = "user://glassvow_run_v2.json"
const DEFAULT_VIGIL_PATH: String = "user://glassvow_vigil_v2.json"


static var native_starts: int = 0


static func run(fails: Array[String]) -> void:
	native_starts = 0
	var default_run: Variant = _file_text(DEFAULT_RUN_PATH)
	var default_vigil: Variant = _file_text(DEFAULT_VIGIL_PATH)
	_k1_paid_chain(fails)
	_k1_joint_and_upgrades(fails)
	_adamant_hold(fails)
	_prism_and_smolder(fails)
	_reaper_draw_energy(fails)
	_return_thorns(fails)
	_abandon_clears_mark(fails)
	_unmodified_m_pending_resume(fails)
	_pv_ordinary_progression(fails)
	if _file_text(DEFAULT_RUN_PATH) != default_run \
			or _file_text(DEFAULT_VIGIL_PATH) != default_vigil:
		fails.append("dd1-matrix: tests touched the default save")
	SaveService.clear(PV_VIGIL_PATH)
	SaveService.clear(PV_RUN_PATH)
	SaveService.clear(ABANDON_RUN_PATH)
	SaveService.clear_vigil(ABANDON_VIGIL_PATH)
	SaveService.clear(M_LOAD_PATH)
	print("  DD1-NATIVE-1-matrix native_starts=%d" % native_starts)


static func _fight(
	tag: String,
	aspect: int = 0,
	enemy_ids: Array = ["sporeling", "sporeling"],
	vow: int = 0,
	kind: String = "normal",
	affix: String = ""
) -> GlassvowGame:
	native_starts += 1
	var content: ContentDB = ContentDB.load_full(false)
	var run: RunState = RunState.new_run(content, 4211701, tag, {"aspect": aspect, "vow": vow})
	var game: GlassvowGame = GlassvowGame.new(content, run)
	var cmd: Dictionary = {"t": "startCombat", "enemies": enemy_ids, "kind": kind}
	if not affix.is_empty():
		cmd["affix"] = affix
	game.apply(cmd)
	if game.cb == null:
		return game
	game.cb.player.energy = 10
	game.cb.player.block = 0
	game.cb.first_card_played = true
	for e: EnemyCombatant in game.cb.enemies:
		e.block = 0
		e.hp = 20
		e.max_hp = 20
		e.chips = 0
		e.staggered = false
		e.statuses.clear()
	return game


static func _add(game: GlassvowGame, id: StringName, up: bool = false) -> CardInst:
	var inst: CardInst = CardInst.new(game.run.next_uid(), id, up)
	game.cb.hand.append(inst)
	return inst


static func _play(game: GlassvowGame, inst: CardInst, target: Variant) -> Array[Dictionary]:
	return game.apply({"t": "playCard", "uid": inst.uid, "target": target})


static func _ji(v: Variant) -> int:
	return int(float(str(v)))


static func _fail(fails: Array[String], ok: Variant, what: String) -> void:
	if ok != true:
		fails.append("dd1-matrix: %s" % what)


static func _file_text(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return FileAccess.get_file_as_string(path)


static func _k1_paid_chain(fails: Array[String]) -> void:
	# Constructed one-trajectory: paid Chisel shatter then paid Lance on that target.
	for vow: int in [0, 5]:
		var game: GlassvowGame = _fight("k1-chain-v%d" % vow, 0, ["sporeling"], vow)
		var e: EnemyCombatant = game.cb.enemies[0]
		e.facet_max = 4
		e.chips = 3
		e.hp = 40
		e.max_hp = 40
		game.cb.player.energy = 2
		var chisel: CardInst = _add(game, &"chisel")
		_play(game, chisel, 0)
		_fail(fails, game.last_ret == true, "vow %d paid Chisel legal" % vow)
		_fail(fails, game.cb.player.energy == 1, "vow %d Chisel spent 1" % vow)
		_fail(fails, e.staggered, "vow %d Chisel coupled Stun" % vow)
		_fail(fails, _ji(e.statuses.get("vulnerable", 0)) >= 2, "vow %d Chisel coupled Cracked" % vow)
		var lance: CardInst = _add(game, &"resonantLance")
		var pre: Dictionary = DuskNativeExportReader.pre_hp_map(game.cb)
		var ev: Array[Dictionary] = _play(game, lance, 0)
		_fail(fails, game.last_ret == true, "vow %d paid Lance legal" % vow)
		_fail(fails, game.cb.player.energy == 0, "vow %d Lance spent last energy" % vow)
		_fail(fails, game.cb.discard.has(chisel) and game.cb.discard.has(lance),
			"vow %d both cards discarded" % vow)
		var cap: Dictionary = DuskNativeExportReader.bind_capture(ev, pre, {
			"role": "native_export/N0/v0", "tag": "k1-chain-v%d" % vow, "vow": vow,
		})
		var obs_v: Variant = DuskNativeExportReader.hit_observations(cap)
		_fail(fails, typeof(obs_v) == TYPE_ARRAY, "vow %d Lance hits from bytes" % vow)
		if typeof(obs_v) == TYPE_ARRAY:
			var obs: Array = obs_v
			_fail(fails, obs.size() >= 1, "vow %d Lance hit observed" % vow)
			if obs.size() >= 1:
				_fail(fails, _ji(obs[0]["amount"]) >= 14, "vow %d echo amount on shattered target" % vow)


static func _k1_joint_and_upgrades(fails: Array[String]) -> void:
	var masked: GlassvowGame = _fight("k1-joint", 0, ["sporeling"])
	var e: EnemyCombatant = masked.cb.enemies[0]
	e.facet_max = 4
	e.chips = 3
	masked.rules.research_mask_shatter = true
	_play(masked, _add(masked, &"chisel"), 0)
	_fail(fails, e.hp == 16, "joint-off Chisel still hits")
	_fail(fails, e.chips >= 4, "joint-off chips still land")
	_fail(fails, not e.staggered, "joint-off does not Stun")
	_fail(fails, _ji(e.statuses.get("vulnerable", 0)) == 0, "joint-off does not Crack")
	var up_p: GlassvowGame = _fight("k1-chisel-up", 0, ["sporeling"])
	var e2: EnemyCombatant = up_p.cb.enemies[0]
	e2.facet_max = 8
	e2.chips = 0
	_play(up_p, _add(up_p, &"chisel", true), 0)
	_fail(fails, e2.chips == 2, "upgraded producer still prints extra chip")
	var up_c: GlassvowGame = _fight("k1-lance-up", 0, ["sporeling"])
	var e3: EnemyCombatant = up_c.cb.enemies[0]
	e3.hp = 50
	e3.max_hp = 50
	e3.staggered = true
	_play(up_c, _add(up_c, &"resonantLance", true), 0)
	_fail(fails, e3.hp == 50 - 20, "upgraded Lance echo 10*2=20, hp %d" % e3.hp)


static func _adamant_hold(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight("adamant", 0, ["sporeling"], 0, "elite", "adamant")
	if game.cb == null or game.cb.enemies.is_empty():
		_fail(fails, false, "adamant elite fight missing")
		return
	var e: EnemyCombatant = game.cb.enemies[0]
	_fail(fails, e.flags.get("adamant", false) == true, "adamant affix flag")
	e.facet_max = 4
	e.chips = 3
	e.staggered = false
	var ev1: Array[Dictionary] = _play(game, _add(game, &"chisel"), 0)
	var held: bool = false
	for ev: Dictionary in ev1:
		if str(ev.get("t", "")) == "adamantHold":
			held = true
	_fail(fails, held, "first threshold emits adamantHold")
	_fail(fails, not e.staggered, "adamant hold suppresses Stun")
	_fail(fails, _ji(e.statuses.get("vulnerable", 0)) == 0, "adamant hold suppresses Cracked")
	e.chips = e.facet_max
	_play(game, _add(game, &"chisel"), 0)
	_fail(fails, e.staggered, "spent adamant then shatters")
	_fail(fails, _ji(e.statuses.get("vulnerable", 0)) >= 2, "post-hold coupled Cracked")


static func _prism_and_smolder(fails: Array[String]) -> void:
	var pr: GlassvowGame = _fight("prism", 0, ["sporeling", "sporeling"])
	pr.run.player.relics.append("prismCharm")
	var a: EnemyCombatant = pr.cb.enemies[0]
	a.facet_max = 4
	a.chips = 3
	var embers0: int = pr.cb.embers
	_play(pr, _add(pr, &"chisel"), 0)
	_fail(fails, pr.cb.prism_procd, "Prism procs on first Shatter")
	_fail(fails, pr.cb.embers == embers0 + 4, "Shatter 2 + Prism 2 embers, got %d" % pr.cb.embers)
	var b: EnemyCombatant = pr.cb.enemies[1]
	b.facet_max = 4
	b.chips = 3
	var embers1: int = pr.cb.embers
	_play(pr, _add(pr, &"chisel"), 1)
	_fail(fails, pr.cb.embers == embers1 + 2, "second Shatter has no extra Prism")
	var sm: GlassvowGame = _fight("smolder", 0, ["sporeling", "sporeling"])
	var s0: EnemyCombatant = sm.cb.enemies[0]
	var s1: EnemyCombatant = sm.cb.enemies[1]
	s0.statuses["poison"] = 3
	s0.facet_max = 4
	s0.chips = 3
	var rng_before: int = sm.run.rng.get_state()
	_play(sm, _add(sm, &"chisel"), 0)
	var rng_after: int = sm.run.rng.get_state()
	_fail(fails, rng_after != rng_before, "Smolder transfer consumes seeded RNG")
	_fail(fails, _ji(s0.statuses.get("poison", 0)) == 0, "Smolder left the shattered host")
	_fail(fails, _ji(s1.statuses.get("poison", 0)) == 3, "Smolder jumped to the other living enemy")


static func _reaper_draw_energy(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight("reaper")
	game.run.player.relics.append("reapersBell")
	var extra: CardInst = CardInst.new(game.run.next_uid(), &"defend", false)
	game.cb.draw.append(extra)
	var strike: CardInst = _add(game, &"strike")
	var energy0: int = game.cb.player.energy
	var hand0: int = game.cb.hand.size()
	game.cb.enemies[0].hp = 1
	var ev: Array[Dictionary] = _play(game, strike, 0)
	_fail(fails, game.cb.enemies[0].hp <= 0, "primary died")
	_fail(fails, not game.cb.over, "second enemy keeps combat live")
	_fail(fails, game.cb.player.energy == energy0, "strike paid 1 and Reaper refunds 1")
	var drew: bool = false
	for row: Dictionary in ev:
		if str(row.get("t", "")) == "draw" and _ji(row.get("uid", -1)) == extra.uid:
			drew = true
	_fail(fails, drew, "Reaper emitted a real DRAW of the draw-pile card")
	_fail(fails, game.cb.hand.has(extra), "drawn card is in hand, not draws_owed")
	_fail(fails, game.cb.hand.size() == hand0, "hand: played strike, drew one")


static func _return_thorns(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight("return-thorns")
	var a: EnemyCombatant = game.cb.enemies[0]
	var b: EnemyCombatant = game.cb.enemies[1]
	a.statuses["thorns"] = 3
	_play(game, _add(game, &"setTheAngle"), 0)
	game.cb.player.hp = 20
	game.cb.player.block = 0
	var ev: Array[Dictionary] = _play(game, _add(game, &"crosscut"), 1)
	var hits: Array = []
	for row: Dictionary in ev:
		if str(row.get("t", "")) == "hitEnemy":
			hits.append(row)
	_fail(fails, hits.size() == 2, "primary survives so return occurs")
	_fail(fails, b.hp == 15, "primary 5 on unmarked B")
	_fail(fails, a.hp == 15, "return 5 on thorned A")
	_fail(fails, game.cb.player.hp == 17, "return-Thorns 3 hits living player")
	_fail(fails, not game.cb.over, "player survives return-Thorns")


static func _abandon_clears_mark(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	SaveService.clear(ABANDON_RUN_PATH)
	SaveService.clear_vigil(ABANDON_VIGIL_PATH)
	var main: Main = _main(content, ABANDON_RUN_PATH, ABANDON_VIGIL_PATH)
	main.game = _fight("abandon-mark")
	_play(main.game, _add(main.game, &"setTheAngle"), 0)
	_fail(fails, main.game.cb.has_live_crosscut_anchor(), "mark live before abandon")
	main._on_abandon_choice("yes")
	_fail(fails, main.game.run.pending_run_end != null \
			and str(main.game.run.pending_run_end.get("outcome", "")) == "abandon",
		"Main abandon boundary wrote pending_run_end")
	var saved: RunState = SaveService.load_run(content, ABANDON_RUN_PATH)
	_fail(fails, saved != null, "abandon stored a run")
	if saved != null:
		var blob: String = JSON.stringify(saved.to_save_dict())
		_fail(fails, not blob.contains("crosscut_anchor") and not blob.contains("crosscutAnchor"),
			"abandon save has no mark field")
	native_starts += 1
	var next: GlassvowGame = GlassvowGame.new(content, RunState.new_run(content, 4211702, "after-abandon"))
	next.apply({"t": "startCombat", "enemies": ["sporeling", "sporeling"], "kind": "normal"})
	_fail(fails, next.cb != null and next.cb.crosscut_anchor == null,
		"combat after abandon is marker-free")
	_dispose(main)


static func _unmodified_m_pending_resume(fails: Array[String]) -> void:
	if not FileAccess.file_exists(M_PENDING_PATH):
		_fail(fails, false,
			"unmodified M pending bytes missing at %s (emit on unchanged M first)" % M_PENDING_PATH)
		return
	var raw: String = FileAccess.get_file_as_string(M_PENDING_PATH)
	_fail(fails, not raw.is_empty(), "M pending file empty")
	var parsed: Variant = JSON.parse_string(raw)
	_fail(fails, typeof(parsed) == TYPE_DICTIONARY, "M pending JSON")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var save: Dictionary = parsed
	_fail(fails, _ji(save.get("v", 0)) == 2, "M pending is v2 as emitted")
	_fail(fails, save.get("pendingCombat") != null, "M pending has pendingCombat in the bytes")
	_fail(fails, typeof(save.get("pendingEnemyIds")) == TYPE_ARRAY,
		"M pending has pendingEnemyIds in the bytes")
	_fail(fails, not save.has("crosscut_anchor") and not save.has("crosscutAnchor"),
		"M pending has no overlay mark field")
	var wf: FileAccess = FileAccess.open(M_LOAD_PATH, FileAccess.WRITE)
	_fail(fails, wf != null, "could not copy M pending bytes")
	if wf == null:
		return
	wf.store_string(raw)
	wf.close()
	var content: ContentDB = ContentDB.load_full(false)
	var loaded: RunState = SaveService.load_run(content, M_LOAD_PATH)
	_fail(fails, loaded != null, "SaveService.load_run of unmodified M pending")
	if loaded == null:
		return
	var main: Main = _main(content, M_LOAD_PATH, "user://dd1_native_m_pending_vigil.json")
	main.game = GlassvowGame.new(content, loaded)
	main._resume_pending_combat()
	_fail(fails, main.game.cb != null, "Main._resume_pending_combat started combat")
	_fail(fails, main.game.cb != null and main.game.cb.crosscut_anchor == null,
		"M pending resume is marker-free")
	if main.game.cb != null:
		native_starts += 1
	_dispose(main)
	SaveService.clear_vigil("user://dd1_native_m_pending_vigil.json")


static func _pv_ordinary_progression(fails: Array[String]) -> void:
	SaveService.clear(PV_VIGIL_PATH)
	SaveService.clear(PV_RUN_PATH)
	var content: ContentDB = ContentDB.load_full(false)
	var vigil: VigilState = VigilState.blank()
	Pilot.set_ban(PackedStringArray())
	Pilot.apply_policy({})
	Pilot.set_modes(false, false)
	var p0: Dictionary = {}
	var p5: Dictionary = {}
	var traces: Array = []
	# First-valid: predeclared seeds, keep losses, stop at first ledger that meets the row.
	for i: int in range(8):
		var seed: int = 5421600 + i
		var vow: int = mini(4, int(vigil.vow_unlocked))
		var row: Dictionary = _legal_campaign(content, vigil, seed, vow)
		traces.append({
			"seed": seed, "vow": vow, "outcome": row.get("outcome", ""),
			"shatters": row.get("shatters", 0), "starts": row.get("starts", 0),
			"paneBreaker": vigil.unlocks.has("card:resonantLance"),
			"vowUnlocked": vigil.vow_unlocked,
		})
		SaveService.store_vigil(vigil, PV_VIGIL_PATH)
		if p0.is_empty() and vigil.unlocks.has("card:resonantLance"):
			p0 = {
				"seed": seed, "vowUnlocked": vigil.vow_unlocked,
				"unlocks": vigil.unlocks.duplicate(),
				"deedsShatters": _ji(vigil.deeds.get("shatters", 0)),
				"runsPlayed": vigil.runs_played,
			}
		if p5.is_empty() and vigil.vow_unlocked >= 5 and vigil.unlocks.has("card:resonantLance"):
			p5 = {
				"seed": seed, "vowUnlocked": vigil.vow_unlocked,
				"unlocks": vigil.unlocks.duplicate(),
			}
			break
		if not p0.is_empty() and vigil.vow_unlocked >= 5:
			break
	_fail(fails, not p0.is_empty(),
		"P_0 not earned after attempted legal campaigns: %s" % JSON.stringify(traces))
	if not p0.is_empty():
		_fail(fails, _ji(p0.get("deedsShatters", 0)) >= 15, "P_0 paneBreaker from folded shatters")
		_fail(fails, vigil.unlocks.has("card:resonantLance"), "P_0 has Resonant Lance opportunity")
	if p5.is_empty():
		_fail(fails, false,
			"P_5 blocked after attempted legal campaigns; traces=%s (not 'no recovered ledger')" \
				% JSON.stringify(traces))
	var qpath: String = "res://research/p9-six-route/dusk-design-1-20260916/native-qualification/pv-ledgers.json"
	var qf: FileAccess = FileAccess.open(qpath, FileAccess.WRITE)
	if qf != null:
		qf.store_string(JSON.stringify({"p0": p0, "p5": p5, "traces": traces}))
		qf.close()


static func _legal_campaign(content: ContentDB, vigil: VigilState, seed: int, vow: int) -> Dictionary:
	var profile: Dictionary = {
		"aspect": 0,
		"vow": vow,
		"reveals": vigil.unlocks.filter(func(id: String) -> bool: return content.reveal_ids.has(id)),
		"unlocks": vigil.unlocks.duplicate(),
		"quests": vigil.quests.duplicate(true),
		"shards": vigil.shards.duplicate(),
		"lamplighter": vigil.unlocks.has("lamplighter"),
	}
	var run: RunState = RunState.new_run(content, seed, "dd1-pv-%d" % seed, profile)
	var game: GlassvowGame = GlassvowGame.new(content, run)
	var starts: int = 0
	var outcome: String = "error"
	for _act: int in range(3):
		var map: WorldMap = WorldMap.benchmark(run)
		var act_ok: bool = true
		while not map.is_finished():
			var reachable: Array[int] = map.reachable()
			if reachable.is_empty():
				act_ok = false
				break
			var i: int = Pilot.choose_node(map, run)
			if not map.enter(i):
				act_ok = false
				break
			var node: MapNode = map.current()
			run.node_id = node.id
			run.waystones_lit = node.row + 1
			if node.is_combat():
				var enemies: Array[String] = node.enemies.duplicate()
				if enemies.is_empty():
					enemies = game.rewards.roll_encounter(run, node.type, node.row, node)
				native_starts += 1
				starts += 1
				game.apply({"t": "startCombat", "enemies": enemies, "kind": node.combat_kind()})
				while game.cb != null and not game.cb.over:
					Pilot.play_turn(game)
					if game.cb.over:
						break
					if game.cb.turn >= 30:
						break
					game.apply({"t": "endTurn"})
				if game.cb == null or not game.cb.over or str(game.cb.result) != "win":
					outcome = "loss"
					act_ok = false
					break
				if node.type == "boss" and run.act == 2:
					outcome = "win"
					map.clear_current()
					act_ok = true
					break
				BalanceSim._claim_rewards(game, game.gen_combat_rewards(node.combat_kind(), game.cb.affix))
			else:
				BalanceSim._resolve_safe_node(game, node)
			map.clear_current()
			if node.type == "boss" and not run.is_final_act():
				var offered: Array[String] = game.rewards.roll_boss_relics(run)
				var relic: String = Pilot.choose_relic(offered, content, run.aspect, run.rng)
				if not relic.is_empty():
					game.rewards.gain_relic(run, relic)
				run.boss_relic_act = run.act
				run.start_next_act(content)
				break
		if outcome == "win" or outcome == "loss" or not act_ok:
			break
	if outcome == "error":
		outcome = "loss"
	var commit: String = "win" if outcome == "win" else "death"
	vigil.commit_run(run, commit, content)
	return {
		"outcome": outcome,
		"starts": starts,
		"shatters": _ji(run.stats.get("shatters", 0)),
		"vow": run.vow,
	}


static func _main(content: ContentDB, run_path: String, vigil_path: String) -> Main:
	var main: Main = Main.new()
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main.content = content
	main._run_save_path = run_path
	main._vigil_save_path = vigil_path
	main._vigil = VigilState.blank()
	main._opening_suppressed = true
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	return main


static func _dispose(main: Main) -> void:
	main._clear_route()
	for child: Node in main.get_children():
		child.free()
	main.free()
