class_name HandView
extends Control
## The hand: arc layout + the tap/drag state machine (plan M5). Below the
## slop threshold a release is a tap (inspect); above it the card is dragged
## and the screen decides what a release means (play on an enemy / above the
## hand line, else snap back). Hover raise is mouse-only.

signal card_tapped(uid: int)
signal card_drag_moved(uid: int, global_pos: Vector2)
signal card_drag_released(uid: int, global_pos: Vector2)

const SLOP: float = 14.0
const CARD_SPACING: float = 120.0
const ARC_DROP: float = 14.0
const TILT_DEGREES: float = 4.0
const HOVER_RAISE: float = 30.0

## Ignore pointer input while the sequencer is busy (input-lock contract).
var locked: bool = false

var _views: Dictionary = {}  # uid -> CardView
var _order: Array[int] = []  # layout order, independent of z-order changes
var _drag_uid: int = -1
var _dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # cards take the pointer, not the strip
	resized.connect(_relayout)


func has_card(uid: int) -> bool:
	return _views.has(uid)


func card_view(uid: int) -> CardView:
	var v: CardView = _views.get(uid)
	return v


func uids() -> Array[int]:
	return _order.duplicate()


func add_card(inst: CardInst, data: Dictionary, cost: int) -> CardView:
	if _views.has(inst.uid):
		return _views[inst.uid]
	var view: CardView = CardView.new(inst, data, cost)
	_views[inst.uid] = view
	_order.append(inst.uid)
	add_child(view)
	view.pressed_at.connect(_on_card_pressed_at)
	view.moved_to.connect(_on_card_moved_to)
	view.released_at.connect(_on_card_released_at)
	view.hover_changed.connect(_on_card_hover)
	_relayout()
	return view


func remove_card(uid: int) -> void:
	var view: CardView = _views.get(uid)
	if view == null:
		return
	if _drag_uid == uid:
		_drag_uid = -1
		_dragging = false
	_views.erase(uid)
	_order.erase(uid)
	remove_child(view)  # detach now — queue_free alone leaves a zombie until frame end
	view.queue_free()
	_relayout()


func clear() -> void:
	for uid_v: Variant in _views.keys():
		var view: CardView = _views[uid_v]
		remove_child(view)
		view.queue_free()
	_views.clear()
	_order.clear()
	_drag_uid = -1
	_dragging = false


## Cancel an in-flight drag (input lock kicking in mid-gesture).
func cancel_drag() -> void:
	if _drag_uid >= 0:
		var view: CardView = _views.get(_drag_uid)
		if view != null:
			view.snap_home()
	_drag_uid = -1
	_dragging = false


func snap_back(uid: int) -> void:
	var view: CardView = _views.get(uid)
	if view != null:
		view.snap_home()


# ---------------------------------------------------------------- layout

## Fan the cards along a shallow arc: centered spread, outer cards sit lower
## and tilt outward.
func _relayout() -> void:
	var n: int = _order.size()
	if n == 0:
		return
	var spacing: float = CARD_SPACING
	if n > 1:
		spacing = minf(CARD_SPACING, (size.x - 160.0) / float(n - 1))
	var center_x: float = size.x * 0.5
	var base_y: float = maxf(0.0, size.y - 200.0)
	for i: int in range(n):
		var view: CardView = _views[_order[i]]
		var t: float = float(i) - float(n - 1) * 0.5
		view.home_position = Vector2(
			center_x + t * spacing - view.size.x * 0.5,
			base_y + t * t * ARC_DROP
		)
		view.home_rotation = deg_to_rad(t * TILT_DEGREES)
		if _drag_uid != view.uid or not _dragging:
			view.snap_home()


# ---------------------------------------------------------------- gestures

func _on_card_pressed_at(uid: int, global_pos: Vector2) -> void:
	if locked:
		return
	_drag_uid = uid
	_dragging = false
	_press_pos = global_pos


func _on_card_moved_to(uid: int, global_pos: Vector2) -> void:
	if locked or _drag_uid != uid:
		return
	var view: CardView = _views.get(uid)
	if view == null:
		return
	if not _dragging:
		if global_pos.distance_to(_press_pos) < SLOP:
			return
		if not view.playable:
			return  # unplayable cards can be tapped, never dragged
		_dragging = true
		view.move_to_front()
		view.rotation = 0.0
	view.global_position = global_pos - view.size * 0.5
	card_drag_moved.emit(uid, global_pos)


func _on_card_released_at(uid: int, global_pos: Vector2) -> void:
	if _drag_uid != uid:
		return
	var was_dragging: bool = _dragging
	_drag_uid = -1
	_dragging = false
	if locked:
		snap_back(uid)
		return
	if was_dragging:
		card_drag_released.emit(uid, global_pos)
	else:
		card_tapped.emit(uid)


func _on_card_hover(uid: int, hovering: bool) -> void:
	if locked or _dragging:
		return
	var view: CardView = _views.get(uid)
	if view == null:
		return
	view.snap_home()
	if hovering:
		view.position.y -= HOVER_RAISE
		view.move_to_front()
