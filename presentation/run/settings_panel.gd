class_name SettingsPanel
extends Control
## Benchmark-sized audio/settings overlay; the route behind it stays visible.

signal closed
signal reset_requested

const GOLD: Color = Color("#f2c14e")
const DANGER: Color = Color("#ff8d8d")
const WIDTH: float = 320.0

var _preferences: AudioPreferences
var _sfx: SfxBus


func _init(preferences: AudioPreferences, reset_disabled: bool = false) -> void:
	_preferences = preferences
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sfx = SfxBus.new()
	add_child(_sfx)

	var scrim: ColorRect = ColorRect.new()
	scrim.color = Color.TRANSPARENT
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x = WIDTH
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style())
	centre.add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var title: Label = Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load(GlassStyle.CINZEL_500) as Font)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", GOLD)
	column.add_child(title)

	var audio: VBoxContainer = VBoxContainer.new()
	audio.add_theme_constant_override("separation", 7)
	column.add_child(audio)
	audio.add_child(_audio_row("MUSIC", AudioPreferences.MUSIC))
	audio.add_child(_audio_row("SFX", AudioPreferences.SFX))

	var debug_section: VBoxContainer = VBoxContainer.new()
	debug_section.add_theme_constant_override("separation", 8)
	column.add_child(debug_section)

	var divider: HSeparator = HSeparator.new()
	divider.add_theme_color_override("separator", Color(DANGER, 0.22))
	divider.add_theme_constant_override("separation", 1)
	debug_section.add_child(divider)

	var debug: Label = Label.new()
	debug.text = "DEBUG"
	debug.add_theme_font_override("font", _tracked_font(GlassStyle.CINZEL_500, 2))
	debug.add_theme_font_size_override("font_size", 12)
	debug.add_theme_color_override("font_color", Color(DANGER, 0.9))
	debug_section.add_child(debug)

	var reset: Button = _button("RESET SAVE", DANGER, 14)
	reset.disabled = reset_disabled
	reset.pressed.connect(func() -> void:
		_sfx.play(&"click")
		reset_requested.emit()
	)
	debug_section.add_child(reset)

	var warning: Label = Label.new()
	warning.text = "Wipes the current climb and all Vigil progress. Cannot be undone."
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_font_override("font", load(GlassStyle.ALEGREYA_400) as Font)
	warning.add_theme_font_size_override("font_size", 12)
	warning.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	debug_section.add_child(warning)

	var close: Button = _button("CLOSE", GlassStyle.GLASS)
	close.pressed.connect(func() -> void:
		_sfx.play(&"click")
		closed.emit()
	)
	column.add_child(close)
	close.grab_focus.call_deferred()


func _audio_row(label_text: String, bus: StringName) -> VBoxContainer:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	row.add_child(header)

	var label: Label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", _tracked_font(GlassStyle.CINZEL_500, 1))
	label.add_theme_font_size_override("font_size", 13)
	header.add_child(label)

	var mute: Button = _small_button()
	header.add_child(mute)

	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = roundf(_preferences.volume(bus) * 100.0)
	slider.custom_minimum_size.y = 22.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = "%s volume" % label_text.capitalize()
	_style_slider(slider)
	row.add_child(slider)

	var sync: Callable = func() -> void:
		var muted: bool = _preferences.is_muted(bus)
		mute.text = "UNMUTE" if muted else "MUTE"
		slider.editable = not muted
	sync.call()
	slider.value_changed.connect(func(value: float) -> void:
		_preferences.set_volume(bus, value / 100.0)
	)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		_sfx.play(&"click")
	)
	mute.pressed.connect(func() -> void:
		_preferences.set_muted(bus, not _preferences.is_muted(bus))
		sync.call()
		_sfx.play(&"click")
	)
	return row


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		closed.emit()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		closed.emit()


static func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.071, 0.133, 0.86)
	style.set_border_width_all(1)
	style.border_color = Color(GOLD, 0.28)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	style.shadow_size = 18
	return style


static func _button(text: String, accent: Color, font_size: int = 13) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 36.0
	button.add_theme_font_override("font", load(GlassStyle.CINZEL_500) as Font)
	button.add_theme_font_size_override("font_size", font_size)
	_style_button(button, accent, 8.0, 8)
	return button


static func _small_button() -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(76.0, 26.0)
	button.add_theme_font_override("font", load(GlassStyle.CINZEL_500) as Font)
	button.add_theme_font_size_override("font_size", 12)
	_style_button(button, GOLD, 4.0, 6)
	return button


static func _style_button(button: Button, accent: Color, vertical: float,
		radius: int) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.055, 0.071, 0.133, 0.60)
		style.set_border_width_all(1)
		style.border_color = Color(accent, 0.28 if state == "normal" else 0.8)
		style.set_corner_radius_all(radius)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = vertical
		style.content_margin_bottom = vertical
		if state == "hover":
			style.bg_color = Color(accent, 0.14)
		elif state == "pressed":
			style.bg_color = Color(accent, 0.08)
		elif state == "disabled":
			style.border_color = Color(accent, 0.12)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", GlassStyle.TEXT)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_disabled_color", Color(GlassStyle.TEXT_DIM, 0.45))


static func _style_slider(slider: HSlider) -> void:
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(0.02, 0.03, 0.06, 0.9)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill: StyleBoxFlat = track.duplicate()
	fill.bg_color = GOLD
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var grabber: Texture2D = _disc(GOLD, 1.0)
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_highlight", grabber)
	slider.add_theme_icon_override("grabber_disabled", _disc(GlassStyle.TEXT_DIM, 0.45))


static func _disc(colour: Color, alpha: float) -> GradientTexture2D:
	var texture: GradientTexture2D = GlassStyle.grad_tex(
		PackedColorArray([Color(colour, alpha), Color(colour, alpha * 0.45),
			Color(colour, 0.0)]),
		PackedFloat32Array([0.0, 0.52, 1.0]), true,
		Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	texture.width = 16
	texture.height = 16
	return texture


static func _tracked_font(path: String, glyph_spacing: int) -> FontVariation:
	var tracked: FontVariation = FontVariation.new()
	tracked.base_font = load(path) as Font
	tracked.spacing_glyph = glyph_spacing
	return tracked
