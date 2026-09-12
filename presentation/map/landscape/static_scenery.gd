extends Node3D
## Static imported meshes share spatially bounded draw batches. Placement anchors
## retain identity; each actual GPU instance is linked back to its source part.
const Surfaces = preload("res://presentation/map/landscape/asset_surfaces.gd")
const CELL: float = 16.0
var failure: String = ""
var templates: Dictionary = {}
var groups: Dictionary = {}
var material_pool: Dictionary = {}
var draw_count: int = 0
func prepare(path: String, kind: String) -> Node3D:
	if not templates.has(path):
		var packed: PackedScene = load(path) as PackedScene
		if packed==null:
			failure="Cannot load static scenery: "+path
			return null
		var original: Node3D = packed.instantiate() as Node3D
		var surfaces: int = Surfaces.prepare(original,material_pool)
		if (kind.begins_with("conifer") or kind.begins_with("ash-")) and kind not in ["conifer-snag","ash-fern"] and surfaces==0:
			failure="Static foliage has no prepared cut-out surface: "+kind
		var parts: Array[Dictionary] = []
		_collect(original,original.transform.affine_inverse(),parts)
		templates[path]={"root":original.transform,"parts":parts}
		original.free()
		if not failure.is_empty(): return null
	var anchor: Node3D = Node3D.new()
	anchor.name=kind
	anchor.transform=templates[path]["root"]
	anchor.set_meta("static_template",path)
	anchor.set_meta("static_draws",[])
	return anchor
func register(anchor: Node3D) -> void:
	var path: String = anchor.get_meta("static_template")
	var parts: Array = templates[path]["parts"]
	var cell: Vector2i = Vector2i(floori(anchor.position.x/CELL),floori(anchor.position.z/CELL))
	for index: int in range(parts.size()):
		var key: String = path+"/%d/%d/%d"%[index,cell.x,cell.y]
		if not groups.has(key): groups[key]={"part":parts[index],"placements":[]}
		groups[key]["placements"].append(anchor)
func finish() -> void:
	for key: String in groups:
		var part: Dictionary = groups[key]["part"]
		var anchors: Array = groups[key]["placements"]
		var relative: Transform3D = part["transform"]
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=part["mesh"]
		multi.instance_count=anchors.size()
		var draw: MultiMeshInstance3D = MultiMeshInstance3D.new()
		draw.multimesh=multi
		draw.layers=part["layers"]
		draw.cast_shadow=part["shadow"]
		add_child(draw)
		for i: int in range(anchors.size()):
			var anchor: Node3D = anchors[i]
			multi.set_instance_transform(i,anchor.transform*relative)
			var links: Array = anchor.get_meta("static_draws")
			links.append({"draw":draw,"index":i,"part":relative})
		draw_count+=1
func _collect(node: Node, parent: Transform3D, parts: Array[Dictionary]) -> void:
	var pose: Transform3D = parent
	if node is Node3D:
		var spatial: Node3D = node as Node3D
		if not spatial.visible: return
		pose=parent*spatial.transform
	if node is MeshInstance3D:
		var item: MeshInstance3D = node as MeshInstance3D
		if item.skin!=null or not item.mesh is ArrayMesh:
			failure="Static scenery contains unsupported deforming geometry"
			return
		var mesh: ArrayMesh = item.mesh.duplicate() as ArrayMesh
		for surface: int in range(mesh.get_surface_count()):
			mesh.surface_set_material(surface,item.get_active_material(surface))
		parts.append({"mesh":mesh,"transform":pose,"layers":item.layers,"shadow":item.cast_shadow})
	for child: Node in node.get_children(): _collect(child,pose,parts)
