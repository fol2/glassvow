class_name TreasureScreen
extends Control
## Benchmark treasure presentation. The reserved claim is display-only here.

signal continue_requested

const PANEL_WIDTH: float = 560.0
const TOP_INSET: float = 96.0
const ART_WIDTH: float = 340.0
const CHEST: String = "res://assets/art/props/chest.png"
const CHEST_OPEN: String = "res://assets/art/props/chest-open.png"

var shape: StringName = StageShape.IDENTITY

var _claim: Dictionary
var _content: ContentDB
var _opened: bool = false
var _margin: MarginContainer
var _panel: PanelContainer
var _art: TextureRect
var _sub: RichTextLabel
var _actions: HBoxContainer
var _sfx: SfxBus


func _init(claim: Dictionary, content: ContentDB,
		stage_shape: StringName = StageShape.IDENTITY, sfx: SfxBus = null) -> void:
	_claim = claim
	_content = content
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	RunStyle.add_backdrop(self)
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	_build()


func _build() -> void:
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.add_theme_constant_override("margin_left", 12)
	_margin.add_theme_constant_override("margin_right", 12)
	_margin.add_theme_constant_override("margin_bottom", 20)
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
	_panel.custom_minimum_size.x = PANEL_WIDTH
	_panel.add_theme_stylebox_override("panel", RunStyle.panel(16, 28, 0.92))
	centre.add_child(_panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)

	var title: Label = Label.new()
	title.text = "TREASURE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 3))
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", RunStyle.PARCHMENT)
	column.add_child(title)
	column.add_child(_underline())

	_art = TextureRect.new()
	_art.texture = load(CHEST) as Texture2D
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_art.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_art.gui_input.connect(_art_input)
	column.add_child(_art)

	_sub = RichTextLabel.new()
	_sub.bbcode_enabled = true
	_sub.fit_content = true
	_sub.scroll_active = false
	_sub.text = Locale.active.t("ui.treasure.sub")
	_sub.custom_minimum_size.y = 24
	_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub.add_theme_font_override("normal_font", load(GlassStyle.ALEGREYA_400) as Font)
	_sub.add_theme_font_size_override("normal_font_size", 15)
	_sub.add_theme_color_override("default_color", RunStyle.TEXT_DIM)
	column.add_child(_sub)

	_actions = HBoxContainer.new()
	_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions.add_theme_constant_override("separation", 14)
	column.add_child(_actions)
	_actions.add_child(_button(Locale.active.t("ui.treasure.openBtn"), _open))

	resized.connect(_fit)
	set_shape(shape)


func _art_input(event: InputEvent) -> void:
	if not _opened and event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_open()


func _open() -> void:
	if _opened:
		return
	_opened = true
	_sfx.play(&"relic" if _claim.get("relic") != null else &"coin")
	_art.texture = load(CHEST_OPEN) as Texture2D
	_art.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_sub.text = _reward_copy()
	for child: Node in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	_actions.add_child(_button("Continue", _continue))


func _reward_copy() -> String:
	var relic_v: Variant = _claim.get("relic")
	if relic_v != null:
		var id: String = str(relic_v)
		var relic: Dictionary = _content.relics.get(id, {})
		var tone: Color = Color.from_string(str(relic.get("tone", "")), RunStyle.GOLD)
		return "You claim [color=#%s]%s[/color] — [i]%s[/i]" % [
			tone.to_html(false), str(relic.get("name", id)), str(relic.get("text", ""))]
	var gold: int = maxi(0, int(float(str(_claim.get("gold", 0)))))
	if gold > 0:
		return "Only coins remain — [color=#%s]+%d gold[/color]." % [
			RunStyle.GOLD.to_html(false), gold]
	return "The chest lies empty."


func _continue() -> void:
	_sfx.play(&"click")
	continue_requested.emit()


func _button(text: String, pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_override("font", load(GlassStyle.CINZEL_500) as Font)
	button.add_theme_font_size_override("font_size", 17)
	RunStyle.style_button(button, true)
	button.pressed.connect(pressed)
	button.mouse_entered.connect(func() -> void: _sfx.play(&"hover", 0.45))
	return button


func _underline() -> TextureRect:
	var line: TextureRect = TextureRect.new()
	line.custom_minimum_size = Vector2(84, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line.texture = GlassStyle.grad_tex(
		PackedColorArray([Color.TRANSPARENT, RunStyle.GOLD, Color.TRANSPARENT]),
		PackedFloat32Array([0.0, 0.5, 1.0]), false, Vector2.ZERO, Vector2.RIGHT)
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	return line


func _fit() -> void:
	if _panel == null or _art == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var panel_width: float = minf(PANEL_WIDTH, maxf(280.0, size.x - 24.0))
	_panel.custom_minimum_size.x = panel_width
	var art_width: float = minf(ART_WIDTH, panel_width * 0.70)
	_art.custom_minimum_size = Vector2(art_width,
		minf(art_width * 409.0 / 512.0, size.y * 0.42))


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	var top: int = 48 if shape == &"phone-landscape" else (
		70 if shape == &"phone-portrait" else int(TOP_INSET))
	_margin.add_theme_constant_override("margin_top", top)
	_fit()
