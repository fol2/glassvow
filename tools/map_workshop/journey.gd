extends Node3D
## Visible journey state consumes WorldMap; it never invents legal connections.
const Meshes = preload("res://tools/map_workshop/mesh_tools.gd")
const Terrain = preload("res://tools/map_workshop/terrain.gd")
const Paths = preload("res://tools/map_workshop/road_paths.gd")
const Pilgrim = preload("res://tools/map_workshop/pilgrim.gd")
var terrain: Terrain
var anchors: PackedVector3Array
var walker: Pilgrim
var glasses: Array[StandardMaterial3D] = []
var bases: Array[Node3D] = []
var trace: MeshInstance3D
var walking: bool = false
var reduced_motion: bool = false
var distance_walked: float = 0
signal arrived
var curve: Curve3D
var walk_length: float = 0
var walk_speed: float = 0

func build(surface: Terrain, points: PackedVector3Array, source_points: PackedVector3Array) -> void:
	terrain = surface
	anchors = points
	var packed: PackedScene = preload("res://assets/art/map-journey/waystone.glb")
	for i: int in range(points.size()):
		var source: Vector3 = source_points[i]
		var at: Vector3 = seat(terrain,source)
		var contacts: PackedVector3Array = []
		for corner: int in range(8):
			var angle: float = corner*TAU/8
			var contact: Vector3 = terrain.present(source+Vector3(cos(angle),0,sin(angle))*.38)
			contacts.append(contact)
			at.y = maxf(at.y,contact.y)
		var base: Node3D = packed.instantiate() as Node3D
		add_child(base)
		base.position = at
		# The imported glass faces -Z. Turn towards the default journey camera.
		base.rotation.y = PI
		bases.append(base)
		var footing: SurfaceTool = SurfaceTool.new()
		footing.begin(Mesh.PRIMITIVE_TRIANGLES)
		for corner: int in range(8):
			var a: Vector3 = contacts[corner]-Vector3.UP*.03
			var b: Vector3 = contacts[(corner+1)%8]-Vector3.UP*.03
			var c: Vector3 = Vector3(a.x,at.y+.025,a.z)
			var d: Vector3 = Vector3(b.x,at.y+.025,b.z)
			Meshes.triangle(footing,a,d,c)
			Meshes.triangle(footing,a,b,d)
		Meshes.node(self,Meshes.finish(footing),Meshes.material(Color("484047")),"Waystone footing")
		var glass: StandardMaterial3D = Meshes.material(Color("47404b"),.38)
		glass.emission_enabled = true
		glass.emission_energy_multiplier = .25
		for child: Node in base.find_children("*","MeshInstance3D",true,false):
			var mesh: MeshInstance3D = child as MeshInstance3D
			for index: int in range(mesh.mesh.get_surface_count()):
				var material: Material = mesh.get_active_material(index)
				if material.resource_name=="Old amber window":
					mesh.set_surface_override_material(index,glass)
		glasses.append(glass)
	walker = Pilgrim.new()
	add_child(walker)

func sync(map: WorldMap, selected: int) -> void:
	var reachable: Array[int] = map.reachable()
	for i: int in range(glasses.size()):
		var lit: bool = reachable.has(i) or map.at==i
		glasses[i].albedo_color = Color("b38d57") if lit else Color("49424f")
		glasses[i].emission = Color("aa7841") if lit else Color.BLACK
	if not walking:
		walker.visible = map.at>=0
		if map.at>=0:
			walker.position = parked(anchors[map.at])
	if trace!=null:
		trace.queue_free()
		trace = null
	if selected<0 or not reachable.has(selected) or map.at<0:
		return
	var route: PackedVector3Array = path(map.nodes[map.at].id,map.nodes[selected].id)
	if route.size()<2:
		return
	var ribbon: SurfaceTool = SurfaceTool.new()
	ribbon.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length: float = 0
	for i: int in range(route.size()-1):
		var a: Vector3 = route[i]
		var b: Vector3 = route[i+1]
		# Let the waystone itself mark the destination; avoid drawing a dotted
		# ring around the local footpath used to walk past its physical base.
		var start: Vector3 = anchors[map.at]
		var finish: Vector3 = anchors[selected]
		if Vector2(a.x-start.x,a.z-start.z).length()<1.1 or Vector2(b.x-finish.x,b.z-finish.z).length()<1.1:
			continue
		length += a.distance_to(b)
		if fmod(length,.38)>.14:
			continue
		var side: Vector3 = (b-a).cross(Vector3.UP).normalized()*.021
		var lift: Vector3 = Vector3.UP*.04
		Meshes.triangle(ribbon,a-side+lift,b-side+lift,b+side+lift)
		Meshes.triangle(ribbon,a-side+lift,b+side+lift,a+side+lift)
	var material: StandardMaterial3D = Meshes.material(Color("a48a65"))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trace = Meshes.node(self,Meshes.finish(ribbon),material,"Selected walking route")
	trace.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func path(from_id: String, to_id: String) -> PackedVector3Array:
	for edge: Dictionary in terrain.source_edges.values():
		if edge["from"]!=from_id or edge["to"]!=to_id:
			continue
		var raw: PackedVector3Array = []
		for point: Array in edge["centerline"]:
			raw.append(Meshes.v3(point))
		var upper: bool = false
		for point: Vector3 in raw:
			upper = upper or point.y>.015
		var route: PackedVector3Array = []
		for point: Vector3 in Paths.sample(raw,.12):
			route.append(terrain.present(point,upper))
		return preload("res://tools/map_workshop/journey_routes.gd").around_stones(terrain,route)
	return []

func walk(route: PackedVector3Array, destination: Vector3) -> void:
	walking = true
	walker.visible = true
	if reduced_motion or route.is_empty():
		walker.position = parked(destination)
		walking = false
		return
	var points: PackedVector3Array = route
	curve = Curve3D.new()
	curve.bake_interval = .06
	for point: Vector3 in points:
		curve.add_point(point)
	walk_length = curve.get_baked_length()
	walk_speed = walk_length/clampf(walk_length/3.5,.7,4.5)
	distance_walked = 0
	await arrived

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not walking or curve==null:
		return
	distance_walked = minf(walk_length,distance_walked+delta*walk_speed)
	var at: Vector3 = curve.sample_baked(distance_walked)
	var ahead: Vector3 = curve.sample_baked(minf(walk_length,distance_walked+.08))
	walker.position = at
	if at.distance_to(ahead)>.001:
		walker.rotation.y = atan2(ahead.x-at.x,ahead.z-at.z)
	walker.pose(distance_walked,true)
	if distance_walked>=walk_length:
		walker.pose(0,false)
		walking = false
		arrived.emit()

func parked(at: Vector3) -> Vector3:
	var point: Vector3 = at+Vector3(.85,0,0)
	# A parked traveller stands on the same deck/land surface as the node.
	var raw: Vector3 = Vector3(point.x,0,point.z)
	point.y = terrain.present(raw).y
	return point

static func seat(surface: Terrain, source: Vector3) -> Vector3:
	var at: Vector3 = surface.present(source)
	for corner: int in range(8):
		var angle: float = corner*TAU/8
		at.y = maxf(at.y,surface.present(source+Vector3(cos(angle),0,sin(angle))*.38).y)
	return at
