class_name MirroredFinish
extends RefCounted
## Shared Act IV stone authority. Each renderer preserves its native geometry/alpha.
const STONE: Color = Color("41424e")
static func apply_world(material: ShaderMaterial) -> void:
	material.set_shader_parameter("stone_colour",STONE)
static func combat() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = preload("res://presentation/stage/mirrored_ground.gdshader")
	material.set_shader_parameter("stone_colour",STONE)
	return material
