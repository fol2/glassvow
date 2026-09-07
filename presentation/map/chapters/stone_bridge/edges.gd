extends RefCounted
## Continuous edge masonry follows the actual fitted deck, including bends.
## Takes surface queries rather than chapter IDs or generated game state.
const M = preload("res://presentation/map/landscape/mesh_tools.gd")
var blocks: SurfaceTool
var caps: SurfaceTool
var arch_stones: SurfaceTool
var stone_batch: RefCounted
var timings_ms: Dictionary = {}
var _stage_started: int = 0
var _piece_us: int = 0
var _query_us: int = 0

func _mark(stage: String) -> void:
	var now: int = Time.get_ticks_msec()
	timings_ms[stage]=now-_stage_started
	_stage_started=now
	print("STONE_EDGE_TIMING ",stage,"=",timings_ms[stage])

func build(parent: Node3D, mesh: ArrayMesh, field: RefCounted,
		other_fields: Array, stone: Material, trim: Material, settings: Dictionary = {}) -> Array[ArrayMesh]:
	_stage_started=Time.get_ticks_msec()
	blocks = SurfaceTool.new()
	caps = SurfaceTool.new()
	arch_stones = SurfaceTool.new()
	for surface: SurfaceTool in [blocks,caps,arch_stones]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	stone_batch=preload("res://presentation/map/chapters/common/box_batch.gd").new(arch_stones)
	var count: int = 0
	var accepted: Array[Dictionary] = []
	var boundary: Array[Dictionary] = []
	for edge: Dictionary in preload("res://presentation/map/chapters/stone_bridge/outline.gd").segments(mesh):
		var a: Vector3 = edge["a"]
		var b: Vector3 = edge["b"]
		var divisions: int = maxi(1,ceili(a.distance_to(b)/.20))
		for i: int in range(divisions):
			boundary.append({"a":a.lerp(b,float(i)/divisions),"b":a.lerp(b,float(i+1)/divisions)})
	_mark("outline")
	for edge: Dictionary in boundary:
		var a: Vector3 = edge["a"]
		var b: Vector3 = edge["b"]
		if a.distance_to(b)<.002:
			continue
		var at: Vector3 = (a+b)*.5
		var outward: Vector3 = Vector3(b.z-a.z,0,a.x-b.x).normalized()
		var query_started: int = Time.get_ticks_usec()
		var left: Dictionary = field.field(Vector2(at.x+outward.x*.1,at.z+outward.z*.1))
		var right: Dictionary = field.field(Vector2(at.x-outward.x*.1,at.z-outward.z*.1))
		var left_distance: float = left["distance"]
		var right_distance: float = right["distance"]
		# A triangulation seam is not an exposed deck boundary.
		if left_distance<-.03 and right_distance<-.03: continue
		if left_distance<right_distance:
			outward = -outward
		var shared_join: bool = false
		var openings: Array = settings.get("openings",[])
		for opening: Vector3 in openings:
			shared_join = shared_join or (Vector2(at.x-opening.x,at.z-opening.z).length()<1.6 and absf(at.y-opening.y)<.25)
		# The full coping must fit in the gap between branches. A valid deck
		# outline alone can surround a notch narrower than the rail itself.
		var rail_width: float = settings.get("parapet_width",.20)
		var outer: float = .14+(rail_width+.12)*.5
		for endpoint: Vector3 in [a,at,b]:
			var probe_at: Vector3 = endpoint+outward*outer
			var own: Dictionary = field.field(Vector2(probe_at.x,probe_at.z))
			var own_distance: float = own["distance"]
			var own_height: float = own["height"]
			shared_join=shared_join or (own_distance<-.025 and _rail_obstructs(own_height,endpoint.y,settings))
		for other: RefCounted in other_fields:
			if other==field:
				continue
			for endpoint: Vector3 in [a,at,b]:
				var query: Dictionary = other.field(Vector2(endpoint.x+outward.x*.08,endpoint.z+outward.z*.08))
				var distance: float = query["distance"]
				var height: float = query["height"]
				shared_join = shared_join or (distance<=.20 and _rail_obstructs(height,endpoint.y,settings))
		_query_us+=Time.get_ticks_usec()-query_started
		if shared_join:
			continue
		accepted.append({"a":a,"b":b,"outward":outward})
		_piece(arch_stones,a,b,outward*.04-Vector3.UP*.16,.34,.16)
		_arch_band(a,b,outward,field)
		count += 1
	_mark("boundary_masonry")
	print("STONE_EDGE_PARTS query_ms=",_query_us/1000.0," piece_ms=",_piece_us/1000.0)
	preload("res://presentation/map/chapters/stone_bridge/pointed_parapets.gd").new().build(accepted,blocks,caps,other_fields,settings)
	_mark("parapets")
	var result: Array[ArrayMesh] = []
	if count>0:
		for surface: SurfaceTool in [blocks,caps,arch_stones]:
			var finished: ArrayMesh = M.finish(surface)
			result.append(finished)
			M.node(parent,finished,stone if surface==blocks else trim,"BridgeEdgeMasonry")
	_mark("normals")
	print("STONE_BRIDGE_BOUNDARY_PIECES ",count)
	return result

func _arch_band(a: Vector3,b: Vector3,outward: Vector3,field: RefCounted) -> void:
	# The deck outline can be straight above an entire arch. Sample the
	# intrados separately; joining only deck endpoints draws a false diagonal.
	var divisions: int = maxi(1,ceili(a.distance_to(b)/.20))
	for i: int in range(divisions):
		var pa: Vector3 = a.lerp(b,float(i)/divisions)
		var pb: Vector3 = a.lerp(b,float(i+1)/divisions)
		var query_started: int = Time.get_ticks_usec()
		var qa: Dictionary = field.field(Vector2(pa.x,pa.z))
		var qb: Dictionary = field.field(Vector2(pb.x,pb.z))
		_query_us+=Time.get_ticks_usec()-query_started
		var low_a: float = qa["bottom"]
		var low_b: float = qb["bottom"]
		if minf(low_a,low_b)<=1.0 or absf(low_a-low_b)>.65:
			continue
		pa.y = low_a+.12
		pb.y = low_b+.12
		_piece(arch_stones,pa,pb,outward*.04,.23,.26,-.012)

func _piece(_surface: SurfaceTool,a: Vector3,b: Vector3,offset: Vector3,width: float,height: float,overlap: float = .008) -> void:
	var started: int = Time.get_ticks_usec()
	var delta: Vector3 = b-a
	var run: float = maxf(.002,Vector2(delta.x,delta.z).length())
	var side: Vector3 = delta.cross(Vector3.UP).normalized()
	# Vertical sections shear with the slope: tilted boxes used to produce
	# a serrated coping silhouette where their rotated ends overlapped.
	var basis: Basis = Basis(side,Vector3.UP,-delta/run)
	stone_batch.append(Transform3D(basis.scaled_local(Vector3(width,height,maxf(.002,run+overlap))),(a+b)*.5+offset))
	_piece_us+=Time.get_ticks_usec()-started

static func _rail_obstructs(other_height: float,deck_height: float,settings: Dictionary) -> bool:
	# A rising route can cross a lower rail before reaching equal deck height.
	# Test the rail's full vertical extent against that route's walking body.
	var wall: float = settings.get("parapet_height",.83)
	return other_height<deck_height+wall+.23 and other_height+2.12>deck_height+.04
