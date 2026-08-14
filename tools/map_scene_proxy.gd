class_name MapSceneProxy
extends RefCounted
## Honest one-act map stand-in for #233's headed frame-cost bench.
##
## Public interface:
##   MapSceneProxy.new(prop_second_octave, prop_triplanar, tilt_degrees = -55.0)
##   get_root() -> Node3D                 # parent into the caller's SubViewport
##   pan(delta_x: float) -> void          # relative journey-axis camera pan
##
## `tilt_degrees` is the signed Camera3D X rotation. The documented default is
## -55 degrees; the intended running-scene tuning band is -60 through -50.
## The caller owns viewport size and update policy. This builder never touches
## `scaling_3d_scale`.

const GROUND_SHADER: String = "res://presentation/map/map_ground.gdshader"
const PROP_SHADER: String = "res://presentation/map/map_prop.gdshader"
const GRADE_MIN: Vector2 = Vector2(-24.0, -12.0)
const GRADE_SIZE: Vector2 = Vector2(48.0, 24.0)
const GRADE_RESOLUTION: Vector2i = Vector2i(256, 128)
const TILE_SIZE: int = 128
const TILE_CELLS: int = 12
const GROUND_VALUE_LINEAR: float = 0.420
const PROP_VALUE_LINEAR: float = 0.100
const SUN_TO: Vector3 = Vector3(-0.35, 0.78, 0.52)

var _root: Node3D
var _camera: Camera3D
var _ground_mean: float = 0.5
var _prop_mean: float = 0.5


func _init(prop_second_octave: bool, prop_triplanar: bool,
		tilt_degrees: float = -55.0) -> void:
	_root = Node3D.new()
	_root.name = "MapSceneProxy"
	var positions: PackedVector3Array = _all_prop_positions()
	var grade: ImageTexture = ImageTexture.create_from_image(_grade_image(positions))
	var ground_surface: ImageTexture = ImageTexture.create_from_image(
		_noise_image(true, true))
	var prop_surface: ImageTexture = ImageTexture.create_from_image(
		_noise_image(prop_second_octave, false))
	var light: DirectionalLight3D = _add_key()
	var shader_sun: Vector3 = light.basis.z.normalized()
	var ground_material: ShaderMaterial = _material(
		GROUND_SHADER, ground_surface, grade, _ground_mean,
		GROUND_VALUE_LINEAR, shader_sun)
	var prop_path: String = PROP_SHADER if prop_triplanar else GROUND_SHADER
	var prop_material: ShaderMaterial = _material(
		prop_path, prop_surface, grade, _prop_mean,
		PROP_VALUE_LINEAR, shader_sun)
	_add_ground(ground_material)
	_add_props(prop_material)
	_add_environment()
	_add_camera(tilt_degrees)


func get_root() -> Node3D:
	return _root


func pan(delta_x: float) -> void:
	_camera.position.x += delta_x


func _material(shader_path: String, surface: Texture2D, grade: Texture2D,
		tex_mean: float, surface_value: float, shader_sun: Vector3) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(shader_path) as Shader
	material.set_shader_parameter("surface_tex", surface)
	material.set_shader_parameter("grade", grade)
	material.set_shader_parameter("grade_rect", Vector4(
		GRADE_MIN.x, GRADE_MIN.y, GRADE_SIZE.x, GRADE_SIZE.y))
	material.set_shader_parameter("tex_mean", tex_mean)
	material.set_shader_parameter("surface_value", surface_value)
	material.set_shader_parameter("sun", shader_sun)
	return material


func _add_key() -> DirectionalLight3D:
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = "MapKeyData"
	light.shadow_enabled = false
	light.basis = Basis.looking_at(-SUN_TO.normalized(), Vector3.UP)
	_root.add_child(light)
	return light


func _add_ground(material: ShaderMaterial) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = GRADE_SIZE
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "TerrainProxy"
	ground.mesh = plane
	ground.material_override = material
	_root.add_child(ground)


func _add_environment() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.018, 0.022, 0.045)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "MapEnvironment"
	world_environment.environment = environment
	_root.add_child(world_environment)


func _add_camera(tilt_degrees: float) -> void:
	_camera = Camera3D.new()
	_camera.name = "MapCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 20.0
	_camera.position = Vector3(-7.0, 18.0, 16.0)
	_camera.rotation_degrees = Vector3(tilt_degrees, 0.0, 0.0)
	_camera.far = 80.0
	_camera.current = true
	_root.add_child(_camera)


func _add_props(material: ShaderMaterial) -> void:
	var wedge: PrismMesh = PrismMesh.new()
	wedge.size = Vector3(2.3, 3.4, 1.25)
	_add_multimesh("FlatWedges", wedge, _wedge_positions(), material, 0)

	var slab: BoxMesh = BoxMesh.new()
	slab.size = Vector3(2.5, 0.62, 1.7)
	_add_multimesh("StackedSlabs", slab, _slab_positions(), material, 9)

	_add_multimesh("DabMasses", _dab_mesh(), _dab_positions(), material, 17)


func _add_multimesh(node_name: String, mesh: Mesh,
		positions: PackedVector3Array, material: ShaderMaterial, first_index: int) -> void:
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = positions.size()
	for i: int in range(positions.size()):
		var index: int = first_index + i
		var angle: float = float(index) * 1.117
		var scale: Vector3 = Vector3(
			0.82 + 0.09 * float(index % 4),
			0.86 + 0.08 * float((index + 2) % 3),
			0.84 + 0.07 * float((index + 1) % 4))
		if node_name == "StackedSlabs" and i % 2 == 1:
			scale *= 0.76
		var basis: Basis = Basis(Vector3.UP, angle).scaled(scale)
		multimesh.set_instance_transform(i, Transform3D(basis, positions[i]))
		multimesh.set_instance_custom_data(i, Color(
			fposmod(float(index) * 0.173, 1.0),
			fposmod(float(index) * 0.317, 1.0),
			fposmod(float(index) * 0.619, 1.0), 1.0))
	var instances: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instances.name = node_name
	instances.multimesh = multimesh
	instances.material_override = material
	_root.add_child(instances)


func _wedge_positions() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-21.0, 1.7, -6.5), Vector3(-17.0, 1.7, 5.7),
		Vector3(-12.0, 1.7, -7.7), Vector3(-6.5, 1.7, 6.4),
		Vector3(-1.0, 1.7, -5.8), Vector3(5.0, 1.7, 7.2),
		Vector3(10.5, 1.7, -6.7), Vector3(16.0, 1.7, 5.9),
		Vector3(21.0, 1.7, -7.5),
	])


## Four two-piece stacks. Each piece is deliberately a broad, flat module.
func _slab_positions() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-18.5, 0.31, 3.9), Vector3(-18.5, 0.86, 3.9),
		Vector3(-8.0, 0.31, -4.5), Vector3(-8.0, 0.86, -4.5),
		Vector3(4.0, 0.31, 4.2), Vector3(4.0, 0.86, 4.2),
		Vector3(15.5, 0.31, -4.0), Vector3(15.5, 0.86, -4.0),
	])


func _dab_positions() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-22.0, 0.0, 7.8), Vector3(-14.0, 0.0, -5.2),
		Vector3(-10.5, 0.0, 7.6), Vector3(-3.5, 0.0, 5.0),
		Vector3(2.0, 0.0, -7.7), Vector3(8.5, 0.0, 5.2),
		Vector3(13.0, 0.0, -7.8), Vector3(20.5, 0.0, 6.9),
	])


func _all_prop_positions() -> PackedVector3Array:
	var all: PackedVector3Array = _wedge_positions()
	all.append_array(_slab_positions())
	all.append_array(_dab_positions())
	return all


## Eight broad triangles with per-face normals: a dab, not a smooth pebble.
func _dab_mesh() -> ArrayMesh:
	var top: Vector3 = Vector3(0.05, 1.45, -0.08)
	var bottom: Vector3 = Vector3(-0.08, 0.0, 0.05)
	var east: Vector3 = Vector3(0.95, 0.56, 0.02)
	var north: Vector3 = Vector3(0.02, 0.62, -0.78)
	var west: Vector3 = Vector3(-0.82, 0.48, -0.04)
	var south: Vector3 = Vector3(-0.03, 0.58, 0.86)
	var triangles: PackedVector3Array = PackedVector3Array([
		top, east, north, top, south, east,
		top, west, south, top, north, west,
		bottom, north, east, bottom, east, south,
		bottom, south, west, bottom, west, north,
	])
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(0, triangles.size(), 3):
		var a: Vector3 = triangles[i]
		var b: Vector3 = triangles[i + 1]
		var c: Vector3 = triangles[i + 2]
		var normal: Vector3 = (b - a).cross(c - a).normalized()
		for vertex: Vector3 in [a, b, c]:
			surface.set_normal(normal)
			surface.add_vertex(vertex)
	return surface.commit()


func _grade_image(positions: PackedVector3Array) -> Image:
	var image: Image = Image.create_empty(
		GRADE_RESOLUTION.x, GRADE_RESOLUTION.y, false, Image.FORMAT_RGBA8)
	for y: int in range(GRADE_RESOLUTION.y):
		for x: int in range(GRADE_RESOLUTION.x):
			var world_x: float = GRADE_MIN.x + (float(x) + 0.5) \
				/ float(GRADE_RESOLUTION.x) * GRADE_SIZE.x
			var world_z: float = GRADE_MIN.y + (float(y) + 0.5) \
				/ float(GRADE_RESOLUTION.y) * GRADE_SIZE.y
			var journey: float = clampf((world_x - GRADE_MIN.x) / GRADE_SIZE.x, 0.0, 1.0)
			var corridor: float = 1.0 - smoothstep(2.6, 6.2, absf(world_z))
			var hue: float = lerpf(0.71, 0.61, journey)
			var saturation: float = lerpf(0.50, 0.25, journey)
			var value: float = 0.56
			hue = lerpf(hue, 0.12, corridor)
			saturation = lerpf(saturation, 0.08, corridor)
			value = lerpf(value, 1.0, corridor)
			var alpha: float = 1.0
			for prop_position: Vector3 in positions:
				var distance: float = Vector2(world_x - prop_position.x,
					world_z - prop_position.z).length()
				alpha = minf(alpha, lerpf(0.18, 1.0, smoothstep(0.35, 1.75, distance)))
			image.set_pixel(x, y, Color.from_hsv(hue, saturation, value, alpha))
	return image


func _noise_image(second_octave: bool, ground: bool) -> Image:
	var image: Image = Image.create_empty(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGB8)
	var total: float = 0.0
	for y: int in range(TILE_SIZE):
		for x: int in range(TILE_SIZE):
			var u: float = float(x) / float(TILE_SIZE)
			var v: float = float(y) / float(TILE_SIZE)
			var noise: float = _value_noise(u, v, TILE_CELLS)
			if second_octave:
				noise = noise * 0.68 + _value_noise(u, v, TILE_CELLS * 4) * 0.32
			noise = clampf(0.18 + noise * 0.72, 0.0, 1.0)
			total += noise
			image.set_pixel(x, y, Color(noise, noise, noise))
	var mean: float = total / float(TILE_SIZE * TILE_SIZE)
	if ground:
		_ground_mean = mean
	else:
		_prop_mean = mean
	image.generate_mipmaps()
	return image


func _value_noise(u: float, v: float, cells: int) -> float:
	var fx: float = u * float(cells)
	var fy: float = v * float(cells)
	var ix: int = floori(fx)
	var iy: int = floori(fy)
	var tx: float = fx - float(ix)
	var ty: float = fy - float(iy)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var low: float = lerpf(_hash01(ix, iy, cells), _hash01(ix + 1, iy, cells), tx)
	var high: float = lerpf(_hash01(ix, iy + 1, cells),
		_hash01(ix + 1, iy + 1, cells), tx)
	return lerpf(low, high, ty)


func _hash01(ix: int, iy: int, cells: int) -> float:
	var a: int = posmod(ix, cells)
	var b: int = posmod(iy, cells)
	var hash_value: int = (a * 374761393 + b * 668265263) & 0x7fffffff
	hash_value = ((hash_value ^ (hash_value >> 13)) * 1274126177) & 0x7fffffff
	return float(hash_value & 0xffff) / 65535.0
