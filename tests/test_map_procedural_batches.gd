extends RefCounted
static func run(fails: Array[String]) -> void:
	var root: Node3D = Node3D.new()
	var art: Node3D = Node3D.new()
	root.add_child(art)
	art.rotation.y=.3
	art.position=Vector3(2,0,2)
	var sources: Array[MeshInstance3D] = []
	for i: int in range(3):
		var item: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size=Vector3(i+1,2,.5)
		item.mesh=box
		item.material_override=StandardMaterial3D.new()
		item.position=Vector3(i*2,1,0)
		art.add_child(item)
		sources.append(item)
	var batch: Node3D = preload("res://presentation/map/chapters/common/procedural_batches.gd").new()
	root.add_child(batch)
	var roots: Array[Node3D] = [art]
	var shaders: Array[Shader] = []
	batch.build(roots,shaders)
	if batch.links.size()!=3 or batch.groups.size()!=1: fails.append("Equivalent static materials/boxes do not share a bounded draw")
	for link: Dictionary in batch.links:
		var source: MeshInstance3D = link["source"]
		var draw: MultiMeshInstance3D = link["draw"]
		var instance: int = link["index"]
		var original: PackedVector3Array = source.mesh.get_faces()
		var actual: PackedVector3Array = draw.multimesh.mesh.get_faces()
		var old_pose: Transform3D = art.transform*source.transform
		# The dummy headless renderer always returns identity for MultiMesh.
		# Native execution also checks the renderer's actual instance transform.
		var new_pose: Transform3D = link["submitted_pose"] if DisplayServer.get_name()=="headless" else draw.multimesh.get_instance_transform(instance)
		if source.visible or original.size()!=actual.size(): fails.append("Static draw retains a duplicate source or changes triangle count")
		else:
			for i: int in range(original.size()):
				if (old_pose*original[i]).distance_to(new_pose*actual[i])>.00001:
					fails.append("Static draw moves an actual source triangle")
					break
	root.free()
