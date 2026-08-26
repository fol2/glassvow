class_name MapWaylightTracer
extends MultiMeshInstance3D
## Depth-tested world-space state marker over one compiled routed-edge record.
## Route changes rebuild bounded instances; state changes only update buffers.

const STATE_COLD: StringName = &"cold"
const STATE_OPEN: StringName = &"open"
const STATE_WALKED: StringName = &"walked"
const SAMPLE_SPACING_M: float = 0.80
const SURFACE_LIFT_M: float = 0.055
const BEAD_RADIUS_M: float = 0.10
const BEAD_HEIGHT_M: float = 0.065
const MAX_INSTANCES: int = 128
const WORLD_EPSILON_M: float = 0.001
const COLD_COLOR: Color = Color(0.36, 0.44, 0.60, 1.0)

var _bead_mesh: CylinderMesh
var _waylight_material: StandardMaterial3D
var _geometry_digest: String = ""
var _geometry_builds: int = 0
var _state: StringName = STATE_COLD

func _init() -> void:
	name = "MapWaylightTracer"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bead_mesh = CylinderMesh.new()
	_bead_mesh.top_radius = BEAD_RADIUS_M
	_bead_mesh.bottom_radius = BEAD_RADIUS_M * 1.08
	_bead_mesh.height = BEAD_HEIGHT_M
	_bead_mesh.radial_segments = 8
	_bead_mesh.rings = 1
	_waylight_material = StandardMaterial3D.new()
	_waylight_material.albedo_color = Color.WHITE
	_waylight_material.vertex_color_use_as_albedo = true
	_waylight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_waylight_material.no_depth_test = false
	material_override = _waylight_material

func configure_route(edge_record: Dictionary, state: StringName = STATE_COLD) -> bool:
	if not is_route_state(state):
		return false
	var points: Array[Vector3] = _route_points(edge_record)
	if points.size() < 2 or not MapLayoutCanonical.number(edge_record.get("corridor_width", null), true):
		return false
	var transforms: Array[Transform3D] = _sample_transforms(points)
	if transforms.is_empty() or transforms.size() > MAX_INSTANCES:
		return false
	var identity: Dictionary = {"centerline": edge_record["centerline"],
		"corridor_width": edge_record["corridor_width"], "sample_spacing_m": SAMPLE_SPACING_M,
		"surface_lift_m": SURFACE_LIFT_M}
	var next_digest: String = MapLayoutCanonical.digest(MapLayoutCanonical.ordered_dictionary(identity))
	if next_digest != _geometry_digest:
		_rebuild(transforms)
		_geometry_digest = next_digest
	return set_route_state(state)

func set_route_state(state: StringName) -> bool:
	if not is_route_state(state) or multimesh == null:
		return false
	_state = state
	var count: int = multimesh.instance_count
	for i: int in range(count):
		var progress: float = 0.0 if count <= 1 else float(i) / float(count - 1)
		multimesh.set_instance_color(i, route_state_color(state))
		multimesh.set_instance_custom_data(i, Color(route_state_code(state), progress, 0.0, 1.0))
	return true

func geometry_digest() -> String:
	return _geometry_digest

func geometry_build_count() -> int:
	return _geometry_builds

func route_state() -> StringName:
	return _state

func overhead() -> Dictionary:
	return {"draw_calls": 1, "mesh_resources": 1, "material_resources": 1,
		"instance_count": 0 if multimesh == null else multimesh.instance_count,
		"max_instances": MAX_INSTANCES, "sample_spacing_m": SAMPLE_SPACING_M,
		"surface_lift_m": SURFACE_LIFT_M,
		"depth_test_enabled": not _waylight_material.no_depth_test,
		"depth_draw_disabled": _waylight_material.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_DISABLED}

static func is_route_state(state: StringName) -> bool:
	return state == STATE_COLD or state == STATE_OPEN or state == STATE_WALKED

static func route_state_code(state: StringName) -> float:
	match state:
		STATE_OPEN:
			return 0.5
		STATE_WALKED:
			return 1.0
		_:
			return 0.0

static func route_state_color(state: StringName) -> Color:
	match state:
		STATE_OPEN:
			return GlassStyle.EMBER
		STATE_WALKED:
			return GlassStyle.GOLD
		_:
			return COLD_COLOR

func _rebuild(transforms: Array[Transform3D]) -> void:
	var next: MultiMesh = MultiMesh.new()
	next.transform_format = MultiMesh.TRANSFORM_3D
	next.use_colors = true
	next.use_custom_data = true
	next.mesh = _bead_mesh
	next.instance_count = transforms.size()
	for i: int in range(transforms.size()):
		next.set_instance_transform(i, transforms[i])
	multimesh = next
	_geometry_builds += 1

static func _route_points(edge_record: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var rows_v: Variant = edge_record.get("centerline", null)
	if typeof(rows_v) != TYPE_ARRAY:
		return out
	var rows: Array = rows_v
	for row_v: Variant in rows:
		if typeof(row_v) != TYPE_ARRAY:
			out.clear()
			return out
		var row: Array = row_v
		if row.size() != 3 or not MapLayoutCanonical.number(row[0]) \
				or not MapLayoutCanonical.number(row[1]) or not MapLayoutCanonical.number(row[2]):
			out.clear()
			return out
		var point: Vector3 = Vector3(MapLayoutCanonical.float_value(row[0]),
			MapLayoutCanonical.float_value(row[1]), MapLayoutCanonical.float_value(row[2]))
		if out.is_empty() or out[-1].distance_to(point) > WORLD_EPSILON_M:
			out.append(point)
	return out

static func _sample_transforms(points: Array[Vector3]) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var total: float = 0.0
	for i: int in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	if total <= WORLD_EPSILON_M or int(ceil(total / SAMPLE_SPACING_M)) + 1 > MAX_INSTANCES:
		return out
	var distance: float = 0.0
	while distance < total - WORLD_EPSILON_M:
		out.append(Transform3D(Basis.IDENTITY,
			_point_at_distance(points, distance) + Vector3.UP * SURFACE_LIFT_M))
		distance += SAMPLE_SPACING_M
	var end: Vector3 = points[-1] + Vector3.UP * SURFACE_LIFT_M
	if out.is_empty() or out[-1].origin.distance_to(end) > WORLD_EPSILON_M:
		out.append(Transform3D(Basis.IDENTITY, end))
	return out

static func _point_at_distance(points: Array[Vector3], distance: float) -> Vector3:
	var remaining: float = distance
	for i: int in range(points.size() - 1):
		var span: float = points[i].distance_to(points[i + 1])
		if remaining <= span or i == points.size() - 2:
			return points[i].lerp(points[i + 1], clampf(remaining / span, 0.0, 1.0))
		remaining -= span
	return points[-1]
