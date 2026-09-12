extends SceneTree
## Run after update_journey_fingerprints.py when the woodland source kit changes.
func _initialize() -> void:
	var kinds: Array[String] = []
	kinds.assign(preload("res://presentation/map/landscape/kit.gd").PROFILES.keys())
	kinds.sort()
	var measured: MapJourneyAssets = MapJourneyAssets.new(kinds,true)
	if not measured.failure.is_empty():
		push_error(measured.failure)
		quit(1)
		return
	var catalogue: Resource = preload("res://presentation/map/map_asset_catalogue.gd").new()
	catalogue.set("profile_version",MapAssetProfiles.PROFILE_SCHEMA_VERSION)
	catalogue.set("fingerprints",preload("res://assets/art/map-journey/runtime-fingerprints.json").data)
	catalogue.set("profiles",measured.profiles)
	catalogue.set("digest",measured.digest)
	var error: Error = ResourceSaver.save(catalogue,"res://assets/art/map-journey/geometry-catalogue.res",ResourceSaver.FLAG_COMPRESS)
	print("JOURNEY_CATALOGUE ",measured.digest," ",error_string(error))
	quit(0 if error==OK else 1)
