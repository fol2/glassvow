extends RefCounted
static func run(fails: Array[String]) -> void:
	var source: Node3D = Node3D.new()
	source.position=Vector3(7,2,-4)
	source.rotation.y=.4
	var group: Node3D = Node3D.new()
	source.add_child(group)
	group.position=Vector3(-2,1,3)
	group.rotation.y=-.7
	var item: MeshInstance3D = MeshInstance3D.new()
	item.mesh=BoxMesh.new()
	item.position=Vector3(1,2,1)
	item.scale=Vector3(2,3,.5)
	item.layers=2
	item.material_override=StandardMaterial3D.new()
	var dressed: StandardMaterial3D = StandardMaterial3D.new()
	dressed.albedo_color=Color("d52348")
	item.set_surface_override_material(0,dressed)
	group.add_child(item)
	var restored: Node3D = Node3D.new()
	restored.transform=source.transform
	var snapshot: GDScript = preload("res://presentation/map/chapters/common/static_mesh_snapshot.gd")
	var rows: Array = snapshot.capture(source)
	snapshot.restore(restored,rows)
	var old_faces: PackedVector3Array = []
	var new_faces: PackedVector3Array = []
	MapJourneyAssets._collect(source,Transform3D.IDENTITY,old_faces)
	MapJourneyAssets._collect(restored,Transform3D.IDENTITY,new_faces)
	if old_faces.size()!=new_faces.size(): fails.append("Static snapshot loses geometry")
	else:
		for i: int in range(old_faces.size()):
			if old_faces[i].distance_to(new_faces[i])>.00001:
				fails.append("Static snapshot changes a nested world transform")
				break
	var replay: MeshInstance3D = restored.get_child(0) as MeshInstance3D
	if replay.layers!=2 or replay.material_override!=item.material_override:
		fails.append("Static snapshot changes material or visibility layers")
	if replay.get_surface_override_material(0)!=dressed: fails.append("Static snapshot loses per-surface architectural dressing")
	source.free()
	restored.free()
