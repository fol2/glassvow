extends RefCounted
## M6: the pilgrimage graph gates where the lantern may go, and the map screen
## refuses anything the graph refuses. Covers the slice strip shape, the
## reachability walk, and the rest-site heal law.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map: %s" % what)


static func run(fails: Array[String]) -> void:
	# ---- one representative benchmark seed: full generator, one RNG stream
	var benchmark_content: ContentDB = ContentDB.load_slice()
	var benchmark_run: RunState = RunState.new_run(benchmark_content, 717, "run-map-golden")
	var generated: WorldMap = WorldMap.benchmark(benchmark_run)
	var type_counts: Dictionary = {}
	var unlit: Array[String] = []
	for generated_node: MapNode in generated.nodes:
		type_counts[generated_node.type] = int(float(str(type_counts.get(generated_node.type, 0)))) + 1
		if generated_node.unlit:
			unlit.append("%s:%d" % [generated_node.id, generated_node.bounty])
	_check(fails, generated.nodes.size() == 65, "benchmark seed 717 has 65 joined nodes")
	_check(fails, type_counts == {
		"monster": 34, "event": 9, "elite": 5, "treasure": 5,
		"shop": 2, "rest": 9, "boss": 1,
	}, "benchmark seed 717 node type distribution")
	_check(fails, generated.reachable().size() == 4, "seed 717 opens four distinct row-zero nodes")
	_check(fails, unlit == ["1,3:17", "6,3:17", "11,5:13", "9,5:14", "3,2:20", "7,0:20"],
		"seed 717 unlit bounty trace")
	_check(fails, benchmark_run.rng_state() == 721837281, "seed 717 consumes the benchmark RNG trace")
	var generated_copy: WorldMap = WorldMap.from_dict(generated.to_dict())
	_check(fails, generated_copy != null and generated_copy.nodes.size() == 65,
		"benchmark map survives its save projection")
	# ---- one lifecycle law: bosses move through all three authored acts
	var full: ContentDB = ContentDB.load_full()
	var lifecycle: RunState = RunState.new_run(full, 919, "run-three-acts", {"reveals": null})
	lifecycle.player.hp = 1
	lifecycle.start_next_act(full)
	var second: WorldMap = WorldMap.benchmark(lifecycle)
	lifecycle.player.hp = 1
	lifecycle.start_next_act(full)
	var third: WorldMap = WorldMap.benchmark(lifecycle)
	_check(fails, lifecycle.act == 2 and lifecycle.omens.size() == 3,
		"two boss transitions reach the third act with one omen per act")
	_check(fails, second.region == "sunken_city" and third.region == "obsidian_spire",
		"boss transitions replace the map theme")
	_check(fails, lifecycle.player.hp == 26,
		"each boss transition mends 35 percent without exceeding max HP")

	# ---- the authored strip matches the M5 encounter ladder (brief §4)
	var m: WorldMap = WorldMap.slice()
	_check(fails, m.region == "ashen_woods", "slice region is the Ashen Woods")
	_check(fails, m.nodes.size() == 5, "slice has 5 waystones")
	var types: Array[String] = []
	for n: MapNode in m.nodes:
		types.append(n.type)
	_check(fails, types == ["monster", "monster", "monster", "rest", "elite"],
		"strip reads monster×3 → rest → elite")
	_check(fails, m.nodes[0].enemies == ["sporeling", "sporeling"], "n0 is the sporeling pair")
	_check(fails, m.nodes[1].enemies == ["duskfang"], "n1 duskfang")
	_check(fails, m.nodes[2].enemies == ["waylayer"], "n2 waylayer")
	_check(fails, m.nodes[4].enemies == ["gravewarden"], "n4 gravewarden")
	_check(fails, m.nodes[4].affix == null, "elite affix stays null — start_combat rolls it")
	_check(fails, m.nodes[0].combat_kind() == "normal", "monster starts a normal combat")
	_check(fails, m.nodes[4].combat_kind() == "elite", "elite starts an elite combat")
	_check(fails, not m.nodes[3].is_combat(), "rest is not a fight")
	for i: int in range(m.nodes.size()):
		_check(fails, m.nodes[i].world_x == i, "n%d sits at world_x %d" % [i, i])

	# ---- reachability: stand on it, or step to an out-edge
	_check(fails, m.reachable() == [0], "the road opens on n0 only")
	_check(fails, not m.enter(3), "cannot skip ahead to the rest site")
	_check(fails, m.at == 0, "a refused move leaves the marker seated")
	_check(fails, m.enter(0), "entering the node under the marker is legal")
	_check(fails, m.reachable() == [0], "an unresolved node stays the only choice")
	m.clear_current()
	_check(fails, m.is_cleared(0), "n0 reads cleared")
	_check(fails, m.reachable() == [1], "clearing n0 opens n1")
	for i: int in range(1, 5):
		_check(fails, m.enter(i), "walk reaches n%d" % i)
		m.clear_current()
	_check(fails, m.is_finished(), "the strip ends after the elite")

	# ---- the screen never opens a road the graph closed
	var content: ContentDB = ContentDB.load_slice()
	var walk: WorldMap = WorldMap.slice()
	var screen: WorldMapScreen = WorldMapScreen.new(walk, content)
	screen.instant = true
	var seen: Array[int] = []
	screen.node_chosen.connect(func(i: int) -> void: seen.append(i))
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	# The far bands' bleed must cover the drift they are painted with, and the
	# strip filenames must stay 1-based against 0-based act indices.
	_check(fails, MapBand.FAR_BLEED >= WorldMapScreen.PATH_DRIFT_AMP.y / 3.0,
		"far-band bleed covers the far drift amplitude")
	_check(fails, MapStrip.path_for(0, &"skyband")
		== "res://assets/art/map/act1-skyband.png", "strip paths are 1-based")
	_check(fails, MapRegions.SPIRE_W_RATE.size() == 3
		and MapRegions.SPIRE_H_RATE.size() == 3
		and MapRegions.SPIRE_DARKEN.size() == 3, "spire ramps cover three acts")
	_check(fails, screen._waystones.size() == 5, "one waystone per node")
	_check(fails, not screen.choose(2), "screen refuses an unreachable waystone")
	_check(fails, seen.is_empty(), "a refused choice hands off nothing")
	_check(fails, screen.choose(0), "screen accepts the open waystone")
	_check(fails, seen == [0], "arrival hands the node index to the router")
	_check(fails, walk.at == 0, "the graph moved with the marker")
	screen.refresh(null)
	_check(fails, screen._waystones[0].reachable, "n0 is still live until it is cleared")
	walk.clear_current()
	screen.refresh(null)
	_check(fails, screen._waystones[0].cleared and not screen._waystones[0].reachable,
		"a cleared waystone goes dark")
	_check(fails, screen._waystones[1].reachable, "and lights the next one")
	tree.root.remove_child(screen)
	screen.free()

	# ---- rest heals 30% of max HP, clamped (web engine.js restHealFrac)
	_check(fails, Main.rest_heal_amount(72) == 22, "rest heals 22 of a 72 HP pool")
	_check(fails, Main.rest_heal_amount(0) == 0, "no pool, no heal")
