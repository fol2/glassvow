extends Node3D
## Native land and roads derived from the compiled route topology.
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
const Paint = preload("res://presentation/map/landscape/terrain_paint.gd")
const River = preload("res://presentation/map/landscape/river.gd")
var lines: Array[PackedVector3Array] = []
var source_edges: Dictionary = {}
var anchors: Dictionary = {}
var road_segments: int = 0
var bridge_spans: int = 0
var greybox: bool = true
var height_cache: Dictionary = {}
var landform: RefCounted = preload("res://presentation/map/landscape/landform.gd").new()
const CELL: float = .5
const WATER: float = River.LEVEL

func build(sample: Dictionary, grey: bool) -> void:
	greybox = grey
	source_edges = sample["edges"]
	anchors = sample["anchors"]
	for edge: Dictionary in source_edges.values():
		var points: PackedVector3Array = []
		for point: Array in edge["centerline"]:
			points.append(Meshes.v3(point))
		lines.append(points)
	var source_points: PackedVector3Array = []
	for raw: Array in anchors.values():
		source_points.append(Meshes.v3(raw))
	var gateway: Dictionary = preload("res://presentation/map/landscape/gateway_sites.gd").choose(self,source_points,false)
	if not gateway.is_empty():
		var at: Vector3 = gateway["position"]
		landform.terrace_centre = Vector2(at.x,at.z)
	landform.setup(lines)
	_land()
	_roads()
	var river: River = River.new()
	add_child(river)
	river.build(self)

func distance_to_roads(p: Vector3) -> float:
	var best: float = INF
	var q: Vector2 = Vector2(p.x, p.z)
	for line: PackedVector3Array in lines:
		for i: int in range(line.size() - 1):
			var a: Vector2 = Vector2(line[i].x, line[i].z)
			var b: Vector2 = Vector2(line[i + 1].x, line[i + 1].z)
			best = minf(best, q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b)))
	return best

func stream_distance(x: float, z: float) -> float:
	return absf(x + 5.0 - sin(z * 0.12) * 2.2)

func height_at(x: float, z: float) -> float:
	var key: Vector2 = Vector2(x,z)
	if height_cache.has(key):
		return height_cache[key]
	var result: float = landform.height(x,z)
	height_cache[key] = result
	return result

func surface_height(x: float, z: float) -> float:
	# Match the actual two triangles of each land cell, not the curved source
	# function between vertices. Asset contacts must use the rendered surface.
	var base_x: float = -48 + floorf((x + 48) / CELL) * CELL
	var base_z: float = -30 + floorf((z + 30) / CELL) * CELL
	var u: float = (x - base_x) / CELL
	var v: float = (z - base_z) / CELL
	var h0: float = height_at(base_x, base_z)
	var h2: float = height_at(base_x + CELL, base_z + CELL)
	if v >= u:
		return h0 * (1 - v) + h2 * u + height_at(base_x, base_z + CELL) * (v - u)
	return h0 * (1 - u) + h2 * v + height_at(base_x + CELL, base_z) * (u - v)

func bridge_height(x: float, z: float) -> float:
	var height: float = landform.upland(x,z)
	height += .18*(1.0-smoothstep(.4,3.8,stream_distance(x,z)))
	var crown: float = 0
	for cut: Dictionary in landform.cuts:
		var centre: Vector2 = cut["at"]
		crown = maxf(crown,.75*(1.0-smoothstep(1.2,4.0,centre.distance_to(Vector2(x,z)))))
	return height+crown

func route_height(p: Vector3) -> float:
	if is_elevated(p):
		# Upper roads span the uncut upland; their clearance comes from the
		# actual valley below, rather than a short, excessively steep ramp.
		var bank: float = stream_distance(p.x,p.z)
		var crown: float = .18*(1.0-smoothstep(.4,3.8,bank))
		return landform.upland(p.x,p.z)+crown
	return surface_height(p.x,p.z)

func present(p: Vector3, upper: bool = false) -> Vector3:
	var height: float = route_height(p)
	var approach: bool = false
	for pad: Vector2 in landform.abutments:
		approach = approach or Vector2(p.x,p.z).distance_to(pad)<3.5
	if has_meta("bridge_field") and (upper or p.y>.015 or approach or stream_distance(p.x,p.z)<5.8):
		var field: RefCounted = get_meta("bridge_field")
		var value: Dictionary = field.field(Vector2(p.x,p.z))
		var distance: float = value["distance"]
		if distance<0:
			height = value["height"]
	return Vector3(p.x,height,p.z)

func is_dry(p: Vector3) -> bool:
	return not River.contains(p.x,p.z) or surface_height(p.x,p.z)>WATER+.20

func is_elevated(p: Vector3) -> bool:
	return p.y > 0.015 or stream_distance(p.x, p.z) < 3.8

func _land() -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ix: int in range(int(96/CELL)):
		for iz: int in range(int(60/CELL)):
			var x: float = -48 + ix * CELL
			var z: float = -30 + iz * CELL
			var corners: Array[Vector3] = []
			for offset: Vector2 in [Vector2.ZERO, Vector2(0, CELL), Vector2(CELL, CELL), Vector2(CELL, 0)]:
				var p: Vector2 = Vector2(x, z) + offset
				corners.append(Vector3(p.x, height_at(p.x, p.y), p.y))
			for index: int in [0, 2, 1, 0, 3, 2]:
				var p: Vector3 = corners[index]
				var shade: float = 0.96 + 0.05 * sin(p.x * 0.22 + p.z * 0.15)
				var colour: Color = Color("555663") if greybox else Color("302b30")
				surface.set_color(colour * shade)
				surface.add_vertex(p)
	var mat: StandardMaterial3D = Meshes.material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	var ground_mat: Material = mat if greybox else Paint.create(lines, is_elevated)
	Meshes.node(self, Meshes.finish(surface), ground_mat, "Quiet sculpted ground")

func _roads() -> void:
	if not greybox:
		var ground: MeshInstance3D = get_node("Quiet sculpted ground") as MeshInstance3D
		bridge_spans = preload("res://presentation/map/landscape/bridge_geometry.gd").build(self,lines,is_elevated,ground.material_override as ShaderMaterial)
		for line: PackedVector3Array in lines:
			road_segments += line.size()-1
		return
	var top: SurfaceTool = SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bridge: SurfaceTool = SurfaceTool.new()
	bridge.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blocks: BoxMesh = BoxMesh.new()
	blocks.size = Vector3.ONE
	for line: PackedVector3Array in lines:
		for i: int in range(line.size() - 1):
			road_segments += 1
			var a: Vector3 = line[i]
			var b: Vector3 = line[i + 1]
			var side: Vector3 = (b - a).cross(Vector3.UP).normalized()
			var slices: int = maxi(1, ceili(a.distance_to(b) / 0.6))
			for step: int in range(slices):
				var p: Vector3 = a.lerp(b, float(step) / slices) + Vector3.UP * 0.022
				var q: Vector3 = a.lerp(b, float(step + 1) / slices) + Vector3.UP * 0.022
				var middle: Vector3 = (p + q) * 0.5
				var elevated: bool = is_elevated(middle)
				var half: float = 0.72
				if greybox or elevated:
					Meshes.triangle(top, p - side * half, q - side * half, q + side * half)
					Meshes.triangle(top, p - side * half, q + side * half, p + side * half)
				if elevated:
					bridge_spans += 1
					var basis: Basis = Basis(Vector3.UP, atan2((b - a).x, (b - a).z))
					var forward: Vector3 = (q - p).normalized()
					var right: Vector3 = Vector3.UP.cross(forward).normalized()
					var normal: Vector3 = forward.cross(right)
					var deck_basis: Basis = Basis(right, normal, forward)
					# Match the road slope and keep the whole top face below its ribbon.
					bridge.append_from(blocks, 0, Transform3D(deck_basis.scaled_local(Vector3(1.6, 0.4, p.distance_to(q) + 0.02)), middle - normal * 0.23))
					if step % 4 == 0:
						bridge.append_from(blocks, 0, Transform3D(basis.scaled_local(Vector3(1.25, 1.25, 0.45)), middle - Vector3.UP * 0.83))
					for sign_value: float in [-1, 1]:
						bridge.append_from(blocks, 0, Transform3D(deck_basis.scaled_local(Vector3(0.17, 0.26, p.distance_to(q))), middle + side * sign_value * 0.82 + normal * 0.12))
		for p: Vector3 in line:
			if not greybox and not is_elevated(p + Vector3.UP * 0.022):
				continue
			for i: int in range(16):
				var a: float = i * TAU / 16.0
				var b: float = (i + 1) * TAU / 16.0
				var centre: Vector3 = p + Vector3.UP * 0.023
				Meshes.triangle(top, centre, centre + Vector3(cos(a), 0, sin(a)) * 0.72,
					centre + Vector3(cos(b), 0, sin(b)) * 0.72)
	var mat: StandardMaterial3D = Meshes.material(Color("98938b") if greybox else Color("62584f"))
	Meshes.node(self, Meshes.finish(top), mat, "Compiled roads").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if bridge_spans > 0:
		Meshes.node(self, Meshes.finish(bridge), Meshes.material(Color("65616b")), "Supported bridge spans")
