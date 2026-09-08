extends RefCounted
## A single clipped surface for decks and ramps, including bends and joins.
## Shared grid vertices give adjacent pieces identical contact heights.
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
# Subdivide the land's .5 m cells using the same diagonal. An unrelated grid
# can cut through a land triangle between otherwise sound contact vertices.
const CELL: float = .125
const HALF: float = .80
var query_cell_size: float = CELL
var spans: Array[Dictionary] = []
var cells: Dictionary = {}
var vertices: Dictionary = {}
var ground: Callable
var profile: Callable
var cancel_token: RefCounted

func setup(source: Array[Dictionary], height: Callable, deck_profile: Callable = Callable()) -> void:
	spans = source
	ground = height
	profile = deck_profile
	for span: Dictionary in spans:
		var a: Vector3 = span["a"]
		var b: Vector3 = span["b"]
		var half_a: float = span.get("half_a",HALF)
		var half_b: float = span.get("half_b",HALF)
		var half_width: float = maxf(half_a,half_b)
		var lo: Vector2 = Vector2(minf(a.x,b.x),minf(a.z,b.z))-Vector2.ONE*(half_width+CELL*2)
		var hi: Vector2 = Vector2(maxf(a.x,b.x),maxf(a.z,b.z))+Vector2.ONE*(half_width+CELL*2)
		for x: int in range(floori(lo.x/query_cell_size),ceili(hi.x/query_cell_size)+1):
			for z: int in range(floori(lo.y/query_cell_size),ceili(hi.y/query_cell_size)+1):
				var key: Vector2i = Vector2i(x,z)
				if not cells.has(key):
					cells[key] = []
				cells[key].append(span)

func field(at: Vector2) -> Dictionary:
	var candidates: Array = cells.get(Vector2i(floori(at.x/query_cell_size),floori(at.y/query_cell_size)),[])
	var best: float = INF
	var rise_sum: float = 0
	var rise_weight: float = 0
	var highest_rise: float = 0
	var result: Dictionary = {"distance":INF,"height":0.0,"blend":0.0,"bottom":0.0,"uv":Vector2.ZERO}
	for span: Dictionary in candidates:
		var a3: Vector3 = span["a"]
		var b3: Vector3 = span["b"]
		var a: Vector2 = Vector2(a3.x,a3.z)
		var b: Vector2 = Vector2(b3.x,b3.z)
		var t: float = clampf((at-a).dot(b-a)/maxf(.000001,a.distance_squared_to(b)),0,1)
		var distance: float = at.distance_to(a.lerp(b,t))
		var wa: float = span.get("raise_a",span["wa"])
		var wb: float = span.get("raise_b",span["wb"])
		var rise: float = lerpf(wa,wb,t)
		var weight: float = exp(-distance*distance/.15)*a.distance_to(b)
		rise_sum += rise*weight
		rise_weight += weight
		highest_rise = maxf(highest_rise,rise)
		var half_a: float = span.get("half_a",HALF)
		var half_b: float = span.get("half_b",HALF)
		var boundary: float = distance-lerpf(half_a,half_b,t)
		if boundary >= best:
			continue
		best = boundary
		var blend: float = lerpf(_number(span,"wa"),_number(span,"wb"),t)
		var direction: Vector2 = (b-a).normalized()
		var low_a: float = span.get("bottom_a",a3.y-.18)
		var low_b: float = span.get("bottom_b",b3.y-.18)
		result = {"distance":boundary,"height":lerpf(a3.y,b3.y,t)+.022,
			"blend":blend,"bottom":lerpf(low_a,low_b,t),"uv":Vector2(direction.cross(at-a),_number(span,"s")+a.distance_to(b)*t)}
	if best < INF:
		if profile.is_valid():
			var deck_height: float = profile.call(at.x,at.y)
			result["height"] = deck_height+.022
		var ground_height: float = ground.call(at.x,at.y)
		var rise: float = rise_sum/maxf(.000001,rise_weight)
		# At a true opening the deck is structural. Ground-side material spans
		# beneath it must not pull its height down towards the lower road.
		rise = lerpf(rise,highest_rise,smoothstep(.6,1.2,_number(result,"height")-ground_height))
		result["height"] = lerpf(ground_height+.012,_number(result,"height"),rise)
		# A hillside can rise above the nominal bridge profile at an approach.
		# Keep the complete top surface above it, not just the route centre.
		result["height"] = maxf(ground_height+.012,_number(result,"height"))
		result["bottom"] = minf(_number(result,"height")-.005,lerpf(ground_height+.008,_number(result,"bottom"),_number(result,"blend")))
	return result

func _vertex(key: Vector2i) -> Dictionary:
	if not vertices.has(key):
		var at: Vector2 = Vector2(key)*CELL
		var sample: Dictionary = field(at)
		sample["at"] = at
		vertices[key] = sample
	return vertices[key]

func append(top: SurfaceTool, masonry: SurfaceTool) -> void:
	assert(is_equal_approx(query_cell_size,CELL),"Meshing requires the reference grid; coarse indices are query-only")
	var visited: int = 0
	for key: Vector2i in cells:
		if visited%128==0 and cancel_token!=null and cancel_token.cancelled(): return
		visited+=1
		var corners: Array[Dictionary] = [_vertex(key),_vertex(key+Vector2i(0,1)),
			_vertex(key+Vector2i(1,1)),_vertex(key+Vector2i(1,0))]
		_clip(top,masonry,[corners[0],corners[2],corners[1]])
		_clip(top,masonry,[corners[0],corners[3],corners[2]])

func _clip(top: SurfaceTool, masonry: SurfaceTool, triangle: Array[Dictionary]) -> void:
	var polygon: Array[Dictionary] = []
	for i: int in range(3):
		var a: Dictionary = triangle[i]
		var b: Dictionary = triangle[(i+1)%3]
		var da: float = a["distance"]
		var db: float = b["distance"]
		if da<=0:
			polygon.append(a)
		if (da<0 and db>0) or (da>0 and db<0):
			var t: float = da/(da-db)
			polygon.append({"at":_vector(a,"at").lerp(_vector(b,"at"),t),"distance":0.0,
				"height":lerpf(_number(a,"height"),_number(b,"height"),t),"blend":lerpf(_number(a,"blend"),_number(b,"blend"),t),
				"uv":_vector(a,"uv").lerp(_vector(b,"uv"),t),"bottom":lerpf(_number(a,"bottom"),_number(b,"bottom"),t)})
	for i: int in range(1,polygon.size()-1):
		var origin: Vector3 = _position(polygon[0])
		var first: Vector3 = _position(polygon[i])
		var second: Vector3 = _position(polygon[i+1])
		# An outline can pass exactly through a grid vertex. Its zero-area
		# clipping remnant is not a surface and must not enter the mesh.
		if (first-origin).cross(second-origin).length_squared()<.00000000000001:
			continue
		for item: Dictionary in [polygon[0],polygon[i],polygon[i+1]]:
			top.set_color(Color(_number(item,"blend"),maxf(0,-_number(item,"distance")),1,1))
			top.set_uv(_vector(item,"uv"))
			top.add_vertex(_position(item))
		var underside: PackedVector3Array = []
		for item: Dictionary in [polygon[0],polygon[i+1],polygon[i]]:
			var at: Vector3 = _position(item)
			at.y = _number(item,"bottom")
			underside.append(at)
		Meshes.triangle(masonry,underside[0],underside[1],underside[2])
	for i: int in range(polygon.size()):
		var a: Dictionary = polygon[i]
		var b: Dictionary = polygon[(i+1)%polygon.size()]
		if absf(_number(a,"distance"))>.0001 or absf(_number(b,"distance"))>.0001:
			continue
		var p: Vector3 = _position(a)
		var q: Vector3 = _position(b)
		var down_a: Vector3 = Vector3(p.x,_number(a,"bottom"),p.z)
		var down_b: Vector3 = Vector3(q.x,_number(b,"bottom"),q.z)
		Meshes.triangle(masonry,p,down_a,down_b)
		Meshes.triangle(masonry,p,down_b,q)

func _position(item: Dictionary) -> Vector3:
	var at: Vector2 = item["at"]
	return Vector3(at.x,_number(item,"height"),at.y)

static func _number(item: Dictionary, key: String) -> float:
	var value: float = item[key]
	return value

static func _vector(item: Dictionary, key: String) -> Vector2:
	var value: Vector2 = item[key]
	return value
