class_name MapMaterials
extends RefCounted
## Ground + prop ShaderMaterial pair for one MapScene act (#234 slice 4).
##
## Wires the #255 shaders. Uniforms that must not drift between the two
## surfaces — `sun`, `tex_stop`, the shared tile and grade — are written
## through this object. Grade is the proxy `_grade_image` recipe, one
## texture per act, until painted grades exist. No albedo tint: the
## per-act hue lives on the ramp bands, never multiplied into the tile.

const GROUND_SHADER: String = "res://presentation/map/map_ground.gdshader"
const PROP_SHADER: String = "res://presentation/map/map_prop.gdshader"
const GROUND_VALUE: float = 0.420
const PROP_VALUE: float = 0.100
const GRADE_MIN: Vector2 = Vector2(-24.0, -12.0)
const GRADE_SIZE: Vector2 = Vector2(48.0, 24.0)
const GRADE_RESOLUTION: Vector2i = Vector2i(256, 128)

var ground: ShaderMaterial
var prop: ShaderMaterial


func _init(sun: Vector3, tex_stop: int) -> void:
	var surface: ImageTexture = _placeholder_surface()
	var grade: ImageTexture = _placeholder_grade()
	ground = _make(GROUND_SHADER, surface, grade, GROUND_VALUE, sun, tex_stop)
	prop = _make(PROP_SHADER, surface, grade, PROP_VALUE, sun, tex_stop)
	prop.set_shader_parameter("second_octave", false)


func set_tex_stop(index: int) -> void:
	ground.set_shader_parameter("tex_stop", index)
	prop.set_shader_parameter("tex_stop", index)


func set_sun(direction: Vector3) -> void:
	var sun: Vector3 = direction.normalized()
	ground.set_shader_parameter("sun", sun)
	prop.set_shader_parameter("sun", sun)


func bind_region(region: MapRegions, grade: Texture2D) -> void:
	ground.set_shader_parameter("band_shade", region.band_shade)
	ground.set_shader_parameter("band_key", region.band_key)
	prop.set_shader_parameter("band_shade", region.band_shade)
	prop.set_shader_parameter("band_key", region.band_key)
	ground.set_shader_parameter("grade", grade)
	prop.set_shader_parameter("grade", grade)


static func grade_for(region: MapRegions, positions: PackedVector3Array) -> ImageTexture:
	return ImageTexture.create_from_image(_grade_image(region, positions))


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
