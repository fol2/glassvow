extends RefCounted
## Reversible city derivations retain actual geometry and route-field ownership.
const Snapshot = preload("res://presentation/map/chapters/common/static_mesh_snapshot.gd")
const Smooth = preload("res://presentation/map/chapters/common/smooth_surfaces.gd")
const Landing = preload("res://presentation/map/chapters/common/landing_surfaces.gd")
const Flight = preload("res://presentation/map/chapters/stone_bridge/flight_grade.gd")

static func capture(city: Node3D) -> Dictionary:
	var roads: Node3D = city.terrain.causeways
	var fields: Array[Dictionary] = []
	for field: RefCounted in roads.fields:
		fields.append({"spans":field.spans,"flights":field.stair_profile.cells,"flight_count":field.stair_profile.flight_count})
	var architecture: Array[Dictionary] = []
	for placement: Dictionary in city.measured_placements:
		var item: Node3D = placement["node"]
		var row: Dictionary = placement.duplicate()
		row.erase("node")
		row["transform"]=city.global_transform.affine_inverse()*item.global_transform
		row["meshes"]=Snapshot.capture(item)
		architecture.append(row)
	return {"kind":"drowned-city","fields":fields,"road_meshes":Snapshot.capture(roads),"lines":roads.lines,
		"anchors":roads.anchors,"sampled_routes":roads.sampled_routes,"ruin_links":roads.ruin_links,"sites":roads.ruin_plan.sites,
		"decks":roads.deck_meshes,"undersides":roads.underside_meshes,"decoration":roads.decoration_meshes,
		"architecture":architecture,"profiles":city.measured_profiles}

static func restore_roads(roads: Node3D,data: Dictionary) -> void:
	roads.lines.assign(data["lines"])
	roads.levels.setup(roads.lines)
	roads.anchors=data["anchors"]
	roads.sampled_routes=data["sampled_routes"]
	roads.ruin_links=data["ruin_links"]
	roads.ruin_plan.sites.assign(data["sites"])
	roads.deck_meshes.assign(data["decks"])
	roads.underside_meshes.assign(data["undersides"])
	roads.decoration_meshes.assign(data["decoration"])
	for row: Dictionary in data["fields"]:
		var field: Smooth = Smooth.new() if roads.fields.is_empty() else Landing.new()
		if field is Landing: field.lower=roads.fields[0]
		var spans: Array[Dictionary] = []
		var saved_spans: Array = row["spans"]
		spans.assign(saved_spans)
		field.query_cell_size=.5
		field.setup(spans,func(_x: float,_z: float) -> float: return -2.0)
		var grade: Flight = Flight.new()
		grade.cells=row["flights"]
		grade.flight_count=row["flight_count"]
		field.stair_profile=grade
		roads.fields.append(field)
	var meshes: Array = data["road_meshes"]
	Snapshot.restore(roads,meshes)

static func restore_architecture(city: Node3D,data: Dictionary) -> void:
	city.measured_profiles=data["profiles"]
	city.profile_registry=MapAssetProfiles.new({"assets":[]})
	for row: Dictionary in data["architecture"]:
		var item: Node3D = Node3D.new()
		city.add_child(item)
		item.transform=row["transform"]
		var meshes: Array = row["meshes"]
		Snapshot.restore(item,meshes)
		city.measured_placements.append({"id":row["id"],"asset_id":row["asset_id"],"node":item,"terminal":row["terminal"]})
