extends RefCounted
## Small mesh construction primitives for the native art workshop.

static func material(colour: Color, roughness: float = 0.95) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = roughness
	return mat

static func node(parent: Node3D, mesh: Mesh, mat: Material, label: String) -> MeshInstance3D:
	var item: MeshInstance3D = MeshInstance3D.new()
	item.name = label
	item.mesh = mesh
	item.material_override = mat
	parent.add_child(item)
	return item

static func box(parent: Node3D, at: Vector3, size: Vector3, mat: Material,
		label: String = "Block", yaw: float = 0.0) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var item: MeshInstance3D = node(parent, mesh, mat, label)
	item.position = at
	item.rotation.y = yaw
	return item

static func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		colour: Color = Color.WHITE) -> void:
	for p: Vector3 in [a, b, c]:
		surface.set_color(colour)
		surface.add_vertex(p)

static func finish(surface: SurfaceTool) -> ArrayMesh:
	surface.generate_normals()
	return surface.commit()

static func v3(value: Array) -> Vector3:
	return Vector3(float(str(value[0])), float(str(value[1])), float(str(value[2])))
