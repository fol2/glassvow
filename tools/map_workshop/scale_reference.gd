extends RefCounted
## A 1.75 m review figure; a scale reference rather than a final character asset.
const Meshes = preload("res://tools/map_workshop/mesh_tools.gd")
static func place(parent: Node3D, at: Vector3, yaw: float = 0) -> void:
	var person: Node3D = Node3D.new()
	person.name = "Adult scale reference 1.75 m"
	parent.add_child(person)
	person.position = at
	person.rotation.y = yaw
	var dark: StandardMaterial3D = Meshes.material(Color("302b31"))
	var cloth: StandardMaterial3D = Meshes.material(Color("967e75"))
	for side: float in [-1,1]:
		Meshes.box(person,Vector3(side*.11,.05,.035),Vector3(.14,.10,.29),dark,"Boot")
		var leg: CapsuleMesh = CapsuleMesh.new()
		leg.radius = .075
		leg.height = .68
		Meshes.node(person,leg,dark,"Leg").position = Vector3(side*.10,.40,0)
		var arm: CapsuleMesh = CapsuleMesh.new()
		arm.radius = .065
		arm.height = .52
		var sleeve: MeshInstance3D = Meshes.node(person,arm,cloth,"Sleeve")
		sleeve.position = Vector3(side*.23,1.12,.015)
		sleeve.rotation.z = side*.16
	var cloak: CylinderMesh = CylinderMesh.new()
	cloak.top_radius = .19
	cloak.bottom_radius = .32
	cloak.height = .92
	cloak.radial_segments = 12
	Meshes.node(person,cloak,cloth,"Travelling cloak").position.y = .95
	var hood: SphereMesh = SphereMesh.new()
	hood.radius = .17
	hood.height = .34
	hood.radial_segments = 16
	hood.rings = 8
	Meshes.node(person,hood,cloth,"Hood").position = Vector3(0,1.58,0)
	Meshes.box(person,Vector3(0,1.57,.145),Vector3(.15,.18,.05),dark,"Hood opening")
