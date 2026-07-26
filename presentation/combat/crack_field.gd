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
	_dirty = true


## Composite strands into the field. Additive by construction — each texel keeps the
## MINIMUM normalised distance it has seen — so this is incremental: a strike composites
## only its own new strands and never re-walks the network. That is also what makes
## `reveal(t)` cheap later (§5.1): composite the next segment, no rebuild.
##
## Takes the same `Array[Dictionary]` shape `FractureField.strike` returns, so the
## caller can hand the renderer and the net the same value.
func add(strands: Array) -> void:
	var t0: int = Time.get_ticks_usec()
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
		_stroke(_simplify(pts), tip)
		var origin: Vector2 = d.get("origin", pts[0])
		_glint(origin)
	_bake_us += Time.get_ticks_usec() - t0
	_dirty = true


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


## One strand. Walks segment by segment and touches only the texels inside each
## segment's own expanded box, so the work is the groove's area rather than the field's.
func _stroke(pts: PackedVector2Array, tip: float) -> void:
	var total: float = CrackNet.arc_length(pts)
	if total <= 0.0:
		return
	# Opening displacement goes as √(a − s) (§5.4), so the half-width is a square root
	# of the remaining arc — rescaled so it ends at `tip` rather than always at zero.
	var span: float = 1.0 - tip * tip
	var run: float = 0.0
	var pad: int = int(ceilf(APERTURE * REACH * float(RES))) + 2
	for i: int in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg: float = a.distance_to(b)
		if seg <= 0.0:
			continue
		# Widths at the two ends, then LERPED across the segment rather than rooted per
		# texel. The taper is smooth and a segment is a few texels long, so the
		# difference is invisible and it saves a sqrt in the inner loop.
		var wa: float = APERTURE * sqrt(maxf(0.0, 1.0 - span * (run / total)))
		var wb: float = APERTURE * sqrt(maxf(0.0, 1.0 - span * ((run + seg) / total)))
		run += seg
		if wa <= 0.0 and wb <= 0.0:
			continue
		var lo_x: int = clampi(int(floorf(minf(a.x, b.x) * float(RES))) - pad, 0, RES - 1)
		var hi_x: int = clampi(int(ceilf(maxf(a.x, b.x) * float(RES))) + pad, 0, RES - 1)
		var lo_y: int = clampi(int(floorf(minf(a.y, b.y) * float(RES))) - pad, 0, RES - 1)
		var hi_y: int = clampi(int(ceilf(maxf(a.y, b.y) * float(RES))) + pad, 0, RES - 1)
		var ab: Vector2 = b - a
		var len2: float = ab.length_squared()
		for y: int in range(lo_y, hi_y + 1):
			var row: int = y * RES
			for x: int in range(lo_x, hi_x + 1):
				var p: Vector2 = Vector2(
					(float(x) + 0.5) / float(RES), (float(y) + 0.5) / float(RES))
				# Projection parameter, clamped: gives the distance to the SEGMENT and
				# the position along it for the width, from one dot product.
				var t: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
				var w: float = wa + (wb - wa) * t
				if w <= 0.0:
					continue
				var d: float = p.distance_to(a + ab * t)
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
