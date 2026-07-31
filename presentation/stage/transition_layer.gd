class_name TransitionLayer
extends CanvasLayer
## The screen-to-screen ceremony the benchmark runs at z 72–75 — the wipe, the
## transit leaves and the grain — owned by `application/main.gd` and living
## ABOVE every routed screen, so a leaf started before a route swap survives
## the swap and finishes over the incoming screen. That ownership is the whole
## point: the port had victory/defeat leaves inside `CombatScreen`, and
## `_clear_route()` freed them within a frame of their first paint.
##
## Screens never see this layer. Main fires it around its route helpers, the
## way `navigation.js` wraps `show()` — the wipe on every screen change with a
## live run (`navigation.js:80` `if (S.screen !== name && S.run) wipe()`), the
## entrance on every screen root (`.screen-enter`, styles.css:141).
##
## Draw discipline: every leaf here is draw-only. The one screen-reading node
## is the grain, and it is mutually exclusive with `CombatScreen`'s own grain
## (which folds the world-stop drain into the same pass) — `set_grain(false)`
## on combat routes keeps exactly one `hint_screen_texture` visible per frame.

## `#wipe` (styles.css:1520-1531): a 102° band of lantern light on a 280%-wide
## ground, background-position 135% → −135% over 0.6s. In offset terms that is
## the band image travelling from −2.43×W to +2.43×W — off left, across, off
## right — on `wipeSweep`'s own curve.
const WIPE_TIME: float = 0.6
const WIPE_SPAN: float = 2.43
const WIPE_WIDTH: float = 2.8
## `screenIn` (styles.css:141-142): 0.45s, fade with a 1.015 settle.
const SCREEN_IN_TIME: float = 0.45
const SCREEN_IN_SCALE: float = 1.015
## `#grain` (styles.css:74-81): whole-pixel jitter jumps, eight per 0.9s —
## the same table `CombatScreen` carries, duplicated by the shared-surface
## rule rather than reached across the lane boundary.
const GRAIN_AMOUNT: float = 0.05
const GRAIN_STEP: float = 0.9 / 8.0
const GRAIN_JUMPS: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(-14.0, 7.0), Vector2(10.0, -17.0), Vector2(-7.0, 14.0),
	Vector2(17.0, 5.0), Vector2(-14.0, -10.0), Vector2(7.0, 17.0), Vector2(-10.0, -7.0)]

## The grain-only sibling of `CombatScreen.GRAIN_SHADER` — same hash, same
## overlay blend, no drain uniforms, because outside combat there is no
## world-stop to fold in.
const GRAIN_SHADER: String = """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 jitter = vec2(0.0);
uniform float amount : hint_range(0.0, 1.0) = 0.05;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;
	vec3 g = vec3(hash(floor(FRAGCOORD.xy) + jitter));
	vec3 over = mix(2.0 * base * g,
		1.0 - 2.0 * (1.0 - base) * (1.0 - g), step(vec3(0.5), base));
	COLOR = vec4(mix(base, over, amount), 1.0);
}
"""

## Captures and headless drives must never wait on a tween: every ceremony
## method returns immediately when set. Main sets it from `--shot=`.
var instant: bool = false

var _wipe: TextureRect
var _grain: ColorRect
var _grain_mat: ShaderMaterial
var _grain_t: float = 0.0
var _wipe_tween: Tween = null


func _init() -> void:
	layer = 10
	_wipe = TextureRect.new()
	_wipe.texture = _band_texture()
	_wipe.stretch_mode = TextureRect.STRETCH_SCALE
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe.visible = false
	add_child(_wipe)
	var sh: Shader = Shader.new()
	sh.code = GRAIN_SHADER
	_grain_mat = ShaderMaterial.new()
	_grain_mat.shader = sh
	_grain_mat.set_shader_parameter("amount", GRAIN_AMOUNT)
	_grain = ColorRect.new()
	_grain.material = _grain_mat
	_grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grain.visible = false
	add_child(_grain)


func _process(delta: float) -> void:
	if not _grain.visible:
		return
	_grain_t += delta
	var step: int = int(_grain_t / GRAIN_STEP) % GRAIN_JUMPS.size()
	_grain_mat.set_shader_parameter("jitter", GRAIN_JUMPS[step])


## The band-of-light sweep. Fire-and-forget: main calls it BEFORE the route
## swap and the band crosses whatever arrives underneath, exactly as the
## fixed-position `#wipe` does.
func wipe() -> void:
	if instant:
		return
	var stage: Vector2 = _stage_size()
	if stage.x <= 0.0:
		return
	_wipe.size = Vector2(stage.x * WIPE_WIDTH, stage.y)
	_wipe.position.y = 0.0
	_wipe.visible = true
	if _wipe_tween != null:
		_wipe_tween.kill()
	_wipe_tween = Motion.bez(self, _place_wipe.bind(stage.x), WIPE_TIME, Motion.WIPE)
	_wipe_tween.finished.connect(_hide_wipe, CONNECT_ONE_SHOT)


func _place_wipe(eased: float, stage_w: float) -> void:
	_wipe.position.x = lerpf(-WIPE_SPAN * stage_w, WIPE_SPAN * stage_w, eased)


func _hide_wipe() -> void:
	_wipe.visible = false


## Every screen root's entrance: fade in with a 1.015 → 1 settle about the
## centre. The pivot needs a laid-out size, so the scale half waits one frame
## and is skipped when the root has none to offer.
func screen_in(root: Control) -> void:
	if instant or root == null:
		return
	root.modulate.a = 0.0
	var tree: SceneTree = get_tree()
	if tree == null:
		root.modulate.a = 1.0
		return
	await tree.process_frame
	if not is_instance_valid(root):
		return
	var sized: bool = root.size.x > 0.0 and root.size.y > 0.0
	if sized:
		root.pivot_offset = root.size * 0.5
		root.scale = Vector2.ONE * SCREEN_IN_SCALE
	# The tween is bound to the root, so a mid-entrance route swap kills it
	# with the screen instead of writing into freed memory.
	var entrance: Callable = func(eased: float) -> void:
		if not is_instance_valid(root):
			return
		root.modulate.a = eased
		if sized:
			root.scale = Vector2.ONE * lerpf(SCREEN_IN_SCALE, 1.0, eased)
	Motion.bez(root, entrance, SCREEN_IN_TIME, Motion.SCREEN_IN)


func set_grain(on: bool) -> void:
	_grain.visible = on


## Route reset: kill anything mid-flight. Main calls this when a route change
## must NOT carry ceremony across (save errors, hard resets).
func clear() -> void:
	if _wipe_tween != null:
		_wipe_tween.kill()
		_wipe_tween = null
	_wipe.visible = false


func _stage_size() -> Vector2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return Vector2.ZERO
	return vp.get_visible_rect().size


## The 102° lantern-light band, stops verbatim from `#wipe`'s gradient.
func _band_texture() -> GradientTexture2D:
	var dir: Vector2 = Vector2(sin(deg_to_rad(102.0)), -cos(deg_to_rad(102.0)))
	var centre: Vector2 = Vector2(0.5, 0.5)
	return GlassStyle.grad_tex(
		PackedColorArray([
			Color(0.949, 0.757, 0.306, 0.0),
			Color(0.949, 0.757, 0.306, 0.0),
			Color(0.949, 0.757, 0.306, 0.10),
			Color(1.0, 0.953, 0.839, 0.22),
			Color(0.949, 0.757, 0.306, 0.10),
			Color(0.949, 0.757, 0.306, 0.0),
			Color(0.949, 0.757, 0.306, 0.0),
		]),
		PackedFloat32Array([0.0, 0.36, 0.45, 0.5, 0.55, 0.64, 1.0]),
		false, centre - dir * 0.5, centre + dir * 0.5)
