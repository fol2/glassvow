extends RefCounted
## Render exactly the resolved structural quads. There is no second walking layer.
static func build(plan: Dictionary) -> ArrayMesh:
	if plan.get("ok") != true:
		return null
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for key: String in ["tops", "risers", "walls"]:
		var quads: Array = plan[key]
		for quad: PackedVector3Array in quads:
			for triangle: int in range(1, quad.size()-1):
				for index: int in [0, triangle, triangle+1]:
					surface.add_vertex(quad[index])
	surface.generate_normals()
	return surface.commit()
