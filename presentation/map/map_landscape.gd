class_name MapLandscape
extends Node3D
## Layered land and depth-tested paths assembled from the final compiler result.

const CUTS: Array[float] = [-20.5, 10.5]
var anchors: PackedVector3Array = []
var paths: Array[PackedVector3Array] = []
var boundaries: Array[PackedVector2Array] = []
var ledges: Array[Transform3D] = []
var ground_noise: FastNoiseLite
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var assets: MapLandscapeAssets
var mineral: ShaderMaterial
var masonry: ShaderMaterial
var seals: MultiMesh
var node_ids: Array[String] = []
var _data: Dictionary = {}


func prepare(data: Dictionary, catalogue: MapLandscapeAssets, seed: int) -> void:
	assets = catalogue
	_data = data
	rng.seed = seed
	ground_noise = FastNoiseLite.new()
	ground_noise.seed = 470 + assets.act
	ground_noise.frequency = 0.19
	var node_data: Dictionary = data["node_anchors"]
	var edge_data: Dictionary = data["edges"]
	node_ids = MapLayoutCanonical.sorted_keys(node_data)
	for id: String in node_ids:
		anchors.append(v3(data["node_anchors"][id]))
	for id: String in MapLayoutCanonical.sorted_keys(edge_data):
		var line: PackedVector3Array = []
		for raw: Array in data["edges"][id]["centerline"]:
			line.append(v3(raw))
		paths.append(line)
	for plate: int in range(3):
		boundaries.append(outline(plate))


func build(data: Dictionary) -> void:
	mineral = ShaderMaterial.new()
	mineral.shader = load("res://presentation/map/map_mineral.gdshader") as Shader
	var source: Texture2D = load(MapLandscapeAssets.ROOT + "slate-heath.png") as Texture2D
	var texture_image: Image = source.get_image()
	texture_image.generate_mipmaps()
	mineral.set_shader_parameter("mineral", ImageTexture.create_from_image(texture_image))
	mineral.set_shader_parameter("region_tint", [Color("a4b6b1"), Color("7da8b5"), Color("9290ac"), Color("c3b6a2")][assets.act])
	masonry = mineral.duplicate() as ShaderMaterial
	masonry.set_shader_parameter("heath", false)
	masonry.set_shader_parameter("metres_per_tile", 3.5)
	masonry.set_shader_parameter("tint", Color(1.12, 1.18, 1.15))
	for polygon: PackedVector2Array in boundaries:
		land(polygon)
	batch("Broken ledges", assets.meshes["slate-cluster"], ledges, masonry)
	var floor_mesh: PlaneMesh = PlaneMesh.new()
	floor_mesh.size = Vector2(250, 180)
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = [Color("14272e"), Color("1b404c"), Color("191b2b"), Color("53504d")][assets.act]
	floor_material.roughness = 0.72
	mesh_node("Still water", floor_mesh, floor_material, Vector3(0, -0.8 if assets.act == 1 else -6.0, 0))
	road()
	var scenery: Dictionary = data["scenery_instances"]
	var heroes: Dictionary = data["hero_placements"]
	for id: String in assets.meshes:
		var transforms: Array[Transform3D] = []
		for key: String in MapLayoutCanonical.sorted_keys(scenery):
			var placement: Dictionary = data["scenery_instances"][key]
			if str(placement["asset_id"]) == id:
				transforms.append(placement_transform(placement))
		if not transforms.is_empty():
			batch(id, assets.meshes[id], transforms, masonry if id == "slate-cluster" else null)
	for key: String in MapLayoutCanonical.sorted_keys(heroes):
		var placement: Dictionary = data["hero_placements"][key]
		var id: String = str(placement["asset_id"])
		var item: MeshInstance3D = mesh_node("Landmark " + key, assets.meshes[id])
		item.transform = placement_transform(placement)
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_seals()


func candidates() -> Dictionary:
	var out: Dictionary = {}
	var choices: Array = MapLandscapeAssets.SCENERY[assets.act]
	for i: int in range(900):
		var p: Vector3 = Vector3(rng.randf_range(-46, 46), 0, rng.randf_range(-24, 24))
		if ground_noise.get_noise_2d(p.x * 0.7 + 42, p.z * 0.7) < -0.10:
			continue
		var id: String = choices[i % choices.size()]
		var unit: float = rng.randf_range(0.65, 1.05) if id != "slate-cluster" else rng.randf_range(0.3, 0.8)
		out["grove-%04d" % i] = {"placement": {
			"asset_id": id, "profile_id": id, "semantic_zone": "pilgrimage-surround",
			"transform": {"origin": [p.x, p.y, p.z],
				"yaw_radians": rng.randf_range(-PI, PI) if id == "slate-cluster" else 0.0,
				"scale": [unit, unit, unit]}}}
	return out


func supports(footprint: PackedVector2Array) -> bool:
	for polygon: PackedVector2Array in boundaries:
		if Geometry2D.clip_polygons(footprint, polygon).is_empty():
			return true
	return false


func _build_seals() -> void:
	var stone: CylinderMesh = CylinderMesh.new()
	stone.radial_segments = 12
	stone.top_radius = 0.69
	stone.bottom_radius = 0.75
	stone.height = 0.12
	var transforms: Array[Transform3D] = []
	for anchor: Vector3 in anchors:
		transforms.append(Transform3D(Basis.IDENTITY, anchor - Vector3.UP * 0.015))
	batch("Waystone plinths", stone, transforms, masonry)
	var seal: CylinderMesh = CylinderMesh.new()
	seal.radial_segments = 32
	seal.top_radius = 0.44
	seal.bottom_radius = 0.44
	seal.height = 0.015
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	seals = MultiMesh.new()
	seals.transform_format = MultiMesh.TRANSFORM_3D
	seals.use_colors = true
	seals.mesh = seal
	seals.instance_count = anchors.size()
	for i: int in range(anchors.size()):
		seals.set_instance_transform(i, Transform3D(Basis.IDENTITY, anchors[i] + Vector3.UP * 0.06))
		seals.set_instance_color(i, Color("394b50"))
	var item: MultiMeshInstance3D = MultiMeshInstance3D.new()
	item.name = "Waystone seals"
	item.multimesh = seals
	item.material_override = material
	add_child(item)


func set_node_states(states: Dictionary) -> void:
	if seals == null:
		return
	for i: int in range(node_ids.size()):
		var state: String = str(states.get(node_ids[i], "cold"))
		var colour: Color = Color("394b50")
		if state == "current":
			colour = Color("ffe0a0")
		elif state == "open":
			colour = Color("bca06e")
		elif state == "walked":
			colour = Color("627e80")
		seals.set_instance_color(i, colour)


func batch(label: String, mesh: Mesh, transforms: Array[Transform3D], material: Material = null) -> void:
	if transforms.is_empty():
		return
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i: int in range(transforms.size()):
		multi.set_instance_transform(i, transforms[i])
	var item: MultiMeshInstance3D = MultiMeshInstance3D.new()
	item.name = label
	item.multimesh = multi
	item.material_override = material
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if material != null else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(item)


static func placement_transform(placement: Dictionary) -> Transform3D:
	var value: Dictionary = placement["transform"]
	return Transform3D(Basis(Vector3.UP, MapLayoutCanonical.float_value(value["yaw_radians"]))
		.scaled_local(v3(value["scale"])), v3(value["origin"]))


func gap(cut: float, z: float) -> float:
	var x: float = cut + sin(z * 0.19) * 1.4 + sin(z * 0.61) * 0.3
	for anchor: Vector3 in anchors:
		var dz: float = absf(anchor.z - z)
		if dz < 3.5 and absf(anchor.x - x) < 3.0:
			var side: float = -1.0 if x < anchor.x else 1.0
			x = lerpf(x, anchor.x + side * 3.0, 1.0 - smoothstep(1.7, 3.5, dz))
	return x


func is_gap(p: Vector3) -> bool:
	for cut: float in CUTS:
		if absf(p.x - gap(cut, p.z)) < 1.5:
			return true
	return false


func outline(plate: int) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for i: int in range(45):
		var z: float = -27.0 + i * 1.25
		var x: float = -49.0 + sin(z * 0.25) * 1.2 if plate == 0 else gap(CUTS[plate - 1], z) + 1.5
		points.append(Vector2(x, z))
	for i: int in range(44, -1, -1):
		var z: float = -27.0 + i * 1.25
		var x: float = 48.0 + sin(z * 0.31) * 1.5 if plate == 2 else gap(CUTS[plate], z) - 1.5
		points.append(Vector2(x, z))
	return points


func land(polygon: PackedVector2Array) -> void:
	var points: PackedVector2Array = polygon.duplicate()
	for z: int in range(-26, 28):
		for x: int in range(-50, 51):
			var p: Vector2 = Vector2(x + rng.randf_range(-0.27, 0.27), z + rng.randf_range(-0.27, 0.27))
			if Geometry2D.is_point_in_polygon(p, polygon):
				points.append(p)
	var indices: PackedInt32Array = Geometry2D.triangulate_delaunay(points)
	var top: SurfaceTool = SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(0, indices.size(), 3):
		var a: Vector2 = points[indices[i]]
		var b: Vector2 = points[indices[i + 1]]
		var c: Vector2 = points[indices[i + 2]]
		if not Geometry2D.is_point_in_polygon((a + b + c) / 3.0, polygon):
			continue
		if (b - a).cross(c - a) < 0.0:
			var swap: Vector2 = b
			b = c
			c = swap
		triangle(top, ground_point(a), ground_point(b), ground_point(c), ground_colour(a), ground_colour(b), ground_colour(c))
	mesh_node("Slate heath", finish(top), mineral)
	var cliff: SurfaceTool = SurfaceTool.new()
	cliff.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre: Vector2 = Vector2.ZERO
	for point: Vector2 in polygon:
		centre += point / polygon.size()
	for layer: int in range(9):
		for i: int in range(polygon.size()):
			var a: Vector2 = polygon[i]
			var b: Vector2 = polygon[(i + 1) % polygon.size()]
			var inset: float = sin(layer * 2.7) * 0.14 + layer * 0.045
			var next_inset: float = sin((layer + 1) * 2.7) * 0.14 + (layer + 1) * 0.045
			var y: float = -0.18 - layer * 0.64
			var shade: Color = Color("38494b").lerp(Color("10212b"), layer / 11.0)
			shade *= 0.84 + 0.16 * sin(layer * 3.7 + i * 1.8)
			var av: Vector2 = a.move_toward(centre, inset)
			var bv: Vector2 = b.move_toward(centre, inset)
			var cv: Vector2 = b.move_toward(centre, next_inset)
			var dv: Vector2 = a.move_toward(centre, next_inset)
			quad(cliff, Vector3(av.x, y, av.y), Vector3(bv.x, y, bv.y),
				Vector3(cv.x, y - 0.64, cv.y), Vector3(dv.x, y - 0.64, dv.y), shade)
	mesh_node("Exposed strata", finish(cliff), masonry)
	for i: int in range(0, polygon.size(), 4):
		var point: Vector2 = polygon[i]
		for level: int in range(2):
			var basis: Basis = Basis(Vector3.UP, rng.randf_range(-PI, PI)).scaled_local(Vector3(0.8, 1.2, 0.6))
			ledges.append(Transform3D(basis, Vector3(point.x, -0.5 - level * 1.75, point.y)))


func ground_point(p: Vector2) -> Vector3:
	return Vector3(p.x, -0.15 + ground_noise.get_noise_2dv(p) * 0.055, p.y)


func ground_colour(p: Vector2) -> Color:
	var moss: float = smoothstep(-0.32, 0.4, ground_noise.get_noise_2dv(p))
	return Color("354646").lerp(Color("555a47"), moss)


func road() -> void:
	var paving: SurfaceTool = SurfaceTool.new()
	paving.begin(Mesh.PRIMITIVE_TRIANGLES)
	var block: BoxMesh = BoxMesh.new()
	block.size = Vector3.ONE
	var wall: SurfaceTool = SurfaceTool.new()
	wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	for line: PackedVector3Array in paths:
		for segment: int in range(line.size() - 1):
			var a: Vector3 = line[segment]
			var b: Vector3 = line[segment + 1]
			var steps: int = maxi(1, int(ceilf(a.distance_to(b) / 0.65)))
			var right: Vector3 = (b - a).cross(Vector3.UP).normalized()
			for step: int in range(steps):
				var start: Vector3 = a.lerp(b, float(step) / steps) + Vector3(0, 0.015, 0)
				var end: Vector3 = a.lerp(b, float(step + 1) / steps) + Vector3(0, 0.015, 0)
				var bridge: bool = is_gap(start) or is_gap(end) or is_gap((start + end) * 0.5) or start.y > 0.15
				var half: float = 0.50 if bridge else 0.47 + 0.055 * sin(start.x * 7.0 + start.z * 3.0)
				var colour: Color = Color("8a8974") if bridge else Color("727568")
				if bridge:
					var basis: Basis = Basis(Vector3.UP, atan2((b - a).x, (b - a).z))
					var centre: Vector3 = (start + end) * 0.5
					var span: float = start.distance_to(end)
					wall.append_from(block, 0, Transform3D(basis.scaled_local(Vector3(1.08, 0.4, span + 0.01)), centre - Vector3.UP * 0.19))
					for side: float in [-1.0, 1.0]:
						wall.append_from(block, 0, Transform3D(basis.scaled_local(Vector3(0.13, 0.26, span - 0.018)), centre + right * side * 0.58 + Vector3.UP * 0.19))
						if step % 3 == 0:
							wall.append_from(block, 0, Transform3D(basis.scaled_local(Vector3(0.25, 0.48, 0.25)), centre + right * side * 0.58 + Vector3.UP * 0.26))
				# Width varies within the compiled corridor; the centreline stays exact.
				quad(paving, start - right * half, end - right * half,
					end + right * half, start + right * half, colour)
	var road_paint: ShaderMaterial = mineral.duplicate() as ShaderMaterial
	road_paint.set_shader_parameter("tint", Color(1.2, 1.16, 1.03))
	road_paint.set_shader_parameter("metres_per_tile", 5.0)
	road_paint.set_shader_parameter("heath", false)
	road_paint.set_shader_parameter("trail", true)
	mesh_node("Processional paths", finish(paving), road_paint)
	mesh_node("Bridge masonry", finish(wall), masonry)


func mesh_node(label: String, mesh: Mesh, material: Material = null, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var item: MeshInstance3D = MeshInstance3D.new()
	item.name = label
	item.mesh = mesh
	item.material_override = material
	item.position = at
	add_child(item)
	return item


func finish(surface: SurfaceTool) -> ArrayMesh:
	surface.generate_normals()
	return surface.commit()


func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	surface.set_color(ca)
	surface.add_vertex(a)
	surface.set_color(cb)
	surface.add_vertex(b)
	surface.set_color(cc)
	surface.add_vertex(c)


func quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color) -> void:
	triangle(surface, a, b, c, colour, colour, colour)
	triangle(surface, a, c, d, colour, colour, colour)


static func v3(raw: Variant) -> Vector3:
	var value: Array = raw
	var x: float = value[0]
	var y: float = value[1]
	var z: float = value[2]
	return Vector3(x, y, z)
