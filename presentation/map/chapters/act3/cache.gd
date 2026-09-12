extends RefCounted
## Cached court geometry preserves the measured faces, materials and window light.
const Snapshot = preload("res://presentation/map/chapters/common/static_mesh_snapshot.gd")
static func capture(landscape: Node3D) -> Dictionary:
	var courts: Node3D = landscape.terrain.courts
	var architecture: Array[Dictionary] = []
	for placement: Dictionary in landscape.measured_placements:
		var item: Node3D = placement["node"]
		var row: Dictionary = placement.duplicate()
		row.erase("node")
		row["transform"]=landscape.global_transform.affine_inverse()*item.global_transform
		row["meshes"]=Snapshot.capture(item)
		architecture.append(row)
	var lights: Array[Dictionary] = []
	for child: Node in landscape.find_children("*","OmniLight3D",true,false):
		var light: OmniLight3D = child
		lights.append({"transform":landscape.global_transform.affine_inverse()*light.global_transform,
			"colour":light.light_color,"energy":light.light_energy,"range":light.omni_range,
			"attenuation":light.omni_attenuation,"specular":light.light_specular})
	var foundations: Node3D = landscape.architecture_foundations
	return {"kind":"obsidian-court","meshes":Snapshot.capture(courts),"joined":courts.joined,"court":courts.court,
		"rows":courts.rows,"divisions":courts.divisions,"envelopes":courts.envelopes,"groups":courts.stair_groups,
		"architecture_routes":courts.architecture_routes,"stone":courts.stone,
		"architecture":architecture,"profiles":landscape.measured_profiles,"lights":lights,
		"foundations":Snapshot.capture(foundations)}

static func restore_courts(courts: Node3D,data: Dictionary) -> void:
	var meshes: Array = data["meshes"]
	Snapshot.restore(courts,meshes)
	courts.joined=data["joined"]
	courts.court=data["court"]
	courts.rows=data["rows"]
	courts.divisions.assign(data["divisions"])
	courts.envelopes.assign(data["envelopes"])
	courts.stair_groups.assign(data["groups"])
	courts.architecture_routes=data["architecture_routes"]
	courts.stone=data["stone"]
	courts.walking=courts.get_node("ResolvedWalking")

static func restore_architecture(landscape: Node3D,data: Dictionary) -> void:
	landscape.measured_profiles=data["profiles"]
	landscape.profile_registry=MapAssetProfiles.new({"assets":[]})
	for row: Dictionary in data["architecture"]:
		var item: Node3D = Node3D.new()
		landscape.add_child(item)
		item.transform=row["transform"]
		var meshes: Array = row["meshes"]
		Snapshot.restore(item,meshes)
		landscape.measured_placements.append({"id":row["id"],"asset_id":row["asset_id"],"node":item,"terminal":row["terminal"]})
	var root: Node3D = Node3D.new()
	landscape.architecture_foundations=root
	landscape.add_child(root)
	var foundations: Array = data["foundations"]
	Snapshot.restore(root,foundations)
	for row: Dictionary in data["lights"]:
		var light: OmniLight3D = OmniLight3D.new()
		landscape.add_child(light)
		light.transform=row["transform"]
		light.light_color=row["colour"]
		light.light_energy=row["energy"]
		light.omni_range=row["range"]
		light.omni_attenuation=row["attenuation"]
		light.light_specular=row["specular"]
