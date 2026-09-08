extends Node3D
## Spatially bounded static draws; retain source parts for occupancy and audit.
const CELL: float = 16.0
var links: Array[Dictionary] = []
var groups: Dictionary = {}
var material_keys: Dictionary = {}
var unit_box: BoxMesh = BoxMesh.new()
var world_shaders: Array[Shader] = []

func build(roots: Array[Node3D],allowed_world_shaders: Array[Shader]) -> void:
	unit_box.size=Vector3.ONE
	world_shaders=allowed_world_shaders
	for root: Node3D in roots: _collect(root)
	for group: Dictionary in groups.values():
		var rows: Array = group["parts"]
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=group["mesh"]
		multi.instance_count=rows.size()
		var draw: MultiMeshInstance3D = MultiMeshInstance3D.new()
		draw.multimesh=multi
		draw.material_override=group["material"]
		draw.layers=group["layers"]
		draw.cast_shadow=group["shadows"]
		add_child(draw)
		for i: int in range(rows.size()):
			var row: Dictionary = rows[i]
			var pose: Transform3D = row["pose"]
			multi.set_instance_transform(i,pose)
			var source: MeshInstance3D = row["source"]
			source.set_meta("unbatched_visible",source.visible)
			source.visible=false
			links.append({"source":source,"draw":draw,"index":i,"shape":row["shape"],"submitted_pose":pose,"material_key":group["material_key"]})

func _collect(node: Node3D) -> void:
	if not node.visible: return
	if node is MeshInstance3D:
		var item: MeshInstance3D = node
		if item.mesh!=null and item.skin==null and item.mesh.get_surface_count()==1:
			_register(item)
	for child: Node in node.get_children():
		if child is Node3D: _collect(child as Node3D)

func _register(item: MeshInstance3D) -> void:
	var mesh: Mesh = item.mesh
	var material: Material = item.get_active_material(0)
	var shape: Transform3D = Transform3D.IDENTITY
	var mesh_key: String = str(mesh.get_instance_id())
	if mesh is BoxMesh:
		var box: BoxMesh = mesh
		var normalise: bool = material is StandardMaterial3D and not material.uv1_triplanar and not material.uv2_triplanar
		if material is ShaderMaterial: normalise=world_shaders.has(material.shader)
		if normalise and not box.flip_faces and box.subdivide_width==0 and box.subdivide_height==0 and box.subdivide_depth==0:
			shape.basis=Basis.IDENTITY.scaled_local(box.size)
			mesh=unit_box
			mesh_key="unit-box"
		else:
			mesh_key="box/"+str([box.size,box.flip_faces,box.subdivide_width,box.subdivide_height,box.subdivide_depth])
	var pose: Transform3D = relative(item)*shape
	var cell: Vector2i = Vector2i(floori(pose.origin.x/CELL),floori(pose.origin.z/CELL))
	var mat_key: String = material_key(material)
	var key: String = str([mesh_key,mat_key,cell,item.layers,item.cast_shadow])
	if not groups.has(key):
		groups[key]={"mesh":mesh,"material":material,"material_key":mat_key,"layers":item.layers,"shadows":item.cast_shadow,"parts":[]}
	groups[key]["parts"].append({"source":item,"pose":pose,"shape":shape})

func relative(item: Node3D) -> Transform3D:
	var pose: Transform3D = item.transform
	var parent: Node = item.get_parent()
	while parent!=get_parent() and parent is Node3D:
		pose=(parent as Node3D).transform*pose
		parent=parent.get_parent()
	return pose

func material_key(material: Material) -> String:
	if material==null: return "none"
	var id: int = material.get_instance_id()
	if material_keys.has(id): return material_keys[id]
	var values: Dictionary = {"class":material.get_class()}
	for property: Dictionary in material.get_property_list():
		var usage: int = property["usage"]
		var name: String = property["name"]
		if (usage&PROPERTY_USAGE_STORAGE)==0 or name in ["resource_name","resource_local_to_scene"]: continue
		var value: Variant = material.get(name)
		values[name]=value.get_instance_id() if value is Resource else value
	var hash: HashingContext = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes(values))
	var result: String = hash.finish().hex_encode()
	material_keys[id]=result
	return result
