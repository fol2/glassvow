class_name HelpScreen
extends Control
## Read-only How to Play overlay, copied from roguecardv2@6e06911.

signal closed

const PANEL_MAX_WIDTH: float = 620.0
const PANEL_MAX_HEIGHT: float = 0.88
const DESKTOP_INSET: float = 28.0
const PHONE_INSET: float = 18.0

const SECTIONS: Array[Dictionary] = [
	{
		"title": "The Climb",
		"body": "Choose a path of lanterns up the Spire. Fight monsters, gather cards, relics and phials, and defeat the boss of each of the <b>{count} acts</b>. Unlit lanterns hide what they hold — but pay a bounty for the walking.",
	},
	{
		"title": "Combat",
		"body": "Each turn you draw <b>5 cards</b> and gain <b>3 Energy</b> (⬤). Play a card by clicking or dragging — attacks need a target when several enemies remain. Enemies telegraph their <b>intent</b> above their heads.",
	},
	{
		"title": "The Glass",
		"body": "Every creature is glass with a row of <b>Facets</b> under its lifebar. Attacks that draw unblocked blood chip a facet (heavy cards chip more). Fill the gauge and the glass <b>SHATTERS</b>: it loses its next action, is Cracked, and spills <b>Embers</b> into your lantern. Time a shatter to deny the blow you can't survive.",
	},
	{
		"title": "The Lantern",
		"body": "Embers fuel your <b>Lantern Art</b> — one signature power, always available, once a turn (press <b>A</b>). Drag any card onto the lantern to <b>kindle</b> it: the card burns away and feeds the lantern 1 ember. Once a turn; curses refuse the fire.",
	},
	{
		"title": "Ward & Statuses",
		"body": "<b>Ward</b> is held light that absorbs damage but expires each turn. <b>Cracked</b> ×1.5 damage taken · <b>Dimmed</b> −25% damage dealt · <b>Brittle</b> −25% Ward · <b>Smolder</b> burns each turn, and leaps to another enemy when its host dies or shatters.",
	},
	{
		"title": "The Fires & The Merchant",
		"body": "Rest sites heal <b>30%</b> or upgrade a card. Shops sell cards, relics, phials — and can <b>remove</b> a card from your deck. Keep your deck lean; every reward is optional.",
	},
	{
		"title": "The Vigil — What Death Leaves Behind",
		"body": "Nothing is wasted. At the foot of each climb the <b>Lamplighter</b> offers a boon and lets you choose your Lantern Art. When you fall, carve one thing into the stone — a <b>monument</b> your next climb can recover in that same act. Every shatter, kindle and slaying feeds lifetime <b>Deeds</b> that unlock new cards, relics, and a second aspect, the <b>Ashwarden</b>. Reach the dawn once and the <b>Vows</b> open: an optional difficulty ladder for those who'd climb a crueler Spire.",
	},
]

var shape: StringName = StageShape.IDENTITY

var _panel: PanelContainer
var _column: VBoxContainer
var _sfx: SfxBus


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
	centre.add_child(_panel)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(scroll)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 4)
	scroll.add_child(_column)

	var title: Label = Label.new()
	title.text = "How to Play"
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
	# HSeparator's separator is a STYLEBOX, not a colour — a Color override
	# is a silent no-op. 0.55 reads as the help title's centred flourish.
	var rule_line: StyleBoxLine = StyleBoxLine.new()
	rule_line.color = Color(RunStyle.GOLD, 0.55)
	rule_line.thickness = 1
	rule.add_theme_stylebox_override("separator", rule_line)
	rule_centre.add_child(rule)

	for section: Dictionary in SECTIONS:
		_add_section(str(section["title"]), str(section["body"]))

	var action_margin: MarginContainer = MarginContainer.new()
	action_margin.add_theme_constant_override("margin_top", 16)
	_column.add_child(action_margin)
	var action_centre: CenterContainer = CenterContainer.new()
	action_margin.add_child(action_centre)
	var fight_on: Button = Button.new()
	fight_on.text = "Fight On"
	fight_on.custom_minimum_size = Vector2(150, 44)
	fight_on.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 1))
	fight_on.add_theme_font_size_override("font_size", 17)
	RunStyle.style_button(fight_on)
	fight_on.pressed.connect(_close_with_sound)
	action_centre.add_child(fight_on)
	fight_on.grab_focus.call_deferred()

	resized.connect(_fit)
	_fit.call_deferred()


func _add_section(title_text: String, body_html: String) -> void:
	var heading: Label = Label.new()
	heading.text = title_text
	heading.add_theme_font_override("font", load(GlassStyle.CINZEL_700) as Font)
	heading.add_theme_font_size_override("font_size", 17)
	heading.add_theme_color_override("font_color", RunStyle.GOLD)
	heading.add_theme_constant_override("line_spacing", 0)
	_column.add_child(heading)

	var body: RichTextLabel = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = body_html.replace("{count}", "3").replace("<b>", "[b]").replace("</b>", "[/b]")
	body.add_theme_font_override("normal_font", load(GlassStyle.ALEGREYA_400) as Font)
	body.add_theme_font_override("bold_font", load(GlassStyle.ALEGREYA_700) as Font)
	body.add_theme_font_size_override("normal_font_size", 16)
	body.add_theme_font_size_override("bold_font_size", 16)
	body.add_theme_color_override("default_color", RunStyle.TEXT)
	body.add_theme_color_override("font_selected_color", RunStyle.PARCHMENT)
	body.add_theme_constant_override("line_separation", 7)
	_column.add_child(body)


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
	_panel.add_theme_stylebox_override(
		"panel", RunStyle.panel(0 if phone else 16, inset, 0.92))
	_column.custom_minimum_size.x = maxf(240.0, panel_width - inset * 2.0)


func _close_with_sound() -> void:
	_sfx.play(&"click")
	closed.emit()


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		closed.emit()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		closed.emit()


## Scrim `gui_input` never receives keys; Escape closes via the unhandled path.
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
