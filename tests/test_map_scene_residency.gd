extends RefCounted
## Route changes retain one inactive map and release it when the run ends.
static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var run: RunState = RunState.new_run(content,717,"map-residency")
	var main: Main = Main.new()
	main.game = GlassvowGame.new(content,run)
	var world: WorldMap = WorldMap.benchmark(run)
	var first: WorldMapScreen = WorldMapScreen.new(world,content)
	main.add_child(first)
	main._map_screen = first
	main._freeze_count = 1
	main._frozen_under_modal = first
	first.process_mode = Node.PROCESS_MODE_DISABLED
	main._clear_route()
	if main._parked_map_screen!=first or main._map_screen!=null or first.visible or first.process_mode!=Node.PROCESS_MODE_DISABLED or first.is_queued_for_deletion():
		fails.append("map residency: leaving the map did not retain an inactive scene")
	main._clear_route()
	if main._parked_map_screen!=first or first.is_queued_for_deletion():
		fails.append("map residency: subsequent encounter routes discarded the retained map")
	var second: WorldMapScreen = WorldMapScreen.new(world,content)
	main.add_child(second)
	main._map_screen = second
	main._clear_route()
	if main._parked_map_screen!=second or not first.is_queued_for_deletion():
		fails.append("map residency: replacing a map retained more than one scene")
	main.game = null
	main._clear_route()
	if main._parked_map_screen!=null or not second.is_queued_for_deletion():
		fails.append("map residency: ending the run retained its map")
	main.free()
