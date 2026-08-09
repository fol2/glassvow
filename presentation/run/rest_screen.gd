class_name RestScreen
extends Control
## Benchmark rest-site presentation. The application owns healing and upgrades.

signal action_requested(action: StringName)

const PANEL_WIDTH: float = 560.0
const TOP_INSET: float = 96.0
const ART_WIDTH: float = 340.0
const CAMPFIRE: String = "res://assets/art/props/campfire.png"

var shape: StringName = StageShape.IDENTITY

var _current_hp: int
var _max_hp: int
var _heal_amount: int
var _can_upgrade: bool
var _margin: MarginContainer
var _panel: PanelContainer
var _art: TextureRect
var _sfx: SfxBus


func _init(current_hp: int, max_hp: int, heal_amount: int, can_upgrade: bool,
		stage_shape: StringName = StageShape.IDENTITY, sfx: SfxBus = null) -> void:
	_current_hp = clampi(current_hp, 0, maxi(0, max_hp))
	_max_hp = maxi(0, max_hp)
	_heal_amount = maxi(0, heal_amount)
	_can_upgrade = can_upgrade
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
	# Same reachability defect as #72's boon screen: without this the view never
	# travels with focus, so a button below the fold is focused and invisible.
	scroll.follow_focus = true
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

	var title: Label = _label(Locale.active.t("ui.rest.title"), 26, RunStyle.PARCHMENT)
	title.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 3))
	column.add_child(title)
	column.add_child(_underline())

	_art = TextureRect.new()
	_art.texture = load(CAMPFIRE) as Texture2D
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_art)

	var sub: Label = _label(
		Locale.active.t("ui.rest.sub"), 15, RunStyle.TEXT_DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(sub)

	var actions: HFlowContainer = HFlowContainer.new()
	actions.alignment = FlowContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	column.add_child(actions)

	var rest: Button = _button(Locale.active.t("ui.rest.restHealBtn", {"hp": _heal_amount}), true)
	rest.tooltip_text = Locale.active.t("ui.rest.hpFrac", {"cur": _current_hp, "max": _max_hp})
	rest.pressed.connect(_request.bind(&"heal"))
	actions.add_child(rest)

	var smith: Button = _button("%s %s" % [Locale.active.t("ui.rest.smithBtn"),
		Locale.active.t("ui.rest.smithSub")], false)
	smith.disabled = not _can_upgrade
	smith.pressed.connect(_request.bind(&"upgrade"))
	actions.add_child(smith)

	resized.connect(_fit)
	set_shape(shape)


func _request(action: StringName) -> void:
	_sfx.play(&"click")
	action_requested.emit(action)


func _button(text: String, primary: bool) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_override("font", GlassStyle.face(GlassStyle.CINZEL_500))
	button.add_theme_font_size_override("font_size", 17)
	RunStyle.style_button(button, primary)
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			_sfx.play(&"hover", 0.45)
	)
	return button


func _label(text: String, font_size: int, colour: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", GlassStyle.face(GlassStyle.ALEGREYA_400))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label


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
	_art.custom_minimum_size = Vector2(art_width, minf(art_width, size.y * 0.42))


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	var top: int = 48 if shape == &"phone-landscape" else (
		70 if shape == &"phone-portrait" else int(TOP_INSET))
	_margin.add_theme_constant_override("margin_top", top)
	_fit()
