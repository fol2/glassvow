class_name StageShape
extends RefCounted
## Which virtual stage this window gets, and how far it may stretch to fill it.
##
## The benchmark rendered at one of five authored sizes and scaled uniformly into
## the real window, letterboxed like a console title (`src/stage.js:1-4`). This
## port pinned ONE of them — `pad-landscape`, 1180x820 — into `project.godot`,
## which is why `application/main.gd`'s `--vp=` comment says in as many words
## that nothing reflows. Portrait sizes were a second product and are gone.
##
## The authored sizes are kept verbatim from `src/stage.js:20-26`, names
## included: every document in this repo already cites them, and
## `pad-landscape` is the shape every ported number was measured in. It must
## stay pixel-exact. Portrait names are not in this table.
##
## WHAT IS NOT PORTED, and why. The benchmark picks a shape from `innerWidth /
## innerHeight` against geometric-mean splits, with a `matchMedia('(pointer:
## coarse)')` branch (`src/stage.js:27-52`). Two changes here:
##
##   1. A geometric-mean split IS the minimum-log-distance boundary, so the same
##      rule is expressed directly as "nearest reference in log-aspect space".
##      Same answers, no thresholds to keep in sync when a reference moves.
##   2. The touch branch is dropped. Godot cannot answer that question:
##      `DisplayServer.is_touchscreen_available()` returns true on Windows
##      machines with no touchscreen (godot#84235) and `has_touchscreen_ui_hint()`
##      returned FALSE on a Steam Deck (godot#68518). Device class comes from the
##      platform name and the physical diagonal instead, which are knowable.
##
## THE FLEX. A fixed shape means bars on anything that is not one of the
## shipping references, and Google Play's adaptive quality guidelines want a
## landscape game full screen at 4:3, 16:10 and 21:9 — none of which those
## three hit. So a shape is a design REFERENCE, not a fixed frame: the stage
## stretches along one axis to meet the window, up to FLEX_CAP, and only then
## gives up and letterboxes.
##
## The stretch is expressed as a SIZE, never as a stretch mode. `content_scale_
## aspect` stays `keep` in `project.godot`; when the flexed size matches the
## window's aspect, `keep` has nothing to letterbox and produces no bars on its
## own. Past the cap the size stops moving and `keep` bars the remainder. One
## mechanism, and the cap comes free.
##
## Pure by construction: no `DisplayServer`, no `OS`, no Node. Every input is an
## argument, so `tests/test_stage_shape.gd` can drive every device in the matrix
## headlessly.

## Authored sizes (`src/stage.js:20-26`). Three ship. Portrait names are gone
## from this table; `pick` and `--shape=` never selected them after slice 1.
## Insertion order is the order `pick` considers CANDIDATES, and GDScript
## dictionaries preserve it, so a tie is resolved by this listing rather
## than by hash order.
const REFERENCES: Dictionary[StringName, Vector2i] = {
	&"pad-landscape": Vector2i(1180, 820),
	&"desktop-landscape": Vector2i(1458, 820),  # 1458/820 = 16:9
	&"phone-landscape": Vector2i(844, 390),
}

## Names `--shape=` / `pick(..., forced)` may honour. Retired names are
## ignored the same way an unknown name is.
const SHIPPING: Array[StringName] = [
	&"pad-landscape", &"desktop-landscape", &"phone-landscape",
]

## The identity shape. Every benchmark number this port carries was measured at
## 1180x820, and `CONCEPTS.md` rests the whole parity method on that being 1:1
## with the reference build. `stage_size` must return it EXACTLY at this shape
## and this window, or the parity method has quietly stopped being true.
const IDENTITY: StringName = &"pad-landscape"

const CLASS_PHONE: StringName = &"phone"
const CLASS_PAD: StringName = &"pad"
const CLASS_DESKTOP: StringName = &"desktop"

## Which references each device class may be given. A phone never gets the pad
## composition even when its aspect is closer to one — a 4.7" screen showing the
## iPad layout is the failure the benchmark's touch branch existed to prevent,
## and dropping that branch must not drop its purpose. Portrait names are not
## candidates: a taller-than-wide window gets that class's landscape shape.
const CANDIDATES: Dictionary[StringName, Array] = {
	CLASS_PHONE: [&"phone-landscape"],
	CLASS_PAD: [&"pad-landscape"],
	CLASS_DESKTOP: [&"pad-landscape", &"desktop-landscape"],
}

## How far a stage may stretch from its reference before it stops and lets the
## window letterbox instead. Keep 0.12: the remaining landscape worst cases
## already sit inside it (iPad 4:3 landscape against `pad-landscape`; 21:9
## Android phone against `phone-landscape` at 7.8%). The old 10.1% tablet-
## portrait justification is dead; do not retune the cap in this slice.
const FLEX_CAP: float = 0.12

## Diagonal inches below which a touch device is a phone rather than a tablet.
## The conventional split, and it puts the 8.3" iPad mini on the pad side where
## its layout belongs.
const PAD_MIN_INCHES: float = 7.0
## …and above which a touch-capable machine is really a desktop. A 13" 2-in-1
## has a desktop's pointer and a desktop's window manager.
const DESKTOP_MIN_INCHES: float = 13.0

## Platform names `OS.get_name()` returns for machines with a desktop window
## manager. Listed rather than inferred, because the answer for anything not
## here is decided by physical size instead.
const DESKTOP_PLATFORMS: PackedStringArray = [
	"Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD",
]


## The device class for a platform. `os_name` is `OS.get_name()`; `diagonal` is
## the screen diagonal in inches, or 0 when it cannot be measured.
##
## Steam Deck deliberately lands here as `desktop` via "Linux", and that is the
## whole of its special handling. Its 1280x800 panel is 1.6000 — the geometric
## midpoint of `pad-landscape` (1.439) and `desktop-landscape` (1.778) is
## 1.59958, so the Deck sits 0.03% from the boundary and no rule can resolve it.
## Under flex the question stops mattering: it is `desktop-landscape` squeezed
## 10%, with no bars, and Steam Deck Verified accepts letterboxing anyway.
static func class_for(os_name: String, diagonal: float) -> StringName:
	if DESKTOP_PLATFORMS.has(os_name):
		return CLASS_DESKTOP
	if diagonal <= 0.0:
		return CLASS_DESKTOP  # unmeasurable: assume the roomiest composition
	if diagonal < PAD_MIN_INCHES:
		return CLASS_PHONE
	if diagonal < DESKTOP_MIN_INCHES:
		return CLASS_PAD
	return CLASS_DESKTOP


## A reference's aspect, exactly as authored: width over height. Shipping
## references are all landscape (above 1).
static func aspect_of(shape: StringName) -> float:
	var ref: Vector2i = REFERENCES.get(shape, REFERENCES[IDENTITY])
	return float(ref.x) / float(maxi(1, ref.y))


## The reference this window should be composed against.
##
## `forced` short-circuits everything when it names a shipping reference — the
## port of `?shape=` (`src/stage.js:33`), which is how every parity measurement
## is taken and therefore not a debug nicety. A retired or unknown name is
## ignored rather than obeyed.
static func pick(window: Vector2i, device_class: StringName,
		forced: StringName = &"") -> StringName:
	if SHIPPING.has(forced):
		return forced
	var candidates: Array = CANDIDATES.get(device_class, CANDIDATES[CLASS_DESKTOP])
	var want: float = float(maxi(1, window.x)) / float(maxi(1, window.y))
	var best: StringName = IDENTITY
	var best_distance: float = INF
	for name: Variant in candidates:
		var shape: StringName = name
		# Log space, so "20% wider" and "20% narrower" are the same distance.
		# A geometric-mean split is exactly the midpoint of this measure, which
		# is why the benchmark's thresholds do not need porting alongside it.
		var distance: float = absf(log(want / aspect_of(shape)))
		if distance < best_distance:
			best_distance = distance
			best = shape
	return best


## How far this shape must stretch to meet this window, as a signed fraction
## before clamping: +0.11 means the window is 11% wider than the reference.
## Readout for the layout editor, and the number the cap is applied to.
static func flex_of(shape: StringName, window: Vector2i) -> float:
	var want: float = float(maxi(1, window.x)) / float(maxi(1, window.y))
	return want / aspect_of(shape) - 1.0


## The stage size to hand to `Window.content_scale_size`.
##
## The stage only ever GROWS from its reference — never shrinks — so no authored
## composition is cropped by the flex. A window that is relatively wider adds
## stage width; a relatively taller one adds stage height. Inside the cap the
## result matches the window's aspect exactly and `keep` draws no bars; outside
## it, the size stops at the cap and `keep` letterboxes what is left.
static func stage_size(shape: StringName, window: Vector2i) -> Vector2i:
	var ref: Vector2i = REFERENCES.get(shape, REFERENCES[IDENTITY])
	var ratio: float = clampf(flex_of(shape, window) + 1.0,
		1.0 - FLEX_CAP, 1.0 + FLEX_CAP)
	if ratio >= 1.0:
		return Vector2i(int(roundf(float(ref.x) * ratio)), ref.y)
	return Vector2i(ref.x, int(roundf(float(ref.y) / ratio)))
