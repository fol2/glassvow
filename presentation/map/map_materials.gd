class_name MapMaterials
extends RefCounted
## Ground + prop ShaderMaterial pair for one MapScene act (#234 slice 2).
##
## Wires the #255 shaders. Uniforms that must not drift between the two
## surfaces — `sun`, `tex_stop`, the shared tile and grade — are written
## through this object. Placeholder 1×1 textures stand in until slice 4
## binds a real grade and surface tile. No albedo tint: the per-act hue
## lives on the ramp bands, never multiplied into the tile.

const GROUND_SHADER: String = "res://presentation/map/map_ground.gdshader"
const PROP_SHADER: String = "res://presentation/map/map_prop.gdshader"
const GROUND_VALUE: float = 0.420
const PROP_VALUE: float = 0.100
const GRADE_MIN: Vector2 = Vector2(-24.0, -12.0)
const GRADE_SIZE: Vector2 = Vector2(48.0, 24.0)

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
