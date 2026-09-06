extends Node
## Half-resolution planar geometry reflection with a clipped, water-free scene.
## Reflection colour is deliberately simplified; main-scene materials stay intact.
var source_camera: Camera3D
var water: ShaderMaterial
var stage: SubViewport
var mirror: Camera3D
var copies: int = 0
var groups: Dictionary = {}

func build(source: Node3D,camera: Camera3D,material: ShaderMaterial) -> void:
	source_camera = camera
	water = material
	stage = SubViewport.new()
	stage.own_world_3d = true
	stage.size = Vector2i(get_viewport().get_visible_rect().size*.5)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var reflected: Node3D = Node3D.new()
	stage.add_child(reflected)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("102733")
	reflected.add_child(environment)
	_copy(source,reflected)
	for key: String in groups:
		var group: Dictionary = groups[key]
		if group.get("vertices",0)==0:
			continue
		var surface: SurfaceTool = group["surface"]
		var copy: MeshInstance3D = MeshInstance3D.new()
		copy.mesh = surface.commit()
		copy.material_override = group["material"]
		reflected.add_child(copy)
	mirror = Camera3D.new()
	reflected.add_child(mirror)
	mirror.current = true
	water.set_shader_parameter("reflection_texture",stage.get_texture())
	water.set_shader_parameter("has_reflection",true)
	_sync()
	print("ACT_II_PLANAR_REFLECTION meshes=",copies," batches=",groups.size()," size=",stage.size)

func _copy(source: Node,parent: Node3D) -> void:
	if source is MeshInstance3D and source.name not in ["FloodBed","FloodWater"]:
		var original: MeshInstance3D = source
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = preload("res://tools/map_workshop/act2/reflection.gdshader")
		var colour: Color = Color("48576a")
		if original.material_override is StandardMaterial3D:
			var source_material: StandardMaterial3D = original.material_override
			colour = source_material.albedo_color
		elif original.material_override is ShaderMaterial:
			var source_material: ShaderMaterial = original.material_override
			if source_material.shader.resource_path.contains("glass"):
				colour = Color("196887")
		material.set_shader_parameter("colour",colour)
		var key: String = colour.to_html()
		if not groups.has(key):
			var new_surface: SurfaceTool = SurfaceTool.new()
			new_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"surface":new_surface,"material":material,"vertices":0}
		var surface: SurfaceTool = groups[key]["surface"]
		var faces: PackedVector3Array = original.mesh.get_faces()
		for i: int in range(0,faces.size(),3):
			var a: Vector3 = original.global_transform*faces[i]
			var b: Vector3 = original.global_transform*faces[i+1]
			var c: Vector3 = original.global_transform*faces[i+2]
			if maxf(a.y,maxf(b.y,c.y))<1.18:
				continue
			var count: int = groups[key]["vertices"]
			groups[key]["vertices"] = count+3
			for point: Vector3 in [a,b,c]:
				surface.add_vertex(point)
		copies += 1
	for child: Node in source.get_children():
		_copy(child,parent)

func _process(_delta: float) -> void:
	if is_instance_valid(mirror):
		_sync()

func _sync() -> void:
	stage.size = Vector2i(get_viewport().get_visible_rect().size*.5)
	mirror.projection = source_camera.projection
	mirror.size = source_camera.size
	mirror.near = source_camera.near
	mirror.far = source_camera.far
	var position: Vector3 = source_camera.global_position
	position.y = 2*1.18-position.y
	var forward: Vector3 = -source_camera.global_basis.z
	var up: Vector3 = source_camera.global_basis.y
	forward.y = -forward.y
	up.y = -up.y
	mirror.look_at_from_position(position,position+forward,up)
	var matrix: Projection = mirror.get_camera_projection()*Projection(mirror.global_transform.affine_inverse())
	water.set_shader_parameter("reflection_matrix",matrix)
