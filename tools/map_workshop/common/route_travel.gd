extends RefCounted
## Distance and angular-speed bounded read-only travel. The caller owns framing and user cancellation.
var active: bool = false
var points: Array[Vector3] = []
var headings: Array[float] = []
var speed: float = 4.0
var segment: int = 0
var elapsed: float = 0
var angular_speed: float = 40.0

func begin(path: Array[Vector3], angles: Array[float], metres_per_second: float = 4.0, degrees_per_second: float = 40.0) -> bool:
	cancel()
	if path.size()<2 or path.size()!=angles.size() or not is_finite(metres_per_second) or metres_per_second<=0 or not is_finite(degrees_per_second) or degrees_per_second<=0:
		return false
	for index: int in range(path.size()):
		if not path[index].is_finite() or not is_finite(angles[index]):
			return false
	points = path.duplicate()
	headings = angles.duplicate()
	speed = metres_per_second
	angular_speed = degrees_per_second
	segment = 0
	elapsed = 0
	active = true
	return true

func advance(delta: float) -> Dictionary:
	if not active or not is_finite(delta) or delta<0:
		return {}
	elapsed += delta
	while segment<points.size()-1:
		var length: float = points[segment].distance_to(points[segment+1])
		var turn: float = absf(headings[segment+1]-headings[segment])
		var duration: float = maxf(length/speed,turn/angular_speed)
		if duration>.000001 and elapsed<duration:
			var weight: float = elapsed/duration
			return {"point":points[segment].lerp(points[segment+1],weight),
				"heading":lerpf(headings[segment],headings[segment+1],weight),"finished":false}
		elapsed -= duration
		segment += 1
	active = false
	return {"point":points[-1],"heading":headings[-1],"finished":true}

func cancel() -> void:
	active = false
