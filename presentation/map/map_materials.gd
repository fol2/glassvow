class_name MapMaterials
extends RefCounted
## Ground + prop ShaderMaterial pair and active-act asset binding (#291).
##
## `map-assets.json` is metadata only: resources are loaded lazily when an act
## binds. The prior act is first replaced by procedural fallbacks, so shader
## uniforms cannot retain its textures. MapRegions remains the palette owner;
## the manifest never supplies runtime colour. The shaders still fetch one
## surface texture each and one shared grade.

const GROUND_SHADER: String = "res://presentation/map/map_ground.gdshader"
const PROP_SHADER: String = "res://presentation/map/map_prop.gdshader"
const MANIFEST_PATH: String = "res://assets/art/map/map-assets.json"
const ASSET_ROOT: String = "res://assets/art/map/"
const GROUND_VALUE: float = 0.420
const PROP_VALUE: float = 0.100
## The paved corridor. Brighter than the ground it crosses, which is the
## reading `map_ground.gdshader` already describes for the grade corridor.
## Lifted so the paving reads as a road rather than as slightly paler ground.
const ROAD_VALUE: float = 0.880
const GRADE_MIN: Vector2 = Vector2(-36.0, -18.0)
## Still 2:1, which the 512x256 grade PNG requires. Widened with the lattice
## so the map reads less dense.
const GRADE_SIZE: Vector2 = Vector2(72.0, 36.0)
const GRADE_RESOLUTION: Vector2i = Vector2i(256, 128)

var ground: ShaderMaterial
var road: ShaderMaterial
var prop: ShaderMaterial
var _fallback_surface: ImageTexture
var _fallback_grade: ImageTexture
var _manifest_rows: Array[Dictionary] = []
var _resource_loader: Callable
var _active_paths: PackedStringArray = []
var _active_resources: Array[Resource] = []


func _init(sun: Vector3, tex_stop: int, manifest: Dictionary = {},
		resource_loader: Callable = Callable()) -> void:
	_fallback_surface = _placeholder_surface()
	_fallback_grade = _placeholder_grade()
	ground = _make(GROUND_SHADER, _fallback_surface, _fallback_grade,
			GROUND_VALUE, sun, tex_stop)
	road = _make(GROUND_SHADER, _fallback_surface, _fallback_grade,
			ROAD_VALUE, sun, tex_stop)
	prop = _make(PROP_SHADER, _fallback_surface, _fallback_grade,
			PROP_VALUE, sun, tex_stop)
	prop.set_shader_parameter("second_octave", false)
	_resource_loader = resource_loader
	if not _resource_loader.is_valid():
		_resource_loader = Callable(self, "_load_resource")
	var source: Dictionary = manifest
	if source.is_empty():
		source = _read_manifest()
	_manifest_rows = _rows_from(source)


func set_tex_stop(index: int) -> void:
	ground.set_shader_parameter("tex_stop", index)
	road.set_shader_parameter("tex_stop", index)
	prop.set_shader_parameter("tex_stop", index)


func set_sun(direction: Vector3) -> void:
	var sun: Vector3 = direction.normalized()
	ground.set_shader_parameter("sun", sun)
	road.set_shader_parameter("sun", sun)
	prop.set_shader_parameter("sun", sun)


func bind_region(region: MapRegions, grade: Texture2D) -> void:
	road.set_shader_parameter("band_shade", region.band_shade)
	road.set_shader_parameter("band_key", region.band_key)
	road.set_shader_parameter("grade", grade)
	ground.set_shader_parameter("band_shade", region.band_shade)
	ground.set_shader_parameter("band_key", region.band_key)
	prop.set_shader_parameter("band_shade", region.band_shade)
	prop.set_shader_parameter("band_key", region.band_key)
	ground.set_shader_parameter("grade", grade)
	prop.set_shader_parameter("grade", grade)


## Drops all prior-act references before loading only this act's 12-row set:
## two tiles, one grade, three shared + five act kits, and one terminus.
func bind_act(region: MapRegions, positions: PackedVector3Array) -> Dictionary:
	ground.set_shader_parameter("surface_tex", _fallback_surface)
	road.set_shader_parameter("surface_tex", _fallback_surface)
	prop.set_shader_parameter("surface_tex", _fallback_surface)
	road.set_shader_parameter("tex_mean", 0.5)
	ground.set_shader_parameter("tex_mean", 0.5)
	prop.set_shader_parameter("tex_mean", 0.5)
	bind_region(region, _fallback_grade)
	_active_paths = PackedStringArray()
	_active_resources.clear()
	var procedural_grade: ImageTexture = grade_for(region, positions)
	bind_region(region, procedural_grade)
	var kits: Array[Resource] = []
	var kit_ids: PackedStringArray = []
	var terminus: Resource = null
	var terminus_id: String = ""
	var ground_tile: Texture2D = null
	var prop_tile: Texture2D = null
	var painted_grade: Texture2D = null
	var ground_mean: float = 0.5
	var prop_mean: float = 0.5
	for row: Dictionary in _manifest_rows:
		var row_act: int = _row_int(row, "act", -99)
		if row_act != -1 and row_act != region.act:
			continue
		var path: String = ASSET_ROOT + _row_string(row, "path")
		var loaded: Variant = _resource_loader.call(path)
		if not (loaded is Resource):
			continue
		var resource: Resource = loaded
		var kind: String = _row_string(row, "kind")
		if kind in ["tile", "grade"] and not (resource is Texture2D):
			continue
		if kind in ["kit", "terminus"] and not (resource is Mesh or resource is PackedScene):
			continue
		_active_paths.append(path)
		_active_resources.append(resource)
		match kind:
			"kit":
				kits.append(resource)
				kit_ids.append(_row_string(row, "id"))
			"terminus":
				terminus = resource
				terminus_id = _row_string(row, "id")
			"tile":
				var tile: Texture2D = resource as Texture2D
				if _row_string(row, "role") == "ground":
					ground_tile = tile
					ground_mean = _row_float(row, "tex_mean", 0.5)
				else:
					prop_tile = tile
					prop_mean = _row_float(row, "tex_mean", 0.5)
			"grade":
				painted_grade = resource as Texture2D
	if ground_tile != null:
		ground.set_shader_parameter("surface_tex", ground_tile)
		ground.set_shader_parameter("tex_mean", ground_mean)
		road.set_shader_parameter("surface_tex", ground_tile)
		road.set_shader_parameter("tex_mean", ground_mean)
	if prop_tile != null:
		prop.set_shader_parameter("surface_tex", prop_tile)
		prop.set_shader_parameter("tex_mean", prop_mean)
	if painted_grade != null:
		bind_region(region, painted_grade)
	return {
		"kits": kits, "kit_ids": kit_ids,
		"terminus": terminus, "terminus_id": terminus_id,
		"ground_tile": ground_tile, "prop_tile": prop_tile,
		"grade": painted_grade,
	}


func active_asset_paths() -> PackedStringArray:
	return _active_paths.duplicate()


func active_asset_resources() -> Array[Resource]:
	var resources: Array[Resource] = []
	resources.assign(_active_resources)
	return resources


static func grade_for(region: MapRegions, positions: PackedVector3Array) -> ImageTexture:
	return ImageTexture.create_from_image(_grade_image(region, positions))


func _read_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary:
		var manifest: Dictionary = parsed
		return manifest
	return {}


func _rows_from(manifest: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var raw: Variant = manifest.get("assets", [])
	if not (raw is Array):
		return rows
	var items: Array = raw
	for item: Variant in items:
		if item is Dictionary:
			var row: Dictionary = item
			rows.append(row)
	return rows


static func _row_int(row: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = row.get(key, fallback)
	if value is int:
		var integer: int = value
		return integer
	if value is float:
		var decimal: float = value
		return int(decimal)
	return fallback


static func _row_string(row: Dictionary, key: String) -> String:
	var value: Variant = row.get(key, "")
	if value is String:
		var text: String = value
		return text
	return ""


static func _row_float(row: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = row.get(key, fallback)
	if value is float:
		var decimal: float = value
		return decimal
	if value is int:
		var integer: int = value
		return float(integer)
	return fallback


func _load_resource(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path)


func _make(shader_path: String, surface: Texture2D, grade: Texture2D,
		surface_value: float, sun: Vector3, tex_stop: int) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(shader_path) as Shader
	material.set_shader_parameter("surface_tex", surface)
	material.set_shader_parameter("grade", grade)
	material.set_shader_parameter("grade_rect", Vector4(
			GRADE_MIN.x, GRADE_MIN.y, GRADE_SIZE.x, GRADE_SIZE.y))
	material.set_shader_parameter("tex_mean", 0.5)
	material.set_shader_parameter("surface_value", surface_value)
	material.set_shader_parameter("sun", sun.normalized())
	material.set_shader_parameter("tex_stop", tex_stop)
	return material


func _placeholder_surface() -> ImageTexture:
	var image: Image = Image.create_empty(1, 1, false, Image.FORMAT_RGB8)
	image.set_pixel(0, 0, Color(0.5, 0.5, 0.5))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _placeholder_grade() -> ImageTexture:
	var image: Image = Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(image)


## Proxy `MapSceneProxy._grade_image`: corridor + aerial + contact in alpha.
## Same per-texel prop walk as the proxy; hues come from MapRegions.
static func _grade_image(region: MapRegions, positions: PackedVector3Array) -> Image:
	var image: Image = Image.create_empty(
			GRADE_RESOLUTION.x, GRADE_RESOLUTION.y, false, Image.FORMAT_RGBA8)
	var w: float = float(GRADE_RESOLUTION.x)
	var h: float = float(GRADE_RESOLUTION.y)
	for y: int in range(GRADE_RESOLUTION.y):
		for x: int in range(GRADE_RESOLUTION.x):
			var world_x: float = GRADE_MIN.x + (float(x) + 0.5) / w * GRADE_SIZE.x
			var world_z: float = GRADE_MIN.y + (float(y) + 0.5) / h * GRADE_SIZE.y
			var journey: float = clampf((world_x - GRADE_MIN.x) / GRADE_SIZE.x, 0.0, 1.0)
			var corridor: float = 1.0 - smoothstep(2.6, 6.2, absf(world_z))
			var hue: float = lerpf(region.grade_hue_near, region.grade_hue_far, journey)
			var saturation: float = lerpf(0.50, 0.25, journey)
			var value: float = 0.56
			hue = lerpf(hue, region.grade_hue_corridor, corridor)
			saturation = lerpf(saturation, 0.08, corridor)
			value = lerpf(value, 1.0, corridor)
			var alpha: float = 1.0
			for prop_position: Vector3 in positions:
				var distance: float = Vector2(world_x - prop_position.x,
						world_z - prop_position.z).length()
				alpha = minf(alpha, lerpf(0.18, 1.0, smoothstep(0.35, 1.75, distance)))
			image.set_pixel(x, y, Color.from_hsv(hue, saturation, value, alpha))
	return image
