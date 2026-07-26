class_name HandView
extends Control
## The hand: arc layout + the tap/drag state machine (plan M5). Below the
## slop threshold a release is a tap (inspect); above it the card is dragged
## and the screen decides what a release means (play on an enemy / above the
## hand line, else snap back). Hover raise is mouse-only.

signal card_tapped(uid: int)
signal card_drag_moved(uid: int, global_pos: Vector2)
signal card_drag_released(uid: int, global_pos: Vector2)
## Which card the pointer is over, or -1 for none. `cardHover` (combat.js:1375)
## fires only when the answer CHANGES, which is what keeps `sfx.hover()` from
## machine-gunning as the cursor crosses a seat.
signal card_hover_changed(uid: int)
## The drag armed, or was refused because the card can neither be played nor
## burned. `beginCardDrag` (combat.js:1522) answers the first with a hover tick
## and the second with a rejection.
signal card_drag_armed(uid: int)
signal card_drag_refused(uid: int)

const SLOP: float = 14.0
## The fan's gap rule, from the benchmark (combat.js:460). `GAP_MAX` is the
## resting gap; `GAP_BUDGET / count` is what tightens it as the hand grows;
## `STAGE_MARGIN` is the room the chrome keeps at both ends of the stage.
const GAP_MAX: float = 112.0
const GAP_BUDGET: float = 640.0
const STAGE_MARGIN: float = 246.0
## The rest of the fan law, from `src/ui/hand-layout.js` — the benchmark's own
## single source for resting seats. The tilt is a per-seat STEP that shrinks as
## the hand grows (`min(5, 42 / n)`), and the sag is proportional to how far a
## card is tilted, not to the square of its index. The two produce visibly
## different fans: a flat 4-degree step with a `t * t` drop peaks in the middle
## and flattens at the edges, which is the shape this port had and the benchmark
## never did.
const TILT_STEP_MAX: float = 5.0
const TILT_TOTAL_DEG: float = 42.0
const SAG_PER_DEG: float = 3.2
const BASE_Y: float = 26.0
## Seats stop being added past ten; an eleventh card sits on the tenth's seat.
const MAX_CARDS: int = 10
## `handCardBottomInset` for pad-landscape — a resting card's bottom edge sits
## this far above the hand zone's own bottom.
const CARD_INSET: float = 8.0
## `HAND_BOTTOM_INSET` — the deepest a resting card may tuck below the stage
## bottom before the WHOLE fan is lifted to keep it readable. Without this the
## outer cards of a five-card hand hang 62px off the screen and lose their name
## and rules text, which is what the assembled screen was doing.
const BOTTOM_INSET: float = 40.0
const HOVER_RAISE: float = 30.0
## `drawBatchSchedule` (pile-chrome.js:91) — how a wave of draws is paced. One
## card gets the full flight; a wave splits a 500ms budget into a stagger and
## what is left over, so five cards leave the pile 100ms apart and the whole
## deal is done in 680ms however big the hand is.
const DEAL_BUDGET: float = 0.5
const DEAL_FLIGHT_MAX: float = 0.28
const DEAL_FLIGHT_MIN: float = 0.16
const DEAL_STAGGER_MIN: float = 0.04
## `schedule: { flightDur: 200 }` at drain.js:866 — a spent card goes home
## faster than a drawn one arrives.
const SPEND_FLIGHT: float = 0.2
## `flyCardBacks([...], {x, y}, 270, ...)` with the anchor at `r.width * 0.22` —
## how long a targeted card takes to reach its foe, and how small it gets there.
const STRIKE_FLIGHT: float = 0.27
const STRIKE_SCALE: float = 0.22

## Ignore pointer input while the sequencer is busy (input-lock contract).
var locked: bool = false
## Kindle turns every card into fuel, so nothing aims. Mirrors the benchmark's
## `kindleOnly` branch, which sets `free` and clears targeting.
var kindle_mode: bool = false
## How far this box deliberately hangs past the stage's bottom edge — the screen
## that placed it says so, because only the screen knows.
##
## The fan is clamped against the STAGE bottom, not this box's, and deriving that
## line from `global_position` looked equivalent and was not: `_relayout` runs
## when cards are added, `resized` only fires when the SIZE changes, and this box
## is moved into place after that without ever changing size. The seats were laid
## out against a stale position and stayed there — 12px too low, every hand.
var stage_overhang: float = 0.0

## `S.hoveredCard` — the seat the pointer is over, -1 for none. Held here
## rather than inferred per event so the change test has something to compare
## against, and so a card leaving under the cursor cannot leave it stuck.
var hovered_uid: int = -1

var _views: Dictionary = {}  # uid -> CardView
var _order: Array[int] = []  # layout order, independent of z-order changes
var _drag_uid: int = -1
var _dragging: bool = false
## True while the live drag is AIMING rather than carrying: the card holds its
## seat and the screen draws an arc from it. See `is_aiming()`.
var _aiming: bool = false
var _press_pos: Vector2 = Vector2.ZERO
## uid -> the pile face it launched from, in global px. A card in here is
## mid-flight and `_relayout` leaves its transform alone.
var _flight_from: Dictionary = {}


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


## Is the live drag an aim rather than a carry? The screen asks so it knows
## whether to draw the arc.
func is_aiming() -> bool:
	return _dragging and _aiming


## Where an aimed card's arc launches from: the centre of its RESTING seat, in
## global coordinates. `handCardSeatBounds` reads the same thing — the seat, not
## wherever a carried card happens to be.
func seat_centre(uid: int) -> Vector2:
	var view: CardView = _views.get(uid)
	if view == null:
		return Vector2.ZERO
	return global_position + view.home_position + view.size * 0.5


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
	if hovered_uid == uid:
		hovered_uid = -1
		card_hover_changed.emit(-1)
	if _drag_uid == uid:
		_drag_uid = -1
		_dragging = false
		_aiming = false
	_views.erase(uid)
	_order.erase(uid)
	_flight_from.erase(uid)
	remove_child(view)  # detach now — queue_free alone leaves a zombie until frame end
	view.queue_free()
	_relayout()


## Bring the fan in line with the engine's hand without rebuilding it.
##
## `presentation.syncHand` reconciles; this used to `clear()` and re-add every
## card at every drain-idle, which destroys a CardView that is still flying. A
## five-card deal overlaps its flights by design, so the last one was reliably
## in the air when the pump went idle — and it did not land, it was replaced by
## a fresh card already sitting in its seat.
##
## Returns the views now in the fan, in hand order, so the caller can set
## playability without asking for each one back.
func sync_hand(order: Array[int]) -> Array[CardView]:
	var wanted: Dictionary = {}
	for uid: int in order:
		wanted[uid] = true
	for uid_v: Variant in _views.keys():
		var uid: int = uid_v
		if not wanted.has(uid):
			remove_card(uid)
	_order.clear()
	var out: Array[CardView] = []
	for uid: int in order:
		var view: CardView = _views.get(uid)
		if view != null:
			_order.append(uid)
			out.append(view)
	_relayout()
	return out


func clear() -> void:
	for uid_v: Variant in _views.keys():
		var view: CardView = _views[uid_v]
		remove_child(view)
		view.queue_free()
	_views.clear()
	_order.clear()
	_flight_from.clear()
	_drag_uid = -1
	_dragging = false
	_aiming = false


## Cancel an in-flight drag (input lock kicking in mid-gesture).
func cancel_drag() -> void:
	if _drag_uid >= 0:
		var view: CardView = _views.get(_drag_uid)
		if view != null:
			view.snap_home()
	_drag_uid = -1
	_dragging = false
	_aiming = false


func snap_back(uid: int) -> void:
	var view: CardView = _views.get(uid)
	if view != null:
		view.snap_home()


# ---------------------------------------------------------------- layout

## The gap between card centres, from the benchmark's own `handZoneWidth`
## (combat.js:460): capped at 112, tightening as the hand grows so a big hand
## overlaps rather than overflowing, and finally clamped to the stage.
##
## This used to be a flat 120 tapered by `(size.x - 160) / (n - 1)` — which made
## the spread depend on how wide the CONTAINER happened to be rather than on how
## many cards are in the hand. Two screens with the same five cards fanned
## differently, and neither matched the benchmark's 112.
static func fan_gap(count: int, stage_w: float) -> float:
	var n: int = maxi(1, count)
	return minf(GAP_MAX, minf(GAP_BUDGET / float(n),
		(stage_w - STAGE_MARGIN) / float(maxi(n - 1, 1))))


## `handZoneWidth` — the box hugs the fan, so the hand is as wide as it needs to
## be and no wider. The zone stays centred; only its edges move.
static func zone_width(count: int, stage_w: float) -> float:
	var n: int = maxi(1, count)
	var span: float = CardView.CARD_W
	if n > 1:
		span = float(n - 1) * fan_gap(n, stage_w) + CardView.CARD_W
	return minf(stage_w - 24.0, maxf(CardView.CARD_W + 16.0, ceilf(span + 20.0)))


# ---------------------------------------------------------------- dealing

## `drawBatchSchedule` — the gap between one card leaving the pile and the next.
static func deal_stagger(count: int) -> float:
	if count <= 1:
		return 0.0
	return maxf(DEAL_STAGGER_MIN, floorf(DEAL_BUDGET * 1000.0 / float(count)) * 0.001)


## `drawBatchSchedule` — how long one card spends in the air.
static func deal_flight(count: int) -> float:
	if count <= 1:
		return DEAL_FLIGHT_MAX
	return maxf(DEAL_FLIGHT_MIN, minf(DEAL_FLIGHT_MAX, DEAL_BUDGET - deal_stagger(count)))


## Fly a card that is already in the fan in from the draw pile: it waits on the
## pile for its turn, then travels to its seat, growing from the pile's face to
## a hand card's and taking on its seat's tilt as it lands.
func deal_in(uid: int, from: Rect2, delay: float, flight: float) -> void:
	var view: CardView = _views.get(uid)
	if view == null or not is_inside_tree():
		return
	_flight_from[uid] = from
	view.pivot_offset = view.size * 0.5
	_fly_step(0.0, uid)
	var tw: Tween = create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(_fly_step.bind(uid), 0.0, 1.0, flight) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_land.bind(uid))


## The flight itself, as a function of progress rather than a tween aimed at a
## fixed point. The seat is read LIVE on every step, because each further card
## in the same wave re-fans the hand and moves the seat this one is heading for.
## A tween that had been given the old target would land beside its seat and be
## snapped into place a frame later.
func _fly_step(t: float, uid: int) -> void:
	var view: CardView = _views.get(uid)
	if view == null:
		return
	var from: Rect2 = _flight_from.get(uid, Rect2())
	var born: float = from.size.x / CardView.CARD_W if from.size.x > 0.0 else 1.0
	var home: Vector2 = global_position + view.home_position
	# Both ends are measured by the card's CENTRE, so a shrunken card leaves the
	# pile's face rather than hanging off its corner.
	var start: Vector2 = from.get_center() - view.size * 0.5 * born
	view.global_position = start.lerp(home, t)
	view.rotation = view.home_rotation * t
	view.scale = Vector2.ONE * lerpf(born, 1.0, t)


func _land(uid: int) -> void:
	_flight_from.erase(uid)
	var view: CardView = _views.get(uid)
	if view != null:
		view.scale = Vector2.ONE
		view.snap_home()


## A card leaves the hand for a pile. It is out of the fan the moment this is
## called — the others close the gap immediately, as they do in the benchmark —
## and the node lives only long enough to fly.
func spend_to(uid: int, to: Rect2) -> void:
	var view: CardView = _views.get(uid)
	if view == null:
		return
	_views.erase(uid)
	_order.erase(uid)
	_flight_from.erase(uid)
	if _drag_uid == uid:
		_drag_uid = -1
		_dragging = false
		_aiming = false
	if not is_inside_tree():
		remove_child(view)
		view.queue_free()
		_relayout()
		return
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.pivot_offset = view.size * 0.5
	var shrink: float = to.size.x / CardView.CARD_W if to.size.x > 0.0 else 1.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(view, "global_position",
		to.get_center() - view.size * 0.5 * shrink, SPEND_FLIGHT) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(view, "scale", Vector2.ONE * shrink, SPEND_FLIGHT)
	tw.tween_property(view, "rotation", 0.0, SPEND_FLIGHT)
	tw.tween_property(view, "modulate:a", 0.0, SPEND_FLIGHT)
	tw.chain().tween_callback(view.queue_free)
	_relayout()


## A targeted card does not leave the hand for a pile — it goes at the foe.
## `drain.js:501`: the card streaks into the enemy and lands at 22% of its own
## size, and only the `toDiscard` that follows moves the pile copy. 270ms, which
## is the window the blow is waiting inside.
func strike_to(uid: int, target: Vector2) -> void:
	var view: CardView = _views.get(uid)
	if view == null:
		return
	_views.erase(uid)
	_order.erase(uid)
	_flight_from.erase(uid)
	if _drag_uid == uid:
		_drag_uid = -1
		_dragging = false
		_aiming = false
	if not is_inside_tree():
		remove_child(view)
		view.queue_free()
		_relayout()
		return
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.move_to_front()
	view.pivot_offset = view.size * 0.5
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(view, "global_position",
		target - view.size * 0.5 * STRIKE_SCALE, STRIKE_FLIGHT) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(view, "scale", Vector2.ONE * STRIKE_SCALE, STRIKE_FLIGHT)
	tw.tween_property(view, "rotation", 0.0, STRIKE_FLIGHT)
	# Held opaque for the first half: a card that fades as it launches never
	# reads as having been thrown at anything.
	tw.tween_property(view, "modulate:a", 0.0, STRIKE_FLIGHT * 0.45) \
		.set_delay(STRIKE_FLIGHT * 0.55)
	tw.chain().tween_callback(view.queue_free)
	_relayout()


# ---------------------------------------------------------------- layout

## `handRotationDeg` — the tilt of seat `i`, in degrees, positive clockwise.
static func rotation_deg(i: int, count: int) -> float:
	var n: int = maxi(1, count)
	if n <= 1:
		return 0.0
	return (float(i) - float(n - 1) * 0.5) * minf(TILT_STEP_MAX, TILT_TOTAL_DEG / float(n))


## `handMaxDrop` — how far the lowest seat of an `n`-card fan hangs below the
## resting baseline.
static func max_drop(count: int) -> float:
	var n: int = maxi(1, mini(MAX_CARDS, count))
	return absf(rotation_deg(0, n)) * SAG_PER_DEG + BASE_Y


## `handFanLift` — how far the whole fan rises, arc intact, so its lowest card
## never tucks more than `BOTTOM_INSET` below the stage bottom.
static func fan_lift(count: int, base_bottom: float, stage_bottom: float) -> float:
	return maxf(0.0, base_bottom + max_drop(count) - (stage_bottom + BOTTOM_INSET))


## Fan the cards along a shallow arc: centred spread, outer cards sit lower
## and tilt outward. `layoutHandSeats` in the benchmark, seat for seat.
func _relayout() -> void:
	var n: int = _order.size()
	if n == 0:
		return
	# The stage the gap is measured against is the window, not this box — the
	# box is sized BY the gap, so reading it here would be circular.
	var stage_w: float = get_viewport_rect().size.x if is_inside_tree() else 1180.0
	# Anchored centred by the screen, so the zone resizes by moving its own
	# edges and stays on the stage's centre line. The WIDTH is measured on the
	# real count; the SEATS stop at ten, so an eleventh card doubles up.
	var want: float = zone_width(n, stage_w)
	if absf(want - size.x) > 0.5 and absf(anchor_left - 0.5) < 0.001:
		offset_left = -want * 0.5
		offset_right = want * 0.5
	var seats: int = maxi(1, mini(MAX_CARDS, n))
	var spacing: float = fan_gap(seats, stage_w)
	var center_x: float = want * 0.5
	# The zone hangs past the stage bottom on purpose, so the line the fan is
	# clamped against sits `stage_overhang` above this box's own bottom.
	var base_bottom: float = size.y - CARD_INSET
	var lift: float = fan_lift(seats, base_bottom, size.y - stage_overhang)
	for i: int in range(n):
		var view: CardView = _views[_order[i]]
		var idx: int = mini(i, seats - 1)
		var rot: float = rotation_deg(idx, seats)
		var offset_x: float = (float(idx) - float(seats - 1) * 0.5) * spacing
		var sag: float = absf(rot) * SAG_PER_DEG + BASE_Y
		view.home_position = Vector2(
			center_x + offset_x - view.size.x * 0.5,
			base_bottom - CardView.CARD_H + sag - lift
		)
		view.home_rotation = deg_to_rad(rot)
		# A card being carried follows the pointer, and a card in flight is on its
		# own clock — it reads the seat set just above on its next step, so the
		# new seat is honoured without this function touching its transform.
		if _flight_from.has(view.uid):
			continue
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
			card_drag_refused.emit(uid)
			return  # unplayable cards can be tapped, never dragged
		_dragging = true
		card_drag_armed.emit(uid)
		# `beginCardDrag` (combat.js:1547): a card that targets an enemy AIMS —
		# it keeps its seat and the screen throws an arc from it — and every
		# other card is carried. Kindle turns the whole hand into fuel, so
		# nothing aims, which is the benchmark's `kindleOnly` branch.
		_aiming = view.target_kind == "enemy" and not kindle_mode
		if not _aiming:
			view.move_to_front()
			view.rotation = 0.0
	if not _aiming:
		view.global_position = global_pos - view.size * 0.5
	card_drag_moved.emit(uid, global_pos)


func _on_card_released_at(uid: int, global_pos: Vector2) -> void:
	if _drag_uid != uid:
		return
	var was_dragging: bool = _dragging
	_drag_uid = -1
	_dragging = false
	_aiming = false
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
	# `if (S.hoveredCard !== uid)` — the tick and the relayout are on the
	# CHANGE, not on every move the pointer makes inside one seat.
	var next: int = uid if hovering else -1
	if next != hovered_uid and (hovering or hovered_uid == uid):
		hovered_uid = next
		card_hover_changed.emit(next)
	view.snap_home()
	if hovering:
		view.position.y -= HOVER_RAISE
		view.move_to_front()


## Which card the pointer is over, or -1. Front to back, because a fanned hand
## overlaps and the card you can see is the one you mean.
## The card being carried or aimed, or -1. `S.drag.live` — a press that has
## not yet cleared the slop is not a drag and previews nothing.
func dragged_uid() -> int:
	return _drag_uid if _dragging else -1


## `S.drag.free` — the card is being CARRIED rather than aimed, which is what
## lets an `allEnemies` card keep lighting every foe while it is in the air.
func is_free_drag() -> bool:
	return _dragging and not _aiming


func card_at(global_pos: Vector2) -> int:
	for i: int in range(get_child_count() - 1, -1, -1):
		var view: CardView = get_child(i) as CardView
		if view == null:
			continue
		var local: Vector2 = view.get_global_transform().affine_inverse() * global_pos
		if Rect2(Vector2.ZERO, view.size).has_point(local):
			return view.uid
	return -1


## Which dotted keyword the pointer is over, or "". Same front-to-back walk.
func keyword_at(global_pos: Vector2) -> String:
	for i: int in range(get_child_count() - 1, -1, -1):
		var view: CardView = get_child(i) as CardView
		if view == null:
			continue
		var word: String = view.keyword_at(global_pos)
		if word != "":
			return word
	return ""
