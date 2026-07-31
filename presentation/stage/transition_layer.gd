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
## `combat-in` (navigation.js:44-49): the dark disc collapses into the click
## point over 480ms — cover is immediate, the reveal is the animation. CSS
## `circle(150%)` resolves past any corner from any centre; 1.5× the stage
## diagonal does the same here.
const IRIS_TIME: float = 0.48
const IRIS_SPAN: float = 1.5
## `tr-bloom` — `radial-gradient(circle at 50% 45%, #ffe9ac 0%, #f2c14e55 30%,
## transparent 70%)` over 900ms, `[0, 1 @ 0.4, 0]`. The last stop is the SAME
## amber at zero alpha rather than `transparent`: a browser interpolates
## gradient stops premultiplied, so `transparent` there does not drag the ramp
## toward black, and Godot's `Gradient` — which interpolates raw RGBA — would.
## Fired by main on a combat win (`victoryFlow`, combat.js), and living HERE so
## the 900ms leaf survives the route swap to the reward screen.
const BLOOM_TIME: float = 0.9
const BLOOM_CORE: Color = Color(1.0, 0.9137255, 0.6745098, 1.0)      # #ffe9ac
const BLOOM_MID: Color = Color(0.9490196, 0.75686276, 0.30588236, 0.33333334)
const BLOOM_STOPS: Array[float] = [0.0, 0.3, 0.7]
const BLOOM_AT: Array[float] = [0.0, 0.4, 1.0]
const BLOOM_TRACK: Array[float] = [0.0, 1.0, 0.0]
## The gradient's default extent is farthest-corner from (50%, 45%).
const BLOOM_CENTRE: Vector2 = Vector2(0.5, 0.45)
## `tr-crack` — `rgba(3,4,10,.9)` over 700ms, `[0, 1]`, then the host empties:
## the benchmark's `.finally` does not linger, the screen routed underneath
## takes over the dark.
const CRACK_TIME: float = 0.7
const CRACK_TONE: Color = Color(0.011764706, 0.015686275, 0.039215688, 0.9)
const CRACK_AT: Array[float] = [0.0, 1.0]
const CRACK_TRACK: Array[float] = [0.0, 1.0]

## The `.tr-iris` ink (`#05070e`, styles.css:1533), drawn as an annulus by
## shader rather than by clip: dark inside the radius, nothing outside.
const IRIS_SHADER: String = """
shader_type canvas_item;

uniform vec2 centre = vec2(0.0, 0.0);
uniform float radius = 0.0;
uniform vec2 rect_size = vec2(1.0, 1.0);
uniform vec4 ink : source_color = vec4(0.0196, 0.0275, 0.0549, 1.0);

void fragment() {
	float d = distance(UV * rect_size, centre);
	COLOR = vec4(ink.rgb, ink.a * (1.0 - smoothstep(radius - 0.75, radius + 0.75, d)));
}
"""
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
var _iris: ColorRect
var _iris_mat: ShaderMaterial
var _bloom: TextureRect
var _crack: ColorRect
var _grain: ColorRect
var _grain_mat: ShaderMaterial
var _grain_t: float = 0.0
var _wipe_tween: Tween = null
## The transit-slot guard, `navigation.js`'s `transitionSeq`: a later leaf
## takes the slot and an earlier one's finish must not hide it.
var _transit_seq: int = 0


func _init() -> void:
	layer = 10
	_wipe = TextureRect.new()
	_wipe.texture = _band_texture()
	_wipe.stretch_mode = TextureRect.STRETCH_SCALE
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe.visible = false
	add_child(_wipe)
	var iris_sh: Shader = Shader.new()
	iris_sh.code = IRIS_SHADER
	_iris_mat = ShaderMaterial.new()
	_iris_mat.shader = iris_sh
	_iris = ColorRect.new()
	_iris.material = _iris_mat
	_iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_iris.set_anchors_preset(Control.PRESET_FULL_RECT)
	_iris.visible = false
	add_child(_iris)
	# The bloom is a TextureRect because a radial ramp IS a texture in Godot
	# and a shader would buy nothing; the crack is a flat plate.
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array(BLOOM_STOPS)
	grad.colors = PackedColorArray([BLOOM_CORE, BLOOM_MID,
		Color(BLOOM_MID.r, BLOOM_MID.g, BLOOM_MID.b, 0.0)])
	var bloom_tex: GradientTexture2D = GradientTexture2D.new()
	bloom_tex.gradient = grad
	bloom_tex.fill = GradientTexture2D.FILL_RADIAL
	bloom_tex.fill_from = BLOOM_CENTRE
	# Farthest-corner, expressed in the texture's own UV so it re-solves
	# against whatever the window is rather than the stage it was measured in.
	bloom_tex.fill_to = BLOOM_CENTRE + Vector2(0.5, 0.55)
	bloom_tex.width = 256
	bloom_tex.height = 256
	_bloom = TextureRect.new()
	_bloom.texture = bloom_tex
	_bloom.stretch_mode = TextureRect.STRETCH_SCALE
	_bloom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bloom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloom.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bloom.visible = false
	add_child(_bloom)
	_crack = ColorRect.new()
	_crack.color = CRACK_TONE
	_crack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crack.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crack.visible = false
	add_child(_crack)
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


## The combat entry: dark covers the screen the moment this is called, then
## collapses into `at` (stage px) while the fight builds underneath — the
## route swap's frame hitch happens under the cover, which is the point.
func iris(at: Vector2) -> void:
	if instant:
		return
	var stage: Vector2 = _stage_size()
	if stage.x <= 0.0:
		return
	_transit_seq += 1
	_iris_mat.set_shader_parameter("rect_size", stage)
	_iris_mat.set_shader_parameter("centre", at)
	var full: float = stage.length() * IRIS_SPAN
	_iris_mat.set_shader_parameter("radius", full)
	_iris.visible = true
	var tw: Tween = Motion.bez(self, _shrink_iris.bind(full), IRIS_TIME, Motion.TRANSIT)
	tw.finished.connect(_end_transit.bind(_transit_seq), CONNECT_ONE_SHOT)


func _shrink_iris(eased: float, full: float) -> void:
	_iris_mat.set_shader_parameter("radius", full * (1.0 - eased))


## The win leaf: amber light swells and fades over whatever the route swap
## delivers underneath (`victory-out`, navigation.js:52). WAAPI semantics —
## the ease runs once across the iteration, offsets interpolate linearly.
func bloom() -> void:
	_play_leaf(_bloom, BLOOM_AT, BLOOM_TRACK, BLOOM_TIME)


## The defeat leaf: the world fades to near-black over 700ms, then the host
## empties and the screen behind takes over (`defeat`, navigation.js:53).
func crack() -> void:
	_play_leaf(_crack, CRACK_AT, CRACK_TRACK, CRACK_TIME)


func _play_leaf(leaf: Control, at: Array[float], track: Array[float],
		seconds: float) -> void:
	if instant:
		return
	_transit_seq += 1
	_iris.visible = false
	_bloom.visible = leaf == _bloom
	_crack.visible = leaf == _crack
	leaf.modulate.a = 0.0
	var walk: Callable = func(x: float) -> void:
		leaf.modulate.a = Motion.keyframe(Motion.ease(Motion.TRANSIT, x), at, track)
	var tw: Tween = create_tween()
	tw.tween_method(walk, 0.0, 1.0, seconds)
	tw.finished.connect(_end_transit.bind(_transit_seq), CONNECT_ONE_SHOT)


func _end_transit(seq: int) -> void:
	if seq != _transit_seq:
		return
	_iris.visible = false
	_bloom.visible = false
	_crack.visible = false


func set_grain(on: bool) -> void:
	_grain.visible = on


## Route reset: kill anything mid-flight. Main calls this when a route change
## must NOT carry ceremony across (save errors, hard resets).
func clear() -> void:
	if _wipe_tween != null:
		_wipe_tween.kill()
		_wipe_tween = null
	_wipe.visible = false
	_transit_seq += 1
	_iris.visible = false
	_bloom.visible = false
	_crack.visible = false


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
