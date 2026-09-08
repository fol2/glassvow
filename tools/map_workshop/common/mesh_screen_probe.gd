extends RefCounted
## Diagnostic ray receipts identify actual rendered triangles under a screen point.
static func run(root: Node3D,camera: Camera3D,pixels: Array[Vector2]) -> Array[Dictionary]:
	var meshes: Array[MeshInstance3D] = []
	_collect(root,meshes)
	var report: Array[Dictionary] = []
	for pixel: Vector2 in pixels:
		var origin: Vector3 = camera.project_ray_origin(pixel)
		var direction: Vector3 = camera.project_ray_normal(pixel)
		var end: Vector3 = origin+direction*camera.far
		var hits: Array[Dictionary] = []
		for item: MeshInstance3D in meshes:
			if not item.is_visible_in_tree():
				continue
			if (item.global_transform*item.mesh.get_aabb()).intersects_segment(origin,end)==null:
				continue
			var faces: PackedVector3Array = item.mesh.get_faces()
			for index: int in range(0,faces.size(),3):
				var a: Vector3 = item.global_transform*faces[index]
				var b: Vector3 = item.global_transform*faces[index+1]
				var c: Vector3 = item.global_transform*faces[index+2]
				var hit: Variant = Geometry3D.segment_intersects_triangle(origin,end,a,b,c)
				if hit == null:
					continue
				var point: Vector3 = hit
				var normal: Vector3 = -(b-a).cross(c-a).normalized()
				hits.append({"mesh":str(item.get_path()),"triangle":index/3,"point":point,"normal":normal,"front":normal.dot(direction)<0,"distance":origin.distance_to(point)})
		hits.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a["distance"]<b["distance"])
		report.append({"pixel":pixel,"hits":hits.slice(0,8)})
	return report
static func _collect(node: Node,out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		var item: MeshInstance3D = node
		if item.mesh != null:
			out.append(item)
	for child: Node in node.get_children():
		_collect(child,out)
