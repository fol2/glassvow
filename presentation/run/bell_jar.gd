class_name BellJar
extends Control
## The cold glass on the night stall's right-hand ledge, over the quest offer.
## Concept C1's `.jar` (`docs/design/2026-08-14-ui-direction/shop-c1.html`) —
## drawn, not shipped as art, because it is the one cold light in a warm room
## and the tint has to answer to `GlassStyle.GLASS` rather than to a PNG.
##
## Seated on the `jar` region's upper half by `ShopScreen`, over the offer's own
## button: the glass is in FRONT of what it covers, which is the whole point of
## a bell jar, so this node is added after the ware and ignores the mouse.

## 106x128 in the mock: a semicircle dome over straight sides.
const ASPECT: float = 0.83

static var _pool: GradientTexture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var h: float = size.y
	var w: float = minf(size.x, h * ASPECT)
	if w <= 2.0 or h <= 2.0:
		return
	var left: float = (size.x - w) * 0.5
	var radius: float = w * 0.5
	var cx: float = left + radius
	# The ledge's pool of cold light, and the ellipse the glass rests in.
	draw_texture_rect(_pool_tex(),
		Rect2(cx - w, -h * 0.14, w * 2.0, h * 1.38), false)
	draw_texture_rect(_pool_tex(),
		Rect2(cx - w * 0.64, h - w * 0.11, w * 1.28, w * 0.2), false,
		Color(1.0, 1.0, 1.0, 1.4))
	var shell: PackedVector2Array = PackedVector2Array()
	for step: int in range(21):
		var angle: float = PI + PI * float(step) / 20.0
		shell.append(Vector2(cx, radius)
			+ Vector2(cos(angle), sin(angle)) * radius)
	shell.append(Vector2(left + w, h))
	shell.append(Vector2(left, h))
	draw_colored_polygon(shell, Color(GlassStyle.GLASS, 0.10))
	shell.append(shell[0])
	draw_polyline(shell, Color(GlassStyle.GLASS, 0.46), maxf(1.0, w * 0.012))
	# The knob, half sunk into the apex, and the highlight down the shoulder.
	draw_circle(Vector2(cx, -w * 0.015), w * 0.075, Color(GlassStyle.GLASS, 0.34))
	draw_line(Vector2(left + w * 0.19, radius * 0.62),
		Vector2(left + w * 0.14, h * 0.60),
		Color(0.84, 0.94, 1.0, 0.17), maxf(1.0, w * 0.035))


static func _pool_tex() -> GradientTexture2D:
	if _pool == null:
		_pool = GlassStyle.disc(GlassStyle.GLASS, 0.30, 96)
	return _pool
