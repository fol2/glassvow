class_name EventScreen
extends Control
## Benchmark event panel. The application owns resolution and passes this view
## an immutable projection of the event and its current resolution state.

signal choice_selected(ordinal: int)
signal continue_requested

const PANEL_W: float = 660.0
const EVENT_ART: String = "res://assets/art/events/%s.png"

var shape: StringName = StageShape.IDENTITY

var _event_id: String
var _event: Dictionary
var _result_log: String
var _choices_enabled: bool
var _completed: bool
var _sfx: SfxBus
var _centre: CenterContainer
var _panel: PanelContainer
var _title: Label
var _art: TextureRect
var _body: Label
var _choices: VBoxContainer
var _buttons: Array[Button] = []


func _init(event_id: String, event_definition: Dictionary,
		result_log: String = "", choices_enabled: bool = true,
		completed: bool = false,
		stage_shape: StringName = StageShape.IDENTITY, sfx: SfxBus = null) -> void:
	_event_id = event_id
	_event = event_definition
	_result_log = result_log
	_choices_enabled = choices_enabled
	_completed = completed
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	RunStyle.add_backdrop(self)
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	_build()


func _build() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	# Same reachability defect as #72's boon screen: without this the view never
	# travels with focus, so a button below the fold is focused and invisible.
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	_centre = CenterContainer.new()
	_centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size.x = PANEL_W
	_panel.add_theme_stylebox_override("panel", RunStyle.panel(16, 28, 0.92))
	_centre.add_child(_panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	_title = _label(str(_event.get("name", Locale.active.t("ui.event.strangePlace"))).to_upper(),
		26, RunStyle.PARCHMENT, true)
	_title.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 3))
	column.add_child(_title)

	_art = TextureRect.new()
	var art_path: String = EVENT_ART % _event_id
	if ResourceLoader.exists(art_path):
		_art.texture = load(art_path) as Texture2D
	_art.custom_minimum_size = Vector2(440, 220)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_art)

	_body = _label(str(_event.get("text", "")), 17, Color("#cdd3e4"), true)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_override("font", _italic_font())
	_body.add_theme_constant_override("line_spacing", 7)
	column.add_child(_body)

	if not _result_log.is_empty():
		var log_label: Label = _label(_result_log, 16, RunStyle.GOLD, true)
		log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(log_label)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 10)
	_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_choices)
	if _completed:
		_add_continue()
	else:
		_add_choices()


func _add_choices() -> void:
	var rows: Array = _event.get("choices", [])
	for ordinal: int in range(rows.size()):
		var value: Variant = rows[ordinal]
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = value
		var button: Button = Button.new()
		var sub: String = str(row.get("sub", ""))
		button.text = str(row.get("label", Locale.active.t("ui.common.leave"))) \
			+ ("\n%s" % sub if not sub.is_empty() else "")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 52 if sub.is_empty() else 66
		button.disabled = not _choices_enabled or row.get("disabled", false)
		button.add_theme_font_override("font", GlassStyle.face(
			GlassStyle.CINZEL_700 if sub.is_empty() else GlassStyle.ALEGREYA_400))
		button.add_theme_font_size_override("font_size", 15)
		RunStyle.style_button(button, ordinal == 0)
		button.pressed.connect(_choose.bind(ordinal))
		button.mouse_entered.connect(_hover.bind(button))
		_choices.add_child(button)
		_buttons.append(button)


func _add_continue() -> void:
	var button: Button = Button.new()
	button.text = Locale.active.t("ui.event.continue")
	button.custom_minimum_size = Vector2(180, 46)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", GlassStyle.face(GlassStyle.CINZEL_700))
	RunStyle.style_button(button, true)
	button.pressed.connect(func() -> void:
		_sfx.play(&"click")
		continue_requested.emit()
	)
	_choices.add_child(button)
	_buttons.append(button)


func _choose(ordinal: int) -> void:
	for button: Button in _buttons:
		button.disabled = true
	_sfx.play(&"click")
	choice_selected.emit(ordinal)


func _hover(button: Button) -> void:
	if not button.disabled:
		_sfx.play(&"hover", 0.45)


func _ready() -> void:
	resized.connect(_fit)
	_fit()
	for button: Button in _buttons:
		if not button.disabled:
			button.grab_focus()
			break


func set_shape(stage_shape: StringName) -> void:
	if StageShape.REFERENCES.has(stage_shape):
		shape = stage_shape
		_fit()


func _fit() -> void:
	if _centre == null:
		return
	var phone: bool = shape == &"phone-landscape"
	_centre.custom_minimum_size = Vector2(maxf(0.0, size.x - 24.0),
		maxf(0.0, size.y - 40.0))
	_panel.custom_minimum_size.x = minf(PANEL_W,
		maxf(300.0, size.x - (16.0 if phone else 24.0)))
	_art.custom_minimum_size = Vector2(
		minf(440.0, maxf(260.0, size.x - (60.0 if phone else 100.0))),
		150.0 if phone else 220.0)
	_title.add_theme_font_size_override("font_size", 20 if phone else 26)
	_body.add_theme_font_size_override("font_size", 15 if phone else 17)


static func _label(text: String, font_size: int, colour: Color,
		centred: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centred \
		else HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_override("font", GlassStyle.face(GlassStyle.ALEGREYA_400))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label


static func _italic_font() -> FontVariation:
	return RunStyle.slanted(GlassStyle.ALEGREYA_400)
