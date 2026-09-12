extends SceneTree
## Design-study export only. Does not mutate game state outside temporary runs.

const OUT: String = "res://docs/map/studies/camera-composition/"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Locale.active = Locale.new(&"en")
	var content: ContentDB = ContentDB.load_full()
	Locale.active.hydrate_content(content)
	var survey: Array = []
	var dense_seed: int = 7
	var dense_score: int = -1
	for seed_value: int in range(1, 21):
		var run: RunState = RunState.new_run(content, seed_value)
		var world: WorldMap = WorldMap.for_run(run, content)
		var bound: Dictionary = MapLayoutInputBinding.bind(world, 0)
		var branches: int = 0
		for node: MapNode in world.nodes:
			if node.next.size() > 1:
				branches += 1
		var score: int = bound["nodes"].size() + bound["edges"].size()
		survey.append({"seed": seed_value, "nodes": bound["nodes"].size(),
			"edges": bound["edges"].size(), "branches": branches})
		if score > dense_score:
			dense_score = score
			dense_seed = seed_value
	_write("survey.json", {"selection": "maximum nodes plus edges among seeds 1–20, Act I",
		"selected_seed": dense_seed, "rows": survey})
	var samples: Array = []
	for act: int in range(4):
		var sample: Dictionary = _sample(content, act, 717)
		if sample.is_empty():
			quit(1)
			return
		samples.append(sample)
	_write("generated-layouts.json", {"source_head": "2ed6cdb0302ba3aab5845a18d862841165e8aaf7",
		"engine": Engine.get_version_info()["string"], "samples": samples})
	print("STUDY_EXPORT_OK ", samples.size())
	quit(0)

func _sample(content: ContentDB, act: int, seed_value: int) -> Dictionary:
	var run: RunState = RunState.new_run(content, seed_value)
	run.act = act
	var world: WorldMap = WorldMap.for_run(run, content)
	var bound: Dictionary = MapLayoutInputBinding.bind(world, act)
	if bound.get("ok") != true:
		push_error(str(bound))
		return {}
	var scene: MapScene = MapScene.new()
	scene.set_scatter_salt(seed_value + WorldMapScreen.SCENERY_SEED_OFFSET)
	scene.set_act(act)
	var assets: Dictionary = scene.layout_asset_bundle()
	var nodes: Array = bound["nodes"]
	var edges: Array = bound["edges"]
	var quality: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/map-quality-v2.json"))
	var input: MapLayoutInput = MapLayoutInput.from_dict({
		"schema_version": MapLayoutInput.SCHEMA_VERSION,
		"generator_schema": "map-compiler-v2", "generator_version": MapLayoutCompiler.VERSION,
		"nodes": bound["nodes"], "edges": bound["edges"], "act": act,
		"run_seed": seed_value, "scenery_seed": seed_value + WorldMapScreen.SCENERY_SEED_OFFSET,
		"asset_profile_digest": assets["digest"],
		"camera_profile_digest": MapQualityEvaluator.camera_registry(nodes, quality, edges)["digest"],
		"hero_anchor_contract": scene.layout_hero_contract(),
		"quality_registry_digest": MapLayoutCanonical.digest(quality)})
	print("STUDY_INPUT act=", act + 1, " seed=", seed_value, " digest=", input.digest())
	var cache_path: String = "/tmp/glassvow-map-preview-cache/".path_join(input.digest() + ".bin")
	var compiled: Dictionary = {}
	if FileAccess.file_exists(cache_path):
		var file: FileAccess = FileAccess.open(cache_path, FileAccess.READ)
		var raw: Variant = file.get_var(false)
		if raw is Dictionary and str(raw.get("input_digest", "")) == input.digest():
			var record: Dictionary = raw
			var cached: MapLayoutResult = MapLayoutResult.from_dict(record)
			if cached != null:
				compiled = {"status": MapLayoutCompiler.COMPILED, "result": cached}
				print("STUDY_VALIDATED_CACHE ", cached.digest())
	if compiled.is_empty():
		push_error("Study cache unavailable for current complete input; no stale substitution: " + input.digest())
		scene.free()
		return {}
	if compiled.get("status") != MapLayoutCompiler.COMPILED:
		push_error(JSON.stringify(compiled))
		scene.free()
		return {}
	var result: MapLayoutResult = compiled["result"]
	var layout: Dictionary = result.to_dict()
	var history: Array = []
	for step: int in range(4 if act < 3 else 2):
		var next: Array[int] = world.reachable()
		if not next.is_empty():
			world.enter(next[0])
			world.clear_current()
			history.append(world.nodes[world.at].id)
	var reachable: Array = []
	for index: int in world.reachable():
		reachable.append(world.nodes[index].id)
	var records: Array = []
	for node: MapNode in world.nodes:
		records.append(node.to_dict())
	var report: Dictionary = MapQualityEvaluator.evaluate(input, result, assets, quality)
	var out: Dictionary = {"act": act + 1, "seed": seed_value, "nodes": records,
		"anchors": layout["node_anchors"], "edges": layout["edges"],
		"input_digest": input.digest(), "layout_digest": result.digest(),
		"asset_profile_digest": assets["digest"], "compiler_hard_pass": report.get("hard_pass", false),
		"history": history, "current": world.nodes[world.at].id, "reachable": reachable,
		"hero_placements": layout["hero_placements"]}
	_write("act%d-seed%d.json" % [act + 1, seed_value], out)
	print("STUDY_COMPILE_OK act=", act + 1, " seed=", seed_value,
		" nodes=", records.size(), " edges=", layout["edges"].size(), " hard_pass=", out["compiler_hard_pass"])
	scene.free()
	return out

func _write(name: String, value: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(OUT + name, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write study: " + name)
		quit(2)
		return
	file.store_string(JSON.stringify(value, "\t"))
