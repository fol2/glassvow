extends MapJourneyLandscape
## Approved intact courts, actual generated stairs and shared campaign navigation.
const CourtTerrain = preload("res://presentation/map/chapters/act3/terrain.gd")
const Architecture = preload("res://presentation/map/chapters/act3/architecture.gd")
var source_nodes: Array = []
var source_quality: Dictionary = {}
var measured_profiles: Dictionary = {}
var measured_placements: Array[Dictionary] = []
var profile_registry: MapAssetProfiles
var architecture_foundations: Node3D
var halo: Node3D

func _init() -> void:
	node_lit_colour=Color("ce83b7")
	node_emission_colour=Color("a43b87")

func build(data: Dictionary) -> void:
	var started: int = Time.get_ticks_msec()
	var boss_id: String = ""
	for row: Dictionary in source_nodes:
		if row["type"]=="boss": boss_id=row["id"]
	if boss_id.is_empty():
		failure="Court landscape needs its generated boss node"
		return
	var courts: CourtTerrain = CourtTerrain.new()
	terrain=courts
	courts.quality=source_quality
	courts.boss_id=boss_id
	add_child(courts)
	courts.build({"anchors":data["node_anchors"],"edges":data["edges"]},false,map_bounds,cache)
	if not courts.failure.is_empty():
		failure=courts.failure
		return
	timings_ms["courts"]=Time.get_ticks_msec()-started
	started=Time.get_ticks_msec()
	var boss: Vector3 = v3(data["node_anchors"][boss_id])
	if terrain.restored:
		var stored: Dictionary = cache.get("chapter_data")
		preload("res://presentation/map/chapters/act3/cache.gd").restore_architecture(self,stored)
	else:
		var architecture: Architecture = Architecture.new()
		add_child(architecture)
		architecture.build(courts.courts,boss)
		if not architecture.failure.is_empty():
			failure=architecture.failure
			return
		var index: int = 0
		for item: Node3D in architecture.buildings:
			var asset_name: String = item.get_meta("asset_name")
			if not measured_profiles.has(asset_name):
				var measured: Dictionary = preload("res://presentation/map/map_procedural_assets.gd").measure(asset_name,item,"res://assets/map/act3/"+asset_name+".glb",2)
				if measured.is_empty():
					failure="Cannot measure court model: "+asset_name
					return
				profile_registry=measured["registry"]
				measured_profiles[asset_name]=measured["profile"]
			measured_placements.append({"id":"court-building-%d"%index,"asset_id":asset_name,"node":item,"terminal":asset_name=="obsidian-great-hall"})
			index+=1
		architecture_foundations=Node3D.new()
		add_child(architecture_foundations)
		for child: Node in architecture.get_children():
			if child is MeshInstance3D: child.reparent(architecture_foundations)
	timings_ms["architecture"]=Time.get_ticks_msec()-started
	var material: ShaderMaterial = courts.courts.stone
	material.set_shader_parameter("inlay_centre",boss)
	material.set_shader_parameter("inlay_radius",8.5)
	material.set_shader_parameter("inlay_colour",Color("62516d"))
	halo=preload("res://presentation/map/chapters/act3/sovereign_halo.gd").new()
	halo.position=boss+Vector3(0,7.2,0)
	halo.rotation_degrees=Vector3(48,0,18)
	add_child(halo)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees=Vector3(-22,145,0)
	rim.light_color=Color("9c8bc5")
	rim.light_energy=.4
	rim.light_specular=.2
	rim.shadow_enabled=false
	add_child(rim)
	var resolved: PackedVector3Array = []
	for p: Vector3 in anchors: resolved.append(terrain.present(p))
	journey=Journey.new()
	add_child(journey)
	journey.build(terrain,resolved,anchors)
	for i: int in range(anchors.size()): _resolved_seats[Vector2(anchors[i].x,anchors[i].z)]=journey.bases[i].position
	journey.set_process(false)
	journey.walker.visible=false

func realise(source: MapLayoutResult) -> Dictionary:
	return preload("res://presentation/map/chapters/act3/realisation.gd").finish(source,self)

func capture_chapter() -> Dictionary:
	return preload("res://presentation/map/chapters/act3/cache.gd").capture(self)

func set_ambient_motion(enabled: bool) -> void:
	if halo!=null: halo.set_process(enabled)
