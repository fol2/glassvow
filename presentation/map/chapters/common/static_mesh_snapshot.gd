extends RefCounted
## Derived static scenery only; actors, water and gameplay are rebuilt normally.
static func capture(root: Node3D) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	_collect(root,root.transform.affine_inverse(),rows)
	return rows

static func _collect(node: Node3D,parent: Transform3D,rows: Array[Dictionary]) -> void:
	var pose: Transform3D = parent*node.transform
	if node is MeshInstance3D:
		var item: MeshInstance3D = node
		rows.append({"name":str(item.name),"mesh":item.mesh,"material":item.material_override,"transform":pose,
			"layers":item.layers,"shadows":item.cast_shadow,"visible":item.get_meta("unbatched_visible",item.visible)})
	for child: Node in node.get_children():
		if child is Node3D: _collect(child as Node3D,pose,rows)

static func restore(root: Node3D,rows: Array) -> void:
	for row: Dictionary in rows:
		var item: MeshInstance3D = MeshInstance3D.new()
		item.name=row["name"]
		item.mesh=row["mesh"]
		item.material_override=row["material"]
		item.transform=row["transform"]
		item.layers=row["layers"]
		item.cast_shadow=row["shadows"]
		item.visible=row["visible"]
		root.add_child(item)
