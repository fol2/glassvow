extends RefCounted
## Verify actual rendered deck coverage, including ownership at shared landings.
const Probe = preload("res://tools/map_workshop/act2/mesh_probe.gd")
static func measure(causeways: Node3D) -> Dictionary:
	var probe: Probe = Probe.new()
	var maximum_grade: float = 0
	var steepest: Vector3 = Vector3.ZERO
	var steepest_vertices: Array = []
	var steepest_area: float = 0
	for mesh: ArrayMesh in causeways.deck_meshes:
		probe.build(mesh)
		var vertices: PackedVector3Array = mesh.get_faces()
		for i: int in range(0,vertices.size(),3):
			var normal: Vector3 = (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
			if absf(normal.y)<.0000001:
				continue
			var grade: float = Vector2(normal.x,normal.z).length()/absf(normal.y)
			if grade>maximum_grade:
				maximum_grade = grade
				steepest = (vertices[i]+vertices[i+1]+vertices[i+2])/3
				steepest_area = absf(normal.y)/2
				steepest_vertices = [[vertices[i].x,vertices[i].y,vertices[i].z],[vertices[i+1].x,vertices[i+1].y,vertices[i+1].z],[vertices[i+2].x,vertices[i+2].y,vertices[i+2].z]]
	var samples: int = 0
	var missing: int = 0
	var worst_error: float = 0
	var failures: Array[Dictionary] = []
	var corridors: Dictionary = causeways.sampled_routes.duplicate()
	var links: Dictionary = causeways.ruin_links
	corridors.merge(links)
	for key: String in corridors:
		var points: PackedVector3Array = corridors[key]
		for i: int in range(points.size()):
			var p: Vector3 = points[i]
			var forward: Vector3 = points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]
			var side: Vector2 = Vector2(-forward.z,forward.x).normalized()
			for lateral: int in range(-3,4):
				var at: Vector2 = Vector2(p.x,p.z)+side*lateral*.2
				var heights: PackedFloat32Array = probe.heights(at)
				samples += 1
				if heights.is_empty():
					missing += 1
					if failures.size()<8:
						failures.append({"edge":key,"at":[at.x,at.y],"reason":"missing rendered deck"})
					continue
				var error: float = INF
				for height: float in heights:
					error = minf(error,absf(height-p.y-.022))
				worst_error = maxf(worst_error,error)
	return {"samples":samples,"missing":missing,"first_failures":failures,
		"maximum_height_difference_from_route":worst_error,"maximum_rendered_triangle_grade":maximum_grade,
		"steepest_projected_area":steepest_area,"steepest_vertices":steepest_vertices,"steepest_at":[steepest.x,steepest.y,steepest.z],
		"scope":"Actual deck triangles, all route samples at seven offsets across 1.2 m; triangle grade across both complete decks"}
