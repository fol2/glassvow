class_name RunHud
extends Control
## Persistent run chrome for every non-title, non-combat route screen.
##
## Values come from RunState; this leaf only redraws them and signals intent.

signal deck_requested
signal menu_requested
signal potion_requested(slot: int)

const HP_FILL_A: Color = Color("#c22f43")
const HP_FILL_B: Color = Color("#ff7060")

var shape: StringName = StageShape.IDENTITY
var content: ContentDB
var _run: RunState
var _sfx: SfxBus

var _top: Control
var _row: HBoxContainer
var _hp_wrap: VBoxContainer
var _hp_num: Label
var _hp_bar: ProgressBar
var _gold_num: Label
var _title: Label
var _right: HBoxContainer
var _collection: HFlowContainer


func _init(run: RunState, content_ref: ContentDB,
		stage_shape: StringName = StageShape.IDENTITY, sfx: SfxBus = null) -> void:
	_run = run
	content = content_ref
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	_build()
	refresh(run)


func refresh(run: RunState) -> void:
	_run = run
	var player: RunState.Player = run.player
	_hp_num.text = "%d / %d" % [player.hp, player.max_hp]
	_hp_bar.max_value = maxi(1, player.max_hp)
	_hp_bar.value = clampi(player.hp, 0, maxi(1, player.max_hp))
	_gold_num.text = str(player.gold)
	_title.text = _location_text(run)
	_rebuild_right(player)
	_rebuild_collection(run, player)


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	_apply_shape()
	if _run != null:
		_rebuild_right(_run.player)
		_rebuild_collection(_run, _run.player)


func _build() -> void:
	_top = Control.new()
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)

	var fade: TextureRect = TextureRect.new()
	fade.texture = GlassStyle.grad_tex(
		PackedColorArray([
			Color(0.031, 0.039, 0.086, 0.92),
			Color(0.031, 0.039, 0.086, 0.55),
			Color(0.031, 0.039, 0.086, 0.0),
		]),
		PackedFloat32Array([0.0, 0.80, 1.0]), false,
		Vector2(0.5, 0.0), Vector2(0.5, 1.0))
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(fade)

	_row = HBoxContainer.new()
	_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(_row)

	_hp_wrap = VBoxContainer.new()
	_hp_wrap.add_theme_constant_override("separation", 3)
	_hp_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_hp_wrap)
	var hp_line: HBoxContainer = _stat_line("ui/heart")
	_hp_wrap.add_child(hp_line)
	_hp_num = _label("", 17, Color("#ff9aa0"))
	hp_line.add_child(_hp_num)
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size.y = 7
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.add_theme_stylebox_override("background",
		_flat(Color(1.0, 1.0, 1.0, 0.12), 4))
	_hp_bar.add_theme_stylebox_override("fill", _flat(HP_FILL_B, 4))
	_hp_wrap.add_child(_hp_bar)

	var gold_line: HBoxContainer = _stat_line("ui/coin")
	_row.add_child(gold_line)
	_gold_num = _label("", 17, RunStyle.GOLD)
	gold_line.add_child(_gold_num)

	_title = _label("", 14, RunStyle.TEXT_DIM)
	_title.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 2))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_title)

	_right = HBoxContainer.new()
	_right.alignment = BoxContainer.ALIGNMENT_END
	_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_right)

	_collection = HFlowContainer.new()
	_collection.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_collection.offset_left = 10
	_collection.offset_right = -10
	_collection.add_theme_constant_override("h_separation", 2)
	_collection.add_theme_constant_override("v_separation", 2)
	_collection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_collection)
	_apply_shape()


func _rebuild_right(player: RunState.Player) -> void:
	_clear(_right)
	for slot: int in range(player.potions.size()):
		_right.add_child(_potion_seat(slot, player.potions[slot]))
	var icon_side: int = _shape_value(46, 42, 56)
	var button_side: int = _shape_value(40, 38, 44)
	var deck: Button = _art_button("ui/deck", icon_side, button_side, "View deck")
	for state: String in ["normal", "hover", "pressed", "focus"]:
		deck.add_theme_stylebox_override(state, _flat(Color.TRANSPARENT, 0))
	var count: Label = _label(str(player.deck.size()),
		_shape_value(18, 16, 22), Color.WHITE)
	count.set_anchors_preset(Control.PRESET_FULL_RECT)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck.add_child(count)
	deck.pressed.connect(_request.bind(&"deck", -1))
	_right.add_child(deck)
	var menu: Button = _art_button("ui/menu",
		_shape_value(17, 16, 19), _shape_value(36, 34, 40), "Menu")
	menu.pressed.connect(_request.bind(&"menu", -1))
	_right.add_child(menu)


func _potion_seat(slot: int, id: String) -> Control:
	var side: Vector2 = Vector2(_shape_value(32, 30, 38), _shape_value(38, 36, 44))
	var definition: Dictionary = content.potions.get(id, {})
	if id.is_empty():
		var empty: Panel = Panel.new()
		empty.custom_minimum_size = side
		empty.add_theme_stylebox_override("panel", _seat_style(false))
		empty.tooltip_text = "Empty phial seat"
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return empty
	var button: Button = _art_button("potions/" + id,
		_shape_value(25, 24, 30), int(side.x), _tip(definition, "Unknown phial: " + id))
	button.custom_minimum_size = side
	button.add_theme_stylebox_override("normal", _seat_style(true))
	button.pressed.connect(_request.bind(&"potion", slot))
	return button


func _rebuild_collection(run: RunState, player: RunState.Player) -> void:
	_clear(_collection)
	if run.act >= 0 and run.act < run.omens.size() and run.omens[run.act] != null:
		var omen_id: String = str(run.omens[run.act])
		var omen: Dictionary = content.omens.get(omen_id, {})
		_collection.add_child(_content_art("omens", omen_id, omen, true))
	for relic_id: String in player.relics:
		var relic: Dictionary = content.relics.get(relic_id, {})
		_collection.add_child(_content_art("relics", relic_id, relic, false))


func _content_art(folder: String, id: String, definition: Dictionary,
		omen: bool) -> Control:
	var side: int = _shape_value(34 if omen else 38, 30 if omen else 34, 42 if omen else 44)
	var seat: PanelContainer = PanelContainer.new()
	seat.custom_minimum_size = Vector2(side, side)
	seat.tooltip_text = _tip(definition, "Unknown %s: %s" % [folder.trim_suffix("s"), id])
	seat.mouse_filter = Control.MOUSE_FILTER_PASS
	var style: StyleBoxFlat = _seat_style(true)
	style.set_corner_radius_all(side / 2)
	if omen:
		var tone: Color = Color.from_string(str(definition.get("tone", "")), RunStyle.GOLD)
		style.border_color = Color(tone, 0.72)
	seat.add_theme_stylebox_override("panel", style)
	var art: Texture2D = HudBar.icon(folder + "/" + id)
	if art != null:
		var image: TextureRect = TextureRect.new()
		image.texture = art
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seat.add_child(image)
	else:
		_add_fallback(seat, str(definition.get("glyph", "?")),
			Color.from_string(str(definition.get("tone", "")), RunStyle.GOLD))
	return seat


func _apply_shape() -> void:
	var phone_portrait: bool = shape == &"phone-portrait"
	var phone_landscape: bool = shape == &"phone-landscape"
	var bar_height: int = 58 if phone_portrait else (42 if phone_landscape else 56)
	_top.offset_bottom = bar_height
	_row.offset_left = 10 if phone_portrait else 16
	_row.offset_right = -_row.offset_left
	_row.offset_top = 4 if phone_landscape else 6
	_row.offset_bottom = -4 if phone_landscape else -6
	_row.add_theme_constant_override("separation", 10 if shape.begins_with("phone") else 18)
	_right.add_theme_constant_override("separation", 6 if shape.begins_with("phone") else 10)
	_hp_wrap.custom_minimum_size.x = _shape_value(96, 110, 170)
	_title.visible = not phone_portrait
	_collection.offset_top = bar_height + 4
	_collection.offset_bottom = bar_height + _shape_value(78, 70, 96)


func _location_text(run: RunState) -> String:
	if content.acts.is_empty():
		return "UNKNOWN ACT · FLOOR %d" % run.floors_climbed
	var act: Dictionary = content.acts[clampi(run.act, 0, content.acts.size() - 1)]
	return ("%s · FLOOR %d · %s" % [
		str(act.get("name", "Unknown Act")),
		run.floors_climbed,
		str(act.get("bossName", "Unknown Boss")),
	]).to_upper()


func _shape_value(phone_portrait: int, phone_landscape: int, roomy: int) -> int:
	if shape == &"phone-portrait":
		return phone_portrait
	if shape == &"phone-landscape":
		return phone_landscape
	return roomy


func _stat_line(icon_name: String) -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 7)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: TextureRect = TextureRect.new()
	icon.texture = HudBar.icon(icon_name)
	icon.custom_minimum_size = Vector2(14, 14)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon)
	return line


func _art_button(asset: String, art_side: int, button_side: int,
		tip: String) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(button_side, button_side)
	button.tooltip_text = tip
	button.add_theme_stylebox_override("normal", _seat_style(true))
	button.add_theme_stylebox_override("hover", _seat_style(true, RunStyle.GOLD))
	button.add_theme_stylebox_override("pressed", _seat_style(true, RunStyle.PARCHMENT))
	var art: Texture2D = HudBar.icon(asset)
	if art != null:
		var image: TextureRect = TextureRect.new()
		image.texture = art
		image.custom_minimum_size = Vector2(art_side, art_side)
		image.set_anchors_preset(Control.PRESET_CENTER)
		image.position = -Vector2(art_side, art_side) * 0.5
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(image)
	else:
		_add_fallback(button, "?", RunStyle.DANGER)
	button.mouse_entered.connect(func() -> void: _sfx.play(&"hover", 0.45))
	return button


## Escape opens the run menu on every route that hosts this chrome. Keys arrive
## unhandled (full-rect STOP children eat the mouse, not the keyboard); when
## main has a `_modal` overlay up it disables this callback so the overlay owns
## the cancel rung.
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	menu_requested.emit()
	get_viewport().set_input_as_handled()


func _request(kind: StringName, slot: int) -> void:
	_sfx.play(&"click")
	match kind:
		&"deck":
			deck_requested.emit()
		&"menu":
			menu_requested.emit()
		&"potion":
			potion_requested.emit(slot)


func _label(text: String, font_size: int, colour: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", load(GlassStyle.CINZEL_700) as Font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _add_fallback(parent: Control, glyph: String, colour: Color) -> void:
	var fallback: Label = _label(glyph if not glyph.is_empty() else "?", 20, colour)
	fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(fallback)


func _tip(definition: Dictionary, missing: String) -> String:
	if definition.is_empty():
		return missing
	var lines: PackedStringArray = [
		str(definition.get("name", missing)),
		str(definition.get("text", "")),
		str(definition.get("rarity", "")),
	]
	var shown: PackedStringArray = []
	for line: String in lines:
		if not line.is_empty():
			shown.append(line)
	return "\n".join(shown)


func _seat_style(full: bool, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style: StyleBoxFlat = _flat(Color(0.055, 0.071, 0.133, 0.72), 9)
	style.set_border_width_all(1)
	style.border_color = border if border != Color.TRANSPARENT else (
		Color(1.0, 1.0, 1.0, 0.25) if full else Color(0.02, 0.027, 0.055, 1.0))
	return style


func _flat(colour: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(radius)
	return style


func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
