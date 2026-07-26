class_name AimArc
extends Control
## The targeting arc: a dashed red bow that springs from a seated card up over
## the battlefield to the pointer, with a hollow ring at the far end.
##
## Drawn to match the benchmark's `aimMove` (`combat.js:1063`), which writes an
## SVG path into a full-stage overlay. Every number below is that function's,
## not a fitted approximation:
##
##   P0 = the card's SEAT centre lifted 80px   (`from.y - 80`)
##   C  = ((from.x + to.x) / 2, min(from.y, to.y) - 120)
##   P1 = the pointer
##
## stroked once at width 4, colour rgba(255,89,100,.85) (`--hp` red), with
## SVG `stroke-dasharray: 4 10` — 4px ink then 10px gap along the path's arc
## length, repeating. A long arc therefore gets many small dashes; a short one
## gets few. The reticle is a hollow circle at the pointer, r = 9, stroke 3,
## rgba(255,89,100,.95).
##
## The arc is only ever drawn for a card that targets an enemy. That is not a
## style choice: `beginCardDrag` (`combat.js:1547`) sets targeting for
## `target === 'enemy'` and marks every other card `free`, and the two branches
## look completely different. A free card follows your finger; an aimed card
## STAYS IN ITS SEAT and throws this arc instead. Dragging the card itself in
## both cases — which is what this port did until now — loses the distinction
## the benchmark's whole targeting read is built on.

## SVG `stroke-dasharray: 4 10` — pixels of ink, then gap, measured along the
## path. Duty cycle is the constant 4/14; dash count scales with arc length.
const DASH_INK: float = 4.0
const DASH_GAP: float = 10.0
const DASH_PERIOD: float = DASH_INK + DASH_GAP
## Samples along the Bézier for the arc-length walk. A few hundred is plenty
## for a ~1000px stage arc; denser sampling only costs draw-prep time.
const ARC_SAMPLES: int = 512
## How far above the card centre the arc launches, and how far above the higher
## of the two endpoints the apex floats.
const LAUNCH_LIFT: float = 80.0
const APEX_LIFT: float = 120.0

## Reference `--hp` red (#ff5964) at the SVG stroke alphas.
const INK_COLOUR: Color = Color(1.0, 0.34901962, 0.39215687)  # #ff5964
const INK_WIDTH: float = 4.0
const INK_ALPHA: float = 0.85

const RETICLE_RADIUS: float = 9.0
const RETICLE_WIDTH: float = 3.0
const RETICLE_ALPHA: float = 0.95

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


## Both points are in GLOBAL coordinates; `from` is the card's resting seat
## centre, not wherever the pointer dragged it.
func draw_between(from_global: Vector2, to_global: Vector2) -> void:
	_from = from_global - global_position
	_to = to_global - global_position
	visible = true
	queue_redraw()


func clear_aim() -> void:
	if not visible:
		return
	visible = false
	queue_redraw()


## Quadratic Bézier at `t`, with the control point implied by the endpoints the
## same way `aimMove` (`combat.js:1063`) implies it.
func _point_at(t: float) -> Vector2:
	var p0: Vector2 = Vector2(_from.x, _from.y - LAUNCH_LIFT)
	var c: Vector2 = Vector2((_from.x + _to.x) * 0.5, minf(_from.y, _to.y) - APEX_LIFT)
	var u: float = 1.0 - t
	return u * u * p0 + 2.0 * u * t * c + t * t * _to


## One dash with round caps. Godot's `draw_line` has no cap mode, so the body is
## drawn short by one radius at each end and the caps are discs sitting exactly
## tangent to it — overlapping them instead would double-blend and read as a
## string of beads rather than a clean SVG round-capped stroke.
func _dash(a: Vector2, b: Vector2, colour: Color, width: float) -> void:
	var radius: float = width * 0.5
	var span: Vector2 = b - a
	var length: float = span.length()
	if length > width:
		var step: Vector2 = span / length * radius
		draw_line(a + step, b - step, colour, width, true)
	draw_circle(a, radius, colour)
	draw_circle(b, radius, colour)


## Walk the Bézier by arc length and emit ink where `fmod(distance, 14) < 4`,
## matching SVG `stroke-dasharray: 4 10`. Each contiguous ink run is one
## round-capped `_dash`.
func _draw_dashed_arc(colour: Color, width: float) -> void:
	var prev: Vector2 = _point_at(0.0)
	var distance: float = 0.0
	var in_ink: bool = true
	var dash_start: Vector2 = prev
	for i: int in range(1, ARC_SAMPLES + 1):
		var t: float = float(i) / float(ARC_SAMPLES)
		var curr: Vector2 = _point_at(t)
		distance += prev.distance_to(curr)
		var want_ink: bool = fmod(distance, DASH_PERIOD) < DASH_INK
		if want_ink and not in_ink:
			dash_start = curr
			in_ink = true
		elif not want_ink and in_ink:
			_dash(dash_start, prev, colour, width)
			in_ink = false
		prev = curr
	if in_ink:
		_dash(dash_start, prev, colour, width)


func _draw() -> void:
	if not visible:
		return
	_draw_dashed_arc(Color(INK_COLOUR, INK_ALPHA), INK_WIDTH)
	draw_arc(_to, RETICLE_RADIUS, 0.0, TAU, 48,
		Color(INK_COLOUR, RETICLE_ALPHA), RETICLE_WIDTH, true)
