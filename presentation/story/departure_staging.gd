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
## How far the reflection comes up once the lag is paid. Dark glass returns a
## fraction of the room, never a second room.
const REFLECT_ALPHA: float = 0.45

var instant: bool = false
var hearth_plate: String = HEARTH_PLATE
## Which reading of 窗中反影 to stage — see `WindowReflection`. #334 fork.
var route: StringName = WindowReflection.ROUTE_ROSE_FIGURE
var _done: bool = false
var _plant: TextureRect = null
var _reflection: WindowReflection = null


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
	# ONE plate and ONE body. The hall is never mirrored: what lags is the
	# reflection inside a single window (`docs/art-ledger.md:228-233`).
	_plant = TextureRect.new()
	_plant.name = "HearthPlant"
	_plant.texture = load(hearth_plate) as Texture2D
	_plant.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plant.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plant.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_plant.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plant)
	if HearthFigure.present():
		HearthFigure.attach(_plant)
	_reflection = WindowReflection.new(route)
	_reflection.modulate.a = REFLECT_ALPHA if Preferences.active.reduce_motion else 0.0
	_plant.add_child(_reflection)
	Motion.bez(self, _tick_window, HEARTH_HOLD, Motion.CSS_EASE) \
		.finished.connect(_complete)


func _tick_window(u: float) -> void:
	if _reflection == null or Preferences.active.reduce_motion:
		return
	var elapsed: float = u * HEARTH_HOLD
	_reflection.modulate.a = REFLECT_ALPHA * clampf(
		(elapsed - WINDOW_LAG) / maxf(HEARTH_HOLD - WINDOW_LAG, 0.01), 0.0, 1.0)


func _complete() -> void:
	if _done:
		return
	_done = true
	finished.emit()
