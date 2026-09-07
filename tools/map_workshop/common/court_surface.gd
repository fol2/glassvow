extends RefCounted
## Court paving excludes every route footprint, including lower passage surfaces.
## The walking route owns those areas; a terrace can never cover a stair tread.
const Union = preload("res://tools/map_workshop/common/walking_surface_union.gd")
static func resolve(patches: Array[Dictionary], routes: Array[Dictionary]) -> Dictionary:
	var masks: Array[PackedVector2Array] = []
	var mask_heights: Array[float] = []
	for route: Dictionary in routes:
		if route.get("ok") != true:
			return {"ok":false,"reason":"unresolved route cannot govern court cut-outs"}
		for top: PackedVector3Array in route["tops"]:
			var mask: PackedVector2Array = []
			for point: Vector3 in top:
				mask.append(Vector2(point.x,point.z))
			masks.append(mask)
			mask_heights.append(top[0].y)
	var tops: Array[PackedVector3Array] = []
	var walls: Array[PackedVector3Array] = []
	for patch: Dictionary in patches:
		var outline: PackedVector2Array = patch["outline"]
		var height: float = patch["height"]
		walls.append_array(_cut_walls(outline,height,masks,mask_heights))
		var indices: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
		if indices.is_empty():
			return {"ok":false,"reason":"court outline did not triangulate"}
		for index: int in range(0,indices.size(),3):
			var pieces: Array[PackedVector2Array] = [PackedVector2Array([
				outline[indices[index]],outline[indices[index+1]],outline[indices[index+2]]])]
			for mask: PackedVector2Array in masks:
				var remaining: Array[PackedVector2Array] = []
				for piece: PackedVector2Array in pieces:
					if Union._bounds(piece).intersects(Union._bounds(mask)):
						remaining.append_array(Union._subtract(piece,mask))
					else:
						remaining.append(piece)
				pieces = remaining
				if pieces.is_empty():
					break
			for piece: PackedVector2Array in pieces:
				for triangle: int in range(1,piece.size()-1):
					tops.append(PackedVector3Array([Vector3(piece[0].x,height,piece[0].y),
						Vector3(piece[triangle].x,height,piece[triangle].y),
						Vector3(piece[triangle+1].x,height,piece[triangle+1].y)]))
		for edge: int in range(outline.size()):
			var a: Vector2 = outline[edge]
			var b: Vector2 = outline[(edge+1)%outline.size()]
			var intervals: Array[Vector2] = [Vector2(0,1)]
			for mask: PackedVector2Array in masks:
				var cut: Vector2 = _interval(a,b,mask)
				if cut.x > cut.y:
					continue
				var remaining: Array[Vector2] = []
				for interval: Vector2 in intervals:
					if cut.y <= interval.x or cut.x >= interval.y:
						remaining.append(interval)
						continue
					if cut.x > interval.x:
						remaining.append(Vector2(interval.x,cut.x))
					if cut.y < interval.y:
						remaining.append(Vector2(cut.y,interval.y))
				intervals = remaining
			for interval: Vector2 in intervals:
				var first: Vector2 = a.lerp(b,interval.x)
				var last: Vector2 = a.lerp(b,interval.y)
				walls.append(PackedVector3Array([Vector3(first.x,height,first.y),
					Vector3(first.x,-1,first.y),Vector3(last.x,-1,last.y),Vector3(last.x,height,last.y)]))
	return {"ok":true,"tops":tops,"walls":walls,"risers":[]}
static func _interval(a: Vector2,b: Vector2,polygon: PackedVector2Array) -> Vector2:
	var low: float = 0
	var high: float = 1
	var orientation: float = signf(Union._area(polygon))
	for i: int in range(polygon.size()):
		var start: Vector2 = polygon[i]
		var delta: Vector2 = polygon[(i+1)%polygon.size()]-start
		var first: float = orientation*delta.cross(a-start)
		var change: float = orientation*delta.cross(b-a)
		if absf(change) < .000001:
			if first < 0:
				return Vector2(1,0)
		elif change > 0:
			low = maxf(low,-first/change)
		else:
			high = minf(high,-first/change)
		if low > high:
			return Vector2(1,0)
	return Vector2(low,high)

## Close only exposed cut boundaries. Offset probes distinguish a shared tread
## edge from an exterior boundary; earlier masks own coincident boundaries.
static func _cut_walls(outline: PackedVector2Array,height: float,masks: Array[PackedVector2Array],levels: Array[float]) -> Array[PackedVector3Array]:
	var walls: Array[PackedVector3Array] = []
	var boxes: Array[Rect2] = []
	for mask: PackedVector2Array in masks:
		boxes.append(Union._bounds(mask).grow(.00002))
	for index: int in range(masks.size()):
		if levels[index]>=height-.00001:
			continue
		var mask: PackedVector2Array = masks[index]
		for edge: int in range(mask.size()):
			var a: Vector2 = mask[edge]
			var b: Vector2 = mask[(edge+1)%mask.size()]
			var direction: Vector2 = (b-a).normalized()
			var outward: Vector2 = Vector2(direction.y,-direction.x)*signf(Union._area(mask))*.00001
			var allowed: Vector2 = _interval(a+outward,b+outward,outline)
			if allowed.y-allowed.x<=.000001:
				continue
			var intervals: Array[Vector2] = [allowed]
			var edge_box: Rect2 = Rect2(a,Vector2.ZERO).expand(b).grow(.00002)
			for other: int in range(masks.size()):
				if other==index or not edge_box.intersects(boxes[other]):
					continue
				var cut: Vector2 = _interval(a if other<index else a+outward,b if other<index else b+outward,masks[other])
				if cut.y-cut.x<=.000001:
					continue
				var remaining: Array[Vector2] = []
				for interval: Vector2 in intervals:
					if cut.y<=interval.x or cut.x>=interval.y:
						remaining.append(interval)
					else:
						if cut.x>interval.x:
							remaining.append(Vector2(interval.x,cut.x))
						if cut.y<interval.y:
							remaining.append(Vector2(cut.y,interval.y))
				intervals = remaining
				if intervals.is_empty():
					break
			for interval: Vector2 in intervals:
				var first: Vector2 = a.lerp(b,interval.x)
				var last: Vector2 = a.lerp(b,interval.y)
				walls.append(PackedVector3Array([Vector3(last.x,height,last.y),Vector3(last.x,levels[index],last.y),Vector3(first.x,levels[index],first.y),Vector3(first.x,height,first.y)]))
	return walls
