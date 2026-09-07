class_name MapJourneyAssets
extends RefCounted
## Imported geometry profiles for the scenery actually used by a journey recipe.
## Root-relative transforms include every mesh in a glTF scene, not one child.
const ROOT: String = "res://assets/art/map-journey/"
var profiles: Dictionary = {}
var registry: MapAssetProfiles
var failure: String = ""
var digest: String = ""

func _init(kinds: Array[String]) -> void:
	var rows: Array = []
	var defaults: Dictionary = {}
	for kind: String in kinds:
		rows.append({"id":kind,"kind":"kit","act":0,"path":kind+".glb"})
		defaults[kind] = {"scale":1.0,"semantic_class":"arch_passable" if kind=="amber-arch" else "scenery","yaw_mode":"free","yaw_degrees":0.0}
	registry = MapAssetProfiles.new({"assets":rows,"profile_defaults":defaults},ROOT)
	var values: Array[Dictionary] = []
	for kind: String in kinds:
		var resource: PackedScene = load(ROOT+kind+".glb") as PackedScene
		if resource == null:
			failure = "Missing journey asset: "+kind
			return
		var item: Node3D = resource.instantiate() as Node3D
		var vertices: PackedVector3Array = []
		_collect(item,item.transform.affine_inverse(),vertices)
		item.free()
		if vertices.is_empty():
			failure = "Journey asset has no mesh geometry: "+kind
			return
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var profile: Dictionary = registry.profile(kind,mesh)
		if profile.is_empty():
			failure = "Invalid journey asset profile: "+kind
			return
		profiles[kind] = profile
		values.append(profile)
	digest = registry.digest(values)

static func _collect(node: Node, parent: Transform3D, vertices: PackedVector3Array) -> void:
	var pose: Transform3D = parent
	if node is Node3D:
		pose = parent*(node as Node3D).transform
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null:
			var transformed: PackedVector3Array = pose*mesh.get_faces()
			vertices.append_array(transformed)
	for child: Node in node.get_children(): _collect(child,pose,vertices)

func bundle() -> Dictionary:
	return {"profiles":profiles.duplicate(true),"digest":digest} if failure.is_empty() else {}
