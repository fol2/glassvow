extends RefCounted
const Binding = preload("res://tools/map_workshop/common/workshop_hero_binding.gd")
static func run(fails: Array[String]) -> void:
	var root: Node3D = Node3D.new()
	root.position = Vector3(4,0,0)
	var child: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(2,4,6)
	child.mesh = box
	child.position = Vector3(0,2,3)
	child.rotation.y = PI*.5
	root.add_child(child)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	Binding._collect(root,Transform3D.IDENTITY,surface)
	var mesh: ArrayMesh = surface.commit()
	var bounds: AABB = mesh.get_aabb()
	if not bounds.position.is_equal_approx(Vector3(1,0,2)) or not bounds.size.is_equal_approx(Vector3(6,4,2)):
		fails.append("hero profile: nested mesh transforms lost during aggregation")
	if mesh.get_faces().size() != box.get_faces().size():
		fails.append("hero profile: source triangles lost during aggregation")
	root.free()
