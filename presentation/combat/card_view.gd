class_name CardView
extends PanelContainer
## One card in the hand: cost / name / rules text, plus the raw pointer
## surface for the hand's drag state machine. Mouse and touch both arrive
## through _gui_input (no emulate_touch_from_mouse); hover exists only on
## the mouse path by nature.

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
	custom_minimum_size = Vector2(150, 190)
	size = custom_minimum_size
	pivot_offset = custom_minimum_size * 0.5
	var display_name: String = str(data.get("name", String(inst.id)))
	if inst.up:
		display_name += "+"
	var rules_text: String = str(data.get("text", ""))
	# Web card text wraps numbers in @dmg@ / #block# markers; strip for now —
	# rich text lands with the craft pass.
	rules_text = rules_text.replace("@", "").replace("#", "")
	var cost_line: String = "-" if unplayable else str(cost)
	var body: Label = Label.new()
	body.text = "[%s]  %s\n\n%s" % [cost_line, display_name, rules_text]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE  # pointer belongs to the card
	add_child(body)
	mouse_entered.connect(func() -> void: hover_changed.emit(uid, true))
	mouse_exited.connect(func() -> void: hover_changed.emit(uid, false))


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
