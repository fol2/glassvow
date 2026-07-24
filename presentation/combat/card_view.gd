class_name CardView
extends PanelContainer
## One card as a pane of night glass: a corner cost-gem, a name line over a
## type-tinted divider, and the rules text. The card's type tints its rim, gem
## and divider (ember attacks, glass-blue skills, violet powers). Below the
## style sits the raw pointer surface for the hand's drag state machine — mouse
## and touch both arrive through _gui_input (no emulate_touch_from_mouse); hover
## exists only on the mouse path by nature.

signal pressed_at(uid: int, global_pos: Vector2)
signal moved_to(uid: int, global_pos: Vector2)
signal released_at(uid: int, global_pos: Vector2)
signal hover_changed(uid: int, hovering: bool)

var uid: int = 0
var card_id: StringName = &""
## "enemy" needs a drop on an enemy; everything else plays on release above the hand.
var target_kind: String = ""
var unplayable: bool = false
var playable: bool = true
## Layout home assigned by HandView._relayout; snap-back target.
var home_position: Vector2 = Vector2.ZERO
var home_rotation: float = 0.0

var _held: bool = false


func _init(inst: CardInst, data: Dictionary, cost: int) -> void:
	uid = inst.uid
	card_id = inst.id
	target_kind = str(data.get("target", ""))
	var unplayable_flag: bool = data.get("unplayable", false)
	unplayable = unplayable_flag
	var ctype: String = str(data.get("type", ""))
	var tint: Color = _type_tint(ctype)
	custom_minimum_size = Vector2(152, 194)
	size = custom_minimum_size
	pivot_offset = custom_minimum_size * 0.5

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.085, 0.105, 0.17, 0.98)
	sb.border_color = Color(tint.r, tint.g, tint.b, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(0)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 5
	add_theme_stylebox_override("panel", sb)

	var layer: Control = Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 11
	vbox.offset_right = -11
	vbox.offset_top = 44
	vbox.offset_bottom = -12
	vbox.add_theme_constant_override("separation", 7)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vbox)

	var display_name: String = str(data.get("name", String(inst.id)))
	if inst.up:
		display_name += "+"
	var name_label: Label = Label.new()
	name_label.text = display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", tint.lerp(GlassStyle.TEXT, 0.5))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	var divider: ColorRect = ColorRect.new()
	divider.color = Color(tint.r, tint.g, tint.b, 0.4)
	divider.custom_minimum_size = Vector2(0, 1)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(divider)

	# Web card text wraps numbers in @dmg@ / #block# markers; strip for now.
	var rules_text: String = str(data.get("text", "")).replace("@", "").replace("#", "")
	var body: Label = Label.new()
	body.text = rules_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(body)

	# Cost gem, top-left corner.
	var gem: PanelContainer = PanelContainer.new()
	gem.add_theme_stylebox_override("panel", GlassStyle.gem(tint))
	gem.custom_minimum_size = Vector2(32, 32)
	gem.position = Vector2(7, 6)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cost_label: Label = Label.new()
	cost_label.text = "-" if unplayable else str(cost)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 16)
	cost_label.add_theme_color_override("font_color", Color(0.04, 0.05, 0.09))
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.add_child(cost_label)
	layer.add_child(gem)

	mouse_entered.connect(func() -> void: hover_changed.emit(uid, true))
	mouse_exited.connect(func() -> void: hover_changed.emit(uid, false))


static func _type_tint(ctype: String) -> Color:
	match ctype:
		"attack":
			return GlassStyle.EMBER
		"power":
			return Color(0.72, 0.56, 1.0)
		"status", "curse":
			return Color(0.52, 0.55, 0.64)
		_:
			return GlassStyle.GLASS


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_press_release(mb.pressed, mb.global_position)
		return
	var st: InputEventScreenTouch = event as InputEventScreenTouch
	if st != null:
		# Touch events carry only a control-local position — lift to global.
		_press_release(st.pressed, get_global_transform() * st.position)
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and _held:
		moved_to.emit(uid, mm.global_position)
		return
	var sd: InputEventScreenDrag = event as InputEventScreenDrag
	if sd != null and _held:
		moved_to.emit(uid, get_global_transform() * sd.position)


func _press_release(pressed: bool, global_pos: Vector2) -> void:
	if pressed:
		_held = true
		pressed_at.emit(uid, global_pos)
	elif _held:
		_held = false
		released_at.emit(uid, global_pos)


## Grey out cards the player cannot afford / play right now.
func set_playable(can: bool) -> void:
	playable = can
	modulate = Color(1, 1, 1, 1) if can else Color(0.6, 0.6, 0.6, 0.8)


func snap_home() -> void:
	position = home_position
	rotation = home_rotation
	scale = Vector2.ONE
