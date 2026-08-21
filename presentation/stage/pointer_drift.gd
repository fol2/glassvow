class_name PointerDrift
extends RefCounted
## The ambient pointer response every world layer shares.
##
## The benchmark's whole scene answers the pointer: `scene3d.js:280-284` keeps
## a smoothed `mouse` in −1..1 and the camera reads it every frame (`:417` the
## ambient eye, `:412-413` the map orbit). Losing that is most of what makes a
## still port read as flat. One instance per consuming surface — no singleton;
## the consumer owns it and applies its own amplitudes.
##
## `camera.position.lerp(_posT, min(1, dt * 2.2))` — the chase rate is the
## benchmark's own, and it is the whole feel: the world leans after the hand,
## never with it.

const CHASE: float = 2.2

## Smoothed pointer, each axis in −1..1. Zero is the resting centre.
var n: Vector2 = Vector2.ZERO


## Chase the pointer. When the pointer is outside the stage (or there is no
## viewport — headless), the target is centre, so the world settles home and
## a capture with the cursor elsewhere photographs the resting composition.
func step(host: Control, delta: float) -> void:
	var vp: Viewport = host.get_viewport()
	if vp == null:
		return
	var rect: Rect2 = vp.get_visible_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var target: Vector2 = target_for(
		rect,
		DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE),
		Callable(host, "get_global_mouse_position"),
	)
	n = n.lerp(target, minf(1.0, delta * CHASE))


## Pure capability seam for touch-only platforms and headless regression tests.
static func target_for(rect: Rect2, has_mouse: bool, sample_mouse: Callable) -> Vector2:
	# iOS is touch-only and its DisplayServer reports an engine error if the
	# sampler reaches mouse_get_position(). Return before invoking it.
	if not has_mouse:
		return Vector2.ZERO
	var p: Vector2 = sample_mouse.call()
	if not rect.has_point(p):
		return Vector2.ZERO
	return ((p / rect.size) * 2.0 - Vector2.ONE).clamp(-Vector2.ONE, Vector2.ONE)
