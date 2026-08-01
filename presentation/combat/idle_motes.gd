class_name IdleMotes
extends Control
## `.idle-motes` (styles.css:1625-1638) — two spores drifting off a wisp or a
## plant, and the only piece of the benchmark's per-kind idle that is not a
## transform on the body.
##
## Hung on the actor's Control rather than built into the 3D stage, because that
## is where it lives over there: a div inside `.enemy-sprite` at `z-index: 2`, in
## front of the raster, laid out in the sprite box's own coordinates
## (`src/ui/combat.js:1845-1849`). Two soft points cost a draw call each; the
## same picture inside the stage would cost a render target that is already the
## project's largest line of VRAM.
##
## Deliberately NOT seed-desynced. The sprite carries
## `animation-delay: -(seed % 2.8)s` but `animation-delay` does not inherit, so
## two wisps in the same lineup drift in lockstep over there too. Faithful, not
## an oversight — if it ever reads as mechanical, that is a design change and it
## belongs in both builds.


## `width/height: 7px`, `filter: blur(.5px)`, `box-shadow: 0 0 10px` — a bloomed
## point, not a disc, so it is drawn as a radial the way `SkyField` draws its own
## (`sky_field.gd:139`).
const DOT_PX: float = 7.0
const GLOW_PX: float = 10.0
## `inset: -8% 0 0` — the box grown UPWARD only, so a mote can leave the crown
## while the other three edges stay flush with the painting.
const OVERHANG_FRAC: float = 0.08
## `@keyframes moteDrift`, the 50% stop. 0% and 100% are rest, which is also why
## `::after`'s `reverse` direction is a no-op: a symmetric keyframe set read
## backwards is the same animation. Only its `-1.2s` delay actually separates
## the two points.
const DRIFT: Vector2 = Vector2(6.0, -18.0)
const SCALE_PEAK: float = 1.15
const ALPHA_REST: float = 0.35
const ALPHA_PEAK: float = 0.85
## `::before { left: 18%; top: 42% }` and `::after { right: 16%; top: 28% }`, as
## fractions of the grown box. CSS places the dot's EDGE, so the centre is half a
## dot further in.
const BEFORE_AT: Vector2 = Vector2(0.18, 0.42)
const BEFORE_PERIOD: float = 2.6
const AFTER_AT: Vector2 = Vector2(0.16, 0.28)
const AFTER_PERIOD: float = 3.1
const AFTER_DELAY: float = -1.2

static var _disc: GradientTexture2D = null

## `--mote: hsla(hue, 85%, 62%, .6)`, the creature's own hue.
var _tone: Color = Color(0.55, 1.0, 0.47, 0.6)
var _t: float = 0.0
## One redraw on entering the stilled state, not one per frame.
var _stilled: bool = false


func _init(hue: float) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# CSS states the colour in HSL and Godot's constructor takes HSV, so the
	# lightness has to be converted rather than passed through:
	# v = l + s·min(l, 1−l) = .62 + .85×.38 = .943, and s_v = 2(1 − l/v) = .685.
	_tone = Color(Color.from_hsv(fmod(hue, 360.0) / 360.0, 0.685, 0.943), 0.6)


func _process(delta: float) -> void:
	# `.idle-motes::before/::after { animation: none; }` (styles.css:2043):
	# both points hold at the keyframes' rest. The hold happens in _mote's
	# input, not by zeroing the clock — `_phase` bakes ::after's -1.2s delay
	# in, so a zeroed clock would still leave that mote frozen mid-drift.
	if Preferences.active.reduce_motion:
		if not _stilled:
			_stilled = true
			# CSS semantics: removing an animation and re-adding it restarts
			# it from 0% — so the clock resets on entry, and a later toggle
			# OFF resumes from rest rather than a stale mid-phase.
			_t = 0.0
			queue_redraw()
		return
	_stilled = false
	_t += delta
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if Preferences.active.reduce_motion:
		var half_rest: float = DOT_PX * 0.5
		var top_rest: float = -size.y * OVERHANG_FRAC
		var tall_rest: float = size.y * (1.0 + OVERHANG_FRAC)
		_mote(Vector2(size.x * BEFORE_AT.x + half_rest,
			top_rest + tall_rest * BEFORE_AT.y + half_rest), 0.0)
		_mote(Vector2(size.x * (1.0 - AFTER_AT.x) - half_rest,
			top_rest + tall_rest * AFTER_AT.y + half_rest), 0.0)
		return
	# The grown box, in this Control's coordinates. Nothing clips it: the overhang
	# is the whole reason the container has negative inset.
	var top: float = -size.y * OVERHANG_FRAC
	var tall: float = size.y * (1.0 + OVERHANG_FRAC)
	var half: float = DOT_PX * 0.5
	_mote(Vector2(size.x * BEFORE_AT.x + half, top + tall * BEFORE_AT.y + half),
		_phase(BEFORE_PERIOD, 0.0))
	_mote(Vector2(size.x * (1.0 - AFTER_AT.x) - half, top + tall * AFTER_AT.y + half),
		_phase(AFTER_PERIOD, AFTER_DELAY))


## A negative CSS `animation-delay` starts the iteration already that far in.
func _phase(period: float, delay: float) -> float:
	return fposmod(_t - delay, period) / period


func _mote(at: Vector2, u: float) -> void:
	var e: float = Motion.css_pulse(u, 0.0, 1.0)
	var p: Vector2 = at + DRIFT * e
	var r: float = half_dot() * lerpf(1.0, SCALE_PEAK, e)
	var a: float = _tone.a * lerpf(ALPHA_REST, ALPHA_PEAK, e)
	var tex: GradientTexture2D = _soft_disc()
	# The `box-shadow` first, then the dot over it — a 10px bloom carrying a
	# little over half the point's own alpha.
	var glow: float = r + GLOW_PX
	draw_texture_rect(tex, Rect2(p - Vector2(glow, glow), Vector2(glow, glow) * 2.0),
		false, Color(_tone, a * 0.55))
	draw_texture_rect(tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0),
		false, Color(_tone, a))


static func half_dot() -> float:
	return DOT_PX * 0.5


static func _soft_disc() -> GradientTexture2D:
	if _disc == null:
		_disc = GlassStyle.grad_tex(
			PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)]),
			PackedFloat32Array([0.0, 0.35, 1.0]), true,
			Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	return _disc
