extends RefCounted
## The Night Stall holds its composition at every shape (#242 slice 1).
##
## Pure-maths half (#242 PR 1 of 2): every authored region inside the safe
## band, every placed region inside the frame, the counter lip on its line,
## and the identity shape still reproducing the signed mock's
## `object-fit: cover` numbers. The screen half — building the real
## `ShopScreen` at each frame and measuring what it seated — lands with the
## screen rebuild in the next PR.
##
## No `await`: nothing here is laid out by a container, so the geometry is a
## pure function of `size` and needs no frames. That is the point of placing
## against the painting rather than in a `VBoxContainer`, and it is why this
## can live in the discovered synchronous suite instead of beside
## `dawn_phone_containment.gd`.

## The window sizes the acceptance names, resolved through the real shape
## pipeline rather than hardcoded: a 4:3 iPad, a 20:9 phone held either way,
## and the two landscape references either side of them.
const WINDOWS: Dictionary[StringName, Array] = {
	&"pad-landscape": [Vector2i(1180, 820), &"identity"],
	&"pad-landscape-4x3": [Vector2i(2048, 1536), &"pad-landscape"],
	&"phone-landscape-20x9": [Vector2i(2400, 1080), &"phone-landscape"],
	&"phone-portrait-9x20": [Vector2i(1080, 2400), &"phone-portrait"],
	&"desktop-16x9": [Vector2i(2560, 1440), &"desktop-landscape"],
}


static func run(fails: Array[String]) -> void:
	_authored_inside_safe_band(fails)
	for label: StringName in WINDOWS:
		var row: Array = WINDOWS[label]
		var window: Vector2i = row[0]
		var reference: StringName = row[1]
		var shape: StringName = StageShape.IDENTITY if reference == &"identity" \
			else reference
		var frame: Vector2 = Vector2(StageShape.stage_size(shape, window))
		_fit_holds(fails, label, frame)


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_stall_layout: %s" % what)


## Authoring rule: a region outside the safe band is a region that leaves the
## screen at one of the two acceptance ratios. Caught here, not on a device.
static func _authored_inside_safe_band(fails: Array[String]) -> void:
	for region: StringName in StallLayout.REGIONS:
		var box: Rect2 = StallLayout.REGIONS[region]
		_check(fails, StallLayout.SAFE_BAND.encloses(box),
			"region %s is authored outside the safe band %s: %s" % [
				region, StallLayout.SAFE_BAND, box])
	# Every anchor above is a fraction OF THIS IMAGE, so a replacement painting
	# of another size silently moves all of them. Slice 3 overwrites this file;
	# this is the line that stops it doing so quietly.
	var painting: Texture2D = load(StallLayout.BACKDROP) as Texture2D
	_check(fails, painting != null
		and Vector2(painting.get_size()) == StallLayout.IMAGE,
		"the painting at %s is not %s" % [StallLayout.BACKDROP, StallLayout.IMAGE])
	# The mock this was measured from: 1600x1100 cover-fitted into 1180x820.
	var identity: Rect2 = StallLayout.canvas(Vector2(1180.0, 820.0))
	_check(fails, identity.position.distance_to(Vector2(-6.36, 0.0)) < 0.1
		and absf(identity.size.x - 1192.73) < 0.1 and absf(identity.size.y - 820.0) < 0.1,
		"identity shape no longer reproduces the mock canvas: %s" % identity)


static func _fit_holds(fails: Array[String], label: StringName, frame: Vector2) -> void:
	var view: Rect2 = Rect2(Vector2.ZERO, frame)
	for region: StringName in StallLayout.REGIONS:
		var box: Rect2 = StallLayout.place(frame, region)
		_check(fails, view.encloses(box),
			"%s region %s escapes the frame %s: %s" % [label, region, frame, box])
	var canvas: Rect2 = StallLayout.canvas(frame)
	var lip: float = canvas.position.y + StallLayout.COUNTER_LINE * canvas.size.y
	_check(fails, absf(lip - StallLayout.COUNTER_LINE * frame.y) < 0.5,
		"%s counter lip left its line: %.1f, wanted %.1f" % [
			label, lip, StallLayout.COUNTER_LINE * frame.y])
	_check(fails, canvas.size.x >= frame.x - 0.5,
		"%s leaves a gap beside the painting: %s in %s" % [label, canvas, frame])
	var band: Rect2 = StallLayout.rack_band(frame)
	_check(fails, band.size.x > 0.0 and band.size.y > 0.0 and view.encloses(band)
		and band.position.y > lip,
		"%s rack band is not a usable strip below the lip: %s" % [label, band])


