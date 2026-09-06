extends SceneTree
## Geometry-level checks on the complete generated flight, not its counters.
const Stairs = preload("res://tools/map_workshop/stone_bridge/stairs.gd")
class Ramp extends RefCounted:
	var spans: Array[Dictionary] = []
	var slope: float
	var curvature: float
	var fitted: RefCounted
	func _init(value: float,bend: float = 0) -> void:
		slope = value
		curvature = bend
		for i: int in range(80):
			var x: float = i*.125
			spans.append({"edge":"test","a":Vector3(x,x*slope,0),"b":Vector3(x+.125,(x+.125)*slope,0)})
	func field(at: Vector2) -> Dictionary:
		var height: float = at.x*slope+curvature*at.x*at.x
		if fitted!=null:
			height = fitted.height(at,height)
		return {"height":height,"distance":absf(at.y)-1.0}

func _initialize() -> void:
	var parent: Node3D = Node3D.new()
	root.add_child(parent)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var gentle: ArrayMesh = Stairs.new().build(parent,Ramp.new(.08),material)
	assert(gentle==null,"A gentle slope must remain a paved ramp")
	for ramp: Ramp in [Ramp.new(.3),Ramp.new(-.3),Ramp.new(.18,.01)]:
		if ramp.curvature!=0:
			var grading: RefCounted = preload("res://tools/map_workshop/stone_bridge/flight_grade.gd").new()
			grading.prepare(ramp,{})
			ramp.fitted = grading
			var top_height: float = grading.height(Vector2(10,0),2.8)
			assert(absf(top_height-2.8)<.00001,"Top landing height must remain fixed")
			assert(grading.height(Vector2(11,0),3.19)==3.19,"Grading must not extend beyond a flight")
		var mesh: ArrayMesh = Stairs.new().build(parent,ramp,material)
		assert(mesh!=null,"Both ascending and descending sustained inclines need complete flights")
		var heights: Array[float] = []
		var depths: Array[float] = []
		var faces: PackedVector3Array = mesh.get_faces()
		for i: int in range(0,faces.size(),3):
			var a: Vector3 = faces[i]
			var b: Vector3 = faces[i+1]
			var c: Vector3 = faces[i+2]
			if absf(a.y-b.y)<.00001 and absf(a.y-c.y)<.00001:
				if heights.is_empty() or absf(heights[-1]-a.y)>.00001:
					heights.append(a.y)
					depths.append(maxf(a.x,maxf(b.x,c.x))-minf(a.x,minf(b.x,c.x)))
		assert(heights.size()>10,"A sustained incline must not become scattered isolated stones")
		var normal: Vector3 = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0]
		assert(normal.dot(Vector3.UP)>.999,"Tread tops need hard horizontal normals, not smoothed ramp lighting")
		heights.sort()
		var rise: float = heights[1]-heights[0]
		assert(rise>.12 and rise<=.17,"Risers must fit the configured human scale")
		
		# ArrayMesh positions are quantised to 0.1 mm; compare within two quanta.
		for i: int in range(1,heights.size()):
			assert(absf(heights[i]-heights[i-1]-rise)<.00021,"Every riser in a flight must have equal height")
			assert(absf(depths[i]-depths[0])<.00021,"Curved ramp grading must produce equal tread depths")
	print("PASS: gentle ramp retained; uphill/downhill flights have horizontal tops and equal human-scale risers")
	quit()
