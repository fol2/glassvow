extends Node3D
## Complete sample routes become fitted masonry. Upper and lower decks stay separate.
const M = preload("res://presentation/map/landscape/mesh_tools.gd")
const Paths = preload("res://presentation/map/landscape/road_paths.gd")
const Surfaces = preload("res://presentation/map/landscape/bridge_surfaces.gd")
var levels: RefCounted
var material_factory: Callable
var lines: Array[PackedVector3Array] = []
var fields: Array[Surfaces] = []
var anchors: Dictionary = {}
var deck_meshes: Array[ArrayMesh] = []
var underside_meshes: Array[ArrayMesh] = []
var decoration_meshes: Array[ArrayMesh] = []
var sampled_routes: Dictionary = {}
var failure: String = ""
var ruin_plan: RefCounted
var ruin_links: Dictionary = {}
var height_profile: RefCounted = preload("res://presentation/map/chapters/common/profile.gd").new()
var bridge_style: Dictionary = {}
var stone: ShaderMaterial = ShaderMaterial.new()
var deck: ShaderMaterial = ShaderMaterial.new()
var build_timings_ms: Dictionary = {}
var _stage_started: int = 0
## Geometry jobs retain meshes; only the main thread publishes visible instances.
var defer_instances: bool = false
var instance_rows: Array[Dictionary] = []
var cancel_token: RefCounted

func _cancelled() -> bool:
	if cancel_token==null or not cancel_token.cancelled(): return false
	failure="Geometry construction cancelled"
	return true

func publish_instances() -> void:
	for row: Dictionary in instance_rows:
		var mesh: Mesh = row["mesh"]
		var material: Material = row["material"]
		M.node(self,mesh,material,str(row["name"]))
	instance_rows.clear()

func _instance(mesh: Mesh,material: Material,label: String) -> void:
	if defer_instances:
		instance_rows.append({"mesh":mesh,"material":material,"name":label})
	else:
		M.node(self,mesh,material,label)

func _mark(stage: String) -> void:
	var now: int = Time.get_ticks_msec()
	build_timings_ms[stage] = now-_stage_started
	_stage_started = now
	print("FITTED_ROUTE_TIMING ",stage,"=",build_timings_ms[stage])

func build(sample: Dictionary) -> void:
	_stage_started = Time.get_ticks_msec()
	build_timings_ms.clear()
	if levels==null or ruin_plan==null or bridge_style.is_empty():
		failure = "Fitted routes require caller-owned grading, destination plan and bridge style"
		return
	height_profile.load_candidate(sample)
	if not height_profile.failure.is_empty():
		failure = height_profile.failure
		return
	var materials: Dictionary = material_factory.call(bridge_style) if material_factory.is_valid() else preload("res://presentation/map/chapters/stone_bridge/presets.gd").materials(bridge_style)
	stone = materials["body"]
	deck = materials["deck"]
	for edge: Dictionary in sample["edges"].values():
		var line: PackedVector3Array = []
		for value: Array in edge["centerline"]:
			line.append(M.v3(value))
		lines.append(line)
	var spatial_lines: Array[PackedVector3Array] = []
	var spatial_scale: float = height_profile.planar_scale
	for line: PackedVector3Array in lines:
		var spatial: PackedVector3Array = []
		for point: Vector3 in line:
			spatial.append(Vector3(point.x*spatial_scale,point.y,point.z*spatial_scale))
		spatial_lines.append(spatial)
	levels.setup(spatial_lines)
	for key: String in sample["anchors"]:
		var raw: Array = sample["anchors"][key]
		var p: Vector3 = M.v3(raw)
		p.x *= height_profile.planar_scale
		p.z *= height_profile.planar_scale
		p.y = levels.height(p.x,p.z)+.022
		anchors[key] = p
	var lower: Array[Dictionary] = []
	var upper: Array[Dictionary] = []
	var index: int = 0
	for key: String in sample["edges"]:
		var source_edge: Dictionary = sample["edges"][key]
		var line: PackedVector3Array = lines[index]
		index += 1
		var raised: bool = false
		for p: Vector3 in line:
			raised = raised or p.y>.3
		var sampling: float = bridge_style.get("sample_spacing",.2)
		var points: PackedVector3Array = Paths.sample(line,sampling)
		var lengths: PackedFloat32Array = [0]
		for i: int in range(points.size()):
			if i>0:
				lengths.append(lengths[-1]+Vector2(points[i].x-points[i-1].x,points[i].z-points[i-1].z).length())
			points[i].y = 4.8 if raised else levels.height(points[i].x,points[i].z)
		if raised:
			for i: int in range(points.size()):
				var landing_run: float = bridge_style.get("approach_landing",0.0)
				var run: float = maxf(0,minf(lengths[i],lengths[-1]-lengths[i])-landing_run)
				var rise: float = .44*(run-.15*(1.0-exp(-run/.15)))
				if rise>.7:
					var ease: float = clampf((rise-.7)/.5,0,1)
					rise = .7+.25*ease*(2-ease)
				points[i].y += rise
		points = height_profile.apply(key,points)
		if not height_profile.failure.is_empty():
			failure = height_profile.failure
			return
		if not height_profile.routes.is_empty():
			for station: int in range(lengths.size()):
				lengths[station] *= height_profile.planar_scale
		anchors[source_edge["from"]] = points[0]+Vector3.UP*.022
		anchors[source_edge["to"]] = points[-1]+Vector3.UP*.022
		sampled_routes[key] = points
		for i: int in range(points.size()-1):
			var a: Vector3 = points[i]
			var b: Vector3 = points[i+1]
			var wa: float = .92+.37*(1-smoothstep(.4,1.5,minf(lengths[i],lengths[-1]-lengths[i])))
			var wb: float = .92+.37*(1-smoothstep(.4,1.5,minf(lengths[i+1],lengths[-1]-lengths[i+1])))
			var span: Dictionary = {"edge":key,"from":source_edge["from"],"to":source_edge["to"],"a":a,"b":b,"wa":1.0,"wb":1.0,"half_a":wa,"half_b":wb,"s":lengths[i],"bottom_a":_soffit(a.y,lengths[i],lengths[-1],raised),"bottom_b":_soffit(b.y,lengths[i+1],lengths[-1],raised)}
			if raised:
				upper.append(span)
			else:
				lower.append(span)
	_mark("route_profiles")
	if _cancelled(): return
	ruin_plan.build(sample,anchors,sampled_routes)
	if not ruin_plan.failure.is_empty():
		failure = ruin_plan.failure
		return
	for site: Dictionary in ruin_plan.sites:
		var start: Vector3 = site["anchor"]-Vector3.UP*.022
		var finish: Vector3 = site["door"]-Vector3.UP*.022
		var total: float = Vector2(start.x-finish.x,start.z-finish.z).length()
		var count: int = ceili(total/.25)
		var link: PackedVector3Array = []
		for i: int in range(count+1):
			var station: float = total*i/count
			var point: Vector3 = start.lerp(finish,float(i)/count)
			point.y = lerpf(start.y,finish.y,clampf((station-1.8)/maxf(.1,total-3.6),0,1))
			link.append(point)
		var key: String = "ruin_"+str(site["ordinal"])
		ruin_links[key] = link
		for i: int in range(count):
			var sa: float = total*i/count
			var sb: float = total*(i+1)/count
			lower.append({"edge":key,"from":site["node"],"to":key,"a":link[i],"b":link[i+1],"wa":1.0,"wb":1.0,"half_a":1.1,"half_b":1.1,"s":sa,"bottom_a":_soffit(link[i].y,sa,total,false),"bottom_b":_soffit(link[i+1].y,sb,total,false)})
	lines = spatial_lines
	var stair_exclusions: Array = anchors.values()
	for site: Dictionary in ruin_plan.sites:
		stair_exclusions.append(site["door"])
	for cut: Dictionary in levels.cuts:
		var at: Vector2 = cut["at"]
		stair_exclusions.append(Vector3(at.x,0,at.y))
	_mark("destination_links")
	if _cancelled(): return
	for spans: Array[Dictionary] in [lower,upper]:
		if spans.is_empty():
			continue
		var field: Surfaces = Surfaces.new()
		if not height_profile.routes.is_empty():
			field = preload("res://presentation/map/chapters/common/smooth_surfaces.gd").new()
		if spans == upper and not height_profile.routes.is_empty():
			var landing: Surfaces = preload("res://presentation/map/chapters/common/landing_surfaces.gd").new()
			landing.lower = fields[0]
			landing.pads = levels.abutments
			field = landing
		var profile: Callable = Callable(levels,"height") if spans == lower and height_profile.routes.is_empty() else Callable()
		field.setup(spans,func(_x: float,_z: float) -> float: return -2.0,profile)
		field.cancel_token=cancel_token
		_mark("field_%d_setup" % fields.size())
		if _cancelled(): return
		if not height_profile.routes.is_empty():
			var grading: RefCounted = preload("res://presentation/map/chapters/stone_bridge/flight_grade.gd").new()
			grading.prepare(field,{"openings":stair_exclusions})
			field.set("stair_profile",grading)
		_mark("field_%d_grading" % fields.size())
		if _cancelled(): return
		fields.append(field)
		var top: SurfaceTool = SurfaceTool.new()
		var sides: SurfaceTool = SurfaceTool.new()
		top.begin(Mesh.PRIMITIVE_TRIANGLES)
		sides.begin(Mesh.PRIMITIVE_TRIANGLES)
		field.append(top,sides)
		_mark("field_%d_meshing" % (fields.size()-1))
		if _cancelled(): return
		var deck_mesh: ArrayMesh = M.finish(top)
		var underside_mesh: ArrayMesh = M.finish(sides)
		deck_meshes.append(deck_mesh)
		underside_meshes.append(underside_mesh)
		_instance(deck_mesh,deck,"FittedCausewayDeck")
		_instance(underside_mesh,stone,"ArchedCausewayStructure")
		_mark("field_%d_normals" % (fields.size()-1))
		if _cancelled(): return

	var trim: Material = materials["trim"]
	var edge_style: Dictionary = bridge_style.duplicate()
	edge_style["cancel_token"]=cancel_token
	edge_style["openings"] = []
	for site: Dictionary in ruin_plan.sites:
		edge_style["openings"].append(site["door"])
	for i: int in range(fields.size()):
		_build_edges(i,trim,edge_style)
		_mark("field_%d_parapets" % i)
		if _cancelled(): return
	for i: int in range(fields.size()):
		var steps: ArrayMesh = preload("res://presentation/map/chapters/stone_bridge/stairs.gd").new().build(null if defer_instances else self,fields[i],trim,{"openings":stair_exclusions,"tread_width":bridge_style["tread_width"]})
		if steps!=null:
			if defer_instances: _instance(steps,trim,"StoneBridgeStairTreads")
			# Keep indexed treads and the unindexed deck in separate surfaces.
			# A mixed append would leave the deck outside the index buffer.
			var combined: ArrayMesh = ArrayMesh.new()
			combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,deck_meshes[i].surface_get_arrays(0))
			combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,steps.surface_get_arrays(0))
			deck_meshes[i] = combined
	_mark("stairs")
	if _cancelled(): return
	_build_piers(trim,edge_style)
	_mark("piers")
	if _cancelled(): return
	print("FITTED_ROUTE_ASSEMBLY nodes=",anchors.size()," edges=",sampled_routes.size()," layers=",fields.size())

func _soffit(height: float,s: float,total: float,raised: bool) -> float:
	return preload("res://presentation/map/chapters/stone_bridge/profile.gd").soffit(height,s,total,raised,bridge_style)

func _build_edges(index: int,trim: Material,settings: Dictionary) -> void:
	var meshes: Array[ArrayMesh] = preload("res://presentation/map/chapters/stone_bridge/edges.gd").new().build(null if defer_instances else self,deck_meshes[index],fields[index],fields,stone,trim,settings)
	decoration_meshes.append_array(meshes)
	if defer_instances:
		for i: int in range(meshes.size()): _instance(meshes[i],stone if i==0 else trim,"BridgeEdgeMasonry")

func _build_piers(trim: Material,settings: Dictionary) -> void:
	var meshes: Array[ArrayMesh] = preload("res://presentation/map/chapters/stone_bridge/piers.gd").build(null if defer_instances else self,fields,stone,trim,settings)
	decoration_meshes.append_array(meshes)
	if defer_instances:
		for i: int in range(meshes.size()): _instance(meshes[i],stone if i==0 else trim,"BridgePierButtresses")
