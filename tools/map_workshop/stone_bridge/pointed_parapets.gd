extends RefCounted
## Approved B language: complete two-opening bays fitted to continuous edges.
## Distances belong to the boundary run, never a nearest-route UV lookup.
const M = preload("res://tools/map_workshop/mesh_tools.gd")
var points: Array[Vector3] = []
var normals: Array[Vector3] = []
var stations: Array[float] = []
var body: SurfaceTool
var trim: SurfaceTool
var fields: Array
var wall: float = .83
var thickness: float = .20
var bays: int = 0
var stair_bays: int = 0

func build(edges: Array[Dictionary],blocks: SurfaceTool,caps: SurfaceTool,all_fields: Array,settings: Dictionary) -> void:
	body = blocks
	trim = caps
	fields = all_fields
	wall = settings.get("parapet_height",.83)
	thickness = settings.get("parapet_width",.20)
	body.set_smooth_group(-1)
	trim.set_smooth_group(-1)
	for edge: Dictionary in edges:
		var a: Vector3 = edge["a"]
		var b: Vector3 = edge["b"]
		var outward: Vector3 = edge["outward"]
		if not points.is_empty():
			var previous: Vector3 = (points[-1]-points[-2]).normalized() if points.size()>1 else (b-a).normalized()
			if points[-1].distance_to(a)>.025 or previous.dot((b-a).normalized())<.78:
				_finish_run()
		if points.is_empty():
			points.append(a)
			normals.append(outward)
			stations.append(0.0)
		else:
			normals[-1] = (normals[-1]+outward).normalized()
		stations.append(stations[-1]+Vector2(b.x-a.x,b.z-a.z).length())
		points.append(b)
		normals.append(outward)
	_finish_run()
	print("POINTED_PARAPET_BAYS ",bays," STAIR_BAYS ",stair_bays)

func _finish_run() -> void:
	if points.size()<2:
		return
	var total: float = stations[-1]
	if total<.025:
		_clear()
		return
	if total<1.55:
		_band(body,0,total,0,wall,thickness)
		_band(trim,0,total,wall,wall+.12,thickness+.12)
	else:
		var divisions: int = maxi(1,roundi(total/2.9))
		var length: float = total/divisions
		for i: int in range(divisions):
			var start: float = i*length
			var end: float = (i+1)*length
			var a: Vector3 = _sample(start)["point"]
			var b: Vector3 = _sample(end)["point"]
			var slope: float = absf(b.y-a.y)/length
			_band(body,start,end,0,.20,thickness)
			# Long coping sections are a continuous loft, not rotated blocks.
			_band(trim,start,end,wall,wall+.12,thickness+.12)
			if slope>.14:
				_stair_panel(start,end)
				stair_bays += 1
			else:
				_arch_panel(start,end)
			bays += 1
		for i: int in range(divisions+1):
			var station: float = i*length
			var start: float = maxf(0,station-.16)
			var end: float = minf(total,station+.16)
			# Post centre moves towards the water. Full cap corners must fit.
			if _post_fits(start,end):
				_band(body,start,end,0,wall+.09,thickness+.08,.22)
				_band(trim,maxf(0,start-.04),minf(total,end+.04),wall+.09,wall+.23,thickness+.16,.22)
	_clear()

func _clear() -> void:
	points.clear()
	normals.clear()
	stations.clear()

func _arch_panel(start: float,end: float) -> void:
	var usable_start: float = start+.16
	var usable_end: float = end-.16
	var pitch: float = (usable_end-usable_start)*.5
	for i: int in range(2):
		var left: float = usable_start+i*pitch+.09
		var right: float = usable_start+(i+1)*pitch-.09
		_band(body,left-.09,left,.20,wall,thickness)
		_band(body,right,right+.09,.20,wall,thickness)
		var width: float = right-left
		var sections: int = maxi(8,ceili(width/.12))
		for j: int in range(sections):
			var a: float = left+width*j/sections
			var b: float = left+width*(j+1)/sections
			var low_a: float = .37+_pointed(a-left-width*.5,width,.36)
			var low_b: float = .37+_pointed(b-left-width*.5,width,.36)
			_loft(body,a,b,low_a,low_b,wall,wall,thickness,.14)
			_loft(trim,a,b,low_a,low_b,low_a+.065,low_b+.065,thickness+.04,.14)
	_band(body,start,usable_start,.20,wall,thickness)
	_band(body,usable_end,end,.20,wall,thickness)

func _stair_panel(start: float,end: float) -> void:
	var divisions: int = maxi(2,roundi((end-start)/.48))
	for i: int in range(divisions+1):
		var at: float = lerpf(start,end,float(i)/divisions)
		_band(body,maxf(start,at-.08),minf(end,at+.08),.20,wall,thickness)

func _pointed(x: float,width: float,rise: float) -> float:
	var half: float = width*.5
	return sqrt(maxf(0,width*width-pow(absf(x)+half,2)))/(sqrt(3.0)*half)*rise

func _sample(at: float) -> Dictionary:
	var index: int = clampi(stations.bsearch(at)-1,0,points.size()-2)
	var t: float = clampf((at-stations[index])/maxf(.000001,stations[index+1]-stations[index]),0,1)
	return {"point":points[index].lerp(points[index+1],t),"normal":normals[index].lerp(normals[index+1],t).normalized()}

func _band(surface: SurfaceTool,start: float,end: float,low: float,high: float,width: float,offset: float = .14) -> void:
	if end-start<.001:
		return
	var cuts: Array[float] = [start]
	for station: float in stations:
		if station>start+.001 and station<end-.001:
			cuts.append(station)
	cuts.append(end)
	for i: int in range(cuts.size()-1):
		_loft(surface,cuts[i],cuts[i+1],low,low,high,high,width,offset)

func _loft(surface: SurfaceTool,start: float,end: float,low_a: float,low_b: float,high_a: float,high_b: float,width: float,offset: float) -> void:
	var a: Dictionary = _sample(start)
	var b: Dictionary = _sample(end)
	var pa: Vector3 = a["point"]
	var pb: Vector3 = b["point"]
	var na: Vector3 = a["normal"]
	var nb: Vector3 = b["normal"]
	var p: Array[Vector3] = [pa+na*(offset-width*.5)+Vector3.UP*low_a,pb+nb*(offset-width*.5)+Vector3.UP*low_b,pb+nb*(offset-width*.5)+Vector3.UP*high_b,pa+na*(offset-width*.5)+Vector3.UP*high_a,pa+na*(offset+width*.5)+Vector3.UP*low_a,pb+nb*(offset+width*.5)+Vector3.UP*low_b,pb+nb*(offset+width*.5)+Vector3.UP*high_b,pa+na*(offset+width*.5)+Vector3.UP*high_a]
	# Boundary winding can reverse around an island: face orientation follows
	# the measured outward vector, not the order returned by the outline.
	var reverse: bool = (pb-pa).cross(Vector3.UP).dot(na)<0
	for face: Array in [[0,1,2,3],[5,4,7,6],[4,0,3,7],[1,5,6,2],[3,2,6,7],[4,5,1,0]]:
		if reverse:
			M.triangle(surface,p[face[0]],p[face[2]],p[face[1]])
			M.triangle(surface,p[face[0]],p[face[3]],p[face[2]])
		else:
			M.triangle(surface,p[face[0]],p[face[1]],p[face[2]])
			M.triangle(surface,p[face[0]],p[face[2]],p[face[3]])

func _post_fits(start: float,end: float) -> bool:
	for station: float in [maxf(0,start-.04),(start+end)*.5,minf(stations[-1],end+.04)]:
		var sample: Dictionary = _sample(station)
		var point: Vector3 = sample["point"]
		var normal: Vector3 = sample["normal"]
		for side: int in [-1,1]:
			var corner: Vector3 = point+normal*(.22+side*(thickness+.16)*.5)
			for field: RefCounted in fields:
				var query: Dictionary = field.field(Vector2(corner.x,corner.z))
				var distance: float = query["distance"]
				var height: float = query["height"]
				if distance<-.025 and absf(height-point.y)<.35:
					return false
	return true
