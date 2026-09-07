extends RefCounted
## The same measured asset contract for authored meshes and imported scenery.
static func measure(id: String, item: Node3D, source_path: String, act: int) -> Dictionary:
	var registry: MapAssetProfiles = MapAssetProfiles.new({"assets":[{"id":id,"kind":"kit","act":act,"path":source_path.trim_prefix("res://")}],
		"profile_defaults":{id:{"scale":1.0,"semantic_class":"scenery","yaw_mode":"free","yaw_degrees":0.0}}},"res://")
	var vertices: PackedVector3Array = []
	MapJourneyAssets._collect(item,item.transform.affine_inverse(),vertices)
	if vertices.is_empty(): return {}
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var profile: Dictionary = registry.profile(id,mesh)
	if profile.is_empty(): return {}
	return {"profile":profile,"registry":registry}
