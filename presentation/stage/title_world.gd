class_name TitleWorld
extends Control
## The title-camera slice of benchmark `scene3d.js`: near shards, forest floor
## and two point fields. The map owns the climbable tower; this layer keeps only
## what the fixed ambient title camera exposes.

const SKY: Color = Color("#0b0e1a")
const GROUND: Color = Color("#07110d")
const SHARD: Color = Color("#04090a")
const TREE: Color = Color("#0a1a12")
const MAIN: Color = Color("#ffa04d")
const ACCENT: Color = Color("#66ff9e")
const MAIN_COUNT: int = 115
const ACCENT_COUNT: int = 36

var _main: Array[Vector4] = []
var _accent: Array[Vector4] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time: float = 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 0x51CE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and size.x > 0.0:
		_seed()


func _seed() -> void:
	_main.clear()
	_accent.clear()
	for _i: int in range(MAIN_COUNT):
		_main.append(_mote(0.55, 1.8))
	for _i: int in range(ACCENT_COUNT):
		_accent.append(_mote(0.8, 2.8))


func _mote(lo: float, hi: float) -> Vector4:
	return Vector4(
		_rng.randf_range(0.0, size.x),
		_rng.randf_range(0.0, size.y),
		_rng.randf_range(lo, hi),
		_rng.randf_range(0.0, TAU))


func _process(delta: float) -> void:
	if _main.is_empty() and size.x > 0.0:
		_seed()
	var dt: float = minf(0.05, delta)
	_time += dt
	_drift(_main, dt, 1.0)
	_drift(_accent, dt, 0.55)
	queue_redraw()


func _drift(motes: Array[Vector4], dt: float, rate: float) -> void:
	for i: int in motes.size():
		var mote: Vector4 = motes[i]
		mote.y -= dt * rate * (9.0 + fmod(mote.w, 1.0) * 12.0)
		mote.x += sin(_time * 0.5 + mote.w) * dt * 2.4
		if mote.y < -8.0:
			mote.y = size.y + 8.0
			mote.x = _rng.randf_range(0.0, size.x)
		motes[i] = mote


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(Vector2.ZERO, size), SKY)
	# Four close, clipped cones from `fgGroup`; they frame rather than read as
	# architecture, which is why their bases disappear into the forest.
	_poly([Vector2(-0.10, -0.05), Vector2(0.25, -0.05),
		Vector2(0.29, 0.52), Vector2(0.20, 0.58), Vector2(-0.03, 0.54)], w, h, SHARD)
	_poly([Vector2(0.27, -0.05), Vector2(0.55, -0.05),
		Vector2(0.56, 0.53), Vector2(0.48, 0.59), Vector2(0.34, 0.54)], w, h, SHARD)
	_poly([Vector2(0.54, -0.05), Vector2(0.77, -0.05),
		Vector2(0.76, 0.54), Vector2(0.68, 0.60), Vector2(0.57, 0.53)], w, h, SHARD)
	_poly([Vector2(0.76, -0.05), Vector2(1.10, -0.05),
		Vector2(1.05, 0.55), Vector2(0.86, 0.59), Vector2(0.78, 0.52)], w, h, SHARD)

	draw_rect(Rect2(0.0, h * 0.53, w, h * 0.47), GROUND)
	for i: int in range(25):
		var x: float = (float(i) - 0.4) * w / 23.5
		var tree_h: float = h * (0.075 + 0.055 * (0.5 + 0.5 * sin(float(i) * 2.17)))
		var base_y: float = h * (0.57 + 0.025 * sin(float(i) * 1.31))
		var half_w: float = tree_h * (0.20 + 0.05 * sin(float(i)))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, base_y - tree_h),
			Vector2(x + half_w, base_y),
			Vector2(x - half_w, base_y),
		]), TREE)
	_stamp(_main, MAIN, 0.58)
	_stamp(_accent, ACCENT, 0.50 + sin(_time * 0.9) * 0.12)


func _poly(points: Array[Vector2], w: float, h: float, colour: Color) -> void:
	var scaled: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		scaled.append(Vector2(point.x * w, point.y * h))
	draw_colored_polygon(scaled, colour)


func _stamp(motes: Array[Vector4], tint: Color, alpha: float) -> void:
	var colour: Color = Color(tint, alpha)
	var texture: Texture2D = SkyField.disc()
	for mote: Vector4 in motes:
		var radius: float = mote.z
		draw_texture_rect(texture, Rect2(
			Vector2(mote.x, mote.y) - Vector2.ONE * radius * 2.0,
			Vector2.ONE * radius * 4.0), false, colour)
