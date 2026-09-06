extends Node3D
## One broad obsidian terrace with actual lowered passages around the generated routes.
const M = preload("res://tools/map_workshop/mesh_tools.gd")
var samples: Dictionary = {}
var footprint: PackedVector2Array = []
func build(causeways: Node3D) -> void:
	var low: Vector2 = Vector2.INF
	var high: Vector2 = -Vector2.INF
	var outline_points: PackedVector2Array = []
	for line: PackedVector3Array in causeways.sampled_routes.values():
		for i: int in range(0,line.size(),2):
			var p: Vector3 = line[i]
			low = low.min(Vector2(p.x,p.z))
			high = high.max(Vector2(p.x,p.z))
			for offset: Vector2 in [Vector2(-5,-5),Vector2(5,-5),Vector2(5,5),Vector2(-5,5)]:
				outline_points.append(Vector2(p.x,p.z)+offset)
			var cell: Vector2i = Vector2i(floori(p.x/6),floori(p.z/6))
			if not samples.has(cell):
				samples[cell] = []
			samples[cell].append(p)
	# Decorative palace arrivals also grade the land; they do not expand its footprint.
	for line: PackedVector3Array in causeways.ruin_links.values():
		for p: Vector3 in line:
			var cell: Vector2i = Vector2i(floori(p.x/6),floori(p.z/6))
			if not samples.has(cell):
				samples[cell] = []
			samples[cell].append(p)
	low -= Vector2(6,7)
	high += Vector2(5,7)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hull: PackedVector2Array = Geometry2D.convex_hull(outline_points)
	hull.remove_at(hull.size()-1)
	footprint = hull
	# Boundary vertices must follow the same graded entry height as the interior.
	var boundary: PackedVector2Array = []
	for i: int in range(hull.size()):
		var a: Vector2 = hull[i]
		var b: Vector2 = hull[(i+1)%hull.size()]
		var segments: int = maxi(1,ceili(a.distance_to(b)))
		for step: int in range(segments):
			boundary.append(a.lerp(b,step/float(segments)))
	hull = boundary
	var points: PackedVector2Array = hull.duplicate()
	for x: int in range(floori(low.x/1.5),ceili(high.x/1.5)):
		for z: int in range(floori(low.y/1.5),ceili(high.y/1.5)):
			var p: Vector2 = Vector2(x*1.5,z*1.5)
			if Geometry2D.is_point_in_polygon(p,hull):
				points.append(p)
	var indices: PackedInt32Array = Geometry2D.triangulate_delaunay(points)
	for i: int in range(0,indices.size(),3):
		var a: Vector2 = points[indices[i]]
		var b: Vector2 = points[indices[i+1]]
		var c: Vector2 = points[indices[i+2]]
		if (b-a).cross(c-a)>0:
			M.triangle(surface,_point(a.x,a.y),_point(b.x,b.y),_point(c.x,c.y))
		else:
			M.triangle(surface,_point(a.x,a.y),_point(c.x,c.y),_point(b.x,b.y))
	for i: int in range(hull.size()):
		var a: Vector2 = hull[i]
		var b: Vector2 = hull[(i+1)%hull.size()]
		_wall(surface,_point(a.x,a.y),_point(b.x,b.y))
	M.node(self,M.finish(surface),preload("res://tools/map_workshop/act3/materials.gd").obsidian(Color("191521"),.045),"ContinuousFacetedPrecinct")

func _point(x: float,z: float) -> Vector3:
	var height: float = 6.2
	var cell: Vector2i = Vector2i(floori(x/6),floori(z/6))
	for dx: int in range(-1,2):
		for dz: int in range(-1,2):
			for p: Vector3 in samples.get(cell+Vector2i(dx,dz),[]):
				var distance: float = Vector2(x-p.x,z-p.z).length()
				if distance<5.5:
					height = minf(height,p.y-.28+maxf(0,distance-2.2)*.65)
	return Vector3(x,height,z)

func _wall(surface: SurfaceTool,a: Vector3,b: Vector3) -> void:
	var c: Vector3 = Vector3(b.x,-1.8,b.z)
	var d: Vector3 = Vector3(a.x,-1.8,a.z)
	M.triangle(surface,a,c,b)
	M.triangle(surface,a,d,c)
