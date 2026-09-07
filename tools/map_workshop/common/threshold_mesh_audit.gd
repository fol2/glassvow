extends RefCounted
## Vertical probes against actual rendered triangles, across each route's width.
static func run(roots: Array[Node3D], walking: MeshInstance3D, routes: Dictionary, require_overhead: bool = true) -> Dictionary:
	var ceilings: Array[Dictionary] = []
	for root: Node3D in roots:
		_collect(root,ceilings)
	var floors: Array[Dictionary] = []
	_collect(walking,floors)
	return sample(ceilings,floors,routes,require_overhead)

static func sample(ceilings: Array[Dictionary], floors: Array[Dictionary], routes: Dictionary, require_overhead: bool = true) -> Dictionary:
	var ceiling_index: Dictionary = _index(ceilings)
	var floor_index: Dictionary = _index(floors)
	var minimum: float = INF
	var probes: int = 0
	var overhead_hits: int = 0
	var failures: Array[Dictionary] = []
	for id: String in MapLayoutCanonical.sorted_keys(routes):
		var route: Dictionary = routes[id]
		var line: Array = route["centerline"]
		var radius: float = MapLayoutCanonical.float_value(route["corridor_width"])*.5
		for i: int in range(line.size()-1):
			var a: Vector3 = _point(line[i])
			var b: Vector3 = _point(line[i+1])
			var direction: Vector3 = Vector3(b.x-a.x,0,b.z-a.z)
			var steps: int = maxi(1,ceili(direction.length()/.35))
			var side: Vector3 = direction.normalized().cross(Vector3.UP)
			for step: int in range(steps+1):
				var centre: Vector3 = a.lerp(b,float(step)/steps)
				for lane: int in range(7):
					var p: Vector3 = centre+side*lerpf(-radius,radius,float(lane)/6)
					var overhead: float = INF
					var bucket: Vector2i = Vector2i(floori(p.x/4.0),floori(p.z/4.0))
					var possible_ceilings: Array = ceiling_index.get(bucket,[])
					for triangle: Dictionary in possible_ceilings:
						var y: float = _height(p,triangle)
						if is_finite(y) and y > centre.y-.01:
							overhead = minf(overhead,y)
					if not is_finite(overhead) and require_overhead:
						continue
					if is_finite(overhead):
						overhead_hits += 1
					var floor_y: float = -INF
					var possible_floors: Array = floor_index.get(bucket,[])
					for triangle: Dictionary in possible_floors:
						var y: float = _height(p,triangle,.0001)
						# The actual step can be one riser above the slope centreline.
						if is_finite(y) and y <= centre.y+.18 and y >= centre.y-.18:
							floor_y = maxf(floor_y,y)
					probes += 1
					if not is_finite(floor_y):
						failures.append({"edge":id,"nearest_walking_edge_m":_nearest_edge(p,centre.y,floors),"reason":"no walking triangle under threshold probe","at":[p.x,p.y,p.z]})
						continue
					var clearance: float = overhead-floor_y
					minimum = minf(minimum,clearance)
					if clearance < 2.4:
						failures.append({"edge":id,"reason":"actual threshold headroom below 2.4 m","clearance":clearance})
	return {"ok":not probes == 0 and failures.is_empty(),"probe_count":probes,"overhead_hits":overhead_hits,"require_overhead":require_overhead,
		"minimum_headroom_m":minimum if is_finite(minimum) else -1.0,"failures":failures,
		"floor_edge_tolerance_m":.0001,"spacing_m":.35,"width_lanes":7,"scope":"sampled actual mesh, thresholds only"}

static func _index(triangles: Array[Dictionary]) -> Dictionary:
	var buckets: Dictionary = {}
	for triangle: Dictionary in triangles:
		var bounds: Rect2 = triangle["bounds"]
		bounds = bounds.grow(.0001)
		for x: int in range(floori(bounds.position.x/4.0),floori(bounds.end.x/4.0)+1):
			for z: int in range(floori(bounds.position.y/4.0),floori(bounds.end.y/4.0)+1):
				var key: Vector2i = Vector2i(x,z)
				if not buckets.has(key):
					buckets[key] = []
				var entries: Array = buckets[key]
				entries.append(triangle)
	return buckets
static func _collect(root: Node, triangles: Array[Dictionary]) -> void:
	if root is MeshInstance3D:
		var instance: MeshInstance3D = root
		var faces: PackedVector3Array = instance.mesh.get_faces()
		for i: int in range(0,faces.size(),3):
			var a: Vector3 = instance.global_transform*faces[i]
			var b: Vector3 = instance.global_transform*faces[i+1]
			var c: Vector3 = instance.global_transform*faces[i+2]
			var box: Rect2 = Rect2(Vector2(a.x,a.z),Vector2.ZERO).expand(Vector2(b.x,b.z)).expand(Vector2(c.x,c.z))
			triangles.append({"a":a,"b":b,"c":c,"bounds":box.grow(.00001)})
	for child: Node in root.get_children():
		_collect(child,triangles)
static func _height(p: Vector3,triangle: Dictionary,tolerance: float = 0.0) -> float:
	var box: Rect2 = triangle["bounds"]
	if not box.grow(tolerance).has_point(Vector2(p.x,p.z)):
		return NAN
	var a: Vector3 = triangle["a"]
	var b: Vector3 = triangle["b"]
	var c: Vector3 = triangle["c"]
	var ab: Vector2 = Vector2(b.x-a.x,b.z-a.z)
	var ac: Vector2 = Vector2(c.x-a.x,c.z-a.z)
	var ap: Vector2 = Vector2(p.x-a.x,p.z-a.z)
	var determinant: float = ab.cross(ac)
	if absf(determinant) < .0000001:
		return NAN
	var u: float = ap.cross(ac)/determinant
	var v: float = ab.cross(ap)/determinant
	if u < -.00001 or v < -.00001 or u+v > 1.00001:
		var vertices: Array[Vector3] = [a,b,c]
		for i: int in range(3):
			var first: Vector3 = vertices[i]
			var last: Vector3 = vertices[(i+1)%3]
			var start: Vector2 = Vector2(first.x,first.z)
			var end: Vector2 = Vector2(last.x,last.z)
			var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2(p.x,p.z),start,end)
			if tolerance > 0 and nearest.distance_to(Vector2(p.x,p.z)) <= tolerance:
				return lerpf(first.y,last.y,start.distance_to(nearest)/maxf(start.distance_to(end),.000001))
		return NAN
	return a.y+u*(b.y-a.y)+v*(c.y-a.y)
static func _point(value: Variant) -> Vector3:
	var point: Array = value
	return Vector3(MapLayoutCanonical.float_value(point[0]),MapLayoutCanonical.float_value(point[1]),MapLayoutCanonical.float_value(point[2]))

static func _nearest_edge(p: Vector3,expected_y: float,triangles: Array[Dictionary]) -> float:
	var minimum: float = INF
	for triangle: Dictionary in triangles:
		var a: Vector3 = triangle["a"]
		var b: Vector3 = triangle["b"]
		var c: Vector3 = triangle["c"]
		if maxf(a.y,maxf(b.y,c.y)) < expected_y-.18 or minf(a.y,minf(b.y,c.y)) > expected_y+.18:
			continue
		var points: Array[Vector2] = [Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)]
		var sample: Vector2 = Vector2(p.x,p.z)
		for i: int in range(3):
			minimum = minf(minimum,sample.distance_to(Geometry2D.get_closest_point_to_segment(sample,points[i],points[(i+1)%3])))
	return minimum if is_finite(minimum) else -1.0
