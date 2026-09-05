extends SceneTree
## Runtime/catalogue geometry and cosmetic determinism across all four acts.
## This component probe does not claim to compile or qualify generated maps;
## tools/preview_map.gd --compile-only --quality=… evaluates complete layouts.

func _initialize() -> void:
	var seeds: int = 20
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--seeds=") or not arg.get_slice("=", 1).is_valid_int():
			_fail("Expected --seeds=<positive integer>")
			return
		seeds = int(arg.get_slice("=", 1))
	if seeds < 1 or seeds > 1000:
		_fail("Seed count must be 1–1000")
		return
	var provenance: Variant = JSON.parse_string(FileAccess.get_file_as_string(MapLandscapeAssets.ROOT + "provenance.json"))
	if not provenance is Dictionary or not provenance.get("assets") is Array:
		_fail("Missing landscape provenance")
		return
	var declared: Array[String] = []
	for row: Dictionary in provenance["assets"]:
		declared.append(MapLandscapeAssets.ROOT + str(row["file"]))
	var loaded: Array[String] = []
	var total: int = 0
	for act: int in range(4):
		var assets: MapLandscapeAssets = MapLandscapeAssets.new(act)
		var scene: MapScene = MapScene.new()
		scene.set_act(act)
		var matches: bool = assets.failure.is_empty() and not assets.digest.is_empty() \
			and scene.asset_profile_digest() == assets.digest
		scene.free()
		if not matches:
			_fail("Act %d runtime/catalogue profile mismatch: %s" % [act, assets.failure])
			return
		var texture_bytes: int = 0
		for resource: Resource in assets.resources:
			if resource is Texture2D:
				texture_bytes += (resource as Texture2D).get_image().get_data_size()
		if texture_bytes > 64 * 1024 * 1024:
			_fail("Act %d exceeds the 64 MiB resident texture budget" % act)
			return
		for path: String in assets.paths:
			if path not in declared:
				_fail("Runtime loaded an asset without provenance: " + path)
				return
			if path not in loaded:
				loaded.append(path)
		print("Act %d mipmapped texture bytes: %d" % [act + 1, texture_bytes])
		var previous: String = ""
		for seed_value: int in range(1, seeds + 1):
			var first: Dictionary = _candidates(assets, seed_value)
			var repeated: Dictionary = _candidates(assets, seed_value)
			var digest: String = MapLayoutCanonical.digest(first)
			if first.is_empty() or digest != MapLayoutCanonical.digest(repeated) or digest == previous:
				_fail("Act %d seed %d lost deterministic variation" % [act, seed_value])
				return
			previous = digest
			for value: Dictionary in first.values():
				var placement: Dictionary = value["placement"]
				var id: String = str(placement["profile_id"])
				if id not in MapLandscapeAssets.SCENERY[act] or not assets.profiles.has(id):
					_fail("Candidate references another act or an absent profile: " + id)
					return
				var transform: Dictionary = placement["transform"]
				var profile: Dictionary = assets.profiles[id]
				var footprint: PackedVector2Array = assets.registry.transformed_footprint(
					profile, MapLandscape.v3(transform["origin"]),
					rad_to_deg(MapLayoutCanonical.float_value(transform["yaw_radians"])),
					MapLandscape.v3(transform["scale"]))
				if footprint.size() < 3:
					_fail("Candidate has no measurable transformed footprint: " + id)
					return
			total += first.size()
		print("Act %d profiles %s: %d cosmetic seeds repeat exactly" % [act + 1, assets.digest, seeds])
	if loaded.size() != declared.size():
		_fail("Declared landscape payload is unused by all runtime acts")
		return
	print("map profiles OK (4 acts, %d candidate transforms; complete-layout proof is separate)" % total)
	quit(0)


func _candidates(assets: MapLandscapeAssets, seed_value: int) -> Dictionary:
	var landscape: MapLandscape = MapLandscape.new()
	landscape.prepare({"node_anchors": {}, "edges": {}}, assets, seed_value)
	var result: Dictionary = landscape.candidates()
	landscape.free()
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(2)
