extends RefCounted
## M6: the pilgrimage graph gates where the lantern may go, and the map screen
## refuses anything the graph refuses. Covers the slice strip shape, the
## reachability walk, and the rest-site heal law.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map: %s" % what)


static func run(fails: Array[String]) -> void:
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
