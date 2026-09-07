extends SceneTree
## Fresh generator samples for the workshop. Current-input cache reuse is explicit.
var act: int = 0
var seed_value: int = 4
var output: String = ""
var spatial_recipe: String = ""
var first_attempt_only: bool = false
var diagnostic_grade: bool = false
var journey_camera: bool = false
var production_journey: bool = false
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
		elif argument.begins_with("--spatial-recipe="):
			spatial_recipe = argument.trim_prefix("--spatial-recipe=")
		elif argument == "--production-journey":
			production_journey = true
		elif argument == "--journey-camera":
			journey_camera = true
		elif argument == "--diagnostic-grade":
			diagnostic_grade = true
		elif argument == "--first-attempt":
			first_attempt_only = true
		else:
			push_error("Unexpected export argument: "+argument)
			quit(2)
			return
	if act<0 or act>3 or output.is_empty() or (production_journey and act!=0):
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
	if journey_camera:
		quality = preload("res://presentation/map/map_journey_camera_registry.gd").quality(quality)
	var heroes: Dictionary = scene.layout_hero_contract()
	if not spatial_recipe.is_empty():
		var recipe_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(spatial_recipe))
		if not recipe_raw is Dictionary:
			push_error("Invalid spatial recipe")
			scene.free()
			return {}
		var recipe: Dictionary = recipe_raw
		quality["spatial_profile"] = recipe.get("spatial_profile")
		var spatial: Dictionary = quality["spatial_profile"]
		if spatial.get("ordering_version", "") == "layered-order-dp-v1":
			var ordered: Dictionary = preload("res://presentation/map/map_spatial_ordering.gd").generate(nodes, edges)
			if ordered.get("ok") != true:
				push_error(JSON.stringify(ordered))
				scene.free()
				return {}
			spatial["lane_assignments"] = ordered["assignments"]
			print("SPATIAL_ORDER minimum_crossings=", ordered["minimum_layered_crossings"], " transitions=", ordered["transitions"])
		if spatial.get("spacing_version", "") == "physical-reservations-v1":
			var spacing: Dictionary = preload("res://presentation/map/map_spatial_spacing.gd").apply(spatial,nodes,edges)
			spatial = spacing["profile"]
			quality["spatial_profile"] = spatial
			var shifted: Dictionary = recipe.get("hero_translations",{})
			for role: String in shifted:
				shifted[role][0] = MapLayoutCanonical.float_value(shifted[role][0])+MapLayoutCanonical.float_value(spacing["added_length_m"])
			print("SPATIAL_SPACING added_m=",spacing["added_length_m"])
		var errors: Array[String] = preload("res://presentation/map/map_spatial_profile.gd").validate(quality, act)
		if not errors.is_empty():
			push_error("; ".join(errors))
			scene.free()
			return {}
		var translations: Dictionary = recipe.get("hero_translations", {})
		for role: String in translations:
			var delta: Array = translations[role]
			if not MapLayoutCanonical.vector(delta, 3) or not heroes["anchors"].has(role):
				push_error("Invalid spatial hero translation: " + role)
				scene.free()
				return {}
			var position: Array = heroes["anchors"][role]["position"]
			for axis: int in range(3):
				position[axis] = MapLayoutCanonical.float_value(position[axis]) + MapLayoutCanonical.float_value(delta[axis])
			heroes["anchors"][role]["position"] = position
			for zone_id: String in heroes["protected_zones"]:
				var zone: Dictionary = heroes["protected_zones"][zone_id]
				if zone.get("role") == role:
					for point: Array in zone["polygon"]:
						point[0] = MapLayoutCanonical.float_value(point[0]) + MapLayoutCanonical.float_value(delta[0])
						point[1] = MapLayoutCanonical.float_value(point[1]) + MapLayoutCanonical.float_value(delta[2])
		if recipe.has("hero_assets"):
			var hero_binding: Dictionary = preload("res://tools/map_workshop/common/workshop_hero_binding.gd").apply(recipe,quality,nodes,assets,heroes)
			if hero_binding.get("ok") != true:
				push_error(str(hero_binding))
				scene.free()
				return {}
	if production_journey:
		if not spatial_recipe.is_empty():
			push_error("Production journey cannot be mixed with a trial spatial recipe")
			scene.free()
			return {}
		var prepared: Dictionary = preload("res://presentation/map/map_journey_recipe.gd").build(nodes,edges,quality)
		if prepared.get("ok")!=true:
			push_error(str(prepared))
			scene.free()
			return {}
		quality = prepared["quality"]
		assets = prepared["assets"]
		heroes = prepared["heroes"]
	var input: MapLayoutInput = MapLayoutInput.from_dict({
		"schema_version": MapLayoutInput.SCHEMA_VERSION,
		"generator_schema": "map-compiler-v2", "generator_version": MapLayoutCompiler.VERSION,
		"nodes": bound["nodes"], "edges": bound["edges"], "act": act,
		"run_seed": seed_value, "scenery_seed": seed_value + WorldMapScreen.SCENERY_SEED_OFFSET,
		"asset_profile_digest": assets["digest"],
		"camera_profile_digest": MapQualityEvaluator.camera_registry(nodes, quality, edges)["digest"],
		"hero_anchor_contract": heroes,
		"quality_registry_digest": MapLayoutCanonical.digest(quality)})
	if input == null:
		push_error("Generated study input did not validate")
		scene.free()
		return {}
	print("STUDY_INPUT act=", act + 1, " seed=", seed_value, " digest=", input.digest())
	var cache_path: String = "/tmp/glassvow-map-preview-cache/".path_join(input.digest() + ".bin")
	var compiled: Dictionary = {}
	if not first_attempt_only and spatial_recipe.is_empty() and FileAccess.file_exists(cache_path):
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
		if first_attempt_only:
			var generated: Dictionary = MapNodeCandidateGenerator.generate(input, quality, 0)
			if not generated["errors"].is_empty() or not generated["impossibilities"].is_empty():
				push_error(JSON.stringify(generated))
				scene.free()
				return {}
			var selection: Dictionary = {}
			for node_id: String in generated["node_sets"]:
				selection[node_id] = 0
			var hero_report: Dictionary = MapLayoutCompiler._hero_placements(input.to_dict(), assets)
			if hero_report.get("ok") != true:
				push_error(JSON.stringify(hero_report))
				scene.free()
				return {}
			var placements: Dictionary = hero_report["placements"]
			var node_sets: Dictionary = generated["node_sets"]
			var attempt: Dictionary = MapLayoutCompiler._build_attempt(input, input.to_dict(),
				quality, assets, placements, node_sets, selection, diagnostic_grade, true)
			compiled = {"status": MapLayoutCompiler.COMPILED if attempt.get("ok") == true else "FIRST_ATTEMPT_REJECTED",
				"result": attempt.get("result"), "failure": attempt.get("binding", {}),
				"diagnostics": attempt.get("diagnostics", {}),
				"rejected_geometry": attempt.get("rejected_geometry", {}),
				"quality_violations": attempt.get("quality_violations", [])}
		else:
			compiled = MapLayoutCompiler.compile(input,quality,assets)
		if not first_attempt_only and spatial_recipe.is_empty() and compiled.get("result") is MapLayoutResult:
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
		"hero_placements": layout["hero_placements"],
		"spatial_profile": quality.get("spatial_profile", {}),
		"quality_registry_digest": MapLayoutCanonical.digest(quality)}
	var hero_sources: Dictionary = {}
	for placement: Dictionary in layout["hero_placements"].values():
		var profile: Dictionary = assets["profiles"][placement["profile_id"]]
		var source_path: String = str(profile["source_path"])
		hero_sources[str(placement["asset_id"])] = {"path":source_path,"sha256":FileAccess.get_sha256(source_path)}
	out["hero_sources"] = hero_sources
	if out["compiler_hard_pass"]!=true:
		push_error("Compiled layout failed its existing quality contract")
		scene.free()
		return {}
	print("STUDY_COMPILE_OK act=", act + 1, " seed=", seed_value,
		" nodes=", records.size(), " edges=", layout["edges"].size(), " hard_pass=", out["compiler_hard_pass"])
	scene.free()
	return out
