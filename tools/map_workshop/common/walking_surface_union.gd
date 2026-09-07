extends RefCounted
## Remove coplanar overlap without changing stairs or separate passage levels.
## Convex subtraction preserves holes as separate pieces; no filled courtyards.
const EPS: float = .000001
static func resolve(plans: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {"ok":true,"tops":[],"risers":[],"walls":[]}
	var accepted: Dictionary = {}
	var removed_area: float = 0.0
	for plan: Dictionary in plans:
		if plan.get("ok") != true:
			return {"ok":false,"reason":"unresolved source surface"}
		for key: String in ["risers","walls"]:
			result[key].append_array(plan[key])
		for face: PackedVector3Array in plan["tops"]:
			var height: float = face[0].y
			for p: Vector3 in face:
				if absf(p.y-height) > EPS:
					return {"ok":false,"reason":"walking union requires level treads"}
			var bucket: int = roundi(height/EPS)
			if not accepted.has(bucket):
				accepted[bucket] = []
			# Source faces are convex triangles/quads; split before subtraction.
			for index: int in range(1,face.size()-1):
				var subject: PackedVector2Array = [Vector2(face[0].x,face[0].z),
					Vector2(face[index].x,face[index].z),Vector2(face[index+1].x,face[index+1].z)]
				var pieces: Array[PackedVector2Array] = [subject]
				var original_area: float = absf(_area(subject))
				var prior: Array = accepted[bucket]
				for clip: PackedVector2Array in prior:
					var remaining: Array[PackedVector2Array] = []
					for piece: PackedVector2Array in pieces:
						if not _bounds(piece).intersects(_bounds(clip)):
							remaining.append(piece)
						else:
							remaining.append_array(_subtract(piece,clip))
					pieces = remaining
					if pieces.is_empty():
						break
				var kept_area: float = 0.0
				for piece: PackedVector2Array in pieces:
					kept_area += absf(_area(piece))
					for triangle: int in range(1,piece.size()-1):
						var top: PackedVector3Array = []
						for point: Vector2 in [piece[0],piece[triangle],piece[triangle+1]]:
							top.append(Vector3(point.x,height,point.y))
						result["tops"].append(top)
				removed_area += maxf(0,original_area-kept_area)
				# Store original triangle: the union of previous coverage is unchanged.
				accepted[bucket].append(subject)
	result["removed_overlap_m2"] = removed_area
	return result
static func _subtract(subject: PackedVector2Array, clip: PackedVector2Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var inside: PackedVector2Array = subject
	var orientation: float = signf(_area(clip))
	for i: int in range(clip.size()):
		var a: Vector2 = clip[i]
		var b: Vector2 = clip[(i+1)%clip.size()]
		var outside: PackedVector2Array = _half(inside,a,b,-orientation)
		if outside.size() >= 3 and absf(_area(outside)) > EPS:
			out.append(outside)
		inside = _half(inside,a,b,orientation)
		if inside.size() < 3:
			break
	return out
static func _half(poly: PackedVector2Array,a: Vector2,b: Vector2,side: float) -> PackedVector2Array:
	var out: PackedVector2Array = []
	if poly.is_empty():
		return out
	var previous: Vector2 = poly[-1]
	var prior: float = side*(b-a).cross(previous-a)
	for current: Vector2 in poly:
		var distance: float = side*(b-a).cross(current-a)
		if (distance >= 0) != (prior >= 0):
			out.append(previous.lerp(current,prior/(prior-distance)))
		if distance >= 0:
			out.append(current)
		previous = current
		prior = distance
	return out
static func _area(poly: PackedVector2Array) -> float:
	var area: float = 0.0
	for i: int in range(poly.size()):
		area += poly[i].cross(poly[(i+1)%poly.size()])
	return area*.5
static func _bounds(poly: PackedVector2Array) -> Rect2:
	var result: Rect2 = Rect2(poly[0],Vector2.ZERO)
	for point: Vector2 in poly:
		result = result.expand(point)
	return result
