extends MapJourneyLandscape
## Monumental threshold, intimate hearth and three memories over an infinite void.
const VoidTerrain = preload("res://presentation/map/chapters/act4/terrain.gd")
const VoidKit = preload("res://presentation/map/chapters/act4/kit.gd")
var measured_profiles: Dictionary = {}
var measured_placements: Array[Dictionary] = []
var profile_registry: MapAssetProfiles
var structures: Array[Node3D] = []
var library: VoidKit = VoidKit.new()
var background: CanvasLayer
var embers: Node3D
var void_material: ShaderMaterial
func _init() -> void:
	node_lit_colour=Color("d8bd8d")
	node_emission_colour=Color("b77b3e")
func build(data: Dictionary) -> void:
	terrain=VoidTerrain.new()
	add_child(terrain)
	terrain.build({"anchors":data["node_anchors"],"edges":data["edges"]},false,map_bounds,cache)
	failure=terrain.failure
	if not failure.is_empty(): return
	var positions: Dictionary = {}
	for id: String in data["node_anchors"]: positions[id]=v3(data["node_anchors"][id])
	for role: String in data["hero_placements"]:
		var placement: Dictionary = data["hero_placements"][role]
		var label: String = placement["asset_id"]
		var pose: Dictionary = placement["transform"]
		var item: Node3D = _asset(label,v3(pose["origin"]),role=="terminus")
		item.rotation.y=MapLayoutCanonical.float_value(pose["yaw_radians"])
		item.scale=v3(pose["scale"])
		measured_placements[-1]["role"]=role
	var echoes: Array[Node3D] = preload("res://presentation/map/chapters/act4/echoes.gd").build(self,positions)
	for item: Node3D in echoes:
		_record(str(item.name),item,false)
	var index: int = 0
	var routes: Dictionary = data["edges"]
	for id: String in MapLayoutCanonical.sorted_keys(routes):
		var edge: Dictionary = data["edges"][id]
		var line: Array = edge["centerline"]
		var a: Vector3 = v3(line[1])
		var b: Vector3 = v3(line[2])
		var side: Vector3 = (b-a).normalized().cross(Vector3.UP)
		var at: Vector3 = terrain.present(a.lerp(b,.42)+side*(2.08 if index%2==0 else -2.08))
		var marker: Node3D = _asset("memory-stele",at,false)
		marker.scale=Vector3.ONE*(.70+index*.06)
		marker.rotation.y=atan2(side.x,side.z)
		index+=1
	var end: Vector3 = positions["n4"]
	var start: Vector3 = positions["n0"]
	_glow(end+Vector3(0,2,-7),Color("ffa34a"),4,25)
	_glow(start+Vector3(0,7,-4),Color("e7a34f"),8,22)
	embers=preload("res://presentation/map/chapters/act4/embers.gd").new()
	add_child(embers)
	background=CanvasLayer.new()
	background.layer=-10
	add_child(background)
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader=preload("res://presentation/map/chapters/act4/void_background.gdshader")
	void_material=material
	rect.material=material
	background.add_child(rect)
	var resolved: PackedVector3Array = []
	for p: Vector3 in anchors: resolved.append(terrain.present(p))
	journey=Journey.new()
	add_child(journey)
	journey.build(terrain,resolved,anchors)
	for i: int in range(anchors.size()): _resolved_seats[Vector2(anchors[i].x,anchors[i].z)]=journey.bases[i].position
	journey.set_process(false)
	journey.walker.visible=false
func _asset(label: String,at: Vector3,terminal: bool) -> Node3D:
	var item: Node3D = library.instance(label)
	add_child(item)
	item.position=at
	_record(label,item,terminal)
	return item
func _record(label: String,item: Node3D,terminal: bool) -> void:
	if not measured_profiles.has(label):
		var path: String = "res://assets/map/act4/"+label+".glb" if VoidKit.SOURCES.has(label) else "res://presentation/map/chapters/act4/echoes.gd"
		var measured: Dictionary = preload("res://presentation/map/map_procedural_assets.gd").measure(label,item,path,3)
		if measured.is_empty():
			failure="Cannot measure void structure: "+label
			return
		profile_registry=measured["registry"]
		measured_profiles[label]=measured["profile"]
	measured_placements.append({"id":"void-structure-%d"%structures.size(),"asset_id":label,"node":item,"terminal":terminal})
	structures.append(item)
func _glow(at: Vector3,colour: Color,energy: float,distance: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.position=at
	light.light_color=colour
	light.light_energy=energy
	light.omni_range=distance
	add_child(light)
func realise(source: MapLayoutResult) -> Dictionary:
	return preload("res://presentation/map/chapters/common/measured_realisation.gd").finish(source,self,"mirrored-procession-surface-v2","mirrored-procession")
func capture_chapter() -> Dictionary:
	# The small static procession rebuilds; its compiled source remains cached.
	return {"kind":"mirrored-procession"}

func set_ambient_motion(enabled: bool) -> void:
	if void_material!=null: void_material.set_shader_parameter("motion",1.0 if enabled else 0.0)
	if embers!=null and embers.material!=null: embers.material.set_shader_parameter("motion",1.0 if enabled else 0.0)
