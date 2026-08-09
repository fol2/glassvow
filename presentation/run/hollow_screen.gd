class_name HollowScreen
extends Control
## Persisted Hollow Lamplighter interruption on an Unlit Way.

signal action_requested(action: StringName)

const HOLLOW: String = "res://assets/art/meta/hollow-lamplighter.svg"

var shape: StringName = StageShape.IDENTITY

var _pending: Dictionary
var _meeting: Dictionary
var _meeting_number: int
var _target: int
var _sfx: SfxBus
var _layout: GridContainer
var _figure: TextureRect
var _portrait_figure: TextureRect
var _copy: PanelContainer
var _kicker: Label
var _title: Label
var _ask: Label
var _answer: Label
var _error: Label
var _actions: GridContainer
var _pay: Button
var _continue: Button
var _leave: Button


func _init(pending: Dictionary, meeting: Dictionary, meeting_number: int,
		target: int, stage_shape: StringName = StageShape.IDENTITY,
		sfx: SfxBus = null) -> void:
	_pending = pending
	_meeting = meeting
	_meeting_number = clampi(meeting_number, 1, maxi(1, target))
	_target = maxi(1, target)
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	_build()


func _build() -> void:
	var background: TextureRect = TextureRect.new()
	background.texture = GlassStyle.grad_tex(
		PackedColorArray([Color("#05080d"), Color("#0a1118"), Color("#08090f")]),
		PackedFloat32Array([0.0, 0.48, 1.0]), false,
		Vector2.ZERO, Vector2.RIGHT)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var vignette: TextureRect = TextureRect.new()
	vignette.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.12), Color(0, 0, 0, 0.84)]),
		PackedFloat32Array([0.0, 0.35, 1.0]), true,
		Vector2(0.58, 0.48), Vector2(1.0, 0.48))
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	_portrait_figure = TextureRect.new()
	_portrait_figure.texture = load(HOLLOW) as Texture2D
	_portrait_figure.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_figure.offset_left = -132
	_portrait_figure.offset_top = 50
	_portrait_figure.offset_right = 70
	_portrait_figure.offset_bottom = -17
	_portrait_figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_figure.modulate.a = 0.22
	_portrait_figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_figure.visible = false
	add_child(_portrait_figure)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var centre: CenterContainer = CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(centre)
	_layout = GridContainer.new()
	_layout.columns = 2
	_layout.add_theme_constant_override("h_separation", 64)
	_layout.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_layout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	centre.add_child(_layout)

	var figure_centre: CenterContainer = CenterContainer.new()
	figure_centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	figure_centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout.add_child(figure_centre)
	_figure = TextureRect.new()
	_figure.texture = load(HOLLOW) as Texture2D
	_figure.custom_minimum_size = Vector2(336, 558)
	_figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	figure_centre.add_child(_figure)

	_copy = PanelContainer.new()
	_copy.custom_minimum_size.x = 520
	_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_copy.add_theme_stylebox_override("panel", _copy_style(46))
	_layout.add_child(_copy)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_copy.add_child(column)
	_kicker = _label(
		Locale.active.t("ui.hollow.kicker", {
			"current": _meeting_number, "total": _target}),
		11, Color("#83939d"))
	_kicker.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 2))
	column.add_child(_kicker)
	_title = _label(Locale.active.t("ui.hollow.title"), 38, Color("#c3cdd2"))
	_title.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 2))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)
	_ask = _label("“%s”" % str(_meeting.get("ask", "")), 19, Color("#d8dfe2"))
	_ask.add_theme_font_override("font", load(GlassStyle.CINZEL_500) as Font)
	_ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ask.custom_minimum_size.y = 96
	column.add_child(_ask)
	_answer = _label("", 14, Color("#d9c98c"))
	_answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_answer.custom_minimum_size.y = 48
	column.add_child(_answer)
	_error = _label("", 12, Color("#e2a0a0"))
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.custom_minimum_size.y = 20
	column.add_child(_error)

	_actions = GridContainer.new()
	_actions.columns = 3
	_actions.add_theme_constant_override("h_separation", 12)
	_actions.add_theme_constant_override("v_separation", 8)
	column.add_child(_actions)
	_pay = _action(Locale.active.t("ui.hollow.payPrice").to_upper(), &"pay", true)
	_actions.add_child(_pay)
	_continue = _action(Locale.active.t("ui.common.continue").to_upper(), &"continue", false)
	_actions.add_child(_continue)
	_leave = _action(Locale.active.t("ui.hollow.returnLater").to_upper(), &"leave", false)
	_actions.add_child(_leave)
	set_paid(str(_pending.get("paid", false)) == "true",
		str(_pending.get("answer", "")))
	set_shape(shape)


func _action(text: String, action: StringName, primary: bool) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 44)
	RunStyle.style_button(button, primary, Color("#83939d"))
	button.pressed.connect(func() -> void:
		_sfx.play(&"click")
		action_requested.emit(action)
	)
	return button


func set_paid(paid: bool, answer: String = "") -> void:
	_pending["paid"] = paid
	_pending["answer"] = answer
	_answer.text = answer
	_answer.add_theme_color_override(
		"font_color", Color("#d9c98c") if paid else Color("#9eabb2"))
	_pay.text = (Locale.active.t("ui.hollow.pricePaid") if paid \
		else Locale.active.t("ui.hollow.payPrice")).to_upper()
	_pay.disabled = paid
	_continue.disabled = not paid
	_leave.disabled = paid
	_error.text = ""


func show_error(message: String) -> void:
	_error.text = message
	_answer.text = ""
	_pay.disabled = false
	_continue.disabled = true
	_leave.disabled = false


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	var portrait: bool = shape == &"phone-portrait"
	var short: bool = shape == &"phone-landscape"
	_portrait_figure.visible = portrait
	_layout.columns = 1 if portrait else 2
	_layout.add_theme_constant_override("h_separation", 24 if short else 64)
	_figure.custom_minimum_size = Vector2(
		180 if short else (250 if portrait else 336),
		304 if short else (390 if portrait else 558))
	_figure.visible = not portrait
	_figure.modulate.a = 0.22 if portrait else 1.0
	_copy.custom_minimum_size.x = 330 if portrait else (520 if not short else 560)
	_copy.add_theme_stylebox_override("panel", _copy_style(
		22 if portrait else (18 if short else 46)))
	_actions.columns = 1 if portrait else (3 if not short else 2)
	_title.add_theme_font_size_override("font_size", 24 if portrait else (24 if short else 38))
	_ask.add_theme_font_size_override("font_size", 16 if portrait else (13 if short else 19))
	_ask.custom_minimum_size.y = 76 if portrait else (48 if short else 96)


static func _label(text: String, font_size: int, colour: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", load(GlassStyle.ALEGREYA_400) as Font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label


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
