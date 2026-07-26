class_name AimArc
extends Control
## The targeting arc: a dashed red bow that springs from a seated card up over
## the battlefield to the pointer, with a ringed crosshair at the far end.
##
## Ported verbatim from the benchmark's `paintAim` (`src/ui/combat-gl.js:1254`).
## Every number below is that function's, not a fitted approximation:
##
##   P0 = the card's SEAT centre lifted 80px   (`from.y - 80`)
##   C  = ((from.x + to.x) / 2, min(from.y, to.y) - 120)
##   P1 = the pointer
##
## sampled into ten round-capped dashes at 62% ink per cell, stroked twice —
## a wide soft glow beneath crisp ink.
##
## The arc is only ever drawn for a card that targets an enemy. That is not a
## style choice: `beginCardDrag` (`combat.js:1547`) sets targeting for
## `target === 'enemy'` and marks every other card `free`, and the two branches
## look completely different. A free card follows your finger; an aimed card
## STAYS IN ITS SEAT and throws this arc instead. Dragging the card itself in
## both cases — which is what this port did until now — loses the distinction
## the benchmark's whole targeting read is built on.

## Ten cells, 62% of each filled. `INK` below 1.0 is what makes it a dashed
## reticle line rather than a solid rope.
const DASHES: int = 10
const INK: float = 0.62
## How far above the card centre the arc launches, and how far above the higher
## of the two endpoints the apex floats.
const LAUNCH_LIFT: float = 80.0
const APEX_LIFT: float = 120.0

const GLOW_COLOUR: Color = Color(1.0, 0.34901962, 0.39215687)  # #ff5964
const INK_COLOUR: Color = Color(1.0, 0.5411765, 0.57254905)  # #ff8a92
const GLOW_WIDTH: float = 9.0
const GLOW_ALPHA: float = 0.16
const INK_WIDTH: float = 4.0
const INK_ALPHA: float = 0.92

const RETICLE_RADIUS: float = 11.0
const RETICLE_WIDTH: float = 2.5
const RETICLE_ALPHA: float = 0.95
const CORE_RADIUS: float = 3.0
const CORE_ALPHA: float = 0.9

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


## Quadratic Bezier at `t`, with the control point implied by the endpoints the
## same way `paintAim` implies it.
func _point_at(t: float) -> Vector2:
	var p0: Vector2 = Vector2(_from.x, _from.y - LAUNCH_LIFT)
	var c: Vector2 = Vector2((_from.x + _to.x) * 0.5, minf(_from.y, _to.y) - APEX_LIFT)
	var u: float = 1.0 - t
	return u * u * p0 + 2.0 * u * t * c + t * t * _to


## One dash with round caps. Godot's `draw_line` has no cap mode, so the body is
## drawn short by one radius at each end and the caps are discs sitting exactly
## tangent to it — overlapping them instead would double-blend, and at the glow
## pass's 0.16 alpha that reads as a string of beads rather than a soft line.
func _dash(a: Vector2, b: Vector2, colour: Color, width: float) -> void:
	var radius: float = width * 0.5
	var span: Vector2 = b - a
	var length: float = span.length()
	if length > width:
		var step: Vector2 = span / length * radius
		draw_line(a + step, b - step, colour, width, true)
	draw_circle(a, radius, colour)
	draw_circle(b, radius, colour)


func _draw() -> void:
	if not visible:
		return
	var glow: Color = Color(GLOW_COLOUR, GLOW_ALPHA)
	var ink: Color = Color(INK_COLOUR, INK_ALPHA)
	for pass_index: int in range(2):
		var colour: Color = glow if pass_index == 0 else ink
		var width: float = GLOW_WIDTH if pass_index == 0 else INK_WIDTH
		for i: int in range(DASHES):
			_dash(_point_at(float(i) / float(DASHES)),
				_point_at((float(i) + INK) / float(DASHES)), colour, width)
	draw_arc(_to, RETICLE_RADIUS, 0.0, TAU, 48,
		Color(GLOW_COLOUR, RETICLE_ALPHA), RETICLE_WIDTH, true)
	draw_circle(_to, CORE_RADIUS, Color(INK_COLOUR, CORE_ALPHA))
