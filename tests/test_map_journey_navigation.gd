extends RefCounted
const Navigation = preload("res://presentation/map/map_journey_navigation.gd")
static func run(fails: Array[String]) -> void:
	Locale.active = Locale.new(&"en")
	var content: ContentDB = ContentDB.load_full()
	Locale.active.hydrate_content(content)
	var run: RunState = RunState.new_run(content,4)
	var world: WorldMap = WorldMap.for_run(run,content)
	var before: String = JSON.stringify(world.to_dict())
	var rng_before: int = run.rng_state()
	var navigation: Navigation = Navigation.new()
	navigation.synchronise(world)
	var requested: Array[int] = []
	navigation.travel_requested.connect(func(index: int) -> void: requested.append(index))
	var entrances: Array[int] = world.reachable()
	for entrance: int in entrances:
		navigation.show_overview()
		navigation._confirm()
		if not requested.is_empty():
			fails.append("journey navigation: overview entered an encounter")
		navigation.inspect(entrance)
		if navigation.overview or not navigation.context_indices().has(entrance):
			fails.append("journey navigation: entrance unavailable through area inspection")
		if not requested.is_empty():
			fails.append("journey navigation: area inspection travelled before confirmation")
		navigation._confirm()
		if requested != [entrance]:
			fails.append("journey navigation: confirmation did not request the exact entrance")
		requested.clear()
		navigation.set_locked(true)
		navigation._confirm()
		if not requested.is_empty():
			fails.append("journey navigation: locked confirmation requested travel")
		navigation.set_locked(false)
	# An inspected future stop remains information, never an illegal shortcut.
	var future: int = world.nodes.size()-1
	navigation.show_overview()
	navigation.inspect(future)
	navigation._confirm()
	if not requested.is_empty():
		fails.append("journey navigation: future destination requested illegal travel")
	if JSON.stringify(world.to_dict()) != before or run.rng_state() != rng_before:
		fails.append("journey navigation: inspection mutated graph or campaign RNG")
	navigation.free()
