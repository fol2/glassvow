extends MapJourneyLandscape
## The approved flooded city is assembled around the live compiler's graph.
const CityTerrain = preload("res://presentation/map/chapters/act2/terrain.gd")
const Library = preload("res://presentation/map/chapters/act2/library.gd")
const M = preload("res://presentation/map/landscape/mesh_tools.gd")
var source_nodes: Array = []
var measured_profiles: Dictionary = {}
var measured_placements: Array[Dictionary] = []
var profile_registry: MapAssetProfiles

func _init() -> void:
	node_lit_colour=Color("96dec7")
	node_emission_colour=Color("66d4aa")

func build(data: Dictionary) -> void:
	var started: int = Time.get_ticks_msec()
	terrain=CityTerrain.new()
	add_child(terrain)
	terrain.build({"anchors":data["node_anchors"],"edges":data["edges"],"nodes":source_nodes,"layout_digest":data["layout_digest"] if data.has("layout_digest") else ""},false,map_bounds,cache)
	if not terrain.failure.is_empty():
		failure=terrain.failure
		return
	var city: CityTerrain = terrain as CityTerrain
	timings_ms["terrain"]=Time.get_ticks_msec()-started
	started=Time.get_ticks_msec()
	if terrain.restored:
		var stored: Dictionary = cache.get("chapter_data")
		preload("res://presentation/map/chapters/act2/cache.gd").restore_architecture(self,stored)
	else:
		for site: Dictionary in city.causeways.ruin_plan.sites:
			var item: Node3D
			var ordinal: int = site["ordinal"]
			var kind: String = site["kind"]
			if kind=="library":
				var library: Library = Library.new()
				library.connected_forecourt=true
				var at: Vector3 = site["centre"]
				library.build(1.18-at.y)
				item=library
			elif kind=="ward":
				var ward: Node3D = preload("res://presentation/map/chapters/act2/ward.gd").new()
				ward.build_ward(6.6 if ordinal==1 else 5.4,ordinal%2==0)
				item=ward
			else:
				var quarter: Node3D = preload("res://presentation/map/chapters/act2/sunken_quarter.gd").new()
				quarter.build(ordinal-4)
				item=quarter
			add_child(item)
			item.position=site["centre"]
			item.rotation.y=site["yaw"]
			_record("ruin-%d"%ordinal,"city-"+kind+str(ordinal),item,ordinal==0)
		var scenery: Node3D = preload("res://presentation/map/chapters/act2/scenery.gd").new()
		add_child(scenery)
		scenery.build(city.causeways)
		var index: int = 0
		for child: Node in scenery.get_children():
			if not child is MeshInstance3D: continue
			var mesh_item: MeshInstance3D = child
			var variant: String = ""
			var meshes: Dictionary = scenery.assets.meshes
			for id: String in meshes:
				if meshes[id]==mesh_item.mesh: variant=id
			if variant.is_empty():
				failure="Unidentified city scenery mesh"
				return
			_record("scenery-%d"%index,"city-"+variant,mesh_item,false,"res://presentation/map/chapters/act2/scenery_assets.gd")
			index+=1
	timings_ms["architecture"]=Time.get_ticks_msec()-started
	var water: MeshInstance3D = preload("res://presentation/map/chapters/water/surface.gd").new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size=map_bounds.size+Vector2(180,180)
	water.configure(plane,preload("res://presentation/map/chapters/water/presets.gd").drowned_city())
	water.name="Stream"
	terrain.add_child(water)
	water.position=Vector3(map_bounds.get_center().x,1.18,map_bounds.get_center().y)
	M.box(terrain,Vector3(map_bounds.get_center().x,-1,map_bounds.get_center().y),Vector3(plane.size.x,1,plane.size.y),M.material(Color("112b32")),"FloodBed")
	var resolved: PackedVector3Array = []
	for p: Vector3 in anchors: resolved.append(terrain.present(p))
	journey=Journey.new()
	add_child(journey)
	journey.build(terrain,resolved,anchors)
	for i: int in range(anchors.size()): _resolved_seats[Vector2(anchors[i].x,anchors[i].z)]=journey.bases[i].position
	journey.set_process(false)
	journey.walker.visible=false

func _record(id: String, asset_id: String, item: Node3D, terminal: bool, source: String = "") -> void:
	if not measured_profiles.has(asset_id):
		if source.is_empty(): source=item.get_script().resource_path
		var measured: Dictionary = preload("res://presentation/map/map_procedural_assets.gd").measure(asset_id,item,source,1)
		if measured.is_empty():
			failure="Cannot measure city asset: "+asset_id
			return
		profile_registry=measured["registry"]
		measured_profiles[asset_id]=measured["profile"]
	measured_placements.append({"id":id,"asset_id":asset_id,"node":item,"terminal":terminal})

func realise(source: MapLayoutResult) -> Dictionary:
	return preload("res://presentation/map/chapters/act2/realisation.gd").finish(source,self)

func capture_chapter() -> Dictionary:
	return preload("res://presentation/map/chapters/act2/cache.gd").capture(self)
