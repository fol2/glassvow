extends RefCounted
## #211 bake-off pins: empty mix is identity, startHex is dead, smoke suite runs.

const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Incentives: GDScript = preload("res://tools/vow_incentives.gd")
const Bakeoff: GDScript = preload("res://tools/vow_ladder_bakeoff.gd")
const Clock: GDScript = preload("res://tools/vigil_clock.gd")


static func run(fails: Array[String]) -> void:
	_empty_mix_is_identity(fails)
	_isolate_deadhex_vs_empty1(fails)
	_isolate_unknown_is_a_no_op(fails)
	_smoke_suite_runs(fails)
	_clock_formula(fails)


static func _empty_mix_is_identity(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var rewards: RewardRules = RewardRules.new(content)
	if rewards.rarity_shift != 0.0 or rewards.rarity_uncommon_only \
			or rewards.gold_vow_mult != 1.0 or rewards.elite_relic_second != 0.0:
		fails.append("vow bakeoff: RewardRules defaults must be the shipping identity")
	Incentives.apply(rewards, {}, 5)
	Incentives.apply(rewards, Incentives.by_id("none"), 5)
	if rewards.rarity_shift != 0.0 or rewards.gold_vow_mult != 1.0 \
			or rewards.elite_relic_second != 0.0:
		fails.append("vow bakeoff: empty / none mix must leave knobs untouched")
	var bare: Dictionary = Sim.simulate(content, "duskblade", 1000, 0)
	var empty_mix: Dictionary = Sim.simulate(content, "duskblade", 1000, 0,
		PackedStringArray(), {}, false, false, {})
	var none_mix: Dictionary = Sim.simulate(content, "duskblade", 1000, 0,
		PackedStringArray(), {}, false, false, Incentives.by_id("none"))
	if Sim.outcome_digest(bare) != Sim.outcome_digest(empty_mix):
		fails.append("vow bakeoff: empty mix must match the no-mix digest")
	if Sim.outcome_digest(bare) != Sim.outcome_digest(none_mix):
		fails.append("vow bakeoff: catalog none must match the no-mix digest")


static func _isolate_deadhex_vs_empty1(fails: Array[String]) -> void:
	var dead_content: ContentDB = ContentDB.load_full(false)
	var dead_spec: Dictionary = Incentives.isolate(dead_content, "deadhex")
	var empty_content: ContentDB = ContentDB.load_full(false)
	var empty_spec: Dictionary = Incentives.isolate(empty_content, "empty1")
	var mark_content: ContentDB = ContentDB.load_full(false)
	var mark_spec: Dictionary = Incentives.isolate(mark_content, "mark")
	if dead_spec.has("error") or empty_spec.has("error") or mark_spec.has("error"):
		fails.append("vow bakeoff: isolate names deadhex / empty1 / mark must resolve")
		return
	var dead_vow: int = int(float(str(dead_spec["vow"])))
	var empty_vow: int = int(float(str(empty_spec["vow"])))
	var mark_vow: int = int(float(str(mark_spec["vow"])))
	if dead_vow != 1 or empty_vow != 1 or mark_vow != 4:
		fails.append("vow bakeoff: isolate vows expected deadhex=1 empty1=1 mark=4")
	var dead_mods: Dictionary = dead_content.vows[0].get("mods", {})
	if dead_mods.get("startHex", false) != true:
		fails.append("vow bakeoff: deadhex must plant startHex on vow 1")
	var empty_mods: Dictionary = empty_content.vows[0].get("mods", {})
	if empty_mods.get("startHex", false) == true:
		fails.append("vow bakeoff: empty1 must not plant startHex")
	if _hex_count(_fresh_run(dead_content, dead_vow)) != 0:
		fails.append("vow bakeoff: deadhex at vow 1 must not add Hex (startHex is dead)")
	if _hex_count(_fresh_run(empty_content, empty_vow)) != 0:
		fails.append("vow bakeoff: empty1 at vow 1 must not add Hex")
	if _hex_count(_fresh_run(mark_content, mark_vow)) < 1:
		fails.append("vow bakeoff: mark at vow 4 must add Hex via vow >= 4")
	var dead_row: Dictionary = Sim.simulate(dead_content, "duskblade", 7000, dead_vow)
	var empty_row: Dictionary = Sim.simulate(empty_content, "duskblade", 7000, empty_vow)
	if Sim.outcome_digest(dead_row) != Sim.outcome_digest(empty_row):
		fails.append("vow bakeoff: deadhex isolate must match empty1 (startHex is unused)")


static func _isolate_unknown_is_a_no_op(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var before: Dictionary = content.vows[0].get("mods", {})
	var spec: Dictionary = Incentives.isolate(content, "A_modest_linear")
	if not spec.has("error"):
		fails.append("vow bakeoff: unknown isolate name must error")
	var after: Dictionary = content.vows[0].get("mods", {})
	if after.get("hpMult", 0) != before.get("hpMult", 0):
		fails.append("vow bakeoff: unknown isolate must not strip vow mods")


static func _smoke_suite_runs(fails: Array[String]) -> void:
	var opts: Dictionary = Bakeoff._options(PackedStringArray(["--suite=smoke", "--runs=2"]))
	if opts.has("error") or str(opts.get("suite", "")) != "smoke":
		fails.append("vow bakeoff: --suite=smoke must parse")
		return
	var cells: Array[Dictionary] = Bakeoff._run_smoke()
	if cells.size() != 2:
		fails.append("vow bakeoff: smoke suite expected 2 cells, got %d" % cells.size())
		return
	var first: Dictionary = cells[0]
	var second: Dictionary = cells[1]
	if str(first.get("kind", "")) != "ladder" or int(float(str(first.get("vow", -1)))) != 0:
		fails.append("vow bakeoff: smoke cell 0 must be ladder vow 0")
	if str(second.get("isolate", "")) != "deadhex":
		fails.append("vow bakeoff: smoke cell 1 must isolate deadhex")
	for cell: Dictionary in cells:
		for aspect: String in ["duskblade", "ashwarden"]:
			if not cell.has(aspect):
				fails.append("vow bakeoff: smoke cell missing %s" % aspect)
				continue
			var arm: Dictionary = cell[aspect]
			if int(float(str(arm.get("runs", 0)))) != 2:
				fails.append("vow bakeoff: smoke %s runs expected 2" % aspect)


static func _clock_formula(fails: Array[String]) -> void:
	if Clock.expected_wins(0.5, 10) != 20.0:
		fails.append("vow bakeoff: expected_wins(0.5, 10) must be 20")
	if Clock.expected_wins(0.0, 10) != INF:
		fails.append("vow bakeoff: expected_wins at p=0 must be INF")
	if Clock.expected_own_shade(0.5) != 10.0:
		fails.append("vow bakeoff: expected_own_shade(0.5) must be 2/0.5 + 3/0.5 = 10")


static func _fresh_run(content: ContentDB, vow: int) -> RunState:
	return RunState.new_run(content, 7000, "iso-%d" % vow, {
		"aspect": 0, "vow": vow, "reveals": [], "unlocks": [],
	})


static func _hex_count(run: RunState) -> int:
	var n: int = 0
	for card: CardInst in run.player.deck:
		if card.id == &"hex":
			n += 1
	return n
