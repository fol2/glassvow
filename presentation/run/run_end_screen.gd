class_name RunEndScreen
extends Control
## Benchmark terminal presentation. The application owns bequests and Vigil commits.

signal bequest_requested(id: String)
signal commit_requested
signal deck_requested

const FALLEN: String = "res://assets/art/meta/fallen.png"

var shape: StringName = StageShape.IDENTITY

var _outcome: String
var _stats: Dictionary
var _bequest_choices: Array
var _bequest_answered: bool
var _fall_floor: int
var _sfx: SfxBus
var _margin: MarginContainer
var _panel: PanelContainer
var _column: VBoxContainer
var _title: Label
var _stats_grid: GridContainer
var _bequest_grid: GridContainer


func _init(outcome: String, stats: Dictionary, bequest_choices: Array,
		bequest_answered: bool, fall_floor: int,
		stage_shape: StringName = StageShape.IDENTITY) -> void:
	_outcome = outcome
	_stats = stats.duplicate(true)
	_bequest_choices = bequest_choices.duplicate(true)
	_bequest_answered = bequest_answered
	_fall_floor = maxi(0, fall_floor)
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	_sfx = SfxBus.new()
	add_child(_sfx)
	_build()


func _build() -> void:
	# "win" never reaches this screen: main short-circuits it to the Dawn
	# ceremony before construction (_show_run_end), exactly as the benchmark's
	# won end-screen is its own render branch (end.js:186).
	if _outcome == "death":
		_add_meta_backdrop(FALLEN)
	else:
		RunStyle.add_backdrop(self)
	_add_vignette()
	if _outcome == "death":
		_add_embers()

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_margin.add_child(scroll)
	var centre: CenterContainer = CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", RunStyle.panel(14, 24, 0.90))
	centre.add_child(_panel)
	_column = VBoxContainer.new()
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override("separation", 9)
	_panel.add_child(_column)

	_title = _label(_title_text(), 42, _title_colour())
	_title.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 4))
	_column.add_child(_title)
	var subtitle: Label = _label(_subtitle_text(), 16, RunStyle.TEXT_DIM)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(subtitle)
	_column.add_child(_underline())
	_build_stats()
	if _outcome == "death" and not _bequest_answered and not _bequest_choices.is_empty():
		_build_bequest()
	else:
		_build_commit()
	set_shape(shape)


func _build_stats() -> void:
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 4
	_stats_grid.add_theme_constant_override("h_separation", 6)
	_stats_grid.add_theme_constant_override("v_separation", 6)
	_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_child(_stats_grid)
	_add_stat("floors", "FLOORS")
	_add_stat("slain", "SLAIN")
	_add_stat("elites_bosses", "ELITES + BOSSES")
	_add_stat("deck_size", "DECK SIZE")
	_add_stat("damage_dealt", "DAMAGE DEALT")
	_add_stat("damage_taken", "DAMAGE TAKEN")
	_add_stat("cards_played", "CARDS PLAYED")
	_add_stat("run_time", "RUN TIME")


func _add_stat(key: String, caption: String) -> void:
	var cell: PanelContainer = PanelContainer.new()
	cell.add_theme_stylebox_override("panel", GlassStyle.pane(RunStyle.GOLD, 0.60))
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_grid.add_child(cell)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_child(stack)
	var value: Label = _label(str(_stats.get(key, "—")), 22, RunStyle.PARCHMENT)
	value.add_theme_font_override("font", load(GlassStyle.CINZEL_700) as Font)
	stack.add_child(value)
	var name_label: Label = _label(caption, 9, RunStyle.TEXT_DIM)
	name_label.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 1))
	stack.add_child(name_label)


func _build_bequest() -> void:
	var copy: Label = _label(
		"Carve one thing into the stone — the next climb may recover it in %s."
		% str(_stats.get("act_name", "this act")), 13, RunStyle.TEXT_DIM)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(copy)
	_bequest_grid = GridContainer.new()
	_bequest_grid.columns = mini(4, _bequest_choices.size())
	_bequest_grid.add_theme_constant_override("h_separation", 10)
	_bequest_grid.add_theme_constant_override("v_separation", 8)
	_bequest_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_child(_bequest_grid)
	for row_v: Variant in _bequest_choices:
		var row: Dictionary = row_v
		var button: Button = _bequest_button(row)
		button.pressed.connect(_request_bequest.bind(str(row.get("id", ""))))
		_bequest_grid.add_child(button)


func _bequest_button(row: Dictionary) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(148, 102)
	RunStyle.style_card(button, false)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.offset_left = 8
	stack.offset_top = 7
	stack.offset_right = -8
	stack.offset_bottom = -7
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(stack)
	var icons: HBoxContainer = HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override("separation", 3)
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(icons)
	for path_v: Variant in [row.get("icon", ""), row.get("art", "")]:
		var path: String = str(path_v)
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var art: TextureRect = TextureRect.new()
		art.texture = load(path) as Texture2D
		art.custom_minimum_size = Vector2(27, 27)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icons.add_child(art)
	var name_label: Label = _label(str(row.get("name", row.get("label", ""))),
		14, RunStyle.PARCHMENT)
	name_label.add_theme_font_override("font", load(GlassStyle.CINZEL_500) as Font)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(name_label)
	var note: Label = _label(str(row.get("note", "")), 11, RunStyle.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(note)
	return button


func _build_commit() -> void:
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	_column.add_child(actions)
	var deck: Button = _action_button("VIEW FINAL DECK")
	deck.pressed.connect(func() -> void:
		_sfx.play(&"click")
		deck_requested.emit()
	)
	actions.add_child(deck)
	var commit: Button = _action_button("RETURN TO THE VIGIL")
	commit.pressed.connect(_request_commit)
	actions.add_child(commit)


func _action_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190, 46)
	button.add_theme_font_override("font", load(GlassStyle.CINZEL_700) as Font)
	RunStyle.style_button(button)
	return button


func _request_bequest(id: String) -> void:
	_sfx.play(&"relic")
	bequest_requested.emit(id)


func _request_commit() -> void:
	_sfx.play(&"click")
	commit_requested.emit()


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	match shape:
		&"phone-portrait":
			_apply_shape(14, 350, 42, 2, 1)
		&"pad-portrait":
			_apply_shape(42, 700, 64, 4, 2)
		&"pad-landscape":
			_apply_shape(54, 780, 72, 4, 4)
		&"desktop-landscape":
			_apply_shape(58, 820, 80, 4, 4)
		&"phone-landscape":
			_apply_shape(10, 720, 46, 4, 2)


func _apply_shape(inset: int, panel_width: float, title_size: int,
		stat_columns: int, bequest_columns: int) -> void:
	for side: String in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, inset)
	_panel.custom_minimum_size.x = panel_width
	_title.add_theme_font_size_override("font_size", title_size)
	_stats_grid.columns = stat_columns
	if _bequest_grid != null:
		_bequest_grid.columns = mini(bequest_columns, _bequest_choices.size())


func _title_text() -> String:
	match _outcome:
		"death": return "FALLEN"
		_: return "THE VOW IS SET ASIDE"


func _subtitle_text() -> String:
	match _outcome:
		"death": return "Your lantern went dark on floor %d." % _fall_floor
		_: return "The pilgrimage ends here. The Vigil will keep the record."


func _title_colour() -> Color:
	return Color("#6a7288") if _outcome == "death" else RunStyle.PARCHMENT


func _add_meta_backdrop(path: String) -> void:
	var art: TextureRect = TextureRect.new()
	art.texture = load(path) as Texture2D
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)


func _add_vignette() -> void:
	var shade: TextureRect = TextureRect.new()
	shade.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(0, 0, 0, 0.16), Color(0, 0, 0, 0.78)]),
		PackedFloat32Array([0.0, 1.0]), true, Vector2(0.5, 0.48), Vector2(1.0, 0.48))
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _add_embers() -> void:
	var layer: Control = Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	for i: int in range(14):
		var ember: ColorRect = ColorRect.new()
		ember.color = Color(1.0, 0.42 + float(i % 3) * 0.10, 0.16, 0.82)
		ember.position = Vector2(70 + (i * 83) % 1040, 110 + (i * 137) % 620)
		ember.size = Vector2(2 + i % 2, 5 + i % 4)
		ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(ember)


static func _label(text: String, font_size: int, colour: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load(GlassStyle.ALEGREYA_400) as Font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label


static func _underline() -> TextureRect:
	var line: TextureRect = TextureRect.new()
	line.custom_minimum_size = Vector2(100, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line.texture = GlassStyle.grad_tex(
		PackedColorArray([Color.TRANSPARENT, RunStyle.GOLD, Color.TRANSPARENT]),
		PackedFloat32Array([0.0, 0.5, 1.0]), false, Vector2.ZERO, Vector2.RIGHT)
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	return line
