extends RefCounted
## Foliage uses cut-out depth and coverage rather than order-dependent blending.
static func prepare(root: Node3D) -> int:
	var count: int = 0
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = child as MeshInstance3D
		if instance.mesh == null:
			continue
		for index: int in range(instance.mesh.get_surface_count()):
			var original: StandardMaterial3D = instance.get_active_material(index) as StandardMaterial3D
			if original == null or not original.resource_name.begins_with("Foliage /"):
				continue
			var material: StandardMaterial3D = original.duplicate() as StandardMaterial3D
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = 0.3
			material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.roughness = 0.96
			material.metallic = 0
			instance.set_surface_override_material(index, material)
			count += 1
	return count
