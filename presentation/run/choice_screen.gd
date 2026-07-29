class_name ChoiceScreen
extends Control
## One quiet glass panel for every non-combat decision. The application owns
## routing and domain mutation; this view only emits the selected id.

signal chosen(id: String)

var _first_button: Button = null
var _panel: PanelContainer


func _init(title_text: String, body_text: String, choices: Array[Dictionary]) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()

	var ground: ColorRect = ColorRect.new()
	ground.color = GlassStyle.NIGHT_BOT
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.offset_left = 24.0
	centre.offset_top = 24.0
	centre.offset_right = -24.0
	centre.offset_bottom = -24.0
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(520.0, 0.0)
	_panel.add_theme_stylebox_override("panel", GlassStyle.pane(GlassStyle.GLASS, 0.94))
	centre.add_child(_panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_panel.add_child(column)

	var title: Label = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load(GlassStyle.CINZEL_700) as Font)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GlassStyle.TEXT)
	column.add_child(title)

	if not body_text.is_empty():
		var body: Label = Label.new()
		body.text = body_text
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_override("font", load(GlassStyle.ALEGREYA_400) as Font)
		body.add_theme_font_size_override("font_size", 18)
		body.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
		column.add_child(body)

	var button_column: VBoxContainer = column
	if choices.size() > 7:
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.custom_minimum_size.y = 420.0
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(scroll)
		button_column = VBoxContainer.new()
		button_column.add_theme_constant_override("separation", 14)
		button_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(button_column)
	for row: Dictionary in choices:
		var button: Button = Button.new()
		button.text = str(row.get("label", row.get("id", "")))
		button.disabled = row.get("disabled", false)
		button.tooltip_text = str(row.get("hint", ""))
		button.custom_minimum_size.y = 48.0
		GlassStyle.style_button(button, GlassStyle.EMBER if not row.get("quiet", false) else GlassStyle.GLASS)
		var id: String = str(row.get("id", ""))
		button.pressed.connect(func() -> void: chosen.emit(id))
		button_column.add_child(button)
		if _first_button == null and not button.disabled:
			_first_button = button


func _ready() -> void:
	resized.connect(_fit_panel)
	_fit_panel()
	if _first_button != null:
		_first_button.grab_focus()


func _fit_panel() -> void:
	if _panel != null:
		_panel.custom_minimum_size.x = minf(520.0, maxf(280.0, size.x - 48.0))
