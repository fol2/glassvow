extends SceneTree
## Fresh generator samples for the workshop. Current-input cache reuse is explicit.
var act: int = 0
var seed_value: int = 4
var output: String = ""
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--act="):
			act = argument.trim_prefix("--act=").to_int()
		elif argument.begins_with("--seed="):
			seed_value = argument.trim_prefix("--seed=").to_int()
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		else:
			push_error("Unexpected export argument: "+argument)
			quit(2)
			return
	if act<0 or act>3 or output.is_empty():
		quit(2)
		return
	Locale.active = Locale.new(&"en")
	var content: ContentDB = ContentDB.load_full()
	Locale.active.hydrate_content(content)
	var sample: Dictionary = _sample(content,act,seed_value)
	if sample.is_empty():
		quit(1)
		return
	var file: FileAccess = FileAccess.open(output,FileAccess.WRITE)
	if file==null:
		push_error("Cannot write generated sample: "+output)
		quit(2)
		return
	file.store_string(JSON.stringify(sample,"\t"))
	file.close()
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
		print("FRESH_COMPILATION ",input.digest())
		compiled = MapLayoutCompiler.compile(input,quality,assets)
		if compiled.get("result") is MapLayoutResult:
			var selected: MapLayoutResult = compiled["result"]
			DirAccess.make_dir_recursive_absolute(cache_path.get_base_dir())
			var cache: FileAccess = FileAccess.open(cache_path,FileAccess.WRITE)
			cache.store_var(selected.to_dict(),false)
			cache.close()
	if compiled.get("status") != MapLayoutCompiler.COMPILED:
		# Preserve the full certificate without flooding the native console.
		var failure_path: String = output+".failure.json"
		var failure_file: FileAccess = FileAccess.open(failure_path,FileAccess.WRITE)
		if failure_file!=null:
			failure_file.store_string(JSON.stringify(compiled))
			failure_file.close()
		var failure: Dictionary = compiled.get("failure",{})
		push_error(JSON.stringify({"status":compiled.get("status"),"input_digest":input.digest(),"kind":failure.get("kind"),"id":failure.get("id"),"reason":failure.get("reason"),"certificate":failure_path if failure_file!=null else "Could not save certificate"}))
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
	if out["compiler_hard_pass"]!=true:
		push_error("Compiled layout failed its existing quality contract")
		scene.free()
		return {}
	print("STUDY_COMPILE_OK act=", act + 1, " seed=", seed_value,
		" nodes=", records.size(), " edges=", layout["edges"].size(), " hard_pass=", out["compiler_hard_pass"])
	scene.free()
	return out
