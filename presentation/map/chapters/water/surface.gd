extends MeshInstance3D
## Shared Step 3 water surface. Call configure before adding it to the scene.
## One horizontal mesh per body; callers own its footprint and water level.
const WATER_SHADER: Shader = preload("res://presentation/map/chapters/water/surface.gdshader")
static var textures: Array[Texture2D] = []
var animate: bool = true:
	set(value):
		animate=value
		if material_override!=null: set_capture_time(-1.0 if value else 0.0)

func configure(footprint: Mesh, preset: Dictionary = {}) -> void:
	if textures.is_empty():
		textures = [_noise(4103, true, .035), _noise(7207, true, .052), _pattern()]
	mesh = footprint
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("normal_a", textures[0])
	material.set_shader_parameter("normal_b", textures[1])
	material.set_shader_parameter("foam_noise", textures[2])
	for key: String in preset:
		material.set_shader_parameter(key, preset[key])
	material_override = material

func set_capture_time(seconds: float = -1.0) -> void:
	(material_override as ShaderMaterial).set_shader_parameter("captured_time", seconds)

static func _noise(seed_value: int, normal: bool, frequency: float) -> Texture2D:
	# Synchronous generation avoids a blank first frame from asynchronous noise
	# resources. Local seeds never consume the campaign RNG.
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = 3
	var image: Image = noise.get_seamless_image(256, 256)
	if normal:
		image.bump_map_to_normal_map(3.0)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func _pattern() -> Texture2D:
	# Periodic rounded cells, baked once rather than evaluating dozens of
	# circles per fragment. The shader turns this distance field into crests.
	var image: Image = Image.create(256, 256, false, Image.FORMAT_L8)
	for y: int in range(256):
		for x: int in range(256):
			var at: Vector2 = Vector2(x, y) / 32.0
			var cell: Vector2 = at.floor()
			var nearest: float = 4.0
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var neighbour: Vector2 = cell + Vector2(dx, dy)
					var wrapped: Vector2 = Vector2(posmod(int(neighbour.x), 8), posmod(int(neighbour.y), 8))
					var seed_value: float = wrapped.dot(Vector2(127.1, 311.7)) + 13.0
					var jitter: Vector2 = Vector2(fposmod(sin(seed_value) * 43758.5453, 1.0), fposmod(sin(seed_value + 19.3) * 23731.31, 1.0))
					nearest = minf(nearest, at.distance_to(neighbour + Vector2(.2, .2) + jitter * .6))
			var value: float = clampf(nearest, 0.0, 1.0)
			image.set_pixel(x, y, Color(value, value, value))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
