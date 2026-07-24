class_name GlassGem
extends Control
## The enemy avatar as living stained glass: a faceted gem in the enemy's hue
## that dims and cracks as HP falls and goes to a dark husk on death. Pure
## _draw (no art), so it costs nothing but a redraw. Never reads combat state
## — the view pushes state in through set_state (sequencer contract).

var _hue: float = 210.0
var _frac: float = 1.0
var _dead: bool = false


func set_state(hue: float, hp_frac: float, dead: bool) -> void:
	_hue = hue
	_frac = clampf(hp_frac, 0.0, 1.0)
	_dead = dead
	queue_redraw()


func _draw() -> void:
	var cx: float = size.x * 0.5
	var cy: float = size.y * 0.5
	var rx: float = size.x * 0.40
	var ry: float = size.y * 0.46
	var lit: float = 0.35 + 0.65 * _frac
	var body: Color = Color.from_hsv(fmod(_hue, 360.0) / 360.0, 0.5, 0.55 + 0.35 * _frac)
	var rim: Color = GlassStyle.GLASS
	if _dead:
		body = Color(0.24, 0.26, 0.32)
		rim = Color(0.40, 0.42, 0.50)
		lit = 0.5
	# Cut-gem silhouette: pointed top and bottom, shouldered mid.
	var centre: Vector2 = Vector2(cx, cy - ry * 0.06)
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(cx, cy - ry),                     # crown point
		Vector2(cx + rx, cy - ry * 0.28),         # right shoulder
		Vector2(cx + rx * 0.52, cy + ry * 0.58),  # lower right
		Vector2(cx, cy + ry),                     # cutlet point
		Vector2(cx - rx * 0.52, cy + ry * 0.58),  # lower left
		Vector2(cx - rx, cy - ry * 0.28),         # left shoulder
	])
	# Soft outer glow: same silhouette scaled up, very low alpha.
	if not _dead:
		var glow: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			glow.append(centre + (p - centre) * 1.20)
		draw_colored_polygon(glow, Color(rim.r, rim.g, rim.b, 0.07 * lit))
	# Translucent body, brighter crown table, then facet spokes from centre.
	draw_colored_polygon(pts, Color(body.r, body.g, body.b, 0.42 * lit + 0.12))
	var table: PackedVector2Array = PackedVector2Array([
		pts[0], pts[1], centre, pts[5],
	])
	draw_colored_polygon(table, Color(body.r, body.g, body.b, 0.30 * lit))
	for p: Vector2 in pts:
		draw_line(centre, p, Color(rim.r, rim.g, rim.b, 0.35 * lit), 1.0)
	# Rim outline (closed).
	var outline: PackedVector2Array = pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(rim.r, rim.g, rim.b, 0.85 * lit), 1.8)
	# Glass gleam: a bright sliver down one crown facet.
	var gleam: PackedVector2Array = PackedVector2Array([
		Vector2(cx, cy - ry),
		Vector2(cx + rx * 0.30, cy - ry * 0.28),
		centre,
		Vector2(cx + rx * 0.06, cy - ry * 0.30),
	])
	draw_colored_polygon(gleam, Color(1.0, 1.0, 1.0, 0.12 * lit))
	# Ember cracks bleed through as the gem weakens.
	if _frac < 0.6 and not _dead:
		var crack: float = (0.6 - _frac) / 0.6
		draw_line(Vector2(cx - rx * 0.3, cy - ry * 0.3), Vector2(cx + rx * 0.1, cy + ry * 0.5),
			Color(GlassStyle.EMBER.r, GlassStyle.EMBER.g, GlassStyle.EMBER.b, 0.55 * crack), 1.4)
		draw_line(Vector2(cx + rx * 0.2, cy - ry * 0.4), Vector2(cx - rx * 0.15, cy + ry * 0.4),
			Color(GlassStyle.EMBER.r, GlassStyle.EMBER.g, GlassStyle.EMBER.b, 0.40 * crack), 1.2)
