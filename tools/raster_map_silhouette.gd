extends SceneTree
## Godot GPU silhouette raster and 20-placement review capture (#292).
##
## Imports a kit GLB, renders eight Y-rotation alpha masks at
## MapCameraRig.TILT_DEGREES and widest zoom stop 28, at authored metre scale,
## against a transparent target. Optional --review= writes a 5×4 lit-clay
## grid (same seed 292 yaws) a human can actually read. Never --headless
## if the dummy renderer returns an empty mask — the Python gate retries headed.
##
##   godot --path . --position -4000,-4000 -s res://tools/raster_map_silhouette.gd -- \
##     --glb=res://assets/art/map/geometry/shared/road-slab-a.glb --out=/tmp/sil \
##     --review=res://docs/reviews/292/road-slab-a-20.png

const MASK_SIZE: Vector2i = Vector2i(1024, 1024)
const REVIEW_SIZE: Vector2i = Vector2i(1280, 720)
const WIDEST_STOP: int = 3
const REVIEW_STOP: int = 2
const YAW_STEP_DEG: int = 45
const PLACEMENTS: int = 20
const PLACEMENT_SEED: int = 292
const MASK_FRAMES: int = 6
const SILHOUETTE_SHADER: String = """shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
void fragment() { ALBEDO = vec3(1.0); ALPHA = 1.0; }
"""


func _initialize() -> void:
	var opts: Dictionary = _parse(OS.get_cmdline_user_args())
	if opts.is_empty():
		printerr("raster_map_silhouette: --glb= and --out= are required")
		quit(1)
		return
	await _run(opts)


func _run(opts: Dictionary) -> void:
	var glb: String = str(opts["glb"])
	var out_dir: String = str(opts["out"])
	var mesh: Mesh = _load_mesh(glb)
	if mesh == null:
		printerr("raster_map_silhouette: no mesh in %s" % glb)
		quit(1)
		return
	var tris: int = _triangle_count(mesh)
	var surfaces: int = mesh.get_surface_count()
	if DirAccess.make_dir_recursive_absolute(out_dir) != OK:
		printerr("raster_map_silhouette: cannot create %s" % out_dir)
		quit(1)
		return
	var sil_mat: ShaderMaterial = _silhouette_material()
	var mask_viewport: SubViewport = _make_stage(MASK_SIZE, true)
	var mask_world: Node3D = _stage_world(mask_viewport)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "Subject"
	instance.mesh = mesh
	instance.material_override = sil_mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mask_world.add_child(instance)
	var views: Array[Dictionary] = []
	var yaw: int = 0
	while yaw < 360:
		instance.rotation_degrees = Vector3(0.0, float(yaw), 0.0)
		var image: Image = await _capture(mask_viewport, MASK_FRAMES)
		if image == null:
			printerr("raster_map_silhouette: empty mask at yaw %d" % yaw)
			quit(1)
			return
		var png: String = "%s/rot-%03d.png" % [out_dir, yaw]
		if image.save_png(png) != OK:
			printerr("raster_map_silhouette: save failed %s" % png)
			quit(1)
			return
		var opaque: int = _opaque_count(image)
		views.append({"deg": yaw, "opaque": opaque, "png": "rot-%03d.png" % yaw})
		yaw += YAW_STEP_DEG
	var review_rel: String = str(opts.get("review", ""))
	if review_rel != "":
		var review_path: String = _absolute(review_rel)
		var parent: String = review_path.get_base_dir()
		if DirAccess.make_dir_recursive_absolute(parent) != OK:
			printerr("raster_map_silhouette: cannot create %s" % parent)
			quit(1)
			return
		var review_viewport: SubViewport = _make_stage(REVIEW_SIZE, false)
		var review_world: Node3D = _stage_world(review_viewport)
		_add_review_light(review_world)
		_add_ground(review_world)
		_add_placements(review_world, mesh, _clay_material())
		var review_image: Image = await _capture(review_viewport, MASK_FRAMES)
		if review_image == null or review_image.save_png(review_path) != OK:
			printerr("raster_map_silhouette: review capture failed")
			quit(1)
			return
		print("raster_map_silhouette: review %dx%d -> %s" % [
				review_image.get_width(), review_image.get_height(), review_path])
	var report: Dictionary = {
		"glb": glb,
		"triangles": tris,
		"surfaces": surfaces,
		"tilt_degrees": MapCameraRig.TILT_DEGREES,
		"zoom_size": MapCameraRig.ZOOM_STOPS[WIDEST_STOP],
		"views": views,
	}
	var report_path: String = "%s/raster-report.json" % out_dir
	var report_file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if report_file == null:
		printerr("raster_map_silhouette: cannot write %s" % report_path)
		quit(1)
		return
	report_file.store_string(JSON.stringify(report))
	report_file.close()
	print("raster_map_silhouette: OK tris=%d surfaces=%d views=%d -> %s" % [
			tris, surfaces, views.size(), out_dir])
	quit(0)


func _parse(args: PackedStringArray) -> Dictionary:
	var opts: Dictionary = {}
	for arg: String in args:
		if arg.begins_with("--glb="):
			opts["glb"] = arg.substr(6)
		elif arg.begins_with("--out="):
			opts["out"] = arg.substr(6)
		elif arg.begins_with("--review="):
			opts["review"] = arg.substr(9)
	if not opts.has("glb") or not opts.has("out"):
		return {}
	return opts


func _make_stage(size: Vector2i, transparent: bool) -> SubViewport:
	var viewport: SubViewport = SubViewport.new()
	viewport.name = "SilhouetteStage"
	viewport.size = size
	viewport.own_world_3d = true
	viewport.transparent_bg = transparent
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.positional_shadow_atlas_size = 0
	root.add_child(viewport)
	var world: Node3D = Node3D.new()
	world.name = "World"
	viewport.add_child(world)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0) if transparent \
			else Color(0.14, 0.15, 0.16, 1.0)
	if transparent:
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	else:
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.32, 0.33, 0.34)
		environment.ambient_light_energy = 0.28
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var rig: MapCameraRig = MapCameraRig.new()
	world.add_child(rig)
	rig.pan_bounds = Rect2(-100.0, -100.0, 200.0, 200.0)
	rig.set_zoom_stop(REVIEW_STOP if not transparent else WIDEST_STOP)
	rig.set_camera_xz(MapCameraRig.pose_for_world(Vector3.ZERO))
	rig.get_camera().current = true
	return viewport


func _stage_world(viewport: SubViewport) -> Node3D:
	var node: Node = viewport.get_node("World")
	if node is Node3D:
		var world: Node3D = node
		return world
	var fallback: Node3D = Node3D.new()
	fallback.name = "World"
	viewport.add_child(fallback)
	return fallback


func _capture(viewport: SubViewport, frames: int) -> Image:
	var i: int = 0
	while i < frames:
		await process_frame
		i += 1
	var texture: ViewportTexture = viewport.get_texture()
	if texture == null:
		return null
	return texture.get_image()


func _load_mesh(path: String) -> Mesh:
	var res_path: String = path
	if not res_path.begins_with("res://") and not res_path.begins_with("/"):
		res_path = "res://" + res_path
	if ResourceLoader.exists(res_path):
		var loaded: Resource = ResourceLoader.load(res_path)
		var from_resource: Mesh = _mesh_from_resource(loaded)
		if from_resource != null:
			return from_resource
	var abs_path: String = _absolute(path)
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	if document.append_from_file(abs_path, state) != OK:
		return null
	var generated: Node = document.generate_scene(state)
	if generated == null:
		return null
	var mesh: Mesh = _mesh_from_node(generated)
	generated.free()
	return mesh


func _mesh_from_resource(resource: Resource) -> Mesh:
	if resource is Mesh:
		return resource as Mesh
	if not (resource is PackedScene):
		return null
	var instance: Node = (resource as PackedScene).instantiate()
	var mesh: Mesh = _mesh_from_node(instance)
	instance.free()
	return mesh


func _mesh_from_node(root: Node) -> Mesh:
	var mesh_node: MeshInstance3D = _first_mesh(root)
	if mesh_node == null:
		return null
	return mesh_node.mesh


func _first_mesh(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root as MeshInstance3D
	for child: Node in root.get_children():
		var found: MeshInstance3D = _first_mesh(child)
		if found != null:
			return found
	return null


func _triangle_count(mesh: Mesh) -> int:
	var total: int = 0
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if indices is PackedInt32Array:
			var packed: PackedInt32Array = indices
			total += packed.size() / 3
			continue
		var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
		if vertices is PackedVector3Array:
			var points: PackedVector3Array = vertices
			total += points.size() / 3
	return total


func _silhouette_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = SILHOUETTE_SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material


func _clay_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.albedo_color = Color(0.68, 0.68, 0.70)
	material.roughness = 0.82
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


func _add_review_light(world: Node3D) -> void:
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.name = "ReviewKey"
	key.rotation_degrees = Vector3(-52.0, 38.0, 0.0)
	key.light_energy = 0.72
	key.shadow_enabled = false
	world.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "ReviewFill"
	fill.rotation_degrees = Vector3(-18.0, -70.0, 0.0)
	fill.light_energy = 0.22
	fill.shadow_enabled = false
	world.add_child(fill)


func _add_ground(world: Node3D) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(48.0, 24.0)
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "ReviewGround"
	ground.mesh = plane
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.18, 0.19, 0.20)
	ground.material_override = material
	world.add_child(ground)


func _add_placements(world: Node3D, mesh: Mesh, material: Material) -> void:
	# 5×4 lattice so a human can read each module. Seed 292 still picks yaw
	# and scale; position is no longer a distant scatter of unreadable dots.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = PLACEMENT_SEED
	const COLS: int = 5
	const ROWS: int = 4
	const GAP: float = 2.6
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = PLACEMENTS
	for i: int in range(PLACEMENTS):
		var col: int = i % COLS
		var row: int = i / COLS
		var yaw: float = rng.randf() * TAU
		var scale: float = 0.82 + rng.randf() * 0.27
		var origin: Vector3 = Vector3(
				(float(col) - 2.0) * GAP,
				0.0,
				(float(row) - 1.5) * GAP)
		var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3(scale, scale, scale))
		multimesh.set_instance_transform(i, Transform3D(basis, origin))
	var instances: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instances.name = "ReviewPlacements"
	instances.multimesh = multimesh
	instances.material_override = material
	instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(instances)


func _opaque_count(image: Image) -> int:
	var count: int = 0
	var size: Vector2i = image.get_size()
	var y: int = 0
	while y < size.y:
		var x: int = 0
		while x < size.x:
			if image.get_pixel(x, y).a >= 0.5:
				count += 1
			x += 1
		y += 1
	return count


func _absolute(path: String) -> String:
	if path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	if path.begins_with("/"):
		return path
	return ProjectSettings.globalize_path("res://").path_join(path)


