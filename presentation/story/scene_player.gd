class_name ScenePlayer
extends Control
## Shared scripted-scene sequencer. DawnScreen's beat grammar, HollowScreen's
## dialogue panel, a full-bleed plate that degrades to graded ground.

signal advance_requested
signal finished

const REVEAL_TIME: float = 0.55
## Reading pace, not a fixed beat. DawnScreen's flat 1.6s was sized for a
## short result card; a line of dialogue is not one, and a long line would
## walk out from under the player mid-sentence. A tap always pre-empts the
## dwell, so this only ever sets the hands-off pace.
##
## KNOWN CEILING: one rate serves both locales, and zh-Hant carries roughly
## twice the meaning per character that English does — so a zh line dwells
## too briefly at the same count. Both constants are placeholder-era and get
## measured once real copy lands (story Batch 2 / Batch 4, #263).
const DWELL_BASE: float = 1.2
const DWELL_PER_CHAR: float = 0.09
const SKIP_HOLD: float = 0.6
const SKIP_WAIT: float = 0.04
const PUSH_IN_TIME: float = 8.0
const PUSH_IN_SCALE: float = 1.08
const LINGER_SCALE: float = 1.06
const LINGER_AMP: Vector2 = Vector2(12.0, 8.0)

const BEAT_IDLE: int = 0
const BEAT_REVEAL: int = 1
const BEAT_WAIT: int = 2

var instant: bool = false
var shape: StringName = StageShape.IDENTITY

var _script: SceneScript
var _cursor: int = 0
var _sfx: SfxBus
var _beat: int = BEAT_IDLE
var _beat_t: float = 0.0
var skipped: bool = false
var _hold_t: float = 0.0
var _holding: bool = false
var _skipping: bool = false
var _asked: bool = false
var _done: bool = false
var _motion_t: float = 0.0
var _motion: String = "hold"
var _beat_i: int = -1
var _plate_host: Control
var _plate: TextureRect
var _margin: MarginContainer
var _copy: PanelContainer
var _speaker: Label
var _line: Label
var _caption: Label
var _skip_fill: ColorRect
var _letter_top: ColorRect
var _letter_bot: ColorRect
var _hearth_figure: HearthFigure = null
var _unsealing: UnsealingStaging = null


func _init(scene_script: SceneScript, cursor: int = 0,
		stage_shape: StringName = StageShape.IDENTITY, sfx: SfxBus = null) -> void:
	_script = scene_script
	_cursor = clampi(cursor, 0, scene_script.line_count())
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = GlassStyle.theme()
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	_build()


func _ready() -> void:
	if _cursor >= _script.line_count():
		_complete()
	else:
		_begin_beat()
	set_process(true)


func _build() -> void:
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
	_plate_host = Control.new()
	_plate_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate_host.clip_contents = true
	_plate_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate_host)
	_plate = TextureRect.new()
	_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.name = "Plate"
	_plate_host.add_child(_plate)
	var wash: ColorRect = ColorRect.new()
	wash.color = Color(0.025, 0.020, 0.035, 0.28)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)
	_letter_top = _band()
	_letter_bot = _band()
	add_child(_letter_top)
	add_child(_letter_bot)
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	var dock: VBoxContainer = VBoxContainer.new()
	dock.alignment = BoxContainer.ALIGNMENT_END
	dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock.add_theme_constant_override("separation", 10)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(dock)
	var centre: CenterContainer = CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(centre)
	_copy = PanelContainer.new()
	_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(_copy)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_copy.add_child(column)
	_speaker = _label("", 11, RunStyle.GOLD_DIM)
	_speaker.name = "Speaker"
	_speaker.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 2))
	column.add_child(_speaker)
	_line = _label("", 19, Color("#d8dfe2"))
	_line.name = "Line"
	_line.add_theme_font_override("font", GlassStyle.face(GlassStyle.CINZEL_500))
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_line)
	var caption_seat: VBoxContainer = VBoxContainer.new()
	caption_seat.alignment = BoxContainer.ALIGNMENT_CENTER
	caption_seat.add_theme_constant_override("separation", 3)
	caption_seat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption_seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(caption_seat)
	_caption = _label(Locale.active.t("ui.dawn.inputHint"), 10,
		Color(RunStyle.TEXT_DIM, 0.85))
	_caption.name = "Caption"
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption_seat.add_child(_caption)
	_skip_fill = ColorRect.new()
	_skip_fill.name = "SkipFill"
	_skip_fill.color = RunStyle.GOLD
	_skip_fill.custom_minimum_size = Vector2(0.0, 2.0)
	_skip_fill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_skip_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_seat.add_child(_skip_fill)
	set_shape(shape)


func advance_confirmed() -> void:
	if _done:
		return
	_cursor += 1
	if _cursor >= _script.line_count():
		_complete()
	else:
		_begin_beat()


func _begin_beat() -> void:
	_asked = false
	_present_line()
	_beat = BEAT_REVEAL
	_beat_t = 0.0
	if instant or _skipping:
		_copy.modulate.a = 1.0
		_finish_beat()
		return
	_copy.modulate.a = 0.0


func _finish_beat() -> void:
	_beat = BEAT_WAIT
	_beat_t = 0.0


func _complete() -> void:
	_beat = BEAT_IDLE
	_caption.visible = false
	_skip_fill.visible = false
	if _done:
		return
	_done = true
	finished.emit()


func _present_line() -> void:
	if _cursor < 0 or _cursor >= _script.line_count():
		return
	var row: Dictionary = _script.lines[_cursor]
	_line.text = Locale.active.t(str(row["key"]))
	var speaker_id: String = str(row.get("speaker", "")).strip_edges()
	_speaker.visible = not speaker_id.is_empty()
	_speaker.text = Locale.active.t("ui.scene.speaker.%s" % speaker_id) \
		if _speaker.visible else ""
	var beat_i: int = row["beat"]
	if beat_i != _beat_i:
		_beat_i = beat_i
		_motion_t = 0.0
		_motion = str(_script.beat_at(_cursor).get("motion", "hold"))
		_bind_plate()
		_bind_staging()
	_caption.visible = true
	_skip_fill.visible = true


func _bind_plate() -> void:
	var path: String = _art_path(_cursor)
	if path.is_empty():
		_plate.texture = null
		_plate.visible = false
		return
	_plate.texture = load(path) as Texture2D
	_plate.visible = _plate.texture != null


## Per-scene presentation, not new grammar (07-scenes §1). Opening seats
## the #283 cutout on the empty hearth; unsealing dresses beats 1–2 with
## the shipped mural/masks/frame and yields to the one-queue plate.
func _bind_staging() -> void:
	_sync_hearth_figure()
	_sync_unsealing()


func _sync_hearth_figure() -> void:
	var wanted: bool = _script.id == "opening" and HearthFigure.present()
	if not wanted:
		if _hearth_figure != null:
			_hearth_figure.queue_free()
			_hearth_figure = null
		return
	_hearth_figure = HearthFigure.attach(_plate, false)
	_hearth_figure.visible = _plate.visible


func _sync_unsealing() -> void:
	if _script.id != "unsealing":
		if _unsealing != null:
			_unsealing.queue_free()
			_unsealing = null
		return
	if _unsealing == null:
		_unsealing = UnsealingStaging.new()
		_plate_host.add_child(_unsealing)
	_unsealing.present(_beat_i, instant or Preferences.active.reduce_motion)


func _art_path(index: int) -> String:
	var intended: String = ""
	for i: int in range(index + 1):
		var art: String = str(_script.beat_at(i).get("art", ""))
		if not art.is_empty():
			intended = art
	if not intended.is_empty() and ResourceLoader.exists(intended):
		return intended
	for i: int in range(index, -1, -1):
		var art: String = str(_script.beat_at(i).get("art", ""))
		if not art.is_empty() and ResourceLoader.exists(art):
			return art
	return ""


func _process(delta: float) -> void:
	_apply_motion(delta)
	if _holding and _beat != BEAT_IDLE:
		_hold_t += delta
		_skip_fill.custom_minimum_size.x = maxf(_caption.size.x, 220.0) \
			* clampf(_hold_t / SKIP_HOLD, 0.0, 1.0)
		if _hold_t >= SKIP_HOLD and not _skipping:
			_skipping = true
			skipped = true
			_sfx.play(&"click")
			# Do not emit on arm. The WAIT branch below enforces `_beat_t`
			# against `_skip_wait()`, so a hold that arms on beat ② still
			# owes the destination floor instead of skipping it.
	match _beat:
		BEAT_REVEAL:
			_beat_t += delta
			var u: float = clampf(_beat_t / REVEAL_TIME, 0.0, 1.0)
			var shown: float = 1.0 if Preferences.active.reduce_motion \
				else Motion.ease(Motion.CSS_EASE, u)
			_copy.modulate.a = shown
			if u >= 1.0:
				_finish_beat()
		BEAT_WAIT:
			_beat_t += delta
			var wait: float = 0.0 if instant else _skip_wait()
			if _beat_t >= wait and not _asked:
				_asked = true
				advance_requested.emit()


## How long a settled line holds before it asks on its own.
func _dwell() -> float:
	return DWELL_BASE + DWELL_PER_CHAR * float(_line.text.length())


## Skip is 40 ms/line unless the beat names a floor. The design holds a
## minimum ~1 s on beat ② (the destination-naming beat) — once, on that
## beat's first line, not 1 s stacked on every line of the beat.
func _skip_wait() -> float:
	if not _skipping:
		return _dwell()
	var floor_s: float = float(str(_script.beat_at(_cursor).get("skip_dwell", 0.0)))
	if floor_s <= 0.0:
		return SKIP_WAIT
	if _cursor > 0:
		var row: Dictionary = _script.lines[_cursor]
		var prev: Dictionary = _script.lines[_cursor - 1]
		var beat_i: int = row["beat"]
		var prev_i: int = prev["beat"]
		if beat_i == prev_i:
			return SKIP_WAIT
	return floor_s


func _gui_input(event: InputEvent) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT:
		_press(mouse.pressed)


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or key_event.echo:
		return
	if key_event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_press(key_event.pressed)


func _press(down: bool) -> void:
	if _beat == BEAT_IDLE:
		return
	if down:
		_holding = true
		_hold_t = 0.0
		return
	if not _holding:
		return
	_holding = false
	var was_tap: bool = _hold_t < SKIP_HOLD
	_hold_t = 0.0
	_skip_fill.custom_minimum_size.x = 0.0
	if not was_tap or _skipping or _asked:
		return
	_sfx.play(&"click")
	if _beat == BEAT_WAIT:
		_asked = true
		advance_requested.emit()
	elif _beat == BEAT_REVEAL:
		_copy.modulate.a = 1.0
		_finish_beat()
		_asked = true
		advance_requested.emit()


func _apply_motion(delta: float) -> void:
	var host_size: Vector2 = _plate_host.size
	if host_size.x < 1.0 or host_size.y < 1.0:
		return
	var scale_n: float = 1.0
	var drift: Vector2 = Vector2.ZERO
	if not instant and not Preferences.active.reduce_motion:
		match _motion:
			"push-in":
				_motion_t += delta
				var u: float = clampf(_motion_t / PUSH_IN_TIME, 0.0, 1.0)
				scale_n = lerpf(1.0, PUSH_IN_SCALE, Motion.ease(Motion.EASE_IN_OUT, u))
			"linger":
				_motion_t += delta
				scale_n = LINGER_SCALE
				drift = Vector2(sin(_motion_t * 0.15) * LINGER_AMP.x,
					sin(_motion_t * 0.11) * LINGER_AMP.y)
	var cover: Vector2 = host_size * scale_n
	_plate.size = cover
	_plate.position = (host_size - cover) * 0.5 + drift


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	var portrait: bool = shape == &"phone-portrait"
	var short: bool = shape == &"phone-landscape"
	var inset: int = 14 if portrait else (10 if short else 48)
	for side: String in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, inset)
	_copy.custom_minimum_size.x = 330.0 if portrait else (560.0 if short else 520.0)
	_copy.add_theme_stylebox_override("panel", _copy_style(
		22.0 if portrait else (18.0 if short else 46.0)))
	_line.add_theme_font_size_override("font_size",
		16 if portrait else (13 if short else 19))
	var band: float = 0.05 if short else 0.08
	_set_band(_letter_top, 0.0, band)
	_set_band(_letter_bot, 1.0 - band, 1.0)


static func _set_band(bar: ColorRect, top: float, bottom: float) -> void:
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = top
	bar.anchor_bottom = bottom
	bar.offset_left = 0.0
	bar.offset_right = 0.0
	bar.offset_top = 0.0
	bar.offset_bottom = 0.0


static func _band() -> ColorRect:
	var bar: ColorRect = ColorRect.new()
	bar.color = Color(0.01, 0.012, 0.02, 0.92)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


static func _copy_style(inset: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.07, 0.095, 0.92)
	style.set_border_width_all(1)
	style.border_color = Color(0.51, 0.60, 0.65, 0.25)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 3
	style.set_content_margin_all(inset)
	style.shadow_color = Color(0, 0, 0, 0.62)
	style.shadow_size = 28
	return style


static func _label(text: String, font_size: int, colour: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", GlassStyle.face(GlassStyle.ALEGREYA_400))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
