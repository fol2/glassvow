class_name CreditsScreen
extends Control
## Manifest-driven credits overlay — same skeleton as HelpScreen: scrim over
## the living title world, centred glass panel, Escape / scrim-click to close.

signal closed

const PANEL_MAX_WIDTH: float = 640.0
const PANEL_MAX_HEIGHT: float = 0.88
const DESKTOP_INSET: float = 28.0
const PHONE_INSET: float = 18.0
const MUSIC_MANIFEST: String = "res://assets/audio/music/manifest.json"
const SFX_MANIFEST: String = "res://assets/audio/sfx/manifest.json"

var shape: StringName = StageShape.IDENTITY

var _panel: PanelContainer
var _column: VBoxContainer
var _scroll: ScrollContainer
var _sfx: SfxBus
var _licence_wrap: MarginContainer
var _licence_toggle: Button
var _licence_built: bool = false


func _init(stage_shape: StringName = StageShape.IDENTITY,
		sfx: SfxBus = null) -> void:
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = GlassStyle.theme()

	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)

	var scrim: ColorRect = ColorRect.new()
	scrim.color = GlassStyle.scrim()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", GlassStyle.pane(GlassStyle.GLASS, 0.94))
	centre.add_child(_panel)

	var shell: VBoxContainer = VBoxContainer.new()
	shell.add_theme_constant_override("separation", 10)
	_panel.add_child(shell)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(_scroll)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 4)
	_scroll.add_child(_column)

	var title: Label = Label.new()
	title.text = "Credits"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 3))
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", RunStyle.PARCHMENT)
	_column.add_child(title)

	var rule_centre: CenterContainer = CenterContainer.new()
	rule_centre.custom_minimum_size.y = 10
	_column.add_child(rule_centre)
	var rule: HSeparator = HSeparator.new()
	rule.custom_minimum_size.x = 84
	var rule_line: StyleBoxLine = StyleBoxLine.new()
	rule_line.color = Color(GlassStyle.GOLD, 0.55)
	rule_line.thickness = 1
	rule.add_theme_stylebox_override("separator", rule_line)
	rule_centre.add_child(rule)

	_add_heading("GLASSVOW")
	_add_body("A roguelite deckbuilder · by fol2")

	_add_heading("THE GLASS")
	_add_body("Parallel-ported from roguecardv2 (web reference 0.5.0+6e06911).")

	_add_heading("MUSIC — STAINED GLASS")
	_add_body("stained-glass-v1", GlassStyle.TEXT_DIM)
	_add_music_rows(_read_manifest(MUSIC_MANIFEST))

	_add_heading("SOUND — ASHGLASS VIGIL")
	_add_body("ashglass-v1", GlassStyle.TEXT_DIM)
	_add_sfx_rows(_read_manifest(SFX_MANIFEST))

	_add_heading("TYPE")
	_add_body("Cinzel — Natanael Gama (OFL)")
	_add_body("Alegreya — Juan Pablo del Peral, Huerta Tipográfica (OFL)")
	_add_body("Noto Sans TC — Google (OFL)")

	_add_heading("ENGINE")
	_add_body("Made with Godot Engine")
	_add_licence_fold()

	var footer: Label = _body_label(
		"© 2026 fol2 · thank you for keeping the vigil", GlassStyle.TEXT_DIM)
	var footer_seat: MarginContainer = MarginContainer.new()
	footer_seat.add_theme_constant_override("margin_top", 14)
	footer_seat.add_child(footer)
	_column.add_child(footer_seat)

	# The panel's primary action is LEAVING it — a visible, focused dismiss
	# at the foot of the pane, outside the scroll so it never hides below
	# the fold (Help's "Fight On" contract). First-frame focus lands here.
	var close_centre: CenterContainer = CenterContainer.new()
	shell.add_child(close_centre)
	var close: Button = Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(150, 44)
	close.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 1))
	close.add_theme_font_size_override("font_size", 17)
	RunStyle.style_button(close)
	close.pressed.connect(func() -> void:
		_sfx.play(&"click")
		closed.emit()
	)
	close_centre.add_child(close)
	close.grab_focus.call_deferred()

	resized.connect(_fit)
	_fit.call_deferred()


func set_shape(stage_shape: StringName) -> void:
	if stage_shape == shape or not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	_fit()


func _fit() -> void:
	var reference: Vector2i = StageShape.REFERENCES[shape]
	var stage_size: Vector2 = size if size.x > 0.0 and size.y > 0.0 else Vector2(reference)
	var phone: bool = shape in [&"phone-portrait", &"phone-landscape"]
	var inset: float = PHONE_INSET if phone else DESKTOP_INSET
	var panel_width: float = minf(PANEL_MAX_WIDTH, stage_size.x)
	var panel_height: float = stage_size.y if phone else stage_size.y * PANEL_MAX_HEIGHT
	_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	_column.custom_minimum_size.x = maxf(240.0, panel_width - inset * 2.0)


func _read_manifest(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _add_music_rows(manifest: Variant) -> void:
	if typeof(manifest) != TYPE_DICTIONARY:
		_add_body("the stained-glass tracklist", GlassStyle.TEXT_DIM)
		return
	var pack: Dictionary = manifest
	var items_raw: Variant = pack.get("items", null)
	if typeof(items_raw) != TYPE_DICTIONARY:
		_add_body("the stained-glass tracklist", GlassStyle.TEXT_DIM)
		return
	var items: Dictionary = items_raw
	var titles: Array[String] = []
	for cue_raw: Variant in items.values():
		if typeof(cue_raw) != TYPE_DICTIONARY:
			continue
		var cue: Dictionary = cue_raw
		if cue.has("title"):
			titles.append(str(cue["title"]))
	if titles.is_empty():
		_add_body("the stained-glass tracklist", GlassStyle.TEXT_DIM)
		return
	for track_title: String in titles:
		_add_body(track_title)


func _add_sfx_rows(manifest: Variant) -> void:
	var count: int = 0
	var theme_line: String = "Ashglass Vigil"
	if typeof(manifest) == TYPE_DICTIONARY:
		var pack: Dictionary = manifest
		var items_raw: Variant = pack.get("items", null)
		if typeof(items_raw) == TYPE_DICTIONARY:
			var items: Dictionary = items_raw
			count = items.size()
		var packed: String = str(pack.get("theme", "")).strip_edges()
		if not packed.is_empty():
			theme_line = packed
	if count > 0:
		_add_body("%d sounds · synthesised with ElevenLabs" % count)
	else:
		_add_body("synthesised with ElevenLabs")
	_add_body(theme_line, GlassStyle.TEXT_DIM)


func _add_licence_fold() -> void:
	var seat: MarginContainer = MarginContainer.new()
	seat.add_theme_constant_override("margin_top", 8)
	_column.add_child(seat)
	var fold: VBoxContainer = VBoxContainer.new()
	fold.add_theme_constant_override("separation", 8)
	seat.add_child(fold)

	_licence_toggle = Button.new()
	_licence_toggle.text = "Third-party licences"
	_licence_toggle.custom_minimum_size = Vector2(0, 36)
	_licence_toggle.add_theme_font_override("font",
		load(GlassStyle.ALEGREYA_400) as Font)
	_licence_toggle.add_theme_font_size_override("font_size", 15)
	GlassStyle.style_button(_licence_toggle, GlassStyle.GLASS)
	_licence_toggle.pressed.connect(_on_licence_toggle)
	fold.add_child(_licence_toggle)

	_licence_wrap = MarginContainer.new()
	_licence_wrap.visible = false
	fold.add_child(_licence_wrap)


func _on_licence_toggle() -> void:
	_sfx.play(&"click")
	if not _licence_built:
		_build_licence()
		_licence_built = true
	_licence_wrap.visible = not _licence_wrap.visible


func _build_licence() -> void:
	# One scrollbar only: the outer panel carries the licence text — a well
	# with its own scroll inside a scrolling panel is a wheel-capture trap.
	_licence_wrap.add_theme_constant_override("margin_bottom", 8)
	var body: RichTextLabel = RichTextLabel.new()
	body.fit_content = true
	body.scroll_active = false
	body.selection_enabled = true
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.text = Engine.get_license_text()
	body.add_theme_font_override("normal_font", load(GlassStyle.ALEGREYA_400) as Font)
	body.add_theme_font_size_override("normal_font_size", 12)
	body.add_theme_color_override("default_color", GlassStyle.TEXT_DIM)
	_licence_wrap.add_child(body)


func _add_heading(text: String) -> void:
	var seat: MarginContainer = MarginContainer.new()
	seat.add_theme_constant_override("margin_top", 20)
	_column.add_child(seat)
	var heading: Label = Label.new()
	heading.text = text
	heading.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 2))
	heading.add_theme_font_size_override("font_size", 17)
	heading.add_theme_color_override("font_color", GlassStyle.GOLD)
	heading.add_theme_constant_override("line_spacing", 0)
	seat.add_child(heading)


func _add_body(text: String, colour: Color = GlassStyle.TEXT) -> void:
	_column.add_child(_body_label(text, colour))


func _body_label(text: String, colour: Color) -> Label:
	var body: Label = Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("font", load(GlassStyle.ALEGREYA_400) as Font)
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_color_override("font_color", colour)
	return body


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		closed.emit()


## Scrim `gui_input` never receives keys; Escape closes via the unhandled path.
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
