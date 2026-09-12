extends RefCounted
## Independent native comparison: engine-composed source scenes versus GPU draw instances.
static func audit(kit: Node3D) -> Dictionary:
	var sources: Dictionary = {}
	var geometry_checked: Dictionary = {}
	var failures: Array = []
	var count: int = 0
	var maximum: float = 0
	var rows: Array = kit.get("placed")
	var anchors: Array = kit.get("placed_nodes")
	for i: int in range(rows.size()):
		var anchor: Node3D = anchors[i]
		if not anchor.has_meta("static_draws"): continue
		var row: Dictionary = rows[i]
		var kind: String = row["kind"]
		if not sources.has(kind):
			var source: PackedScene = load("res://assets/art/map-journey/"+kind+".glb") as PackedScene
			var reference: Node3D = source.instantiate() as Node3D
			kit.add_child(reference)
			reference.hide()
			preload("res://presentation/map/landscape/asset_surfaces.gd").prepare(reference)
			sources[kind]={"root":reference,"transform":reference.transform,"parts":reference.find_children("*","MeshInstance3D",true,false)}
		var reference: Node3D = sources[kind]["root"]
		reference.transform=sources[kind]["transform"]
		var scale_value: float = row["scale"]
		var at: Vector3 = row["position"]
		reference.position=at+Vector3.UP*reference.position.y*scale_value
		reference.scale=Vector3.ONE*scale_value
		reference.rotation.y=row["yaw"]
		var parts: Array = sources[kind]["parts"]
		var draws: Array = anchor.get_meta("static_draws")
		if draws.size()!=parts.size():
			failures.append({"kind":kind,"reason":"Source mesh parts omitted or added"})
			continue
		for part_index: int in range(parts.size()):
			var original: MeshInstance3D = parts[part_index]
			var draw: MultiMeshInstance3D = draws[part_index]["draw"]
			var instance: int = draws[part_index]["index"]
			var actual: Transform3D = draw.global_transform*draw.multimesh.get_instance_transform(instance)
			var expected: Transform3D = original.global_transform
			var error: float = actual.origin.distance_to(expected.origin)
			for axis: int in range(3): error=maxf(error,actual.basis[axis].distance_to(expected.basis[axis]))
			maximum=maxf(maximum,error)
			if error>.00003: failures.append({"kind":kind,"placement":i,"part":part_index,"transform_error":error})
			var key: int = draw.multimesh.mesh.get_instance_id()
			if not geometry_checked.has(key):
				geometry_checked[key]=true
				if draw.multimesh.mesh.get_faces()!=original.mesh.get_faces():
					failures.append({"kind":kind,"reason":"Imported triangle geometry changed"})
				for surface: int in range(original.mesh.get_surface_count()):
					var before: Material = original.get_active_material(surface)
					var after: Material = draw.multimesh.mesh.surface_get_material(surface)
					for property: Dictionary in before.get_property_list():
						var usage: int = property["usage"]
						var name: String = str(property["name"])
						if (usage&PROPERTY_USAGE_STORAGE)!=0 and name not in ["resource_name","resource_local_to_scene"] and before.get(name)!=after.get(name):
							failures.append({"kind":kind,"reason":"Material property changed","property":name})
			count+=1
	for data: Dictionary in sources.values():
		var source: Node3D = data["root"]
		source.free()
	return {"draw_instances":count,"mesh_templates":geometry_checked.size(),"maximum_transform_error":maximum,"failure_count":failures.size(),"failures":failures.slice(0,12)}

static func negative_canary(kit: Node3D) -> bool:
	for anchor: Node3D in kit.get("placed_nodes"):
		if not anchor.has_meta("static_draws"): continue
		var links: Array = anchor.get_meta("static_draws")
		if links.is_empty(): continue
		var draw: MultiMeshInstance3D = links[0]["draw"]
		var index: int = links[0]["index"]
		var original: Transform3D = draw.multimesh.get_instance_transform(index)
		var shifted: Transform3D = original
		shifted.origin.x+=0.01
		draw.multimesh.set_instance_transform(index,shifted)
		var rejected: Dictionary = audit(kit)
		draw.multimesh.set_instance_transform(index,original)
		return rejected["failure_count"]==1 and rejected["maximum_transform_error"]>0.009
	return false
