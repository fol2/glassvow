extends RefCounted
## Detect whole monotonic inclines, then divide their height into equal risers.
## Contour stations follow the fitted road; no tread is placed independently.
const M = preload("res://tools/map_workshop/mesh_tools.gd")
var count: int = 0
var maximum_riser: float = 0
var flights: int = 0

func build(parent: Node3D,field: RefCounted,material: Material,
		settings: Dictionary = {}) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
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
			var run: float = Vector2(delta.x,delta.z).length()
			var grade: float = absf(delta.y)/maxf(run,.001)
			var sign_value: float = signf(delta.y)
			# Hysteresis keeps the easing shoulders of a flight together.
			if excluded or grade<.09 or grade>.52 or (direction!=0 and sign_value!=direction):
				if steep:
					_flight(surface,points,field,settings)
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
			_flight(surface,points,field,settings)
	if count==0:
		return null
	var mesh: ArrayMesh = M.finish(surface)
	M.node(parent,mesh,material,"StoneBridgeStairTreads")
	print("STONE_BRIDGE_FLIGHTS flights=",flights," treads=",count," maximum_rise=",maximum_riser)
	return mesh

func _flight(surface: SurfaceTool,source: Array[Vector3],field: RefCounted,settings: Dictionary) -> void:
	if source.size()<3:
		return
	var points: Array[Vector3] = source.duplicate()
	if points[0].y>points[-1].y:
		points.reverse()
	var rise: float = points[-1].y-points[0].y
	if rise<.45:
		return
	var maximum: float = settings.get("maximum_riser",.17)
	var steps: int = maxi(3,ceili(rise/maximum))
	var riser: float = rise/steps
	var cuts: Array[Vector3] = [points[0]]
	var cursor: int = 0
	for i: int in range(1,steps+1):
		var level: float = points[0].y+riser*i
		while cursor<points.size()-2 and points[cursor+1].y<level:
			cursor += 1
		var a: Vector3 = points[cursor]
		var b: Vector3 = points[cursor+1]
		cuts.append(a.lerp(b,clampf((level-a.y)/maxf(.00001,b.y-a.y),0,1)))
	# Reject the complete flight if any tread is too short or leaves the deck.
	var width: float = settings.get("tread_width",1.60)
	for i: int in range(steps):
		var a: Vector3 = cuts[i]
		var b: Vector3 = cuts[i+1]
		var delta: Vector3 = Vector3(b.x-a.x,0,b.z-a.z)
		if delta.length()<.28:
			return
		var side: Vector3 = delta.normalized().cross(Vector3.UP)
		for point: Vector3 in [a,(a+b)*.5,b]:
			for sign_value: int in [-1,1]:
				var edge: Vector3 = point+side*sign_value*width*.5
				var distance: float = field.field(Vector2(edge.x,edge.z))["distance"]
				if distance>-.015:
					return
	for i: int in range(steps):
		var a: Vector3 = cuts[i]
		var b: Vector3 = cuts[i+1]
		var before: Vector3 = cuts[maxi(0,i-1)]
		var after: Vector3 = cuts[mini(steps,i+2)]
		var side_a: Vector3 = Vector3(b.z-before.z,0,before.x-b.x).normalized()*width*.5
		var side_b: Vector3 = Vector3(after.z-a.z,0,a.x-after.x).normalized()*width*.5
		var top: float = b.y+.018
		var bottom: float = a.y-.06
		var p: Array[Vector3] = [a-side_a,a+side_a,b+side_b,b-side_b]
		for j: int in range(4):
			p[j].y = top
		# Horizontal tops and closed vertical risers; shared cross-sections
		# avoid gaps on bends. The fitted masonry remains the structural fill.
		_quad(surface,p[0],p[1],p[2],p[3])
		for j: int in range(4):
			var next: int = (j+1)%4
			var low_a: Vector3 = p[j]
			var low_b: Vector3 = p[next]
			low_a.y = bottom
			low_b.y = bottom
			_quad(surface,p[next],p[j],low_a,low_b)
		count += 1
	maximum_riser = maxf(maximum_riser,riser)
	flights += 1

func _quad(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	M.triangle(surface,a,b,c)
	M.triangle(surface,a,c,d)
