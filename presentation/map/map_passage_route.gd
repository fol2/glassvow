extends RefCounted
## Construct passage approaches as real flights with level corners.
const Terrace = preload("res://presentation/map/map_terrace_route.gd")
const F = preload("res://domain/map_layout/map_layout_canonical.gd")

static func resolve(edge: Dictionary, spans: Array, clearance: float,
		grade: float, landing: float) -> Dictionary:
	var line: PackedVector3Array = []
	var arcs: Array[float] = [0.0]
	for value: Array in edge["centerline"]:
		var point: Vector3 = Vector3(F.float_value(value[0]),F.float_value(value[1]),F.float_value(value[2]))
		if not line.is_empty():
			arcs.append(arcs[-1]+Vector2(point.x-line[-1].x,point.z-line[-1].z).length())
		line.append(point)
	var baseline: float = line[0].y
	var width: float = F.float_value(edge["corridor_width"])
	var out: PackedVector3Array = []
	var cursor: float = 0.0
	for index: int in range(spans.size()):
		var span: Dictionary = spans[index]
		var start: float = F.float_value(span["deck_start_m"])
		var end: float = F.float_value(span["deck_end_m"])
		var next_start: float = arcs[-1]
		if index+1 < spans.size():
			next_start = (end+F.float_value(spans[index+1]["deck_start_m"]))*.5
		var up: Dictionary = Terrace.resolve(_slice(line,arcs,cursor,start),
			baseline,baseline+clearance,width,grade,landing)
		var down: Dictionary = Terrace.resolve(_slice(line,arcs,end,next_start),
			baseline+clearance,baseline,width,grade,landing)
		if up.get("ok") != true or down.get("ok") != true:
			return {"ok":false,"reason":"passage approach cannot fit level turns and flights",
				"span_index":index,"up":up,"down":down}
		var up_line: PackedVector3Array = up["line"]
		_append(out,up_line)
		var deck: PackedVector3Array = _slice(line,arcs,start,end)
		for i: int in range(deck.size()):
			deck[i].y = baseline+clearance
		_append(out,deck)
		var down_line: PackedVector3Array = down["line"]
		_append(out,down_line)
		cursor = next_start
	var points: Array = []
	for point: Vector3 in out:
		points.append([point.x,point.y,point.z])
	return {"ok":true,"line":points}

static func _slice(line: PackedVector3Array, arcs: Array[float],
		start: float, end: float) -> PackedVector3Array:
	var out: PackedVector3Array = [_point(line,arcs,start)]
	for i: int in range(line.size()):
		if arcs[i] > start+.00001 and arcs[i] < end-.00001:
			out.append(line[i])
	out.append(_point(line,arcs,end))
	return out

static func _point(line: PackedVector3Array, arcs: Array[float], distance: float) -> Vector3:
	for i: int in range(1,line.size()):
		if distance <= arcs[i]:
			return line[i-1].lerp(line[i],(distance-arcs[i-1])/maxf(.00001,arcs[i]-arcs[i-1]))
	return line[-1]

static func _append(out: PackedVector3Array, part: PackedVector3Array) -> void:
	for point: Vector3 in part:
		if out.is_empty() or point.distance_to(out[-1]) > .00001:
			out.append(point)
