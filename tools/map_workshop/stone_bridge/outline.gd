extends RefCounted
## Simplify the fitted grid boundary before assembling masonry strips.
## The 2 cm tolerance is below the wall overlap and does not change the deck.
static func segments(mesh: ArrayMesh) -> Array[Dictionary]:
	var edges: Dictionary = {}
	var faces: PackedVector3Array = mesh.get_faces()
	for i: int in range(0,faces.size(),3):
		for j: int in range(3):
			var a: Vector3 = faces[i+j]
			var b: Vector3 = faces[i+(j+1)%3]
			var ka: String = _key(a)
			var kb: String = _key(b)
			var key: String = ka+"/"+kb if ka<kb else kb+"/"+ka
			if edges.has(key):
				edges[key]["count"] += 1
			else:
				edges[key] = {"a":a,"b":b,"ka":ka,"kb":kb,"count":1}
	var adjacency: Dictionary = {}
	var boundary: Array[Dictionary] = []
	for edge: Dictionary in edges.values():
		if edge["count"]!=1:
			continue
		for key: String in [edge["ka"],edge["kb"]]:
			if not adjacency.has(key):
				adjacency[key] = []
			adjacency[key].append(boundary.size())
		boundary.append(edge)
	var visited: Dictionary = {}
	var result: Array[Dictionary] = []
	for start: int in range(boundary.size()):
		if visited.has(start):
			continue
		var first: Dictionary = boundary[start]
		var points: PackedVector3Array = [first["a"],first["b"]]
		var cursor: String = first["kb"]
		visited[start] = true
		while true:
			var next: int = -1
			for candidate: int in adjacency.get(cursor,[]):
				if not visited.has(candidate):
					next = candidate
					break
			if next<0:
				break
			visited[next] = true
			var edge: Dictionary = boundary[next]
			var forwards: bool = edge["ka"]==cursor
			var next_point: Vector3 = edge["b"] if forwards else edge["a"]
			points.append(next_point)
			cursor = edge["kb"] if forwards else edge["ka"]
		var simplified: Array[Vector3] = [points[0]]
		var middle: int = points.size()/2
		_reduce(points,0,middle,simplified)
		_reduce(points,middle,points.size()-1,simplified)
		for i: int in range(simplified.size()-1):
			result.append({"a":simplified[i],"b":simplified[i+1]})
	print("STONE_BRIDGE_OUTLINE original=",boundary.size()," simplified=",result.size())
	return result

static func _reduce(points: PackedVector3Array,first: int,last: int,out: Array[Vector3]) -> void:
	if last<=first:
		return
	var a: Vector3 = points[first]
	var delta: Vector3 = points[last]-a
	var greatest: float = .02*.02
	var split: int = -1
	for i: int in range(first+1,last):
		var t: float = clampf((points[i]-a).dot(delta)/maxf(.00000001,delta.length_squared()),0,1)
		var distance: float = points[i].distance_squared_to(a+delta*t)
		if distance>greatest:
			greatest = distance
			split = i
	if split<0:
		out.append(points[last])
	else:
		_reduce(points,first,split,out)
		_reduce(points,split,last,out)

static func _key(p: Vector3) -> String:
	return "%d,%d,%d" % [roundi(p.x*10000),roundi(p.y*10000),roundi(p.z*10000)]
