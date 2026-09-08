extends RefCounted
## Cached real mesh triangles: open arches are not treated as solid bounding boxes.
var meshes: Array[Dictionary] = []
func collect(root: Node3D) -> void:
	if root is MeshInstance3D:
		var item: MeshInstance3D = root
		if item.mesh != null:
			cache_faces(item.mesh.get_faces(),item.global_transform,_cull_mode(item.material_override))
	for child: Node in root.get_children():
		if child is Node3D:
			collect(child as Node3D)
## Unknown or mixed materials remain conservative; explicit overrides follow rendering.
func _cull_mode(material: Material) -> int:
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).cull_mode
	if material is ShaderMaterial:
		var shader: Shader = (material as ShaderMaterial).shader
		if shader != null:
			var modes: RegEx = RegEx.create_from_string("render_mode\\s+([^;]+);")
			for match_result: RegExMatch in modes.search_all(shader.code):
				var options: String = match_result.get_string(1)
				if "cull_disabled" in options:
					return BaseMaterial3D.CULL_DISABLED
				if "cull_front" in options:
					return BaseMaterial3D.CULL_FRONT
			return BaseMaterial3D.CULL_BACK
	return BaseMaterial3D.CULL_DISABLED

func cache_faces(source: PackedVector3Array, transform: Transform3D = Transform3D.IDENTITY, cull_mode: int = BaseMaterial3D.CULL_DISABLED) -> void:
	var faces: PackedVector3Array = source.duplicate()
	for index: int in range(faces.size()):
		faces[index] = transform*faces[index]
	# Spatially local triangle batches avoid testing an entire landscape
	# whenever its chapter-wide bounding box intersects the sightline.
	for start: int in range(0,faces.size(),384):
		var batch: PackedVector3Array = faces.slice(start,mini(start+384,faces.size()))
		var bounds: AABB = AABB(batch[0],Vector3.ZERO)
		for vertex: Vector3 in batch:
			bounds = bounds.expand(vertex)
		meshes.append({"bounds":bounds.grow(.0001),"faces":batch,"cull_mode":cull_mode})

func blocked(camera: Camera3D, target: Vector3) -> bool:
	var screen: Vector2 = camera.unproject_position(target)
	var origin: Vector3 = camera.project_ray_origin(screen)
	return segment_blocked(origin,target)

func segment_blocked(origin: Vector3,target: Vector3) -> bool:
	for item: Dictionary in meshes:
		var bounds: AABB = item["bounds"]
		if bounds.intersects_segment(origin,target) == null:
			continue
		var faces: PackedVector3Array = item["faces"]
		for index: int in range(0,faces.size(),3):
			var facing: float = (faces[index+1]-faces[index]).cross(faces[index+2]-faces[index]).dot(target-origin)
			var culling: int = item.get("cull_mode",BaseMaterial3D.CULL_DISABLED)
			if (culling==BaseMaterial3D.CULL_BACK and facing<=0) or (culling==BaseMaterial3D.CULL_FRONT and facing>=0):
				continue
			var hit: Variant = Geometry3D.segment_intersects_triangle(origin,target,faces[index],faces[index+1],faces[index+2])
			if hit != null:
				return true
	return false
