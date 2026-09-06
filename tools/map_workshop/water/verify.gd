extends SceneTree
## Bounded resource contract; native captures separately qualify shader output.
const Water = preload("res://tools/map_workshop/water/surface.gd")
const Presets = preload("res://tools/map_workshop/water/presets.gd")

func _initialize() -> void:
	var city: Water = Water.new()
	var river: Water = Water.new()
	city.configure(PlaneMesh.new(), Presets.drowned_city())
	river.configure(PlaneMesh.new(), Presets.quiet_river())
	var city_material: ShaderMaterial = city.material_override
	var river_material: ShaderMaterial = river.material_override
	assert(city_material != river_material, "Water bodies must own independent settings")
	assert(city_material.shader == river_material.shader, "Bodies must use the shared shader")
	assert(city_material.get_shader_parameter("absorption") != river_material.get_shader_parameter("absorption"))
	var texture_bytes: int = 0
	for parameter: String in ["normal_a", "normal_b", "foam_noise"]:
		var texture: Texture2D = city_material.get_shader_parameter(parameter)
		assert(texture == river_material.get_shader_parameter(parameter), "Noise should be shared")
		assert(texture.get_image() != null, "Noise must be ready on the first frame")
		assert(texture.get_image().has_mipmaps(), "Distant water needs mipmaps")
		texture_bytes += texture.get_image().get_data().size()
	var pattern_texture: Texture2D = city_material.get_shader_parameter("foam_noise")
	var pattern: Image = pattern_texture.get_image()
	for pixel: int in range(256):
		assert(absf(pattern.get_pixel(0,pixel).r-pattern.get_pixel(255,pixel).r)<.04, "Horizontal pattern seam")
		assert(absf(pattern.get_pixel(pixel,0).r-pattern.get_pixel(pixel,255).r)<.04, "Vertical pattern seam")
	assert(texture_bytes < 1048576, "Shared source textures should remain below 1 MiB")
	print("SHARED_WATER_TEXTURE_BYTES ",texture_bytes)
	city.set_capture_time(2.0)
	river.set_capture_time(5.0)
	assert(city_material.get_shader_parameter("captured_time") == 2.0)
	assert(river_material.get_shader_parameter("captured_time") == 5.0)
	city.set_capture_time()
	assert(city_material.get_shader_parameter("captured_time") == -1.0)
	city.free()
	river.free()
	print("SHARED_WATER_RESOURCE_CONTRACT PASS")
	quit()
