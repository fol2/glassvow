extends RefCounted
## Conservative world-space model bounds and swept-route occupancy.
static func bounds(root: Node3D) -> AABB:
	var boxes: Array[AABB] = []
	_collect(root,boxes)
	assert(not boxes.is_empty(), "Architecture has no mesh bounds")
	var result: AABB = boxes[0]
	for box: AABB in boxes:
		result = result.merge(box)
	return result
static func _collect(node: Node, boxes: Array[AABB]) -> void:
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node
		if instance.mesh != null:
			boxes.append(instance.global_transform*instance.mesh.get_aabb())
	for child: Node in node.get_children():
		_collect(child,boxes)
static func conflicts(box: AABB, routes: Dictionary, margin: float = .35) -> Array[String]:
	var out: Array[String] = []
	var footprint: Rect2 = Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
	for id: String in MapLayoutCanonical.sorted_keys(routes):
		var route: Dictionary = routes[id]
		var width: float = MapLayoutCanonical.float_value(route["corridor_width"])
		var expanded: Rect2 = footprint.grow(width*.5+margin)
		var line: Array = route["centerline"]
		for i: int in range(line.size()-1):
			if _intersects(_xz(line[i]),_xz(line[i+1]),expanded):
				out.append(id)
				break
	return out
static func _xz(value: Variant) -> Vector2:
	var point: Array = value
	return Vector2(MapLayoutCanonical.float_value(point[0]),MapLayoutCanonical.float_value(point[2]))
static func _intersects(a: Vector2,b: Vector2,box: Rect2) -> bool:
	# Slab clipping includes tangency and avoids sampling gaps on long segments.
	var low: float = 0.0
	var high: float = 1.0
	var delta: Vector2 = b-a
	for axis: int in range(2):
		if absf(delta[axis]) < .000001:
			if a[axis] < box.position[axis] or a[axis] > box.end[axis]:
				return false
			continue
		var first: float = (box.position[axis]-a[axis])/delta[axis]
		var last: float = (box.end[axis]-a[axis])/delta[axis]
		low = maxf(low,minf(first,last))
		high = minf(high,maxf(first,last))
		if low > high:
			return false
	return true

## Conservative broad-phase placement gate. Touching bounds are permitted.
static func overlaps_buildings(candidate: Node3D, others: Array[Node3D]) -> bool:
	var box: AABB = bounds(candidate)
	for other: Node3D in others:
		if other == candidate:
			continue
		if boxes_overlap(box,bounds(other)):
			return true
	return false

static func boxes_overlap(first: AABB, second: AABB) -> bool:
	var overlap: AABB = first.intersection(second)
	return minf(overlap.size.x,minf(overlap.size.y,overlap.size.z)) > .001
