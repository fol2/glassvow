extends SceneTree
## Throwaway probe for the P4.11 shop in-place update. Asserts: an update with
## the same data keeps the same controls and scroll position; a gold drop flips
## affordability in place (including the card emit gate); a sold flag dims in
## place; a bought quest offer leaves the stall. Exits 1 on any FAIL.
##   godot --path . --position -4000,-4000 -s res://tools/probe_p411_shop.gd

var _fails: int = 0


func _check(name: String, ok: bool) -> void:
	print(name, ": ", "PASS" if ok else "FAIL")
	if not ok:
		_fails += 1


func _initialize() -> void:
	var host: Control = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var content: ContentDB = ContentDB.load_slice()
	var card_id: String = content.cards.keys()[0]
	var relic_id: String = content.relics.keys()[0]
	var card_rows: Array = []
	for i: int in range(8):
		card_rows.append({"id": card_id, "price": 50 + i})
	var stock: Dictionary = {
		"cards": card_rows,
		"relics": [{"id": relic_id, "price": 120}],
		"potions": [],
		"removeCost": 75,
	}
	var offer: Dictionary = {
		"id": "flamelessLantern", "name": "LANTERNPROBE", "price": 650,
	}
	var shop: ShopScreen = ShopScreen.new(stock, 100, content, offer, true)
	host.add_child(shop)
	await process_frame

	var emitted: Array[String] = []
	shop.action_selected.connect(func(id: String) -> void: emitted.append(id))
	var scroll: ScrollContainer = shop.find_children("", "ScrollContainer",
		true, false)[0] as ScrollContainer
	var buttons: Array[Node] = shop.find_children("", "Button", true, false)
	var ids: Array[int] = []
	for b: Node in buttons:
		ids.append(b.get_instance_id())
	scroll.scroll_vertical = 40
	await process_frame
	var scroll_before: int = scroll.scroll_vertical

	shop.update(stock, 100, offer, true)
	await process_frame
	var after: Array[Node] = shop.find_children("", "Button", true, false)
	var same: bool = after.size() == buttons.size()
	for i: int in range(mini(after.size(), buttons.size())):
		same = same and after[i].get_instance_id() == ids[i]
	_check("same-data update keeps controls", same)
	_check("scroll survives update",
		scroll_before > 0 and scroll.scroll_vertical == scroll_before)

	var views: Array[Node] = shop.find_children("", "CardView", true, false)
	var first_card: CardView = views[0] as CardView
	_check("card affordable at 100g", is_equal_approx(first_card.modulate.a, 1.0))
	first_card.released_at.emit(-1, Vector2.ZERO)
	var emitted_when_affordable: bool = emitted.size() == 1

	shop.update(stock, 10, offer, true)
	await process_frame
	_check("gold drop dims card in place",
		is_equal_approx(first_card.modulate.a, 0.58))
	first_card.released_at.emit(-1, Vector2.ZERO)
	_check("card emit gated when unaffordable",
		emitted_when_affordable and emitted.size() == 1)

	shop.update(stock, 100, offer, true)
	first_card.released_at.emit(-1, Vector2.ZERO)
	_check("gate reopens when gold returns", emitted.size() == 2)

	var rows: Array = stock["cards"]
	var row0: Dictionary = rows[0]
	row0["sold"] = true
	shop.update(stock, 100, offer, true)
	_check("sold dims to 0.28 in place", is_equal_approx(first_card.modulate.a, 0.28))

	shop.update(stock, 100, {}, true)
	var offer_hidden: bool = false
	for b: Node in after:
		if (b as Button).text.contains("LANTERNPROBE"):
			offer_hidden = not (b.get_parent() as Control).visible
	_check("bought offer leaves the stall", offer_hidden)
	quit(0 if _fails == 0 else 1)
