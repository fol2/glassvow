extends RefCounted
## Native-friendly batching retains primitive triangles, texture mapping and shading.
static func run(fails: Array[String]) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size=Vector3.ONE
	var reference: SurfaceTool = SurfaceTool.new()
	var candidate: SurfaceTool = SurfaceTool.new()
	for tool: SurfaceTool in [reference,candidate]: tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var batch: RefCounted = preload("res://presentation/map/chapters/common/box_batch.gd").new(candidate)
	for i: int in range(12):
		var basis: Basis = Basis(Vector3.UP,i*.3)
		basis.z.y=.2
		var pose: Transform3D = Transform3D(basis.scaled_local(Vector3(.34,.16,.2+i*.03)),Vector3(i*.5,i*.2,-i*.1))
		reference.append_from(box,0,pose)
		batch.append(pose)
	var results: Array = []
	for tool: SurfaceTool in [reference,candidate]:
		tool.generate_normals()
		results.append(tool.commit().surface_get_arrays(0))
	# SurfaceTool may deduplicate its index buffers differently. Compare the
	# attributes actually consumed by each rendered triangle instead.
	var old_indices: PackedInt32Array = results[0][Mesh.ARRAY_INDEX]
	var new_indices: PackedInt32Array = results[1][Mesh.ARRAY_INDEX]
	if old_indices.size()!=new_indices.size():
		fails.append("Batched stone changes the triangle count")
		return
	for i: int in range(old_indices.size()):
		var old_vertex: Vector3 = results[0][Mesh.ARRAY_VERTEX][old_indices[i]]
		var new_vertex: Vector3 = results[1][Mesh.ARRAY_VERTEX][new_indices[i]]
		var old_normal: Vector3 = results[0][Mesh.ARRAY_NORMAL][old_indices[i]]
		var new_normal: Vector3 = results[1][Mesh.ARRAY_NORMAL][new_indices[i]]
		var old_uv: Vector2 = results[0][Mesh.ARRAY_TEX_UV][old_indices[i]]
		var new_uv: Vector2 = results[1][Mesh.ARRAY_TEX_UV][new_indices[i]]
		if old_vertex!=new_vertex or not old_normal.is_equal_approx(new_normal) or old_uv!=new_uv:
			fails.append("Batched stone changes a rendered triangle attribute at "+str(i))
			return
