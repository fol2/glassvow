extends RefCounted
## Keep the generated road, with grounded local turns around physical waystones.
const CLEARANCE: float = .85

static func around_stones(terrain: Node3D, route: PackedVector3Array) -> PackedVector3Array:
	if route.size()<2:
		return route
	var first: Vector3 = route[0]
	var last: Vector3 = route[-1]
	var middle: PackedVector3Array = []
	for point: Vector3 in route:
		if _flat(point-first).length()>=CLEARANCE and _flat(point-last).length()>=CLEARANCE:
			middle.append(point)
	if middle.is_empty():
		push_error("Generated edge has insufficient space between waystones")
		return []
	var result: PackedVector3Array = _arc(terrain,first,Vector2(CLEARANCE,0),_flat(middle[0]-first))
	result.append_array(middle)
	result.append_array(_arc(terrain,last,_flat(middle[-1]-last),Vector2(CLEARANCE,0)))
	return result

static func _arc(terrain: Node3D, centre: Vector3, from: Vector2, to: Vector2) -> PackedVector3Array:
	var result: PackedVector3Array = []
	var start: float = from.angle()
	var turn: float = wrapf(to.angle()-start,-PI,PI)
	var count: int = maxi(2,ceili(absf(turn)/.075))
	for step: int in range(count+1):
		var t: float = float(step)/count
		var direction: Vector2 = Vector2.from_angle(start+turn*t)
		var p: Vector3 = centre+Vector3(direction.x,0,direction.y)*lerpf(from.length(),to.length(),t)
		# Node anchors are ground-level topology; present chooses their actual
		# bank landing where the river or a bridge approach crosses them.
		var grounded: Vector3 = terrain.present(Vector3(p.x,0,p.z))
		result.append(grounded)
	return result

static func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x,point.z)
