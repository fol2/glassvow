class_name StallLayout
extends RefCounted
## Where the Night Stall's goods sit on the painting, and how the painting is
## cropped so they are still there at every shape.
##
## Concept C1 (`docs/design/2026-08-14-ui-direction/README.md` § 4) makes the
## painted furniture the layout: phials on the canopy hooks, relics on the
## counter, the quest under a bell jar on the right ledge, the stair as the way
## out. So a ware's position is a point on the IMAGE, not on the screen, and
## every number below was measured off the signed mock `shop-c1.html` at its
## 1180x820 canvas and converted into the image's own 0..1 space. At the
## identity shape this class reproduces that canvas exactly — `fit()` returns
## scale 0.74545 and origin (-6.36, 0), which is what `object-fit: cover;
## object-position: 50% 50%` computes for 1600x1100 into 1180x820.
##
## TWO RULES HOLD THE COMPOSITION, and both are one line each in `fit()`:
##
##   1. THE COUNTER IS THE HORIZON. The crop pivots on the counter's front lip
##      rather than on the image centre, so the lip lands at 70.73% of the frame
##      height at every aspect. That fraction is not chosen, it is measured: it
##      is where the lip already sits at the identity shape. It is what keeps
##      the foreground rack's band (the 29% below it) from collapsing on a wide
##      phone — a centred crop puts the lip at 82% of a 20:9 frame and leaves
##      70px for the cards.
##   2. THE CROP NEVER EATS MORE THAN THE SAFE BAND. Cover-fitting a 1.4545
##      image into a 0.45 portrait frame shows 31% of its width, which is not a
##      crop but a different painting. `fit()` therefore stops scaling up once
##      the visible width reaches `SAFE_BAND`, and lets the frame letterbox
##      instead. Every region below is inside that band, so every region is on
##      screen at every shape by construction — that is the property
##      `tests/test_stall_layout.gd` asserts, and the reason it can.
##
## SAFE_BAND is the intersection of what the two acceptance ratios show:
## 4:3 (`pad-landscape` flexed to 1180x885) crops the width to
## 1180/1287.3 = 0.9166 and keeps every row; 20:9 (`phone-landscape` flexed to
## 867x390) keeps the full width and crops v to [0.2445, 0.8988]. Nothing
## load-bearing may be authored outside their overlap.
##
## Pure by construction, like `StageShape`: no Node, no DisplayServer, every
## input an argument, so the whole matrix is drivable headlessly.

## The painting. Today it is the concept-grade master copied verbatim from the
## design record (`docs/art-ledger.md` › `scenes/night-stall.png`); slice 3
## overwrites this same path with the production render and must keep its
## contract: 1600x1100, counter lip at v=0.7073, nothing load-bearing outside
## SAFE_BAND.
const BACKDROP: String = "res://assets/art/scenes/night-stall.png"
const IMAGE: Vector2 = Vector2(1600.0, 1100.0)

## The painted counter's front lip, in image space and in frame space. One
## number for both: rule 1 pins the second to the first.
const COUNTER_LINE: float = 0.7073

## The image window guaranteed visible from 4:3 through 20:9 — and, via rule 2,
## at every shape narrower than 4:3 as well.
const SAFE_BAND: Rect2 = Rect2(0.0417, 0.2445, 0.9166, 0.6543)

## Every scene-locked region, in image space: the box a ware and its tag own.
## Measured off `shop-c1.html`; see the class docstring for the conversion.
const REGIONS: Dictionary[StringName, Rect2] = {
	# The merchant's line, under the canopy. Clamped below the HUD band at
	# runtime — on a 20:9 frame the canopy compresses to the top 7%.
	&"say": Rect2(0.2535, 0.2537, 0.4008, 0.0659),
	# Canopy hooks. Staggered in v because the tags are wider than the 80px
	# hook spacing; HOOK_ORDER keeps two wares on the outer pair, which is the
	# only arrangement in which no two tags share a column.
	&"hook0": Rect2(0.5788, 0.4146, 0.1191, 0.1951),
	&"hook1": Rect2(0.6518, 0.4098, 0.1207, 0.2134),
	&"hook2": Rect2(0.7146, 0.4098, 0.1191, 0.2268),
	# Relic stands on the counter, either side of the merchant's hood.
	&"stand0": Rect2(0.3005, 0.5488, 0.1358, 0.1622),
	&"stand1": Rect2(0.4497, 0.5049, 0.1174, 0.2024),
	# The cold bell jar on the right ledge. Pulled 24px left of the mock so its
	# right edge clears the 4:3 crop with room to spare.
	&"jar": Rect2(0.8085, 0.5378, 0.1341, 0.3037),
	# The way out, on the stair treads.
	&"stair": Rect2(0.0707, 0.5927, 0.1979, 0.0780),
}

## Wares take the outer hooks first. See the REGIONS comment.
const HOOK_ORDER: Array[StringName] = [&"hook0", &"hook2", &"hook1"]
const STANDS: Array[StringName] = [&"stand0", &"stand1"]

## The foreground rack is frame-locked, not scene-locked: it stands in front of
## the counter rather than on a painted feature, so it takes the band between
## the counter lip and the bottom edge and sizes its cards to fit.
const RACK_GAP: float = 0.018
const RACK_INSET: float = 0.15


## Image-to-frame transform: cover, pivoted on the counter lip, capped so the
## visible width never falls below SAFE_BAND's.
static func fit(frame: Vector2) -> Transform2D:
	var cover: float = maxf(frame.x / IMAGE.x, frame.y / IMAGE.y)
	var widest: float = frame.x / (IMAGE.x * SAFE_BAND.size.x)
	var scale: float = minf(cover, widest)
	var drawn: Vector2 = IMAGE * scale
	return Transform2D(0.0, Vector2(scale, scale), 0.0,
		(frame - drawn) * Vector2(0.5, COUNTER_LINE))


## Where the painting itself is drawn.
static func canvas(frame: Vector2) -> Rect2:
	var xform: Transform2D = fit(frame)
	return Rect2(xform.origin, IMAGE * xform.get_scale())


## A named region's box, in frame pixels.
static func place(frame: Vector2, region: StringName) -> Rect2:
	var box: Rect2 = REGIONS.get(region, Rect2())
	var xform: Transform2D = fit(frame)
	var scale: Vector2 = xform.get_scale()
	return Rect2(xform.origin + box.position * IMAGE * scale,
		box.size * IMAGE * scale)


## The foreground band: below the counter lip, inset from the left, stopping
## short of the bell jar's ledge so the two never share a column.
static func rack_band(frame: Vector2) -> Rect2:
	var gap: float = RACK_GAP * frame.y
	var top: float = COUNTER_LINE * frame.y + gap
	var left: float = RACK_INSET * frame.x
	var right: float = place(frame, &"jar").position.x - gap
	return Rect2(left, top, maxf(0.0, right - left), maxf(0.0, frame.y - gap - top))


## Which slice of the image this frame actually shows, in image space. The
## containment property every region must hold, and what the test measures.
static func visible_uv(frame: Vector2) -> Rect2:
	var box: Rect2 = canvas(frame)
	return Rect2(-box.position / box.size, frame / box.size)
