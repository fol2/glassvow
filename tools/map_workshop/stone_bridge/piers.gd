extends RefCounted
## Buttresses, foundation shoes and capped newels at the solid arch piers.
const M = preload("res://tools/map_workshop/mesh_tools.gd")

static func build(parent: Node3D,fields: Array,stone: Material,trim: Material,
		settings: Dictionary = {}) -> Array[ArrayMesh]:
	var body: SurfaceTool = SurfaceTool.new()
	var caps: SurfaceTool = SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	caps.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE
	var placed: Array[Vector3] = []
	for field: RefCounted in fields:
		var groups: Dictionary = {}
		for span: Dictionary in field.spans:
			var key: String = span["edge"]
			if not groups.has(key):
				groups[key] = []
			groups[key].append(span)
		for spans: Array in groups.values():
			var active: bool = false
			for span: Dictionary in spans:
				var low_a: float = span["bottom_a"]
				var low_b: float = span["bottom_b"]
				if maxf(low_a,low_b)>0:
					active = false
					continue
				if active:
					continue
				active = true
				var a: Vector3 = span["a"]
				var b: Vector3 = span["b"]
				var at: Vector3 = (a+b)*.5
				var too_close: bool = false
				for previous: Vector3 in placed:
					too_close = too_close or previous.distance_to(at)<2.0
				var openings: Array = settings.get("openings",[])
				for opening: Vector3 in openings:
					too_close = too_close or opening.distance_to(at)<2.0
				if too_close:
					continue
				placed.append(at)
				var sample: Dictionary = field.field(Vector2(at.x,at.z))
				var deck: float = sample["height"]
				var width: float = sample["distance"]
				width = -width
				var forward: Vector3 = Vector3(b.x-a.x,0,b.z-a.z).normalized()
				var side: Vector3 = forward.cross(Vector3.UP)
				var basis: Basis = Basis(side,Vector3.UP,-forward)
				for sign_value: int in [-1,1]:
					var centre: Vector3 = at+side*sign_value*(width+.32)
					var query: Dictionary = field.field(Vector2(centre.x,centre.z))
					var distance: float = query["distance"]
					if distance<0:
						continue
					var clear: bool = true
					for across: float in [-.28,0.0,.28]:
						for along: float in [-.39,0.0,.39]:
							var corner: Vector3 = centre+side*across+forward*along
							for neighbour: RefCounted in fields:
								var nearby: Dictionary = neighbour.field(Vector2(corner.x,corner.z))
								var nearby_distance: float = nearby["distance"]
								var nearby_height: float = nearby["height"]
								if nearby_distance<.015 and nearby_height<deck+.9 and nearby_height>-.45:
									clear = false
					if not clear:
						continue
					var foot: float = settings.get("foundation_level", -.45)
					var top: float = deck+.77
					centre.y = (foot+top)*.5
					body.append_from(box,0,Transform3D(basis.scaled_local(Vector3(.40,top-foot,.62)),centre))
					centre.y = foot+.17
					caps.append_from(box,0,Transform3D(basis.scaled_local(Vector3(.62,.34,.86)),centre))
					centre.y = deck+.81
					caps.append_from(box,0,Transform3D(basis.scaled_local(Vector3(.56,.14,.78)),centre))
	var result: Array[ArrayMesh] = []
	if not placed.is_empty():
		for surface: SurfaceTool in [body,caps]:
			var mesh: ArrayMesh = M.finish(surface)
			result.append(mesh)
			M.node(parent,mesh,stone if surface==body else trim,"BridgePierButtresses")
	print("STONE_BRIDGE_PIER_PAIRS ",placed.size())
	return result
