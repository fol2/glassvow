extends RefCounted
static func obsidian(colour: Color = Color("211b30"),glow: float = .06) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = preload("res://tools/map_workshop/act3/obsidian.gdshader")
	material.set_shader_parameter("stone_colour",colour)
	material.set_shader_parameter("joint_light",glow)
	return material

static func glass() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("532047")
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = Color("aa337b")
	material.emission_energy_multiplier = .48
	material.roughness = .38
	return material

static func bridge(_settings: Dictionary) -> Dictionary:
	return {"body":obsidian(Color("1c1828"),.09),"deck":obsidian(Color("30283f"),.07),"trim":obsidian(Color("413549"),.03)}
