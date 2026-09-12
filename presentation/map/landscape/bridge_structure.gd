extends RefCounted
## Arch soffits join the same clipped mesh as the deck, including its junctions.
## This leaves real openings without overlapping internal walls at shared nodes.
static func profile(parent: Node3D, points: PackedVector3Array, weights: PackedFloat32Array) -> PackedFloat32Array:
	var bottom: PackedFloat32Array = []
	for p: Vector3 in points:
		bottom.append(p.y-.30)
	var first: int = -1
	for i: int in range(points.size()):
		var p: Vector3 = points[i]
		var ground: float = parent.surface_height(p.x,p.z)
		var gap: bool = p.y-ground>.30 and weights[i]>.9
		if gap and first<0:
			first = maxi(0,i-1)
		if first>=0 and (not gap or i==points.size()-1):
			if points[first].distance_to(points[i])>1.2:
				bottom = _arch(parent,points,first,i,bottom)
			first = -1
	return bottom

static func _arch(parent: Node3D, points: PackedVector3Array, first: int, last: int, bottom: PackedFloat32Array) -> PackedFloat32Array:
	var lengths: PackedFloat32Array = [0]
	for i: int in range(first+1,last+1):
		lengths.append(lengths[-1]+points[i].distance_to(points[i-1]))
	var total: float = lengths[-1]
	for i: int in range(first,last+1):
		var p: Vector3 = points[i]
		var t: float = lengths[i-first]/total
		var ground: float = parent.surface_height(p.x,p.z)
		var spring: float = pow(absf(t*2-1),2.5)
		bottom[i] = lerpf(p.y-.34,ground-.15,spring)
	return bottom
