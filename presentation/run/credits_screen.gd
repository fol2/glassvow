class_name CreditsScreen
extends Control
## Manifest-driven credits overlay — same skeleton as HelpScreen: scrim over
## the living title world, centred glass panel, Escape / scrim-click to close.

signal closed

const PANEL_MAX_WIDTH: float = 640.0
const PANEL_MAX_HEIGHT: float = 0.88
## Matches `GlassStyle.pane` `set_content_margin_all(12)` — the real inset the
## column must subtract when sizing against the pane (not a dead DESKTOP/PHONE
## knob that never bound to the stylebox).
const PANE_INSET: float = 12.0
const MUSIC_MANIFEST: String = "res://assets/audio/music/manifest.json"
const SFX_MANIFEST: String = "res://assets/audio/sfx/manifest.json"

const FONT_LICENCES: Array[Dictionary] = [
	{"family": "Cinzel", "path": "res://assets/fonts/OFL-Cinzel.txt"},
	{"family": "Alegreya", "path": "res://assets/fonts/OFL-Alegreya.txt"},
	# OFL.txt's copyright reads "Adobe ... Reserved Font Name 'Source'" and
	# that IS Noto Sans TC's genuine declaration: Adobe manufactures Noto CJK
	# for Google (derived from Source Han Sans) — verified against the TTF's
	# own name table (nameID 8 = Adobe).
	{"family": "Noto Sans TC", "path": "res://assets/fonts/OFL.txt"},
]

var shape: StringName = StageShape.IDENTITY

var _panel: PanelContainer
var _column: VBoxContainer
var _scroll: ScrollContainer
var _sfx: SfxBus
var _licence_wrap: MarginContainer
var _licence_toggle: Button
var _licence_built: bool = false
var _font_licence_wrap: MarginContainer
var _font_licence_toggle: Button
var _font_licence_built: bool = false


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
	title.text = Locale.active.t("ui.credits.title")
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

	_add_heading(Locale.active.t("ui.credits.headingBrand"))
	_add_body(Locale.active.t("ui.credits.bodyBrand"))

	_add_heading(Locale.active.t("ui.credits.headingGlass"))
	_add_body(Locale.active.t("ui.credits.bodyGlass"))

	_add_heading(Locale.active.t("ui.credits.headingMusic"))
	_add_pack_id("stained-glass-v1")
	var music_manifest: Variant = _read_manifest(MUSIC_MANIFEST)
	_add_music_attribution(music_manifest)
	_add_music_rows(music_manifest)

	_add_heading(Locale.active.t("ui.credits.headingSound"))
	_add_pack_id("ashglass-v1")
	_add_sfx_rows(_read_manifest(SFX_MANIFEST))

	_add_heading(Locale.active.t("ui.credits.headingType"))
	_add_body(Locale.active.t("ui.credits.bodyCinzel"))
	_add_body(Locale.active.t("ui.credits.bodyAlegreya"))
	_add_body(Locale.active.t("ui.credits.bodyNoto"))
	_add_font_licence_fold()

	_add_heading(Locale.active.t("ui.credits.headingEngine"))
	_add_body(Locale.active.t("ui.credits.bodyEngine"))
	_add_licence_fold()

	var footer: Label = _body_label(
		Locale.active.t("ui.credits.footer"), GlassStyle.TEXT_DIM)
	var footer_seat: MarginContainer = MarginContainer.new()
	footer_seat.add_theme_constant_override("margin_top", 14)
	footer_seat.add_child(footer)
	_column.add_child(footer_seat)

	# Fixed-foot seam: gold hairline marks the scroll/foot boundary so the
	# last track title is not sliced against the Close row (#54 NIT).
	var hairline: ColorRect = ColorRect.new()
	hairline.custom_minimum_size = Vector2(0, 1)
	hairline.color = Color(GlassStyle.GOLD, 0.25)
	hairline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hairline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(hairline)

	# The panel's primary action is LEAVING it — a visible, focused dismiss
	# at the foot of the pane, outside the scroll so it never hides below
	# the fold (Help's "Fight On" contract). First-frame focus lands here.
	var close_centre: CenterContainer = CenterContainer.new()
	shell.add_child(close_centre)
	var close: Button = Button.new()
	close.text = Locale.active.t("ui.credits.close")
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
	var panel_width: float = minf(PANEL_MAX_WIDTH, stage_size.x)
	var panel_height: float = stage_size.y if phone else stage_size.y * PANEL_MAX_HEIGHT
	_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	_column.custom_minimum_size.x = maxf(240.0, panel_width - PANE_INSET * 2.0)


func _read_manifest(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _add_music_attribution(manifest: Variant) -> void:
	var count: int = 0
	if typeof(manifest) == TYPE_DICTIONARY:
		var pack: Dictionary = manifest
		var items_raw: Variant = pack.get("items", null)
		if typeof(items_raw) == TYPE_DICTIONARY:
			var items: Dictionary = items_raw
			count = items.size()
	var line: String = Locale.active.t("ui.credits.musicAttribution")
	if count > 0:
		line = Locale.active.t("ui.credits.musicAttributionCount", {"count": count})
	# Breath below the attribution: its gap to the first track must exceed
	# the track pitch, or the line reads as track zero.
	var seat: MarginContainer = MarginContainer.new()
	seat.add_theme_constant_override("margin_bottom", 8)
	seat.add_child(_body_label(line, GlassStyle.TEXT))
	_column.add_child(seat)


func _add_music_rows(manifest: Variant) -> void:
	if typeof(manifest) != TYPE_DICTIONARY:
		_add_body(Locale.active.t("ui.credits.musicTracklistFallback"), GlassStyle.TEXT_DIM)
		return
	var pack: Dictionary = manifest
	var items_raw: Variant = pack.get("items", null)
	if typeof(items_raw) != TYPE_DICTIONARY:
		_add_body(Locale.active.t("ui.credits.musicTracklistFallback"), GlassStyle.TEXT_DIM)
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
		_add_body(Locale.active.t("ui.credits.musicTracklistFallback"), GlassStyle.TEXT_DIM)
		return
	for track_title: String in titles:
		_add_body(track_title)


func _add_sfx_rows(manifest: Variant) -> void:
	var count: int = 0
	var theme_line: String = Locale.active.t("ui.credits.themeLine")
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
		_add_body(Locale.active.t("ui.credits.sfxAttributionCount", {"count": count}))
	else:
		_add_body(Locale.active.t("ui.credits.sfxAttribution"))
	_add_body(theme_line, GlassStyle.TEXT_DIM)


func _add_licence_fold() -> void:
	var seat: MarginContainer = MarginContainer.new()
	seat.add_theme_constant_override("margin_top", 8)
	_column.add_child(seat)
	var fold: VBoxContainer = VBoxContainer.new()
	fold.add_theme_constant_override("separation", 8)
	seat.add_child(fold)

	_licence_toggle = Button.new()
	_licence_toggle.text = Locale.active.t("ui.credits.engineLicences")
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


func _add_font_licence_fold() -> void:
	var seat: MarginContainer = MarginContainer.new()
	seat.add_theme_constant_override("margin_top", 8)
	_column.add_child(seat)
	var fold: VBoxContainer = VBoxContainer.new()
	fold.add_theme_constant_override("separation", 8)
	seat.add_child(fold)

	_font_licence_toggle = Button.new()
	_font_licence_toggle.text = Locale.active.t("ui.credits.fontLicences")
	_font_licence_toggle.custom_minimum_size = Vector2(0, 36)
	_font_licence_toggle.add_theme_font_override("font",
		load(GlassStyle.ALEGREYA_400) as Font)
	_font_licence_toggle.add_theme_font_size_override("font_size", 15)
	GlassStyle.style_button(_font_licence_toggle, GlassStyle.GLASS)
	_font_licence_toggle.pressed.connect(_on_font_licence_toggle)
	fold.add_child(_font_licence_toggle)

	_font_licence_wrap = MarginContainer.new()
	_font_licence_wrap.visible = false
	fold.add_child(_font_licence_wrap)


func _on_licence_toggle() -> void:
	_sfx.play(&"click")
	if not _licence_built:
		_build_licence()
		_licence_built = true
	_licence_wrap.visible = not _licence_wrap.visible
	if _licence_wrap.visible:
		_scroll.ensure_control_visible.call_deferred(_licence_wrap)


func _on_font_licence_toggle() -> void:
	_sfx.play(&"click")
	if not _font_licence_built:
		_build_font_licences()
		_font_licence_built = true
	_font_licence_wrap.visible = not _font_licence_wrap.visible
	if _font_licence_wrap.visible:
		_scroll.ensure_control_visible.call_deferred(_font_licence_wrap)


func _build_licence() -> void:
	# One scrollbar only: the outer panel carries the licence text — a well
	# with its own scroll inside a scrolling panel is a wheel-capture trap.
	_licence_wrap.add_theme_constant_override("margin_bottom", 8)
	var fold: VBoxContainer = VBoxContainer.new()
	fold.add_theme_constant_override("separation", 8)
	fold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_licence_wrap.add_child(fold)

	var engine_text: RichTextLabel = _licence_body(Engine.get_license_text())
	fold.add_child(engine_text)

	fold.add_child(_fold_heading(Locale.active.t("ui.credits.components")))

	var copyright_info: Array = Engine.get_copyright_info()
	for entry_raw: Variant in copyright_info:
		if typeof(entry_raw) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_raw
		var lines: PackedStringArray = PackedStringArray()
		var parts_raw: Variant = entry.get("parts", [])
		if typeof(parts_raw) == TYPE_ARRAY:
			var parts: Array = parts_raw
			for part_raw: Variant in parts:
				if typeof(part_raw) != TYPE_DICTIONARY:
					continue
				var part: Dictionary = part_raw
				var cr_raw: Variant = part.get("copyright", [])
				var cr_bits: PackedStringArray = PackedStringArray()
				if typeof(cr_raw) == TYPE_ARRAY:
					var cr_list: Array = cr_raw
					for cr_item: Variant in cr_list:
						cr_bits.append(str(cr_item))
				elif typeof(cr_raw) == TYPE_STRING:
					var cr_str: String = str(cr_raw).strip_edges()
					if not cr_str.is_empty():
						cr_bits.append(cr_str)
				if not cr_bits.is_empty():
					lines.append("© " + "; ".join(cr_bits))
				var lic_id: String = str(part.get("license", "")).strip_edges()
				if not lic_id.is_empty():
					lines.append(lic_id)
		# Two-tier entry: the name a step brighter than its © lines, and the
		# intra-entry gap tighter than the roll's separation, so ~100
		# near-identical entries stay scannable.
		var component: VBoxContainer = VBoxContainer.new()
		component.add_theme_constant_override("separation", 2)
		var name_line: Label = Label.new()
		name_line.text = str(entry.get("name", ""))
		name_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_line.add_theme_font_override("font", load(GlassStyle.ALEGREYA_400) as Font)
		name_line.add_theme_font_size_override("font_size", 12)
		name_line.add_theme_color_override("font_color", GlassStyle.TEXT)
		component.add_child(name_line)
		if not lines.is_empty():
			var part_lines: Label = Label.new()
			part_lines.text = "\n".join(lines)
			part_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			part_lines.add_theme_font_override("font", load(GlassStyle.ALEGREYA_400) as Font)
			part_lines.add_theme_font_size_override("font_size", 11)
			part_lines.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
			component.add_child(part_lines)
		fold.add_child(component)

	fold.add_child(_fold_heading(Locale.active.t("ui.credits.licenceTexts")))

	var licence_info: Dictionary = Engine.get_license_info()
	for name_raw: Variant in licence_info.keys():
		# Seated heading: the gap above each licence name must beat a blank
		# line inside its body, or the strongest break reads weakest.
		fold.add_child(_fold_heading(str(name_raw)))
		var text_raw: Variant = licence_info[name_raw]
		fold.add_child(_licence_body(str(text_raw), 11))


func _build_font_licences() -> void:
	_font_licence_wrap.add_theme_constant_override("margin_bottom", 8)
	var fold: VBoxContainer = VBoxContainer.new()
	fold.add_theme_constant_override("separation", 8)
	fold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_font_licence_wrap.add_child(fold)

	for entry: Dictionary in FONT_LICENCES:
		var family: String = str(entry["family"])
		var path: String = str(entry["path"])
		fold.add_child(_fold_heading(family))
		if not FileAccess.file_exists(path):
			var missing: Label = Label.new()
			missing.text = "licence file not found: %s" % family
			missing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			missing.add_theme_font_override("font",
				load(GlassStyle.ALEGREYA_400) as Font)
			missing.add_theme_font_size_override("font_size", 11)
			missing.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
			fold.add_child(missing)
			continue
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			var missing_open: Label = Label.new()
			missing_open.text = "licence file not found: %s" % family
			missing_open.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			missing_open.add_theme_font_override("font",
				load(GlassStyle.ALEGREYA_400) as Font)
			missing_open.add_theme_font_size_override("font_size", 11)
			missing_open.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
			fold.add_child(missing_open)
			continue
		fold.add_child(_licence_body(file.get_as_text(), 11))


func _fold_heading(text: String) -> MarginContainer:
	var seat: MarginContainer = MarginContainer.new()
	seat.add_theme_constant_override("margin_top", 12)
	var heading: Label = Label.new()
	heading.text = text
	heading.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 1))
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", GlassStyle.GOLD)
	seat.add_child(heading)
	return seat


func _licence_body(text: String, font_size: int = 12) -> RichTextLabel:
	var body: RichTextLabel = RichTextLabel.new()
	body.fit_content = true
	body.scroll_active = false
	body.selection_enabled = true
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.text = text
	body.add_theme_font_override("normal_font", load(GlassStyle.ALEGREYA_400) as Font)
	body.add_theme_font_size_override("normal_font_size", font_size)
	body.add_theme_color_override("default_color", GlassStyle.TEXT_DIM)
	return body


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


## Pack-id dim line: wrap so the extra breath sits below the id (toward the
## list), not between heading and id.
func _add_pack_id(text: String) -> void:
	var seat: MarginContainer = MarginContainer.new()
	seat.add_theme_constant_override("margin_bottom", 8)
	seat.add_child(_body_label(text, GlassStyle.TEXT_DIM))
	_column.add_child(seat)


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


## Scrim `gui_input` never receives keys; Escape / ui_cancel closes via the
## unhandled path — `_unhandled_input` so gamepad ui_cancel reaches it too.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
