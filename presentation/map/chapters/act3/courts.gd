extends Node3D
## Four generated court levels, supported by relief and exact shared stair faces.
const M = preload("res://presentation/map/landscape/mesh_tools.gd")
const Envelope = preload("res://presentation/map/chapters/common/precinct_envelope.gd")
const CourtStairs = preload("res://presentation/map/chapters/common/court_stair_assembly.gd")
const Kit = preload("res://presentation/map/chapters/act3/kit.gd")
var world: Node3D
var stone: Material
var failure: String = ""
var rows: Array = []
var divisions: Array[float] = []
var envelopes: Array[Dictionary] = []
var stair_groups: Array[Dictionary] = []
var architecture_routes: Dictionary = {}
var joined: Dictionary = {}
var court: Dictionary = {}
var obstacles: Array[Node3D] = []
var walking: MeshInstance3D
var landscape_hollows: bool = false
func build(sample: Dictionary,quality: Dictionary,boss_id: String) -> void:
	world=self
	var spatial: Dictionary = quality["spatial_profile"]
	rows = spatial["rows"]
	var bounds: Array = spatial["bounds_xz_m"]
	var west: float = MapLayoutCanonical.float_value(bounds[0])
	var east: float = MapLayoutCanonical.float_value(bounds[2])
	var near_z: float = MapLayoutCanonical.float_value(bounds[1])
	var far_z: float = MapLayoutCanonical.float_value(bounds[3])
	divisions = []
	for index: int in range(1,rows.size()):
		if rows[index].get("region") == rows[index-1].get("region"):
			continue
		divisions.append((MapLayoutCanonical.float_value(rows[index-1]["station_m"])+MapLayoutCanonical.float_value(rows[index]["station_m"]))*.5)
	stone = Kit.stone(ObsidianFinish.STONE,ObsidianFinish.SLAB_METRES,ObsidianFinish.JOINT_COVERAGE,ObsidianFinish.JOINT_STRENGTH)
	ObsidianFinish.apply_world(stone as ShaderMaterial)
	var paving: ShaderMaterial = stone as ShaderMaterial
	# All graph routes remain visible: no discarded edges to rescue composition.
	var edges: Dictionary = sample["edges"]
	var region_stations: Array[float] = [west,divisions[0],divisions[1],divisions[2],east]
	envelopes = Envelope.regions(edges,region_stations)
	var terminal: Vector3 = _point(sample["anchors"][boss_id])
	envelopes[-1]["near"] = minf(MapLayoutCanonical.float_value(envelopes[-1]["near"]),terminal.z-18)
	envelopes[-1]["far"] = maxf(MapLayoutCanonical.float_value(envelopes[-1]["far"]),terminal.z+18)
	var route_plans: Array[Dictionary] = []
	var plans_by_id: Dictionary = {}
	for id: String in edges:
		var edge: Dictionary = edges[id]
		var line: PackedVector3Array = []
		for point: Variant in edge["centerline"]:
			line.append(_point(point))
		var plan: Dictionary = preload("res://presentation/map/chapters/common/resolved_route_surface.gd").resolve(line,2.5,-1,.65)
		if plan.get("ok") != true:
			failure="Unresolved route "+id+": "+str(plan)
			return
		route_plans.append(plan)
		plans_by_id[id] = plan
	architecture_routes = edges.duplicate(true)
	stair_groups = []
	if spatial.get("stair_version", "") == "transverse-court-v1":
		var assembly: Dictionary = CourtStairs.resolve(route_plans,divisions)
		if assembly.get("ok") != true:
			failure=str(assembly)
			return
		route_plans = assembly["plans"]
		stair_groups = assembly["groups"]
		var reserves: Dictionary = assembly["reserves"]
		architecture_routes.merge(reserves)
	var union_start: int = Time.get_ticks_usec()
	joined = preload("res://presentation/map/chapters/common/walking_surface_union.gd").resolve(route_plans)
	if joined.get("ok") != true:
		failure=str(joined)
		return
	print("WALKING_UNION removed_m2=",joined["removed_overlap_m2"]," build_ms=",(Time.get_ticks_usec()-union_start)/1000.0)
	walking = MeshInstance3D.new()
	walking.name = "ResolvedWalking"
	walking.mesh = preload("res://presentation/map/chapters/common/flight_mesh.gd").build(joined)
	walking.material_override = paving
	world.add_child(walking)
	var landscape_openings: Array[Rect2] = []
	if landscape_hollows:
		landscape_openings = preload("res://presentation/map/chapters/common/court_landscape_openings.gd").select(envelopes,edges)
	print("LANDSCAPE_OPENINGS count=",landscape_openings.size())
	var patches: Array[Dictionary] = []
	var court_heights: Array[float] = []
	for region: Dictionary in envelopes:
		var x0: float = region["west"]
		var x1: float = region["east"]
		var z0: float = region["near"]
		var z1: float = region["far"]
		var height: float = _court_height((x0+x1)*.5,rows)
		court_heights.append(height)
		patches.append({"height":height,"outline":PackedVector2Array([
			Vector2(x0,z0),Vector2(x1,z0),Vector2(x1,z1),Vector2(x0,z1)])})
		for piece: Rect2 in preload("res://presentation/map/chapters/common/court_landscape_openings.gd").subtract(Rect2(x0,z0,x1-x0,z1-z0),landscape_openings):
			_box(Vector3(piece.get_center().x,-1.05,piece.get_center().y),Vector3(piece.size.x,2,piece.size.y),stone)
	var plinth_material: StandardMaterial3D = M.material(Color("373441"),.7)
	var terrain_reserves: Array[Rect2] = []
	var terrain_bounds: Rect2 = Rect2(Vector2(west,near_z),Vector2(east-west,far_z-near_z))
	for region: Dictionary in envelopes:
		var reserve: Rect2 = Rect2(Vector2(MapLayoutCanonical.float_value(region["west"]),MapLayoutCanonical.float_value(region["near"])),Vector2(MapLayoutCanonical.float_value(region["east"])-MapLayoutCanonical.float_value(region["west"]),MapLayoutCanonical.float_value(region["far"])-MapLayoutCanonical.float_value(region["near"])))
		terrain_reserves.append(reserve.grow(2.0))
		terrain_bounds = terrain_bounds.merge(reserve)
	var terrain_profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://presentation/map/chapters/act3/terrain-profile.json"))
	terrain_profile = preload("res://presentation/map/chapters/common/landscape_relief.gd").resolve_profile(terrain_profile,terrain_reserves)
	var terrain_contact_reserves: Array[Rect2] = []
	for reserve: Rect2 in terrain_reserves:
		terrain_contact_reserves.append_array(preload("res://presentation/map/chapters/common/court_landscape_openings.gd").subtract(reserve,landscape_openings))
	var terrain_mesh: MeshInstance3D = preload("res://presentation/map/chapters/common/landscape_relief.gd").build(terrain_bounds.grow(32),terrain_profile,terrain_contact_reserves,M.material(Color("24232e"),.95))
	world.add_child(terrain_mesh)
	plinth_material.vertex_color_use_as_albedo = true
	preload("res://presentation/map/chapters/common/precinct_plinth.gd").build(world,envelopes,court_heights,plinth_material)
	var court_masks: Array[Dictionary] = route_plans.duplicate()
	for opening: Rect2 in landscape_openings:
		court_masks.append(preload("res://presentation/map/chapters/common/court_landscape_openings.gd").mask(opening,-.1))
	court = preload("res://presentation/map/chapters/common/court_surface.gd").resolve(patches,court_masks)
	if court.get("ok") != true:
		failure=str(court)
		return
	var court_mesh: MeshInstance3D = MeshInstance3D.new()
	court_mesh.name = "CourtSurface"
	court_mesh.mesh = preload("res://presentation/map/chapters/common/flight_mesh.gd").build(court)
	court_mesh.material_override = stone
	world.add_child(court_mesh)
	print("COURT_SURFACE triangles=",court["tops"].size())
	var trim: StandardMaterial3D = M.material(Color("323544"),.38)
	trim.emission_enabled=true
	trim.emission=Color(.07,.002,.04)
	for x: float in divisions:
		var local_bounds: Vector2 = Envelope.at_x(envelopes,x)
		var threshold: Dictionary = CourtStairs.threshold(stair_groups,x,local_bounds.x,local_bounds.y)
		if threshold.get("ok")!=true:
			failure=str(threshold)
			return
		obstacles.append(CourtStairs.build_retaining(self,threshold,stone,trim))
	for pair: Array in _passage_pairs(edges):
		var upper: Dictionary = edges[pair[0]]
		var lower: Dictionary = edges[pair[1]]
		obstacles.append(preload("res://presentation/map/chapters/common/passage_masonry.gd").build(self,upper,lower,stone,true))
func _box(position: Vector3, size: Vector3, material: Material) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	world.add_child(instance)
func _point(value: Variant) -> Vector3:
	var coordinates: Array = value
	return M.v3(coordinates)

func _court_height(x: float, rows: Array) -> float:
	var value: float = MapLayoutCanonical.float_value(rows[0]["height_m"])
	for i: int in range(1,rows.size()):
		var boundary: float = (MapLayoutCanonical.float_value(rows[i-1]["station_m"])+MapLayoutCanonical.float_value(rows[i]["station_m"]))*.5
		if x < boundary:
			break
		value = MapLayoutCanonical.float_value(rows[i]["height_m"])
	return value

func _passage_pairs(edges: Dictionary) -> Array[Array]:
	var conflicts: Array[Dictionary] = MapGradeSeparation._xz_conflicts(edges,.001)
	var pairs: Array[Array] = []
	for conflict: Dictionary in conflicts:
		var ids: Array = conflict["edge_ids"]
		var peaks: Array[float] = []
		for id: String in ids:
			var peak: float = -INF
			for point: Array in edges[id]["centerline"]:
				peak = maxf(peak,MapLayoutCanonical.float_value(point[1]))
			peaks.append(peak)
		var ordered: Array[String] = [str(ids[0]),str(ids[1])]
		if peaks[1] > peaks[0]:
			ordered.reverse()
		pairs.append(ordered)
	return pairs
