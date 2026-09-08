extends RefCounted
## One structural section owns the walking surfaces; no ramp underlay.
## Turns belong to adjoining level landings, never bent or overlapping treads.
const MAX_RISER: float = .17
const MIN_TREAD: float = .28

static func resolve(start: Vector3, end: Vector3, width: float,
		foundation: float, landing: float) -> Dictionary:
	return _resolve(start, end, width, foundation, landing, false)

## The caller supplies the adjoining level platforms and owns their walking faces.
static func between_landings(start: Vector3, end: Vector3, width: float,
		foundation: float) -> Dictionary:
	return _resolve(start, end, width, foundation, 0.0, true)

static func _resolve(start: Vector3, end: Vector3, width: float,
		foundation: float, landing: float, external: bool) -> Dictionary:
	if not start.is_finite() or not end.is_finite() or not is_finite(width) or \
			not is_finite(foundation) or not is_finite(landing):
		return {"ok": false, "reason": "non-finite flight input"}
	if width <= 0 or (landing < MIN_TREAD and not external):
		return {"ok": false, "reason": "flight width and complete landings required"}
	if start.y > end.y:
		var swap: Vector3 = start
		start = end
		end = swap
	var rise: float = end.y - start.y
	var horizontal: Vector3 = Vector3(end.x - start.x, 0, end.z - start.z)
	var length: float = horizontal.length()
	if rise <= 0 or foundation >= start.y or length <= 2.0 * landing:
		return {"ok": false, "reason": "flight needs positive rise, run and structural depth"}
	var count: int = ceili(rise / MAX_RISER)
	var run: float = (length - 2.0 * landing) / count
	if run < MIN_TREAD:
		return {"ok": false, "reason": "insufficient run for safe treads"}
	var direction: Vector3 = horizontal / length
	var side: Vector3 = direction.cross(Vector3.UP) * width * .5
	var riser: float = rise / count
	var walking: Array[Dictionary] = []
	var risers: Array[PackedVector3Array] = []
	var walls: Array[PackedVector3Array] = []
	var surfaces: Array[PackedVector3Array] = []
	var cursor: Vector3 = start
	var first: Vector3 = start + direction * landing
	if not external:
		_add_strip(walking, surfaces, walls, start, first, side, foundation, "landing")
	cursor = first
	for index: int in range(count):
		var level: float = start.y + riser * (index + 1)
		var next_start: Vector3 = Vector3(cursor.x, level, cursor.z)
		var next_end: Vector3 = start + direction * (landing + run * (index + 1))
		next_end.y = level
		risers.append(PackedVector3Array([cursor + side, cursor - side,
			next_start - side, next_start + side]))
		_add_strip(walking, surfaces, walls, next_start, next_end, side, foundation, "tread")
		cursor = next_end
	# Use the caller's exact endpoint height at both final contacts.
	cursor.y = end.y
	if not external:
		_add_strip(walking, surfaces, walls, cursor, end, side, foundation, "landing")
	for endpoint: Vector3 in [start, end]:
		var a: Vector3 = endpoint - side
		var b: Vector3 = endpoint + side
		var cap: PackedVector3Array = PackedVector3Array([a, b, Vector3(b.x, foundation, b.z),
			Vector3(a.x, foundation, a.z)])
		if endpoint == end:
			cap.reverse()
		walls.append(cap)
	return {"ok": true, "walking": walking, "tops": surfaces, "risers": risers,
		"walls": walls, "riser_m": riser, "tread_m": run, "width_m": width,
		"foundation_m": foundation}

static func _add_strip(walking: Array[Dictionary], surfaces: Array[PackedVector3Array],
		walls: Array[PackedVector3Array], start: Vector3, end: Vector3,
		side: Vector3, foundation: float, kind: String) -> void:
	walking.append({"start": start, "end": end, "kind": kind})
	surfaces.append(PackedVector3Array([start - side, end - side, end + side, start + side]))
	for sign_value: float in [-1.0, 1.0]:
		var a: Vector3 = start + side * sign_value
		var b: Vector3 = end + side * sign_value
		var bottom_a: Vector3 = Vector3(a.x, foundation, a.z)
		var bottom_b: Vector3 = Vector3(b.x, foundation, b.z)
		walls.append(PackedVector3Array([a, bottom_a, bottom_b, b]) if sign_value < 0 \
			else PackedVector3Array([b, bottom_b, bottom_a, a]))
