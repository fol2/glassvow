extends RefCounted
## Physical presentation heights: a wooded upland, incised river and dry passes.
## Generator coordinates retain their X/Z layout; Y tags identify upper routes.
const CELL: float = .5
var cuts: Array[Dictionary] = []
var ground_cells: Dictionary = {}
var abutments: PackedVector2Array = []

func setup(lines: Array[PackedVector3Array]) -> void:
	for upper: PackedVector3Array in lines:
		for p: Vector3 in upper:
			if p.y>.3:
				abutments.append(Vector2(upper[0].x,upper[0].z))
				abutments.append(Vector2(upper[-1].x,upper[-1].z))
				break
		for i: int in range(upper.size()-1):
			if minf(upper[i].y,upper[i+1].y)<.3:
				continue
			var a: Vector2 = Vector2(upper[i].x,upper[i].z)
			var b: Vector2 = Vector2(upper[i+1].x,upper[i+1].z)
			for lower: PackedVector3Array in lines:
				for j: int in range(lower.size()-1):
					if maxf(lower[j].y,lower[j+1].y)>.01:
						continue
					var c: Vector2 = Vector2(lower[j].x,lower[j].z)
					var d: Vector2 = Vector2(lower[j+1].x,lower[j+1].z)
					var intersection: Variant = Geometry2D.segment_intersects_segment(a,b,c,d)
					if intersection is Vector2:
						cuts.append({"at":intersection,"direction":(d-c).normalized()})

	_grade_roads(lines)

func upland(x: float, z: float) -> float:
	# Long, calm ridges carry the roads too. No global flat route plane.
	var h: float = 1.0+1.0*sin(x*.061+z*.035)+.60*cos(z*.112-x*.023)
	h += 1.45*exp(-pow((x+28)/11,2)-pow((z+10)/13,2))
	h += .75*exp(-pow((x-24)/10,2)-pow((z-18)/9,2))
	# A broad level saddle supports the already-approved gateway.
	var terrace: float = 1.0-smoothstep(3.1,6.5,Vector2(x,z).distance_to(Vector2(-19.565,14.756)))
	return lerpf(h,.32,terrace)

func cut_depth(x: float, z: float) -> float:
	var depth: float = 0
	for cut: Dictionary in cuts:
		var at: Vector2 = cut["at"]
		var direction: Vector2 = cut["direction"]
		var delta: Vector2 = Vector2(x,z)-at
		var along: float = absf(delta.dot(direction))
		var across: float = absf(delta.cross(direction))
		# A generous flat-bottomed pass, with graded approaches and shoulders.
		depth = maxf(depth,3.05*(1.0-smoothstep(2.0,11.0,along))*(1.0-smoothstep(1.1,4.5,across)))
	for at: Vector2 in abutments:
		depth *= smoothstep(1.6,3.1,Vector2(x,z).distance_to(at))
	return depth

func natural_height(x: float, z: float) -> float:
	var h: float = upland(x,z)-cut_depth(x,z)
	var river: float = absf(x+5.0-sin(z*.12)*2.2)
	# The steep bank sits back from the water; a dry ledge reads below the deck.
	var ledge: float = lerpf(-4.15,-2.65,smoothstep(1.15,1.95,river))
	return lerpf(ledge,h,smoothstep(2.05,3.8,river))

func height(x: float, z: float) -> float:
	var h: float = natural_height(x,z)
	if absf(x+5.0-sin(z*.12)*2.2)<3.8:
		return h
	var at: Vector2 = Vector2(x,z)
	var best: float = 2.2
	var reference: float = h
	var candidates: Array = ground_cells.get(Vector2i(floori(x/4),floori(z/4)),[])
	for segment: Array in candidates:
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(at,a,b)
		var distance: float = at.distance_to(nearest)
		if distance<best:
			best = distance
			var ha: float = segment[2]
			var hb: float = segment[3]
			var t: float = clampf((nearest-a).dot(b-a)/maxf(.000001,a.distance_squared_to(b)),0,1)
			reference = lerpf(ha,hb,t)
	# Shape the crossfall locally, while following each road's real elevation.
	h = lerpf(h,reference,1.0-smoothstep(.65,2.2,best))
	return h

func _grade_roads(lines: Array[PackedVector3Array]) -> void:
	var points: PackedVector3Array = []
	var lookup: Dictionary = {}
	var links: Array[Array] = []
	var pieces: Array[Vector2i] = []
	for line: PackedVector3Array in lines:
		var upper: bool = false
		for p: Vector3 in line:
			upper = upper or p.y>.015
		if upper:
			continue
		var previous: int = -1
		for i: int in range(line.size()-1):
			var count: int = maxi(1,ceili(line[i].distance_to(line[i+1])/.4))
			for step: int in range(count+1):
				var p: Vector3 = line[i].lerp(line[i+1],float(step)/count)
				var key: Vector2i = Vector2i(roundi(p.x*10000),roundi(p.z*10000))
				var index: int = lookup.get(key,-1)
				if index<0:
					index = points.size()
					lookup[key] = index
					p.y = upland(p.x,p.z)
					for cut: Dictionary in cuts:
						var centre: Vector2 = cut["at"]
						var distance: float = centre.distance_to(Vector2(p.x,p.z))
						if distance<1.2:
							p.y = minf(p.y,upland(centre.x,centre.y)-3.05+distance*.08)
					points.append(p)
					links.append([])
				if previous>=0 and previous!=index:
					links[previous].append(index)
					links[index].append(previous)
					pieces.append(Vector2i(previous,index))
				previous = index
	# Propagate excavation along the real road graph. Every adjacent centreline
	# pair has at most a 0.42 rise/run, so nearby branches get a usable approach.
	var queue: Array[int] = []
	for i: int in range(points.size()):
		queue.append(i)
	var cursor: int = 0
	while cursor<queue.size():
		var index: int = queue[cursor]
		cursor += 1
		for neighbour: int in links[index]:
			var a: Vector3 = points[index]
			var b: Vector3 = points[neighbour]
			var limit: float = a.y+Vector2(a.x-b.x,a.z-b.z).length()*.42
			if b.y>limit+.0001:
				points[neighbour].y = limit
				queue.append(neighbour)
	# Bridgehead heights are fixed by the upper route. Propagate their approach
	# grade through connected earth roads, rather than raising a radial mound.
	queue.clear()
	cursor = 0
	var lower_bound: PackedFloat32Array = []
	lower_bound.resize(points.size())
	lower_bound.fill(-10000)
	for pad: Vector2 in abutments:
		var key: Vector2i = Vector2i(roundi(pad.x*10000),roundi(pad.y*10000))
		var index: int = lookup.get(key,-1)
		if index>=0:
			lower_bound[index] = upland(pad.x,pad.y)
			queue.append(index)
	while cursor<queue.size():
		var index: int = queue[cursor]
		cursor += 1
		for neighbour: int in links[index]:
			var a: Vector3 = points[index]
			var b: Vector3 = points[neighbour]
			var limit: float = lower_bound[index]-Vector2(a.x-b.x,a.z-b.z).length()*.32
			if lower_bound[neighbour]<limit-.0001:
				lower_bound[neighbour] = limit
				queue.append(neighbour)
	for i: int in range(points.size()):
		points[i].y = maxf(points[i].y,lower_bound[i])
	ground_cells.clear()
	for piece: Vector2i in pieces:
		var a: Vector3 = points[piece.x]
		var b: Vector3 = points[piece.y]
		var start: Vector2 = Vector2(a.x,a.z)
		var end: Vector2 = Vector2(b.x,b.z)
		var low: Vector2 = (start.min(end)-Vector2.ONE*2.2)/4
		var high: Vector2 = (start.max(end)+Vector2.ONE*2.2)/4
		for x: int in range(floori(low.x),floori(high.x)+1):
			for z: int in range(floori(low.y),floori(high.y)+1):
				var key: Vector2i = Vector2i(x,z)
				if not ground_cells.has(key):
					ground_cells[key] = []
				ground_cells[key].append([start,end,a.y,b.y])
