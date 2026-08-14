class_name MapScene
extends Control
## Standalone 3D map surface for one act (#234 slice 1).
##
## Instantiable without a WorldMap. The live 2D `WorldMapScreen` is not
## replaced here — swap-over is a later slice. Geometry is placeholder
## primitives; the #255 cel/triplanar pair is wired in slice 2.
##
## Freeze is a switch, not a scene-graph assumption (#207 decision 10). Rest
## is `UPDATE_ONCE` (one paint, then sleep). Call `set_live(true)` while the
## camera moves; `set_live(false)` re-arms a single frame at the new pose —
## the same contract as `presentation/combat/card_view.gd` `_set_live`.

const OVERSAMPLE: float = 1.0
const VP_MAX: int = 2048
const GROUND_SIZE: Vector2 = Vector2(48.0, 34.0)
const SUN_TO: Vector3 = Vector3(-0.35, 0.78, 0.52)
const PLACEHOLDER_GROUND: Color = Color(0.22, 0.28, 0.24)
const SKY: Color = Color(0.018, 0.022, 0.045)

var _stage: SubViewport
var _display: TextureRect
var _rig: MapCameraRig
var _key: DirectionalLight3D
var _dragging: bool = false


func _init() -> void:
	name = "MapScene"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_stage = SubViewport.new()
	_stage.name = "MapStage"
	_stage.own_world_3d = true
	_stage.transparent_bg = false
	_stage.size = Vector2i(64, 64)
	_stage.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_stage)
	var world: Node3D = Node3D.new()
	world.name = "MapWorld"
	_stage.add_child(world)
	_rig = MapCameraRig.new()
	world.add_child(_rig)
	_add_key(world)
	_add_environment(world)
	_add_ground(world)
	_display = TextureRect.new()
	_display.name = "MapDisplay"
	_display.texture = _stage.get_texture()
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_display)


func _ready() -> void:
	_fit()
	resized.connect(_fit)


func get_rig() -> MapCameraRig:
	return _rig


func get_stage() -> SubViewport:
	return _stage


func get_key() -> DirectionalLight3D:
	return _key


func is_live() -> bool:
	return _stage.render_target_update_mode == SubViewport.UPDATE_ALWAYS


func set_live(on: bool) -> void:
	_stage.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_ONCE)


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		if button.pressed and button.button_index in [
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var inward: int = -1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			_rig.nudge_zoom(inward)
			set_live(false)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
			set_live(button.pressed)
			accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _dragging:
		_rig.pan_screen(motion.relative, _view_height())
		accept_event()
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		_dragging = touch.pressed
		set_live(touch.pressed)
		accept_event()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and _dragging:
		_rig.pan_screen(drag.relative, _view_height())
		accept_event()


func _fit() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var next: Vector2i = Vector2i(
			mini(maxi(int(size.x * OVERSAMPLE), 1), VP_MAX),
			mini(maxi(int(size.y * OVERSAMPLE), 1), VP_MAX))
	if _stage.size == next:
		return
	_stage.size = next
	if not is_live():
		set_live(false)


func _view_height() -> float:
	return float(_stage.size.y) if _stage.size.y > 0 else maxf(size.y, 1.0)


func _add_key(world: Node3D) -> void:
	_key = DirectionalLight3D.new()
	_key.name = "MapKey"
	_key.shadow_enabled = false
	_key.basis = Basis.looking_at(-SUN_TO.normalized(), Vector3.UP)
	world.add_child(_key)


func _add_environment(world: Node3D) -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "MapEnvironment"
	world_environment.environment = environment
	world.add_child(world_environment)


func _add_ground(world: Node3D) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = GROUND_SIZE
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = PLACEHOLDER_GROUND
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "TerrainPlaceholder"
	ground.mesh = plane
	ground.material_override = material
	world.add_child(ground)
