extends RefCounted
## Act IV authored map: five-node line, no omen, fail-closed encounters, and
## first-clear pins versus repeat-run redraw from `encounters[3]`.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_act4_map: %s" % what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var first: RunState = _act4_run(content, 401, [])
	var road: WorldMap = WorldMap.act4(first, content)
	_check(fails, road.region == "rose_window" and road.nodes.size() == 5,
		"authored map is five rose_window waystones")
	var types: Array[String] = []
	for n: MapNode in road.nodes:
		types.append(n.type)
	_check(fails, types == ["monster", "monster", "elite", "rest", "boss"],
		"types are monster → monster → elite → rest → boss")
	_check(fails, road.reachable() == [0], "the road opens on n0 only")
	_check(fails, road.nodes[0].enemies == ["unopenedSelf"],
		"threshold-prime pins unopenedSelf")
	_check(fails, not road.nodes[0].enemies.has("uncarvedSelf"),
		"threshold elite stays in the repeat pool")
	_check(fails, road.nodes[1].enemies == ["unobsidianSelf", "unwalkedSelf"],
		"III-prime pins both landed normals")
	_check(fails, road.nodes[2].enemies == ["uncrossedSelf", "unsunkSelf"],
		"II-prime elite pins both axes")
	_check(fails, road.nodes[3].enemies.is_empty(),
		"I-prime rest stays empty on first clear")
	_check(fails, road.nodes[4].enemies == ["eternalKeeper"],
		"hearth-prime pins the Eternal Keeper")
	_check(fails, not road.nodes[0].unlit and road.nodes[0].bounty == 0,
		"the authored line carries no unlit bounty")
	var copy: WorldMap = WorldMap.from_dict(road.to_dict())
	_check(fails, copy != null and copy.nodes.size() == 5
			and copy.nodes[0].enemies == ["unopenedSelf"]
			and copy.nodes[1].enemies == ["unobsidianSelf", "unwalkedSelf"]
			and copy.nodes[2].enemies == ["uncrossedSelf", "unsunkSelf"]
			and copy.nodes[4].enemies == ["eternalKeeper"],
		"authored occupants survive the save projection")
	var generated: WorldMap = WorldMap.for_run(_act4_run(content, 402, []), content)
	_check(fails, generated.nodes.size() == 5,
		"for_run at act 3 returns the authored line, not benchmark()")
	var early: RunState = RunState.new_run(content, 403, "run-act4-early")
	_check(fails, WorldMap.for_run(early, content).nodes.size() > 5,
		"for_run at act 0 stays generated")

	var climb: RunState = RunState.new_run(content, 404, "run-act4-omen", {
		"reveals": null, "shards": VigilState.QUEST_IDS.duplicate(),
	})
	climb.start_next_act(content)
	climb.start_next_act(content)
	climb.start_next_act(content)
	_check(fails, climb.act == 3 and climb.omens.size() == 4 and climb.omens[3] == null,
		"entering Act IV pads a null omen rather than rolling one")
	var ordinary: RunState = RunState.new_run(content, 405, "run-act3-omen", {"reveals": null})
	ordinary.start_next_act(content)
	ordinary.start_next_act(content)
	_check(fails, ordinary.act == 2 and ordinary.omens.size() == 3
			and ordinary.omens[2] != null,
		"an ordinary final act still rolls an omen")

	var rewards: RewardRules = RewardRules.new(content)
	var truncated: ContentDB = ContentDB.load_full()
	truncated.encounters = truncated.encounters.slice(0, 3)
	var hollow: RunState = _act4_run(truncated, 406, [])
	var rolled: Array[String] = RewardRules.new(truncated).roll_encounter(hollow, "monster", 0)
	_check(fails, rolled.is_empty(),
		"act 3 with no encounters[3] fails closed")
	_check(fails, not rolled.has("sporeling"),
		"act 3 does not clamp to the Act I weak pool")
	var live: Array[String] = rewards.roll_encounter(_act4_run(content, 410, []), "monster", 0)
	_check(fails, not live.is_empty() and not live.has("sporeling"),
		"act 3 with a pool draws Act IV normals, not Act I weak")
	var act0: RunState = RunState.new_run(content, 407, "run-weak-row")
	var weak: Array[String] = rewards.roll_encounter(act0, "monster", 0)
	_check(fails, not weak.is_empty(), "act 0 row 0 still draws the weak pool")

	var injected: ContentDB = ContentDB.load_full()
	var rows: Array = injected.encounters.duplicate(true)
	rows[3] = {
		"normal": [["unwalkedSelf"], ["uncrossedSelf"]],
		"elite": [["uncrossedSelf"], ["unwalkedSelf"]],
		"boss": [["eternalKeeper"]],
	}
	injected.encounters = rows
	var authored: WorldMap = WorldMap.act4(_act4_run(injected, 408, []), injected)
	_check(fails, authored.nodes[0].enemies == ["unopenedSelf"]
			and authored.nodes[1].enemies == ["unobsidianSelf", "unwalkedSelf"]
			and authored.nodes[2].enemies == ["uncrossedSelf", "unsunkSelf"]
			and authored.nodes[4].enemies == ["eternalKeeper"],
		"first clear pins motifs even when a pool is present")
	var repeat: WorldMap = WorldMap.act4(
		_act4_run(injected, 409, [RunState.MIRRORED_ROAD]), injected)
	_check(fails, repeat.nodes[4].enemies == ["eternalKeeper"],
		"repeat runs keep the authored boss")
	_check(fails, repeat.nodes[0].type == "monster" and repeat.nodes[2].type == "elite"
			and repeat.nodes[3].type == "rest",
		"repeat runs keep node types and order")
	var from_pool: bool = _in_pool(repeat.nodes[0].enemies, [["unwalkedSelf"], ["uncrossedSelf"]]) \
		and _in_pool(repeat.nodes[2].enemies, [["uncrossedSelf"], ["unwalkedSelf"]])
	_check(fails, from_pool, "repeat monsters and elite draw from the act-4 pool")
	var prod_repeat: WorldMap = WorldMap.act4(
		_act4_run(content, 411, [RunState.MIRRORED_ROAD]), content)
	_check(fails, prod_repeat.nodes[4].enemies == ["eternalKeeper"]
			and prod_repeat.nodes[3].enemies.is_empty(),
		"production repeat keeps the Keeper and empty rest")
	_check(fails, _in_pool(prod_repeat.nodes[0].enemies, [
			["unopenedSelf", "uncarvedSelf"],
			["unwalkedSelf", "unobsidianSelf"],
			["uncrossedSelf", "unsunkSelf"],
			["unlitSelf", "unwoodedSelf"],
		]) and _in_pool(prod_repeat.nodes[2].enemies, [["unsunkSelf"], ["uncarvedSelf"]]),
		"production repeat draws from encounters[3]")

	climb.omens = climb.omens.slice(0, 3)
	var parsed: Variant = JSON.parse_string(JSON.stringify(climb.to_save_dict()))
	_check(fails, typeof(parsed) == TYPE_DICTIONARY, "Act IV save encoded")
	if typeof(parsed) == TYPE_DICTIONARY:
		var raw: Dictionary = parsed
		var loaded: RunState = RunState.from_save_dict(raw, content)
		_check(fails, loaded != null and loaded.omens.size() == 4 and loaded.omens[3] == null,
			"save top-up does not roll an Act IV omen")
	climb.mark_mirrored_road_cleared()
	_check(fails, climb.unlocks.has(RunState.MIRRORED_ROAD),
		"a final-act win records mirroredRoad")


static func _act4_run(content: ContentDB, seed: int, extra_unlocks: Array) -> RunState:
	var profile: Dictionary = {
		"reveals": null,
		"shards": VigilState.QUEST_IDS.duplicate(),
		"unlocks": extra_unlocks.duplicate(),
	}
	var run: RunState = RunState.new_run(content, seed, "run-act4-%d" % seed, profile)
	run.act = 3
	return run


static func _in_pool(got: Array[String], groups: Array) -> bool:
	for group_v: Variant in groups:
		if typeof(group_v) != TYPE_ARRAY:
			continue
		var group: Array = group_v
		if group.size() != got.size():
			continue
		var same: bool = true
		for i: int in range(got.size()):
			if str(group[i]) != got[i]:
				same = false
				break
		if same:
			return true
	return false
