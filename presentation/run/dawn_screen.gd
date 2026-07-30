class_name DawnScreen
extends Control
## Durable Dawn ceremony. The application owns cursor advancement and persistence.

signal deck_requested
signal commit_requested

const ASCENDED: String = "res://assets/art/meta/ascended.png"

var shape: StringName = StageShape.IDENTITY

var _events: Array
var _cursor: int
var _stats: Dictionary
var _sfx: SfxBus
var _margin: MarginContainer
var _panel: PanelContainer
var _title: Label
var _grid: GridContainer
var _stats_grid: GridContainer
var _progress: Label


func _init(events: Array, cursor: int,
		stage_shape: StringName = StageShape.IDENTITY,
		stats: Dictionary = {}) -> void:
	_events = events.duplicate(true)
	_cursor = clampi(cursor, 0, _events.size())
	_stats = stats.duplicate(true)
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	_sfx = SfxBus.new()
	add_child(_sfx)
	_build()


func _build() -> void:
	var art: TextureRect = TextureRect.new()
	art.texture = load(ASCENDED) as Texture2D
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	var wash: ColorRect = ColorRect.new()
	wash.color = Color(0.025, 0.020, 0.035, 0.62)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var centre: CenterContainer = CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_margin.add_child(centre)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", RunStyle.panel(14, 22, 0.88))
	centre.add_child(_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 9)
	_panel.add_child(column)

	_title = _label("ASCENDED", 42, RunStyle.GOLD)
	_title.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 4))
	column.add_child(_title)
	var subtitle: Label = _label("At Dawn, the Vigil remembers.", 15, RunStyle.PARCHMENT)
	column.add_child(subtitle)
	column.add_child(_underline())

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 260
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	if _events.is_empty():
		_grid.add_child(_event_card({"title": "Dawn", "body": "The Vigil is quiet."}, true))
	else:
		for i: int in range(mini(_cursor + 1, _events.size())):
			var event: Dictionary = _events[i]
			_grid.add_child(_event_card(event, i == _cursor and _cursor < _events.size()))

	_build_stats(column)
	_progress = _label(_progress_text(), 11, RunStyle.GOLD_DIM)
	_progress.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 1))
	column.add_child(_progress)
	if _cursor >= _events.size():
		var actions: HFlowContainer = HFlowContainer.new()
		actions.alignment = FlowContainer.ALIGNMENT_CENTER
		actions.add_theme_constant_override("h_separation", 12)
		actions.add_theme_constant_override("v_separation", 8)
		column.add_child(actions)
		var deck: Button = _action_button("VIEW FINAL DECK")
		deck.pressed.connect(func() -> void:
			_sfx.play(&"click")
			deck_requested.emit()
		)
		actions.add_child(deck)
		var commit: Button = _action_button("RETURN TO THE VIGIL")
		commit.pressed.connect(func() -> void:
			_sfx.play(&"click")
			commit_requested.emit()
		)
		actions.add_child(commit)
	set_shape(shape)


func _event_card(event: Dictionary, current: bool) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 92)
	var style: StyleBoxFlat = GlassStyle.pane(RunStyle.GOLD, 0.78 if current else 0.62)
	style.border_color = Color(RunStyle.GOLD, 0.68 if current else 0.22)
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 4)
	card.add_child(stack)
	var kind: String = str(event.get("kind", "memory"))
	var kicker: Label = _label(_event_kicker(kind), 9, RunStyle.GOLD_DIM)
	kicker.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 1))
	stack.add_child(kicker)
	var title: Label = _label(str(event.get("title", "Dawn")), 13, RunStyle.PARCHMENT)
	title.add_theme_font_override("font", load(GlassStyle.CINZEL_700) as Font)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(title)
	var body: Label = _label(str(event.get("body", "")), 11, RunStyle.TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(body)
	return card


func _build_stats(column: VBoxContainer) -> void:
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 4
	_stats_grid.add_theme_constant_override("h_separation", 4)
	_stats_grid.add_theme_constant_override("v_separation", 4)
	_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_stats_grid)
	for row: Array in [
		["floors", "FLOORS"], ["slain", "SLAIN"],
		["elites_bosses", "ELITES + BOSSES"], ["deck_size", "DECK SIZE"],
		["damage_dealt", "DAMAGE DEALT"], ["damage_taken", "DAMAGE TAKEN"],
		["cards_played", "CARDS PLAYED"], ["run_time", "RUN TIME"],
	]:
		var cell: PanelContainer = PanelContainer.new()
		cell.add_theme_stylebox_override("panel", GlassStyle.pane(RunStyle.GOLD, 0.52))
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stats_grid.add_child(cell)
		var stack: VBoxContainer = VBoxContainer.new()
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_child(stack)
		var value: Label = _label(str(_stats.get(row[0], "—")), 17, RunStyle.PARCHMENT)
		value.add_theme_font_override("font", load(GlassStyle.CINZEL_700) as Font)
		stack.add_child(value)
		var caption: Label = _label(str(row[1]), 8, RunStyle.TEXT_DIM)
		caption.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 1))
		stack.add_child(caption)


func _event_kicker(kind: String) -> String:
	match kind:
		"whisper": return "A WHISPER AT DAWN"
		"quest": return "A JOURNEY REVEALED"
		"progress": return "THE JOURNEY CONTINUES"
		"shard": return "EMBERGLASS SHARD"
		"unlock": return "THE VIGIL OPENS"
		_: return "AT DAWN"


func _action_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190, 46)
	button.add_theme_font_override("font", load(GlassStyle.CINZEL_700) as Font)
	RunStyle.style_button(button, true)
	return button


func _progress_text() -> String:
	if _events.is_empty() or _cursor >= _events.size():
		return "DAWN COMPLETE"
	return "DAWN %d OF %d · THE CURRENT MEMORY IS LIT" % [_cursor + 1, _events.size()]


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	match shape:
		&"phone-portrait":
			_apply_shape(14, 350, 42, 2, 380)
		&"pad-portrait":
			_apply_shape(42, 720, 64, 2, 460)
		&"pad-landscape":
			_apply_shape(48, 800, 72, 3, 260)
		&"desktop-landscape":
			_apply_shape(52, 900, 80, 4, 260)
		&"phone-landscape":
			_apply_shape(10, 760, 46, 2, 150)


func _apply_shape(inset: int, panel_width: float, title_size: int,
		columns: int, grid_height: float) -> void:
	for side: String in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, inset)
	_panel.custom_minimum_size.x = panel_width
	_title.add_theme_font_size_override("font_size", title_size)
	_grid.columns = columns
	_grid.get_parent().custom_minimum_size.y = grid_height


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
