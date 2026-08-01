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
var _flash: float = 0.0


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


## Heat-lightning envelope from the host. Redraw only on a meaningful step
## (or when the flash dies) so a decaying sub-cent pulse does not thrash.
func set_flash(v: float) -> void:
	var prev: float = _flash
	_flash = v
	if absf(v - prev) > 0.01 or (v <= 0.0 and prev > 0.0):
		queue_redraw()


## Each band washes only the area it painted — both far bands are full-rect
## Controls, so an unclipped overlay double-applies (composite 0.19, not the
## intended 0.10) and would sit over P5.6's strips (PR #75 DL R1).
func _draw_flash_overlay(rect: Rect2) -> void:
	if _flash <= 0.0:
		return
	draw_rect(rect, Color(MapRegions.LIGHTNING_TONE, _flash * 0.10))


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
		_draw_flash_overlay(Rect2(Vector2.ZERO, size))


class RegionBand extends MapBand:
	## Shaft sway clock — advanced only when motion is allowed, so reduce-motion
	## stills the caustics the same way it stills the veil.
	var _age: float = 0.0

	func _init() -> void:
		super(0.35)

	## The sunken region ungates so the shafts keep swaying while the camera
	## rests; the other weathers stay gated (static silhouettes need no
	## per-frame paint). The band asks the config, not the act index.
	func apply_region(region: MapRegions) -> void:
		gated = region.weather != &"sunken"
		set_process(region.weather == &"sunken")
		queue_redraw()

	func _process(delta: float) -> void:
		if host == null:
			return
		# Stilled sway re-gates the band: repainting an identical frame is
		# the cost the gate exists to avoid (PR #75 DL R1 NIT).
		gated = Preferences.active.reduce_motion
		if Preferences.active.reduce_motion:
			return
		_age += delta

	func _draw() -> void:
		if host == null:
			return
		var w: float = size.x
		var h: float = size.y
		var horizon: float = h * host._trail_num("horizonY", 0.36) + drift.y
		var path_y: float = h * host._trail_num("pathY", 0.64) + drift.y
		# Bleeds past the frame bottom by more than the far drift amplitude —
		# an upward lean must not leave a strip of raw sky under the ground.
		draw_rect(Rect2(0.0, horizon, w, h - horizon + 8.0),
			Color(WorldMapScreen.REGION_GROUND, 0.62 if host._act == 0 else 0.38))
		var ground: Rect2 = Rect2(0.0, horizon, w, h - horizon)
		if host._region != null and host._region.weather == &"sunken":
			_draw_shafts(w, horizon, path_y)
		if host._act > 0:
			for cloud: int in range(9):
				var cloud_w: float = w * (0.18 + float(cloud % 3) * 0.035)
				var cloud_h: float = 54.0 + float(cloud % 4) * 13.0
				var x: float = fposmod(float(cloud) * w * 0.17 - cam_x * factor,
					w + cloud_w) - cloud_w + drift.x
				draw_texture_rect(SkyField.disc(),
					Rect2(x, horizon - cloud_h * 0.68, cloud_w, cloud_h), false,
					Color(host._fog_colour.lightened(0.50), 0.15))
			_draw_flash_overlay(ground)
			return
		# Trees derive from the horizon→path span — the RATIOS are the P5.2
		# absolutes read against that shape's own span (bases 321–351 and
		# heights 90–180 over a 230px span at pad-landscape → 0.113–0.244 and
		# 0.391–0.783), so the identity shape keeps its approved look while
		# phone-landscape (span 55: bases 146.2–153.4, ribbon 195) stays clear.
		var span_y: float = path_y - horizon
		var span: float = w + 400.0
		var trunk: Color = Color(0.025, 0.065, 0.048, 0.94)
		var rim: Color = Color(host._accent_colour, 0.08)
		for tree: int in range(20):
			var index: float = float(tree)
			var x: float = fposmod(index * 163.0 - cam_x * factor, span) \
				- 200.0 + drift.x
			var tree_h: float = span_y * (0.391 + fmod(index * 53.0, 90.0) / 90.0 * 0.392)
			var base_y: float = horizon + span_y * (0.113 \
				+ fmod(index * 29.0, 30.0) / 30.0 * 0.131)
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
		_draw_flash_overlay(ground)

	func _draw_shafts(w: float, horizon: float, path_y: float) -> void:
		# Six near-vertical caustics between horizon and path — the Sunken
		# City's drowned light. Sway is deterministic off _age + index. Each
		# shaft is two per-vertex-ramped quads (a wide veil over a narrower
		# core) fading to nothing at the road: light that SINKS must not end
		# in a flat cut a few px under the ribbon (PR #75 DL R1).
		for i: int in range(6):
			var fi: float = float(i)
			var sway: float = sin(_age * 0.4 + fi * 1.7)
			var x: float = fposmod(fi * w * 0.19 - cam_x * factor, w * 1.2) \
				- w * 0.1 + sway * 14.0 + drift.x
			var alpha: float = 0.05 + 0.03 * (0.5 + 0.5 * sway)
			var glow: Color = host._glow_colour
			var clear: Color = Color(glow, 0.0)
			draw_polygon(PackedVector2Array([
				Vector2(x - 14.0, horizon), Vector2(x + 14.0, horizon),
				Vector2(x + 34.0, path_y), Vector2(x - 34.0, path_y),
			]), PackedColorArray([
				Color(glow, alpha * 0.7), Color(glow, alpha * 0.7),
				clear, clear,
			]))
			draw_polygon(PackedVector2Array([
				Vector2(x - 7.0, horizon), Vector2(x + 7.0, horizon),
				Vector2(x + 17.0, path_y), Vector2(x - 17.0, path_y),
			]), PackedColorArray([
				Color(glow, alpha * 0.6), Color(glow, alpha * 0.6),
				clear, clear,
			]))


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
		# Terminus rose-window BEFORE the graph so edges/stones layer over it.
		_draw_rose_window()
		_draw_graph()
		# The current lantern's glow sits behind its waystone (or mid-glide
		# along the same bezier the edges draw — host owns travel state).
		if host.map.at >= 0 and host.map.at < host.map.nodes.size():
			var at: Vector2 = host.marker_screen_position()
			var ember: Color = GlassStyle.EMBER
			draw_circle(at, 30.0, Color(ember.r, ember.g, ember.b, 0.10))
			draw_circle(at, 15.0, Color(ember.r, ember.g, ember.b, 0.18))

	## §3 keystone backdrop — quiet night-glass silhouette; painted art is P5.6+.
	func _draw_rose_window() -> void:
		var boss: MapNode = null
		for node: MapNode in host.map.nodes:
			if node.type == "boss":
				boss = node
				break
		if boss == null:
			return
		var pos: Vector2 = host._node_pos(boss)
		var step: float = host._step()
		var depth: float = absf(host._world_x(float(boss.row)) - host._cam_x) \
			/ maxf(step, 1.0)
		# Same depth compress the waystones use — the window tracks the stone.
		var compress: float = clampf(1.08 - depth * 0.035, 0.72, 1.08)
		var R: float = 110.0 * compress
		var glass: Color = GlassStyle.GLASS
		var side: float = R * 2.6
		draw_texture_rect(SkyField.disc(),
			Rect2(pos - Vector2.ONE * side * 0.5, Vector2.ONE * side), false,
			Color(host._accent_colour, 0.10))
		draw_arc(pos, R, 0.0, TAU, 64, Color(glass.r, glass.g, glass.b, 0.18), 3.0)
		draw_arc(pos, R * 0.62, 0.0, TAU, 48, Color(glass.r, glass.g, glass.b, 0.14), 2.0)
		for spoke: int in range(8):
			var a: float = float(spoke) * TAU / 8.0
			var dir: Vector2 = Vector2(cos(a), sin(a))
			draw_line(pos + dir * R * 0.18, pos + dir * R,
				Color(glass.r, glass.g, glass.b, 0.16), 2.0)

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
	var _weather: StringName = &"ash"

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

	func apply_region(region: MapRegions) -> void:
		_weather = region.weather
		# Particle budget stays 128 unless the config names another count —
		# rebuilding would shuffle the deterministic scatter mid-walk.
		queue_redraw()

	func _process(delta: float) -> void:
		if host == null:
			return
		# REDUCE MOTION: the ash hangs where it is — the region keeps its weather
		# as dressing, it just stops falling (the benchmark stills `.ember` and
		# every map keyframe the same way, styles.css:2042-2049).
		if Preferences.active.reduce_motion:
			return
		var span: float = maxf(size.x, 1.0) * 2.0
		var kind: StringName = _weather
		if host._region != null:
			kind = host._region.weather
		for i: int in range(_ash.size()):
			var m: Vector3 = _ash[i]
			var fi: float = float(i)
			match kind:
				&"sunken":
					# Rising motes with a per-index lateral sway — deterministic.
					m.y -= m.z * delta * 0.55
					m.x += sin((m.y + fi) * 0.02) * 12.0 * delta
					if m.y < -40.0:
						m.y += size.y + 40.0
				&"storm":
					# Sideways ember streaks against the walk.
					m.x -= m.z * delta * 2.6
					m.y += m.z * delta * 0.22
					if m.y > size.y:
						m.y -= size.y + 40.0
					elif m.y < -40.0:
						m.y += size.y + 40.0
				_:
					# Act-0 ash — byte-identical fall/drift/wrap.
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
		var kind: StringName = _weather
		var visible_count: int = _ash.size()
		if host._region != null:
			kind = host._region.weather
			visible_count = mini(host._region.particle_count, _ash.size())
		for index: int in range(visible_count):
			var m: Vector3 = _ash[index]
			var x: float = fposmod(m.x - cam_shift + drift.x, span)
			if x > w:
				continue
			var y: float = fposmod(m.y + drift.y, maxf(size.y, 1.0))
			var radius: float = 2.0 + m.z * 0.08
			var tint: Color = host._glow_colour if index % 3 != 0 \
				else host._particle_colour
			var alpha: float = 0.20 + 0.26 * (m.z / 36.0)
			if kind == &"storm":
				# Speed reads as a streak — the SAME soft disc stretched along
				# the velocity, ≥3× longer than tall and 40% dimmer, so an
				# ember can never be confused with the graph's crisp lead
				# dashes on the play plane (PR #75 DL R1 MAJOR).
				var length: float = maxf(radius * 3.0, m.z * 0.5)
				draw_texture_rect(glow, Rect2(
					Vector2(x - length * 0.5, y - radius * 0.5),
					Vector2(length, radius)), false,
					Color(tint, alpha * 0.6))
			else:
				draw_texture_rect(glow, Rect2(
					Vector2(x, y) - Vector2.ONE * radius * 2.0,
					Vector2.ONE * radius * 4.0), false,
					Color(tint, alpha))
