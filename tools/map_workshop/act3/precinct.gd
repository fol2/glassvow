extends Node3D
## Complete royal architecture: entry, recessed audience court and raised hall.
const M = preload("res://tools/map_workshop/mesh_tools.gd")
const Palette = preload("res://tools/map_workshop/act3/materials.gd")
const Stonework = preload("res://tools/map_workshop/act3/stonework.gd")
var kit: Stonework = Stonework.new()
var halo: Node3D
var crystal: MeshInstance3D
var manual_time: bool = false
var elapsed: float = 0.0

func build() -> void:
	# The complete plinth carries the court; the centre is a deliberate recess.
	kit.ring(self,10.88,19.0,2.02,-3.1,kit.stone)
	kit.ring(self,0,8.0,.32,-3.1,Palette.obsidian(Color("211927"),.10))
	for i: int in range(6):
		kit.ring(self,8.0+i*.48,8.48+i*.48,.6+i*.284,.2,kit.trim)
	M.box(self,Vector3(0,1.88,18.0),Vector3(5.0,.28,4.0),kit.stone,"EntryApron")
	# Complete front portal with broad tapering pylons, not scattered spikes.
	for side: int in [-1,1]:
		kit.pier(self,Vector3(side*3.6,2.02,15.9),1.45,6.0)
		kit.arch(self,Vector3(side*3.6,2.55,16.5),.72,3.8,.28,true)
	kit.arch(self,Vector3(0,2.02,15.9),5.5,6.5,.85)
	# Intact side galleries frame the recessed centre and stay open at the gate.
	for i: int in range(17):
		var angle: float = -.98*PI+i*1.96*PI/16
		var point: Vector3 = Vector3(sin(angle)*16.2,2.02,cos(angle)*16.2)
		if absf(point.x)<7.2:
			continue
		var bay: Node3D = Node3D.new()
		add_child(bay)
		bay.position = point
		bay.rotation.y = angle
		kit.pier(bay,Vector3(-3.05,0,0),.85,5.1)
		kit.arch(bay,Vector3.ZERO,5.3,4.9,.7)
		M.box(bay,Vector3(0,5.15,0),Vector3(6.35,.38,1.1),kit.stone,"WholeGalleryCornice")
		if i%3==0:
			kit.arch(bay,Vector3(-3.05,.45,.32),.48,3.6,.12,true)
	_hall()
	_halo()

func _hall() -> void:
	var hall: Node3D = Node3D.new()
	add_child(hall)
	hall.position = Vector3(0,3.25,-11.5)
	M.box(self,Vector3(0,.05,-11.5),Vector3(13.8,6.4,11.0),kit.stone,"SovereignHallFoundation")
	for side: int in [-1,1]:
		M.box(hall,Vector3(side*6.1,3.7,0),Vector3(.65,7.4,9.8),kit.stone,"IntactHallWall")
		for i: int in range(3):
			var bay: Node3D = Node3D.new()
			hall.add_child(bay)
			bay.position = Vector3(side*6.5,.45,-3.0+i*3.0)
			bay.rotation.y = side*PI*.5
			kit.pier(bay,Vector3(1.25,-.45,-.15),.7,7.5)
			kit.arch(bay,Vector3.ZERO,1.7,5.8,.30,true)
	M.box(hall,Vector3(0,3.7,-4.8),Vector3(12.2,7.4,.6),kit.stone,"CompleteRearWall")
	for side: int in [-1,1]:
		M.box(hall,Vector3(side*4.45,3.7,4.8),Vector3(3.3,7.4,.6),kit.stone,"HallFrontWing")
		kit.arch(hall,Vector3(side*4.4,.4,5.16),1.8,5.7,.25,true)
		kit.pier(hall,Vector3(side*6.25,0,5),.95,8.5)
	kit.arch(hall,Vector3(0,0,4.8),4.8,7.5,.8)
	kit.roof(hall,Vector3(0,7.4,0),13.4,11.0,5.8)
	kit.arch(hall,Vector3(0,8.0,5.52),2.3,3.9,.28,true)
	for i: int in range(18):
		var top: float = .32+(i+1)*2.93/18
		M.box(self,Vector3(0,(top+.32)*.5,-1.1-i*.28),Vector3(5.2,top-.32,.3),kit.stone,"SovereignHallStair")

func _halo() -> void:
	halo = Node3D.new()
	add_child(halo)
	halo.position = Vector3(0,3.4,0)
	halo.rotation_degrees = Vector3(28,0,0)
	for i: int in range(20):
		if i in [3,4,10,16]:
			continue
		var angle: float = i*TAU/20
		var point: Vector3 = Vector3(cos(angle)*3.05,0,sin(angle)*3.05)
		M.box(halo,point,Vector3(.92,.23,.42),kit.trim,"FragmentedSupernaturalHalo",-angle-PI*.5)
		M.box(halo,point+Vector3.UP*.125,Vector3(.77,.035,.08),kit.glass,"HaloJointLight",-angle-PI*.5)
	var mesh: PrismMesh = PrismMesh.new()
	mesh.size = Vector3(.95,2.7,.95)
	crystal = M.node(self,mesh,kit.glass,"SuspendedVioletCrystal")
	crystal.position = Vector3(0,2.75,0)
	crystal.rotation_degrees = Vector3(0,45,180)

func set_capture_time(seconds: float) -> void:
	halo.rotation.y = seconds*.065
	crystal.position.y = 2.75+sin(seconds*.7)*.09

func _process(delta: float) -> void:
	if not manual_time and is_instance_valid(halo):
		elapsed += delta
		set_capture_time(elapsed)
