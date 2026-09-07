extends RefCounted
## Preserved seeds need local crossing decks without stretching the whole map.
static func run(fails: Array[String]) -> void:
	for seed: int in [1,10,14]:
		_case(seed,fails)

static func _case(seed: int, fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var run: RunState = RunState.new_run(content,seed)
	var world: WorldMap = WorldMap.for_run(run,content)
	var before: Dictionary = run.to_dict()
	var bound: Dictionary = preload("res://presentation/map/map_journey_input.gd").bind(world,0)
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/map-quality-v2.json"))
	var nodes: Array = bound["nodes"]
	var edges: Array = bound["edges"]
	var recipe: Dictionary = preload("res://presentation/map/map_journey_recipe.gd").build(nodes,edges,base)
	if recipe.get("ok")!=true:
		fails.append("journey stress: production recipe failed")
		return
	var quality: Dictionary = recipe["quality"]
	var assets: Dictionary = recipe["assets"]
	var input: MapLayoutInput = MapLayoutInput.from_dict({
		"schema_version":MapLayoutInput.SCHEMA_VERSION,"generator_schema":"map-compiler-v2",
		"generator_version":MapLayoutCompiler.VERSION,"nodes":nodes,"edges":edges,"act":0,
		"run_seed":seed,"scenery_seed":seed+WorldMapScreen.SCENERY_SEED_OFFSET,
		"asset_profile_digest":assets["digest"],
		"camera_profile_digest":MapQualityEvaluator.camera_registry(nodes,quality,edges)["digest"],
		"hero_anchor_contract":recipe["heroes"],"quality_registry_digest":MapLayoutCanonical.digest(quality)})
	var result: Dictionary = MapLayoutCompiler.compile(input,quality,assets)
	if result["status"]!=MapLayoutCompiler.COMPILED:
		fails.append("journey stress: preserved three-crossing seed cannot be compiled")
		return
	if result["diagnostics"].get("selected_strategy")!="grade-priority-v1":
		fails.append("journey stress: bounded physical proposal fell into exhaustive fallback")
	var layout: MapLayoutResult = result["result"]
	var report: Dictionary = MapQualityEvaluator.evaluate(input,layout,assets,quality)
	if report.get("hard_pass")!=true:
		fails.append("journey stress: emitted layout fails complete quality evaluation")
	if run.to_dict()!=before:
		fails.append("journey stress: presentation mutated the game run")
