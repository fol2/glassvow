extends RefCounted
## Bounded landscape reserves carved from court paving and its solid foundation.
const Occupancy = preload("res://tools/map_workshop/common/architectural_occupancy.gd")
const F = preload("res://domain/map_layout/map_layout_canonical.gd")

static func select(regions: Array[Dictionary], routes: Dictionary) -> Array[Rect2]:
	var openings: Array[Rect2] = []
	for index: int in range(regions.size()-1):
		var region: Dictionary = regions[index]
		var bounds: Rect2 = Rect2(Vector2(F.float_value(region["west"])+14,F.float_value(region["near"])+12),
			Vector2(F.float_value(region["east"])-F.float_value(region["west"])-28,F.float_value(region["far"])-F.float_value(region["near"])-24))
		var count: int = 0
		for size: Vector2 in [Vector2(18,12),Vector2(12,8),Vector2(8,6)]:
			var x: float = bounds.position.x
			while x+size.x <= bounds.end.x and count < 2:
				var z: float = bounds.position.y
				while z+size.y <= bounds.end.y and count < 2:
					var candidate: Rect2 = Rect2(Vector2(x,z),size)
					var clear: bool = true
					for existing: Rect2 in openings:
						if existing.grow(6).intersects(candidate):
							clear = false
					var box: AABB = AABB(Vector3(x,-4,z),Vector3(size.x,10,size.y))
					if clear and Occupancy.conflicts(box,routes,2.0).is_empty():
						openings.append(candidate)
						count += 1
					z += 4
				x += 4
	return openings

static func subtract(rectangle: Rect2, openings: Array[Rect2]) -> Array[Rect2]:
	var pieces: Array[Rect2] = [rectangle]
	for opening: Rect2 in openings:
		var next: Array[Rect2] = []
		for piece: Rect2 in pieces:
			var cut: Rect2 = piece.intersection(opening)
			if not cut.has_area():
				next.append(piece)
				continue
			for remainder: Rect2 in [Rect2(piece.position,Vector2(cut.position.x-piece.position.x,piece.size.y)),
				Rect2(Vector2(cut.end.x,piece.position.y),Vector2(piece.end.x-cut.end.x,piece.size.y)),
				Rect2(Vector2(cut.position.x,piece.position.y),Vector2(cut.size.x,cut.position.y-piece.position.y)),
				Rect2(Vector2(cut.position.x,cut.end.y),Vector2(cut.size.x,piece.end.y-cut.end.y))]:
				if remainder.has_area():
					next.append(remainder)
		pieces = next
	return pieces

static func mask(opening: Rect2, height: float) -> Dictionary:
	var p: Vector2 = opening.position
	var e: Vector2 = opening.end
	return {"ok":true,"tops":[PackedVector3Array([Vector3(p.x,height,p.y),Vector3(e.x,height,p.y),Vector3(e.x,height,e.y),Vector3(p.x,height,e.y)])]}
