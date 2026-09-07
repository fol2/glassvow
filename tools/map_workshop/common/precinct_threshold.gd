extends RefCounted
## Route-derived transverse masonry: a swept opening for every crossing.
const M = preload("res://presentation/map/landscape/mesh_tools.gd")
static func plan(routes: Dictionary, x: float, near_z: float, far_z: float,
		depth: float = 1.6, clearance: float = 3.0) -> Dictionary:
	var openings: Array[Dictionary] = []
	for id: String in MapLayoutCanonical.sorted_keys(routes):
		var edge: Dictionary = routes[id]
		var radius: float = MapLayoutCanonical.float_value(edge["corridor_width"])*.5+.4
		var band: float = depth*.5+radius
		var line: Array = edge["centerline"]
		for i: int in range(line.size()-1):
			var a: Vector3 = _point(line[i])
			var b: Vector3 = _point(line[i+1])
			var t0: float = 0
			var t1: float = 1
			if absf(b.x-a.x) < .00001:
				if absf(a.x-x) > band:
					continue
			else:
				var first: float = (x-band-a.x)/(b.x-a.x)
				var last: float = (x+band-a.x)/(b.x-a.x)
				t0 = maxf(0,minf(first,last))
				t1 = minf(1,maxf(first,last))
				if t0 > t1:
					continue
			var start: Vector3 = a.lerp(b,t0)
			var end: Vector3 = a.lerp(b,t1)
			openings.append({"near":minf(start.z,end.z)-radius,
				"far":maxf(start.z,end.z)+radius,
				"spring":maxf(start.y,end.y)+clearance,"edges":[id]})
	openings.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a["near"] < b["near"])
	var merged: Array[Dictionary] = []
	for opening: Dictionary in openings:
		if merged.is_empty() or MapLayoutCanonical.float_value(opening["near"])-MapLayoutCanonical.float_value(merged[-1]["far"]) > 1.4:
			merged.append(opening.duplicate(true))
		else:
			merged[-1]["far"] = maxf(MapLayoutCanonical.float_value(merged[-1]["far"]),MapLayoutCanonical.float_value(opening["far"]))
			merged[-1]["spring"] = maxf(MapLayoutCanonical.float_value(merged[-1]["spring"]),MapLayoutCanonical.float_value(opening["spring"]))
			merged[-1]["edges"].append_array(opening["edges"])
	for opening: Dictionary in merged:
		if MapLayoutCanonical.float_value(opening["near"]) < near_z or MapLayoutCanonical.float_value(opening["far"]) > far_z:
			return {"ok":false,"reason":"threshold footprint cannot enclose routed opening"}
	return {"ok":true,"x":x,"near":near_z,"far":far_z,"depth":depth,"openings":merged}
static func build(parent: Node3D, layout: Dictionary, material: Material, trim_material: Material = null, maximum_arch_span: float = INF) -> Node3D:
	assert(layout.get("ok") == true)
	var root: Node3D = Node3D.new()
	parent.add_child(root)
	var x: float = layout["x"]
	var depth: float = layout["depth"]
	var cursor: float = layout["near"]
	var dressed: Material = material if trim_material == null else trim_material
	for opening: Dictionary in layout["openings"]:
		var start: float = opening["near"]
		var end: float = opening["far"]
		var spring: float = opening["spring"]
		if start > cursor:
			M.box(root,Vector3(x,.6,(cursor+start)*.5),Vector3(depth,3.2,start-cursor),material,"ThresholdPier")
		for jamb: float in [start-.35,end+.35]:
			M.box(root,Vector3(x,(spring-.5)*.5,jamb),Vector3(depth+.25,spring+1.5,.7),material,"VaultJamb")
			M.box(root,Vector3(x,-.2,jamb),Vector3(depth+.55,1.6,1.0),dressed,"DressedFooting")
			M.box(root,Vector3(x,spring-.15,jamb),Vector3(depth+.45,.3,.95),dressed,"SpringCapital")
		# A merged ceremonial stair can span a court. It is an open approach,
		# not an ordinary doorway scaled into a structurally implausible arch.
		if end-start > maximum_arch_span:
			for jamb: float in [start-.35,end+.35]:
				M.box(root,Vector3(x,spring+.35,jamb),Vector3(depth+.5,.35,1.05),dressed,"OpenApproachPierCap")
			cursor = end
			continue
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_smooth_group(-1)
		# A pointed, faceted soffit rises above the guaranteed clear rectangle.
		var steps: int = 12
		for i: int in range(steps):
			var u: float = float(i)/steps
			var v: float = float(i+1)/steps
			var z0: float = lerpf(start,end,u)
			var z1: float = lerpf(start,end,v)
			var y0: float = spring+_arch_rise(u,end-start)
			var y1: float = spring+_arch_rise(v,end-start)
			var a: Vector3 = Vector3(x-depth*.5,y0,z0)
			var b: Vector3 = Vector3(x-depth*.5,y1,z1)
			var c: Vector3 = Vector3(x+depth*.5,y1,z1)
			var d: Vector3 = Vector3(x+depth*.5,y0,z0)
			_quad(surface,a,b,c,d)
			_quad(surface,Vector3(a.x,y0+.55,z0),Vector3(b.x,y1+.55,z1),b,a)
			_quad(surface,d,c,Vector3(c.x,y1+.55,z1),Vector3(d.x,y0+.55,z0))
			_quad(surface,Vector3(a.x,y0+.55,z0),Vector3(d.x,y0+.55,z0),Vector3(c.x,y1+.55,z1),Vector3(b.x,y1+.55,z1))
		M.node(root,M.finish(surface),material,"ThresholdVault")
		var crown: float = spring+_arch_rise(.5,end-start)
		M.box(root,Vector3(x,crown+.3,(start+end)*.5),Vector3(depth+.35,.8,.5),dressed,"CrownStone")
		cursor = end
	var far_z: float = layout["far"]
	if cursor < far_z:
		M.box(root,Vector3(x,.6,(cursor+far_z)*.5),Vector3(depth,3.2,far_z-cursor),material,"ThresholdPier")
	return root
static func _quad(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	M.triangle(surface,a,b,c)
	M.triangle(surface,a,c,d)
static func _point(value: Variant) -> Vector3:
	var point: Array = value
	return M.v3(point)

static func _arch_rise(t: float,width: float) -> float:
	var half: float = width*.5
	var rise: float = maxf(width*.7,1.7)
	var centre: float = (rise*rise-half*half)/(2*half)
	var radius: float = half+centre
	var horizontal: float = -absf((2*t-1)*half)-centre
	return sqrt(maxf(0,radius*radius-horizontal*horizontal))
