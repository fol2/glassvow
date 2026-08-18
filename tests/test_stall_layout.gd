extends RefCounted
## The Night Stall holds its landscape composition (#242).
##
## Three halves, which is one more than there should be. The first drives
## `StallLayout` as pure maths — every authored region inside the safe band,
## every placed region inside the frame, the counter lip on its line, and the
## identity shape still reproducing the signed mock's `object-fit: cover`
## numbers. The second builds the real `ShopScreen` at each frame and measures
## what it actually seated, tags included. The third drives the state grammar
## through `update()` and measures what it drew: a gap and a struck name for
## SOLD, a red number for unaffordable, spent shears after a removal.
##
## No `await`: nothing here is laid out by a container, so the geometry is a
## pure function of `size` and needs no frames. That is the point of placing
## against the painting rather than in a `VBoxContainer`, and it is why this
## can live in the discovered synchronous suite instead of beside
## `dawn_phone_containment.gd`.

## The window sizes the shipping landscape identities, resolved through the
## real shape pipeline rather than hardcoded: identity pad-landscape 1180×820,
## 4:3 iPad as flexed pad-landscape, phone-landscape's short 844×390 stage and
## its 20:9 flex, and desktop 16:9. Portrait identities are retired
## (`docs/design/2026-08-18-landscape-only.md`) and are not shipping windows.
const WINDOWS: Dictionary[StringName, Array] = {
	&"pad-landscape": [Vector2i(1180, 820), &"identity"],
	&"pad-landscape-4x3": [Vector2i(2048, 1536), &"pad-landscape"],
	&"phone-landscape": [Vector2i(844, 390), &"phone-landscape"],
	&"phone-landscape-20x9": [Vector2i(2400, 1080), &"phone-landscape"],
	&"desktop-16x9": [Vector2i(2560, 1440), &"desktop-landscape"],
}


static func run(fails: Array[String]) -> void:
	_authored_inside_safe_band(fails)
	# One stall, re-seated at each shape: that is the runtime path (`set_shape`
	# and `resized` both re-run `_relayout`), and it keeps the suite from
	# building six CardViews five times over.
	var content: ContentDB = ContentDB.load_slice()
	var stock: Dictionary = _stock(content)
	var offer: Dictionary = {
		"id": "flamelessLantern", "name": "A Lantern with No Flame", "price": 300,
	}
	var screen: ShopScreen = ShopScreen.new(stock, 100, content, offer, true)
	for label: StringName in WINDOWS:
		var row: Array = WINDOWS[label]
		var window: Vector2i = row[0]
		var reference: StringName = row[1]
		var shape: StringName = StageShape.IDENTITY if reference == &"identity" \
			else reference
		var frame: Vector2 = Vector2(StageShape.stage_size(shape, window))
		_fit_holds(fails, label, frame)
		screen.size = frame
		screen.set_shape(shape)
		_screen_holds(fails, label, screen, frame)
	_state_grammar(fails, screen, stock, offer)
	screen.free()
	# Slice 5: longer zh-Hant tags are what break a label. Build a new
	# ShopScreen after the switch — tags bake locale at construct time.
	_zh_screen_holds(fails, content, stock, offer)


## zh-Hant tags bake at construct time, so a new ShopScreen is required. Always
## restore Locale.active and the ContentDB overlay, including on early return.
static func _zh_screen_holds(fails: Array[String], content: ContentDB,
		stock: Dictionary, offer: Dictionary) -> void:
	var previous: Locale = Locale.active
	Locale.active = Locale.new(Locale.CODE_ZH_HANT)
	Locale.active.hydrate_content(content)
	var zh_screen: ShopScreen = ShopScreen.new(stock, 100, content, offer, true)
	for label: StringName in [&"pad-landscape", &"phone-landscape"]:
		var row: Array = WINDOWS[label]
		var window: Vector2i = row[0]
		var reference: StringName = row[1]
		var shape: StringName = StageShape.IDENTITY if reference == &"identity" \
			else reference
		var frame: Vector2 = Vector2(StageShape.stage_size(shape, window))
		zh_screen.size = frame
		zh_screen.set_shape(shape)
		_screen_holds(fails, StringName("zh-%s" % label), zh_screen, frame)
	zh_screen.free()
	Locale.active.restore_content()
	Locale.active = previous


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
	# of another size silently moves all of them. Slice 3 overwrote this file
	# once already; this is the line that stops the next one doing so quietly.
	var painting: Texture2D = load(StallLayout.BACKDROP) as Texture2D
	_check(fails, painting != null
		and Vector2(painting.get_size()) == StallLayout.IMAGE,
		"the painting at %s is not %s" % [StallLayout.BACKDROP, StallLayout.IMAGE])
	# The approved master, cover-fitted into 1180x820: 1512x1040 is taller in
	# proportion than the frame, so the fit is height-driven and the painting
	# overhangs 6.08px each side.
	var identity: Rect2 = StallLayout.canvas(Vector2(1180.0, 820.0))
	_check(fails, identity.position.distance_to(Vector2(-6.0769, 0.0)) < 0.1
		and absf(identity.size.x - 1192.1538) < 0.1 and absf(identity.size.y - 820.0) < 0.1,
		"identity shape no longer reproduces the master's cover fit: %s" % identity)
	# Type is measured at the identity shape, so the factor there must be 1.0 or
	# every size in `WareTag` has quietly stopped meaning what the mock says.
	_check(fails, absf(StallLayout.type_scale(Vector2(1180.0, 820.0)) - 1.0) < 0.001,
		"identity type scale is not 1.0: %f" % StallLayout.type_scale(Vector2(1180.0, 820.0)))
	_check(fails, StallLayout.type_scale(Vector2(867.0, 390.0)) < 0.85,
		"20:9 no longer shrinks type with the painting: %f"
			% StallLayout.type_scale(Vector2(867.0, 390.0)))


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


static func _screen_holds(fails: Array[String], label: StringName,
		screen: ShopScreen, frame: Vector2) -> void:
	var view: Rect2 = Rect2(Vector2.ZERO, frame)
	for entry: Dictionary in screen._slots:
		var control: Control = entry["control"]
		var card: CardView = control as CardView
		var rect: Rect2 = ShopScreen.card_rect(card) if card != null \
			else Rect2(control.position, control.size)
		var tag: WareTag = entry["tag"]
		var tag_rect: Rect2 = Rect2(tag.position, tag.size)
		_check(fails, rect.size.x > 0.0 and rect.size.y > 0.0 and view.encloses(rect),
			"%s ware %s/%d escapes the frame %s: %s" % [
				label, entry["kind"], entry["index"], frame, rect])
		# The tag is what the type scale is for: at 20:9 an unscaled tag is
		# wider and taller than its region and leaves the frame with it.
		_check(fails, tag_rect.size.x > 0.0 and tag_rect.size.y > 0.0
			and view.encloses(tag_rect),
			"%s tag for %s/%d escapes the frame %s: %s" % [
				label, entry["kind"], entry["index"], frame, tag_rect])
		# What is DRAWN, not what was set: a non-wrapping row shrinks to fit,
		# but below MIN_PX it can still run past the block.
		for row: Dictionary in tag._rows:
			var run_w: float = float(str(row["run"]))
			_check(fails, run_w <= tag.size.x + 0.5,
				"%s tag row for %s/%d draws past its block: %.1f > %.1f (%s)" % [
					label, entry["kind"], entry["index"],
					run_w, tag.size.x, str(row["text"]).left(24)])
	_seated_on_the_painting(fails, label, screen, frame)
	_rack_is_one_row(fails, label, screen)
	var jar: Rect2 = Rect2(screen._jar.position, screen._jar.size)
	_check(fails, jar.size.x > 0.0 and jar.size.y > 0.0 and view.encloses(jar),
		"%s the bell jar is unseated: %s in %s" % [label, jar, frame])
	var leave: Rect2 = Rect2(screen._leave.position, screen._leave.size)
	_check(fails, view.encloses(leave) and leave.size.y >= 44.0,
		"%s the stair is not a reachable way out: %s in %s" % [label, leave, frame])
	_check(fails, screen._say.position.y >= screen._hud_band(),
		"%s the merchant's line runs under the HUD band: %.1f" % [
			label, screen._say.position.y])


## James's scale ruling (#242, 2026-08-15): a ware sits in the painting's own
## perspective, on the furniture it rests on — never floating at UI scale. Which
## makes it a measurable property, not a taste one: every phial's foot lands on
## the painted shelf board and every relic's on the painted counter slab, at
## every shipping landscape shape.
##
## Both feet are EXACT by construction, so the tolerance is a hairline rather
## than a budget: a relic's tag is above it and `_seat` pins a tag-above foot to
## the region's bottom edge; a phial's ware rect is its own column, square, so
## its foot is the region's top plus that width. Neither moves when rules text
## wraps differently — which is the whole point, and was measured failing at
## 20px before the square-ware rule landed. Two image px is the assertion.
const SEAT_TOL: float = 0.002


## Landscape ships one rack row. A two-row restack was the retired portrait
## interim; phone-landscape's short 844×390 stage must scale, not restack.
static func _rack_is_one_row(fails: Array[String], label: StringName,
		screen: ShopScreen) -> void:
	var tops: Array[float] = []
	for entry: Dictionary in screen._rack:
		var control: Control = entry["control"]
		var card: CardView = control as CardView
		var rect: Rect2 = ShopScreen.card_rect(card) if card != null \
			else Rect2(control.position, control.size)
		tops.append(rect.position.y)
	if tops.size() < 2:
		return
	var spread: float = tops.max() - tops.min()
	_check(fails, spread < 8.0,
		"%s rack is not a single row (y-spread %.1f): %s" % [label, spread, tops])


static func _seated_on_the_painting(fails: Array[String], label: StringName,
		screen: ShopScreen, frame: Vector2) -> void:
	var canvas: Rect2 = StallLayout.canvas(frame)
	for entry: Dictionary in screen._slots:
		var region: StringName = entry["region"]
		var seat: float = 0.0
		var surface: String = ""
		if StallLayout.SHELF_SEATS.has(region):
			seat = StallLayout.SHELF_LINE + StallLayout.PHIAL_SINK
			surface = "the shelf board"
		elif StallLayout.STANDS.has(region):
			seat = StallLayout.COUNTER_SEAT
			surface = "the counter slab"
		else:
			continue
		var control: Control = entry["control"]
		var foot: float = (control.position.y + control.size.y
			- canvas.position.y) / canvas.size.y
		_check(fails, absf(foot - seat) <= SEAT_TOL,
			"%s %s is not standing on %s: foot at v=%.4f, wanted %.4f" % [
				label, region, surface, foot, seat])


## What the tag DREW, not what it was told: `_rows` is the list `_draw` walks,
## and its last row is the price chip or the state word that replaced it.
static func _last_row(tag: WareTag) -> Dictionary:
	return {} if tag._rows.is_empty() else tag._rows[tag._rows.size() - 1]


static func _price_ink(tag: WareTag) -> Color:
	var ink: Color = _last_row(tag).get("colour", Color.WHITE)
	return ink


static func _price_text(tag: WareTag) -> String:
	return str(_last_row(tag).get("text", ""))


static func _slot(screen: ShopScreen, kind: String) -> Dictionary:
	for entry: Dictionary in screen._slots:
		if str(entry["kind"]) == kind:
			return entry
	return {}


## The state grammar of #242 slice 2, measured at the identity shape.
static func _state_grammar(fails: Array[String], screen: ShopScreen,
		stock: Dictionary, offer: Dictionary) -> void:
	screen.size = Vector2(1180.0, 820.0)
	screen.set_shape(StageShape.IDENTITY)
	var card: Dictionary = _slot(screen, "card")
	var relic: Dictionary = _slot(screen, "misc")
	var removal: Dictionary = _slot(screen, "removal")

	# Unaffordable: the ware stays exactly where it is, and one number turns red.
	var relic_tag: WareTag = relic["tag"]
	var relic_ware: Control = relic["control"]
	var was: Rect2 = Rect2(relic_ware.position, relic_ware.size)
	screen.update(stock, 10, offer, true)
	_check(fails, relic_ware.visible
		and Rect2(relic_ware.position, relic_ware.size).is_equal_approx(was),
		"an unaffordable ware moved or vanished: %s was %s" % [
			Rect2(relic_ware.position, relic_ware.size), was])
	_check(fails, _price_ink(relic_tag) == RunStyle.DANGER,
		"an unaffordable price is not drawn in DANGER: %s" % _price_ink(relic_tag))
	screen.update(stock, 400, offer, true)
	_check(fails, _price_ink(relic_tag) == RunStyle.GOLD,
		"an affordable price is not drawn in GOLD: %s" % _price_ink(relic_tag))

	# SOLD: the ware is not there at all, and its tag keeps the struck name.
	var cards: Array = stock["cards"]
	var first: Dictionary = cards[0]
	first["sold"] = true
	screen.update(stock, 400, offer, true)
	var card_tag: WareTag = card["tag"]
	var card_ware: Control = card["control"]
	var name_row: Dictionary = {} if card_tag._rows.is_empty() else card_tag._rows[0]
	var struck: bool = name_row.get("strike", false)
	var struck_name: String = str(name_row.get("text", ""))
	_check(fails, not card_ware.visible and card_tag.visible,
		"a sold ware left no gap, or took its tag with it")
	_check(fails, struck and not struck_name.is_empty(),
		"a sold ware's name is not struck through: %s" % name_row)
	_check(fails, _price_text(card_tag) == Locale.active.t("ui.shop.sold"),
		"a sold ware does not say so where its price was: %s" % _price_text(card_tag))
	_check(fails, Rect2(Vector2.ZERO, screen.size).encloses(
		Rect2(card_tag.position, card_tag.size)),
		"a sold ware's tag left the frame: %s" % Rect2(card_tag.position, card_tag.size))
	first["sold"] = false

	# The shears deactivate once used, and say which state they are in.
	stock["removed"] = true
	screen.update(stock, 400, offer, true)
	var shears: Button = removal["control"]
	var removal_tag: WareTag = removal["tag"]
	var deactivated: bool = removal["disabled"]
	_check(fails, shears.disabled and deactivated,
		"card removal is still live after use")
	_check(fails, _price_text(removal_tag) == Locale.active.t("ui.shop.removalSpent"),
		"spent shears do not read as spent: %s" % _price_text(removal_tag))
	stock["removed"] = false
	screen.update(stock, 400, offer, true)
	_check(fails, not shears.disabled,
		"card removal did not come back when the stock said it should")


static func _stock(content: ContentDB) -> Dictionary:
	var cards: Array = []
	for id: Variant in content.cards.keys().slice(0, 5):
		cards.append({"id": str(id), "price": 60, "sold": false})
	var relics: Array = []
	for id: Variant in content.relics.keys().slice(0, 2):
		relics.append({"id": str(id), "price": 150, "sold": false})
	var potions: Array = []
	for id: Variant in content.potions.keys().slice(0, 2):
		potions.append({"id": str(id), "price": 55, "sold": false})
	return {"cards": cards, "relics": relics, "potions": potions, "removeCost": 75}
