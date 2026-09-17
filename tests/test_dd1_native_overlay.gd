extends RefCounted
## DD1-NATIVE-1 focused native refinement: PROMOTION §3 + NATIVE-HANDOFF.
## Every claim is driven through GlassvowGame.apply / play_card / preview_play
## / card_pool / v2 save. Python-grid rows are not observations.


static var native_starts: int = 0


static func run(fails: Array[String]) -> void:
	native_starts = 0
	_crosscut_return_and_order(fails)
	_crosscut_same_target_spends(fails)
	_crosscut_replace_no_stack(fails)
	_crosscut_illegal_does_not_mutate(fails)
	_crosscut_costs_and_upgrades(fails)
	_crosscut_expiry_death_terminal(fails)
	_crosscut_aspect_and_preview(fails)
	_k1_disjunctive_guard(fails)
	_k1_chisel_chip_and_subsets(fails)
	_k2_empower_flurry_strength(fails)
	_mixed_three_roles(fails)
	_both_pool_paths(fails)
	_v2_save_and_pending_reconstruction(fails)
	_marker_and_export_reader(fails)
	_r1_same_command_masks(fails)
	_r1_sequential_energy_and_vow(fails)
	_r2_ash_marker_and_thorns_preview(fails)
	_r2_finale_handoff_suppresses_return(fails)
	_r3_ordering_negative_and_bell(fails)
	_r3_overkill_and_m_fixture(fails)
	_r3_byte_root_controls(fails)
	print("  DD1-NATIVE-1 native_starts=%d" % native_starts)


static func _fight(
	tag: String,
	aspect: int = 0,
	enemy_ids: Array = ["sporeling", "sporeling"],
	vow: int = 0
) -> GlassvowGame:
	native_starts += 1
	var content: ContentDB = ContentDB.load_full(false)
	var run: RunState = RunState.new_run(content, 4211601, tag, {"aspect": aspect, "vow": vow})
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": enemy_ids, "kind": "normal"})
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


static func _cap(game: GlassvowGame, events: Array, pre_hp: Dictionary, tag: String) -> Dictionary:
	return DuskNativeExportReader.bind_capture(events, pre_hp, {
		"role": "native_export/N0/v0",
		"tag": tag,
		"vow": game.run.vow,
		"aspect": game.run.aspect,
	})


static func _play(game: GlassvowGame, inst: CardInst, target: Variant) -> Array[Dictionary]:
	return game.apply({"t": "playCard", "uid": inst.uid, "target": target})


static func _hits(events: Array) -> Array:
	var out: Array = []
	for ev: Dictionary in events:
		if str(ev.get("t", "")) == "hitEnemy":
			out.append(ev)
	return out


static func _ji(v: Variant) -> int:
	return int(float(str(v)))


static func _fail(fails: Array[String], ok: Variant, what: String) -> void:
	if ok != true:
		fails.append("dd1-native: %s" % what)


static func _crosscut_return_and_order(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight("return-order")
	if game.cb == null or game.cb.enemies.size() < 2:
		_fail(fails, false, "return-order fight missing")
		return
	var a: EnemyCombatant = game.cb.enemies[0]
	var b: EnemyCombatant = game.cb.enemies[1]
	var producer: CardInst = _add(game, &"setTheAngle")
	var events_p: Array[Dictionary] = _play(game, producer, 0)
	_fail(fails, game.last_ret == true, "producer play ret")
	_fail(fails, game.cb.crosscut_anchor == a, "producer anchors A")
	_fail(fails, game.cb.player.block == 4, "producer ordinary block 4")
	var saw_hit: bool = false
	for ev: Dictionary in events_p:
		if str(ev.get("t", "")) == "hitEnemy":
			saw_hit = true
	_fail(fails, not saw_hit, "producer must not deal damage")
	var pre_hp: Dictionary = DuskNativeExportReader.pre_hp_map(game.cb)
	var consumer: CardInst = _add(game, &"crosscut")
	var events_c: Array[Dictionary] = _play(game, consumer, 1)
	_fail(fails, game.last_ret == true, "consumer play ret")
	_fail(fails, game.cb.crosscut_anchor == null, "consumer consumes the mark")
	var hits: Array = _hits(events_c)
	_fail(fails, hits.size() == 2, "consumer two ordinary hits, got %d" % hits.size())
	if hits.size() != 2:
		return
	_fail(fails, _ji(hits[0].get("idx", -1)) == b.idx, "primary is B idx 1")
	_fail(fails, _ji(hits[1].get("idx", -1)) == a.idx, "return is A idx 0")
	_fail(fails, _ji(hits[0].get("amount", 0)) == 5, "primary amount 5")
	_fail(fails, _ji(hits[1].get("amount", 0)) == 5, "return amount 5")
	_fail(fails, b.hp == 15 and a.hp == 15, "physical HP after both hits")
	_fail(fails, DuskNativeExportReader.ordinary_hits_precede_first_chip(events_c, 2),
		"both Crosscut hits before this card's first chip")
	var cap: Dictionary = _cap(game, events_c, pre_hp, "return-order")
	var obs_v: Variant = DuskNativeExportReader.hit_observations(cap)
	_fail(fails, typeof(obs_v) == TYPE_ARRAY, "reader resolved hits")
	if typeof(obs_v) != TYPE_ARRAY:
		return
	var obs: Array = obs_v
	_fail(fails, obs.size() == 2, "reader two hits")
	if obs.size() != 2:
		return
	_fail(fails, _ji(obs[0]["physicalHpLoss"]) == 5, "physical primary 5")
	_fail(fails, _ji(obs[1]["physicalHpLoss"]) == 5, "physical return 5")
	_fail(fails, _ji(obs[0]["overkill"]) == 0, "no overkill on primary")
	var p0: Dictionary = obs[0]["pointer"]
	_fail(fails, DuskNativeExportReader.resolve(p0, cap) != null,
		"primary pointer resolves against captured bytes")
	var chips: Array = DuskNativeExportReader.chip_order(events_c)
	_fail(fails, chips.size() == 2, "one-card chips on both connected targets")
	if chips.size() >= 2:
		_fail(fails, _ji(chips[0]["idx"]) == b.idx and _ji(chips[1]["idx"]) == a.idx,
			"chip insertion order B then A")
	_fail(fails, game.cb.discard.has(consumer), "consumer discarded, not exhausted")
	_fail(fails, game.cb.counters_attacks == 1, "one Attack count for Crosscut")


static func _crosscut_same_target_spends(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight("same-target")
	var a: EnemyCombatant = game.cb.enemies[0]
	_play(game, _add(game, &"setTheAngle"), 0)
	var events: Array[Dictionary] = _play(game, _add(game, &"crosscut"), 0)
	var hits: Array = _hits(events)
	_fail(fails, hits.size() == 1, "same-target spends without return")
	_fail(fails, game.cb.crosscut_anchor == null, "same-target mark spent")
	_fail(fails, a.hp == 15, "same-target only primary 5")


static func _crosscut_replace_no_stack(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight("replace")
	var a: EnemyCombatant = game.cb.enemies[0]
	var b: EnemyCombatant = game.cb.enemies[1]
	_play(game, _add(game, &"setTheAngle"), 0)
	_fail(fails, game.cb.crosscut_anchor == a, "first producer A")
	_play(game, _add(game, &"setTheAngle"), 1)
	_fail(fails, game.cb.crosscut_anchor == b, "second producer replaces with B")
	var events: Array[Dictionary] = _play(game, _add(game, &"crosscut"), 0)
	var hits: Array = _hits(events)
	_fail(fails, hits.size() == 2, "return after replace")
	if hits.size() >= 2:
		_fail(fails, _ji(hits[0].get("idx", -1)) == a.idx, "primary on A")
		_fail(fails, _ji(hits[1].get("idx", -1)) == b.idx, "return on replaced B")
	var second: CardInst = _add(game, &"crosscut")
	var events2: Array[Dictionary] = _play(game, second, 1)
	_fail(fails, _hits(events2).size() == 1, "second consumer cannot reuse the spent mark")
	_fail(fails, game.cb.crosscut_anchor == null, "spent mark stays cleared")


static func _crosscut_illegal_does_not_mutate(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight("illegal")
	var a: EnemyCombatant = game.cb.enemies[0]
	_play(game, _add(game, &"setTheAngle"), 0)
	var energy: int = game.cb.player.energy
	var block: int = game.cb.player.block
	var missing: CardInst = CardInst.new(game.run.next_uid(), &"crosscut", false)
	var events: Array[Dictionary] = game.apply({"t": "playCard", "uid": missing.uid, "target": 1})
	_fail(fails, game.last_ret == false, "missing UID rejected")
	_fail(fails, events.is_empty(), "missing UID emits nothing")
	_fail(fails, game.cb.crosscut_anchor == a, "missing UID leaves mark")
	game.cb.player.energy = 0
	var consumer: CardInst = _add(game, &"crosscut")
	game.cb.player.energy = 0
	game.apply({"t": "playCard", "uid": consumer.uid, "target": 1})
	_fail(fails, game.last_ret == false, "zero energy rejected")
	_fail(fails, game.cb.crosscut_anchor == a, "zero energy leaves mark")
	_fail(fails, game.cb.hand.has(consumer), "zero energy keeps the card")
	game.cb.player.energy = energy
	game.apply({"t": "playCard", "uid": consumer.uid, "target": 9})
	_fail(fails, game.last_ret == false, "out-of-range target rejected")
	_fail(fails, game.cb.crosscut_anchor == a, "bad target leaves mark")
	game.cb.enemies[1].hp = 0
	game.apply({"t": "playCard", "uid": consumer.uid, "target": 1})
	_fail(fails, game.last_ret == false, "dead target rejected")
	_fail(fails, game.cb.player.block == block, "illegal plays do not change block")
	game.cb.enemies[1].hp = 20
	game.cb.player.energy = 3
	var ash: GlassvowGame = _fight("illegal-ash", 1)
	if ash.cb != null:
		_play(ash, _add(ash, &"setTheAngle"), 0)
		_fail(fails, ash.cb.player.block == 4, "Ash producer still grants Block")
		_fail(fails, ash.cb.crosscut_anchor == null, "Ash must not install the public marker")
		var ash_events: Array[Dictionary] = _play(ash, _add(ash, &"crosscut"), 1)
		_fail(fails, _hits(ash_events).size() == 1, "Ash return is null-domain")


static func _crosscut_costs_and_upgrades(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight("upgrades")
	var p_up: CardInst = _add(game, &"setTheAngle", true)
	_play(game, p_up, 0)
	_fail(fails, game.cb.player.block == 6, "upgraded producer block 6")
	var c_up: CardInst = _add(game, &"crosscut", true)
	var events: Array[Dictionary] = _play(game, c_up, 1)
	var hits: Array = _hits(events)
	_fail(fails, hits.size() == 2, "upgraded consumer two hits")
	if hits.size() == 2:
		_fail(fails, _ji(hits[0].get("amount", 0)) == 7, "upgraded primary 7")
		_fail(fails, _ji(hits[1].get("amount", 0)) == 7, "upgraded return 7")
	var disc: GlassvowGame = _fight("duskmirror")
	disc.run.player.relics.append("duskmirror")
	disc.cb.first_card_played = false
	var cheap: CardInst = _add(disc, &"setTheAngle")
	var cost: int = disc.rules.eff_cost(disc.run, disc.cb, cheap)
	_fail(fails, cost == 0, "Duskmirror first-card cost 0")
	disc.cb.player.energy = 0
	_play(disc, cheap, 0)
	_fail(fails, disc.last_ret == true, "Duskmirror first producer is legal at 0 energy")


static func _crosscut_expiry_death_terminal(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight("expiry")
	_play(game, _add(game, &"setTheAngle"), 0)
	_fail(fails, game.cb.has_live_crosscut_anchor(), "mark live before end turn")
	game.apply({"t": "endTurn"})
	_fail(fails, game.cb.crosscut_anchor == null, "mark expires before enemy phase")
	var death: GlassvowGame = _fight("death")
	var marked: EnemyCombatant = death.cb.enemies[0]
	_play(death, _add(death, &"setTheAngle"), 0)
	marked.hp = 1
	_play(death, _add(death, &"strike"), 0)
	_fail(fails, death.cb.crosscut_anchor == null, "dead marked enemy clears")
	var lethal: GlassvowGame = _fight("lethal-primary")
	_play(lethal, _add(lethal, &"setTheAngle"), 0)
	lethal.cb.enemies[1].hp = 1
	var events: Array[Dictionary] = _play(lethal, _add(lethal, &"crosscut"), 1)
	# Two sporelings: killing one does not end combat. Return should still fire
	# if A lives. If the primary somehow ended combat, return is suppressed.
	if lethal.cb.over:
		_fail(fails, _hits(events).size() == 1, "terminal primary suppresses return")
	else:
		_fail(fails, _hits(events).size() == 2, "non-terminal primary still returns")
	var win: GlassvowGame = _fight("win-clear", 0, ["sporeling"])
	_play(win, _add(win, &"setTheAngle"), 0)
	win.cb.enemies[0].hp = 1
	_play(win, _add(win, &"strike"), 0)
	_fail(fails, win.cb.over, "single-enemy lethal ends combat")
	_fail(fails, win.cb.crosscut_anchor == null, "victory clears mark")


static func _crosscut_aspect_and_preview(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight("preview")
	var producer: CardInst = _add(game, &"setTheAngle")
	var pv_p: Variant = game.rules.preview_play(game.cb, producer, 0, game.run)
	_fail(fails, typeof(pv_p) == TYPE_DICTIONARY, "producer preview exists")
	if typeof(pv_p) == TYPE_DICTIONARY:
		var pp: Dictionary = pv_p
		_fail(fails, _ji(pp.get("block", 0)) == 4, "producer preview block 4")
		_fail(fails, not pp.has("return"), "producer preview has no return")
	_play(game, producer, 0)
	var consumer: CardInst = _add(game, &"crosscut")
	var pv_b: Variant = game.rules.preview_play(game.cb, consumer, 1, game.run)
	_fail(fails, typeof(pv_b) == TYPE_DICTIONARY, "two-target preview exists")
	if typeof(pv_b) == TYPE_DICTIONARY:
		var pb: Dictionary = pv_b
		_fail(fails, pb.has("return"), "eligible Crosscut preview names return")
		if pb.has("return") and typeof(pb["return"]) == TYPE_DICTIONARY:
			var ret: Dictionary = pb["return"]
			_fail(fails, _ji(ret.get("idx", -1)) == 0, "return preview idx is A")
			_fail(fails, _ji(ret.get("loss", 0)) == 5, "return preview loss 5")
	var pv_same: Variant = game.rules.preview_play(game.cb, consumer, 0, game.run)
	if typeof(pv_same) == TYPE_DICTIONARY:
		var same_d: Dictionary = pv_same
		_fail(fails, not same_d.has("return"), "same-target preview is primary-only")
	var blocked: GlassvowGame = _fight("preview-block")
	_play(blocked, _add(blocked, &"setTheAngle"), 0)
	blocked.cb.enemies[0].block = 99
	var c2: CardInst = _add(blocked, &"crosscut")
	var pv_blk: Variant = blocked.rules.preview_play(blocked.cb, c2, 1, blocked.run)
	if typeof(pv_blk) == TYPE_DICTIONARY:
		var blk_d: Dictionary = pv_blk
		_fail(fails, typeof(blk_d.get("return", null)) == TYPE_DICTIONARY, "blocked preview still names return")
		if typeof(blk_d.get("return", null)) == TYPE_DICTIONARY:
			var rb: Dictionary = blk_d["return"]
			_fail(fails, _ji(rb.get("loss", -1)) == 0, "full Block eliminates return HP")
			_fail(fails, rb.get("lethal", true) != true, "blocked return is not lethal")


static func _k1_disjunctive_guard(fails: Array[String]) -> void:
	# Staggered only — echo 2, no Cracked multiplier.
	var st: GlassvowGame = _fight("k1-staggered", 0, ["sporeling"])
	var e0: EnemyCombatant = st.cb.enemies[0]
	e0.staggered = true
	e0.statuses.erase("vulnerable")
	var lance: CardInst = _add(st, &"resonantLance")
	var pv: Variant = st.rules.preview_play(st.cb, lance, 0, st.run)
	_play(st, lance, 0)
	_fail(fails, e0.hp == 6, "staggered-only Lance deals 14, hp %d" % e0.hp)
	if typeof(pv) == TYPE_DICTIONARY:
		var st_pv: Dictionary = pv
		_fail(fails, _ji(st_pv.get("loss", 0)) == 14, "staggered-only preview 14")
	# Cracked only — echo 2 then native Cracked 1.5.
	var cr: GlassvowGame = _fight("k1-cracked", 0, ["sporeling"])
	var e1: EnemyCombatant = cr.cb.enemies[0]
	e1.hp = 40
	e1.max_hp = 40
	e1.staggered = false
	e1.statuses["vulnerable"] = 1
	_play(cr, _add(cr, &"resonantLance"), 0)
	_fail(fails, e1.hp == 19, "cracked-only Lance 7*2*1.5=21, hp %d" % e1.hp)
	# Neither — 7.
	var none: GlassvowGame = _fight("k1-neither", 0, ["sporeling"])
	var e2: EnemyCombatant = none.cb.enemies[0]
	e2.staggered = false
	e2.statuses.erase("vulnerable")
	_play(none, _add(none, &"resonantLance"), 0)
	_fail(fails, e2.hp == 13, "neither Lance deals 7, hp %d" % e2.hp)
	# Both — same damage as Cracked-only, staggered still set.
	var both: GlassvowGame = _fight("k1-both", 0, ["sporeling"])
	var e3: EnemyCombatant = both.cb.enemies[0]
	e3.hp = 40
	e3.max_hp = 40
	e3.staggered = true
	e3.statuses["vulnerable"] = 1
	_play(both, _add(both, &"resonantLance"), 0)
	_fail(fails, e3.hp == 19, "staggered+cracked Lance 21, hp %d" % e3.hp)
	_fail(fails, e3.staggered, "staggered flag remains independently observable")


static func _k1_chisel_chip_and_subsets(fails: Array[String]) -> void:
	var ch: GlassvowGame = _fight("k1-chisel", 0, ["sporeling"])
	var e: EnemyCombatant = ch.cb.enemies[0]
	e.facet_max = 4
	e.chips = 0
	_play(ch, _add(ch, &"chisel"), 0)
	_fail(fails, e.hp == 16, "Chisel ordinary hit 4")
	_fail(fails, e.chips == 2, "Chisel implicit 1 + printed extra 1")
	# Proper subset: Strike has the ordinary hit/implicit chip, not printed extra.
	var st: GlassvowGame = _fight("k1-strike", 0, ["sporeling"])
	var e2: EnemyCombatant = st.cb.enemies[0]
	e2.facet_max = 4
	e2.chips = 0
	_play(st, _add(st, &"strike"), 0)
	_fail(fails, e2.chips == 1, "Strike implicit chip only")
	# Threshold + Stun AND Cracked coupling.
	var sh: GlassvowGame = _fight("k1-shatter", 0, ["sporeling"])
	var e3: EnemyCombatant = sh.cb.enemies[0]
	e3.facet_max = 4
	e3.chips = 3
	e3.staggered = false
	_play(sh, _add(sh, &"chisel"), 0)
	_fail(fails, e3.staggered, "Chisel shatter staggers")
	_fail(fails, _ji(e3.statuses.get("vulnerable", 0)) >= 2, "shatter applies Cracked")
	# Direct Cracked + ordinary attack already able to Shatter: not a Lance.
	var dir: GlassvowGame = _fight("k1-direct-crack", 0, ["sporeling"])
	var e4: EnemyCombatant = dir.cb.enemies[0]
	e4.facet_max = 2
	e4.chips = 1
	_play(dir, _add(dir, &"eclipseSlash"), 0)
	_fail(fails, _ji(e4.statuses.get("vulnerable", 0)) >= 1, "Eclipse Slash applies Cracked")
	_fail(fails, e4.staggered, "ordinary connecting hit can Shatter without Lance")


static func _k2_empower_flurry_strength(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight("k2-flurry", 0, ["sporeling"])
	var e: EnemyCombatant = game.cb.enemies[0]
	_play(game, _add(game, &"empower"), 0)
	_fail(fails, _ji(game.cb.player.statuses.get("str", 0)) == 2, "Empower +2 Strength")
	_fail(fails, game.cb.counters_attacks == 0, "Empower is not an Attack")
	var pre_hp: Dictionary = DuskNativeExportReader.pre_hp_map(game.cb)
	var events: Array[Dictionary] = _play(game, _add(game, &"flurry"), 0)
	var hits: Array = _hits(events)
	_fail(fails, hits.size() == 3, "Flurry three sequential hits, got %d" % hits.size())
	if hits.size() != 3:
		return
	_fail(fails, _ji(hits[0].get("amount", 0)) == 4, "hit1 2+2 str")
	_fail(fails, _ji(hits[1].get("amount", 0)) == 4, "hit2 2+2 str")
	_fail(fails, _ji(hits[2].get("amount", 0)) == 4, "hit3 2+2 str")
	_fail(fails, e.hp == 8, "three Strength-boosted hits, hp %d" % e.hp)
	_fail(fails, DuskNativeExportReader.ordinary_hits_precede_first_chip(events, 3),
		"three Flurry hits before this card's first chip")
	_fail(fails, game.cb.counters_attacks == 1, "Flurry counts as one Attack")
	var ritual: GlassvowGame = _fight("k2-ritual", 0, ["sporeling"])
	ritual.cb.player.statuses["str"] = 1
	_play(ritual, _add(ritual, &"empower"), 0)
	_fail(fails, _ji(ritual.cb.player.statuses.get("str", 0)) == 3, "Empower stacks with existing Strength")
	var tal: GlassvowGame = _fight("k2-talisman", 0, ["sporeling"])
	tal.run.player.relics.append("ironTalisman")
	tal.cb.counters_attacks = 2
	_play(tal, _add(tal, &"flurry"), 0)
	_fail(fails, _ji(tal.cb.player.statuses.get("str", 0)) == 1, "Iron Talisman on the third Attack")
	var cap: Dictionary = _cap(game, events, pre_hp, "k2-flurry")
	var obs_v: Variant = DuskNativeExportReader.hit_observations(cap)
	_fail(fails, typeof(obs_v) == TYPE_ARRAY, "reader resolved Flurry hits")
	if typeof(obs_v) == TYPE_ARRAY:
		var obs: Array = obs_v
		_fail(fails, obs.size() == 3, "reader sees three native hits")
		if obs.size() == 3:
			_fail(fails, _ji(obs[0]["physicalHpLoss"]) == 4, "reader physical matches amount")
			var fp: Dictionary = obs[0]["pointer"]
			_fail(fails, DuskNativeExportReader.resolve(fp, cap) != null,
				"Flurry pointer resolves")


static func _mixed_three_roles(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight("mixed")
	_play(game, _add(game, &"empower"), 0)
	_play(game, _add(game, &"setTheAngle"), 0)
	var events: Array[Dictionary] = _play(game, _add(game, &"crosscut"), 1)
	var hits: Array = _hits(events)
	_fail(fails, hits.size() == 2, "Strength applies to both Crosscut hits")
	if hits.size() != 2:
		return
	_fail(fails, _ji(hits[0].get("amount", 0)) == 7, "primary 5+2 str")
	_fail(fails, _ji(hits[1].get("amount", 0)) == 7, "return 5+2 str")
	_play(game, _add(game, &"chisel"), 1)
	var lance: GlassvowGame = _fight("mixed-lance")
	lance.cb.enemies[0].staggered = true
	_play(lance, _add(lance, &"setTheAngle"), 1)
	_play(lance, _add(lance, &"resonantLance"), 0)
	_fail(fails, lance.cb.enemies[0].hp == 6, "Lance on staggered A is not a Crosscut return")
	_fail(fails, lance.cb.has_live_crosscut_anchor(), "Lance does not consume the mark")


static func _both_pool_paths(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var dusk: RunState = RunState.new_run(content, 4211602, "pool-dusk", {"aspect": 0})
	var ash: RunState = RunState.new_run(content, 4211603, "pool-ash", {"aspect": 1})
	var rewards: RewardRules = RewardRules.new(content)
	var dusk_u: Array = rewards.card_pool(dusk, "uncommon")
	var ash_u: Array = rewards.card_pool(ash, "uncommon")
	_fail(fails, dusk_u.has("setTheAngle") and dusk_u.has("crosscut"),
		"Dusk uncommon pool includes both cards")
	_fail(fails, not ash_u.has("setTheAngle") and not ash_u.has("crosscut"),
		"Ash uncommon pool excludes both cards")
	var dusk_wo: Array = []
	for id_v: Variant in dusk_u:
		var id: String = str(id_v)
		if id != "setTheAngle" and id != "crosscut":
			dusk_wo.append(id)
	_fail(fails, dusk_wo == ash_u, "Ash pool restores old uncommon order")
	ash.unlocks.append("card:setTheAngle")
	ash.unlocks.append("card:crosscut")
	var ash_unlock: Array = rewards.card_pool(ash, "uncommon")
	_fail(fails, not ash_unlock.has("setTheAngle") and not ash_unlock.has("crosscut"),
		"Ash unlock path still filters Dusk-only cards")
	dusk.unlocks.append("card:setTheAngle")
	var dusk_unlock: Array = rewards.card_pool(dusk, "uncommon")
	_fail(fails, dusk_unlock.has("setTheAngle"), "Dusk unlock path may still list the card")
	# Reward and shop sampling both call card_pool.
	var shop_ash: Dictionary = rewards.gen_shop(ash)
	var shop_cards: Array = shop_ash.get("cards", [])
	for row_v: Variant in shop_cards:
		var row: Dictionary = row_v
		_fail(fails, str(row.get("id", "")) != "setTheAngle" and str(row.get("id", "")) != "crosscut",
			"Ash shop must not offer Crosscut cards")


static func _v2_save_and_pending_reconstruction(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight("save")
	_play(game, _add(game, &"setTheAngle"), 0)
	_fail(fails, game.cb.has_live_crosscut_anchor(), "mark present before save")
	game.run.pending_combat = "monster"
	game.run.pending_enemy_ids = ["sporeling", "sporeling"]
	var save: Dictionary = game.run.to_save_dict()
	_fail(fails, _ji(save.get("v", 0)) == 2, "v2 envelope")
	_fail(fails, not save.has("crosscut_anchor") and not save.has("crosscutAnchor"),
		"no new serialized mark field")
	var blob: String = JSON.stringify(save)
	_fail(fails, not blob.contains("crosscutAnchor") and not blob.contains("crosscut_anchor"),
		"save JSON has no half-played anchor")
	var loaded: RunState = RunState.from_save_dict(save, game.content)
	_fail(fails, loaded != null, "v2 load accepted")
	if loaded == null:
		return
	native_starts += 1
	var resumed: GlassvowGame = GlassvowGame.new(game.content, loaded)
	resumed.apply({
		"t": "startCombat",
		"enemies": loaded.pending_enemy_ids,
		"kind": "normal",
	})
	_fail(fails, resumed.cb != null and resumed.cb.crosscut_anchor == null,
		"pending reconstruction is marker-free")
	# Old snapshot without the new IDs still loads.
	var old: GlassvowGame = _fight("old-save")
	var old_save: Dictionary = old.run.to_save_dict()
	var old_loaded: RunState = RunState.from_save_dict(old_save, old.content)
	_fail(fails, old_loaded != null, "pre-change v2 snapshot still loads")
	# New-ID deck in the new binary.
	old.run.player.deck.append(CardInst.new(old.run.next_uid(), &"crosscut", false))
	var with_id: Dictionary = old.run.to_save_dict()
	var with_loaded: RunState = RunState.from_save_dict(with_id, old.content)
	_fail(fails, with_loaded != null, "new binary loads its own new-ID save")


static func _marker_and_export_reader(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight("marker")
	_fail(fails, not game.cb.has_live_crosscut_anchor(), "new combat starts unmarked")
	_play(game, _add(game, &"setTheAngle"), 0)
	_fail(fails, game.cb.has_live_crosscut_anchor(), "rules-derived mark after producer")
	var screen_src: String = FileAccess.get_file_as_string("res://presentation/combat/combat_screen.gd")
	_fail(fails, screen_src.contains("set_crosscut_anchor"), "combat screen binds the mark from state")
	_play(game, _add(game, &"crosscut"), 1)
	_fail(fails, not game.cb.has_live_crosscut_anchor(), "rules-derived mark clears on consume")
	var src: String = FileAccess.get_file_as_string("res://presentation/combat/enemy_view.gd")
	_fail(fails, src.contains("set_crosscut_anchor") and src.contains("_crosscut_mark"),
		"marker source exists")
	var cap: Dictionary = _cap(game, game.cb.queue, DuskNativeExportReader.pre_hp_map(game.cb), "marker")
	var plays: Array = DuskNativeExportReader.play_observations(cap)
	_fail(fails, plays.size() >= 2, "reader binds ordered play pointers")
	if plays.size() >= 2:
		_fail(fails, str(plays[0]["id"]) == "setTheAngle", "first play is producer")
		_fail(fails, str(plays[1]["id"]) == "crosscut", "second play is consumer")
		_fail(fails, typeof(plays[0]["pointer"]) == TYPE_DICTIONARY, "pointer is a dict")
		if typeof(plays[0]["pointer"]) == TYPE_DICTIONARY:
			var ptr: Dictionary = plays[0]["pointer"]
			_fail(fails, str(ptr.get("role", "")) == "native_export/N0/v0",
				"pointer uses N0 role")
			_fail(fails, plays[0].get("resolved") == true, "play pointer resolves")


static func _r1_same_command_masks(fails: Array[String]) -> void:
	# Same paid Chisel, printed extra chip off. Strike substitution stays separate.
	var ch: GlassvowGame = _fight("r1-chisel-mask", 0, ["sporeling"])
	var e: EnemyCombatant = ch.cb.enemies[0]
	e.facet_max = 8
	e.chips = 0
	ch.rules.research_mask_printed_chip = true
	_play(ch, _add(ch, &"chisel"), 0)
	_fail(fails, e.hp == 16, "masked Chisel still deals ordinary 4")
	_fail(fails, e.chips == 1, "masked Chisel keeps implicit chip only")
	_fail(fails, ch.cb.player.energy == 9, "masked Chisel still paid 1")
	# Same paid Lance, echo multiplier off; Cracked scaling remains.
	var ln: GlassvowGame = _fight("r1-lance-mask", 0, ["sporeling"])
	var e2: EnemyCombatant = ln.cb.enemies[0]
	e2.hp = 40
	e2.max_hp = 40
	e2.staggered = false
	e2.statuses["vulnerable"] = 1
	ln.rules.research_mask_echo = true
	_play(ln, _add(ln, &"resonantLance"), 0)
	_fail(fails, e2.hp == 40 - 10, "echo-off Lance is 7 then Cracked 1.5 = 10, hp %d" % e2.hp)
	# DD1: mask anchor keeps Block; mask return keeps primary.
	var p_off: GlassvowGame = _fight("r1-anchor-mask")
	p_off.rules.research_mask_anchor = true
	_play(p_off, _add(p_off, &"setTheAngle"), 0)
	_fail(fails, p_off.cb.player.block == 4, "anchor-off still grants Block")
	_fail(fails, p_off.cb.crosscut_anchor == null, "anchor-off does not install marker")
	var c_off: GlassvowGame = _fight("r1-return-mask")
	_play(c_off, _add(c_off, &"setTheAngle"), 0)
	c_off.rules.research_mask_return = true
	var ev: Array[Dictionary] = _play(c_off, _add(c_off, &"crosscut"), 1)
	_fail(fails, _hits(ev).size() == 1, "return-off keeps primary only")
	_fail(fails, c_off.cb.crosscut_anchor == null, "return-off still consumes the mark")
	# Substitutions remain labelled substitutions (not masks).
	var sub: GlassvowGame = _fight("r1-strike-sub", 0, ["sporeling"])
	var e3: EnemyCombatant = sub.cb.enemies[0]
	e3.facet_max = 8
	e3.chips = 0
	_play(sub, _add(sub, &"strike"), 0)
	_fail(fails, e3.chips == 1, "Strike substitution is implicit chip only")


static func _r1_sequential_energy_and_vow(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight("r1-energy")
	game.cb.player.energy = 2
	var p: CardInst = _add(game, &"setTheAngle")
	var c: CardInst = _add(game, &"crosscut")
	_fail(fails, game.cb.player.energy == 2, "_add does not refill energy")
	_play(game, p, 0)
	_fail(fails, game.cb.player.energy == 1, "producer spent 1 of 2")
	_play(game, c, 1)
	_fail(fails, game.cb.player.energy == 0, "consumer spent last energy")
	var extra: CardInst = _add(game, &"setTheAngle")
	game.apply({"t": "playCard", "uid": extra.uid, "target": 0})
	_fail(fails, game.last_ret == false, "third card denied at 0 energy")
	var v5: GlassvowGame = _fight("r1-vow5", 0, ["sporeling", "sporeling"], 5)
	_play(v5, _add(v5, &"setTheAngle"), 0)
	var v5e: Array[Dictionary] = _play(v5, _add(v5, &"crosscut"), 1)
	_fail(fails, _hits(v5e).size() == 2, "vow 5 still delivers return")
	var v5c: GlassvowGame = _fight("r1-vow5-chisel", 0, ["sporeling"], 5)
	v5c.cb.enemies[0].facet_max = 8
	_play(v5c, _add(v5c, &"chisel"), 0)
	_fail(fails, v5c.cb.enemies[0].chips == 2, "vow 5 Chisel still prints extra chip")


static func _r2_ash_marker_and_thorns_preview(fails: Array[String]) -> void:
	var ash: GlassvowGame = _fight("r2-ash-mark", 1)
	_play(ash, _add(ash, &"setTheAngle"), 0)
	_fail(fails, ash.cb.player.block == 4, "Ash Block retained")
	_fail(fails, not ash.cb.has_live_crosscut_anchor(), "Ash public marker absent")
	var th: GlassvowGame = _fight("r2-thorns")
	th.cb.enemies[1].statuses["thorns"] = 3
	_play(th, _add(th, &"setTheAngle"), 0)
	th.cb.player.hp = 2
	th.cb.player.block = 0
	var consumer: CardInst = _add(th, &"crosscut")
	var pv: Variant = th.rules.preview_play(th.cb, consumer, 1, th.run)
	_fail(fails, typeof(pv) == TYPE_DICTIONARY, "thorns preview exists")
	if typeof(pv) == TYPE_DICTIONARY:
		var pvd: Dictionary = pv
		_fail(fails, not pvd.has("return"), "primary-Thorns-lethal preview suppresses return")
	var ev: Array[Dictionary] = _play(th, consumer, 1)
	_fail(fails, th.cb.over, "Thorns 3 kills 2 HP player")
	_fail(fails, _hits(ev).size() == 1, "Thorns-lethal primary suppresses return")


static func _r2_finale_handoff_suppresses_return(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight("r2-finale", 0, ["sporeling", "eternalKeeper"])
	if game.cb == null or game.cb.enemies.size() < 2:
		_fail(fails, false, "finale fight missing")
		return
	var keeper: EnemyCombatant = game.cb.enemies[1]
	keeper.hp = 3
	keeper.max_hp = 3
	_play(game, _add(game, &"setTheAngle"), 0)
	var consumer: CardInst = _add(game, &"crosscut")
	var pv: Variant = game.rules.preview_play(game.cb, consumer, 1, game.run)
	if typeof(pv) == TYPE_DICTIONARY:
		var pvd: Dictionary = pv
		_fail(fails, not pvd.has("return"), "finale-lethal preview suppresses return")
	var ev: Array[Dictionary] = _play(game, consumer, 1)
	_fail(fails, game.cb.finale_handoff or game.cb.over, "keeper lethal is handoff/terminal")
	_fail(fails, _hits(ev).size() == 1, "finale handoff suppresses return")


static func _r3_ordering_negative_and_bell(fails: Array[String]) -> void:
	var bad: Array = [
		{"t": "hitEnemy", "idx": 1, "amount": 5, "hpAfter": 15, "overkill": 0},
		{"t": "chip", "idx": 1, "n": 1},
		{"t": "hitEnemy", "idx": 0, "amount": 5, "hpAfter": 15, "overkill": 0},
		{"t": "chip", "idx": 0, "n": 1},
	]
	_fail(fails, not DuskNativeExportReader.ordinary_hits_precede_first_chip(bad, 2),
		"interleaved hit/chip must fail the ordering predicate")
	var good: Array = [
		{"t": "hitEnemy", "idx": 1},
		{"t": "hitEnemy", "idx": 0},
		{"t": "chip", "idx": 1},
		{"t": "hitEnemy", "idx": 0},
	]
	_fail(fails, DuskNativeExportReader.ordinary_hits_precede_first_chip(good, 2),
		"Bell-like hit after settlement is allowed")
	var missing: Dictionary = DuskNativeExportReader.bind_capture(
		[{"t": "hitEnemy", "idx": 0, "amount": 7}],
		{},
		{"role": "native_export/N0/v0"}
	)
	_fail(fails, DuskNativeExportReader.hit_observations(missing) == null,
		"reader rejects manufactured HP without pre snapshot / hpAfter")
	var bell: GlassvowGame = _fight("r3-bell")
	bell.run.player.relics.append("bellOfEndings")
	var a: EnemyCombatant = bell.cb.enemies[0]
	var b: EnemyCombatant = bell.cb.enemies[1]
	a.hp = 6
	a.max_hp = 6
	b.facet_max = 4
	b.chips = 3
	_play(bell, _add(bell, &"setTheAngle"), 0)
	var ev: Array[Dictionary] = _play(bell, _add(bell, &"crosscut"), 1)
	_fail(fails, DuskNativeExportReader.ordinary_hits_precede_first_chip(ev, 2),
		"Crosscut hits still precede first chip when Bell is armed")
	_fail(fails, a.hp <= 0, "Bell kills anchor A before A's chip can land")
	var chips: Array = DuskNativeExportReader.chip_order(ev)
	var a_chip: bool = false
	for rec_v: Variant in chips:
		var rec: Dictionary = rec_v
		if _ji(rec.get("idx", -1)) == a.idx:
			a_chip = true
	_fail(fails, not a_chip, "dead A receives no chip settlement")


static func _r3_overkill_and_m_fixture(fails: Array[String]) -> void:
	var ov: GlassvowGame = _fight("r3-overkill", 0, ["sporeling"])
	var e: EnemyCombatant = ov.cb.enemies[0]
	e.hp = 2
	e.max_hp = 2
	var pre: Dictionary = DuskNativeExportReader.pre_hp_map(ov.cb)
	var ev: Array[Dictionary] = _play(ov, _add(ov, &"resonantLance"), 0)
	var hits: Array = _hits(ev)
	_fail(fails, hits.size() == 1, "overkill one hit")
	if hits.size() == 1:
		_fail(fails, _ji(hits[0].get("amount", 0)) == 7, "reported amount 7")
		_fail(fails, _ji(hits[0].get("overkill", 0)) == 5, "overkill 5")
		_fail(fails, _ji(hits[0].get("hpAfter", -1)) == 0, "hpAfter 0")
	var cap: Dictionary = _cap(ov, ev, pre, "overkill")
	var obs_v: Variant = DuskNativeExportReader.hit_observations(cap)
	if typeof(obs_v) == TYPE_ARRAY:
		var obs: Array = obs_v
		_fail(fails, obs.size() == 1 and _ji(obs[0]["physicalHpLoss"]) == 2,
			"physical HP removed is 2, not reported 7")
	# M fixture via SaveService, not an overlay-minted save labelled as recovered.
	var content: ContentDB = ContentDB.load_full(false)
	var raw: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://port_fixtures/saves/snapshots.json")
	)
	_fail(fails, typeof(raw) == TYPE_DICTIONARY, "M snapshot fixture readable")
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var root: Dictionary = raw
	var snapshots: Array = root.get("snapshots", [])
	_fail(fails, snapshots.size() > 0, "M snapshot list")
	if snapshots.is_empty():
		return
	var entry: Dictionary = snapshots[0]
	var snapshot: Dictionary = entry["snapshot"]
	var save: Dictionary = snapshot.duplicate(true)
	save["v"] = 2
	save["runId"] = "dd1-m-fixture"
	save["map"] = {"nodes": [], "visited": []}
	save["pendingCombat"] = "monster"
	save["pendingEnemyIds"] = ["sporeling", "sporeling"]
	var path: String = "user://dd1_m_fixture_v2.json"
	var rs: RunState = RunState.from_save_dict(save, content)
	_fail(fails, rs != null, "M fixture from_save_dict accepted")
	if rs == null:
		return
	_fail(fails, SaveService.store(rs, path), "SaveService stored M fixture")
	var loaded: RunState = SaveService.load_run(content, path)
	_fail(fails, loaded != null, "SaveService.load_run is the application load seam")
	if loaded == null:
		return
	native_starts += 1
	var resumed: GlassvowGame = GlassvowGame.new(content, loaded)
	resumed.apply({
		"t": "startCombat",
		"enemies": loaded.pending_enemy_ids,
		"kind": "normal",
	})
	_fail(fails, resumed.cb != null and resumed.cb.crosscut_anchor == null,
		"M-fixture pending resume is marker-free")
	SaveService.clear(path)


static func _r3_byte_root_controls(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight("byte-root", 0, ["sporeling"])
	var e: EnemyCombatant = game.cb.enemies[0]
	e.hp = 20
	var pre: Dictionary = DuskNativeExportReader.pre_hp_map(game.cb)
	var ev: Array[Dictionary] = _play(game, _add(game, &"strike"), 0)
	var cap: Dictionary = _cap(game, ev, pre, "byte-root")
	_fail(fails, cap.has("bytes") and str(cap["bytes"]).contains("\"role\""),
		"serialized payload contains role")
	_fail(fails, str(cap.get("digest", "")) == DuskNativeExportReader.digest_bytes(str(cap["bytes"])),
		"bind_capture digest matches bytes")
	var intact: Variant = DuskNativeExportReader.hit_observations(cap)
	_fail(fails, typeof(intact) == TYPE_ARRAY and (intact as Array).size() == 1,
		"intact byte roundtrip resolves one hit")
	if typeof(intact) == TYPE_ARRAY and (intact as Array).size() == 1:
		var row: Dictionary = intact[0]
		_fail(fails, _ji(row["physicalHpLoss"]) == _ji(row["amount"]),
			"observations match the resolved record")
		var resolved_v: Variant = DuskNativeExportReader.resolve(row["pointer"], cap)
		_fail(fails, typeof(resolved_v) == TYPE_DICTIONARY, "pointer resolves from bytes")
		if typeof(resolved_v) == TYPE_DICTIONARY:
			var resolved: Dictionary = resolved_v
			_fail(fails, _ji(resolved.get("amount", -1)) == _ji(row["amount"]),
				"resolved event amount equals observation")
	var bytes_only: Dictionary = {
		"bytes": cap["bytes"],
		"digest": cap["digest"],
	}
	_fail(fails, typeof(DuskNativeExportReader.hit_observations(bytes_only)) == TYPE_ARRAY,
		"observations succeed from bytes with companions dropped")
	var mutated: Dictionary = cap.duplicate(true)
	var events_v: Variant = mutated["events"]
	var events: Array = events_v
	var first: Dictionary = events[0].duplicate(true)
	first["amount"] = 999
	events[0] = first
	mutated["events"] = events
	_fail(fails, DuskNativeExportReader.hit_observations(mutated) == null,
		"companion-only mutation is rejected")
	mutated["events"] = cap["events"]
	_fail(fails, typeof(DuskNativeExportReader.hit_observations(mutated)) == TYPE_ARRAY,
		"restoring the companion input succeeds")
	var digest_mismatch: Dictionary = cap.duplicate(true)
	digest_mismatch["bytes"] = str(cap["bytes"]).replace("strike", "XXXXXX")
	_fail(fails, DuskNativeExportReader.hit_observations(digest_mismatch) == null,
		"bytes changed without the bound digest fail")
	var malformed: Dictionary = cap.duplicate(true)
	malformed["bytes"] = "{"
	malformed["digest"] = DuskNativeExportReader.digest_bytes("{")
	_fail(fails, DuskNativeExportReader.hit_observations(malformed) == null,
		"malformed payload fails")
	var wrong_role: Dictionary = {"role": "native_export/OTHER/v0", "path": ["events", 0]}
	_fail(fails, DuskNativeExportReader.resolve(wrong_role, cap) == null,
		"wrong capture identity/role fails")
	var wrong_path: Dictionary = {"role": "native_export/N0/v0", "path": ["events", 99]}
	_fail(fails, DuskNativeExportReader.resolve(wrong_path, cap) == null,
		"wrong path fails")
	var pub: String = "user://dd1_reader_capture_bytes.json"
	var f: FileAccess = FileAccess.open(pub, FileAccess.WRITE)
	_fail(fails, f != null, "could not write capture bytes")
	if f != null:
		f.store_string(str(cap["bytes"]))
		f.close()
	var qpath: String = "res://research/p9-six-route/dusk-design-1-20260916/native-qualification/reader-capture-bytes.json"
	var qf: FileAccess = FileAccess.open(qpath, FileAccess.WRITE)
	if qf != null:
		qf.store_string(JSON.stringify({
			"digest": cap["digest"],
			"bytes": cap["bytes"],
			"tag": "byte-root",
		}))
		qf.close()
