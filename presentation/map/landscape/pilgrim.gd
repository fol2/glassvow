extends Node3D
## Small anonymous cloaked traveller, with a carried light and a grounded hem.
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
var cloak: Node3D
var lamp: Node3D
var boots: Array[Node3D] = []

func _ready() -> void:
	var cloth: StandardMaterial3D = Meshes.material(Color("38333e"))
	var dark: StandardMaterial3D = Meshes.material(Color("211e27"))
	var iron: StandardMaterial3D = Meshes.material(Color("443b39"),.65)
	cloak = Node3D.new()
	add_child(cloak)
	var folds: SurfaceTool = SurfaceTool.new()
	folds.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[Vector2] = [Vector2(.33,.10),Vector2(.27,.70),Vector2(.24,1.25),Vector2(.15,1.38)]
	for j: int in range(rings.size()-1):
		for i: int in range(12):
			var a: float = i*TAU/12
			var b: float = (i+1)*TAU/12
			var r: float = 1.0 if i%2==0 else .91
			var next_r: float = 1.0 if (i+1)%2==0 else .91
			var p: Vector3 = Vector3(cos(a)*rings[j].x*r,rings[j].y,sin(a)*rings[j].x*r)
			var q: Vector3 = Vector3(cos(b)*rings[j].x*next_r,rings[j].y,sin(b)*rings[j].x*next_r)
			var u: Vector3 = Vector3(cos(a)*rings[j+1].x*r,rings[j+1].y,sin(a)*rings[j+1].x*r)
			var v: Vector3 = Vector3(cos(b)*rings[j+1].x*next_r,rings[j+1].y,sin(b)*rings[j+1].x*next_r)
			Meshes.triangle(folds,p,v,u)
			Meshes.triangle(folds,p,q,v)
	Meshes.node(cloak,Meshes.finish(folds),cloth,"Heavy travelling cloak")
	var hood: SphereMesh = SphereMesh.new()
	hood.radius = .205
	hood.height = .43
	hood.radial_segments = 12
	hood.rings = 6
	Meshes.node(cloak,hood,cloth,"Deep hood").position = Vector3(0,1.47,0)
	var face: SphereMesh = SphereMesh.new()
	face.radius = .13
	face.height = .28
	var hollow: MeshInstance3D = Meshes.node(cloak,face,dark,"Hood shadow")
	hollow.position = Vector3(0,1.47,.215)
	hollow.scale.z = .42
	for side: float in [-1,1]:
		boots.append(Meshes.box(self,Vector3(side*.11,.06,.05),Vector3(.13,.12,.24),dark,"Worn boot"))
	var sleeve: CylinderMesh = CylinderMesh.new()
	sleeve.top_radius = .10
	sleeve.bottom_radius = .075
	sleeve.height = .48
	sleeve.radial_segments = 8
	var arm: MeshInstance3D = Meshes.node(cloak,sleeve,cloth,"Lantern arm")
	arm.position = Vector3(.29,1.01,.08)
	arm.rotation.z = .30
	var glove: SphereMesh = SphereMesh.new()
	glove.radius = .07
	glove.height = .15
	Meshes.node(cloak,glove,iron,"Worn glove").position = Vector3(.38,.80,.14)
	lamp = Node3D.new()
	lamp.position = Vector3(.40,.58,.19)
	add_child(lamp)
	Meshes.box(lamp,Vector3(0,.17,0),Vector3(.18,.035,.18),iron,"Lantern cap")
	Meshes.box(lamp,Vector3(0,-.07,0),Vector3(.17,.035,.17),iron,"Lantern foot")
	var glass: StandardMaterial3D = Meshes.material(Color("edbd71"))
	glass.emission_enabled = true
	glass.emission = Color("e9ab54")
	glass.emission_energy_multiplier = 1.8
	Meshes.box(lamp,Vector3(0,.05,0),Vector3(.115,.20,.115),glass,"Carried ember")
	for x: float in [-1,1]:
		for z: float in [-1,1]:
			Meshes.box(lamp,Vector3(x*.073,.05,z*.073),Vector3(.022,.24,.022),iron,"Lantern corner")
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color("e9b76d")
	light.light_energy = .32
	light.omni_range = 1.4
	lamp.add_child(light)
	Meshes.box(lamp,Vector3(0,.21,0),Vector3(.025,.12,.025),iron,"Lantern handle")

func pose(distance: float, walking: bool) -> void:
	cloak.rotation.z = sin(distance*5)*.025 if walking else 0.0
	lamp.rotation.x = sin(distance*5)*.12 if walking else 0.0
	for i: int in range(boots.size()):
		var stride: float = sin(distance*5+i*PI) if walking else 0.0
		boots[i].position.z = .05+stride*.09
		boots[i].position.y = .06+maxf(0,stride)*.045
