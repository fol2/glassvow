extends RefCounted
## Fit complete sustained inclines before meshing their structural deck.
## End heights and route footprints remain fixed; grade becomes uniform.
var cells: Dictionary = {}
var flight_count: int = 0
const CELL: float = 4.0

func prepare(field: RefCounted,settings: Dictionary) -> void:
	var groups: Dictionary = {}
	for span: Dictionary in field.spans:
		var key: String = span["edge"]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(span)
	var openings: Array = settings.get("openings",[])
	for spans: Array in groups.values():
		var points: Array[Vector3] = []
		var previous: Vector3 = Vector3.INF
		var direction: float = 0
		var steep: bool = false
		for span: Dictionary in spans:
			var point: Vector3 = span["b"]
			var query: Dictionary = field.field(Vector2(point.x,point.z))
			point.y = query["height"]
			var excluded: bool = query.get("delegated",false)
			for opening: Vector3 in openings:
				excluded = excluded or Vector2(point.x-opening.x,point.z-opening.z).length()<1.7
			var delta: Vector3 = point-previous if previous.is_finite() else Vector3.ZERO
			var grade: float = absf(delta.y)/maxf(.001,Vector2(delta.x,delta.z).length())
			var sign_value: float = signf(delta.y)
			if excluded or grade<.09 or grade>.52 or (direction!=0 and direction!=sign_value):
				if steep:
					_store(points,str(spans[0]["edge"]))
				points = []
				steep = false
				direction = 0
			elif previous.is_finite():
				if points.is_empty():
					points.append(previous)
				points.append(point)
				direction = sign_value
				var trigger: float = settings.get("stair_trigger_grade",.22)
				steep = steep or grade>=trigger
			previous = Vector3.INF if excluded else point
		if steep:
			_store(points,str(spans[0]["edge"]))
	print("STONE_BRIDGE_GRADED_FLIGHTS ",flight_count)

func _store(points: Array[Vector3],owner: String) -> void:
	if points.size()<3 or absf(points[-1].y-points[0].y)<.45:
		return
	var lengths: Array[float] = [0.0]
	for i: int in range(1,points.size()):
		lengths.append(lengths[-1]+Vector2(points[i].x-points[i-1].x,points[i].z-points[i-1].z).length())
	var total: float = lengths[-1]
	# A broad turning landing is retained rather than forcing a winding stair.
	for i: int in range(1,points.size()-1):
		var before: Vector3 = (points[i]-points[i-1]).normalized()
		var after: Vector3 = (points[i+1]-points[i]).normalized()
		if before.dot(after)<.97:
			return
	for i: int in range(points.size()-1):
		var a: Vector2 = Vector2(points[i].x,points[i].z)
		var b: Vector2 = Vector2(points[i+1].x,points[i+1].z)
		var segment: Dictionary = {"edge":owner,"a":a,"b":b,
			"low":lerpf(points[0].y,points[-1].y,lengths[i]/total),
			"high":lerpf(points[0].y,points[-1].y,lengths[i+1]/total),
			"start":Vector2(points[0].x,points[0].z),"finish":Vector2(points[-1].x,points[-1].z),
			"start_dir":Vector2(points[1].x-points[0].x,points[1].z-points[0].z),
			"end_dir":Vector2(points[-1].x-points[-2].x,points[-1].z-points[-2].z)}
		var low: Vector2 = a.min(b)-Vector2.ONE*1.5
		var high: Vector2 = a.max(b)+Vector2.ONE*1.5
		for x: int in range(floori(low.x/CELL),floori(high.x/CELL)+1):
			for z: int in range(floori(low.y/CELL),floori(high.y/CELL)+1):
				var key: Vector2i = Vector2i(x,z)
				if not cells.has(key):
					cells[key] = []
				cells[key].append(segment)
	flight_count += 1

func height(at: Vector2,original: float,owner: String) -> float:
	var fitted: Vector2 = sample(at,owner)
	return lerpf(original,fitted.x,fitted.y)

func sample(at: Vector2,owner: String) -> Vector2:
	var nearest: float = 1.5*1.5
	var result: Vector2 = Vector2.ZERO
	for segment: Dictionary in cells.get(Vector2i(floori(at.x/CELL),floori(at.y/CELL)),[]):
		if str(segment["edge"])!=owner: continue
		var a: Vector2 = segment["a"]
		var delta: Vector2 = segment["b"]-a
		var t: float = (at-a).dot(delta)/maxf(.000001,delta.length_squared())
		var start: Vector2 = segment["start"]
		var finish: Vector2 = segment["finish"]
		var start_dir: Vector2 = segment["start_dir"]
		var end_dir: Vector2 = segment["end_dir"]
		if (at-start).dot(start_dir)<0 or (at-finish).dot(end_dir)>0:
			continue
		t = clampf(t,0,1)
		var distance: float = at.distance_squared_to(a+delta*t)
		if distance<nearest:
			nearest = distance
			var low: float = segment["low"]
			var high: float = segment["high"]
			var shoulder: float = smoothstep(0,.5,(at-start).dot(start_dir.normalized()))*smoothstep(0,.5,(finish-at).dot(end_dir.normalized()))
			result = Vector2(lerpf(low,high,t),shoulder)
	return result
