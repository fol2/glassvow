class_name LamplighterScreen
extends Control
## One-screen boon and Lantern Art choice before the first map.

signal confirmed(boon_id: String, art_id: StringName)

var shape: StringName = StageShape.IDENTITY

var _aspect: Dictionary
var _boons: Dictionary
var _arts: Dictionary
var _boon_ids: Array[String] = []
var _selected_boon: String
var _selected_art: StringName
var _sfx: SfxBus
var _column: VBoxContainer
var _hero: TextureRect
var _title: Label
var _sub: Label
var _boon_grid: GridContainer
var _boon_buttons: Dictionary[String, Button] = {}
var _boon_descriptions: Dictionary[String, Label] = {}
var _art_heading: Label
var _art_grid: GridContainer
var _art_buttons: Dictionary[StringName, Button] = {}
var _description: RichTextLabel
var _begin: Button


func _init(aspect: Dictionary, boons: Dictionary, arts: Dictionary,
		boon_ids: Array, selected_art: StringName,
		stage_shape: StringName = StageShape.IDENTITY, sfx: SfxBus = null) -> void:
	_aspect = aspect
	_boons = boons
	_arts = arts
	for id_v: Variant in boon_ids:
		var id: String = str(id_v)
		if boons.has(id):
			_boon_ids.append(id)
	_selected_art = selected_art if arts.has(str(selected_art)) \
		else StringName(str(arts.keys()[0]) if not arts.is_empty() else "")
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	_add_scene()
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	_build()


func _add_scene() -> void:
	RunStyle.add_backdrop(self)


func _build() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 16)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	# At phone-landscape the column measures 517px against a 350px viewport, so
	# CHOOSE A BOON sits 141px below the fold. Focus traversal reaches it either
	# way — Godot moves focus regardless of scroll position — but without
	# `follow_focus` the view never travels with it, so the button the whole
	# screen exists to press is focused and invisible (#72).
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	var centre: CenterContainer = CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)
	_column = VBoxContainer.new()
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override("separation", 8)
	centre.add_child(_column)

	_hero = TextureRect.new()
	var hero_path: String = "res://assets/art/heroes/%s.png" % \
		str(_aspect.get("id", "duskblade"))
	_hero.texture = load(hero_path) as Texture2D
	_hero.custom_minimum_size = Vector2.ONE * 78
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_column.add_child(_hero)
	_title = _label(Locale.active.t("ui.lamp.title"), 34, RunStyle.GOLD, true)
	_title.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 3))
	_column.add_child(_title)
	var aspect_name: String = str(_aspect.get("name", "climber"))
	_sub = _label(Locale.active.t("ui.lamp.sub", {"aspect": aspect_name}),
		14, RunStyle.TEXT_DIM, true)
	_sub.custom_minimum_size.x = 540
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_sub)
	_column.add_child(_section_label(Locale.active.t("ui.lamp.boonLabel").to_upper()))

	_boon_grid = GridContainer.new()
	_boon_grid.columns = mini(3, _boon_ids.size())
	_boon_grid.add_theme_constant_override("h_separation", 14)
	_boon_grid.add_theme_constant_override("v_separation", 10)
	_boon_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(_boon_grid)
	for id: String in _boon_ids:
		_add_boon(id)

	_art_heading = _section_label("%s  %s" % [
		Locale.active.t("ui.lamp.artLabel").to_upper(),
		Locale.active.t("ui.lamp.artHint").to_upper(),
	])
	_column.add_child(_art_heading)
	_art_grid = GridContainer.new()
	_art_grid.columns = _arts.size()
	_art_grid.add_theme_constant_override("h_separation", 9)
	_art_grid.add_theme_constant_override("v_separation", 7)
	_art_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(_art_grid)
	for id_v: Variant in _arts:
		_add_art(StringName(str(id_v)))

	_description = RichTextLabel.new()
	_description.bbcode_enabled = true
	_description.fit_content = true
	_description.scroll_active = false
	_description.custom_minimum_size = Vector2(500, 38)
	_description.add_theme_font_override("normal_font",
		GlassStyle.face(GlassStyle.ALEGREYA_400))
	_description.add_theme_font_size_override("normal_font_size", 13)
	_description.add_theme_color_override("default_color", RunStyle.TEXT_DIM)
	_column.add_child(_description)

	_begin = Button.new()
	_begin.text = Locale.active.t("ui.menu.chooseBoon").to_upper()
	_begin.custom_minimum_size = Vector2(280, 46)
	_begin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_begin.disabled = true
	RunStyle.style_button(_begin, true)
	_begin.pressed.connect(func() -> void:
		_sfx.play(&"relic")
		confirmed.emit(_selected_boon, _selected_art)
	)
	_column.add_child(_begin)
	_refresh()
	set_shape(shape)


func _add_boon(id: String) -> void:
	var boon: Dictionary = _boons[id]
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(210, 142)
	button.tooltip_text = str(boon.get("name", id))
	button.pressed.connect(_select_boon.bind(id))
	_boon_grid.add_child(button)
	_boon_buttons[id] = button
	var copy: VBoxContainer = VBoxContainer.new()
	copy.set_anchors_preset(Control.PRESET_FULL_RECT)
	copy.offset_left = 15
	copy.offset_top = 10
	copy.offset_right = -15
	copy.offset_bottom = -10
	copy.add_theme_constant_override("separation", 3)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(copy)
	var art: TextureRect = TextureRect.new()
	art.texture = load("res://assets/art/boons/%s.png" % id) as Texture2D
	art.custom_minimum_size = Vector2.ONE * 56
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	copy.add_child(art)
	var name: Label = _label(str(boon.get("name", id)), 16, RunStyle.GOLD, false)
	name.add_theme_font_override("font", GlassStyle.face(GlassStyle.CINZEL_500))
	copy.add_child(name)
	var text: Label = _label(str(boon.get("text", "")), 12, RunStyle.TEXT_DIM, false)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(text)
	_boon_descriptions[id] = text


func _add_art(id: StringName) -> void:
	var art: Dictionary = _arts[str(id)]
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(138, 56)
	button.tooltip_text = str(art.get("text", ""))
	button.pressed.connect(_select_art.bind(id))
	_art_grid.add_child(button)
	_art_buttons[id] = button
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 9
	row.offset_top = 7
	row.offset_right = -10
	row.offset_bottom = -7
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var icon: TextureRect = TextureRect.new()
	icon.texture = load("res://assets/art/arts/%s.png" % str(id)) as Texture2D
	icon.custom_minimum_size = Vector2.ONE * 40
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var name: Label = _label(str(art.get("name", id)), 13, RunStyle.TEXT, false)
	name.add_theme_font_override("font", GlassStyle.face(GlassStyle.CINZEL_500))
	row.add_child(name)


func _select_boon(id: String) -> void:
	_selected_boon = id
	_sfx.play(&"click")
	_refresh()


func _select_art(id: StringName) -> void:
	_selected_art = id
	_sfx.play(&"hover", 0.45)
	_refresh()


func _refresh() -> void:
	for id: String in _boon_buttons:
		RunStyle.style_card(_boon_buttons[id], id == _selected_boon)
	for id: StringName in _art_buttons:
		_art_style(_art_buttons[id], id == _selected_art)
	var art_v: Variant = _arts.get(str(_selected_art), {})
	var art: Dictionary = art_v if typeof(art_v) == TYPE_DICTIONARY else {}
	var tone: Color = Color(str(art.get("tone", "#f2c14e")))
	_description.text = "[center][color=#%s][font_size=14][b]%s %s[/b][/font_size][/color] · %s[/center]" % [
		tone.to_html(false), art.get("glyph", ""), art.get("name", ""),
		art.get("text", "")]
	_begin.disabled = _selected_boon.is_empty()
	_begin.text = Locale.active.t("ui.menu.lightTheWay").to_upper() \
		if not _selected_boon.is_empty() \
		else Locale.active.t("ui.menu.chooseBoon").to_upper()


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	var phone: bool = shape in [&"phone-portrait", &"phone-landscape"]
	_hero.custom_minimum_size = Vector2.ONE * (60 if phone else 78)
	_title.add_theme_font_size_override("font_size", 24 if phone else 34)
	_sub.custom_minimum_size.x = 330 if phone else 540
	_column.add_theme_constant_override("separation", 5 if phone else 8)
	_boon_grid.columns = 1 if shape == &"phone-portrait" else (
		3 if not phone else _boon_ids.size())
	_art_grid.columns = 2 if shape == &"phone-portrait" else (
		_arts.size() if not phone else 3)
	for button: Button in _boon_buttons.values():
		button.custom_minimum_size = Vector2(
			300 if shape == &"phone-portrait" else (190 if phone else 210),
			142)
	_description.custom_minimum_size.x = 330 if phone else 500


static func _section_label(text: String) -> Label:
	var label: Label = _label(text, 12, RunStyle.GOLD_DIM, true)
	label.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 2))
	return label


static func _label(text: String, size: int, colour: Color, centred: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", GlassStyle.face(GlassStyle.ALEGREYA_400))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER if centred else HORIZONTAL_ALIGNMENT_LEFT)
	return label


static func _art_style(button: Button, selected: bool) -> void:
	RunStyle.style_button(button, false, RunStyle.GOLD, true)
	for state: String in ["normal", "hover", "pressed"]:
		var style: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
		style.set_corner_radius_all(28)
		style.set_border_width_all(2 if selected else 1)
		style.border_color = RunStyle.GOLD if selected or state == "hover" \
			else RunStyle.PANEL_LINE
		button.add_theme_stylebox_override(state, style)
	# Circular art: the shared ring must match the 28px body radius, not
	# the compact 6 style_button left behind.
	button.add_theme_stylebox_override("focus",
		GlassStyle.focus_ring(RunStyle.GOLD, 28))
