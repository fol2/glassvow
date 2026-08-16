class_name DepartureStaging
extends Control
## L0 every-departure plant (00-truth §5, 07-scenes §2): camera lingers a
## beat on the hearth, the window reflection lags half a beat. Art-gated —
## no plate, no linger. Run 1 rides the opening's beats ③–④; this screen
## is the run 2+ home, fired on the Embark → run transition. A staged
## `pool.hearth` row rides the same plate; copy stays in the line table.

signal finished

const HEARTH_PLATE: String = "res://assets/art/scenes/opening-hearth.png"
const HEARTH_HOLD: float = 1.0
const WINDOW_LAG: float = 0.5
## How far the reflection comes up once the lag is paid. Dark glass returns a
## fraction of the room, never a second room.
const REFLECT_ALPHA: float = 0.45

var instant: bool = false
var hearth_plate: String = HEARTH_PLATE
var _line_row: Dictionary = {}
var line_row: Dictionary:
	get:
		return _line_row
	set(value):
		_line_row = value
		_bind_line()
		if not value.is_empty():
			_await_line()
var _done: bool = false
var _line_up: bool = false
var _plant: TextureRect = null
var _reflection: WindowReflection = null
var _copy_layer: Control = null
var _copy: PanelContainer = null
var _speaker: Label = null
var _line: Label = null


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
	_build_copy()


func _ready() -> void:
	_bind_line()
	if not line_row.is_empty():
		_await_line()
	if instant or not ResourceLoader.exists(hearth_plate):
		if line_row.is_empty():
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
	_reflection = WindowReflection.new()
	_reflection.modulate.a = REFLECT_ALPHA if Preferences.active.reduce_motion else 0.0
	_plant.add_child(_reflection)
	if _copy_layer != null:
		move_child(_copy_layer, -1)
	Motion.bez(self, _tick_window, HEARTH_HOLD, Motion.CSS_EASE) \
		.finished.connect(_on_plant_done)


func _build_copy() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	_copy_layer = margin
	var dock: VBoxContainer = VBoxContainer.new()
	dock.alignment = BoxContainer.ALIGNMENT_END
	dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(dock)
	var centre: CenterContainer = CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(centre)
	_copy = PanelContainer.new()
	_copy.visible = false
	_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_copy.custom_minimum_size.x = 520.0
	centre.add_child(_copy)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_copy.add_child(column)
	_speaker = Label.new()
	_speaker.name = "Speaker"
	_speaker.visible = false
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 2))
	_speaker.add_theme_font_size_override("font_size", 11)
	_speaker.add_theme_color_override("font_color", RunStyle.GOLD_DIM)
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_speaker)
	_line = Label.new()
	_line.name = "Line"
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.add_theme_font_override("font", GlassStyle.face(GlassStyle.CINZEL_500))
	_line.add_theme_font_size_override("font_size", 19)
	_line.add_theme_color_override("font_color", Color("#d8dfe2"))
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_line)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.07, 0.095, 0.92)
	style.set_border_width_all(1)
	style.border_color = Color(0.51, 0.60, 0.65, 0.25)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 3
	style.set_content_margin_all(46.0)
	_copy.add_theme_stylebox_override("panel", style)


func _bind_line() -> void:
	if line_row.is_empty() or _line == null:
		return
	_line.text = LineTable.text(line_row, Locale.active.code == Locale.CODE_ZH_HANT)
	var speaker_id: String = str(line_row.get("speaker", "")).strip_edges()
	_speaker.visible = speaker_id == "keeper"
	_speaker.text = Locale.active.t("ui.scene.speaker.keeper") if _speaker.visible else ""


func _tick_window(u: float) -> void:
	if _reflection == null or Preferences.active.reduce_motion:
		return
	var elapsed: float = u * HEARTH_HOLD
	_reflection.modulate.a = REFLECT_ALPHA * clampf(
		(elapsed - WINDOW_LAG) / maxf(HEARTH_HOLD - WINDOW_LAG, 0.01), 0.0, 1.0)


func _on_plant_done() -> void:
	if line_row.is_empty():
		_complete()
	else:
		_await_line()


func _await_line() -> void:
	if _copy != null:
		_copy.visible = true
	_line_up = true


func _gui_input(event: InputEvent) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed:
		_tap()


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or key_event.echo or key_event.pressed:
		return
	if key_event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_tap()


func _tap() -> void:
	if _line_up:
		_complete()


func _complete() -> void:
	if _done:
		return
	_done = true
	finished.emit()
