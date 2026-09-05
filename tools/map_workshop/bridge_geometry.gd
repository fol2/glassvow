extends RefCounted
## Decks continue over conformed approaches instead of stopping at a threshold.
const Meshes = preload("res://tools/map_workshop/mesh_tools.gd")
const Paths = preload("res://tools/map_workshop/road_paths.gd")
const Surfaces = preload("res://tools/map_workshop/bridge_surfaces.gd")

static func build(parent: Node3D, lines: Array[PackedVector3Array], elevated: Callable, paint: ShaderMaterial) -> int:
	var top: SurfaceTool = SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var masonry: SurfaceTool = SurfaceTool.new()
	masonry.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spans: Array[Dictionary] = []
	var chains: Array[Dictionary] = []
	for line: PackedVector3Array in lines:
		var points: PackedVector3Array = Paths.sample(line)
		var distances: PackedFloat32Array = []
		var lengths: PackedFloat32Array = [0]
		distances.resize(points.size())
		distances.fill(10000)
		for i: int in range(points.size()):
			if i>0:
				lengths.append(lengths[-1]+points[i].distance_to(points[i-1]))
			if elevated.call(points[i]):
				distances[i] = 0
			elif i>0:
				distances[i] = minf(distances[i],distances[i-1]+lengths[i]-lengths[i-1])
		for i: int in range(points.size()-2,-1,-1):
			distances[i] = minf(distances[i],distances[i+1]+lengths[i+1]-lengths[i])
		var weights: PackedFloat32Array = []
		for distance: float in distances:
			weights.append(1.0-smoothstep(0,2.2,distance))
		# The bank transition also follows adjoining earth roads. Otherwise a
		# deck ending on a graph junction leaves an unsupported side entrance.
		for i: int in range(points.size()):
			var p: Vector3 = points[i]
			var bank: float = absf(p.x+5.0-sin(p.z*.12)*2.2)
			weights[i] = maxf(weights[i],1.0-smoothstep(3.8,5.8,bank))
		# A bridgehead is one shared landing across every incident road. Its
		# paved approach reaches into each branch, so none enters a raised side.
		for i: int in range(points.size()):
			for pad: Vector2 in parent.landform.abutments:
				var distance: float = Vector2(points[i].x,points[i].z).distance_to(pad)
				weights[i] = maxf(weights[i],1.0-smoothstep(.5,3.5,distance))
		for i: int in range(points.size()):
			points[i].y = parent.bridge_height(points[i].x,points[i].z)
		var soffit: PackedFloat32Array = preload("res://tools/map_workshop/bridge_structure.gd").profile(parent,points,weights)
		for i: int in range(points.size()-1):
			if maxf(weights[i],weights[i+1])<.001:
				continue
			spans.append({"a":points[i],"b":points[i+1],"wa":weights[i],"wb":weights[i+1],"s":lengths[i],"bottom_a":soffit[i],"bottom_b":soffit[i+1]})
		chains.append({"points":points,"lengths":lengths,"weights":weights})
	if spans.is_empty():
		return 0
	var surface: Surfaces = Surfaces.new()
	surface.setup(spans,Callable(parent,"surface_height"),Callable(parent,"bridge_height"))
	surface.append(top,masonry)
	parent.set_meta("bridge_field",surface)
	# _stonework is appended to its own mesh so imported box formats cannot reset the barrel.
	var kerbs: SurfaceTool = SurfaceTool.new()
	kerbs.begin(Mesh.PRIMITIVE_TRIANGLES)
	_stonework(kerbs,chains,surface,lines)
	Meshes.node(parent,Meshes.finish(kerbs),Meshes.material(Color("49454b")),"Bridge parapet stones")
	var deck_paint: ShaderMaterial = paint.duplicate() as ShaderMaterial
	deck_paint.set_shader_parameter("bridge_surface",true)
	Meshes.node(parent,Meshes.finish(top),deck_paint,"Continuous bridge decks")
	var stone: ShaderMaterial = ShaderMaterial.new()
	stone.shader = preload("res://tools/map_workshop/bridge_stone.gdshader")
	Meshes.node(parent,Meshes.finish(masonry),stone,"Joined bridge masonry")
	return spans.size()

static func _stonework(masonry: SurfaceTool, chains: Array[Dictionary], surface: Surfaces,
		lines: Array[PackedVector3Array]) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE
	for chain: Dictionary in chains:
		var points: PackedVector3Array = chain["points"]
		var lengths: PackedFloat32Array = chain["lengths"]
		var weights: PackedFloat32Array = chain["weights"]
		var next_stone: float = .25
		for i: int in range(points.size()-1):
			if lengths[i+1]<next_stone or maxf(weights[i],weights[i+1])<.72:
				continue
			var p: Vector3 = points[i]
			var q: Vector3 = points[i+1]
			var middle: Vector3 = (p+q)*.5
			next_stone = lengths[i+1]+.43
			var forward: Vector3 = (q-p).normalized()
			var side: Vector3 = forward.cross(Vector3.UP).normalized()
			var join: bool = false
			for line: PackedVector3Array in lines:
				if minf(Vector2(middle.x,middle.z).distance_to(Vector2(line[0].x,line[0].z)),Vector2(middle.x,middle.z).distance_to(Vector2(line[-1].x,line[-1].z)))<1.05:
					join = true
			if join:
				continue
			for sign_value: float in [-1,1]:
				var at: Vector3 = middle+side*.755*sign_value
				var nearby: Dictionary = surface.field(Vector2(at.x,at.z))
				var outside: Vector3 = at+side*.22*sign_value
				if Surfaces._number(surface.field(Vector2(outside.x,outside.z)),"distance")<0:
					continue
				at.y = Surfaces._number(nearby,"height")+.13
				var basis: Basis = Basis(Vector3.UP,atan2(forward.x,forward.z))
				masonry.append_from(box,0,Transform3D(basis.scaled_local(Vector3(.18,.26,.44)),at))
