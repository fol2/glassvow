extends RefCounted
## Small reverse-chapter memories supported by the processional way, never a ground plane.
const M = preload("res://presentation/map/landscape/mesh_tools.gd")
static func build(parent: Node3D, anchors: Dictionary) -> Array[Node3D]:
	var roots: Array[Node3D] = []
	var obsidian: Node3D = Node3D.new()
	parent.add_child(obsidian)
	obsidian.position = anchors["n1"]+Vector3(-1.8,0,2.6)
	obsidian.name = "ObsidianMemory"
	var black: Material = M.material(Color("252532"),.42)
	M.box(obsidian,Vector3(0,.15,0),Vector3(2.2,.3,1.6),black,"RingFoot")
	var violet: StandardMaterial3D = M.material(Color("624971"),.4)
	violet.emission_enabled = true
	violet.emission = Color("302237")
	_ring(obsidian,Vector3(0,1.3,0),.85,1.08,black,.22,5.15)
	_ring(obsidian,Vector3(0,1.3,.13),.89,.93,violet,.3,4.8)
	roots.append(obsidian)
	var drowned: Node3D = Node3D.new()
	parent.add_child(drowned)
	drowned.position = anchors["n2"]+Vector3(0,0,2.7)
	drowned.name = "SunkenMemory"
	var stone: Material = M.material(Color("343e43"),.75)
	_cylinder(drowned,Vector3(0,.18,0),1.15,.36,stone)
	_cylinder(drowned,Vector3(0,.37,0),.90,.035,M.material(Color("193e45"),.12))
	for x: float in [-.6,.6]: M.box(drowned,Vector3(x,.82,-.55),Vector3(.2,1.2,.25),stone,"LibraryRemnant")
	var lintel: MeshInstance3D = M.box(drowned,Vector3(-.3,1.52,-.55),Vector3(.85,.18,.25),stone,"PointedLibraryArch")
	lintel.rotation.z = .5
	lintel = M.box(drowned,Vector3(.3,1.52,-.55),Vector3(.85,.18,.25),stone,"PointedLibraryArch")
	lintel.rotation.z = -.5
	roots.append(drowned)
	var ash: Node3D = Node3D.new()
	parent.add_child(ash)
	ash.position = anchors["n3"]+Vector3(0,0,-2.8)
	ash.name = "AshenMemory"
	var root_mat: Material = M.material(Color("655d59"))
	for sign_value: float in [-1,1]:
		_branch(ash,Vector3(0,.10,0),Vector3(sign_value*.9,.10,.35),.10,root_mat)
		_branch(ash,Vector3(sign_value*.6,.10,.23),Vector3(sign_value*1.1,.08,-.1),.06,root_mat)
		var lantern: Node3D = _lamp(ash,Vector3(sign_value*.75,0,-.4))
		lantern.name = "PairedLamp"
	roots.append(ash)
	return roots
static func _lamp(parent: Node3D, at: Vector3) -> Node3D:
	var root: Node3D = Node3D.new()
	parent.add_child(root)
	root.position = at
	var metal: Material = M.material(Color("3c3934"),.6)
	M.box(root,Vector3(0,.13,0),Vector3(.44,.26,.44),metal,"LampFoot")
	var glow: StandardMaterial3D = M.material(Color("be8b46"),.4)
	glow.emission_enabled = true
	glow.emission = Color("c18636")
	glow.emission_energy_multiplier = .6
	M.box(root,Vector3(0,.53,0),Vector3(.24,.55,.24),glow,"AmberLight")
	M.box(root,Vector3(0,.85,0),Vector3(.42,.13,.42),metal,"LampCap")
	return root
static func _branch(parent: Node3D,a: Vector3,b: Vector3,r: float,mat: Material) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = r*.45
	mesh.bottom_radius = r
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 7
	var item: MeshInstance3D = M.node(parent,mesh,mat,"PaleRoot")
	item.position = (a+b)*.5
	item.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
static func _cylinder(parent: Node3D,at: Vector3,r: float,h: float,mat: Material) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = h
	mesh.radial_segments = 40
	M.node(parent,mesh,mat,"Basin").position = at
static func _ring(parent: Node3D,at: Vector3,inner: float,outer: float,mat: Material,begin: float,end: float) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for i: int in range(40):
		var a: float = lerpf(begin,end,float(i)/40)
		var b: float = lerpf(begin,end,float(i+1)/40)
		var points: Array[Vector3] = []
		for z: float in [0,.2]:
			for p: Vector2 in [Vector2(cos(a),sin(a))*inner,Vector2(cos(b),sin(b))*inner,Vector2(cos(b),sin(b))*outer,Vector2(cos(a),sin(a))*outer]: points.append(Vector3(p.x,p.y,z))
		for ids: Array in [[0,1,2,3],[7,6,5,4],[0,4,5,1],[3,2,6,7],[0,3,7,4],[1,5,6,2]]:
			M.triangle(surface,points[ids[0]],points[ids[1]],points[ids[2]])
			M.triangle(surface,points[ids[0]],points[ids[2]],points[ids[3]])
	M.node(parent,M.finish(surface),mat,"BrokenObsidianHalo").position = at
