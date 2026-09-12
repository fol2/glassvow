extends Resource
## Disposable derived presentation data. Gameplay saves never depend on this file.
## Bump this epoch whenever the derived mesh/placement format or recipe semantics
## change without a corresponding recipe/surface version. Shader resources remain external.
const VERSION: String = "journey-cache-v6"
const ROOT: String = "user://map-journey-cache"
@export var cache_key: String = ""
@export var quality: Dictionary = {}
@export var heroes: Dictionary = {}
@export var source_result: Dictionary = {}
@export var meshes: Array[Dictionary] = []
@export var bridge_spans: Array[Dictionary] = []
@export var placements: Array[Dictionary] = []
@export var hero_roles: Dictionary = {}
@export var chapter_data: Dictionary = {}
@export var recipe_assets: Dictionary = {}

static func read(key: String, directory: String = ROOT) -> Resource:
	var path: String = directory.path_join(key+".res")
	if not FileAccess.file_exists(path) or not FileAccess.file_exists(path+".json"): return null
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(path+".json"))
	if not manifest is Dictionary or manifest.get("version") != VERSION or manifest.get("key") != key:
		return null
	if manifest.get("sha256") != FileAccess.get_sha256(path): return null
	var value: Resource = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
	if value == null or value.get_script() != load("res://presentation/map/map_journey_cache.gd"):
		return null
	if str(value.get("cache_key")) != key: return null
	return value

func save_cache(directory: String = ROOT) -> Error:
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK: return error
	var path: String = directory.path_join(cache_key+".res")
	var temporary: String = directory.path_join(cache_key+".pending.res")
	error = ResourceSaver.save(self,temporary,ResourceSaver.FLAG_COMPRESS)
	if error != OK: return error
	error = DirAccess.rename_absolute(temporary,path)
	if error != OK: return error
	var manifest: FileAccess = FileAccess.open(path+".json",FileAccess.WRITE)
	if manifest == null: return FileAccess.get_open_error()
	manifest.store_string(JSON.stringify({"key":cache_key,"version":VERSION,"sha256":FileAccess.get_sha256(path)}))
	manifest.close()
	# One campaign has four acts. Keep at most four completed derived sections.
	var files: Array[Dictionary] = []
	for name: String in DirAccess.get_files_at(directory):
		if name.ends_with(".res") and not name.ends_with(".pending.res"):
			files.append({"path":directory.path_join(name),"time":FileAccess.get_modified_time(directory.path_join(name))})
	files.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a["path"] == b["path"]: return false
		if str(a["path"]) == path: return true
		if str(b["path"]) == path: return false
		if a["time"] == b["time"]: return str(a["path"])<str(b["path"])
		return int(str(a["time"]))>int(str(b["time"])))
	for i: int in range(4,files.size()):
		DirAccess.remove_absolute(str(files[i]["path"]))
		DirAccess.remove_absolute(str(files[i]["path"])+".json")
	return OK

func capture(landscape: Node3D) -> void:
	if landscape.has_method("capture_chapter"):
		chapter_data=landscape.capture_chapter()
		return
	meshes.clear()
	for child: Node in landscape.terrain.get_children():
		if not child is MeshInstance3D: continue
		var item: MeshInstance3D = child as MeshInstance3D
		meshes.append({"name":str(item.name),"mesh":item.mesh,"material":item.material_override,
			"transform":item.transform,"layers":item.layers,"shadows":item.cast_shadow,
			"water":item.name==&"Stream","field":item.get("field_image") if item.name==&"Stream" else null})
	if landscape.terrain.has_meta("bridge_field"):
		var field: RefCounted = landscape.terrain.get_meta("bridge_field")
		var spans: Array = field.spans
		bridge_spans.assign(spans)
	var rows: Array = landscape.kit.placed
	placements.assign(rows)
	hero_roles.clear()
	for i: int in range(landscape.kit.placed_nodes.size()):
		var item: Node3D = landscape.kit.placed_nodes[i]
		if item.has_meta("hero_role"): hero_roles[str(i)] = item.get_meta("hero_role")
