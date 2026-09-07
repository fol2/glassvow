extends "res://presentation/map/chapters/act2/library.gd"
## Faceted stained-glass civic tower, echoing the Act II combat skyline.
func build_spire(height: float = 5.4) -> void:
	stone.shader = preload("res://presentation/map/chapters/act2/masonry.gdshader")
	glass.shader = preload("res://presentation/map/chapters/act2/glass.gdshader")
	var base: CylinderMesh = CylinderMesh.new()
	base.top_radius = 1.5
	base.bottom_radius = 1.7
	base.height = 2.2
	base.radial_segments = 8
	M.node(self,base,stone,"FloodedTowerBase").position.y = .2
	var spring: float = 1.28
	var pane_height: float = height-2.4
	for i: int in range(8):
		var angle: float = i*TAU/8
		var facet: Node3D = Node3D.new()
		add_child(facet)
		facet.position = Vector3(sin(angle)*1.39,spring,cos(angle)*1.39)
		facet.rotation.y = angle
		_arch(facet,Vector3.ZERO,1.12,pane_height,true)
		for sign_value: int in [-1,1]:
			M.box(facet,Vector3(sign_value*.59,pane_height*.5,0),Vector3(.13,pane_height,.21),dark,"TowerMullion")
	var roof: CylinderMesh = CylinderMesh.new()
	roof.top_radius = .035
	roof.bottom_radius = 1.85
	roof.height = 2.6
	roof.radial_segments = 8
	M.node(self,roof,M.material(Color("253c49"),.55),"FacetedSpireRoof").position.y = spring+pane_height+1.3
	for i: int in range(8):
		var angle: float = (i+.5)*TAU/8
		var a: Vector3 = Vector3(sin(angle)*1.86,spring+pane_height,cos(angle)*1.86)
		var b: Vector3 = Vector3(0,spring+pane_height+2.6,0)
		var rib: MeshInstance3D = M.box(self,(a+b)*.5,Vector3(.07,.07,a.distance_to(b)),trim,"SpireRoofRib")
		rib.basis = Basis.looking_at((b-a).normalized(),Vector3.UP)
