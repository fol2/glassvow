class_name MapBand
extends Control
## One parallax strip of the pilgrimage map. Host owns camera + PointerDrift;
## bands store the amplitude-scaled slice and redraw when it moves enough.
## Child order IS paint order (sky → region → path → waystones → veil), so the
## Spire wedge sits behind the region trees by construction.

const CAM_EPS: float = 0.05
const DRIFT_EPS: float = 0.1
## Far bands are full-rect Controls painted with a divided drift; the sky bleeds
## above the frame and the region below it so a pointer lean never opens raw
## stage. Must stay ≥ the far-band drift amplitude
## (WorldMapScreen.PATH_DRIFT_AMP.y / 3.0 = 4.0) — asserted in tests/test_map.gd,
## because map_band and world_map_screen are a cyclic class_name pair and a
## const expression across them is not safe to write.
const FAR_BLEED: float = 8.0

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
	var _strip: Texture2D = null

	func _init() -> void:
		super(0.10)

	func apply_region(region: MapRegions) -> void:
		_strip = MapStrip.fetch(region.act, &"skyband")
		queue_redraw()

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
		var horizon: float = h * host._trail_num("horizonY", 0.36)
		# The strip is the band's ATMOSPHERE; the Spire is an OBJECT on it. They
		# are drawn together, never one instead of the other: §1 makes the Spire a
		# single constant goal-anchor doubling as an act meter, and a tiling
		# backdrop cannot hold a singular landmark — a 3072-wide strip lays two
		# tiles on a 1180 stage and the anchor becomes wallpaper (PR #77 DL R1).
		# The screen-anchor rule below survives for the same reason.
		if _strip != null:
			MapStrip.draw_tiled(self, _strip,
				Rect2(0.0, 0.0, w, horizon + FAR_BLEED),
				cam_x * factor - drift.x, Color(1.0, 1.0, 1.0, 1.0))
		_draw_spire(w, horizon)
		# Washes the SKY, not the stage. The full-rect version put a step across
		# the horizon: below it the region's ground scrim is only 0.38, so the
		# sky's flash survived at 0.62 of its strength and added to the region's
		# own wash — one flash counted twice on the lower two thirds of the
		# frame, for the ~0.5s it lasts. Each band washes what it painted, which
		# is the same rule `_draw_flash_overlay`'s own docstring states and this
		# call site did not follow (#69 C2).
		# Ends exactly where the region's ground begins — `horizon + drift.y`, the
		# same expression with the same `far_d` both bands are pushed. An earlier
		# revision used `horizon + FAR_BLEED`, which is drift-blind, so the two
		# rects overlapped 4-12px and left a full-width band at 1.63x the wash
		# during a flash: the step became a hairline instead of going (PR #80 DL R1).
		_draw_flash_overlay(Rect2(0.0, 0.0, w, horizon + drift.y))

	## The §1 goal-anchor. SCREEN-anchored — at 0.10 the whole journey drifts a
	## lone object only a tenth of the act, so a world anchor parks it off-stage
	## for every step of the walk (PR #71 DL R2).
	##
	## The silhouette is read from near-vertical converging edges, so the SLANT is
	## the invariant, not the top width: deriving `top_w` from `base_w` made the
	## flare grow with the act AND with the stage's aspect — one intent gave 14.1°
	## on phone-portrait and 40.9° on desktop-landscape, and act 2 read as a
	## mountain (PR #77 DL R1). Holding the slant instead means the three acts are
	## the same building seen from three distances, which is what an act meter has
	## to be. `MapRegions.SPIRE_SLANT` documents where the taper floor makes that
	## ≤13° rather than =13°.
	##
	## "Converging edges" is the reading, not a promise that both are on stage: at
	## act 2 on a wide shape the right edge clears the frame at every visible row
	## (1194.4 against a 1180 stage), so what ships is one leaning edge and a wall
	## of glass. That IS standing at its foot. Portrait shapes keep both edges, so
	## act 2 is shape-dependent before anyone paints it — noted on #70 for P5.8.
	func _draw_spire(w: float, horizon: float) -> void:
		var act: int = host._act
		if host._region != null:
			act = host._region.act
		act = clampi(act, 0, MapRegions.SPIRE_W_RATE.size() - 1)
		var base_w: float = w * MapRegions.SPIRE_W_RATE[act] * 0.5
		var apex_y: float = horizon * (1.0 - MapRegions.SPIRE_H_RATE[act]) - FAR_BLEED
		# Floored at a fraction of the base so a tall narrow stage can never
		# invert the taper into an hourglass.
		var top_w: float = maxf(base_w - (horizon - apex_y) * MapRegions.SPIRE_SLANT,
			base_w * 0.18)
		var centre: float = w * 0.82 - cam_x * factor + drift.x
		# Near acts cut BELOW the sky, far acts lift toward the fog — see the
		# ramp docstring in map_regions.gd for why darkening alone leaves act 0
		# with no readable silhouette at all.
		var tone: Color = host._sky_colour.darkened(MapRegions.SPIRE_DARKEN[act])
		tone = tone.lerp(host._fog_colour.lightened(0.35),
			MapRegions.SPIRE_HAZE[act])
		draw_colored_polygon(PackedVector2Array([
			Vector2(centre - top_w, apex_y + drift.y),
			Vector2(centre + top_w, apex_y + drift.y),
			Vector2(centre + base_w, horizon + drift.y),
			Vector2(centre - base_w, horizon + drift.y),
		]), tone)


class RegionBand extends MapBand:
	## The procedural treeline's own ratios against `span_y = path_y - horizon`.
	## Named because `CROWN_BLEED` below is DERIVED from them and the strip rect
	## is derived from that: the literals had one reader (the fallback loop) and
	## now have two, and two copies of a ratio is how the strip stops matching
	## the art it was authored against.
	const TREE_H_MIN: float = 0.391
	const TREE_H_SPAN: float = 0.392
	const TREE_BASE_MIN: float = 0.113
	const TREE_BASE_SPAN: float = 0.131
	## How far above the horizon a painted strip may reach, as a fraction of the
	## band's own `span_y`. A RATIO, never a constant: `span_y` is 229.6 px at
	## pad-landscape and 54.6 px at phone-landscape, so a px figure tuned on one
	## shape is 4x wrong on the other — the BED_HALF lesson from #69 C5.
	##
	## The value is the fallback's own supremum, not a taste call. A tree's apex
	## sits `span_y * (base_ratio - height_ratio)` from the horizon, `base_ratio`
	## runs TREE_BASE_MIN…+SPAN and `height_ratio` runs TREE_H_MIN…+SPAN, so the
	## tallest tree on the lowest base lifts `TREE_H_MIN + TREE_H_SPAN -
	## TREE_BASE_MIN` = 0.670 of the span. The 20 indices the loop actually walks
	## reach 0.539 (tree 15, the `fmod` strides never pair a max with a min), so
	## authored art matching what ships clears the rect with room; taking the
	## supremum instead means changing the tree count or either stride cannot
	## silently start decapitating the strip.
	##
	## Safe against the frame top on every shape: it needs
	## `horizonY / (pathY - horizonY)`, which is 1.286 everywhere and 2.571 at
	## phone-landscape (the one shape overriding `pathY`). Asserted per shape in
	## tests/test_map.gd.
	const CROWN_BLEED: float = TREE_H_MIN + TREE_H_SPAN - TREE_BASE_MIN

	## Shaft sway clock — advanced only when motion is allowed, so reduce-motion
	## stills the caustics the same way it stills the veil.
	var _age: float = 0.0
	var _strip: Texture2D = null

	func _init() -> void:
		super(0.35)

	## The sunken region ungates so the shafts keep swaying while the camera
	## rests; the other weathers stay gated (static silhouettes need no
	## per-frame paint). The band asks the config, not the act index.
	func apply_region(region: MapRegions) -> void:
		gated = region.weather != &"sunken"
		set_process(region.weather == &"sunken")
		_strip = MapStrip.fetch(region.act, &"region")
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

	## Where a PAINTED strip goes. Not the ground scrim's rect and not the
	## fallback's: the scrim is ground tint and must stop at the horizon, but a
	## skyline is an object standing ON the ground and its crowns rise above it.
	##
	## The rect used to start exactly AT `horizon`, so a strip could not place one
	## pixel above it while the fallback drawn by the same band stood trees up to
	## `CROWN_BLEED` of the span higher. Art authored to the fallback was
	## decapitated and art authored to the rect was a distant range using a tenth
	## of its canvas (#86). Pure and static so tests/test_map.gd can gate the
	## clearance across the shape matrix instead of chasing it in a capture.
	static func strip_rect(w: float, h: float, horizon: float,
			path_y: float) -> Rect2:
		var lift: float = (path_y - horizon) * CROWN_BLEED
		return Rect2(0.0, horizon - lift, w, h - horizon + lift + FAR_BLEED)

	func _draw() -> void:
		if host == null:
			return
		var w: float = size.x
		var h: float = size.y
		var horizon: float = h * host._trail_num("horizonY", 0.36) + drift.y
		var path_y: float = h * host._trail_num("pathY", 0.64) + drift.y
		# Bleeds past the frame bottom by more than the far drift amplitude —
		# an upward lean must not leave a strip of raw sky under the ground.
		draw_rect(Rect2(0.0, horizon, w, h - horizon + FAR_BLEED),
			Color(WorldMapScreen.REGION_GROUND, 0.62 if host._act == 0 else 0.38))
		var ground: Rect2 = Rect2(0.0, horizon, w, h - horizon)
		# The strip covers the WHOLE ground, not just the skyline — so it goes in
		# BEFORE the shafts, not after. The clouds it was modelled on are 54–93px
		# discs at the horizon; this is a 533px quad that would swallow act 1's
		# signature weather entirely (PR #77 DL R1). Caustics are volumetric light
		# between the viewer and the drowned towers: they belong in front.
		if _strip != null:
			MapStrip.draw_tiled(self, _strip,
				strip_rect(w, h, horizon, path_y),
				cam_x * factor - drift.x, Color(1.0, 1.0, 1.0, 1.0))
		if host._region != null and host._region.weather == &"sunken":
			_draw_shafts(w, horizon, path_y)
		if _strip != null:
			_draw_flash_overlay(ground)
			return
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
			var tree_h: float = span_y * (TREE_H_MIN \
				+ fmod(index * 53.0, 90.0) / 90.0 * TREE_H_SPAN)
			var base_y: float = horizon + span_y * (TREE_BASE_MIN \
				+ fmod(index * 29.0, 30.0) / 30.0 * TREE_BASE_SPAN)
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

	## Act 1's caustics, in the REGION band only — a deliberate departure from
	## §3's "sink through the bands", recorded here because this is where the
	## next reader will come looking for the missing echo (#69 C1).
	##
	## The veil is the 1.35 overshoot plane: a shaft drawn there crosses IN FRONT
	## of the waystones and the graph, which is the wrong-plane failure #66/#67
	## already cost two rounds. Depth here is bought by the shafts standing
	## BEHIND the stones while the rising motes drift in front of them — two
	## planes doing different jobs. A near echo would put the same vocabulary on
	## both sides of the play plane and flatten the very cue it copies.
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
	## Alpha at the crown of the road bed, at the lip where the bed ends, and the
	## verge's reach as a multiple of the bed's own half-height.
	##
	## The lip is what makes this a road rather than a band of haze, and it is a
	## GRADIENT BREAK, not a stroke: the bed falls 0.09 → 0.03 across its half,
	## then the verge falls 0.03 → 0 across a further 0.9 of that half — `VERGE`
	## is the verge's REACH from the crown, so the verge is slightly NARROWER
	## than the bed, not "nearly twice" it as this sentence read until PR #84
	## DL R1 m1 measured the profile and found it zero at t = 1.9. The slope
	## changes at the lip and nothing hard is drawn, because the dashes own the
	## only hard line on this plane (#64) and a second one reads as one thing
	## drawn twice (#66/#67).
	const BED_A: float = 0.09
	const LIP_A: float = 0.03
	const VERGE: float = 1.9
	## Steps across the frame. The taper is piecewise LINEAR — depth is linear in
	## x and the taper is linear in depth — so this polyline is exact everywhere
	## except within one cell of the kink at the camera's seat.
	##
	## With slope `s = base · 0.18 / step`, cell width `h = W / BED_STEPS` and the
	## kink sitting `f` of a cell from the nearest vertex, the deficit there is
	## `2·s·h·f·(1−f)`, bounded by `s·h/2` — HALF the one-cell figure this
	## docstring used to quote, and quoted for the wrong shape besides (PR #84
	## PM R1). Solved per shape, the bed boundary is off by **0.0035–0.0762 px**
	## and the verge's outer boundary, at 1.9× the slope, by up to **0.1448 px**.
	##
	## Worst is **phone-portrait**, and the reason is the thing to carry away: it
	## is the one shape that overrides `lead` (0.22, and `stepMin` 128). Elsewhere
	## `lead·BED_STEPS = 0.333·24 = 7.992`, so the kink lands within 0.008 of a
	## cell of vertex 8 and the error is ~0.005 px; at 0.22 it lands 0.28 of a
	## cell away and the error is 16× larger. **BED_STEPS and `lead` are coupled**
	## — a value that is not a multiple of three stops the kink landing on a
	## vertex at the four shapes where it currently does.
	##
	## Two further facts measured on this polyline, neither of them its fault:
	## the `bed_taper` floor IS reached on desktop-landscape, adding a second
	## kink over the final 5.8 px of a 1458 px stage (sub-pixel, non-degenerate);
	## and the rendered apex measures 6.85 px against the formula's 7.61 — a
	## deficit of 0.76 px, quoted to the precision that makes it fall out of the
	## subtraction as well as out of the ~10% (PR #84 DL R3). Isolated by
	## re-rendering with the taper disabled and fitting a 12-frame median per
	## column — a different control from `bed_taper`'s alpha-zero differencing,
	## and used for a different job, though both fit the SAME 6.85 px.
	##
	## That deficit is 0.76 px, i.e. **162× the chord error at pad-landscape
	## where it was measured** (0.0047 px) and 10× even the worst-shape BED figure
	## above — two orders of magnitude, not the three an earlier draft of this
	## sentence claimed, which PR #84 DL R2 falsified against numbers eight lines
	## up. The conclusion is unchanged and the correction matters anyway: this
	## sentence is the whole argument for not chasing the defect, so it cannot be
	## the one carrying an unreproducible figure.
	##
	## What IS known, and is worth a reader's time before they spend a capture
	## round: at the far edge the formula and the measurement agree to within a
	## couple of percent, against −10% at the apex. **The effect is apex-local —
	## not a global scale factor and not a constant threshold loss.** The cause
	## is still unresolved. It is benign, and arguably load-bearing: a blunt apex
	## is what stops the taper reading as an arrowhead.
	const BED_STEPS: int = 24

	func _init() -> void:
		super(1.0)

	## The bed and its verge, tapered per column. Four strips: bed and verge,
	## above and below `path_y`.
	##
	## The half-height comes from `host.bed_half(x)` — the screen owns it because
	## the taper reads the same depth the stones do, and this map has twice paid
	## for a second derivation of one projection (#70, carried from #69 C5/A7).
	func _draw_bed(w: float, path_y: float) -> void:
		var glass: Color = GlassStyle.GLASS
		_draw_ramp(w, path_y, -1.0, 0.0, 1.0, BED_A, LIP_A, glass)
		_draw_ramp(w, path_y, 1.0, 0.0, 1.0, BED_A, LIP_A, glass)
		_draw_ramp(w, path_y, -1.0, 1.0, VERGE, LIP_A, 0.0, glass)
		_draw_ramp(w, path_y, 1.0, 1.0, VERGE, LIP_A, 0.0, glass)

	## One tapered strip: from `from_mul` of the bed's half-height to `to_mul`,
	## fading `a_from` to `a_to`, on the `sign` side of the road.
	func _draw_ramp(w: float, path_y: float, sign: float, from_mul: float,
			to_mul: float, a_from: float, a_to: float, tone: Color) -> void:
		var points: PackedVector2Array = PackedVector2Array()
		var colours: PackedColorArray = PackedColorArray()
		var near: Color = Color(tone.r, tone.g, tone.b, a_from)
		var far: Color = Color(tone.r, tone.g, tone.b, a_to)
		for i: int in range(BED_STEPS + 1):
			var x: float = w * float(i) / float(BED_STEPS)
			points.append(Vector2(x, path_y + sign * host.bed_half(x) * from_mul))
			colours.append(near)
		for i: int in range(BED_STEPS, -1, -1):
			var x: float = w * float(i) / float(BED_STEPS)
			points.append(Vector2(x, path_y + sign * host.bed_half(x) * to_mul))
			colours.append(far)
		draw_polygon(points, colours)

	func _draw() -> void:
		if host == null:
			return
		var w: float = size.x
		# §5 band 3 — the ground line, the leaded path. No longer a stand-in: the
		# bed tapers with the same depth the stones read and ends at a lip, which
		# is what #69 A7 filed as missing and #70 owns. Still no hairline at
		# `pathY` — a crisp lead there doubles with the centre lane's own edge run
		# and two things drawn the same way read as one thing drawn twice (P5.2,
		# #64). The graph's dashes own the only hard line on this plane.
		var path_y: float = size.y * host._trail_num("pathY", 0.64) + drift.y
		_draw_bed(w, path_y)
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

	## §3 keystone backdrop — quiet night-glass silhouette; painted art is
	## P5.6+/P5.8. The window is an ARCH the stone stands at the foot of: its
	## base meets the path, low-alpha panes fill the upper fan (leading needs
	## glass to separate — rings alone read as a reticle), every weight sits
	## BELOW the path ribbon's, and the leading springs from the stone's rim.
	## P5.8 NOTE: anchored to the boss node's _node_pos at parallax 1.0 as a
	## stand-in; painted terminus architecture belongs to the region plane
	## (§5 band 2) and must not inherit this placement contract.
	func _draw_rose_window() -> void:
		var boss: MapNode = null
		for node: MapNode in host.map.nodes:
			if node.type == "boss":
				boss = node
				break
		if boss == null:
			return
		var pos: Vector2 = host._node_pos(boss)
		var depth: float = host.depth_of(host._world_x(float(boss.row)))
		# The radius lives on the HOST, not here. It was a copy of the stones'
		# curve once, and when that curve's anchor moved from 1.08 to 1.0 the
		# copy was left behind for one commit — an arch 8% larger than the
		# keystone standing at its foot, at the terminus, the one frame this
		# whole change exists to compose (PR #79 PM R1). One function now, so a
		# later edit cannot move the stones without moving the arch, and so
		# `tests/test_map.gd` can assert the fit against what actually draws.
		var R: float = host.arch_radius(depth, size.y)
		var path_y: float = size.y * host._trail_num("pathY", 0.64) + drift.y
		var centre: Vector2 = Vector2(pos.x, path_y - R)
		var glass: Color = GlassStyle.GLASS
		var side: float = R * 2.4
		draw_texture_rect(SkyField.disc(),
			Rect2(centre - Vector2.ONE * side * 0.5, Vector2.ONE * side), false,
			Color(host._accent_colour, 0.08))
		# Six panes across the upper fan, alternating like leaded glass.
		for pane: int in range(6):
			var a0: float = deg_to_rad(-160.0 + float(pane) * (140.0 / 6.0))
			var a1: float = deg_to_rad(-160.0 + float(pane + 1) * (140.0 / 6.0))
			var points: PackedVector2Array = PackedVector2Array([centre])
			for seg: int in range(5):
				var a: float = lerpf(a0, a1, float(seg) / 4.0)
				points.append(centre + Vector2(cos(a), sin(a)) * R)
			draw_colored_polygon(points,
				Color(host._accent_colour, 0.055 if pane % 2 == 0 else 0.035))
		draw_arc(centre, R, 0.0, TAU, 64, Color(glass.r, glass.g, glass.b, 0.09), 2.0)
		draw_arc(centre, R * 0.62, 0.0, TAU, 48, Color(glass.r, glass.g, glass.b, 0.06), 1.5)
		# Leading springs from the stone's rim into the fan — five rays, none
		# horizontal, so no spoke drowns in the path line.
		for ray: int in range(5):
			var ra: float = deg_to_rad(-150.0 + float(ray) * 30.0)
			var to: Vector2 = centre + Vector2(cos(ra), sin(ra)) * R * 0.98
			var dir: Vector2 = (to - pos).normalized()
			draw_line(pos + dir * 46.0, to, Color(glass.r, glass.g, glass.b, 0.10), 1.5)

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
				# The host owns the bow so the marker gliding along this edge
				# cannot drift from the dashes drawn on it — see
				# `WorldMapScreen.edge_control` for why it is not written twice.
				var control: Vector2 = host.edge_control(from, to)
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
	## Hysteresis on the flip, in stage px. `_node_pos` adds
	## `_drift.n.x * PATH_DRIFT_AMP.x` to every stone's screen x, so a stone's
	## flip input sweeps 28 px as the pointer crosses the stage WITH NO PAN AT
	## ALL. Against a bare threshold that pops the pill 98 px across while the
	## player only moves the cursor (PR #80 DL R2). 32 > that 28 px sweep, with
	## margin; the cost of the band is a pill that keeps its side while it has up
	## to 32 px of room back, which reads as nothing.
	const FLIP_SLACK: float = 32.0

	## Last side chosen per stone index — the flip's only state, and the reason
	## `flips` can stay pure and asserted.
	var _flipped: Dictionary[int, bool] = {}

	func _init() -> void:
		super(1.0)
		gated = false

	## Whether the STONE is in frame. Culling on this is what stops the chip
	## outliving its lantern: the pill reaches ~49 stage px from the centre while
	## the stone's own ink reaches ~20, so without it there is a 29 px band at
	## each edge — 12% of a node step, both photographed — where the label is on
	## screen and the lantern is not, and a `+17` sits alone on the road. At the
	## right edge the flip made it worse, converting "nothing drawn" into a
	## truncated `+` with no referent (PR #80 DL R2 MAJOR).
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
	## The "nowhere to go" branch needs `frame_w < 2 · reach` — under ~100 px
	## against the narrowest shipped stage's 390 — so it cannot fire in the game
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
			# at phone-portrait two same-lane bounty stones sit 99.40 stage px
			# apart while their reaches sum to 110.42, so a flipped pill lands
			# 11.02 px inside the one already seated and its `+16` renders as
			# `+1` (#69 D1, PR #80 DL R3, photographed).
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
