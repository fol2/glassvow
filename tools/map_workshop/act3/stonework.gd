extends RefCounted
## Angular obsidian architecture, with complete openings and restrained lancet glass.
const M = preload("res://tools/map_workshop/mesh_tools.gd")
const Palette = preload("res://tools/map_workshop/act3/materials.gd")
var stone: Material = Palette.obsidian()
var trim: Material = Palette.obsidian(Color("46354f"),.04)
var glass: Material = Palette.glass()

func pier(parent: Node3D,at: Vector3,width: float,height: float) -> void:
	M.box(parent,at+Vector3.UP*.18,Vector3(width*1.45,.36,width*1.45),stone,"PierFoot")
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.radial_segments = 4
	mesh.rings = 1
	mesh.bottom_radius = width*.72
	mesh.top_radius = width*.26
	mesh.height = height
	var item: MeshInstance3D = M.node(parent,mesh,stone,"TaperedObsidianPier")
	item.position = at+Vector3.UP*(height*.5)
	item.rotation.y = PI*.25

func arch(parent: Node3D,at: Vector3,width: float,height: float,depth: float,glazed: bool = false) -> void:
	var root: Node3D = Node3D.new()
	parent.add_child(root)
	root.position = at
	var half: float = width*.5
	var spring: float = height*.6
	for side: int in [-1,1]:
		M.box(root,Vector3(side*(half+.18),spring*.5,0),Vector3(.36,spring,depth),trim,"LancetJamb")
		var last: Vector3 = Vector3(side*half,spring,0)
		for i: int in range(1,9):
			var t: float = i/8.0
			var next: Vector3 = Vector3(side*half*(1-t),spring+(height-spring)*sin(t*PI*.35)/sin(PI*.35),0)
			_beam(root,last,next,.32,depth,trim)
			last = next
	if glazed:
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var outline: PackedVector3Array = [Vector3(-half,0,0),Vector3(half,0,0),Vector3(half,spring,0)]
		for i: int in range(1,9):
			var t: float = i/8.0
			outline.append(Vector3(half*(1-t),spring+(height-spring)*sin(t*PI*.35)/sin(PI*.35),0))
		for i: int in range(1,9):
			var t: float = 1-i/8.0
			outline.append(Vector3(-half*(1-t),spring+(height-spring)*sin(t*PI*.35)/sin(PI*.35),0))
		for i: int in range(outline.size()):
			M.triangle(surface,Vector3(0,spring*.5,0),outline[(i+1)%outline.size()],outline[i])
		M.node(root,M.finish(surface),glass,"MagentaLancet")
		M.box(root,Vector3(0,height*.43,.07),Vector3(.08,height*.86,.12),stone,"WindowMullion")
		for side: int in [-1,1]:
			var foot: Vector3 = Vector3(side*half*.48,.15,.09)
			var shoulder: Vector3 = Vector3(side*half*.48,spring*.72,.09)
			_beam(root,foot,shoulder,.055,.12,stone)
			_beam(root,shoulder,Vector3(0,height*.86,.09),.055,.12,stone)
		for i: int in range(2):
			var centre: Vector3 = Vector3(0,spring*(.32+i*.34),.10)
			var span: float = half*.42
			var diamond: Array[Vector3] = [Vector3(0,span*1.5,0),Vector3(span,0,0),Vector3(0,-span*1.5,0),Vector3(-span,0,0)]
			for j: int in range(4):
				_beam(root,centre+diamond[j],centre+diamond[(j+1)%4],.045,.1,stone)

func ring(parent: Node3D,inner: float,outer: float,top: float,bottom: float,material: Material,segments: int = 64) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(segments):
		var a: Vector3 = Vector3(sin(i*TAU/segments),0,cos(i*TAU/segments))
		var b: Vector3 = Vector3(sin((i+1)*TAU/segments),0,cos((i+1)*TAU/segments))
		_quad(surface,a*inner+Vector3.UP*top,b*inner+Vector3.UP*top,b*outer+Vector3.UP*top,a*outer+Vector3.UP*top)
		_quad(surface,a*outer+Vector3.UP*top,b*outer+Vector3.UP*top,b*outer+Vector3.UP*bottom,a*outer+Vector3.UP*bottom)
		_quad(surface,b*inner+Vector3.UP*top,a*inner+Vector3.UP*top,a*inner+Vector3.UP*bottom,b*inner+Vector3.UP*bottom)
	M.node(parent,M.finish(surface),material,"IntactCourtTier")

func roof(parent: Node3D,at: Vector3,width: float,length: float,height: float) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Broad rising facets form one pointed vault, rather than a tiled pitched roof.
	for side: int in [-1,1]:
		for i: int in range(4):
			var t0: float = i/4.0
			var t1: float = (i+1)/4.0
			var p0: Vector3 = Vector3(side*width*.5*(1-t0),height*t0*(1.55-.55*t0),0)
			var p1: Vector3 = Vector3(side*width*.5*(1-t1),height*t1*(1.55-.55*t1),0)
			var a: Vector3 = at+p0+Vector3(0,0,-length*.5)
			var b: Vector3 = at+p0+Vector3(0,0,length*.5)
			var c: Vector3 = at+p1+Vector3(0,0,length*.5)
			var d: Vector3 = at+p1+Vector3(0,0,-length*.5)
			_quad(surface,a,b,c,d) if side>0 else _quad(surface,d,c,b,a)
			for z: float in [-length*.5,length*.5]:
				var centre: Vector3 = at+Vector3(0,0,z)
				var e: Vector3 = at+p0+Vector3(0,0,z)
				var f: Vector3 = at+p1+Vector3(0,0,z)
				M.triangle(surface,centre,f,e) if side*z>0 else M.triangle(surface,centre,e,f)
			for rib: int in range(3):
				var z: float = -length*.5+rib*length*.5
				_beam(parent,at+p0+Vector3(0,0,z),at+p1+Vector3(0,0,z),.18,.24,trim)
	M.node(parent,M.finish(surface),stone,"CompleteFacetedVault")

func _beam(parent: Node3D,a: Vector3,b: Vector3,width: float,depth: float,material: Material) -> void:
	var item: MeshInstance3D = M.box(parent,(a+b)*.5,Vector3(width,a.distance_to(b),depth),material,"AngularStoneRib")
	item.rotation.z = -atan2(b.x-a.x,b.y-a.y)

func _quad(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	M.triangle(surface,a,b,c)
	M.triangle(surface,a,c,d)
