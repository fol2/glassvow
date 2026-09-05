extends Camera3D
## Camera-only prototype; does not replace the production camera contract.
const PITCH: float = 55.0
var pitch: float = PITCH
var heading: float = 0.0
var centre: Vector2 = Vector2.ZERO
var goal_centre: Vector2 = Vector2.ZERO
var goal_size: float = 16.0
var moving: bool = false

func _init() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	rotation_degrees.x = -pitch
	far = 180.0
	size = 16.0
	current = true

func frame(points: PackedVector3Array, stage: Vector2, whole: bool, immediate: bool = false) -> void:
	if points.is_empty():
		return
	var minp: Vector2 = Vector2(INF, INF)
	var maxp: Vector2 = Vector2(-INF, -INF)
	var sine: float = sin(deg_to_rad(pitch))
	for p: Vector3 in points:
		var horizontal: Vector2 = Vector2(p.x,p.z)
		var q: Vector2 = Vector2(horizontal.dot(_right()), horizontal.dot(_forward()) * sine - p.y * cos(deg_to_rad(pitch)))
		minp = minp.min(q)
		maxp = maxp.max(q)
	var span: Vector2 = maxp - minp
	goal_size = maxf(12.0, maxf(span.x * stage.y / maxf(100, stage.x - 100), span.y * stage.y / maxf(100, stage.y - 200)))
	if whole:
		goal_size += 4.0
	var projected: Vector2 = (minp + maxp) * 0.5
	if not whole:
		var lead: float = points[0].x + 0.167 * stage.x * goal_size / stage.y
		var half: float = (stage.x * 0.5 - 42) * goal_size / stage.y
		projected.x = clampf(lead, maxp.x - half, minp.x + half)
	goal_centre = _right()*projected.x + _forward()*(projected.y/sine)
	if immediate:
		centre = goal_centre
		size = goal_size
		_pose()

func pan_pixels(delta: Vector2, stage_height: float) -> void:
	var step: float = size / maxf(1, stage_height)
	goal_centre -= _right()*delta.x*step + _forward()*delta.y*step/sin(deg_to_rad(pitch))
	goal_centre = goal_centre.clamp(Vector2(-50, -30), Vector2(50, 30))
	centre = goal_centre
	_pose()

func zoom_by(factor: float) -> void:
	goal_size = clampf(goal_size * factor, 10, 85)

func _process(delta: float) -> void:
	var rate: float = 1 - exp(-delta * 12)
	centre = centre.lerp(goal_centre, rate)
	size = lerpf(size, goal_size, rate)
	moving = centre.distance_to(goal_centre) > 0.003 or absf(size - goal_size) > 0.003
	_pose()

func _pose() -> void:
	rotation_degrees = Vector3(-pitch,heading,0)
	var horizontal: Vector2 = centre + _forward()*36.0/tan(deg_to_rad(pitch))
	position = Vector3(horizontal.x,36.0,horizontal.y)

func _forward() -> Vector2:
	return Vector2(sin(deg_to_rad(heading)),cos(deg_to_rad(heading)))

func _right() -> Vector2:
	return Vector2(cos(deg_to_rad(heading)),-sin(deg_to_rad(heading)))
