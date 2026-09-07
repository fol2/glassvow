extends SceneTree
## Ray probes distinguish real full-depth openings from dark surface marks.
const Kit = preload("res://tools/map_workshop/stone_bridge/pointed_parapets.gd")
const M = preload("res://presentation/map/landscape/mesh_tools.gd")
func _initialize() -> void:
	for backwards: bool in [false,true]:
		var edges: Array[Dictionary] = []
		for i: int in range(29):
			var a: float = (29-i)*.1 if backwards else i*.1
			var b: float = (28-i)*.1 if backwards else (i+1)*.1
			edges.append({"a":Vector3(a,0,0),"b":Vector3(b,0,0),"outward":Vector3.BACK})
		var body: SurfaceTool = SurfaceTool.new()
		var trim: SurfaceTool = SurfaceTool.new()
		body.begin(Mesh.PRIMITIVE_TRIANGLES)
		trim.begin(Mesh.PRIMITIVE_TRIANGLES)
		var kit: RefCounted = Kit.new()
		kit.build(edges,body,trim,[],{})
		assert(kit.bays==1,"Tiny boundary pieces must form one complete bay")
		var meshes: Array[ArrayMesh] = [M.finish(body),M.finish(trim)]
		for x: float in [.805,2.095]:
			assert(not _hit(meshes,x,.50),"Both approved B arches must be true openings")
		assert(_hit(meshes,1.45,.5),"The centre mullion must remain solid")
		assert(_hit(meshes,.805,.88),"The coping must span the opening")
		assert(_hit(meshes,.805,.10),"The sill must remain solid")
		var normals: PackedVector3Array = meshes[1].surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		var vertices: PackedVector3Array = meshes[1].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var upward: int = 0
		for i: int in range(vertices.size()):
			if absf(vertices[i].y-.95)<.0002 and normals[i].y>.99:
				upward += 1
		assert(upward>0,"Both outline directions need outward-facing coping tops")
	print("PASS: two real arch openings, solid sill/mullion/coping, complete bays and both outline windings")
	quit()

func _hit(meshes: Array[ArrayMesh],x: float,y: float) -> bool:
	for mesh: ArrayMesh in meshes:
		var faces: PackedVector3Array = mesh.get_faces()
		for i: int in range(0,faces.size(),3):
			var hit: Variant = Geometry3D.segment_intersects_triangle(Vector3(x,y,-1),Vector3(x,y,1),faces[i],faces[i+1],faces[i+2])
			if hit!=null:
				return true
	return false
