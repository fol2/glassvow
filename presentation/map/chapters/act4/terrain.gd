extends "res://presentation/map/landscape/terrain.gd"
## Only the supported processional way exists in the void; no enclosing ground.
const M = preload("res://presentation/map/landscape/mesh_tools.gd")
const Surface = preload("res://presentation/map/chapters/common/resolved_route_surface.gd")
const Union = preload("res://presentation/map/chapters/common/walking_surface_union.gd")
const FlightMesh = preload("res://presentation/map/chapters/common/flight_mesh.gd")
const Contacts = preload("res://presentation/map/chapters/common/walking_contacts.gd")
var walking: MeshInstance3D
var joined: Dictionary = {}
var contacts: Contacts = Contacts.new()
func build(sample: Dictionary,_grey: bool,extent: Rect2 = Rect2(-55,-42,110,87),_cache: Resource = null) -> void:
	bounds=extent
	anchors=sample["anchors"]
	source_edges=sample["edges"]
	var plans: Array[Dictionary] = []
	for edge: Dictionary in source_edges.values():
		var line: PackedVector3Array = []
		for p: Array in edge["centerline"]: line.append(M.v3(p))
		var plan: Dictionary = Surface.resolve(line,5.4,-1.5,8)
		if plan.get("ok")!=true:
			failure="Processional route cannot produce a supported surface"
			return
		plans.append(plan)
	for id: String in MapLayoutCanonical.sorted_keys(anchors):
		var raw: Array = anchors[id]
		var at: Vector3 = M.v3(raw)
		var length: float = 6
		var width: float = 8
		if id=="n0":
			at+=Vector3(0,0,-4.5)
			length=28
			width=15
		elif id=="n4":
			at+=Vector3(0,0,-5)
			length=14
			width=16
		plans.append(Surface.resolve(PackedVector3Array([at+Vector3(-length*.5,0,0),at+Vector3(length*.5,0,0)]),width,-1.5,8))
	joined=Union.resolve(plans)
	if joined.get("ok")!=true:
		failure="Processional way could not join its arrival platforms"
		return
	var paving: ShaderMaterial = ShaderMaterial.new()
	paving.shader=preload("res://presentation/map/chapters/act4/processional_stone.gdshader")
	preload("res://presentation/stage/mirrored_finish.gd").apply_world(paving)
	walking=M.node(self,FlightMesh.build(joined),paving,"ProcessionalWay")
	var tops: Array = joined["tops"]
	contacts.add(tops)
func present(p: Vector3,_upper: bool = false) -> Vector3:
	var y: float = contacts.height(p)
	return Vector3(p.x,y if is_finite(y) else p.y,p.z)
func height_at(x: float,z: float) -> float: return present(Vector3(x,0,z)).y
func surface_height(x: float,z: float) -> float: return height_at(x,z)
func is_dry(_p: Vector3) -> bool: return true
