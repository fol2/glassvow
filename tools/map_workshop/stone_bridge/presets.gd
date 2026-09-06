extends RefCounted
## Geometry and materials can vary without introducing chapter-specific code
## into the fitted bridge parts. Woodland is an unapproved starting preset.
static func drowned_city() -> Dictionary:
	return {"arch_spacing":8.0,"pier_width":1.3,"crown_thickness":.46,
		"parapet_height":.83,"parapet_width":.20,"foundation_level":-.45,
		"water_level":1.18,"tread_width":1.60,"stone_colour":Color("44536b"),
		"trim_colour":Color("526277"),"paving_colour":Color("555f70")}

static func woodland() -> Dictionary:
	return {"arch_spacing":6.5,"pier_width":1.45,"crown_thickness":.5,
		"parapet_height":.50,"parapet_width":.24,"foundation_level":-.4,
		"water_level":.1,"tread_width":1.60,"stone_colour":Color("5e5b53"),
		"trim_colour":Color("787365"),"paving_colour":Color("777263")}

static func materials(settings: Dictionary) -> Dictionary:
	var body: ShaderMaterial = ShaderMaterial.new()
	body.shader = preload("res://tools/map_workshop/stone_bridge/masonry.gdshader")
	body.set_shader_parameter("stone_colour",settings["stone_colour"])
	body.set_shader_parameter("water_level",settings["water_level"])
	var trim: StandardMaterial3D = StandardMaterial3D.new()
	trim.albedo_color = settings["trim_colour"]
	trim.roughness = .95
	trim.metallic_specular = .20
	var deck: ShaderMaterial = ShaderMaterial.new()
	deck.shader = preload("res://tools/map_workshop/stone_bridge/paving.gdshader")
	deck.set_shader_parameter("stone_colour",settings["paving_colour"])
	return {"body":body,"trim":trim,"deck":deck}
