extends "res://tools/map_workshop/common/inspection.gd"
## Chapter-specific framing; input and snapshot inspection remain shared.
var landmark: Node3D

func focus_library() -> void:
	var points: Array[Vector3] = []
	_collect(landmark,points)
	_frame(points,false,-35)

func focus_whole() -> void:
	var points: Array[Vector3] = []
	for point: Vector3 in anchors.values():
		points.append(point)
	for x: float in [-21.0,21.0]:
		for z: float in [-21.0,21.0]:
			points.append(library_at+Vector3(x,18,z))
	_frame(points,true,-10)

func _collect(node: Node,points: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var item: MeshInstance3D = node
		var bounds: AABB = item.mesh.get_aabb()
		for i: int in range(8):
			points.append(item.global_transform*bounds.get_endpoint(i))
	for child: Node in node.get_children():
		_collect(child,points)
