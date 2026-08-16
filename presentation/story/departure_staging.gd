class_name DepartureStaging
extends Control
## L0 every-departure plant (00-truth §5, 07-scenes §2): camera lingers a
## beat on the hearth, the window reflection lags half a beat. Art-gated —
## no plate, no linger. Run 1 rides the opening's beats ③–④; this screen
## is the run 2+ home, fired on the Embark → run transition.

signal finished

const HEARTH_PLATE: String = "res://assets/art/scenes/opening-hearth.png"
const HEARTH_HOLD: float = 1.0
const WINDOW_LAG: float = 0.5

var instant: bool = false
var hearth_plate: String = HEARTH_PLATE
var _done: bool = false
var _plant: TextureRect = null
var _window: TextureRect = null


func _init(plate: String = HEARTH_PLATE) -> void:
	hearth_plate = plate
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = GlassStyle.theme()
	var ground: TextureRect = TextureRect.new()
	ground.texture = GlassStyle.grad_tex(
		PackedColorArray([GlassStyle.NIGHT_TOP, GlassStyle.NIGHT_BOT]),
		PackedFloat32Array([0.0, 1.0]), false, Vector2(0.5, 0.0), Vector2(0.5, 1.0))
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.stretch_mode = TextureRect.STRETCH_SCALE
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.name = "Ground"
	add_child(ground)


func _ready() -> void:
	if instant or not ResourceLoader.exists(hearth_plate):
		_complete()
		return
	_plant = _overlay("HearthPlant", 1.0)
	_window = _overlay("HearthWindow",
		0.45 if Preferences.active.reduce_motion else 0.0)
	_window.flip_h = true
	if HearthFigure.present():
		HearthFigure.attach(_plant, false)
		HearthFigure.attach(_window, true)
	Motion.bez(self, _tick_window, HEARTH_HOLD, Motion.CSS_EASE) \
		.finished.connect(_complete)


func _overlay(node_name: String, alpha: float) -> TextureRect:
	var plate: TextureRect = TextureRect.new()
	plate.name = node_name
	plate.texture = load(hearth_plate) as Texture2D
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.modulate.a = alpha
	add_child(plate)
	return plate


func _tick_window(u: float) -> void:
	if _window == null or Preferences.active.reduce_motion:
		return
	var elapsed: float = u * HEARTH_HOLD
	_window.modulate.a = 0.45 * clampf(
		(elapsed - WINDOW_LAG) / maxf(HEARTH_HOLD - WINDOW_LAG, 0.01), 0.0, 1.0)


func _complete() -> void:
	if _done:
		return
	_done = true
	finished.emit()
