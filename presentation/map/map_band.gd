class_name MapBand
extends Control
## Overlay strip of the pilgrimage map. Host owns camera + PointerDrift;
## bands store the amplitude-scaled slice and redraw when it moves enough.
## Child order IS paint order: MapScene (world) → marker glow → waystones → chips.
## SkyBand / RegionBand retired in #234 slice 7b2 — 3D MapScene owns the world.
## VeilBand retired in #156 round 2 — the falling ash read as snow over a
## journey the 3D world now carries on its own.

const CAM_EPS: float = 0.05
const DRIFT_EPS: float = 0.1

var factor: float = 1.0
var cam_x: float = 0.0
var drift: Vector2 = Vector2.ZERO  # px; host already scaled the amplitude
## Bands default to redrawing only when the camera or drift actually moves.
## Projected or stateful bands can opt out when that key is insufficient.
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
	## The traveller's small projected glow. Route topology lives only in the
	## depth-tested world-space waylights owned by MapScene.

	func _init() -> void:
		super(1.0)
		# Projection also changes with camera Z and zoom, which set_view does not
		# carry. This overlay is two circles, so redraw it from the live camera.
		gated = false

	func _draw() -> void:
		if host == null:
			return
		if host.map.at >= 0 and host.map.at < host.map.nodes.size():
			var at: Vector2 = host.marker_screen_position()
			var ember: Color = GlassStyle.EMBER
			draw_circle(at, 30.0, Color(ember.r, ember.g, ember.b, 0.10))
			draw_circle(at, 15.0, Color(ember.r, ember.g, ember.b, 0.18))


## The bounty chips, as ONE layer sitting above the waystones.
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
