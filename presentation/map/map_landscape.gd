class_name MapLandscape
extends Node3D
## Layered land and depth-tested paths assembled from the final compiler result.

const CUTS: Array[float] = [-20.5, 10.5]
const PLINTH_HEIGHT: float = 0.12
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
var _lamps: Array[OmniLight3D] = []


func prepare(data: Dictionary, catalogue: MapLandscapeAssets, seed: int) -> void:
	assets = catalogue
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
	mineral.set_shader_parameter("mineral", assets.stone)
	mineral.set_shader_parameter("groundcover", assets.ground)
	mineral.set_shader_parameter("region_tint", MapRegions.LAND_TINT[assets.act])
	masonry = mineral.duplicate() as ShaderMaterial
	masonry.set_shader_parameter("heath", false)
	masonry.set_shader_parameter("metres_per_tile", 3.5)
	masonry.set_shader_parameter("tint", Color(1.12, 1.18, 1.15))
	for polygon: PackedVector2Array in boundaries:
		land(polygon)
	batch("Broken ledges", assets.meshes["slate-cluster"], ledges, masonry)
	var floor_mesh: PlaneMesh = PlaneMesh.new()
	floor_mesh.size = Vector2(250, 180)
	var floor_material: ShaderMaterial = mineral.duplicate() as ShaderMaterial
	floor_material.set_shader_parameter("basin", true)
	floor_material.set_shader_parameter("region_tint", MapRegions.WATER[assets.act])
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
		if assets.act != 2:
			_lamp(item.position, 4.0, 0.65)
	_contact_shadows(scenery, heroes)
	_build_seals()


func _contact_shadows(scenery: Dictionary, heroes: Dictionary) -> void:
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color(0.01, 0.025, 0.03, 0.56), Color(0.01, 0.025, 0.03, 0)])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 1.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2.ONE
	var transforms: Array[Transform3D] = []
	for placements: Dictionary in [scenery, heroes]:
		for value: Dictionary in placements.values():
			var id: String = str(value["asset_id"])
			if id == "slate-cluster":
				continue
			var transform: Transform3D = placement_transform(value)
			var width: float = assets.meshes[id].get_aabb().size.x * transform.basis.get_scale().x
			var centre: Vector3 = transform.origin + Vector3(0, -0.008, -width * 0.12)
			transforms.append(Transform3D(Basis.from_scale(Vector3(width, 1, width * 0.62)), centre))
	batch("Contact shade", plane, transforms, material)
	var shadows: MultiMeshInstance3D = get_node_or_null("Contact shade") as MultiMeshInstance3D
	if shadows != null:
		shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func candidates() -> Dictionary:
	var out: Dictionary = {}
	var choices: Array = MapLandscapeAssets.SCENERY[assets.act]
	for i: int in range(2400):
		var p: Vector3 = Vector3(rng.randf_range(-46, 46), 0, rng.randf_range(-24, 24))
		var id: String = choices[i % choices.size()]
		var grove: float = ground_noise.get_noise_2d(p.x * 0.7 + 42, p.z * 0.7)
		var low: bool = id in ["heath-tuft", "slate-cluster"]
		if grove < (-0.2 if low or assets.act == 0 else 0.04):
			continue
		var unit: float = rng.randf_range(0.42, 0.95) if id != "slate-cluster" else rng.randf_range(0.25, 0.6)
		var rank: String = "0-copse" if id == "ash-copse" else ("2-heath" if id == "heath-tuft" else ("3-stone" if id == "slate-cluster" else "1-grove"))
		out[rank + "%04d" % i] = {"placement": {
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
	stone.height = PLINTH_HEIGHT
	var transforms: Array[Transform3D] = []
	for anchor: Vector3 in anchors:
		transforms.append(plinth_transform(anchor))
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


func plinth_transform(anchor: Vector3) -> Transform3D:
	var height: float = (1.0 if assets.act == 1 else 6.2) if is_gap(anchor, 0.8) else PLINTH_HEIGHT
	return Transform3D(Basis.from_scale(Vector3(1, height / PLINTH_HEIGHT, 1)),
		anchor + Vector3.UP * (0.045 - height * 0.5))


func set_node_states(states: Dictionary) -> void:
	if seals == null:
		return
	for lamp: OmniLight3D in _lamps:
		lamp.free()
	_lamps.clear()
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
		if state in ["current", "open"]:
			_lamps.append(_lamp(anchors[i], 3.1, 0.45))


func _lamp(at: Vector3, reach: float, energy: float) -> OmniLight3D:
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.position = at + Vector3(0, 0.9, 0.4)
	lamp.light_color = Color("efbd76")
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.shadow_enabled = false
	add_child(lamp)
	return lamp


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
	return cut + sin(z * 0.19) * 1.4 + sin(z * 0.61) * 0.3


func is_gap(p: Vector3, margin: float = 0.0) -> bool:
	for cut: float in CUTS:
		if absf(p.x - gap(cut, p.z)) < 1.5 + margin:
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
	var points: PackedVector2Array = polygon
	# Native ear clipping respects every concave bank. Delaunay plus a centroid
	# filter can keep a triangle whose edges cross open water.
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(points)
	var top: SurfaceTool = SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(0, indices.size(), 3):
		var a: Vector2 = points[indices[i]]
		var b: Vector2 = points[indices[i + 1]]
		var c: Vector2 = points[indices[i + 2]]
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
	return Vector3(p.x, -0.035 + ground_noise.get_noise_2dv(p) * 0.025, p.y)


func ground_colour(p: Vector2) -> Color:
	var moss: float = smoothstep(-0.32, 0.4, ground_noise.get_noise_2dv(p))
	return Color("354646").lerp(Color("555a47"), moss)


func road() -> void:
	var paving: SurfaceTool = SurfaceTool.new()
	var cobbles: SurfaceTool = SurfaceTool.new()
	cobbles.begin(Mesh.PRIMITIVE_TRIANGLES)
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
				var bridge: bool = is_gap(start, 0.55) or is_gap(end, 0.55) or is_gap((start + end) * 0.5, 0.55) or start.y > 0.15
				var half: float = 0.50 if bridge else 0.52
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
				var corners: Array[Vector3] = [start - right * half, end - right * half,
					end + right * half, start + right * half]
				var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]
				for corner: int in [0, 1, 2, 0, 2, 3]:
					paving.set_uv(uvs[corner])
					paving.add_vertex(corners[corner])
				# Broken, inset flagstones give a physical edge at close zoom. Every
				# slab stays inside its own canonical leg; no bend becomes a chord.
				var along: Vector3 = (end - start).normalized()
				var centre: Vector3 = (start + end) * 0.5 + Vector3.UP * 0.012
				var length: float = start.distance_to(end) * 0.42
				var width: float = 0.29 + 0.025 * sin(start.x * 4.7 + start.z * 3.1)
				var shade: Color = colour * (0.82 + 0.14 * sin(start.x * 5.3 + start.z * 6.1))
				var bevel: float = 0.07
				var points: Array[Vector2] = [Vector2(-width + bevel, -length), Vector2(width - bevel, -length),
					Vector2(width, -length + bevel), Vector2(width, length - bevel),
					Vector2(width - bevel, length), Vector2(-width + bevel, length),
					Vector2(-width, length - bevel), Vector2(-width, -length + bevel)]
				for i: int in range(points.size()):
					var first: Vector2 = points[i]
					var next: Vector2 = points[(i + 1) % points.size()]
					triangle(cobbles, centre, centre + right * next.x + along * next.y,
						centre + right * first.x + along * first.y, shade, shade, shade)
		for index: int in range(1, line.size() - 1):
			var centre: Vector3 = line[index] + Vector3.UP * 0.017
			for side: int in range(12):
				paving.set_uv(Vector2(0.5, 0))
				paving.add_vertex(centre)
				for angle: float in [TAU * side / 12.0, TAU * (side + 1) / 12.0]:
					paving.set_uv(Vector2(1, 0))
					paving.add_vertex(centre + Vector3(cos(angle), 0, sin(angle)) * 0.52)
	var road_paint: ShaderMaterial = mineral.duplicate() as ShaderMaterial
	road_paint.set_shader_parameter("tint", Color(0.73, 0.83, 0.88))
	road_paint.set_shader_parameter("metres_per_tile", 9.5)
	road_paint.set_shader_parameter("heath", true)
	road_paint.set_shader_parameter("trail", true)
	mesh_node("Processional paths", finish(paving), road_paint).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paving_stone: StandardMaterial3D = StandardMaterial3D.new()
	paving_stone.vertex_color_use_as_albedo = true
	paving_stone.albedo_color = Color("4d5d60")
	paving_stone.roughness = 1.0
	mesh_node("Worn flagstones", finish(cobbles), paving_stone).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
