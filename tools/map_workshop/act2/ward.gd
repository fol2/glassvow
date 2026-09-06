extends "res://tools/map_workshop/act2/library.gd"
## A connected civic group: glass tower, reading wings and flooded courtyard.
func build_ward(tower_height: float, mirrored: bool) -> void:
	stone.shader = preload("res://tools/map_workshop/act2/masonry.gdshader")
	glass.shader = preload("res://tools/map_workshop/act2/glass.gdshader")
	M.box(self,Vector3(0,-.05,0),Vector3(9.4,2.1,6.4),stone,"WardFoundation")
	# The low precinct is overtopped by the flood. Only its coping and aisles emerge.
	for sign_value: int in [-1,1]:
		M.box(self,Vector3(sign_value*3.35,1.02,0),Vector3(2.5,.4,6.4),stone,"ReadingWingFloor")
		for i: int in range(2):
			_bay(Vector3(sign_value*4.4,1.22,-1.65+i*3.1),sign_value*PI*.5,3.1,3.4-i*.4)
		_bay(Vector3(sign_value*2.8,1.22,-3.0),0,3.2,4.15)
		_shelf(Vector3(sign_value*3.8,1.22,-1.2),-sign_value*PI*.5)
		for i: int in range(4):
			M.box(self,Vector3(sign_value*3.25,1.13-i*.19,2.15+i*.22),Vector3(2.4,.24,.28),stone,"DrownedWingStair")
	var tower: Node3D = preload("res://tools/map_workshop/act2/gothic_spire.gd").new()
	add_child(tower)
	tower.position = Vector3(.6 if mirrored else -.6,0,-.7)
	tower.build_spire(tower_height)
	for sign_value: int in [-1,1]:
		M.box(self,Vector3(sign_value*4.5,.45,2.7),Vector3(.55,2.7,.65),trim,"CourtBoundaryPier")
		M.box(self,Vector3(sign_value*4.5,1.85,2.7),Vector3(.72,.16,.82),dark,"PierCap")
