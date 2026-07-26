class_name CrackField
extends RefCounted
## The crack network as a distance field, for `BODY_SHADER` to read.
##
## **One concept — distance to the network — with three consumers**: the standing
## groove, the ignite bloom and the marked preview. One structure, three jobs, no extra
## node and no extra draw call (`docs/fracture-model.md` §5.1). It writes an
## `ImageTexture` handed to `_body_mat` as `crack_tex`, sampled alongside the existing
## luma-derived normal.
##
## ### Why a distance field and not drawn lines
##
## Godot could rasterise three concentric `Line2D`s per strand on the GPU for free and
## it would match `crackSvg` exactly. It was rejected for one reason: **the gradient of
## a distance field IS the groove's cross-section normal.** A V-groove is read off its
## lit lip — that is this project's standing rule
## (`docs/solutions/design-patterns/procedural-glass-reads-off-its-edges.md`) and §5.5
## calls the lip the whole signal. Drawn bands give colour and no normal; a distance
## field gives the normal for the price of two extra texture taps, and it antialiases
## itself, which is why §5.2 records that `CrackField` survives a forced drop to MSAA
## 2× where an extruded ribbon does not.
##
## ### What is stored
##
## `RG8`. **R** is the distance to the network, normalised by the groove's own local
## half-width and clamped: 0 at the crack centre, 1 at the outer lip and beyond. The
## taper is therefore baked in, which is what lets one threshold in the shader serve a
## groove whose width varies along its length. **G** is the glint at each impact point.
##
## Normalising in here rather than in the shader is deliberate: the width law needs
## `arc` and `terminus`, which are model data, and pushing them into the shader would
## mean shipping a per-strand uniform array.
##
## Lives in `presentation/combat/` and NOT in `fracture/`. It names `Image` and it is
## optics, and the purity gate over `fracture/` is what keeps the model testable
## against invariants. `body_mask.gd` is the model's one `Image` exception and it stays
## the only one.

## Field resolution. The cost is O(crack length × groove width) in texels, so this
## squares the rasterise time — measured at 256 and left there deliberately.
##
## The honest limit: at 256 the outer lip sits ~1.9 texels from the crack centre, so
## the OUTER contour is crisp (the field is locally linear out there and interpolation
## between samples is exact) while the innermost contour is soft, because `|d|` has a
## crease at the centre that linear filtering rounds off. That is acceptable and
## slightly desirable — the inner band is the hot core and only ever shows under
## `ignite` or `marked`, where a soft glow is what is wanted. Raise this to 512 if the
## core ever has to read cold.
const RES: int = 256

## The outer band's half-width at the origin, in body fractions.
##
## From the reference's own authored figure, `../roguecardv2-benchmark/src/art.js`
## (`crackSvg`): three concentric strokes over a 200-unit viewBox at 2.9 / 1.35 / 0.7
## px. The widest is therefore 0.0145 body across, so 0.00725 to a side. The band
## RATIOS live in the shader, because they are thresholds on what this file stores.
##
## Clears the derived floor in `docs/fracture-model.md` §3 — a groove must be ≥ 0.0065
## body wide to survive sampling at the smallest actor — by 2.2×.
const APERTURE: float = 0.00725

## How far out the field is stored, in multiples of the local half-width.
##
## Storing only as far as the outer lip and clamping there LOOKS like the obvious
## choice and breaks the bands. Two adjacent texels straddling a groove this narrow
## would read 0.3 and 1.0-because-clamped when the true value was 1.4, so the linear
## interpolation between them — which is the entire reason a distance field can resolve
## a contour finer than its own texels — would be interpolating a lie. Stored out to
## three half-widths there are five texels of honest linear ramp either side and the
## contours land where they should.
const REACH: float = 3.0

## The three band thresholds, in stored units, and the single source of truth for them
## — `EnemyView` hands this to `BODY_SHADER` as one `vec3` rather than the shader
## carrying its own copy of numbers derived from `REACH`.
##
## The RATIOS are the reference's authored figure (2.9 / 1.35 / 0.7 over a 200-unit
## viewBox); the division by `REACH` is what converts them into this field's units.
const BANDS: Vector3 = Vector3(1.0 / REACH, (1.35 / 2.9) / REACH, (0.7 / 2.9) / REACH)

## How wide the glint is around an impact point, in body fractions.
const GLINT_R: float = 0.022

## Where a strand's groove ends up, as a fraction of `APERTURE`, per terminus. §5.4:
## an `F` must taper to literally nothing or it reads as a *cut* rather than as a
## fracture that ran out of stress; a `T` met another crack and has real width where it
## arrived; an `S` is clipped by the silhouette anyway.
const TIP_FREE: float = 0.0
const TIP_CRACK: float = 0.5
const TIP_EDGE: float = 0.55

## Simplification tolerance, body fractions. The integrator emits a vertex every
## `FractureField.STEP` = 0.012 body, which is far finer than the optics need: the
## rasteriser's cost is per segment box, and consecutive boxes on a dense polyline
## overlap almost entirely, so most of the work would be redundant. At 0.0025 — a third
## of a groove half-width — a gently curved arm keeps five or six vertices instead of
## twenty-five and no displacement is visible.
const SIMPLIFY: float = 0.0025

const NONE: int = 255

var _px: PackedByteArray = PackedByteArray()
var _tex: ImageTexture = null
var _dirty: bool = true
var _bake_us: int = 0

## The reveal in flight: strands prepared once, rasterised in arc windows as the front
## advances. Two parallel typed arrays rather than the `Array[Dictionary]` the model emits,
## because the simplification and the terminus lookup are done ONCE here and re-doing them
## per frame is the whole cost the incremental path exists to avoid.
var _pend_pts: Array[PackedVector2Array] = []
var _pend_tip: PackedFloat32Array = PackedFloat32Array()
var _front: float = 0.0
var _span: float = 0.0


func _init() -> void:
	clear()


## Every texel to "no crack", both channels. Called at construction and by
## `reset_glass()`, so a rebuilt vessel starts unmarked.
func clear() -> void:
	_px.resize(RES * RES * 2)
	# R = NONE (outside every groove), G = 0 (no glint).
	for i: int in range(RES * RES):
		_px[i * 2] = NONE
		_px[i * 2 + 1] = 0
	_drop_pending()
	_dirty = true


## Composite strands into the field, whole and at once. Additive by construction — each
## texel keeps the MINIMUM normalised distance it has seen — so this is incremental: a
## strike composites only its own new strands and never re-walks the network.
##
## Takes the same `Array[Dictionary]` shape `FractureField.strike` returns, so the
## caller can hand the renderer and the net the same value.
##
## `begin`/`reveal` below is the animated door to the same rasteriser, and this is the
## immediate one — for the rite, which has no time to run a front, and for `rebuild`.
func add(strands: Array) -> void:
	var t0: int = Time.get_ticks_usec()
	var pts: Array[PackedVector2Array] = []
	var tips: PackedFloat32Array = PackedFloat32Array()
	_prepare(strands, pts, tips)
	for i: int in range(pts.size()):
		_stroke(pts[i], tips[i], 0.0, INF)
	_bake_us += Time.get_ticks_usec() - t0
	_dirty = true


# ------------------------------------------------------------------- the reveal

## Start revealing `strands` rather than compositing them whole, and return the arc length
## of the LONGEST of them in body units — the caller runs a front from 0 to that.
##
## This is `reveal(t)` of `docs/fracture-model.md` §5, and the seam is the point of it:
## **the model has no clock.** It emits a finished strand and the renderer walks a front
## along it, which is `CONCEPTS.md` › *Angle, not time* applied where it belongs. The
## animation cannot desync from the geometry because there is only one geometry.
##
## The glints are laid IMMEDIATELY, not revealed. The glint is the impact mark, so it
## belongs at t = 0 — the blow point flashes and the arms then run out of it, which is both
## the order the physics happens in and the order that reads.
##
## Any reveal still in flight is finished first. Blows arrive on separate combat beats, so
## overlapping stars is a case that does not occur; if it ever does, snapping the older one
## to complete is the behaviour that cannot lose geometry.
func begin(strands: Array) -> float:
	finish()
	_pend_pts = []
	_pend_tip = PackedFloat32Array()
	_prepare(strands, _pend_pts, _pend_tip)
	_front = 0.0
	_span = 0.0
	for p: PackedVector2Array in _pend_pts:
		_span = maxf(_span, CrackNet.arc_length(p))
	if _span <= 0.0:
		_drop_pending()
	return _span


## Advance the front to `arc`, an arc length in body units measured from each strand's own
## origin. Monotone — the field is min-composited and a texel cannot be un-written, so a
## front that retreated would leave the groove it had already drawn.
##
## The argument is an ARC LENGTH and not the normalised `t` §5 names, and that is the
## physical statement: a crack front runs at a fixed fraction of the shear wave speed and
## does not know how long its own arm will turn out to be. Normalising would have a short
## arm crawl while a long one sprinted, which is the one thing about this animation an eye
## would actually catch.
func reveal(arc: float) -> void:
	if _pend_pts.is_empty() or arc <= _front:
		return
	var t0: int = Time.get_ticks_usec()
	var to: float = minf(arc, _span)
	for i: int in range(_pend_pts.size()):
		_stroke(_pend_pts[i], _pend_tip[i], _front, to)
	_bake_us += Time.get_ticks_usec() - t0
	_front = to
	_dirty = true
	if _front >= _span:
		_drop_pending()


## Snap a reveal in flight to complete. The rite calls this before it carves: the carve
## reads the NET, which has been whole since the blow landed, so a half-drawn field would
## throw shards along cracks the player was never shown.
func finish() -> void:
	if _pend_pts.is_empty():
		return
	reveal(_span)


func growing() -> bool:
	return not _pend_pts.is_empty()


func _drop_pending() -> void:
	_pend_pts = []
	_pend_tip = PackedFloat32Array()
	_front = 0.0
	_span = 0.0


## The model's emission shape into two typed arrays, simplified and with the terminus
## resolved to a tip width — plus the glints, which are laid here because they are not
## revealed (see `begin`).
func _prepare(strands: Array, out_pts: Array[PackedVector2Array],
		out_tip: PackedFloat32Array) -> void:
	for s: Variant in strands:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = s
		var pts: PackedVector2Array = d.get("points", PackedVector2Array())
		if pts.size() < 2:
			continue
		var term: StringName = d.get("terminus", CrackNet.T_FREE)
		var tip: float = TIP_FREE
		if term == CrackNet.T_CRACK:
			tip = TIP_CRACK
		elif term == CrackNet.T_SILHOUETTE:
			tip = TIP_EDGE
		out_pts.append(_simplify(pts))
		out_tip.append(tip)
		var origin: Vector2 = d.get("origin", pts[0])
		_glint(origin)


## Texel-for-texel equality against another field. Public for the same reason `Carve.area`
## is: the one invariant a reveal needs — that growing a groove in windows is byte-identical
## to compositing it at once — cannot be computed from outside without it, and an invariant
## that cannot be computed from outside is not an invariant (`tools/check_fracture.gd`).
##
## An exact comparison rather than a hash, because a hash of a 128 KB buffer would be
## reporting a collision-free claim it has not earned and the buffers are right here.
func same_as(other: CrackField) -> bool:
	return _px == other._px


## Rebuild from a whole net. Only for a caller that has a net and no record of what
## was committed when — the incremental path is the normal one.
func rebuild(net: CrackNet) -> void:
	clear()
	var all: Array[Dictionary] = []
	for i: int in range(net.strand_count()):
		all.append({
			"points": net.strand(i),
			"terminus": net.terminus(i),
			"origin": net.origin(i),
		})
	_bake_us = 0
	add(all)


func is_empty() -> bool:
	return _tex == null and _dirty


## Microseconds spent rasterising since the last `rebuild`/`clear`. Reported rather
## than estimated because `docs/fracture-model.md` §7 prices this row and an unmeasured
## row in a cost table reads as though it were known.
func bake_usec() -> int:
	return _bake_us


## The texture, uploaded lazily so a burst of strikes in one frame pays one upload.
func texture() -> ImageTexture:
	if _dirty:
		var img: Image = Image.create_from_data(RES, RES, false, Image.FORMAT_RG8, _px)
		if _tex == null:
			_tex = ImageTexture.create_from_image(img)
		else:
			_tex.update(img)
		_dirty = false
	return _tex


# --------------------------------------------------------------- the rasteriser

## Douglas–Peucker. Recursion replaced by an explicit stack: a 130-vertex strand would
## otherwise nest 130 deep in the worst case, and GDScript's recursion is not free.
static func _simplify(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var keep: PackedByteArray = PackedByteArray()
	keep.resize(pts.size())
	keep[0] = 1
	keep[pts.size() - 1] = 1
	var stack: Array[Vector2i] = [Vector2i(0, pts.size() - 1)]
	while not stack.is_empty():
		var span: Vector2i = stack.pop_back()
		var worst: float = -1.0
		var at: int = -1
		for i: int in range(span.x + 1, span.y):
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(
				pts[i], pts[span.x], pts[span.y])
			var e: float = q.distance_to(pts[i])
			if e > worst:
				worst = e
				at = i
		if at > 0 and worst > SIMPLIFY:
			keep[at] = 1
			stack.append(Vector2i(span.x, at))
			stack.append(Vector2i(at, span.y))
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(pts.size()):
		if keep[i] == 1:
			out.append(pts[i])
	return out


## One strand, or the slice of it between two arc lengths. Walks segment by segment and
## touches only the texels inside each segment's own expanded box, so the work is the
## groove's area rather than the field's.
##
## `lo`/`hi` are arc lengths in body units and exist for the reveal. **The width law stays
## bound to the strand's FULL length**, which is the load-bearing line in this function: a
## window that measured its own length instead would taper to the tip value at the growing
## front and leave a permanent pinch at every frame boundary — invisible during a 0.12 s
## animation and there for the rest of the fight. `_check_field_reveal` pins it.
func _stroke(pts: PackedVector2Array, tip: float, lo: float, hi: float) -> void:
	var total: float = CrackNet.arc_length(pts)
	if total <= 0.0 or hi <= lo:
		return
	# Opening displacement goes as √(a − s) (§5.4), so the half-width is a square root
	# of the remaining arc — rescaled so it ends at `tip` rather than always at zero.
	var span: float = 1.0 - tip * tip
	var run: float = 0.0
	var pad: int = int(ceilf(APERTURE * REACH * float(RES))) + 2
	for i: int in range(pts.size() - 1):
		var full: Vector2 = pts[i + 1] - pts[i]
		var seg: float = full.length()
		if seg <= 0.0:
			continue
		var start: float = run
		run += seg
		# Wholly behind the window, or wholly ahead of it. Ahead ends the walk: arc only
		# increases, so no later segment can be inside either.
		if run <= lo:
			continue
		if start >= hi:
			break
		var t_lo: float = clampf((lo - start) / seg, 0.0, 1.0)
		var t_hi: float = clampf((hi - start) / seg, 0.0, 1.0)
		# Only the BOX is clipped to the window. Everything the value depends on is measured
		# against the whole segment below, which is what makes the reveal lossless.
		var a: Vector2 = pts[i] + full * t_lo
		var b: Vector2 = pts[i] + full * t_hi
		# Widths at the SEGMENT's two ends, then LERPED across it rather than rooted per
		# texel. The taper is smooth and a segment is a few texels long, so the difference
		# is invisible and it saves a sqrt in the inner loop.
		#
		# The ends are the segment's and NOT the window's, and that is the load-bearing
		# detail. Anchoring the lerp to the window instead is the obvious reading of "draw
		# this slice", it is what the first version did, and it fails: the true law is a
		# square root, so lerping between two interior samples is a FINER approximation than
		# lerping between the segment's ends. The slice would then be slightly wider than
		# the same slice drawn whole — a reveal that quietly re-cut its own groove, caught
		# by `_check_field_reveal` on the first run.
		var wa: float = APERTURE * sqrt(maxf(0.0, 1.0 - span * (start / total)))
		var wb: float = APERTURE * sqrt(maxf(0.0, 1.0 - span * (run / total)))
		if wa <= 0.0 and wb <= 0.0:
			continue
		var lo_x: int = clampi(int(floorf(minf(a.x, b.x) * float(RES))) - pad, 0, RES - 1)
		var hi_x: int = clampi(int(ceilf(maxf(a.x, b.x) * float(RES))) + pad, 0, RES - 1)
		var lo_y: int = clampi(int(floorf(minf(a.y, b.y) * float(RES))) - pad, 0, RES - 1)
		var hi_y: int = clampi(int(ceilf(maxf(a.y, b.y) * float(RES))) + pad, 0, RES - 1)
		var len2: float = full.length_squared()
		for y: int in range(lo_y, hi_y + 1):
			var row: int = y * RES
			for x: int in range(lo_x, hi_x + 1):
				var p: Vector2 = Vector2(
					(float(x) + 0.5) / float(RES), (float(y) + 0.5) / float(RES))
				# ONE projection, two consumers. The WIDTH reads it against the whole
				# segment, so the taper cannot depend on where a window boundary fell. The
				# DISTANCE reads it clamped INTO the window, which is exactly projecting
				# onto the slice — a slice shares its segment's line, so clamping the
				# parameter is the whole difference.
				#
				# A texel whose projection lands outside the window therefore measures to
				# the window's end and over-states its distance. That is correct and not a
				# tolerance: the window holding its projection writes the true value, and
				# the field keeps the minimum.
				var t: float = clampf((p - pts[i]).dot(full) / len2, 0.0, 1.0)
				var w: float = wa + (wb - wa) * t
				if w <= 0.0:
					continue
				var d: float = p.distance_to(pts[i] + full * clampf(t, t_lo, t_hi))
				var r: float = d / (w * REACH)
				if r >= 1.0:
					continue
				var at: int = (row + x) * 2
				var q: int = int(r * 255.0)
				if q < _px[at]:
					_px[at] = q


## The glint at an impact point — `crackSvg`'s brightest single mark. Stored in G and
## left for the shader to spend: cold it sharpens the specular, hot it emits (§5.3
## allows only the innermost band to emit, and only under `ignite` or `marked`).
func _glint(at: Vector2) -> void:
	var pad: int = int(ceilf(GLINT_R * float(RES))) + 1
	var cx: int = int(at.x * float(RES))
	var cy: int = int(at.y * float(RES))
	for y: int in range(maxi(cy - pad, 0), mini(cy + pad, RES - 1) + 1):
		var row: int = y * RES
		for x: int in range(maxi(cx - pad, 0), mini(cx + pad, RES - 1) + 1):
			var p: Vector2 = Vector2(
				(float(x) + 0.5) / float(RES), (float(y) + 0.5) / float(RES))
			var f: float = 1.0 - clampf(p.distance_to(at) / GLINT_R, 0.0, 1.0)
			# Cubed: a glint is a point, not a patch, and a linear falloff over 5 texels
			# reads as a smudge.
			var q: int = int(f * f * f * 255.0)
			var idx: int = (row + x) * 2 + 1
			if q > _px[idx]:
				_px[idx] = q
