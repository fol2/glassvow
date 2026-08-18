class_name StallLayout
extends RefCounted
## Where the Night Stall's goods sit on the painting, and how the painting is
## cropped so they are still there at every shape.
##
## Concept C1 (`docs/design/2026-08-14-ui-direction/README.md` § 4) makes the
## painted furniture the layout, and James's 2026-08-15 ruling on #242 fixes
## which furniture: phials STAND ON A SHELF (the canopy hooks are gone), relics
## stand on the counter, the quest offer stands under a bell jar at the
## counter's right end, and the stair is the way out. So a ware's position is a
## point on the IMAGE, not on the screen.
##
## EVERY NUMBER BELOW WAS MEASURED OFF THE PAINTING ITSELF, not off the mock.
## The landscape master James approved on 2026-08-15
## (`docs/art-ledger.md` › `scenes/night-stall.png`) is 1512x1040, and its
## furniture reads at these lines — column/row luminance profiles, not eyeball:
##
##   counter front lip   v = 0.7721  (y=803, dead straight from u 0.32 to 0.91)
##   counter top, far    v ~ 0.713   — the slab is 60px deep on screen
##   counter ends        u = 0.305 .. 0.930
##   shelf top face      v = 0.5250  (board top y=542, lit face peaks y=546)
##   shelf board         v = 0.5212 .. 0.5433, u = 0.5377 .. 0.885
##   merchant            u = 0.355 .. 0.475, hood crown v = 0.375
##   stair treads        u = 0.085 .. 0.31,  v = 0.555 .. 0.96
##   floor line          v ~ 0.963
##
## TWO RULES HOLD THE COMPOSITION, and both are one line each in `fit()`:
##
##   1. THE COUNTER IS THE HORIZON. The crop pivots on the counter's front lip
##      rather than on the image centre, so the lip lands at 77.21% of the frame
##      height at every aspect. That fraction is not chosen, it is measured, and
##      at the identity shape it is not even free: 1512x1040 cover-fitted into
##      1180x820 is height-driven, so the painting's own lip fraction IS the
##      frame's. It is what keeps the foreground rack's band (the 23% below it)
##      from collapsing on a wide phone.
##   2. THE CROP NEVER EATS MORE THAN THE SAFE BAND. Cover-fitting a 1.4538
##      image into a 0.45 portrait frame shows 31% of its width, which is not a
##      crop but a different painting. `fit()` therefore stops scaling up once
##      the visible width reaches `SAFE_BAND`, and lets the frame letterbox
##      instead. Every region below is inside that band, so every region is on
##      screen at every shape by construction — that is the property
##      `tests/test_stall_layout.gd` asserts, and the reason it can.
##
## SAFE_BAND is the intersection of what the two landscape acceptance ratios
## show: 4:3 (`pad-landscape` flexed to 1180x885) crops the width to
## 1180/1286.7 = 0.9171 and keeps every row; 20:9 (`phone-landscape` flexed to
## 867x390) keeps the full width and crops v to [0.2671, 0.9211]. Nothing
## load-bearing may be authored outside their overlap.
##
## Portrait is a second composition, not a crop of this one. James's 2026-08-15
## ruling still wants a per-aspect master; until that painting lands, `fit()`
## width-contains the stall at the top of the frame (canopy → shelf → counter)
## and `rack_band()` gives the floor below the lip to the cards. Letterboxing
## the landscape painting into a bottom strip is the thing that ruling retired.
##
## Pure by construction, like `StageShape`: no Node, no DisplayServer, every
## input an argument, so the whole matrix is drivable headlessly.

## The painting: the approved landscape master (#242 slice 3).
const BACKDROP: String = "res://assets/art/scenes/night-stall.png"
const IMAGE: Vector2 = Vector2(1512.0, 1040.0)

## The painted counter's front lip, in image space and in frame space. One
## number for both: rule 1 pins the second to the first.
const COUNTER_LINE: float = 0.7721

## The painted shelf's lit top face — where a phial's foot lands. The seat rows
## below are derived from it, so moving the shelf moves the phials.
const SHELF_LINE: float = 0.5250

## How far a phial's ware rect sinks past SHELF_LINE so the GLASS lands on the
## wood. The seven potion sprites carry 2.7%-8.2% of transparent floor under the
## flask (mean 5.4%; `energy.png` is the deepest at 21px of 256), which at a
## 181px ware is 9.8 image px of daylight between a flush rect and the board.
## Sinking by the family mean puts every phial's base within 5px of the paint,
## and the board is 23px thick, so all seven stand on it.
const PHIAL_SINK: float = 0.0094

## Where a ware's foot lands ON the counter, which is NOT the lip. The painted
## slab runs from v 0.7135 (far edge) to COUNTER_LINE, 60px of top face; a jar
## seated on the lip itself reads as balanced on the edge, so goods stand in the
## front third of the slab instead.
const COUNTER_SEAT: float = 0.7620

## The image window guaranteed visible from 4:3 through 20:9 — and, via rule 2,
## at every shape narrower than 4:3 as well.
const SAFE_BAND: Rect2 = Rect2(0.0415, 0.2672, 0.9170, 0.6538)

## Every scene-locked region, in image space: the box a ware and its tag own.
##
## THE SIZES ARE THE PAINTING'S, NOT THE UI'S (James's scale ruling). The two
## phials in `docs/design/2026-08-14-ui-direction/night-stall-2potions-reference.png`
## are the only measured scale datum in the room: 206 image px tall standing on
## the shelf, u 0.6521..0.6997 and 0.7255..0.7705, cork at v 0.3163, base on the
## shelf's lit line. (That file's own content sits 3.2% shorter than this
## master — the potion-removal pass rescaled it vertically — so its measured
## 199px reads 206px here, through `empty_y = potions_y * 1.0331 + 2.1`,
## correlation 0.994 over the whole frame; u needs no correction, the horizontal
## fit is 1.001.)
##
## The runtime cannot match that height, and the gap is a fact worth stating
## rather than rounding away. A painted bottle is slim (70 x 206, ratio 0.34); a
## potion sprite is a round-bellied flask whose ink is 68% of its square by
## width and 90% by height. Matched on height it would be 2.2x wider than the
## painted bottle, and two of them plus their tags would take the whole shelf,
## leaving no column for either relic or for the offer. So the phial column is
## 181px — a 163px flask, 79% of the reference — which is the widest the five
## tagged columns fit in across the counter's 0.306..0.958 with a gap between
## each. The relic seats then take the counter's left span (a 512x341 relic is
## capped at two thirds of its column, 111px) and the jar the right end past the
## shelf.
const REGIONS: Dictionary[StringName, Rect2] = {
	# The merchant's line, under the canopy hem and clear of the left phial's
	# column. Clamped below the HUD band at runtime — on a 20:9 frame the canopy
	# compresses to the top 7%.
	&"say": Rect2(0.2100, 0.3300, 0.3200, 0.0660),
	# The shelf. Two seats, because `Rewards.gen_shop` stocks exactly two
	# phials, and because the reference painting shows exactly two bottles.
	#
	# The column IS the phial: `ShopScreen._seat` gives a shelf seat a square
	# ware rect the width of its region, so `y` is SHELF_LINE plus PHIAL_SINK
	# minus that width in v (181px = 0.1745), and the phial's glass lands on the
	# painted board at every shape and in every locale. The tag then hangs under
	# the board, which is where a shelf label belongs and where the 20:9 crop
	# still shows it — above the shelf it would sit inside the HUD band
	# (measured: image v 0.2733 lands at frame y 3.7 of 390, under a 42px bar).
	&"shelf0": Rect2(0.5440, 0.3599, 0.1200, 0.3100),
	&"shelf1": Rect2(0.6730, 0.3599, 0.1200, 0.3100),
	# Relic stands on the counter, in front of the merchant, in the span the
	# shelf's phials do not overhang. Tag ABOVE, so the ware's foot lands on
	# COUNTER_SEAT. Relic art is 512x341, so a relic can never be taller than
	# two thirds of its column: the ware rect is authored at exactly that
	# height, and the sprite fills it rather than floating inside it.
	&"stand0": Rect2(0.3060, 0.5384, 0.1100, 0.2354),
	&"stand1": Rect2(0.4250, 0.5384, 0.1100, 0.2354),
	# The cold bell jar at the counter's right end — the one stretch of counter
	# the shelf does not stand over, which is why the offer reads as set apart
	# rather than as stock, and why the card rack stops at its left edge.
	#
	# It stands at the slab's FAR edge (0.7135) rather than at COUNTER_SEAT, and
	# that is what makes the column work at all. The offer carries the longest
	# sentence in the stall ("Cold glass. No wick. The merchant will not say who
	# left it."), so its tag runs half again the height of a phial's; seated at
	# the front of the slab, `0.7620 + 1.053 * tag` already passes the 20:9 crop
	# before the ware is given a single pixel. Set back, the same tag finishes
	# near 0.88 with room to spare — and the offer standing behind the
	# merchandise line is the fiction anyway. Its top stops at 0.59 so the glass
	# never covers the painted lantern hanging above it: two lanterns, one
	# apparently inside the jar, is the read to avoid.
	&"jar": Rect2(0.8020, 0.5900, 0.1400, 0.3057),
	# The way out, on the stair treads.
	&"stair": Rect2(0.1000, 0.6000, 0.1900, 0.0780),
}

## Phials take the shelf's seats left to right. Two seats, two phials.
const SHELF_SEATS: Array[StringName] = [&"shelf0", &"shelf1"]
const STANDS: Array[StringName] = [&"stand0", &"stand1"]

## A region's box is the ware PLUS its tag; this is which end the tag takes.
## Measured off the painting rather than chosen: a relic stands on the counter
## with the rack immediately below it, so its tag is tied upward, and
## `ShopScreen._seat` then pins its foot to the region's bottom edge whatever
## its rules text does. The shelf and the jar hang their tags down — the shelf
## because above it is the HUD band at 20:9, the jar because above it is a
## painted lantern — and the shelf pays for that with the square-ware rule in
## `_seat`, the jar with a few px of seat drift on the counter's 60px slab.
const TAG_ABOVE: Array[StringName] = [&"stand0", &"stand1"]

## The identity shape's own cover scale, 820/1040: height-driven, because
## 1180x820 is taller in proportion than the 1512x1040 painting.
const IDENTITY_SCALE: float = 820.0 / 1040.0
## Where type stops shrinking with the painting. Below this a tag is not a
## smaller tag, it is an unreadable one, so it grows past its region instead and
## `ShopScreen._seat` clamps it back into the frame. Portrait width-contain
## sits well below this floor, so tags stay readable on the small stall band.
const TYPE_FLOOR: float = 0.62

## The foreground rack is frame-locked, not scene-locked: it stands in front of
## the counter rather than on a painted feature, so it takes the band between
## the counter lip and the bottom edge and sizes its cards to fit.
const RACK_GAP: float = 0.018
const RACK_INSET: float = 0.15


## Image-to-frame transform: cover, pivoted on the counter lip, capped so the
## visible width never falls below SAFE_BAND's. Portrait is width-contain at
## the top of the frame — a stacked stall, not a cropped one.
static func fit(frame: Vector2) -> Transform2D:
	if is_portrait(frame):
		var scale: float = frame.x / IMAGE.x
		return Transform2D(0.0, Vector2(scale, scale), 0.0, Vector2.ZERO)
	var cover: float = maxf(frame.x / IMAGE.x, frame.y / IMAGE.y)
	var widest: float = frame.x / (IMAGE.x * SAFE_BAND.size.x)
	var scale: float = minf(cover, widest)
	var drawn: Vector2 = IMAGE * scale
	return Transform2D(0.0, Vector2(scale, scale), 0.0,
		(frame - drawn) * Vector2(0.5, COUNTER_LINE))


static func is_portrait(frame: Vector2) -> bool:
	return frame.y > frame.x


## How large type must be drawn at this frame, as a multiple of the sizes the
## mock was authored at.
##
## TYPE SCALES WITH THE PAINTING, NOT WITH THE WINDOW. Every ware sits in a
## region that cover-fitting has already scaled — at 20:9 the whole scene is
## drawn at 73% — so a tag held at its authored size overflows first its region
## and then the frame. That is the 20:9 overflow slice 1 left behind, and one
## factor off `fit()` is the whole of the fix. 1.0 at the identity shape by
## construction: `fit(1180x820)` returns exactly IDENTITY_SCALE.
static func type_scale(frame: Vector2) -> float:
	return maxf(fit(frame).get_scale().x / IDENTITY_SCALE, TYPE_FLOOR)


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


## The foreground band: below the counter lip. Landscape insets from the left
## and stops short of the bell jar so the two never share a column. Portrait
## already seats the jar on the stall band above, so the rack takes the full
## floor in two rows.
static func rack_band(frame: Vector2) -> Rect2:
	var gap: float = RACK_GAP * frame.y
	if is_portrait(frame):
		var box: Rect2 = canvas(frame)
		var top: float = box.position.y + COUNTER_LINE * box.size.y + gap
		var inset: float = frame.x * 0.04
		return Rect2(inset, top, maxf(0.0, frame.x - inset * 2.0),
			maxf(0.0, frame.y - gap - top))
	var top: float = COUNTER_LINE * frame.y + gap
	var left: float = RACK_INSET * frame.x
	var right: float = place(frame, &"jar").position.x - gap
	return Rect2(left, top, maxf(0.0, right - left), maxf(0.0, frame.y - gap - top))


## Which slice of the image this frame actually shows, in image space. The
## containment property every region must hold, and what the test measures.
static func visible_uv(frame: Vector2) -> Rect2:
	var box: Rect2 = canvas(frame)
	return Rect2(-box.position / box.size, frame / box.size)
