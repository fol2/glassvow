class_name RunMenuPanel
extends Control
## Benchmark `pop-menu` leaf. It reports intent; the composition root owns routes.

signal help_requested
signal settings_requested
signal title_requested
signal abandon_requested
signal closed

const WIDTH: float = 200.0

var shape: StringName
var _sfx: SfxBus
var _panel: PanelContainer


func _init(stage_shape: StringName, terminal_locked: bool = false) -> void:
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200

	_sfx = SfxBus.new()
	add_child(_sfx)

	var scrim: ColorRect = ColorRect.new()
	scrim.color = Color.TRANSPARENT
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.custom_minimum_size.x = WIDTH
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)

	var actions: VBoxContainer = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 2)
	_panel.add_child(actions)

	var help: Button = _button("How to Play")
	help.pressed.connect(_request.bind(&"help"))
	actions.add_child(help)

	var settings: Button = _button("Settings")
	settings.pressed.connect(_request.bind(&"settings"))
	actions.add_child(settings)

	if not terminal_locked:
		var abandon: Button = _button("Abandon Run", RunStyle.DANGER, RunStyle.DANGER)
		abandon.pressed.connect(_request.bind(&"abandon"))
		actions.add_child(abandon)

	_apply_shape()


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	_apply_shape()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		closed.emit()
	elif event is InputEventScreenTouch and event.pressed:
		closed.emit()


func _request(action: StringName) -> void:
	_sfx.play(&"click")
	match action:
		&"help":
			help_requested.emit()
		&"settings":
			settings_requested.emit()
		&"abandon":
			abandon_requested.emit()


func _button(label: String, colour: Color = RunStyle.TEXT,
		ring_accent: Color = RunStyle.GOLD) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 44.0 if shape.begins_with("phone") else 34.0
	button.add_theme_font_override("font", load(GlassStyle.CINZEL_500) as Font)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", colour)
	button.add_theme_color_override("font_hover_color", RunStyle.GOLD)
	button.add_theme_color_override("font_pressed_color", colour)
	button.add_theme_color_override("font_focus_color", RunStyle.GOLD)
	# The lantern ring overlays the state boxes; an opaque "focus" box here
	# would shadow it (GlassStyle.focus_ring's ADOPTION PREREQUISITE). The
	# ring accent is EXPLICIT — inferring it from colour-equality would
	# silently re-map every row if TEXT ever changed (DL, PR #43).
	button.add_theme_stylebox_override("focus",
		GlassStyle.focus_ring(ring_accent, 7))
	for state: String in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, _button_style(state))
	button.mouse_entered.connect(func() -> void: _sfx.play(&"hover", 0.45))
	return button


func _apply_shape() -> void:
	var phone: bool = shape.begins_with("phone")
	var margin: float = 10.0 if phone else 16.0
	var top: float = 46.0 if shape == &"phone-landscape" else 54.0
	_panel.offset_left = -margin - WIDTH
	_panel.offset_right = -margin
	_panel.offset_top = top
	_panel.offset_bottom = top
	for child: Node in _panel.get_child(0).get_children():
		var button: Button = child as Button
		button.custom_minimum_size.y = 44.0 if phone else 34.0


static func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = RunStyle.PANEL
	style.set_border_width_all(1)
	style.border_color = RunStyle.PANEL_LINE
	style.set_corner_radius_all(10)
	style.set_content_margin_all(6)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.60)
	style.shadow_size = 40
	style.shadow_offset = Vector2(0, 14)
	return style


static func _button_style(state: String) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(RunStyle.GOLD, 0.14) if state == "hover" \
		else (Color(RunStyle.GOLD, 0.08) if state == "pressed" else Color.TRANSPARENT)
	style.set_corner_radius_all(7)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
