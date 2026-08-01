class_name EmbarkScreen
extends Control
## Aspect/Vow selection, matching the benchmark's one-screen embark flow.

signal begin_requested(aspect: int, vow: int)
signal back_requested

const ROMAN: PackedStringArray = ["0", "I", "II", "III", "IV", "V"]

var shape: StringName = StageShape.IDENTITY

var _aspects: Array
var _vows: Array
var _aspect_unlocked: bool
var _vow_unlocked: int
var _saved_run: bool
var _selected_aspect: int
var _selected_vow: int
var _sfx: SfxBus
var _centre: CenterContainer
var _column: VBoxContainer
var _title: Label
var _sub: Label
var _aspect_row: GridContainer
var _aspect_cards: Array[Button] = []
var _aspect_grids: Array[GridContainer] = []
var _hero_art: Array[TextureRect] = []
var _aspect_copies: Array[VBoxContainer] = []
var _aspect_names: Array[Label] = []
var _aspect_blurbs: Array[Label] = []
var _vow_minus: Button
var _vow_plus: Button
var _vow_level: Label
var _vow_desc: Label
var _actions: GridContainer
var _begin: Button
var _back: Button


func _init(aspects: Array, vows: Array, aspect_unlocked: bool,
		vow_unlocked: int, saved_run: bool, initial_aspect: int = 0,
		initial_vow: int = 0, stage_shape: StringName = StageShape.IDENTITY,
		sfx: SfxBus = null) -> void:
	_aspects = aspects
	_vows = vows
	_aspect_unlocked = aspect_unlocked
	_vow_unlocked = clampi(vow_unlocked, 0, vows.size())
	_saved_run = saved_run
	_selected_aspect = clampi(initial_aspect, 0, maxi(0, aspects.size() - 1)) \
		if aspect_unlocked else 0
	_selected_vow = clampi(initial_vow, 0, _vow_unlocked)
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
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	_centre = CenterContainer.new()
	_centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_centre)

	_column = VBoxContainer.new()
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override("separation", 14)
	_centre.add_child(_column)

	_title = _label("THE CLIMB BEGINS", 26, RunStyle.GOLD, true)
	_title.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 4))
	_column.add_child(_title)

	_sub = _label(
		"Choose how you meet the Spire." if _aspect_unlocked or _vow_unlocked > 0
			else "The lantern is lit. The Spire waits.",
		14, Color(RunStyle.TEXT, 0.75), true)
	_column.add_child(_sub)

	if _aspect_unlocked and _aspects.size() > 1:
		var aspect_label: Label = _label("WHO CARRIES THE LANTERN", 12,
			Color(RunStyle.TEXT, 0.60), true)
		aspect_label.add_theme_font_override(
			"font", RunStyle.tracked(GlassStyle.CINZEL_500, 2))
		_column.add_child(aspect_label)
		_aspect_row = GridContainer.new()
		_aspect_row.columns = 2
		_aspect_row.add_theme_constant_override("h_separation", 16)
		_aspect_row.add_theme_constant_override("v_separation", 8)
		_column.add_child(_aspect_row)
		for index: int in range(_aspects.size()):
			_add_aspect(index)

	if _vow_unlocked > 0:
		_add_vow_picker()

	if _saved_run:
		var warning: Label = _label(
			"Beginning anew abandons your saved climb.", 12, RunStyle.DANGER, true)
		_column.add_child(warning)

	_actions = GridContainer.new()
	_actions.columns = 1
	_actions.custom_minimum_size.x = 340
	_actions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_actions.add_theme_constant_override("h_separation", 7)
	_actions.add_theme_constant_override("v_separation", 8)
	_column.add_child(_actions)

	_begin = _action("BEGIN ANEW" if _saved_run else "BEGIN THE CLIMB", true)
	_begin.pressed.connect(func() -> void:
		_sfx.play(&"click")
		begin_requested.emit(_selected_aspect, _selected_vow)
	)
	_actions.add_child(_begin)
	_back = _action("BACK", false)
	_back.pressed.connect(func() -> void:
		_sfx.play(&"click")
		back_requested.emit()
	)
	_actions.add_child(_back)


func _add_aspect(index: int) -> void:
	var row_value: Variant = _aspects[index]
	if typeof(row_value) != TYPE_DICTIONARY:
		push_warning("embark: aspect %d is not a dictionary" % index)
		return
	var row: Dictionary = row_value
	var card: Button = Button.new()
	card.custom_minimum_size.x = 232
	card.tooltip_text = str(row.get("name", ""))
	card.focus_mode = Control.FOCUS_ALL
	card.pressed.connect(_select_aspect.bind(index))
	card.mouse_entered.connect(func() -> void: _sfx.play(&"hover", 0.45))
	_aspect_row.add_child(card)
	_aspect_cards.append(card)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 1
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.offset_left = 14
	grid.offset_top = 10
	grid.offset_right = -14
	grid.offset_bottom = -11
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(grid)
	_aspect_grids.append(grid)

	var hero: TextureRect = TextureRect.new()
	var hero_path: String = "res://assets/art/heroes/%s.png" % str(row.get("id", ""))
	if ResourceLoader.exists(hero_path):
		hero.texture = load(hero_path) as Texture2D
	hero.custom_minimum_size = Vector2(70, 70)
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_child(hero)
	_hero_art.append(hero)

	var copy: VBoxContainer = VBoxContainer.new()
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 3)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_child(copy)
	_aspect_copies.append(copy)

	var aspect_name: Label = _label(str(row.get("name", "")), 16, RunStyle.GOLD, true)
	aspect_name.add_theme_font_override("font", load(GlassStyle.CINZEL_500) as Font)
	aspect_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aspect_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(aspect_name)
	_aspect_names.append(aspect_name)

	var blurb: Label = _label(str(row.get("blurb", "")), 12, RunStyle.TEXT_DIM, true)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(blurb)
	_aspect_blurbs.append(blurb)
	_refresh_aspects()


func _add_vow_picker() -> void:
	var block: VBoxContainer = VBoxContainer.new()
	block.alignment = BoxContainer.ALIGNMENT_CENTER
	block.add_theme_constant_override("separation", 4)
	_column.add_child(block)

	var stepper: HBoxContainer = HBoxContainer.new()
	stepper.alignment = BoxContainer.ALIGNMENT_CENTER
	stepper.add_theme_constant_override("separation", 14)
	block.add_child(stepper)

	_vow_minus = _step_button("−")
	_vow_minus.pressed.connect(_change_vow.bind(-1))
	stepper.add_child(_vow_minus)
	_vow_level = _label("", 17, RunStyle.PARCHMENT, true)
	_vow_level.custom_minimum_size.x = 118
	_vow_level.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 2))
	stepper.add_child(_vow_level)
	_vow_plus = _step_button("+")
	_vow_plus.pressed.connect(_change_vow.bind(1))
	stepper.add_child(_vow_plus)

	_vow_desc = _label("", 12, RunStyle.TEXT_DIM, true)
	_vow_desc.custom_minimum_size = Vector2(460, 34)
	_vow_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	block.add_child(_vow_desc)
	_refresh_vow()


func _select_aspect(index: int) -> void:
	_selected_aspect = index
	_sfx.play(&"click")
	_refresh_aspects()


func _refresh_aspects() -> void:
	for index: int in range(_aspect_cards.size()):
		RunStyle.style_card(_aspect_cards[index], index == _selected_aspect)


func _change_vow(delta: int) -> void:
	_selected_vow = clampi(_selected_vow + delta, 0, _vow_unlocked)
	_sfx.play(&"click")
	_refresh_vow()


func _refresh_vow() -> void:
	_vow_minus.disabled = _selected_vow == 0
	_vow_plus.disabled = _selected_vow >= _vow_unlocked
	var roman: String = ROMAN[_selected_vow] if _selected_vow < ROMAN.size() \
		else str(_selected_vow)
	var maximum: String = ROMAN[_vow_unlocked] if _vow_unlocked < ROMAN.size() \
		else str(_vow_unlocked)
	_vow_level.text = "VOW %s  / %s" % [roman, maximum]
	if _selected_vow == 0:
		_vow_desc.text = "The Spire as it is. No vows sworn."
		return
	var lines: PackedStringArray = []
	for index: int in range(_selected_vow):
		var row_value: Variant = _vows[index]
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_value
		lines.append("%s — %s" % [row.get("name", ""), row.get("desc", "")])
	_vow_desc.text = "\n".join(lines)


func _ready() -> void:
	resized.connect(_fit)
	_fit()
	_begin.grab_focus()


func set_shape(stage_shape: StringName) -> void:
	if StageShape.REFERENCES.has(stage_shape):
		shape = stage_shape
		_fit()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()


func _fit() -> void:
	if _centre == null:
		return
	_centre.custom_minimum_size = Vector2(maxf(0.0, size.x - 40.0),
		maxf(0.0, size.y - 40.0))
	var phone_portrait: bool = shape == &"phone-portrait"
	var phone_landscape: bool = shape == &"phone-landscape"
	var short_landscape: bool = size.y <= 860.0 and size.x >= 1000.0
	_column.add_theme_constant_override(
		"separation", 6 if phone_landscape else (10 if phone_portrait else 14))
	_title.add_theme_font_size_override(
		"font_size", 20 if phone_landscape else (23 if phone_portrait else 26))
	_sub.add_theme_font_size_override("font_size", 11 if phone_landscape else 14)
	if _aspect_row != null:
		_aspect_row.columns = 1 if phone_portrait else 2
		for index: int in range(_aspect_cards.size()):
			var horizontal: bool = phone_portrait or phone_landscape
			_aspect_grids[index].columns = 2 if horizontal else 1
			var card_size: Vector2 = Vector2(232, 254)
			var hero_size: float = 70 if short_landscape else 92
			if phone_portrait:
				card_size = Vector2(minf(330.0, size.x * 0.88), 84)
				hero_size = 52
			elif phone_landscape:
				card_size = Vector2(252, 66)
				hero_size = 44
			_aspect_cards[index].custom_minimum_size = card_size
			_hero_art[index].custom_minimum_size = Vector2.ONE * hero_size
			_aspect_copies[index].custom_minimum_size.x = maxf(
				80.0, card_size.x - hero_size - 38.0) if horizontal \
				else maxf(80.0, card_size.x - 28.0)
			_aspect_names[index].horizontal_alignment = \
				HORIZONTAL_ALIGNMENT_LEFT if horizontal else HORIZONTAL_ALIGNMENT_CENTER
			_aspect_blurbs[index].horizontal_alignment = \
				HORIZONTAL_ALIGNMENT_LEFT if horizontal else HORIZONTAL_ALIGNMENT_CENTER
			_aspect_names[index].add_theme_font_size_override(
				"font_size", 14 if horizontal else (16 if short_landscape else 18))
			_aspect_blurbs[index].add_theme_font_size_override(
				"font_size", 11 if horizontal else 12)
	if _vow_desc != null:
		_vow_desc.custom_minimum_size.x = minf(
			700.0 if phone_landscape else 460.0, maxf(280.0, size.x - 40.0))
	if _actions != null:
		_actions.columns = 2 if phone_landscape else 1
		_actions.custom_minimum_size.x = 0 if phone_landscape else minf(
			340.0, maxf(280.0, size.x - 40.0))


static func _label(text: String, font_size: int, colour: Color,
		centred: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centred \
		else HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_override("font", load(GlassStyle.ALEGREYA_400) as Font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label


static func _action(text: String, primary: bool) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 1))
	button.add_theme_font_size_override("font_size", 15)
	RunStyle.style_button(button, primary)
	return button


static func _step_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(34, 34)
	button.add_theme_font_size_override("font_size", 20)
	RunStyle.style_button(button, false, RunStyle.GOLD, true)
	return button
