extends SceneTree
## Equivalence probe for the indexed woodland grid; no rendering shortcuts.
const Terrain = preload("res://presentation/map/landscape/terrain.gd")
func _initialize() -> void:
	var terrain: Terrain = Terrain.new()
	terrain._land()
	var actual: Mesh = (terrain.get_node("Quiet sculpted ground") as MeshInstance3D).mesh
	var reference: SurfaceTool = SurfaceTool.new()
	reference.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ix: int in range(192):
		for iz: int in range(120):
			var corners: PackedVector3Array = []
			for offset: Vector2 in [Vector2.ZERO,Vector2(0,.5),Vector2(.5,.5),Vector2(.5,0)]:
				var p: Vector2 = Vector2(-48+ix*.5,-30+iz*.5)+offset
				corners.append(Vector3(p.x,terrain.height_at(p.x,p.y),p.y))
			for index: int in [0,2,1,0,3,2]:
				var p: Vector3 = corners[index]
				reference.set_color(Color("555663")*(.96+.05*sin(p.x*.22+p.z*.15)))
				reference.add_vertex(p)
	reference.generate_normals()
	var expected: Mesh = reference.commit()
	var original: Array = expected.surface_get_arrays(0)
	var indexed: Array = actual.surface_get_arrays(0)
	var faces: PackedInt32Array = indexed[Mesh.ARRAY_INDEX]
	var max_position: float = 0
	var max_normal: float = 0
	var max_colour: float = 0
	for i: int in range(faces.size()):
		var a: Vector3 = original[Mesh.ARRAY_VERTEX][i]
		var b: Vector3 = indexed[Mesh.ARRAY_VERTEX][faces[i]]
		max_position = maxf(max_position,a.distance_to(b))
		var na: Vector3 = original[Mesh.ARRAY_NORMAL][i]
		var nb: Vector3 = indexed[Mesh.ARRAY_NORMAL][faces[i]]
		max_normal = maxf(max_normal,na.distance_to(nb))
		var ca: Color = original[Mesh.ARRAY_COLOR][i]
		var cb: Color = indexed[Mesh.ARRAY_COLOR][faces[i]]
		max_colour = maxf(max_colour,absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)+absf(ca.a-cb.a))
	print("GROUND_EQUIVALENCE ",JSON.stringify({"corners":faces.size(),"vertices":indexed[Mesh.ARRAY_VERTEX].size(),"position_error":max_position,"normal_error":max_normal,"colour_error":max_colour}))
	terrain.free()
	quit(0 if faces.size()==138240 and max_position==0 and max_normal<.00001 and max_colour==0 else 1)
