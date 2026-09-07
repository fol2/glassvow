extends Node3D
## Broad submerged civic forms: a city beneath the flood, not scattered debris.
const M = preload("res://presentation/map/landscape/mesh_tools.gd")

func build(kind: int) -> void:
	var stone: ShaderMaterial = ShaderMaterial.new()
	stone.shader = preload("res://tools/map_workshop/act2/masonry.gdshader")
	var floor_material: StandardMaterial3D = M.material(Color("344652"))
	M.box(self,Vector3(0,.2,0),Vector3(12,1,8),stone,"SubmergedCityBlock")
	if kind%3==0:
		# A flooded hall with an intact perimeter and a single surviving spire.
		for side: int in [-1,1]:
			M.box(self,Vector3(side*5.5,.83,0),Vector3(.55,.32,7.6),stone,"HallCoping")
			if side==-1:
				M.box(self,Vector3(0,.83,side*3.55),Vector3(10.5,.32,.55),stone,"HallCoping")
			else:
				for flank: int in [-1,1]:
					M.box(self,Vector3(flank*3.45,.83,3.55),Vector3(3.6,.32,.55),stone,"HallEntranceReturn")
		M.box(self,Vector3(-2,.73,0),Vector3(4,.12,6),floor_material,"DrownedHallFloor")
	elif kind%3==1:
		# Two long roofs read as one drowned residential street.
		for side: int in [-1,1]:
			M.box(self,Vector3(side*3.25,.75,0),Vector3(4.2,.45,7),stone,"DrownedStreetRoof")
			for z: float in [-2.7,0,2.7]:
				M.box(self,Vector3(side*3.25,1.0,z),Vector3(4.4,.12,.18),stone,"RoofRidge")
	else:
		# A stepped square leaves a broad, quiet shape just below the surface.
		M.box(self,Vector3(0,.73,0),Vector3(9,.3,5.5),floor_material,"DrownedSquare")
		for side: int in [-1,1]:
			M.box(self,Vector3(side*4.7,.92,0),Vector3(.6,.45,6),stone,"SquareParapet")
	var spire: Node3D = preload("res://tools/map_workshop/act2/gothic_spire.gd").new()
	add_child(spire)
	spire.build_spire(5.4)
	spire.scale = Vector3.ONE*(.62 if kind%2==0 else .5)
	spire.position = Vector3(2.8 if kind%2==0 else -3.0,-2.0 if kind%3==0 else -2.6,-1.3)
