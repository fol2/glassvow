class_name BodyMask
extends RefCounted
## Where the creature actually is. The one file in `fracture/` allowed to name
## `Image`, so that everything else in the module is testable against a rectangle
## and the purity gate has exactly one exception (`docs/fracture-model.md` §2.1).
##
## Two questions, and the second is the one that matters:
##
##   solid(p)      is there body at this point
##   reaches(a, b) is there body ALL THE WAY from a to b
##
## `reaches` exists because a crack cannot cross a void. Several paintings in this
## roster are tendrilled or holed, and sampling alpha at the step endpoint alone
## lets a tip commit half a step into the gap between two tendrils and carry on as
## if the glass were continuous. The old standing web had no mask at all, so a
## crack could hang off the silhouette into empty air
## (`docs/glass-crack-rendering.md` §3.3).
##
## Coordinates are body UV, y down, 0..1 — the same space `body_tex` is sampled in.


## Matches the threshold the death path already culls on (`_touches_art`), so the
## mask and the shatter agree about where the creature ends.
const SOLID_A: float = 0.08

var _img: Image = null
var _w: int = 0
var _h: int = 0
var _threshold: float = SOLID_A


## No image means a rectangle: everything inside 0..1 is body. This is the shape a
## test uses, and it is also the honest fallback for a creature whose painting has
## not decoded yet — better a crack that runs to the box edge than one that arrests
## on the first sample because the alpha read as zero.
static func rect() -> BodyMask:
	return BodyMask.new()


static func from_image(img: Image, threshold: float = SOLID_A) -> BodyMask:
	var m: BodyMask = BodyMask.new()
	if img != null and img.get_width() > 0 and img.get_height() > 0:
		m._img = img
		m._w = img.get_width()
		m._h = img.get_height()
		m._threshold = threshold
	return m


func solid(p: Vector2) -> bool:
	if p.x < 0.0 or p.x > 1.0 or p.y < 0.0 or p.y > 1.0:
		return false
	if _img == null:
		return true
	var x: int = clampi(int(p.x * float(_w)), 0, _w - 1)
	var y: int = clampi(int(p.y * float(_h)), 0, _h - 1)
	return _img.get_pixel(x, y).a > _threshold


## Sampled at roughly one texel per step, so a gap narrower than a texel is the
## only one that can be missed — and a gap that narrow is not a gap in the art.
## Capped because a crack that has run most of the way across a 2048px painting
## would otherwise cost two thousand reads on one arrest test, in the inner loop of
## the propagator.
const MAX_PROBES: int = 64


func reaches(a: Vector2, b: Vector2) -> bool:
	if not solid(a) or not solid(b):
		return false
	if _img == null:
		return true
	# Texel-scaled: the number of probes tracks how far the step actually crosses
	# the painting, not how long it is in UV, so a wide creature is not sampled more
	# coarsely than a narrow one.
	var span: Vector2 = b - a
	var texels: float = maxf(absf(span.x) * float(_w), absf(span.y) * float(_h))
	var n: int = clampi(int(ceilf(texels)), 1, MAX_PROBES)
	for i: int in range(1, n):
		if not solid(a + span * (float(i) / float(n))):
			return false
	return true
