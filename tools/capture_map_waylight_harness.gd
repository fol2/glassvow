extends SceneTree
## Deterministic primitive-only visual harness for issue #473.

const EDGE: Dictionary = {"from": "a", "to": "b", "corridor_width": 1.0,
	"centerline": [[-4.0, 0.0, -2.0], [0.0, 0.0, -2.0],
		[0.0, 0.0, 2.0], [4.0, 0.0, 2.0]]}
const PROFILE_NAMES: PackedStringArray = ["phone-landscape", "pad-landscape"]
const PROFILE_SIZES: Array[Vector2i] = [Vector2i(844, 390), Vector2i(1180, 820)]
const STATES: Array[StringName] = [MapWaylightTracer.STATE_COLD,
	MapWaylightTracer.STATE_OPEN, MapWaylightTracer.STATE_WALKED]
const SETTLE_FRAMES: int = 4
var _output: String = ""
var _head: String = ""
var _tracer: MapWaylightTracer
var _label: Label
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			_output = arg.trim_prefix("--output=")
		elif arg.begins_with("--capture-head="):
			_head = arg.trim_prefix("--capture-head=")
	if _output.is_empty() or not _valid_sha(_head):
		printerr("capture_map_waylight_harness: needs --output and full --capture-head")
		quit(2)
		return
	_output = ProjectSettings.globalize_path(_output) if _output.begins_with("res://") else _output
	if DirAccess.make_dir_recursive_absolute(_output) != OK:
		quit(2)
		return
	_build_world()
	var frames: Array[Dictionary] = []
	for profile_index: int in range(PROFILE_NAMES.size()):
		var profile: String = PROFILE_NAMES[profile_index]
		var size: Vector2i = PROFILE_SIZES[profile_index]
		DisplayServer.window_set_size(size)
		root.size = size
		root.content_scale_size = size
		for state: StringName in STATES:
			_tracer.set_route_state(state)
			_label.text = "%s  ·  %s  ·  depth-tested world tracer" % [
				String(state).to_upper(), profile]
			for _frame: int in range(SETTLE_FRAMES):
				await process_frame
			var file: String = "%s_%s.png" % [profile, String(state)]
			var path: String = _output.path_join(file)
			var image: Image = root.get_texture().get_image()
			if image == null or image.save_png(path) != OK:
				quit(1)
				return
			frames.append({"file": file, "profile": profile, "state": String(state),
				"width": image.get_width(), "height": image.get_height(),
				"sha256": FileAccess.get_sha256(path)})
	var manifest: Dictionary = {"schema": 1, "issue": 473, "capture_head": _head,
		"godot": Engine.get_version_info()["string"], "route_digest": _tracer.geometry_digest(),
		"overhead": _tracer.overhead(), "frames": frames}
	var handle: FileAccess = FileAccess.open(_output.path_join("manifest.json"), FileAccess.WRITE)
	if handle == null:
		quit(1)
		return
	handle.store_string(JSON.stringify(manifest, "\t", true, true) + "\n")
	handle.close()
	print("capture_map_waylight_harness: %d exact-head frames" % frames.size())
	quit(0)
func _build_world() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.035, 0.075)
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	root.add_child(world_environment)
	var world: Node3D = Node3D.new()
	root.add_child(world)
	_box(world, Vector3(16.0, 0.18, 10.0), Vector3(0.0, -0.20, 0.0), Color(0.07, 0.09, 0.14))
	_box(world, Vector3(4.2, 0.14, 1.25), Vector3(-2.0, -0.07, -2.0), Color(0.27, 0.28, 0.31))
	_box(world, Vector3(1.25, 0.14, 4.2), Vector3(0.0, -0.07, 0.0), Color(0.27, 0.28, 0.31))
	_box(world, Vector3(4.2, 0.14, 1.25), Vector3(2.0, -0.07, 2.0), Color(0.27, 0.28, 0.31))
	_tracer = MapWaylightTracer.new()
	world.add_child(_tracer)
	_tracer.configure_route(EDGE, MapWaylightTracer.STATE_COLD)
	_box(world, Vector3(1.45, 1.9, 1.55), Vector3(0.0, 0.95, 0.15), Color(0.13, 0.15, 0.20))
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.5
	camera.position = Vector3(8.0, 9.0, 10.0)
	world.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true
	_label = Label.new()
	_label.position = Vector2(18.0, 14.0)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(0.90, 0.93, 1.0))
	root.add_child(_label)
func _box(parent: Node3D, size: Vector3, position: Vector3, color: Color) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = position
	parent.add_child(node)
func _valid_sha(value: String) -> bool:
	if value.length() != 40:
		return false
	for i: int in range(value.length()):
		if "0123456789abcdef".find(value.substr(i, 1)) < 0:
			return false
	return true
