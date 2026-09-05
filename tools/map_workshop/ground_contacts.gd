extends Node3D
## Physical stone footings follow the rendered land; no baked contact shadows.
const Meshes = preload("res://tools/map_workshop/mesh_tools.gd")
const Terrain = preload("res://tools/map_workshop/terrain.gd")
var stone: SurfaceTool = SurfaceTool.new()
var stone_count: int = 0
var terrain: Terrain

func begin(surface: Terrain) -> void:
	terrain = surface
	stone.begin(Mesh.PRIMITIVE_TRIANGLES)

func place(kind: String, at: Vector3, scale_value: float, yaw: float) -> void:
	if kind == "amber-arch":
		for side: float in [-1, 1]:
			var offset: Vector3 = Vector3(side * 1.65, 0, 0).rotated(Vector3.UP, yaw)
			_pad(at + offset * scale_value, Vector2(1.2, 1.35) * scale_value, yaw)
	elif kind == "memorial":
		_pad(at, Vector2(0.92, 0.63) * scale_value, yaw)


func _pad(at: Vector3, footprint: Vector2, yaw: float) -> void:
	var low: float = at.y - 0.08
	for x: float in [-0.5, 0.5]:
		for z: float in [-0.5, 0.5]:
			var p: Vector3 = at + Vector3(x * footprint.x, 0, z * footprint.y).rotated(Vector3.UP, yaw)
			low = minf(low, terrain.surface_height(p.x, p.z) - 0.06)
	var depth: float = at.y + 0.025 - low
	var block: BoxMesh = BoxMesh.new()
	block.size = Vector3(footprint.x, depth, footprint.y)
	stone.append_from(block, 0, Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, low + depth * 0.5, at.z)))
	stone_count += 1

func finish() -> void:
	if stone_count:
		Meshes.node(self, Meshes.finish(stone), Meshes.material(Color("464048")), "Ground-following stone footings")
