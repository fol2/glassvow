extends RefCounted
## Sparse embedded fragments and fallen leaves, grouped along worn verges.
## These are local surface details, not another large-prop distribution pass.
const Meshes = preload("res://tools/map_workshop/mesh_tools.gd")
const Paths = preload("res://tools/map_workshop/road_paths.gd")

static func build(terrain: Node3D) -> void:
	var land: MeshInstance3D = terrain.get_node("Quiet sculpted ground") as MeshInstance3D
	var image: Image = land.material_override.get_meta("habitat_image")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 717071
	var stone: SurfaceTool = SurfaceTool.new()
	stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves: SurfaceTool = SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var groups: int = 0
	var fragments: int = 0
	var fallen: int = 0
	var slabs: int = 0
	var lines: Array[PackedVector3Array] = terrain.get("lines")
	for line: PackedVector3Array in lines:
		var points: PackedVector3Array = Paths.sample(line,.4)
		var next: float = rng.randf_range(.5,2)
		var distance: float = 0
		for i: int in range(points.size()-1):
			distance += points[i].distance_to(points[i+1])
			if distance<next:
				continue
			next = distance+rng.randf_range(1.4,3.6)
			var centre: Vector3 = points[i]
			var bank: float = terrain.call("stream_distance",centre.x,centre.z)
			if centre.y>.03 or bank<4.6:
				continue
			var side: Vector3 = (points[i+1]-centre).cross(Vector3.UP).normalized()
			var at: Vector3 = centre+side*rng.randf_range(.49,.82)*(-1 if rng.randf()<.5 else 1)
			var setting: Color = image.get_pixel(clampi(floori((at.x+48)*4),0,383),clampi(floori((at.z+30)*4),0,239))
			groups += 1
			# Short remnants of embedded slate break up the all-earth treatment.
			# Keep them quiet, part-buried, and biased towards nearby rock banks.
			if rng.randf()<.10+setting.g*.35:
				for n: int in range(rng.randi_range(2,5)):
					var p: Vector3 = centre+Vector3(rng.randf_range(-.5,.5),0,rng.randf_range(-.5,.5))
					var road: float = terrain.call("distance_to_roads",p)
					if road>.55:
						continue
					p.y = terrain.call("surface_height",p.x,p.z)
					_slate(stone,p,rng)
					slabs += 1
			for n: int in range(rng.randi_range(3,8)):
				var p: Vector3 = at+Vector3(rng.randf_range(-.32,.32),0,rng.randf_range(-.32,.32))
				var road: float = terrain.call("distance_to_roads",p)
				if road<.43 or road>1.1:
					continue
				p.y = terrain.call("surface_height",p.x,p.z)
				if rng.randf()<.30+setting.g*.50:
					_chip(stone,p,rng)
					fragments += 1
				if setting.r>.25:
					_leaf(leaves,p+Vector3(rng.randf_range(-.12,.12),.012,rng.randf_range(-.12,.12)),rng)
					fallen += 1
	var material: StandardMaterial3D = Meshes.material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	if fragments+slabs>0:
		Meshes.node(terrain,Meshes.finish(stone),material,"Embedded road fragments")
	if fallen>0:
		Meshes.node(terrain,Meshes.finish(leaves),material,"Fallen verge leaves").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print("ROAD_DETAILS ",JSON.stringify({"groups":groups,"fragments":fragments,"leaves":fallen,"slate_remnants":slabs}))

static func _slate(surface: SurfaceTool, at: Vector3, rng: RandomNumberGenerator) -> void:
	var radius: float = rng.randf_range(.10,.20)
	var yaw: float = rng.randf()*TAU
	var colour: Color = Color("514b4b").lerp(Color("453e43"),rng.randf())
	var ring: PackedVector3Array = []
	for i: int in range(6):
		var angle: float = yaw+TAU*i/6
		ring.append(at+Vector3(cos(angle)*radius*rng.randf_range(.8,1.3),.006,sin(angle)*radius*.67))
	for i: int in range(6):
		Meshes.triangle(surface,at+Vector3.UP*.022,ring[i],ring[(i+1)%6],colour)

static func _chip(surface: SurfaceTool, at: Vector3, rng: RandomNumberGenerator) -> void:
	var radius: float = rng.randf_range(.026,.073)
	var height: float = rng.randf_range(.012,.030)
	var yaw: float = rng.randf()*TAU
	var colour: Color = Color("615b5b").lerp(Color("454146"),rng.randf())
	var ring: PackedVector3Array = []
	for i: int in range(5):
		var angle: float = yaw+TAU*i/5
		ring.append(at+Vector3(cos(angle)*radius*rng.randf_range(.7,1.3),.007,sin(angle)*radius*.72))
	for i: int in range(5):
		Meshes.triangle(surface,at+Vector3.UP*height,ring[i],ring[(i+1)%5],colour)

static func _leaf(surface: SurfaceTool, at: Vector3, rng: RandomNumberGenerator) -> void:
	var length: float = rng.randf_range(.05,.105)
	var angle: float = rng.randf()*TAU
	var forward: Vector3 = Vector3(cos(angle),0,sin(angle))*length
	var side: Vector3 = forward.cross(Vector3.UP)*.42
	var colour: Color = Color("4c3037").lerp(Color("594447"),rng.randf())
	Meshes.triangle(surface,at-forward,at+side+Vector3.UP*.01,at+forward,colour)
	Meshes.triangle(surface,at-forward,at+forward,at-side,colour.darkened(.12))
