extends RefCounted
## DD1-NATIVE-1 PROMOTION §3 / C mandatory rows that were unmapped at E.
## Constructed fixtures are labelled. Routine P_v is a read-only provenance
## gate; acquisition is an explicit Main-route operation and is not auto-run.


const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const MainRoute: GDScript = preload("res://tests/support/dd1_native_main_route.gd")
const Receipt: GDScript = preload("res://tests/support/dd1_native_launch_receipt.gd")
const M_PENDING_PATH: String = "res://research/p9-six-route/dusk-design-1-20260916/native-qualification/m-pending-run-v2.json"
const M_PENDING_ORDINARY_PATH: String = "res://research/p9-six-route/dusk-design-1-20260916/native-qualification/m-pending-ordinary-run-v2.json"
const PV_LEDGERS_PATH: String = "res://research/p9-six-route/dusk-design-1-20260916/native-qualification/pv-ledgers.json"
const QUAL_PV_P0_BYTES: String = "res://research/p9-six-route/dusk-design-1-20260916/native-qualification/p0-first-valid-run-v2.json"
const QUAL_PV_P5_BYTES: String = "res://research/p9-six-route/dusk-design-1-20260916/native-qualification/p5-first-valid-run-v2.json"
const QUAL_PV_P0_VIGIL: String = "res://research/p9-six-route/dusk-design-1-20260916/native-qualification/p0-first-valid-vigil-v2.json"
const QUAL_PV_P5_VIGIL: String = "res://research/p9-six-route/dusk-design-1-20260916/native-qualification/p5-first-valid-vigil-v2.json"
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
	_launch_receipt_controls(fails)
	_combat_dispatch_once(fails)
	_shipped_pending_capture(fails)
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
		print("  FAIL dd1-matrix: %s" % what)


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


static func _launch_receipt_controls(fails: Array[String]) -> void:
	OS.set_environment("DD1_NATIVE_LAUNCH_PERMIT", "1")
	OS.set_environment("DD1_NATIVE_ACQUIRE", "")
	var env_only: Dictionary = Receipt.evaluate("user://dd1_missing_launch_receipt.json")
	_fail(fails, env_only.get("ok", true) != true, "environment variable is not launch authority")
	var empty_path: String = "user://dd1_empty_launch_receipt.json"
	var empty_f: FileAccess = FileAccess.open(empty_path, FileAccess.WRITE)
	_fail(fails, empty_f != null, "could not write empty receipt")
	if empty_f != null:
		empty_f.store_string("")
		empty_f.close()
	var empty_row: Dictionary = Receipt.evaluate(empty_path)
	_fail(fails, empty_row.get("ok", true) != true, "empty receipt rejects")
	_fail(fails, str(empty_row.get("reason", "")).contains("empty"),
		"empty receipt names emptiness")
	var exist_path: String = "user://dd1_exist_only_launch.json"
	var exist_f: FileAccess = FileAccess.open(exist_path, FileAccess.WRITE)
	if exist_f != null:
		exist_f.store_string("{}\n")
		exist_f.close()
	var exist_row: Dictionary = Receipt.evaluate(exist_path)
	_fail(fails, exist_row.get("ok", true) != true, "file existence alone rejects")
	var stale_path: String = "user://dd1_stale_launch.json"
	var stale: Dictionary = {
		"schema": Receipt.SCHEMA,
		"operation": Receipt.OPERATION,
		"bodies": {},
		"source": {"scientific_m": "0".repeat(40), "starting_overlay_commit": "0".repeat(40)},
		"inputs": {"pending_seed": 1, "pv_roots": []},
	}
	var stale_f: FileAccess = FileAccess.open(stale_path, FileAccess.WRITE)
	if stale_f != null:
		stale_f.store_string(JSON.stringify(stale))
		stale_f.close()
	var stale_row: Dictionary = Receipt.evaluate(stale_path)
	_fail(fails, stale_row.get("ok", true) != true, "stale identity rejects")
	if FileAccess.file_exists(Receipt.DEFAULT_RECEIPT_PATH):
		var good: Dictionary = Receipt.evaluate(Receipt.DEFAULT_RECEIPT_PATH)
		_fail(fails, good.get("ok", false) == true, "populated bound receipt permits: %s" % str(good.get("reason", "")))
	OS.set_environment("DD1_NATIVE_LAUNCH_PERMIT", "")
	SaveService.clear(empty_path)
	SaveService.clear(exist_path)
	SaveService.clear(stale_path)


static func _combat_dispatch_once(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var run_path: String = "user://dd1_dispatch_run_v2.json"
	var vigil_path: String = "user://dd1_dispatch_vigil_v2.json"
	SaveService.clear(run_path)
	SaveService.clear_vigil(vigil_path)
	var main: Main = MainRoute.make_main(content, run_path, vigil_path)
	main._forced_seed = 5420099
	main._new_run({"aspect": 0, "vow": 0})
	if main._map == null or main.game == null:
		_fail(fails, false, "dispatch setup missing map")
		MainRoute.dispose(main)
		return
	var reachable: Array[int] = main._map.reachable()
	_fail(fails, not reachable.is_empty(), "dispatch row-0 reachable")
	if reachable.is_empty():
		MainRoute.dispose(main)
		return
	var pick: int = reachable[0]
	_fail(fails, main._map.enter(pick), "dispatch map.enter before arm")
	var node: MapNode = main._map.current()
	main.game.run.node_id = node.id
	main._arm_encounter(node)
	var enemies: Array = main.game.run.pending_enemy_ids if typeof(main.game.run.pending_enemy_ids) == TYPE_ARRAY else ["sporeling"]
	native_starts += 1
	main.game.apply({"t": "startCombat", "enemies": enemies, "kind": "normal"})
	_fail(fails, main.game.cb != null, "dispatch armed a combat")
	if main.game.cb == null:
		MainRoute.dispose(main)
		return
	main.game.cb.over = true
	main.game.cb.result = "win"
	var rng0: int = main.game.run.rng.get_state()
	_fail(fails, MainRoute.dispatch_combat_result_once(main, false) == true,
		"first completed combat dispatches through Main._on_combat_over")
	var rng1: int = main.game.run.rng.get_state()
	_fail(fails, main.game.run.pending_reward != null or main.game.run.pending_run_end != null,
		"first dispatch wrote pending reward or terminal")
	_fail(fails, MainRoute.dispatch_combat_result_once(main, false) == false,
		"second poll with already_dispatched=false does not re-enter _on_combat_over")
	_fail(fails, MainRoute.dispatch_combat_result_once(main, true) == false,
		"already-dispatched combat does not enter _on_combat_over again")
	var rng2: int = main.game.run.rng.get_state()
	_fail(fails, rng2 == rng1, "second poll does not advance RNG / regenerate rewards")
	_fail(fails, rng1 != rng0 or main.game.run.pending_reward != null or main.game.run.pending_run_end != null,
		"first dispatch generated rewards or a terminal")
	MainRoute.dispose(main)
	SaveService.clear(run_path)
	SaveService.clear_vigil(vigil_path)


static func _shipped_pending_capture(fails: Array[String]) -> void:
	# Drives the shipped map-selection / arm / SaveService freeze. Does not
	# overwrite the unchanged-M ordinary pending archive.
	var content: ContentDB = ContentDB.load_full(false)
	var run_path: String = "user://dd1_capture_pending_run_v2.json"
	var vigil_path: String = "user://dd1_capture_pending_vigil_v2.json"
	var before: Variant = MainRoute.file_text(M_PENDING_ORDINARY_PATH)
	var row: Dictionary = MainRoute.capture_pending_map_route(
		content, 5420099, run_path, vigil_path)
	_fail(fails, row.get("ok", false) == true,
		"shipped capture_pending_map_route ok: %s" % str(row.get("reason", "")))
	_fail(fails, _ji(row.get("seed", -1)) == 5420099, "shipped pending seed 5420099")
	_fail(fails, row.get("pendingCombat") != null, "shipped pending has pendingCombat")
	_fail(fails, _ji(row.get("node_count", 0)) > 0, "shipped pending has map nodes")
	_fail(fails, MainRoute.file_text(M_PENDING_ORDINARY_PATH) == before,
		"shipped capture does not overwrite canonical ordinary pending")
	SaveService.clear(run_path)
	SaveService.clear_vigil(vigil_path)


static func _unmodified_m_pending_resume(fails: Array[String]) -> void:
	if not FileAccess.file_exists(M_PENDING_PATH):
		_fail(fails, false,
			"constructed F pending fixture missing at %s" % M_PENDING_PATH)
		return
	var raw: String = FileAccess.get_file_as_string(M_PENDING_PATH)
	_fail(fails, not raw.is_empty(), "M pending file empty")
	var parsed: Variant = JSON.parse_string(raw)
	_fail(fails, typeof(parsed) == TYPE_DICTIONARY, "M pending JSON")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var save: Dictionary = parsed
	_fail(fails, _ji(save.get("v", 0)) == 2, "constructed pending is v2")
	var map_v: Variant = save.get("map", {})
	var nodes: Array = []
	if typeof(map_v) == TYPE_DICTIONARY:
		nodes = map_v.get("nodes", [])
	_fail(fails, nodes.is_empty() and _ji(save.get("floorsClimbed", -1)) == 0
			and str(save.get("runId", "")) == "m-pending-5420099",
		"F m-pending-run-v2.json remains constructed history (empty map, not ordinary-route)")
	if FileAccess.file_exists(M_PENDING_ORDINARY_PATH):
		_resume_ordinary_pending(fails)
	# Application resume of the constructed fixture: unmodified bytes through
	# SaveService then Main._continue_run → _resume_pending_combat.
	# This is not ordinary-route proof.
	_fail(fails, save.get("pendingCombat") != null, "constructed pending has pendingCombat")
	_fail(fails, typeof(save.get("pendingEnemyIds")) == TYPE_ARRAY,
		"constructed pending has pendingEnemyIds")
	_fail(fails, not save.has("crosscut_anchor") and not save.has("crosscutAnchor"),
		"constructed pending has no overlay mark field")
	var wf: FileAccess = FileAccess.open(M_LOAD_PATH, FileAccess.WRITE)
	_fail(fails, wf != null, "could not copy constructed pending bytes")
	if wf == null:
		return
	wf.store_string(raw)
	wf.close()
	var content: ContentDB = ContentDB.load_full(false)
	var loaded: RunState = SaveService.load_run(content, M_LOAD_PATH)
	_fail(fails, loaded != null, "SaveService.load_run of constructed pending")
	if loaded == null:
		return
	_fail(fails, loaded.run_id == str(save.get("runId", "")),
		"runId survives the store/load boundary")
	native_starts += 1
	var main: Main = MainRoute.resume_pending(content, loaded, M_LOAD_PATH, ABANDON_VIGIL_PATH)
	_fail(fails, main.game != null and main.game.cb != null,
		"constructed pending resumed through Main._continue_run")
	_fail(fails, main.game != null and main.game.cb != null and main.game.cb.crosscut_anchor == null,
		"Main resume is marker-free")
	_fail(fails, loaded.pending_combat != null, "pendingCombat preserved through SaveService")
	MainRoute.dispose(main)


static func _resume_ordinary_pending(fails: Array[String]) -> void:
	var raw: String = FileAccess.get_file_as_string(M_PENDING_ORDINARY_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	_fail(fails, typeof(parsed) == TYPE_DICTIONARY, "ordinary pending JSON")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var save: Dictionary = parsed
	var map_v: Variant = save.get("map", {})
	var nodes: Array = []
	if typeof(map_v) == TYPE_DICTIONARY:
		nodes = map_v.get("nodes", [])
	_fail(fails, not nodes.is_empty(), "ordinary pending has map nodes")
	_fail(fails, save.get("pendingCombat") != null, "ordinary pending has pendingCombat")
	_fail(fails, not save.has("crosscut_anchor") and not save.has("crosscutAnchor"),
		"ordinary pending has no overlay mark field")
	var load_path: String = "user://dd1_ordinary_pending_load.json"
	var wf: FileAccess = FileAccess.open(load_path, FileAccess.WRITE)
	if wf == null:
		_fail(fails, false, "could not copy ordinary pending bytes")
		return
	wf.store_string(raw)
	wf.close()
	var content: ContentDB = ContentDB.load_full(false)
	var loaded: RunState = SaveService.load_run(content, load_path)
	_fail(fails, loaded != null, "SaveService.load_run of ordinary pending")
	if loaded == null:
		return
	_fail(fails, loaded.run_id == str(save.get("runId", "")), "ordinary runId survives load")
	_fail(fails, loaded.pending_combat != null, "ordinary pendingCombat through SaveService")
	native_starts += 1
	var main: Main = MainRoute.resume_pending(content, loaded, load_path, ABANDON_VIGIL_PATH)
	_fail(fails, main.game != null and main.game.cb != null,
		"ordinary pending resumed through Main._continue_run")
	_fail(fails, main.game != null and main.game.cb != null and main.game.cb.crosscut_anchor == null,
		"ordinary resume is marker-free")
	MainRoute.dispose(main)
	SaveService.clear(load_path)


static func _pv_ordinary_progression(fails: Array[String]) -> void:
	# Routine regression never acquires profiles and never rewrites pv-ledgers.json.
	_pv_trace_producer_retains_bytes(fails)
	if MainRoute.acquire_requested():
		if not MainRoute.launch_permitted():
			_fail(fails, false,
				"P_5 acquisition BLOCKED: DD1_NATIVE_ACQUIRE set without launch-permitted freeze (original 8-seed cap failed P_5; 16-seed not ratified; cpu/elapsed UNKNOWN)")
			return
		_pv_acquire_via_main(fails)
		return
	_pv_retained_provenance_gate(fails)


static func _pv_retained_provenance_gate(fails: Array[String]) -> void:
	_fail(fails, FileAccess.file_exists(PV_LEDGERS_PATH), "pv-ledgers.json history retained")
	var raw: String = FileAccess.get_file_as_string(PV_LEDGERS_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	_fail(fails, typeof(parsed) == TYPE_DICTIONARY, "pv-ledgers JSON")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var ledgers: Dictionary = parsed
	_fail(fails, ledgers.has("p0") and ledgers.has("p5") and ledgers.has("traces"),
		"F summary history is preserved")
	var admission: String = str(ledgers.get("admission", ""))
	_fail(fails, admission == "UNSUPPORTED_SUMMARIES_NOT_DURABLE_PROVENANCE",
		"P_v summaries are not admitted as earned durable proof")
	var content: ContentDB = ContentDB.load_full(false)
	var canonical: Dictionary = MainRoute.evaluate_n0_witness(
		QUAL_PV_P0_BYTES, QUAL_PV_P0_VIGIL, QUAL_PV_P5_BYTES, QUAL_PV_P5_VIGIL, content)
	if str(canonical.get("result", "")) == "BLOCKED":
		_fail(fails, str(canonical.get("reason", "")).contains("missing"),
			"missing mandatory witness is BLOCKED, not success")
		_fail(fails, str(ledgers.get("n0_result", "")) == "BLOCKED",
			"F ledger still records historical N0 BLOCKED")
	elif str(canonical.get("result", "")) == "ACCEPT":
		_fail(fails, int(float(str(canonical.get("p5_vow_unlocked", 0)))) >= 5,
			"canonical P_5 witness has vow_unlocked>=5")
	else:
		_fail(fails, str(canonical.get("result", "")) == "REJECT",
			"present but invalid witness is REJECT not PASS")
	_n0_supplied_witness_accepts(fails, content)
	var p0_before: Variant = MainRoute.file_text(QUAL_PV_P0_BYTES)
	var p5_before: Variant = MainRoute.file_text(QUAL_PV_P5_BYTES)
	_fail(fails, MainRoute.file_text(QUAL_PV_P0_BYTES) == p0_before
			and MainRoute.file_text(QUAL_PV_P5_BYTES) == p5_before,
		"ordinary regression does not overwrite canonical P_v artifacts")


static func _n0_supplied_witness_accepts(fails: Array[String], content: ContentDB) -> void:
	var p0_run_path: String = "user://dd1_supplied_p0_run_v2.json"
	var p0_vigil_path: String = "user://dd1_supplied_p0_vigil_v2.json"
	var p5_run_path: String = "user://dd1_supplied_p5_run_v2.json"
	var p5_vigil_path: String = "user://dd1_supplied_p5_vigil_v2.json"
	var p0_run: RunState = RunState.new_run(content, 5421601, "supplied-p0", {"aspect": 0, "vow": 0})
	var p5_run: RunState = RunState.new_run(content, 5421609, "supplied-p5", {"aspect": 0, "vow": 4})
	_fail(fails, SaveService.store(p0_run, p0_run_path) and SaveService.store(p5_run, p5_run_path),
		"supplied witness run store")
	var p0_vigil: VigilState = VigilState.blank()
	p0_vigil.runs_played = 1
	p0_vigil.deeds["shatters"] = 15
	p0_vigil.unlocks.append("card:resonantLance")
	var p5_vigil: VigilState = VigilState.blank()
	p5_vigil.runs_played = 6
	p5_vigil.deeds["shatters"] = 40
	p5_vigil.vow_unlocked = 5
	p5_vigil.unlocks.append("card:resonantLance")
	_fail(fails, SaveService.store_vigil(p0_vigil, p0_vigil_path)
			and SaveService.store_vigil(p5_vigil, p5_vigil_path),
		"supplied witness vigil store")
	var missing: Dictionary = MainRoute.evaluate_n0_witness(
		"user://dd1_absent_p0_run.json", p0_vigil_path, p5_run_path, p5_vigil_path, content)
	_fail(fails, str(missing.get("result", "")) == "BLOCKED",
		"N0 path BLOCKED/REJECTs a missing mandatory witness")
	_fail(fails, str(missing.get("result", "")) != "ACCEPT",
		"missing mandatory witness is not success")
	var supplied: Dictionary = MainRoute.evaluate_n0_witness(
		p0_run_path, p0_vigil_path, p5_run_path, p5_vigil_path, content)
	_fail(fails, str(supplied.get("result", "")) == "ACCEPT",
		"N0 path accepts a genuine supplied witness: %s" % str(supplied.get("reason", "")))
	SaveService.clear(p0_run_path)
	SaveService.clear(p5_run_path)
	SaveService.clear_vigil(p0_vigil_path)
	SaveService.clear_vigil(p5_vigil_path)


static func _pv_trace_producer_retains_bytes(fails: Array[String]) -> void:
	# Ordinary regression must fail if the shipped producer drops commands or
	# archives from post-terminal disk. Does not replay 5421600–5421615.
	var content: ContentDB = ContentDB.load_full(false)
	var run_path: String = "user://dd1_producer_run_v2.json"
	var vigil_path: String = "user://dd1_producer_vigil_v2.json"
	var dest_run: String = "user://dd1_producer_archive_run_v2.json"
	var dest_empty: String = "user://dd1_producer_archive_empty_v2.json"
	var run: RunState = RunState.new_run(content, 5421603, "producer-retain", {"aspect": 0, "vow": 1})
	_fail(fails, SaveService.store(run, run_path), "producer fixture run store")
	var pre_v: Variant = MainRoute.file_text(run_path)
	_fail(fails, typeof(pre_v) == TYPE_STRING and not str(pre_v).is_empty(),
		"producer fixture emitted run bytes")
	if typeof(pre_v) != TYPE_STRING:
		return
	var pre: String = str(pre_v)
	var vigil: VigilState = VigilState.blank()
	vigil.unlocks.append("card:resonantLance")
	_fail(fails, SaveService.store_vigil(vigil, vigil_path), "producer fixture vigil store")
	var commit_v: Variant = MainRoute.file_text(vigil_path)
	var initial_sha: String = pre.sha256_text()
	SaveService.clear(run_path)
	_fail(fails, MainRoute.file_text(run_path) == null, "post-terminal disk cleared")
	var row: Dictionary = {
		"status": "death",
		"starts": 30,
		"shatters": 0,
		"incomplete_reason": "",
		"run_id": run.run_id,
		"run_sha": initial_sha,
		"commands": [
			{"t": "node_chosen", "index": 0},
			{"t": "combat_over", "result": "loss"},
			{"t": "terminal_commit", "outcome": "death"},
		],
		"pre_terminal_run": pre,
		"initial_run_sha": initial_sha,
		"commit_vigil": commit_v if typeof(commit_v) == TYPE_STRING else "",
		"rng_initial": 1,
		"rng_final": 2,
		"pilot_version": "p8-d0-v1",
	}
	var trace: Dictionary = MainRoute.durable_trace_row(5421603, 1, row, vigil)
	var commands_v: Variant = trace.get("commands", [])
	_fail(fails, typeof(commands_v) == TYPE_ARRAY and commands_v.size() == 3,
		"shipped producer retains drive_ordinary commands")
	_fail(fails, str(trace.get("pre_terminal_run", "")) == pre,
		"shipped producer retains pre_terminal_run bytes")
	_fail(fails, str(trace.get("initial_run_sha", "")) == initial_sha,
		"shipped producer retains initial_run_sha")
	_fail(fails, str(trace.get("commit_vigil", "")) != "",
		"shipped producer retains commit vigil receipts")
	_fail(fails, MainRoute.archive_profile_run(row, dest_run),
		"archive_profile_run writes pre_terminal_run")
	_fail(fails, MainRoute.file_text(dest_run) == pre,
		"archived P_0 run is pre-terminal bytes, not post-terminal disk")
	var empty_row: Dictionary = {"pre_terminal_run": "", "status": "death"}
	_fail(fails, MainRoute.archive_profile_run(empty_row, dest_empty) == false,
		"archive_profile_run refuses empty pre_terminal_run (no disk fallback)")
	_fail(fails, not FileAccess.file_exists(dest_empty),
		"empty pre_terminal_run does not create an archive from disk")
	SaveService.clear(run_path)
	SaveService.clear(dest_run)
	SaveService.clear_vigil(vigil_path)


static func _pv_acquire_via_main(fails: Array[String]) -> void:
	if not MainRoute.launch_permitted():
		_fail(fails, false, "P_v acquisition BLOCKED: launch receipt invalid")
		return
	var content: ContentDB = ContentDB.load_full(false)
	var vigil: VigilState = VigilState.blank()
	var freeze: Dictionary = MainRoute.bind_unmodified_pilot()
	_fail(fails, str(freeze.get("version", "")) == "p8-d0-v1", "unmodified Pilot identity")
	var p0_archived: bool = false
	var p5_archived: bool = false
	var traces: Array = []
	for seed: int in range(5421600, 5421616):
		var vow: int = mini(vigil.vow_unlocked, 4)
		var run_path: String = "user://dd1_pv_run_%d_v2.json" % seed
		var vigil_path: String = "user://dd1_pv_vigil_%d_v2.json" % seed
		SaveService.store_vigil(vigil, vigil_path)
		var row: Dictionary = MainRoute.drive_ordinary(
			content, vigil, seed, vow, run_path, vigil_path)
		native_starts += int(float(str(row.get("starts", 0))))
		var loaded: VigilState = SaveService.load_vigil(vigil_path)
		if loaded != null:
			vigil = loaded
		traces.append(MainRoute.durable_trace_row(seed, vow, row, vigil))
		if str(row.get("status", "")) == "INCOMPLETE":
			# Incomplete is not death/win and earns no profile credit.
			SaveService.clear(run_path)
			continue
		if not p0_archived and MainRoute.ledger_satisfies_p0(vigil):
			if MainRoute.archive_profile_run(row, QUAL_PV_P0_BYTES):
				MainRoute.archive_bytes(vigil_path, QUAL_PV_P0_VIGIL)
				p0_archived = true
		if p0_archived and not p5_archived and MainRoute.ledger_satisfies_p5(vigil):
			if MainRoute.archive_profile_run(row, QUAL_PV_P5_BYTES):
				MainRoute.archive_bytes(vigil_path, QUAL_PV_P5_VIGIL)
				p5_archived = true
				break
		SaveService.clear(run_path)
	var gate: Dictionary = MainRoute.evaluate_n0_witness(
		QUAL_PV_P0_BYTES, QUAL_PV_P0_VIGIL, QUAL_PV_P5_BYTES, QUAL_PV_P5_VIGIL, content)
	if str(gate.get("result", "")) != "ACCEPT":
		_fail(fails, false,
			"acquisition finished without durable P_0/P_5: %s traces=%s" % [
				str(gate), JSON.stringify(traces)])
		return
	_fail(fails, p0_archived and p5_archived, "first-valid P_0 and P_5 archived")


static func _main(content: ContentDB, run_path: String, vigil_path: String) -> Main:
	return MainRoute.make_main(content, run_path, vigil_path)


static func _dispose(main: Main) -> void:
	MainRoute.dispose(main)
