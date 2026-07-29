extends RefCounted
## The stage shape picker and its flex, driven over the real device matrix.
##
## Two invariants carry the rest. The IDENTITY gate — `pad-landscape` against a
## 1180x820 window must resolve to exactly 1180x820 — is what keeps every ported
## benchmark number meaningful, because all of them were measured in that shape.
## The no-shrink invariant is what keeps the flex safe: a stage may only grow
## from its reference, so no authored composition is ever cropped to fit.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_stage_shape: %s" % what)


## width/height of a size, guarded the same way the class guards it.
static func _aspect(v: Vector2i) -> float:
	return float(maxi(1, v.x)) / float(maxi(1, v.y))


static func run(fails: Array[String]) -> void:
	_identity(fails)
	_classes(fails)
	_matrix(fails)
	_flex(fails)


# ---------------------------------------------------------------- identity

## The one gate that is not about shapes at all: it is about whether the parity
## method still holds. If this fails, every `file:line` number the port carries
## from the benchmark has silently stopped describing what is on screen.
static func _identity(fails: Array[String]) -> void:
	var pad: Vector2i = Vector2i(1180, 820)
	_check(fails, StageShape.REFERENCES[StageShape.IDENTITY] == pad,
		"pad-landscape is 1180x820")
	_check(fails, StageShape.stage_size(StageShape.IDENTITY, pad) == pad,
		"a 1180x820 window on pad-landscape flexes to exactly 1180x820")
	_check(fails, absf(StageShape.flex_of(StageShape.IDENTITY, pad)) < 0.0001,
		"…and reports zero flex doing it")
	_check(fails, StageShape.REFERENCES.size() == 5, "five authored references")
	for shape: StringName in StageShape.REFERENCES:
		var ref: Vector2i = StageShape.REFERENCES[shape]
		_check(fails, StageShape.stage_size(shape, ref) == ref,
			"%s at its own size is unflexed" % shape)


# ---------------------------------------------------------------- classes

static func _classes(fails: Array[String]) -> void:
	# A desktop window manager decides it, whatever the panel measures — this is
	# the branch Steam Deck takes, and it takes it as an ordinary Linux machine.
	for os_name: String in ["Windows", "macOS", "Linux"]:
		_check(fails, StageShape.class_for(os_name, 7.0) == StageShape.CLASS_DESKTOP,
			"%s is a desktop regardless of panel size" % os_name)
	_check(fails, StageShape.class_for("iOS", 6.1) == StageShape.CLASS_PHONE,
		"a 6.1\" iPhone is a phone")
	_check(fails, StageShape.class_for("iOS", 11.0) == StageShape.CLASS_PAD,
		"an 11\" iPad is a pad")
	_check(fails, StageShape.class_for("iOS", 8.3) == StageShape.CLASS_PAD,
		"the 8.3\" iPad mini lands on the pad side of the 7\" split")
	_check(fails, StageShape.class_for("Android", 6.7) == StageShape.CLASS_PHONE,
		"a 6.7\" Android phone is a phone")
	_check(fails, StageShape.class_for("Android", 11.0) == StageShape.CLASS_PAD,
		"an 11\" Android tablet is a pad")
	_check(fails, StageShape.class_for("Web", 0.0) == StageShape.CLASS_DESKTOP,
		"an unmeasurable diagonal falls back to the roomiest composition")


# ---------------------------------------------------------------- matrix

## Every row is a shipping device, in the orientation named. `class` is what
## `class_for` would have returned for it.
static func _matrix(fails: Array[String]) -> void:
	var rows: Array[Array] = [
		# desktop class — the pad references are in play here too, which is the
		# benchmark's own choice: a desktop window gets the pad experience until
		# it is closer to 16:9 than to the iPad frame (`src/stage.js:48-51`).
		["1920x1080 desktop", Vector2i(1920, 1080), StageShape.CLASS_DESKTOP, &"desktop-landscape"],
		["2560x1440 desktop", Vector2i(2560, 1440), StageShape.CLASS_DESKTOP, &"desktop-landscape"],
		["3440x1440 ultrawide", Vector2i(3440, 1440), StageShape.CLASS_DESKTOP, &"desktop-landscape"],
		# 1280x800 is 1.6000 and the pad/desktop boundary is 1.59958. The Deck
		# sits 0.03% past it. Pinned here so the answer is a decision on record
		# rather than whatever the arithmetic happened to do that day.
		["Steam Deck 1280x800", Vector2i(1280, 800), StageShape.CLASS_DESKTOP, &"desktop-landscape"],
		["1920x1200 16:10", Vector2i(1920, 1200), StageShape.CLASS_DESKTOP, &"desktop-landscape"],
		# …and every MacBook falls the OTHER side of that boundary, onto the iPad
		# composition. 16:10.4 is not 16:10.
		["MacBook Pro 14", Vector2i(3024, 1964), StageShape.CLASS_DESKTOP, &"pad-landscape"],
		["MacBook Air 13", Vector2i(2560, 1664), StageShape.CLASS_DESKTOP, &"pad-landscape"],
		["Surface 3:2", Vector2i(2880, 1920), StageShape.CLASS_DESKTOP, &"pad-landscape"],
		["desktop window, portrait", Vector2i(1200, 1920), StageShape.CLASS_DESKTOP, &"pad-portrait"],

		# pad class
		["iPad Air landscape", Vector2i(2360, 1640), StageShape.CLASS_PAD, &"pad-landscape"],
		["iPad Air portrait", Vector2i(1640, 2360), StageShape.CLASS_PAD, &"pad-portrait"],
		["iPad 4:3 landscape", Vector2i(2048, 1536), StageShape.CLASS_PAD, &"pad-landscape"],
		["iPad 4:3 portrait", Vector2i(1536, 2048), StageShape.CLASS_PAD, &"pad-portrait"],
		["Galaxy Tab S9 landscape", Vector2i(2560, 1600), StageShape.CLASS_PAD, &"pad-landscape"],
		["Galaxy Tab S9 portrait", Vector2i(1600, 2560), StageShape.CLASS_PAD, &"pad-portrait"],

		# phone class — note the SE. Its landscape aspect is 1.7787, which is
		# desktop-landscape to four decimal places, and it must NOT get it.
		["iPhone 17 portrait", Vector2i(1179, 2556), StageShape.CLASS_PHONE, &"phone-portrait"],
		["iPhone 17 landscape", Vector2i(2556, 1179), StageShape.CLASS_PHONE, &"phone-landscape"],
		["iPhone SE landscape", Vector2i(1334, 750), StageShape.CLASS_PHONE, &"phone-landscape"],
		["Pixel 9 portrait", Vector2i(1080, 2424), StageShape.CLASS_PHONE, &"phone-portrait"],
		["Galaxy S24U portrait", Vector2i(1440, 3120), StageShape.CLASS_PHONE, &"phone-portrait"],
	]
	for row: Array in rows:
		var label: String = row[0]
		var window: Vector2i = row[1]
		var device_class: StringName = row[2]
		var want: StringName = row[3]
		var got: StringName = StageShape.pick(window, device_class)
		_check(fails, got == want, "%s picks %s (got %s)" % [label, want, got])

	# `?shape=` (`src/stage.js:33`) — the forced override every parity
	# measurement is taken through, and it must beat the device class.
	_check(fails, StageShape.pick(Vector2i(1179, 2556), StageShape.CLASS_PHONE,
		&"desktop-landscape") == &"desktop-landscape",
		"a forced shape overrides the picker")
	_check(fails, StageShape.pick(Vector2i(1920, 1080), StageShape.CLASS_DESKTOP,
		&"not-a-shape") == &"desktop-landscape",
		"an unknown forced name is ignored rather than obeyed")


# ---------------------------------------------------------------- flex

static func _flex(fails: Array[String]) -> void:
	var windows: Array[Vector2i] = [
		Vector2i(1920, 1080), Vector2i(1280, 800), Vector2i(3024, 1964),
		Vector2i(2048, 1536), Vector2i(1640, 2360), Vector2i(1179, 2556),
		Vector2i(2556, 1179), Vector2i(3440, 1440), Vector2i(3840, 1080),
	]
	# No-shrink: the flex may only ADD stage px. If this ever fails, a
	# composition somewhere is being cropped rather than spread.
	for shape: StringName in StageShape.REFERENCES:
		var ref: Vector2i = StageShape.REFERENCES[shape]
		for window: Vector2i in windows:
			var size: Vector2i = StageShape.stage_size(shape, window)
			_check(fails, size.x >= ref.x and size.y >= ref.y,
				"%s never shrinks below its reference at %dx%d"
					% [shape, window.x, window.y])

	# Inside the cap the flexed stage matches the window's aspect, which is what
	# makes `aspect="keep"` produce no bars without ever being told to expand.
	var fitted: Array[Array] = [
		["16:9 desktop", Vector2i(1920, 1080), &"desktop-landscape"],
		["Steam Deck", Vector2i(1280, 800), &"desktop-landscape"],
		["MacBook Pro 14", Vector2i(3024, 1964), &"pad-landscape"],
		["iPad 4:3", Vector2i(2048, 1536), &"pad-landscape"],
		["16:10 tablet portrait", Vector2i(1600, 2560), &"pad-portrait"],
		["Pixel 9 portrait", Vector2i(1080, 2424), &"phone-portrait"],
		# Google Play wants a landscape game full screen at 21:9. That anchor is
		# an Android PHONE held sideways, and it is met: 2.333 against
		# phone-landscape's 2.164 is 7.8%. A desktop 21:9 MONITOR is a different
		# case with a different answer — see the clamp block below.
		["21:9 Android phone", Vector2i(2520, 1080), &"phone-landscape"],
	]
	for row: Array in fitted:
		var label: String = row[0]
		var window: Vector2i = row[1]
		var shape: StringName = row[2]
		_check(fails, absf(StageShape.flex_of(shape, window)) <= StageShape.FLEX_CAP,
			"%s needs no more than the cap" % label)
		var size: Vector2i = StageShape.stage_size(shape, window)
		_check(fails, absf(_aspect(size) - _aspect(window)) < 0.005,
			"%s fills the window with no bars" % label)

	# A desktop ultrawide is the case the class restriction decides against, and
	# deliberately. `phone-landscape` (2.164) is the nearest reference to 21:9 by
	# aspect, but handing a 34" monitor a 844x390 composition would be absurd, so
	# the desktop class never offers it and the monitor pillarboxes instead —
	# which is what nearly every shipping game does at 21:9, and what Steam
	# accepts. The Google Play 21:9 anchor is met on the device it governs, an
	# Android phone, in the fitted block above.
	var ultrawide: Vector2i = Vector2i(3440, 1440)
	_check(fails, StageShape.pick(ultrawide, StageShape.CLASS_DESKTOP) == &"desktop-landscape",
		"a 21:9 monitor stays on desktop-landscape rather than reaching for a phone")
	_check(fails, StageShape.flex_of(&"desktop-landscape", ultrawide) > StageShape.FLEX_CAP,
		"…and wants more flex than the cap allows, so it pillarboxes")

	# …past the cap the stage stops moving and lets `keep` bar the rest. 32:9 is
	# the extreme of the same case: it would want 64% and does not get it.
	var wide: Vector2i = Vector2i(3840, 1080)
	_check(fails, StageShape.flex_of(&"desktop-landscape", wide) > StageShape.FLEX_CAP,
		"a 32:9 monitor wants more flex than the cap allows")
	var capped: Vector2i = StageShape.stage_size(&"desktop-landscape", wide)
	_check(fails, absf(_aspect(capped) - _aspect(wide)) > 0.05,
		"…so it letterboxes instead of stretching to meet it")
	_check(fails, absf(_aspect(capped) / StageShape.aspect_of(&"desktop-landscape")
			- (1.0 + StageShape.FLEX_CAP)) < 0.005,
		"…having stretched exactly to the cap and stopped")

	# The SE is the phone-side version of the same clamp: 1.7787 against a
	# 2.1641 reference is 17.8% and does not fit either.
	var se: Vector2i = Vector2i(1334, 750)
	_check(fails, absf(StageShape.flex_of(&"phone-landscape", se)) > StageShape.FLEX_CAP,
		"an iPhone SE in landscape exceeds the cap against phone-landscape")
