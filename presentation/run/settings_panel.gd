class_name SettingsPanel
extends Control
## The player-facing settings overlay: AUDIO / DISPLAY / MOTION / THE LEDGER,
## with the route behind it staying visible. Reads and writes the main-owned
## Preferences handle; the DISPLAY section hides itself where the platform
## owns the window (web) or there is no window at all (headless).

signal closed
signal reset_requested

const GOLD: Color = Color("#f2c14e")
const DANGER: Color = Color("#ff8d8d")
const WIDTH: float = 320.0

var _preferences: Preferences
var _sfx: SfxBus
var _panel: PanelContainer
var _scroll: ScrollContainer
var _sections: VBoxContainer


func _init(preferences: Preferences, reset_disabled: bool = false) -> void:
	_preferences = preferences
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sfx = SfxBus.new()
	add_child(_sfx)

	var scrim: ColorRect = ColorRect.new()
	# The route stays visible but must not COMPETE: without this veil the
	# title wordmark read straight through the panel copy (DL round 1,
	# measured ~70% local lift). P4.8 unifies scrims project-wide.
	scrim.color = Color(0.02, 0.03, 0.06, 0.5)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size.x = WIDTH
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	centre.add_child(_panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)

	var title: Label = Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load(GlassStyle.CINZEL_500) as Font)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", GOLD)
	column.add_child(title)

	# Four sections can outgrow a phone stage, so they live in a scroll while
	# the title, close button and footer stay put.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)

	# The optical ladder, not the container constant: the 26px controls carry
	# ~8px of internal padding each, so the source ratio must be far steeper
	# than the on-screen ratio it buys (DL round 1 measured 14/7/6 collapsing
	# to one uniform 22-24px band, leaving each slider equidistant between
	# its own label and the next).
	_sections = VBoxContainer.new()
	_sections.add_theme_constant_override("separation", 26)
	_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_sections)

	var audio: VBoxContainer = _section("AUDIO", GOLD, false)
	audio.add_child(_audio_row("MASTER", Preferences.MASTER))
	audio.add_child(_audio_row("MUSIC", Preferences.MUSIC))
	audio.add_child(_audio_row("SFX", Preferences.SFX))

	if _display_supported():
		var display: VBoxContainer = _section("DISPLAY", GOLD)
		display.add_child(_toggle_row("FULLSCREEN",
			func() -> bool: return _preferences.fullscreen,
			func(on: bool) -> void: _preferences.set_fullscreen(on)))
		display.add_child(_toggle_row("VSYNC",
			func() -> bool: return _preferences.vsync,
			func(on: bool) -> void: _preferences.set_vsync(on)))

	var motion: VBoxContainer = _section("MOTION", GOLD)
	motion.add_child(_toggle_row("SCREEN SHAKE",
		func() -> bool: return _preferences.screen_shake,
		func(on: bool) -> void: _preferences.set_screen_shake(on)))
	motion.add_child(_toggle_row("REDUCE MOTION",
		func() -> bool: return _preferences.reduce_motion,
		func(on: bool) -> void: _preferences.set_reduce_motion(on)))

	# The destructive section sits deliberately OUTSIDE the shared rhythm —
	# reaching it should take a beat.
	var ledger_seat: MarginContainer = MarginContainer.new()
	ledger_seat.add_theme_constant_override("margin_top", 14)
	_sections.add_child(ledger_seat)
	var ledger: VBoxContainer = _section("THE LEDGER", DANGER, true, ledger_seat)
	var erase: Button = _button("ERASE ALL PROGRESS", DANGER, 14)
	# The most destructive control in the game must not be CLOSE's twin: the
	# glyph wears the danger, not just one pixel of border.
	erase.add_theme_color_override("font_color", Color(DANGER, 0.92))
	erase.disabled = reset_disabled
	erase.pressed.connect(func() -> void:
		_sfx.play(&"click")
		reset_requested.emit()
	)
	ledger.add_child(erase)

	var warning: Label = Label.new()
	warning.text = "Wipes the current climb and all Vigil progress. Cannot be undone."
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_font_override("font", load(GlassStyle.ALEGREYA_400) as Font)
	warning.add_theme_font_size_override("font_size", 12)
	warning.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	ledger.add_child(warning)

	var close: Button = _button("CLOSE", GlassStyle.GLASS)
	close.pressed.connect(func() -> void:
		_sfx.play(&"click")
		closed.emit()
	)
	column.add_child(close)

	var footer: Label = Label.new()
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	footer.text = "GLASSVOW %s" % version if version != "" else "GLASSVOW"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_override("font", _tracked_font(GlassStyle.CINZEL_500, 2))
	footer.add_theme_font_size_override("font_size", 10)
	footer.add_theme_color_override("font_color", Color(GlassStyle.TEXT_DIM, 0.7))
	column.add_child(footer)

	close.grab_focus.call_deferred()
	# The warning label wraps, so the sections' minimum height is only honest
	# once they have been laid out at the panel's real width — refit whenever
	# that settles rather than trusting the first frame's measure.
	_sections.resized.connect(_fit)
	_fit.call_deferred()


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit()


## The panel never outgrows the stage: the section scroll takes what remains
## after the fixed rows, and the width narrows on stages the 320px column
## would crowd.
func _fit() -> void:
	if _panel == null or size.x <= 0.0 or size.y <= 0.0:
		return
	_panel.custom_minimum_size.x = minf(WIDTH, maxf(272.0, size.x - 24.0))
	var room: float = maxf(180.0, size.y - 190.0)
	var want: float = minf(_sections.get_combined_minimum_size().y, room)
	if absf(_scroll.custom_minimum_size.y - want) > 0.5:
		_scroll.custom_minimum_size.y = want


static func _display_supported() -> bool:
	return not OS.has_feature("web") and DisplayServer.get_name() != "headless"


func _section(heading: String, accent: Color, with_rule: bool = true,
		seat: Container = null) -> VBoxContainer:
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if seat != null:
		seat.add_child(body)
	else:
		_sections.add_child(body)

	# The first section skips its rule: 11px under SETTINGS it groups upward
	# and reads as the title's underline rather than AUDIO's divider.
	if with_rule:
		var divider: HSeparator = HSeparator.new()
		# `separator` is a STYLEBOX theme item, not a Color — a Color
		# override compiles, does nothing, and the stock #808080 line paints
		# instead (DL round 1: all four rules measured dead grey).
		var rule: StyleBoxLine = StyleBoxLine.new()
		rule.color = Color(accent, 0.22)
		rule.thickness = 1
		divider.add_theme_stylebox_override("separator", rule)
		divider.add_theme_constant_override("separation", 1)
		body.add_child(divider)

	var label: Label = Label.new()
	label.text = heading
	label.add_theme_font_override("font", _tracked_font(GlassStyle.CINZEL_500, 2))
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(accent, 0.9))
	body.add_child(label)
	return body


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


## A labelled ON/OFF switch reading through a getter so the button always
## restates the stored truth rather than a mirrored local.
func _toggle_row(label_text: String, getter: Callable, setter: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var label: Label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", _tracked_font(GlassStyle.CINZEL_500, 1))
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)

	var toggle: Button = _small_button()
	var sync: Callable = func() -> void:
		var on: bool = getter.call()
		toggle.text = "ON" if on else "OFF"
		_toggle_state(toggle, on)
	sync.call()
	toggle.pressed.connect(func() -> void:
		var was_on: bool = getter.call()
		setter.call(not was_on)
		sync.call()
		_sfx.play(&"click")
	)
	row.add_child(toggle)
	return row


## State lives in the ACCENT — lit glass against unlit — never in opacity,
## which is the channel `disabled` already owns in this same panel (DL round
## 1: OFF at 0.62 modulate measured 65% of the way to the disabled border).
static func _toggle_state(toggle: Button, on: bool) -> void:
	toggle.add_theme_color_override("font_color",
		GOLD if on else GlassStyle.TEXT_DIM)
	var lit: StyleBoxFlat = StyleBoxFlat.new()
	lit.bg_color = Color(GOLD, 0.10) if on else Color(0.055, 0.071, 0.133, 0.60)
	lit.set_border_width_all(1)
	lit.border_color = Color(GOLD, 0.55 if on else 0.28)
	lit.set_corner_radius_all(6)
	lit.content_margin_left = 10
	lit.content_margin_right = 10
	lit.content_margin_top = 4
	lit.content_margin_bottom = 4
	toggle.add_theme_stylebox_override("normal", lit)


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
	# "focus" left the loop at P4.5: the opaque focus box made keyboard
	# focus ≡ hover here (DL, PR #40) — the shared lantern ring overlays
	# whichever state box is showing instead.
	button.add_theme_stylebox_override("focus", GlassStyle.focus_ring(accent))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
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
	# Hover speaks the button's OWN accent: gold on gold controls, danger on
	# the destructive one — never the affirmative accent over a danger wash
	# (DL round 1: ERASE hovered gold, and a dimmed OFF hovered DARKER than
	# at rest).
	button.add_theme_color_override("font_hover_color", accent)
	button.add_theme_color_override("font_focus_color", GlassStyle.TEXT)
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
