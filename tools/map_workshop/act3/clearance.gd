extends RefCounted
## Actual transformed terrain triangles and conservative building bounds.
const Probe = preload("res://tools/map_workshop/common/mesh_probe.gd")
func measure(ground: Node3D,palace: Node3D,routes: Node3D,scenery: Node3D) -> Dictionary:
	var probe: Probe = Probe.new()
	for child: Node in ground.get_children():
		if child is MeshInstance3D:
			var item: MeshInstance3D = child
			var surface: SurfaceTool = SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for vertex: Vector3 in item.mesh.get_faces():
				surface.add_vertex(item.global_transform*vertex)
			probe.build(surface.commit())
	var checked: int = 0
	var hits: int = 0
	var first: Array[Dictionary] = []
	var corridors: Dictionary = routes.sampled_routes.duplicate()
	var links: Dictionary = routes.ruin_links
	corridors.merge(links)
	for key: String in corridors:
		var line: PackedVector3Array = corridors[key]
		for i: int in range(line.size()):
			var p: Vector3 = line[i]
			var direction: Vector3 = line[mini(i+1,line.size()-1)]-line[maxi(i-1,0)]
			var side: Vector2 = Vector2(-direction.z,direction.x).normalized()
			for offset: float in [-.75,-.5,-.25,0,.25,.5,.75]:
				checked += 1
				for height: float in probe.heights(Vector2(p.x,p.z)+side*offset):
					if height>p.y+.08 and height<p.y+2.2:
						hits += 1
						if first.size()<12:
							first.append({"edge":key,"at":str(p),"height":height})
	var buildings: Array[Node3D] = [palace,scenery]
	return {"terrain_samples":checked,"terrain_body_hits":hits,"first_hits":first,
		"architecture":preload("res://tools/map_workshop/act2/placement_audit.gd").new().measure(buildings,routes),
		"scope":"Rendered ground triangles at seven offsets across 1.5 m; all source and decorative routes. Building bounds use the shared conservative body probe."}
