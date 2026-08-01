class_name VigilScreen
extends Control
## Cross-run deed hall and the revealed Emberglass Rose Window.

signal back_requested
signal cue_requested(cue: StringName)

const DEED_IDS: PackedStringArray = [
	"paneBreaker", "lanternFed", "ashSermon", "untouched",
	"darkWalker", "spendthrift", "hundredShards", "firstDawn",
]
const ROMAN: PackedStringArray = ["—", "I", "II", "III", "IV", "V"]
const WHISPERS: Array[String] = [
	"There is a colour the Spire refuses to name.",
	"A pale hand has touched the dark side of the glass.",
	"Six spaces wait where no window stands.",
	"The dead climb twice: once in flesh, once in memory.",
	"A lantern without flame is still a key.",
	"Count the panes that do not catch the dawn.",
	"A page can be read only after it survives the summit.",
	"The eighth sign is not written among the seven.",
	"The gaunt keeper remembers the road you did not take.",
	"Pale motes gather like frost around a hidden seam.",
	"Your monument does not always lie down.",
	"The merchant keeps one cold thing beneath the counter.",
	"Broken glyphs are the shadow of a complete sentence.",
	"Five pages make a chapter; five prices make a confession.",
	"Three deaths will teach your shade to speak plainly.",
	"The Vigil has a window, though no wall holds it.",
	"Each shard lights one pane of Emberglass.",
	"The Pale Ones are not hunting you. They are pointing upward.",
	"The Sovereign is a mask worn below the final stair.",
	"When six panes burn, look beyond the summit.",
	"There is a sealed door above the crown.",
	"Its inscription has waited longer than the Vigil.",
	"Bring six shards to the Rose Window.",
	"The climb continues.",
]

var shape: StringName = StageShape.IDENTITY

var _vigil: VigilState
var _content: ContentDB
var _has_rose: bool
var _open_rose: bool
var _sfx: SfxBus
var _panel: PanelContainer
var _deeds_tab: Button
var _rose_tab: Button
var _deed_list: ScrollContainer
var _rose: RoseWindowView
var _rows: Array[PanelContainer] = []
var _arts: Array[TextureRect] = []
var _done: Array[bool] = []


func _init(vigil: VigilState, content: ContentDB,
		stage_shape: StringName = StageShape.IDENTITY,
		open_rose: bool = false) -> void:
	_vigil = vigil
	_content = content
	_has_rose = vigil.unlocks.has("emberglass")
	_open_rose = open_rose
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	RunStyle.add_backdrop(self)
	_sfx = SfxBus.new()
	add_child(_sfx)
	_build()


func _build() -> void:
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.offset_top = 10
	centre.offset_bottom = -10
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size.x = 560
	_panel.add_theme_stylebox_override("panel", RunStyle.panel(16, 28, 0.92))
	centre.add_child(_panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)

	var title: Label = _label("THE VIGIL", 26, RunStyle.GOLD, true)
	title.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 4))
	column.add_child(title)
	var underline: TextureRect = TextureRect.new()
	underline.custom_minimum_size = Vector2(84, 2)
	underline.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	underline.texture = GlassStyle.grad_tex(
		PackedColorArray([Color.TRANSPARENT, RunStyle.GOLD, Color.TRANSPARENT]),
		PackedFloat32Array([0.0, 0.5, 1.0]), false,
		Vector2.ZERO, Vector2.RIGHT)
	underline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	underline.stretch_mode = TextureRect.STRETCH_SCALE
	column.add_child(underline)
	var vow: int = clampi(int(float(str(_vigil.deeds.get("bestVow", 0)))),
		0, ROMAN.size() - 1)
	column.add_child(_label("%d climbs · %d dawns · deepest Vow: %s" % [
		int(float(str(_vigil.deeds.get("runs", 0)))),
		int(float(str(_vigil.deeds.get("wins", 0)))),
		ROMAN[vow]], 13, RunStyle.TEXT_DIM, true))

	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 4)
	column.add_child(tabs)
	_deeds_tab = _tab("DEEDS", _show_deeds)
	tabs.add_child(_deeds_tab)
	if _has_rose:
		_rose_tab = _tab("ROSE WINDOW", _show_rose)
		tabs.add_child(_rose_tab)

	_deed_list = ScrollContainer.new()
	_deed_list.custom_minimum_size = Vector2(500, 459)
	_deed_list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_deed_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_deed_list)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	_deed_list.add_child(rows)
	for id: String in DEED_IDS:
		_add_deed(rows, id)

	if _has_rose:
		_rose = RoseWindowView.new(
			_vigil.quests, _content.quests, _vigil.whispers, WHISPERS, shape)
		_rose.visible = false
		column.add_child(_rose)

	var back: Button = Button.new()
	back.text = "RETURN"
	back.custom_minimum_size = Vector2(150, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	RunStyle.style_button(back)
	back.pressed.connect(func() -> void:
		_sfx.play(&"click")
		back_requested.emit()
	)
	column.add_child(back)
	if _open_rose and _has_rose:
		_show_rose()
	else:
		_show_deeds()
	set_shape(shape)


func _add_deed(parent: VBoxContainer, id: String) -> void:
	var deed_v: Variant = _content.deeds.get(id, {})
	if typeof(deed_v) != TYPE_DICTIONARY:
		return
	var deed: Dictionary = deed_v
	var current: int = maxi(0,
		int(float(str(_vigil.deeds.get(str(deed.get("stat")), 0)))))
	var target: int = maxi(1, int(float(str(deed.get("n", 1)))))
	var done: bool = current >= target

	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _deed_style(done))
	parent.add_child(panel)
	_rows.append(panel)
	_done.append(done)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var art: TextureRect = TextureRect.new()
	art.texture = load("res://assets/art/deeds/%s.png" % id) as Texture2D
	art.custom_minimum_size = Vector2(48, 48)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(art)
	_arts.append(art)

	var body: VBoxContainer = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 2)
	row.add_child(body)
	var head: HBoxContainer = HBoxContainer.new()
	body.add_child(head)
	var name: Label = _label(
		("%s " % "✦" if done else "") + str(deed.get("name", id)),
		14, RunStyle.GOLD if done else RunStyle.PARCHMENT, false)
	name.add_theme_font_override("font", load(GlassStyle.CINZEL_500) as Font)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(_label("%d/%d" % [mini(current, target), target],
		12, RunStyle.TEXT_DIM, false))
	var desc: Label = _label("%s → %s" % [
		deed.get("desc", ""), _reward_names(deed.get("unlocks", []))],
		12, Color("#aab4d2"), false)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(desc)
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size.y = 5
	bar.max_value = target
	bar.value = mini(current, target)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _bar_style(Color(0, 0, 0, 0.5)))
	bar.add_theme_stylebox_override("fill", _bar_style(
		Color("#fff3d6") if done else RunStyle.GOLD))
	body.add_child(bar)


func _reward_names(unlocks_v: Variant) -> String:
	var names: PackedStringArray = []
	var unlocks: Array = unlocks_v if typeof(unlocks_v) == TYPE_ARRAY else []
	for unlock_v: Variant in unlocks:
		var unlock: String = str(unlock_v)
		if unlock == "aspect2":
			names.append("The Ashwarden")
			continue
		var bits: PackedStringArray = unlock.split(":", false, 1)
		if bits.size() != 2:
			names.append(unlock)
			continue
		var registry: Dictionary = _content.cards if bits[0] == "card" \
			else _content.relics
		names.append(str(registry.get(bits[1], {}).get("name", bits[1])))
	return ", ".join(names)


func _show_deeds() -> void:
	_deed_list.visible = true
	if _rose != null:
		_rose.visible = false
	_panel.custom_minimum_size.x = 560
	_style_tabs(false)
	cue_requested.emit(&"vigil")


func _show_rose() -> void:
	if _rose == null:
		return
	_deed_list.visible = false
	_rose.visible = true
	_panel.custom_minimum_size.x = 720
	_style_tabs(true)
	cue_requested.emit(&"roseWindow")


func _style_tabs(rose_open: bool) -> void:
	_style_tab(_deeds_tab, not rose_open)
	if _rose_tab != null:
		_style_tab(_rose_tab, rose_open)


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	var phone: bool = shape in [&"phone-portrait", &"phone-landscape"]
	_panel.custom_minimum_size.x = 350 if phone else (
		720 if _rose != null and _rose.visible else 560)
	_deed_list.custom_minimum_size = Vector2(302 if phone else 500,
		440 if shape == &"phone-portrait" else (215 if phone else 459))
	for index: int in range(_rows.size()):
		_rows[index].add_theme_stylebox_override(
			"panel", _deed_style(_done[index], 7 if phone else 9))
	for art: TextureRect in _arts:
		art.custom_minimum_size = Vector2.ONE * (40 if phone else 48)
	if _rose != null:
		_rose.set_shape(shape)


func _tab(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(118, 34)
	button.pressed.connect(func() -> void:
		_sfx.play(&"click")
		callback.call()
	)
	return button


static func _style_tab(button: Button, selected: bool) -> void:
	RunStyle.style_button(button, false, RunStyle.GOLD, true)
	button.add_theme_color_override(
		"font_color", RunStyle.GOLD if selected else RunStyle.TEXT_DIM)


static func _label(text: String, font_size: int, colour: Color,
		centred: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", load(GlassStyle.ALEGREYA_400) as Font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER if centred else HORIZONTAL_ALIGNMENT_LEFT)
	return label


static func _deed_style(done: bool, inset: float = 9.0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.118, 0.102, 0.055, 0.42) if done \
		else Color(1, 1, 1, 0.04)
	style.set_border_width_all(1)
	style.border_color = RunStyle.PANEL_LINE if done else Color(1, 1, 1, 0.09)
	style.set_corner_radius_all(10)
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = inset
	style.content_margin_bottom = inset
	return style


static func _bar_style(colour: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(3)
	return style
