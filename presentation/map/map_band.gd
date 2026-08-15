class_name MapBand
extends Control
## Overlay strip of the pilgrimage map. Host owns camera + PointerDrift;
## bands store the amplitude-scaled slice and redraw when it moves enough.
## Child order IS paint order: MapScene (world) → path → waystones → chips → veil.
## SkyBand / RegionBand retired in #234 slice 7b2 — 3D MapScene owns the world.

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


class PathBand extends MapBand:
	func _init() -> void:
		super(1.0)
		gated = false

	func _draw() -> void:
		if host == null:
			return
		# 3D MapScene owns the ground. This band is the graph overlay —
		# frozen edges projected between lattice seats, plus the lantern glow.
		# `_draw_bed` / `_draw_rose_window` retired with the 2D road in #234 7b2.
		_draw_graph()
		if host.map.at >= 0 and host.map.at < host.map.nodes.size():
			var at: Vector2 = host.marker_screen_position()
			var ember: Color = GlassStyle.EMBER
			draw_circle(at, 30.0, Color(ember.r, ember.g, ember.b, 0.10))
			draw_circle(at, 15.0, Color(ember.r, ember.g, ember.b, 0.18))

	func _draw_graph() -> void:
		var by_id: Dictionary = {}
		var frame: Rect2 = Rect2(Vector2.ZERO, size).grow(80.0)
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
				var fade: float = 1.0 if frame.has_point(from) or frame.has_point(to) \
					else 0.10
				var control: Vector2 = host.edge_control(from, to)
				var previous: Vector2 = from
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
		# Step only what `_draw` renders — storm drew 64 of 128 and stepped all
		# 128 (#69, carried from P5.4 DL R2). The undrawn tail holds its
		# position, which cannot show: `main._show_map` builds a fresh
		# WorldMapScreen on every route to the map, so the scatter is reborn
		# before an act advance could ever resume a frozen mote. The one path
		# that raises the count on a LIVE band is `--map --act=N`, and that
		# applies in the same frame as the build.
		var moving: int = _ash.size()
		if host._region != null:
			moving = mini(host._region.particle_count, _ash.size())
		for i: int in range(moving):
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
				# the velocity, never a `draw_line`, and always ≥3× longer than
				# tall, so an ember cannot be confused with the graph's crisp
				# lead dashes on the play plane (PR #75 DL R1 MAJOR).
				#
				# That fix was right in kind and 5–10× too strong in degree: the
				# primitive change is what stopped the impersonation, and the
				# dimming and thinning on top of it left the act-3 storm as the
				# QUIETEST weather in the game. The aspect floor is what keeps
				# the streak safe, not its faintness, so the ink comes back —
				# thicker, longer, brighter — with the 3:1 floor measured
				# against the new thickness (#69 C3).
				var thick: float = radius * 2.2
				var length: float = maxf(thick * 3.0, m.z * 0.9)
				draw_texture_rect(glow, Rect2(
					Vector2(x - length * 0.5, y - thick * 0.5),
					Vector2(length, thick)), false,
					Color(tint, alpha))
			else:
				draw_texture_rect(glow, Rect2(
					Vector2(x, y) - Vector2.ONE * radius * 2.0,
					Vector2.ONE * radius * 4.0), false,
					Color(tint, alpha))


## The bounty chips, as ONE layer sitting between the waystones and the veil.
##
## Every stone drew its own chip once, first inside `_draw` (where the stone's
## art and every later sibling painted over it) and then in a per-stone child at
## `z_index` 1 — which fixed the slicing by outranking the veil and the chrome
## as well, i.e. by breaking the "child order IS paint order" contract this file
## opens with (PR #80 DL R1).
##
## One sibling in the right seat needs no `z_index` at all, drops six nodes to
## one on seed 717, and takes two hacks with it: the chip no longer inherits a
## stone's depth alpha, so nothing has to divide that back out, and the layer
## knows the FRAME, so a chip that would run off the right edge can flip to the
## stone's left — the rule every tooltip uses, and the fix for a number that
## rendered as `+1` instead of `+17` at 11% of camera positions.
class ChipBand extends MapBand:
	## Hysteresis on the flip, in stage px. Pointer drift sweeps a stone's
	## screen x by PATH_DRIFT_AMP.x as the pointer crosses the stage WITH NO
	## PAN AT ALL. Against a bare threshold that pops the pill 98 px across
	## while the player only moves the cursor (PR #80 DL R2). 32 > that 28 px
	## sweep, with margin; the cost of the band is a pill that keeps its side
	## while it has up to 32 px of room back, which reads as nothing.
	const FLIP_SLACK: float = 32.0

	## Last side chosen per stone index — the flip's only state, and the reason
	## `flips` can stay pure and asserted.
	var _flipped: Dictionary[int, bool] = {}

	func _init() -> void:
		super(1.0)
		gated = false

	## Whether the STONE is in frame. Culling on this is what stops the chip
	## outliving its lantern. In the old 13 px `+N` geometry, the pill reached
	## ~49 stage px from a centre whose stone ink reached ~20, leaving a 29 px
	## edge band where `+17` sat alone on the road. At the right edge the flip
	## made it worse, converting "nothing drawn" into a truncated `+` with no
	## referent (PR #80 DL R2 MAJOR). The cull remains defined by stone ink, so
	## changing label geometry cannot reintroduce that orphan.
	##
	## Measured against the stone's INK, not its rect: the touch rect is padded
	## out to `set_touch_min`'s finger floor and would cull a frame or two late.
	static func on_screen(centre_x: float, ink: float, frame_w: float) -> bool:
		return centre_x + ink > 0.0 and centre_x - ink < frame_w

	## Which side of the stone the pill goes on. Pure, so `tests/test_map.gd` can
	## assert the rule rather than a capture chasing the 26px of node step where
	## it bites. Right by default; left only when the right runs off the frame AND
	## the left does not.
	##
	## The "nowhere to go" branch needs `frame_w < 2 · reach`, still well below
	## the narrowest shipped stage's 390 px, so it cannot fire in the game
	## and is kept only to keep the function total. The reachable failure was
	## never this one: it was the stone leaving the frame, and `on_screen` owns
	## it (PR #80 DL R2).
	static func flips(centre_x: float, reach: float, frame_w: float,
			was_flipped: bool = false) -> bool:
		if centre_x - reach < 0.0:
			return false
		return centre_x + reach > frame_w - (FLIP_SLACK if was_flipped else 0.0)

	## A pill's rect in STAGE px: the stone's own `chip_rect()` through its
	## transform. Pure, and a RECT — the first version of the sibling rule below
	## compared x spans only, which reads every same-column pair as a collision
	## because they share `world_x` and differ only by lane (PR #80 DL R4).
	static func pill_rect(local: Rect2, at: Vector2, node_scale: Vector2) -> Rect2:
		return Rect2(at + local.position * node_scale, local.size * node_scale)

	## Which chips this band paints at `frame_w`, and the side each takes, keyed
	## by stone index. `_draw` asks this and then only draws.
	##
	## Separated because the MAJOR it exists to stop was never a wrong RULE — it
	## was a rule that nothing asked. `flips` was pure and asserted while
	## `_draw` drew every chip unconditionally, so a green suite and an orphaned
	## `+17` on empty road were consistent with each other (PR #80 DL R2). The
	## decision is now the thing the suite can hold.
	func seats(frame_w: float) -> Dictionary[int, bool]:
		var out: Dictionary[int, bool] = {}
		if host == null:
			return out
		# Left to right, so the pill already on the road is the one that keeps
		# its place. Waystone order is row-major and NOT reliably screen order
		# once jitter moves a stone across a step boundary.
		var chipped: Array[GlassWaystone] = []
		for ws: GlassWaystone in host._waystones:
			if ws.has_chip():
				chipped.append(ws)
		chipped.sort_custom(func(a: GlassWaystone, b: GlassWaystone) -> bool:
			return a.position.x < b.position.x)
		var taken: Array[Rect2] = []
		for ws: GlassWaystone in chipped:
			var scale_x: float = ws.scale.x
			var centre_x: float = ws.position.x + ws.size.x * scale_x * 0.5
			if not on_screen(centre_x, ws.pane_radius() * scale_x, frame_w):
				_flipped.erase(ws.index)
				continue
			var was: bool = _flipped.get(ws.index, false)
			var reach: float = ws.chip_reach() * scale_x
			var flip: bool = flips(centre_x, reach, frame_w, was)
			var rect: Rect2 = pill_rect(ws.chip_rect(flip), ws.position, ws.scale)
			# A flip may not bury the neighbour it flips towards. On seed 17634
			# at phone-portrait, two same-lane stones' candidate pill rects overlap.
			# A flipped pill therefore lands inside the one already seated and
			# the old `+16` rendered as `+1` (#69 D1, PR #80 DL R3, photographed).
			#
			# Both axes. The first version of this compared x only and declined
			# every same-COLUMN pair — identical `world_x`, one lane apart, so
			# always overlapping in x and never within 12 px of each other in y.
			# It suppressed 36 of 150 bounty stones for over half their time on
			# screen, some of them entirely (DL R4).
			#
			# Declined rather than re-seated: the other side is the one `flips`
			# just rejected for running off the frame, so seating there renders a
			# TRUNCATED number — which is the R1 MAJOR this PR already fixed
			# once. A number that reads as a different number is worse than no
			# number, and the stone is at the frame edge, so a few px of pan
			# brings it back.
			var buried: bool = false
			for other: Rect2 in taken:
				if rect.intersects(other):
					buried = true
					break
			if buried:
				_flipped.erase(ws.index)
				continue
			taken.append(rect)
			_flipped[ws.index] = flip
			out[ws.index] = flip
		return out

	func _draw() -> void:
		if host == null:
			return
		var painted: Dictionary[int, bool] = seats(size.x)
		for ws: GlassWaystone in host._waystones:
			if not painted.has(ws.index):
				continue
			draw_set_transform(ws.position, 0.0, ws.scale)
			ws.paint_bounty_chip(self, painted[ws.index])
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
