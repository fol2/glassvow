extends RefCounted
const Cache = preload("res://presentation/map/map_journey_cache.gd")
static func run(fails: Array[String]) -> void:
	var fingerprints: Dictionary = preload("res://assets/art/map-journey/runtime-fingerprints.json").data["assets"]
	for kind: String in preload("res://presentation/map/landscape/kit.gd").PROFILES:
		if not fingerprints.has(kind): fails.append("journey cache: missing appearance identity: "+kind)
		elif OS.has_feature("editor") and fingerprints[kind] != FileAccess.get_sha256("res://assets/art/map-journey/"+kind+".glb"):
			fails.append("journey cache: stale appearance identity: "+kind)
	var kinds: Array[String] = []
	kinds.assign(preload("res://presentation/map/landscape/kit.gd").PROFILES.keys())
	kinds.sort()
	var baked: MapJourneyAssets = MapJourneyAssets.new(kinds)
	var measured: MapJourneyAssets = MapJourneyAssets.new(kinds,true)
	if not baked.failure.is_empty() or not measured.failure.is_empty() or baked.digest!=measured.digest or baked.profiles!=measured.profiles:
		fails.append("journey catalogue: imported mesh measurements differ from shipped profiles")
	var directory: String = "user://test-journey-cache-"+str(Time.get_ticks_usec())
	var newest: String = ""
	for i: int in range(6):
		var cache: Cache = Cache.new()
		cache.cache_key = ("cache-test-%d"%i).sha256_text()
		cache.quality = {"test":i}
		cache.recipe_assets={"profile":{"local_aabb":AABB(Vector3(-2,0,-1),Vector3(4,7,2))}}
		cache.chapter_data={"kind":"fixture","route":PackedVector3Array([Vector3(1,2,3),Vector3(4,5,6)])}
		newest = cache.cache_key
		if cache.save_cache(directory)!=OK: fails.append("journey cache: cannot save derived test data")
		var restored: Cache = Cache.read(newest,directory) as Cache
		if restored == null or restored.quality!=cache.quality or restored.recipe_assets!=cache.recipe_assets or restored.chapter_data!=cache.chapter_data:
			fails.append("journey cache: newest entry was lost or changed")
	var count: int = 0
	for name: String in DirAccess.get_files_at(directory):
		if name.ends_with(".res"): count += 1
	if count>4: fails.append("journey cache: completed entries grow without a bound")
	if Cache.read("different-input".sha256_text(),directory)!=null:
		fails.append("journey cache: another input reused this section")
	var path: String = directory.path_join(newest+".res")
	var original_manifest: String = FileAccess.get_file_as_string(path+".json")
	var invalid: Dictionary = JSON.parse_string(original_manifest)
	invalid["version"] = "obsolete"
	var manifest: FileAccess = FileAccess.open(path+".json",FileAccess.WRITE)
	manifest.store_string(JSON.stringify(invalid))
	manifest.close()
	if Cache.read(newest,directory)!=null: fails.append("journey cache: obsolete version was accepted")
	manifest = FileAccess.open(path+".json",FileAccess.WRITE)
	manifest.store_string(original_manifest)
	manifest.close()
	var file: FileAccess = FileAccess.open(path,FileAccess.READ_WRITE)
	if file != null:
		file.seek_end()
		file.store_8(0)
		file.close()
	if Cache.read(newest,directory)!=null:
		fails.append("journey cache: modified bytes were accepted")
	for name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
