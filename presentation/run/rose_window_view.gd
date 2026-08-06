class_name RoseWindowView
extends VBoxContainer
## Six persisted Emberglass panes and the whisper ledger beneath them.

const IDS: Array[String] = [
	"paleOnes", "ownShade", "usurper", "eighthOmen", "unreadablePage",
	"hollowLamplighter",
]
const POSITIONS: Array[Vector2] = [
	Vector2(0.50, 0.15), Vector2(0.78, 0.34), Vector2(0.78, 0.69),
	Vector2(0.50, 0.84), Vector2(0.22, 0.69), Vector2(0.22, 0.34),
]
const MURAL: String = "res://assets/art/meta/emberglass-mural.png"
const FRAME: String = "res://assets/art/meta/emberglass-frame.png"
const MASK: String = "res://assets/art/meta/emberglass-mask-%s.png"
const PANE_SHADER: Shader = preload("res://presentation/run/rose_pane.gdshader")

var shape: StringName = StageShape.IDENTITY

var _quests: Dictionary
var _content: Dictionary
var _whispers: int
var _whisper_lines: Array
var _selected: int
var _window_slot: Control
var _window: Control
var _pane_copies: Array[Control] = []
var _pane_buttons: Array[Button] = []
var _detail: Label
var _log: VBoxContainer


func _init(quests: Dictionary, quest_content: Dictionary, whispers: int,
		whisper_lines: Array, stage_shape: StringName = StageShape.IDENTITY) -> void:
	_quests = quests
	_content = quest_content
	_whispers = maxi(0, whispers)
	_whisper_lines = whisper_lines
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	_selected = _initial_selection()
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build()


func _build() -> void:
	var window_centre: CenterContainer = CenterContainer.new()
	window_centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window_centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(window_centre)

	_window_slot = Control.new()
	_window_slot.custom_minimum_size = Vector2.ONE * 410
	_window_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window_centre.add_child(_window_slot)

	_window = Control.new()
	_window.size = Vector2.ONE * 410
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window_slot.add_child(_window)

	var backdrop: TextureRect = TextureRect.new()
	backdrop.texture = GlassStyle.grad_tex(
		PackedColorArray([
			Color("#1d1f30"), Color("#05070e"), Color(0.02, 0.03, 0.06, 0.0)]),
		PackedFloat32Array([0.0, 0.86, 1.0]), true,
		Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(backdrop)

	for index: int in range(IDS.size()):
		_add_pane(index)

	var frame: TextureRect = TextureRect.new()
	frame.texture = load(FRAME) as Texture2D
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(frame)
	for copy: Control in _pane_copies:
		_window.move_child(copy, _window.get_child_count() - 1)
	for button: Button in _pane_buttons:
		_window.move_child(button, _window.get_child_count() - 1)

	var detail_panel: PanelContainer = PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(620, 50)
	detail_panel.add_theme_stylebox_override("panel", _detail_style())
	add_child(detail_panel)
	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_font_override("font", load(GlassStyle.ALEGREYA_400) as Font)
	_detail.add_theme_font_size_override("font_size", 12)
	_detail.add_theme_color_override("font_color", Color("#c8c6d4"))
	detail_panel.add_child(_detail)

	var log_scroll: ScrollContainer = ScrollContainer.new()
	log_scroll.custom_minimum_size = Vector2(620, 92)
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Without this the view never travels with keyboard focus: Godot moves focus
	# to a control whether or not it is on screen, so a focused entry below the
	# fold is reachable and invisible (issue #72, found on the boon screen).
	log_scroll.follow_focus = true
	log_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(log_scroll)
	_log = VBoxContainer.new()
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.add_theme_constant_override("separation", 4)
	log_scroll.add_child(_log)
	_build_log()
	_refresh_selection()
	set_shape(shape)


func _add_pane(index: int) -> void:
	var id: String = IDS[index]
	var record: Dictionary = _record(id)
	var state: String = _state(record)
	var pane: TextureRect = TextureRect.new()
	pane.texture = load(MASK % id) as Texture2D
	pane.set_anchors_preset(Control.PRESET_FULL_RECT)
	pane.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pane.stretch_mode = TextureRect.STRETCH_SCALE
	pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = PANE_SHADER
	material.set_shader_parameter("mural", load(MURAL) as Texture2D)
	material.set_shader_parameter("show_mural", state == "complete")
	var fill: Color = Color(0.44, 0.41, 0.57, 0.08)
	if state == "armed":
		fill = Color(0.84, 0.88, 1.0, 0.18)
	elif state == "revealed":
		fill = Color(0.68, 0.57, 0.86, 0.28)
	material.set_shader_parameter("fill_colour", fill)
	pane.material = material
	_window.add_child(pane)

	if state != "dormant":
		var copy: PanelContainer = PanelContainer.new()
		copy.position = POSITIONS[index] * 410.0 - Vector2(57, 22)
		copy.size = Vector2(114, 44)
		copy.add_theme_stylebox_override("panel", _copy_style())
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_window.add_child(copy)
		_pane_copies.append(copy)
		var label: Label = Label.new()
		label.text = _pane_copy(id, record)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_override("font", load(GlassStyle.CINZEL_700) as Font)
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", RunStyle.GOLD)
		copy.add_child(label)

	var button: Button = Button.new()
	button.position = POSITIONS[index] * 410.0 - Vector2(57, 29)
	button.size = Vector2(114, 58)
	button.tooltip_text = _pane_accessible_name(index, id, record)
	# Lantern ring overlays; an opaque "focus" box would shadow it
	# (GlassStyle.focus_ring's ADOPTION PREREQUISITE). Radius 9 matches
	# the per-state boxes below.
	button.add_theme_stylebox_override("focus",
		GlassStyle.focus_ring(RunStyle.GOLD, 9))
	button.pressed.connect(_select.bind(index))
	_window.add_child(button)
	_pane_buttons.append(button)


func _select(index: int) -> void:
	_selected = index
	_refresh_selection()


func _refresh_selection() -> void:
	for index: int in range(_pane_buttons.size()):
		var button: Button = _pane_buttons[index]
		for state_name: String in ["normal", "hover", "pressed"]:
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(1)
			style.border_color = Color(RunStyle.GOLD,
				0.38 if index == _selected else (0.22 if state_name == "hover" else 0.0))
			style.set_corner_radius_all(9)
			button.add_theme_stylebox_override(state_name, style)
	var id: String = IDS[_selected]
	var record: Dictionary = _record(id)
	var state: String = _state(record)
	_detail.text = _detail_copy(id, record)
	_detail.add_theme_font_override("font",
		load(GlassStyle.CINZEL_700 if state != "dormant"
			else GlassStyle.ALEGREYA_400) as Font)
	_detail.add_theme_font_size_override("font_size", 16 if state == "armed" else 12)
	_detail.add_theme_color_override(
		"font_color", RunStyle.GOLD if state == "armed" else Color("#c8c6d4"))


func _build_log() -> void:
	var title: Label = Label.new()
	title.text = Locale.active.t("ui.rose.whisperLogTitleUpper")
	title.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 1))
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", RunStyle.GOLD_DIM)
	_log.add_child(title)
	var heard: int = mini(_whispers, _whisper_lines.size())
	for index: int in range(heard):
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_log.add_child(row)
		var number: Label = Label.new()
		number.text = str(index + 1)
		number.custom_minimum_size.x = 20
		number.add_theme_color_override("font_color", RunStyle.GOLD_DIM)
		row.add_child(number)
		var line: Label = Label.new()
		line.text = str(_whisper_lines[index])
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_override("font", load(GlassStyle.ALEGREYA_400) as Font)
		line.add_theme_font_size_override("font_size", 12)
		line.add_theme_color_override("font_color", RunStyle.TEXT_DIM)
		row.add_child(line)
	if _whispers > _whisper_lines.size():
		var final: Label = Label.new()
		final.text = Locale.active.t("ui.rose.finalWhisperMark")
		final.add_theme_color_override("font_color", RunStyle.TEXT_DIM)
		_log.add_child(final)


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	var diameter: float = 300.0 if shape == &"phone-portrait" \
		else (250.0 if shape == &"phone-landscape" else 410.0)
	var scale_factor: float = diameter / 410.0
	_window_slot.custom_minimum_size = Vector2.ONE * diameter
	_window.size = Vector2.ONE * 410.0
	_window.scale = Vector2.ONE * scale_factor
	_window.pivot_offset = Vector2.ZERO


func _initial_selection() -> int:
	for wanted: String in ["revealed", "armed", "complete"]:
		for index: int in range(IDS.size()):
			if _state(_record(IDS[index])) == wanted:
				return index
	return 0


func _record(id: String) -> Dictionary:
	var value: Variant = _quests.get(id, {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _quest(id: String) -> Dictionary:
	var value: Variant = _content.get(id, {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


static func _state(record: Dictionary) -> String:
	var state: String = str(record.get("state", "dormant"))
	return state if state in ["dormant", "armed", "revealed", "complete"] else "dormant"


func _pane_copy(id: String, record: Dictionary) -> String:
	var state: String = _state(record)
	if state == "armed":
		return "???"
	if state == "complete":
		return "%s\nShard recovered" % str(_quest(id).get("name", id))
	return "%s\n%s/%s" % [
		_quest(id).get("name", id), record.get("progress", 0),
		_quest(id).get("target", 0)]


func _detail_copy(id: String, record: Dictionary) -> String:
	var state: String = _state(record)
	if state == "armed":
		return "???"
	if state == "revealed":
		return "%s\n%s\n%s/%s" % [
			_quest(id).get("name", id), _quest(id).get("inscription", ""),
			record.get("progress", 0), _quest(id).get("target", 0)]
	if state == "complete":
		return "%s\nShard recovered" % str(_quest(id).get("name", id))
	return "This pane is dark."


func _pane_accessible_name(index: int, id: String, record: Dictionary) -> String:
	var state: String = _state(record)
	if state == "dormant":
		return "Dormant Emberglass pane %d" % (index + 1)
	if state == "armed":
		return "Unknown Emberglass pane %d" % (index + 1)
	return _detail_copy(id, record).replace("\n", ", ")


static func _copy_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.020, 0.043, 0.76)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(3)
	return style


static func _detail_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.031, 0.035, 0.063, 0.82)
	style.set_border_width_all(1)
	style.border_color = Color(RunStyle.GOLD, 0.20)
	style.set_corner_radius_all(9)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style
