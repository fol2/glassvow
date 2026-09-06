extends Node3D
## Sparse intact architectural groups, placed in measured gaps in the route network.
const M = preload("res://tools/map_workshop/mesh_tools.gd")
const Kit = preload("res://tools/map_workshop/act3/stonework.gd")
var placed: Array[Dictionary] = []
func build(routes: Node3D,ground: Node3D) -> void:
	var samples: PackedVector3Array = []
	for line: PackedVector3Array in routes.sampled_routes.values():
		for i: int in range(0,line.size(),3):
			samples.append(line[i])
	var candidates: Array[Dictionary] = []
	for x: int in range(-54,62,5):
		for z: int in range(-28,29,5):
			var at: Vector2 = Vector2(x,z)
			var distance: float = INF
			for p: Vector3 in samples:
				distance = minf(distance,at.distance_to(Vector2(p.x,p.z)))
			var supported: bool = true
			var footprint: PackedVector2Array = ground.footprint
			for offset: Vector2 in [Vector2(-4.5,-3.5),Vector2(4.5,-3.5),Vector2(4.5,3.5),Vector2(-4.5,3.5)]:
				supported = supported and Geometry2D.is_point_in_polygon(at+offset,footprint)
			if supported and distance>5.8 and distance<12:
				candidates.append({"at":at,"space":distance})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var first: float = a["space"]
		var second: float = b["space"]
		return first>second)
	var kit: Kit = Kit.new()
	for candidate: Dictionary in candidates:
		var at: Vector2 = candidate["at"]
		var occupied: bool = false
		for old: Dictionary in placed:
			var old_at: Vector2 = old["at"]
			occupied = occupied or at.distance_to(old_at)<14
		if occupied:
			continue
		var group: Node3D = Node3D.new()
		add_child(group)
		var base_height: float = -INF
		for offset: Vector2 in [Vector2(-4.4,-3.2),Vector2(4.4,-3.2),Vector2(4.4,3.2),Vector2(-4.4,3.2)]:
			var surface_at: Vector3 = ground._point(at.x+offset.x,at.y+offset.y)
			base_height = maxf(base_height,surface_at.y)
		group.position = Vector3(at.x,base_height,at.y)
		group.scale = Vector3(1.25,1.2,1.25)
		var ordinal: int = placed.size()
		group.rotation.y = .12 if ordinal%2==0 else -.12
		M.box(group,Vector3(0,-1.5,0),Vector3(7,3.88,5),kit.stone,"IntactCeremonialPlatform")
		if ordinal%3==0:
			# One complete empty portal, with a heavy continuous lintel.
			kit.arch(group,Vector3(0,.44,1.95),3.8,5.8,.8)
			for side: int in [-1,1]:
				kit.pier(group,Vector3(side*2.6,.44,1.55),1.05,6.1)
				M.box(group,Vector3(side*2.48,3.1,1.60),Vector3(.65,5.3,.50),kit.stone,"CompleteEntranceWing")
				M.box(group,Vector3(side*2.85,3.1,-.15),Vector3(.6,5.3,3.8),kit.stone,"CompletePavilionSide")
			kit.arch(group,Vector3(0,.44,-1.8),3.8,5.8,.65)
			kit.roof(group,Vector3(0,6.0,-.15),6.5,4.2,2.5)
		elif ordinal%3==1:
			# A short intact gallery, not a broken length of wall.
			for side: int in [-1,1]:
				kit.arch(group,Vector3(side*1.65,.44,0),2.4,3.6,.6)
			M.box(group,Vector3(0,2.25,-1.6),Vector3(6.7,3.6,.4),kit.stone,"CompleteGalleryRear")
			M.box(group,Vector3(0,4.28,-.65),Vector3(6.7,.4,2.8),kit.stone,"CompleteGalleryCoping")
			kit.roof(group,Vector3(0,4.48,-.65),6.7,3.0,1.5)
		else:
			# An empty raised dais retains generous quiet space.
			for step: int in range(3):
				M.box(group,Vector3(0,.5+step*.18,0),Vector3(5-step*.6,.2,3.5-step*.6),kit.trim,"EmptyDaisTier")
			for side: int in [-1,1]:
				kit.pier(group,Vector3(side*2.8,.44,-1.4),.65,3.5)
		placed.append({"at":at,"kind":ordinal%3,"route_distance":candidate["space"]})
		if placed.size()==8:
			break
	print("ACT_III_INTACT_SCENERY groups=",placed.size())
