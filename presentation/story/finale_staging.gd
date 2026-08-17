class_name FinaleStaging
extends Control
## The finale swap's walk-out beat — the game's one deliberate grammar break
## (07-scenes §5): the last steps to the door are walked by the player's own
## hand, never by the dwell timer and never by skip. James picked FORM_HOLD
## off the renders (#312) — the held press walks the step out. FORM_STEP
## (one line per tap) is kept as a dev capture switch only.

const WALK_KEYS: PackedStringArray = [
	"story.finale.b2.l2", "story.finale.b2.l3",
]
const FORM_STEP: StringName = &"step"
const FORM_HOLD: StringName = &"hold"
const HOLD_TIME: float = 0.9
const PIP_SIZE: Vector2 = Vector2(26.0, 4.0)
const PIP_DIM: Color = Color(0.51, 0.60, 0.65, 0.35)

## James ruled hold (#312). Dev capture can still force `--finale-form=step`.
static var form: StringName = FORM_HOLD

var _pips: Array[ColorRect] = []
var _fill: ColorRect


static func walk_key(key: String) -> bool:
	return WALK_KEYS.has(key)


static func caption_key() -> String:
	return "ui.map.openDoor.hold" if form == FORM_HOLD else "ui.map.openDoor.step"


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "FinaleWalk"
	var dock: VBoxContainer = VBoxContainer.new()
	dock.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dock.offset_top = -74.0
	dock.alignment = BoxContainer.ALIGNMENT_CENTER
	dock.add_theme_constant_override("separation", 6)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dock)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(row)
	for i: int in range(WALK_KEYS.size()):
		var pip: ColorRect = ColorRect.new()
		pip.custom_minimum_size = PIP_SIZE
		pip.color = PIP_DIM
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pip)
		_pips.append(pip)
	var fill_seat: CenterContainer = CenterContainer.new()
	fill_seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(fill_seat)
	_fill = ColorRect.new()
	_fill.color = RunStyle.GOLD
	_fill.custom_minimum_size = Vector2(0.0, 2.0)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_seat.add_child(_fill)


## `steps_done` is how many walk lines already lie behind the cursor; the
## pips light one per step so a still render reads the beat's progress.
func present(walking: bool, steps_done: int) -> void:
	visible = walking or steps_done >= WALK_KEYS.size()
	for i: int in range(_pips.size()):
		_pips[i].color = RunStyle.GOLD if i < steps_done else PIP_DIM
	if not walking:
		set_fill(0.0)


## FORM_HOLD progress under the held press; FORM_STEP never fills.
func set_fill(u: float) -> void:
	_fill.custom_minimum_size.x = 140.0 * clampf(u, 0.0, 1.0)
