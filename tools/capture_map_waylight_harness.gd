extends SceneTree
## Deterministic primitive-only visual harness for issue #473.
## Fixed SubViewports make GPU evidence independent of host-window resize state.

const EDGE: Dictionary = {"from": "a", "to": "b", "corridor_width": 1.0,
	"centerline": [[-4.0, 0.0, -2.0], [0.0, 0.0, -2.0],
		[0.0, 0.0, 2.0], [4.0, 0.0, 2.0]]}
const PROFILE_NAMES: PackedStringArray = ["phone-landscape", "pad-landscape"]
const PROFILE_SIZES: Array[Vector2i] = [Vector2i(844, 390), Vector2i(1180, 820)]
const STATES: Array[StringName] = [MapWaylightTracer.STATE_COLD,
	MapWaylightTracer.STATE_OPEN, MapWaylightTracer.STATE_WALKED]
const BACKGROUND: Color = Color(0.025, 0.035, 0.075, 1.0)
const SETTLE_FRAMES: int = 6
const SAMPLE_STRIDE: int = 4
const FOREGROUND_DELTA: float = 0.025
const STATE_DELTA: float = 0.04
const MIN_FOREGROUND_RATIO: float = 0.05
const MIN_STATE_DELTA_RATIO: float = 0.0005
const MAX_NEAR_WHITE_RATIO: float = 0.01

var _output: String = ""
var _head: String = ""


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
		printerr("capture_map_waylight_harness: cannot create %s" % _output)
		quit(2)
		return
	await _capture_all()


func _capture_all() -> void:
	var frames: Array[Dictionary] = []
	var profile_deltas: Array[Dictionary] = []
	var route_digest: String = ""
	var overhead: Dictionary = {}
	for profile_index: int in range(PROFILE_NAMES.size()):
		var profile: String = PROFILE_NAMES[profile_index]
		var size: Vector2i = PROFILE_SIZES[profile_index]
		var stage: Dictionary = _make_stage(size)
		var viewport_v: Variant = stage.get("viewport")
		if not (viewport_v is SubViewport):
			printerr("capture_map_waylight_harness: viewport creation failed for %s" % profile)
			quit(1)
			return
		var viewport: SubViewport = viewport_v
		var tracer_v: Variant = stage.get("tracer")
		if not (tracer_v is MapWaylightTracer):
			printerr("capture_map_waylight_harness: tracer creation failed for %s" % profile)
			quit(1)
			return
		var tracer: MapWaylightTracer = tracer_v
		if route_digest.is_empty():
			route_digest = tracer.geometry_digest()
			overhead = tracer.overhead()
		elif route_digest != tracer.geometry_digest() or overhead != tracer.overhead():
			printerr("capture_map_waylight_harness: profile geometry drift")
			quit(1)
			return
		var images: Array[Image] = []
		for state: StringName in STATES:
			if not tracer.set_route_state(state):
				printerr("capture_map_waylight_harness: state update failed: %s" % state)
				quit(1)
				return
			var image: Image = await _capture(viewport)
			if image == null or image.get_width() != size.x or image.get_height() != size.y:
				printerr("capture_map_waylight_harness: invalid %s %s frame" % [profile, state])
				quit(1)
				return
			var metrics: Dictionary = _frame_metrics(image)
			if MapLayoutCanonical.float_value(metrics.get("foreground_ratio", 0.0)) \
					< MIN_FOREGROUND_RATIO:
				printerr("capture_map_waylight_harness: blank 3D frame %s %s" % [profile, state])
				quit(1)
				return
			if MapLayoutCanonical.float_value(metrics.get("near_white_ratio", 0.0)) \
					> MAX_NEAR_WHITE_RATIO:
				printerr("capture_map_waylight_harness: suspicious white frame %s %s" % [profile, state])
				quit(1)
				return
			var file: String = "%s_%s.png" % [profile, String(state)]
			var path: String = _output.path_join(file)
			if image.save_png(path) != OK:
				printerr("capture_map_waylight_harness: save failed %s" % path)
				quit(1)
				return
			images.append(image)
			frames.append({"file": file, "profile": profile, "state": String(state),
				"width": image.get_width(), "height": image.get_height(),
				"sha256": FileAccess.get_sha256(path),
				"foreground_ratio": metrics["foreground_ratio"],
				"near_white_ratio": metrics["near_white_ratio"]})
		var cold_open: float = _difference_ratio(images[0], images[1])
		var open_walked: float = _difference_ratio(images[1], images[2])
		var cold_walked: float = _difference_ratio(images[0], images[2])
		if cold_open < MIN_STATE_DELTA_RATIO or open_walked < MIN_STATE_DELTA_RATIO \
				or cold_walked < MIN_STATE_DELTA_RATIO:
			printerr("capture_map_waylight_harness: state hierarchy invisible for %s" % profile)
			quit(1)
			return
		profile_deltas.append({"profile": profile, "cold_open_ratio": cold_open,
			"open_walked_ratio": open_walked, "cold_walked_ratio": cold_walked})
		viewport.queue_free()
		await process_frame
	var manifest: Dictionary = {"schema": 2, "issue": 473, "capture_head": _head,
		"godot": Engine.get_version_info()["string"], "route_digest": route_digest,
		"overhead": overhead, "frames": frames, "profile_state_deltas": profile_deltas,
		"validation": {"sample_stride": SAMPLE_STRIDE,
			"minimum_foreground_ratio": MIN_FOREGROUND_RATIO,
			"minimum_state_delta_ratio": MIN_STATE_DELTA_RATIO,
			"maximum_near_white_ratio": MAX_NEAR_WHITE_RATIO}}
	var handle: FileAccess = FileAccess.open(_output.path_join("manifest.json"), FileAccess.WRITE)
	if handle == null:
		printerr("capture_map_waylight_harness: manifest open failed")
		quit(1)
		return
	handle.store_string(JSON.stringify(manifest, "\t", true, true) + "\n")
	handle.close()
	print("capture_map_waylight_harness: %d validated exact-head frames" % frames.size())
	quit(0)


func _make_stage(size: Vector2i) -> Dictionary:
	var viewport: SubViewport = SubViewport.new()
	viewport.name = "WaylightEvidenceViewport"
	viewport.size = size
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.positional_shadow_atlas_size = 0
	root.add_child(viewport)
	var world: Node3D = Node3D.new()
	world.name = "World"
	viewport.add_child(world)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	_box(world, Vector3(16.0, 0.18, 10.0), Vector3(0.0, -0.20, 0.0),
		Color(0.07, 0.09, 0.14))
	_box(world, Vector3(4.2, 0.14, 1.25), Vector3(-2.0, -0.07, -2.0),
		Color(0.27, 0.28, 0.31))
	_box(world, Vector3(1.25, 0.14, 4.2), Vector3(0.0, -0.07, 0.0),
		Color(0.27, 0.28, 0.31))
	_box(world, Vector3(4.2, 0.14, 1.25), Vector3(2.0, -0.07, 2.0),
		Color(0.27, 0.28, 0.31))
	var tracer: MapWaylightTracer = MapWaylightTracer.new()
	world.add_child(tracer)
	if not tracer.configure_route(EDGE, MapWaylightTracer.STATE_COLD):
		viewport.queue_free()
		return {}
	_box(world, Vector3(1.45, 1.9, 1.55), Vector3(0.0, 0.95, 0.15),
		Color(0.13, 0.15, 0.20))
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 9.5
	camera.look_at_from_position(
		Vector3(8.0, 9.0, 10.0),
		Vector3.ZERO,
		Vector3.UP
	)
	world.add_child(camera)
	camera.current = true
	return {"viewport": viewport, "tracer": tracer}


func _capture(viewport: SubViewport) -> Image:
	for _frame: int in range(SETTLE_FRAMES):
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var texture: ViewportTexture = viewport.get_texture()
	if texture == null:
		return null
	return texture.get_image()


func _frame_metrics(image: Image) -> Dictionary:
	var sampled: int = 0
	var foreground: int = 0
	var near_white: int = 0
	for y: int in range(0, image.get_height(), SAMPLE_STRIDE):
		for x: int in range(0, image.get_width(), SAMPLE_STRIDE):
			var pixel: Color = image.get_pixel(x, y)
			sampled += 1
			var delta: float = maxf(absf(pixel.r - BACKGROUND.r),
				maxf(absf(pixel.g - BACKGROUND.g), absf(pixel.b - BACKGROUND.b)))
			if delta > FOREGROUND_DELTA:
				foreground += 1
			if pixel.r > 0.97 and pixel.g > 0.97 and pixel.b > 0.97:
				near_white += 1
	return {"foreground_ratio": float(foreground) / float(sampled),
		"near_white_ratio": float(near_white) / float(sampled)}


func _difference_ratio(left: Image, right: Image) -> float:
	if left.get_size() != right.get_size():
		return 0.0
	var sampled: int = 0
	var changed: int = 0
	for y: int in range(0, left.get_height(), SAMPLE_STRIDE):
		for x: int in range(0, left.get_width(), SAMPLE_STRIDE):
			var a: Color = left.get_pixel(x, y)
			var b: Color = right.get_pixel(x, y)
			sampled += 1
			var delta: float = maxf(absf(a.r - b.r),
				maxf(absf(a.g - b.g), absf(a.b - b.b)))
			if delta > STATE_DELTA:
				changed += 1
	return float(changed) / float(sampled)


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
