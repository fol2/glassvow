class_name FacetPips
extends Control
## The facet gauge as segmented glass diamonds instead of "chips / max" text:
## `filled` lit pips (chips accrued toward a shatter), the rest hollow. Pure
## _draw; the view pushes counts in through set_pips.

const GAP: float = 16.0
const R: float = 5.0

var _filled: int = 0
var _total: int = 0


func set_pips(filled: int, total: int) -> void:
	_filled = filled
	_total = total
	custom_minimum_size = Vector2(float(maxi(total, 1)) * GAP, 14.0)
	queue_redraw()


func _draw() -> void:
	if _total <= 0:
		return
	var span: float = float(_total) * GAP
	var start_x: float = (size.x - span) * 0.5 + GAP * 0.5
	var cy: float = size.y * 0.5
	for i: int in range(_total):
		var cx: float = start_x + float(i) * GAP
		var d: PackedVector2Array = PackedVector2Array([
			Vector2(cx, cy - R), Vector2(cx + R, cy), Vector2(cx, cy + R), Vector2(cx - R, cy),
		])
		var lit: bool = i < _filled
		var fill: Color = GlassStyle.GLASS if lit else Color(GlassStyle.GLASS.r, GlassStyle.GLASS.g, GlassStyle.GLASS.b, 0.12)
		draw_colored_polygon(d, fill)
		var outline: PackedVector2Array = d.duplicate()
		outline.append(d[0])
		draw_polyline(outline, Color(GlassStyle.GLASS.r, GlassStyle.GLASS.g, GlassStyle.GLASS.b, 0.55), 1.0)
