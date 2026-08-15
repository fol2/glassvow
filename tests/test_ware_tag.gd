extends RefCounted
## WareTag / BellJar land dark in #242 slice 2a — this is their direct check.
## The screen wiring (and the five-shape sweep that measures seated geometry)
## arrives with slice 2b; here the contract is the row list `reflow` builds,
## because `_draw` walks the same list and cannot disagree with it.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_ware_tag: %s" % what)


static func run(fails: Array[String]) -> void:
	var tag: WareTag = WareTag.new()
	tag.ware_name = "Stormglass Phial"
	tag.effect = "Deal 20 damage to an enemy."
	tag.price = 55
	var tall: float = tag.reflow(160.0, 1.0)
	_check(fails, tall > 0.0 and tag._rows.size() >= 3,
			"a priced ware lays out name, effect and price rows")
	var wide: float = tag.reflow(160.0, 1.0)
	_check(fails, is_equal_approx(tall, wide),
			"reflow is deterministic for identical inputs")
	var floor_h: float = tag.reflow(160.0, 0.62)
	_check(fails, floor_h < tall,
			"the frame-derived factor actually shrinks the block")
	tag.set_state(true, true)
	tag.state_word = "SOLD"
	var sold_h: float = tag.reflow(160.0, 1.0)
	_check(fails, tag.sold and not is_equal_approx(sold_h, tall),
			"a struck sold tag is a different height from a price row")
	tag.set_state(false, false)
	_check(fails, not tag.sold and not tag.affordable,
			"unaffordable keeps the ware's tag, only the chip state flips")
	tag.free()
	var jar: BellJar = BellJar.new()
	_check(fails, jar.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"the jar glass never eats the offer's input")
	jar.free()
