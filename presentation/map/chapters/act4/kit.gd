extends RefCounted
## Approved void models with shared stone and amber glazing finishes.
const SOURCES: Dictionary = {
 "threshold-window":preload("res://assets/map/act4/threshold-window.glb"),
 "other-side-hearth":preload("res://assets/map/act4/other-side-hearth.glb"),
 "memory-stele":preload("res://assets/map/act4/memory-stele.glb")}
func instance(label: String) -> Node3D:
	var packed: PackedScene = SOURCES[label]
	var root: Node3D = packed.instantiate()
	_finish_kit(root)
	return root

func _finish_kit(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node
		for i: int in range(mesh_node.mesh.get_surface_count()):
			var mat: Material = mesh_node.mesh.surface_get_material(i)
			if not mat is StandardMaterial3D: continue
			var original: StandardMaterial3D = mat
			var name_value: String = original.resource_name
			if not (name_value.begins_with("Amber pane") or name_value.begins_with("Stone course") or name_value=="Charcoal dressed stone"): continue
			var finish: ShaderMaterial = ShaderMaterial.new()
			finish.shader = preload("res://presentation/map/chapters/act4/kit_finish.gdshader")
			finish.set_shader_parameter("tint",original.albedo_color)
			finish.set_shader_parameter("glass",1.0 if name_value.begins_with("Amber pane") else 0.0)
			mesh_node.set_surface_override_material(i,finish)
	for child: Node in node.get_children(): _finish_kit(child)
