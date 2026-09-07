extends RefCounted
## Side masonry is clipped to the actual upper deck and stays outside the lower route.
const F = preload("res://domain/map_layout/map_layout_canonical.gd")
const M = preload("res://presentation/map/landscape/mesh_tools.gd")
static func build(parent: Node3D, upper: Dictionary, lower: Dictionary, material: Material, continuous_foundation: bool = false, deck_depth: float = .65) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "PassageMasonry"
	parent.add_child(root)
	var upper_line: Array = upper["centerline"]
	var lower_line: Array = lower["centerline"]
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	if continuous_foundation:
		root.set_meta("foundation_bounds",_foundation(surface,upper_line,lower_line,F.float_value(upper["corridor_width"]),F.float_value(lower["corridor_width"]),deck_depth))
	for i: int in range(upper_line.size()-1):
		var a: Vector3 = _point(upper_line[i])
		var b: Vector3 = _point(upper_line[i+1])
		if absf(a.y-b.y) > .001:
			continue
		for j: int in range(lower_line.size()-1):
			var c: Vector3 = _point(lower_line[j])
			var d: Vector3 = _point(lower_line[j+1])
			var hit: Variant = Geometry2D.segment_intersects_segment(Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z),Vector2(d.x,d.z))
			if hit == null or a.y-maxf(c.y,d.y) < 2.4:
				continue
			var centre: Vector2 = hit
			root.set_meta("crossing_centre",Vector3(centre.x,c.y+1.5,centre.y))
			var direction: Vector2 = Vector2(d.x-c.x,d.z-c.z).normalized()
			var side: Vector2 = Vector2(-direction.y,direction.x)
			var deck: PackedVector2Array = _strip(Vector2(a.x,a.z),Vector2(b.x,b.z),F.float_value(upper["corridor_width"])*.5)
			var reach: float = Vector2(b.x-a.x,b.z-a.z).length()+4.0
			if continuous_foundation:
				continue
			var offset: float = F.float_value(lower["corridor_width"])*.5+.35+.4
			for sign_value: float in [-1.0,1.0]:
				var at: Vector2 = centre+side*offset*sign_value
				var wall: PackedVector2Array = _strip(at-direction*reach,at+direction*reach,.4)
				for footprint: PackedVector2Array in Geometry2D.intersect_polygons(deck,wall):
					_prism(surface,footprint,minf(c.y,d.y)-.15,a.y-.05)
	M.node(root,M.finish(surface),material,"ClippedStoneAbutments")
	return root
static func _foundation(surface: SurfaceTool,upper: Array,lower: Array,upper_width: float,lower_width: float,deck_depth: float) -> Array[AABB]:
	var bounds: Array[AABB] = []
	var floor_height: float = INF
	for point: Variant in lower:
		floor_height = minf(floor_height,_point(point).y)
	for i: int in range(upper.size()-1):
		var a: Vector3 = _point(upper[i])
		var b: Vector3 = _point(upper[i+1])
		if absf(a.y-b.y) > .001 or a.y-floor_height < 2.4:
			continue
		var pieces: Array[PackedVector2Array] = [_strip(Vector2(a.x,a.z),Vector2(b.x,b.z),upper_width*.5)]
		for j: int in range(lower.size()-1):
			var c: Vector3 = _point(lower[j])
			var d: Vector3 = _point(lower[j+1])
			var opening: PackedVector2Array = _strip(Vector2(c.x,c.z),Vector2(d.x,d.z),lower_width*.5+.35)
			var remaining: Array[PackedVector2Array] = []
			for piece: PackedVector2Array in pieces:
				remaining.append_array(Geometry2D.clip_polygons(piece,opening))
			pieces = remaining
		for piece: PackedVector2Array in pieces:
			_prism(surface,piece,floor_height-.15,a.y-deck_depth)
			var box: AABB = AABB(Vector3(piece[0].x,floor_height-.15,piece[0].y),Vector3.ZERO)
			for point: Vector2 in piece:
				box = box.expand(Vector3(point.x,a.y-deck_depth,point.y))
			bounds.append(box)
	return bounds

static func _strip(a: Vector2,b: Vector2,radius: float) -> PackedVector2Array:
	var along: Vector2 = (b-a).normalized()
	var side: Vector2 = Vector2(-along.y,along.x)*radius
	return PackedVector2Array([a+side,a-side,b-side,b+side])
static func _prism(surface: SurfaceTool, polygon: PackedVector2Array, bottom: float, top: float) -> void:
	var centre: Vector2 = Vector2.ZERO
	for point: Vector2 in polygon:
		centre += point
	centre /= polygon.size()
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	for i: int in range(0,indices.size(),3):
		var a: Vector2 = polygon[indices[i]]
		var b: Vector2 = polygon[indices[i+1]]
		var c: Vector2 = polygon[indices[i+2]]
		_face(surface,Vector3(a.x,top,a.y),Vector3(b.x,top,b.y),Vector3(c.x,top,c.y),Vector3.UP)
		_face(surface,Vector3(a.x,bottom,a.y),Vector3(b.x,bottom,b.y),Vector3(c.x,bottom,c.y),Vector3.DOWN)
	for i: int in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i+1)%polygon.size()]
		var outward: Vector2 = (a+b)*.5-centre
		var normal: Vector3 = Vector3(outward.x,0,outward.y)
		_face(surface,Vector3(a.x,top,a.y),Vector3(a.x,bottom,a.y),Vector3(b.x,bottom,b.y),normal)
		_face(surface,Vector3(a.x,top,a.y),Vector3(b.x,bottom,b.y),Vector3(b.x,top,b.y),normal)
static func _face(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,normal: Vector3) -> void:
	# Godot front faces use clockwise winding.
	if (b-a).cross(c-a).dot(normal) > 0:
		M.triangle(surface,a,c,b)
	else:
		M.triangle(surface,a,b,c)

static func _point(value: Variant) -> Vector3:
	var coordinates: Array = value
	return M.v3(coordinates)
