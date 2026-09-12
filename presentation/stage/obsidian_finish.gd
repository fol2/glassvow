class_name ObsidianFinish
extends RefCounted
## Act III material authority shared by the precinct and combat ground.
const STONE: Color = Color("191c26")
const SLAB_METRES: Vector2 = Vector2(8.4,6.2)
const ROUGHNESS: Vector2 = Vector2(.42,.58)
const JOINT_COVERAGE: float = .22
const JOINT_STRENGTH: float = .18
const PLATE: String = "res://assets/art/stage/act3-court-floor.png"
static func apply_world(material: ShaderMaterial) -> void:
	material.set_shader_parameter("stone_colour",STONE)
	material.set_shader_parameter("slab_size",SLAB_METRES)
	material.set_shader_parameter("roughness_range",ROUGHNESS)
	material.set_shader_parameter("joint_coverage",JOINT_COVERAGE)
	material.set_shader_parameter("joint_strength",JOINT_STRENGTH)
	material.set_shader_parameter("obsidian_facets",true)
static func combat() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://presentation/stage/obsidian_ground.gdshader")
	material.set_shader_parameter("court_plate",load(PLATE))
	material.set_shader_parameter("stone_colour",STONE)
	return material
