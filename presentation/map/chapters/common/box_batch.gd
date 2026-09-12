extends RefCounted
## Read primitive arrays once. Per-piece Mesh reads stall the native renderer.
var surface: SurfaceTool
var vertices: PackedVector3Array
var uvs: PackedVector2Array
var indices: PackedInt32Array
var vertex_count: int = 0

func _init(target: SurfaceTool) -> void:
	surface=target
	var box: BoxMesh = BoxMesh.new()
	box.size=Vector3.ONE
	var arrays: Array = box.surface_get_arrays(0)
	vertices=arrays[Mesh.ARRAY_VERTEX]
	uvs=arrays[Mesh.ARRAY_TEX_UV]
	indices=arrays[Mesh.ARRAY_INDEX]

func append(pose: Transform3D) -> void:
	for i: int in range(vertices.size()):
		surface.set_uv(uvs[i])
		surface.add_vertex(pose*vertices[i])
	for index: int in indices: surface.add_index(vertex_count+index)
	vertex_count+=vertices.size()
