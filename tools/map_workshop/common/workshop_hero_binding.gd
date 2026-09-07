extends RefCounted
## Bind workshop glTF geometry through the existing production asset-profile contract.
const F = preload("res://domain/map_layout/map_layout_canonical.gd")
const Spatial = preload("res://presentation/map/map_spatial_profile.gd")

static func apply(recipe: Dictionary, quality: Dictionary, nodes: Array,
		assets: Dictionary, heroes: Dictionary) -> Dictionary:
	for role: String in recipe.get("hero_assets",{}):
		var specification: Dictionary = recipe["hero_assets"][role]
		var id: String = str(specification["asset_id"])
		var path: String = str(specification["path"])
		var document: GLTFDocument = GLTFDocument.new()
		var state: GLTFState = GLTFState.new()
		if document.append_from_file(path,state) != OK:
			return {"ok":false,"reason":"Cannot load workshop hero: "+path}
		var root: Node3D = document.generate_scene(state)
		if root == null:
			return {"ok":false,"reason":"Cannot construct workshop hero: "+path}
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		_collect(root,Transform3D.IDENTITY,surface)
		var mesh: ArrayMesh = surface.commit()
		root.free()
		var yaw: float = F.float_value(specification.get("yaw_degrees",0.0))
		var scale: float = F.float_value(specification.get("scale",1.0))
		var registry: MapAssetProfiles = MapAssetProfiles.new({"assets":[{"id":id,"kind":"terminus","path":path}],
			"profile_defaults":{id:{"scale":scale,"semantic_class":"hero","yaw_mode":"fixed","yaw_degrees":yaw}}},"")
		var profile: Dictionary = registry.profile(id,mesh)
		if profile.is_empty():
			return {"ok":false,"reason":"Invalid workshop hero geometry: "+id}
		var anchor_node: Dictionary = {}
		for node: Dictionary in nodes:
			if str(node["id"]) == str(specification["node_id"]):
				anchor_node = node
		if anchor_node.is_empty():
			return {"ok":false,"reason":"Workshop hero references absent node"}
		var offset: Array = specification["offset"]
		var position: Vector3 = Spatial.anchor(anchor_node,quality)+Vector3(F.float_value(offset[0]),F.float_value(offset[1]),F.float_value(offset[2]))
		assets["profiles"][id] = profile
		heroes["anchors"][role] = {"asset_id":id,"profile_id":id,"position":[position.x,position.y,position.z],"yaw_radians":deg_to_rad(yaw),"scale":[scale,scale,scale]}
		var polygon: Array = []
		for point: Vector2 in registry.transformed_footprint(profile,position,yaw,Vector3.ONE*scale):
			polygon.append([point.x,point.y])
		heroes["protected_zones"][role+"-zone"] = {"role":role,"polygon":polygon}
	var profiles: Array[Dictionary] = []
	for profile: Dictionary in assets["profiles"].values():
		profiles.append(profile)
	assets["digest"] = MapAssetProfiles.new().digest(profiles)
	return {"ok":not str(assets["digest"]).is_empty()}

static func _collect(node: Node3D, parent: Transform3D, surface: SurfaceTool) -> void:
	var transform: Transform3D = parent*node.transform
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node
		if instance.mesh != null:
			for vertex: Vector3 in instance.mesh.get_faces():
				surface.add_vertex(transform*vertex)
	for child: Node in node.get_children():
		if child is Node3D:
			var spatial_child: Node3D = child
			_collect(spatial_child,transform,surface)
