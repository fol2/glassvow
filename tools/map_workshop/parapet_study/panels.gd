extends RefCounted
## Isolated design comparison. Complete bays, never holes sampled from a wall.
const M = preload("res://tools/map_workshop/mesh_tools.gd")
static func panel(parent: Node3D,kind: String,left: float,right: float,z: float,stone: Material,trim: Material) -> void:
	var centre: float = (left+right)*.5
	var length: float = right-left
	M.box(parent,Vector3(centre,3.50,z),Vector3(length,.20,.24),stone)
	if kind=="a":
		M.box(parent,Vector3(centre,3.95,z),Vector3(length,.70,.10),M.material(Color("35455a")))
	var holes: int = 3 if kind=="c" else 2
	var pitch: float = length/holes
	var width: float = pitch-.18
	for i: int in range(holes):
		var x: float = left+pitch*(i+.5)
		var spring: float = 3.77
		var rise: float = .36
		# True open spandrels; A has a recessed backing wall behind them.
		for j: int in range(16):
			var a: float = -width*.5+width*j/16.0
			var b: float = -width*.5+width*(j+1)/16.0
			var ya: float = spring+pointed(a,width,rise)
			var yb: float = spring+pointed(b,width,rise)
			strip(parent,x+a,x+b,z,.24,ya,yb,4.23,4.23,stone)
			strip(parent,x+a,x+b,z,.28,ya,yb,ya+.065,yb+.065,trim)
		for side: int in [-1,1]:
			M.box(parent,Vector3(x+side*(width*.5+.045),3.91,z),Vector3(.09,.62,.24),stone)
	# Long coping units keep the distant silhouette quiet.
	for i: int in range(2):
		M.box(parent,Vector3(left+length*(i+.5)/2,4.28,z),Vector3(length/2-.008,.12,.34),trim)

static func pointed(x: float,width: float,rise: float) -> float:
	var half: float = width*.5
	return sqrt(maxf(0,width*width-pow(absf(x)+half,2)))/(sqrt(3.0)*half)*rise

static func strip(parent: Node3D,a: float,b: float,z: float,depth: float,low_a: float,low_b: float,high_a: float,high_b: float,material: Material) -> void:
	var s: SurfaceTool = SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	s.set_smooth_group(-1)
	var p: Array[Vector3] = [Vector3(a,low_a,z-depth*.5),Vector3(b,low_b,z-depth*.5),Vector3(b,high_b,z-depth*.5),Vector3(a,high_a,z-depth*.5),Vector3(a,low_a,z+depth*.5),Vector3(b,low_b,z+depth*.5),Vector3(b,high_b,z+depth*.5),Vector3(a,high_a,z+depth*.5)]
	for face: Array in [[0,1,2,3],[5,4,7,6],[4,0,3,7],[1,5,6,2],[3,2,6,7],[4,5,1,0]]:
		M.triangle(s,p[face[0]],p[face[1]],p[face[2]])
		M.triangle(s,p[face[0]],p[face[2]],p[face[3]])
	M.node(parent,M.finish(s),material,"Carved stone")
