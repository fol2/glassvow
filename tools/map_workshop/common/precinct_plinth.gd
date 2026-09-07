extends RefCounted
## One batched dressed foundation around exposed court boundaries only.
const M = preload("res://tools/map_workshop/mesh_tools.gd")
const F = preload("res://domain/map_layout/map_layout_canonical.gd")
static func build(parent: Node3D, regions: Array[Dictionary], heights: Array[float], material: Material) -> MeshInstance3D:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for index: int in range(regions.size()):
		var region: Dictionary = regions[index]
		var x0: float = region["west"]
		var x1: float = region["east"]
		var z0: float = region["near"]
		var z1: float = region["far"]
		_edge(surface,Vector2(x0,z0),Vector2(x1,z0),Vector2(0,-1),heights[index])
		_edge(surface,Vector2(x1,z1),Vector2(x0,z1),Vector2(0,1),heights[index])
		for side: int in [-1,1]:
			var neighbour: int = index+side
			var exposed: Array[Vector2] = [Vector2(z0,z1)]
			if neighbour >= 0 and neighbour < regions.size():
				var next: Dictionary = regions[neighbour]
				exposed = []
				var low: float = minf(z1,F.float_value(next["near"]))
				var high: float = maxf(z0,F.float_value(next["far"]))
				if low > z0:
					exposed.append(Vector2(z0,low))
				if high < z1:
					exposed.append(Vector2(high,z1))
			var x: float = x0 if side < 0 else x1
			for interval: Vector2 in exposed:
				_edge(surface,Vector2(x,interval.x),Vector2(x,interval.y),Vector2(side,0),heights[index])
	return M.node(parent,M.finish(surface),material,"DressedCourtPlinth")

static func _edge(surface: SurfaceTool,a: Vector2,b: Vector2,outward: Vector2,height: float) -> void:
	var direction: Vector2 = b-a
	if Vector2(direction.y,-direction.x).dot(outward) > 0:
		_edge(surface,b,a,outward,height)
		return
	# Entire profile is below walking level. Bevels catch light without a raised trip edge.
	var section: PackedVector2Array = [Vector2(-.12,height-.06),Vector2(.13,height-.16),
		Vector2(.13,height-.38),Vector2(-.04,height-.53),Vector2(-.04,-1.55),
		Vector2(.18,-1.73),Vector2(.18,-2.05),Vector2(-.18,-2.05),Vector2(-.18,height-.06)]
	for index: int in range(section.size()-1):
		var first: Vector2 = section[index]
		var last: Vector2 = section[index+1]
		var colour: Color = Color(.85,.85,.85) if index == 3 else Color.WHITE
		var p: Vector3 = _point(a,outward,first)
		var q: Vector3 = _point(b,outward,first)
		var r: Vector3 = _point(b,outward,last)
		var s: Vector3 = _point(a,outward,last)
		M.triangle(surface,p,q,r,colour)
		M.triangle(surface,p,r,s,colour)
	var cap: PackedInt32Array = Geometry2D.triangulate_polygon(section)
	for i: int in range(0,cap.size(),3):
		M.triangle(surface,_point(a,outward,section[cap[i]]),_point(a,outward,section[cap[i+1]]),_point(a,outward,section[cap[i+2]]))
		M.triangle(surface,_point(b,outward,section[cap[i+2]]),_point(b,outward,section[cap[i+1]]),_point(b,outward,section[cap[i]]))
static func _point(at: Vector2,outward: Vector2,section: Vector2) -> Vector3:
	var xz: Vector2 = at+outward*section.x
	return Vector3(xz.x,section.y,xz.y)
