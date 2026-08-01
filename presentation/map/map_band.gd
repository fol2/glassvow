class_name MapBand
extends Control
## One parallax strip of the pilgrimage map. Host owns camera + PointerDrift;
## bands store the amplitude-scaled slice and redraw when it moves enough.
## Child order IS paint order (sky → region → path → waystones → veil), so the
## Spire wedge sits behind the region trees by construction.

const CAM_EPS: float = 0.05
const DRIFT_EPS: float = 0.1

var factor: float = 1.0
var cam_x: float = 0.0
var drift: Vector2 = Vector2.ZERO  # px; host already scaled the amplitude
## False on the veil: ash animates every frame, so the cam/drift gate would
## freeze weather the moment the camera rests.
var gated: bool = true
var host: WorldMapScreen = null


func _init(p_factor: float = 1.0) -> void:
	factor = p_factor
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_view(p_cam_x: float, p_drift: Vector2, force: bool = false) -> void:
	var moved: bool = force \
		or absf(p_cam_x - cam_x) > CAM_EPS \
		or p_drift.distance_to(drift) > DRIFT_EPS
	# Store only what gets PAINTED. The waystones relayout ungated every
	# frame, so a gate that re-baselines on every push lets sub-epsilon
	# deltas accumulate into a permanent stone/road detach on a slow sweep —
	# the comparison must always be against the last painted view.
	if not gated or moved:
		cam_x = p_cam_x
		drift = p_drift
		queue_redraw()


class SkyBand extends MapBand:
	func _init() -> void:
		super(0.10)

	func _draw() -> void:
		if host == null:
			return
		var w: float = size.x
		var h: float = size.y
		# Night gradient lives on this band — siblings BELOW the waystones, not
		# a TextureRect that would sit above the screen's old single _draw pass.
		draw_texture_rect(host._sky_tex, Rect2(Vector2.ZERO, size), false)
		draw_texture_rect(SkyField.disc(),
			Rect2(-w * 0.10 + drift.x, h * 0.22 + drift.y, w * 1.20, h * 0.60),
			false, Color(host._fog_colour.lightened(0.42), 0.28))
		# Distant goal-anchor at the skyband factor (§5 band 1, 0.10). A band
		# that slow needs a SCREEN anchor, not a world one: at 0.10 the whole
		# journey drifts it only a tenth of the act, so anchoring at
		# `world_x(ROWS)` would park it off-stage for every step of the walk.
		# It starts high in the frame's right and eases toward the lead as you
		# close. The band's factor supplies the cam term; drift is far amplitude.
		var horizon: float = h * host._trail_num("horizonY", 0.36)
		var centre: float = w * 0.82 - cam_x * factor + drift.x
		var top_w: float = maxf(58.0, w * 0.08)
		var bottom_w: float = maxf(180.0, w * 0.28)
		# Top bleeds past the frame by more than the far drift amplitude —
		# a downward lean must not open raw sky above the wedge.
		draw_colored_polygon(PackedVector2Array([
			Vector2(centre - top_w, drift.y - 8.0),
			Vector2(centre + top_w, drift.y - 8.0),
			Vector2(centre + bottom_w, horizon + drift.y),
			Vector2(centre - bottom_w, horizon + drift.y),
		]), host._sky_colour.darkened(0.58))


class RegionBand extends MapBand:
	func _init() -> void:
		super(0.35)

	func _draw() -> void:
		if host == null:
			return
		var w: float = size.x
		var h: float = size.y
		var horizon: float = h * host._trail_num("horizonY", 0.36) + drift.y
		# Bleeds past the frame bottom by more than the far drift amplitude —
		# an upward lean must not leave a strip of raw sky under the ground.
		draw_rect(Rect2(0.0, horizon, w, h - horizon + 8.0),
			Color(WorldMapScreen.REGION_GROUND, 0.62 if host._act == 0 else 0.38))
		if host._act > 0:
			for cloud: int in range(9):
				var cloud_w: float = w * (0.18 + float(cloud % 3) * 0.035)
				var cloud_h: float = 54.0 + float(cloud % 4) * 13.0
				var x: float = fposmod(float(cloud) * w * 0.17 - cam_x * factor,
					w + cloud_w) - cloud_w + drift.x
				draw_texture_rect(SkyField.disc(),
					Rect2(x, horizon - cloud_h * 0.68, cloud_w, cloud_h), false,
					Color(host._fog_colour.lightened(0.50), 0.15))
			return
		var span: float = w + 400.0
		var trunk: Color = Color(0.025, 0.065, 0.048, 0.94)
		var rim: Color = Color(host._accent_colour, 0.08)
		for tree: int in range(20):
			var index: float = float(tree)
			var x: float = fposmod(index * 163.0 - cam_x * factor, span) \
				- 200.0 + drift.x
			var tree_h: float = 90.0 + fmod(index * 53.0, 90.0)
			var base_y: float = horizon + 26.0 + fmod(index * 29.0, 30.0)
			var top_y: float = base_y - tree_h
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - 8.0, base_y), Vector2(x - 2.5, top_y),
				Vector2(x + 2.5, top_y), Vector2(x + 8.0, base_y),
			]), trunk)
			draw_line(Vector2(x, top_y + tree_h * 0.30),
				Vector2(x - 28.0, top_y + tree_h * 0.06), trunk, 4.0)
			draw_line(Vector2(x, top_y + tree_h * 0.46),
				Vector2(x + 32.0, top_y + tree_h * 0.14), trunk, 4.0)
			draw_line(Vector2(x - 2.5, top_y),
				Vector2(x - 5.0, top_y + tree_h * 0.45), rim, 1.0)


class PathBand extends MapBand:
	func _init() -> void:
		super(1.0)

	func _draw() -> void:
		if host == null:
			return
		var w: float = size.x
		# §5 band-3 stand-in: leaded path ribbon along pathY until a real path
		# plane owns taper. Seeds left-to-right reading without claiming the road.
		var path_y: float = size.y * host._trail_num("pathY", 0.64) + drift.y
		var glass: Color = GlassStyle.GLASS
		draw_line(Vector2(0.0, path_y), Vector2(w, path_y),
			Color(glass.r, glass.g, glass.b, 0.10), 3.0)
		draw_line(Vector2(0.0, path_y), Vector2(w, path_y),
			Color(glass.r, glass.g, glass.b, 0.16), 1.0)
		_draw_graph()
		# The current lantern's glow sits behind its waystone (or mid-glide
		# along the same bezier the edges draw — host owns travel state).
		if host.map.at >= 0 and host.map.at < host.map.nodes.size():
			var at: Vector2 = host.marker_screen_position()
			var ember: Color = GlassStyle.EMBER
			draw_circle(at, 30.0, Color(ember.r, ember.g, ember.b, 0.10))
			draw_circle(at, 15.0, Color(ember.r, ember.g, ember.b, 0.18))

	func _draw_graph() -> void:
		var by_id: Dictionary = {}
		var step: float = host._step()
		for node: MapNode in host.map.nodes:
			by_id[node.id] = node
		for node: MapNode in host.map.nodes:
			var from: Vector2 = host._node_pos(node)
			for next_id: String in node.next:
				var next_v: Variant = by_id.get(next_id)
				if typeof(next_v) != TYPE_OBJECT:
					continue
				var next_node: MapNode = next_v
				var to: Vector2 = host._node_pos(next_node)
				var walked: bool = host.map.is_cleared(host.map.nodes.find(node)) \
					and host.map.is_cleared(host.map.nodes.find(next_node))
				var fade: float = clampf(1.0 - maxf(
					absf(host._world_x(float(node.row)) - host._cam_x),
					absf(host._world_x(float(next_node.row)) - host._cam_x)) \
					/ maxf(step, 1.0) * 0.12, 0.10, 1.0)
				# Same-lane edges run straight; rising bows up, falling bows down
				# so crossing paths pull apart rather than stacking.
				var control: Vector2 = (from + to) * 0.5 \
					+ Vector2(0.0, signf(to.y - from.y) * 10.0)
				var previous: Vector2 = from
				# ~10–12px dash cells from chord length; first cell drawn so the
				# dash begins at the source rim instead of detaching from it.
				var segs: int = maxi(12, int(from.distance_to(to) / 11.0))
				for segment: int in range(segs):
					var t: float = float(segment + 1) / float(segs)
					var point: Vector2 = from * (1.0 - t) * (1.0 - t) \
						+ control * 2.0 * (1.0 - t) * t + to * t * t
					if walked or segment % 2 == 0:
						var tone: Color = Color(0.85, 0.87, 0.92) if walked \
							else GlassStyle.GLASS
						draw_line(previous, point, Color(tone.r, tone.g, tone.b,
							fade * (0.72 if walked else 0.24)),
							3.0 if walked else 2.0)
					previous = point


class VeilBand extends MapBand:
	const ASH_COUNT: int = 128
	var _ash: Array[Vector3] = []    # x, y, fall speed

	func _init() -> void:
		super(1.35)
		gated = false
		# Deterministic scatter — the --shot loop diffs frames, so no randomness.
		for i: int in range(ASH_COUNT):
			var fi: float = float(i)
			_ash.append(Vector3(
				fmod(fi * 137.0, 2400.0), fmod(fi * 211.0, 900.0),
				14.0 + fmod(fi * 7.0, 22.0)))
		set_process(true)

	func _process(delta: float) -> void:
		if host == null:
			return
		# REDUCE MOTION: the ash hangs where it is — the region keeps its weather
		# as dressing, it just stops falling (the benchmark stills `.ember` and
		# every map keyframe the same way, styles.css:2042-2049).
		if Preferences.active.reduce_motion:
			return
		var span: float = maxf(size.x, 1.0) * 2.0
		for i: int in range(_ash.size()):
			var m: Vector3 = _ash[i]
			m.y += m.z * delta
			m.x -= m.z * delta * 0.35  # ash drifts against the walk
			if m.y > size.y:
				m.y -= size.y + 40.0
			_ash[i] = Vector3(fposmod(m.x, span), m.y, m.z)

	## Band 4 (1.35) — near ash, overshooting the walk to sell the depth.
	func _draw() -> void:
		if host == null:
			return
		var w: float = size.x
		var span: float = maxf(w, 1.0) * 2.0
		var glow: Texture2D = SkyField.disc()
		# Veil answers the camera at 1.35 overshoot rather than welding to the
		# glass. Under reduce-motion the fall stills; scroll stays user-initiated
		# (same principle as the pointer-chased title camera).
		var cam_shift: float = cam_x * factor
		for index: int in range(_ash.size()):
			var m: Vector3 = _ash[index]
			var x: float = fposmod(m.x - cam_shift + drift.x, span)
			if x > w:
				continue
			var y: float = fposmod(m.y + drift.y, maxf(size.y, 1.0))
			var radius: float = 2.0 + m.z * 0.08
			var tint: Color = host._glow_colour if index % 3 != 0 \
				else host._particle_colour
			draw_texture_rect(glow, Rect2(
				Vector2(x, y) - Vector2.ONE * radius * 2.0,
				Vector2.ONE * radius * 4.0), false,
				Color(tint, 0.20 + 0.26 * (m.z / 36.0)))
