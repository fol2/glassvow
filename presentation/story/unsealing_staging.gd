class_name UnsealingStaging
extends Control
## Per-scene presentation for `unsealing` (07-scenes §1, §8). The machine
## owns sequence; this only dresses beats that name no plate.
##
## Beat 1: sixth pane lights on the shipped mural/masks/frame.
## Beat 2: the window fully lit — 窗全亮的一刻.
## Beat 3+: hide. ScenePlayer binds the one-queue plate; this never stamps
## the crowd per pane (#263 Q13).

const NAME: String = "UnsealingRose"
const DESIGN: float = 520.0
const SIXTH: int = 5
const LIGHT_TIME: float = 0.55

var _slot: Control
var _window: Control
var _panes: Array[TextureRect] = []
var _beat_i: int = -1
var _light: Tween = null


func _init() -> void:
	name = NAME
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func present(beat_i: int, instant: bool) -> void:
	_beat_i = beat_i
	if beat_i < 0 or beat_i > 1:
		visible = false
		_kill_light()
		return
	visible = true
	_layout_rose()
	if beat_i >= 1:
		_kill_light()
		_set_sixth(1.0)
		return
	if instant:
		_kill_light()
		_set_sixth(1.0)
		return
	_set_sixth(0.0)
	_light = Motion.bez(self, _set_sixth, LIGHT_TIME, Motion.CSS_EASE)


func mural_is_emberglass() -> bool:
	for pane: TextureRect in _panes:
		var material: ShaderMaterial = pane.material as ShaderMaterial
		if material == null:
			return false
		var mural_v: Variant = material.get_shader_parameter("mural")
		if not (mural_v is Texture2D):
			return false
		var mural: Texture2D = mural_v
		if mural.resource_path != RoseWindowView.MURAL:
			return false
	return _panes.size() == RoseWindowView.IDS.size()


func mural_on_count() -> int:
	var n: int = 0
	for pane: TextureRect in _panes:
		var material: ShaderMaterial = pane.material as ShaderMaterial
		if material == null:
			continue
		var shown: Variant = material.get_shader_parameter("show_mural")
		if shown == true:
			n += 1
	return n


func sixth_alpha() -> float:
	if SIXTH < 0 or SIXTH >= _panes.size():
		return 0.0
	return _panes[SIXTH].modulate.a


func _build() -> void:
	_slot = Control.new()
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slot)
	_window = Control.new()
	_window.size = Vector2.ONE * DESIGN
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.add_child(_window)
	var backdrop: TextureRect = TextureRect.new()
	backdrop.texture = GlassStyle.grad_tex(
		PackedColorArray([
			Color("#1d1f30"), Color("#05070e"), Color(0.02, 0.03, 0.06, 0.0)]),
		PackedFloat32Array([0.0, 0.86, 1.0]), true,
		Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(backdrop)
	var mural: Texture2D = load(RoseWindowView.MURAL) as Texture2D
	for index: int in range(RoseWindowView.IDS.size()):
		var id: String = RoseWindowView.IDS[index]
		var pane: TextureRect = TextureRect.new()
		pane.name = "Pane%d" % index
		pane.texture = load(RoseWindowView.MASK % id) as Texture2D
		pane.set_anchors_preset(Control.PRESET_FULL_RECT)
		pane.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pane.stretch_mode = TextureRect.STRETCH_SCALE
		pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = RoseWindowView.PANE_SHADER
		material.set_shader_parameter("mural", mural)
		material.set_shader_parameter("show_mural", true)
		pane.material = material
		_window.add_child(pane)
		_panes.append(pane)
	var frame: TextureRect = TextureRect.new()
	frame.name = "Frame"
	frame.texture = load(RoseWindowView.FRAME) as Texture2D
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(frame)
	resized.connect(_layout_rose)


func _set_sixth(u: float) -> void:
	if SIXTH < 0 or SIXTH >= _panes.size():
		return
	_panes[SIXTH].modulate.a = clampf(u, 0.0, 1.0)


func _kill_light() -> void:
	if _light != null:
		_light.kill()
		_light = null


func _layout_rose() -> void:
	var host: Vector2 = size
	if host.x < 1.0 or host.y < 1.0:
		return
	var diameter: float = clampf(minf(host.x, host.y) * 0.64, 250.0, DESIGN)
	_slot.size = Vector2.ONE * diameter
	_slot.position = (host - _slot.size) * 0.5
	_window.size = Vector2.ONE * DESIGN
	var scale_n: float = diameter / DESIGN
	_window.scale = Vector2.ONE * scale_n
	_window.pivot_offset = Vector2.ZERO
	_window.position = Vector2.ZERO
