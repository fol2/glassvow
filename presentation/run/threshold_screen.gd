class_name ThresholdScreen
extends Control
## Act IV threshold ceremony — the sealed door with all six Emberglass panes lit.

signal threshold_touched
signal vigil_requested

const DESIGN: float = 410.0

var shape: StringName = StageShape.IDENTITY

var _sfx: SfxBus
var _margin: MarginContainer
var _window_slot: Control
var _window: Control
var _answer: VBoxContainer
var _sub: Label
var _cta: Button
var _touched: bool = false


func _init(stage_shape: StringName = StageShape.IDENTITY,
		sfx: SfxBus = null) -> void:
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()

	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)

	_build()


func _build() -> void:
	var ground: TextureRect = TextureRect.new()
	ground.texture = GlassStyle.grad_tex(
		PackedColorArray([GlassStyle.NIGHT_TOP, GlassStyle.NIGHT_BOT]),
		PackedFloat32Array([0.0, 1.0]), false,
		Vector2(0.5, 0.0), Vector2(0.5, 1.0))
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.stretch_mode = TextureRect.STRETCH_SCALE
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.add_theme_constant_override("margin_left", 12)
	_margin.add_theme_constant_override("margin_right", 12)
	_margin.add_theme_constant_override("margin_top", 20)
	_margin.add_theme_constant_override("margin_bottom", 20)
	add_child(_margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_margin.add_child(scroll)

	var centre: CenterContainer = CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)

	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	centre.add_child(column)

	var title: Label = Label.new()
	title.text = "THE SEALED DOOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 3))
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", RunStyle.PARCHMENT)
	column.add_child(title)

	# The reference flourish is a 2px tapered gradient, not a flat hairline
	# (.ov-title::after, styles.css:1649).
	var rule_centre: CenterContainer = CenterContainer.new()
	rule_centre.custom_minimum_size.y = 10
	column.add_child(rule_centre)
	var rule: TextureRect = TextureRect.new()
	rule.texture = GlassStyle.grad_tex(
		PackedColorArray([
			Color(GlassStyle.GOLD, 0.0), GlassStyle.GOLD, Color(GlassStyle.GOLD, 0.0)]),
		PackedFloat32Array([0.0, 0.5, 1.0]), false,
		Vector2(0.0, 0.5), Vector2(1.0, 0.5))
	rule.custom_minimum_size = Vector2(84, 2)
	rule.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rule.stretch_mode = TextureRect.STRETCH_SCALE
	rule_centre.add_child(rule)

	column.add_child(_build_rose())

	# `.ov-sub` is dim in the reference (var(--text-dim), styles.css) — the
	# payoff lives in the inscription, not here.
	_sub = Label.new()
	_sub.text = "Six panes burn behind you. The lock answers, but does not open."
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.add_theme_font_override("font", load(GlassStyle.ALEGREYA_400) as Font)
	_sub.add_theme_font_size_override("font_size", 15)
	_sub.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	column.add_child(_sub)

	# Laid out from the first frame at zero alpha, so the reveal costs no
	# relayout — the CTA must never move out from under the pointer.
	_answer = VBoxContainer.new()
	_answer.modulate.a = 0.0
	_answer.alignment = BoxContainer.ALIGNMENT_CENTER
	_answer.add_theme_constant_override("separation", 6)
	column.add_child(_answer)

	var hold: Label = Label.new()
	hold.text = "The glass holds fast. The way is not yet cut."
	hold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hold.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hold.add_theme_font_override("font", load(GlassStyle.ALEGREYA_400) as Font)
	hold.add_theme_font_size_override("font_size", 16)
	hold.add_theme_color_override("font_color", GlassStyle.TEXT)
	_answer.add_child(hold)

	# The benchmark's emotional close: italic Cinzel, tracked, brighter than
	# parchment (.door-inscription, styles.css:2554).
	var climb: Label = Label.new()
	climb.text = "the climb continues"
	climb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	climb.add_theme_font_override("font", RunStyle.slanted(GlassStyle.CINZEL_500, 1))
	climb.add_theme_font_size_override("font_size", 18)
	climb.add_theme_color_override("font_color", Color("#fff3d6"))
	_answer.add_child(climb)

	# The primary action breathes apart from the copy above it.
	var cta_seat: MarginContainer = MarginContainer.new()
	cta_seat.add_theme_constant_override("margin_top", 20)
	column.add_child(cta_seat)
	var cta_row: CenterContainer = CenterContainer.new()
	cta_seat.add_child(cta_row)
	_cta = Button.new()
	_cta.text = "Stand at the Threshold"
	_cta.custom_minimum_size = Vector2(280, 44)
	_cta.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 1))
	_cta.add_theme_font_size_override("font_size", 17)
	RunStyle.style_button(_cta, true)
	_cta.pressed.connect(_on_cta)
	cta_row.add_child(_cta)
	_cta.grab_focus.call_deferred()

	resized.connect(func() -> void: set_shape(shape))
	set_shape(shape)


func _build_rose() -> Control:
	var window_centre: CenterContainer = CenterContainer.new()
	window_centre.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	_window_slot = Control.new()
	_window_slot.custom_minimum_size = Vector2.ONE * DESIGN
	# PASS, not IGNORE: the tooltip is the rose's accessible name
	# (sealedDoor.aria in the reference).
	_window_slot.mouse_filter = Control.MOUSE_FILTER_PASS
	_window_slot.tooltip_text = "The sealed door"
	window_centre.add_child(_window_slot)

	_window = Control.new()
	_window.size = Vector2.ONE * DESIGN
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

	for id: String in RoseWindowView.IDS:
		var pane: TextureRect = TextureRect.new()
		pane.texture = load(RoseWindowView.MASK % id) as Texture2D
		pane.set_anchors_preset(Control.PRESET_FULL_RECT)
		pane.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pane.stretch_mode = TextureRect.STRETCH_SCALE
		pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = RoseWindowView.PANE_SHADER
		material.set_shader_parameter("mural", load(RoseWindowView.MURAL) as Texture2D)
		material.set_shader_parameter("show_mural", true)
		pane.material = material
		_window.add_child(pane)

	var frame: TextureRect = TextureRect.new()
	frame.texture = load(RoseWindowView.FRAME) as Texture2D
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(frame)

	return window_centre


func _on_cta() -> void:
	_sfx.play(&"click")
	if not _touched:
		_touched = true
		threshold_touched.emit()
		if Preferences.active.reduce_motion:
			_answer.modulate.a = 1.0
		else:
			create_tween().tween_property(_answer, "modulate:a", 1.0, 0.45)
		_cta.text = "Return to the Vigil"
		_cta.grab_focus.call_deferred()
		return
	vigil_requested.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		vigil_requested.emit()
		get_viewport().set_input_as_handled()


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	var diameter: float = 300.0 if shape == &"phone-portrait" \
		else (250.0 if shape == &"phone-landscape" else DESIGN)
	# This strut sets the whole column's width: wide enough that the sub line
	# does not strand "open." alone (needs ~415px at 15pt), narrow enough for
	# phone-portrait to take a balanced two-line wrap instead.
	_sub.custom_minimum_size.x = 340.0 if shape == &"phone-portrait" else 440.0
	var scale_factor: float = diameter / DESIGN
	_window_slot.custom_minimum_size = Vector2.ONE * diameter
	_window.size = Vector2.ONE * DESIGN
	_window.scale = Vector2.ONE * scale_factor
	_window.pivot_offset = Vector2.ZERO


