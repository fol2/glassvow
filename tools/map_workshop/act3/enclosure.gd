extends Node3D
## Continuous intact outer gallery gives the journey a shared architectural boundary.
const M = preload("res://presentation/map/landscape/mesh_tools.gd")
const Kit = preload("res://tools/map_workshop/act3/stonework.gd")
var bays: int = 0
func build(ground: Node3D) -> void:
	var hull: PackedVector2Array = ground.footprint
	var kit: Kit = Kit.new()
	for i: int in range(hull.size()):
		var a: Vector2 = hull[i]
		var b: Vector2 = hull[(i+1)%hull.size()]
		# The far gallery encloses the court without hiding the near-side journey.
		if maxf(a.y,b.y)>-15 or a.distance_to(b)<2:
			continue
		var count: int = maxi(1,ceili(a.distance_to(b)/6.0))
		var width: float = a.distance_to(b)/count
		var forward: Vector2 = (b-a).normalized()
		for bay: int in range(count):
			var point: Vector2 = a.lerp(b,(bay+.5)/count)
			var at: Vector3 = ground._point(point.x,point.y)
			var group: Node3D = Node3D.new()
			add_child(group)
			group.position = at
			group.rotation.y = -atan2(forward.y,forward.x)
			M.box(group,Vector3(0,-2.0,0),Vector3(width+.05,4.4,1.9),kit.stone,"ContinuousGalleryFoundation")
			kit.arch(group,Vector3(0,.2,0),maxf(.8,width-.8),5.2,.65)
			kit.pier(group,Vector3(-width*.5,.2,0),.70,5.5)
			M.box(group,Vector3(0,5.8,0),Vector3(width+.08,.42,1.1),kit.stone,"ContinuousOuterCoping")
			if bays%4==0:
				kit.arch(group,Vector3(-width*.5,.65,.40),.4,3.5,.12,true)
			bays += 1
	_near_boundary(ground,kit)
	print("ACT_III_ENCLOSURE bays=",bays)

func _near_boundary(ground: Node3D,kit: Kit) -> void:
	var hull: PackedVector2Array = ground.footprint
	for i: int in range(hull.size()):
		var a: Vector2 = hull[i]
		var b: Vector2 = hull[(i+1)%hull.size()]
		if minf(a.y,b.y)<18 or a.distance_to(b)<8:
			continue
		var count: int = maxi(1,floori(a.distance_to(b)/13))
		for j: int in range(count):
			var point: Vector2 = a.lerp(b,(j+.5)/count)
			point.y -= 2.0
			var at: Vector3 = ground._point(point.x,point.y)
			var group: Node3D = Node3D.new()
			add_child(group)
			group.position = at
			# Low, broad guards establish the near edge without a wall across the view.
			M.box(group,Vector3(0,-.4,0),Vector3(2.2,1.1,2.2),kit.stone,"BoundaryGuardFoot")
			kit.pier(group,Vector3(0,.15,0),1.2,3.7)
			kit.arch(group,Vector3(0,.55,.62),.6,2.6,.12,true)
