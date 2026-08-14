class_name ShopScreen
extends Control
## The Night Stall. Concept C1 (`docs/design/2026-08-14-ui-direction`): the
## painting IS the screen — no panel, heading, section label or button box.
## Goods stand on the painted furniture, and `StallLayout` owns where that is
## and how the crop keeps it on screen at every shape.
##
## Slice 1 of #242 places the scene. The wares are still the old buttons and
## the old price labels, standing in their regions; slice 2 replaces them with
## thread-tied tags and the SOLD / unaffordable grammar. This view stays
## read-only either way: every purchase is emitted using the action id already
## understood by Main.

signal action_selected(id: String)

const CARD_SIZE: Vector2 = Vector2(CardView.CARD_W, CardView.CARD_H)
const CARD_ART_RATIO: float = CardView.CARD_H / CardView.CARD_W
const POTION_ART: String = "res://assets/art/potions/%s.png"
const RELIC_ART: String = "res://assets/art/relics/%s.png"
## The mock's two scrims (`shop-c1.html` .vig-top/.vig-bot), which is what keeps
## the HUD readable over the canopy and the prices readable over the counter.
const SCRIM_INK: Color = GlassStyle.NIGHT_BOT
const SCRIM_TOP: float = 0.21
const SCRIM_BOTTOM: float = 0.33
## Slice-1 split of a ware's region: the ware, then its price under it.
const PRICE_BAND: float = 0.26
const RACK_PRICE_GAP: float = 2.0

var shape: StringName = StageShape.IDENTITY

var _stock: Dictionary
var _gold: int
var _content: ContentDB
var _quest_offer: Dictionary
var _potion_slot_available: bool
var _sfx: SfxBus
var _painting: TextureRect
var _say: Label
var _leave: Button
var _card_views: Array[CardView] = []
## Purchasable slots registered at build; update() refreshes state in place.
var _slots: Array[Dictionary] = []
## Slots standing in the foreground rack, in the order they stand there.
var _rack: Array[Dictionary] = []


func update(stock: Dictionary, gold: int, quest_offer: Dictionary,
		potion_slot_available: bool) -> void:
	_stock = stock
	_gold = gold
	_quest_offer = quest_offer
	_potion_slot_available = potion_slot_available
	for entry: Dictionary in _slots:
		_apply_slot_state(entry)


func _init(stock: Dictionary, gold: int, content: ContentDB,
		quest_offer: Dictionary = {}, potion_slot_available: bool = true,
		stage_shape: StringName = StageShape.IDENTITY, sfx: SfxBus = null) -> void:
	_stock = stock
	_gold = gold
	_content = content
	_quest_offer = quest_offer
	_potion_slot_available = potion_slot_available
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	_build()


func _build() -> void:
	var ink: ColorRect = ColorRect.new()
	ink.color = SCRIM_INK
	ink.set_anchors_preset(Control.PRESET_FULL_RECT)
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ink)

	_painting = TextureRect.new()
	_painting.texture = load(StallLayout.BACKDROP) as Texture2D
	_painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_painting.stretch_mode = TextureRect.STRETCH_SCALE
	_painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_painting)
	_add_scrim(0.80, SCRIM_TOP, true)
	_add_scrim(0.72, SCRIM_BOTTOM, false)

	_say = _label(Locale.active.t("ui.shop.greeting"), 17, RunStyle.PARCHMENT, false)
	_say.add_theme_font_override("font", RunStyle.slanted(GlassStyle.ALEGREYA_400))
	_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_say)

	_add_stock()

	# Leaving is walking up the stair, so the control is the words on the
	# treads: a real Button for focus and touch, with its box taken away.
	_leave = Button.new()
	_leave.text = "←  " + Locale.active.t("ui.shop.leaveUpper")
	_leave.flat = true
	_leave.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_leave.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 3))
	_leave.add_theme_font_size_override("font_size", 14)
	_leave.add_theme_color_override("font_color", Color("#d8bb71"))
	_leave.pressed.connect(_emit_action.bind("leave"))
	add_child(_leave)


func _add_scrim(alpha: float, rate: float, from_top: bool) -> void:
	var scrim: TextureRect = TextureRect.new()
	scrim.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(SCRIM_INK, alpha), Color(SCRIM_INK, 0.0)]),
		PackedFloat32Array([0.0, 1.0]), false,
		Vector2(0.5, 0.0 if from_top else 1.0), Vector2(0.5, 1.0 if from_top else 0.0))
	scrim.anchor_right = 1.0
	scrim.anchor_top = 0.0 if from_top else 1.0 - rate
	scrim.anchor_bottom = rate if from_top else 1.0
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)


func _add_stock() -> void:
	var card_rows: Array = _stock.get("cards", [])
	for index: int in range(card_rows.size()):
		var row: Dictionary = card_rows[index]
		_add_card(row, index)
	# Phials hang from the canopy hooks, relics stand on the counter.
	var potion_rows: Array = _stock.get("potions", [])
	for index: int in range(potion_rows.size()):
		var potion: Dictionary = potion_rows[index]
		_add_misc("potions", potion, index,
			StallLayout.HOOK_ORDER[index % StallLayout.HOOK_ORDER.size()])
	var relic_rows: Array = _stock.get("relics", [])
	for index: int in range(relic_rows.size()):
		var relic: Dictionary = relic_rows[index]
		_add_misc("relics", relic, index,
			StallLayout.STANDS[index % StallLayout.STANDS.size()])
	if not _quest_offer.is_empty():
		_add_offer()
	_add_removal()


func _add_card(row: Dictionary, index: int) -> void:
	var id: String = str(row.get("id", ""))
	var definition: Dictionary = _content.cards.get(id, {})
	var cost_v: Variant = definition.get("cost")
	var cost: int = 0 if cost_v == null else int(float(str(cost_v)))
	var view: CardView = CardView.new(CardInst.new(-index - 1, StringName(id)),
		definition, cost)
	var price_label: Label = _price_label(_price(row), false)
	var entry: Dictionary = _register_slot("card", "cards", index, view,
		price_label, RunStyle.GOLD, &"")
	# Always connect; gate on the slot's live disabled flag from _apply_slot_state.
	view.released_at.connect(func(_uid: int, _position: Vector2) -> void:
		if entry.get("disabled", false):
			return
		_emit_action("cards:%d" % index)
	)
	add_child(view)
	add_child(price_label)
	_rack.append(entry)
	_card_views.append(view)


func _add_misc(category: String, row: Dictionary, index: int,
		region: StringName) -> void:
	var id: String = str(row.get("id", ""))
	var registry: Dictionary = _content.relics if category == "relics" \
		else _content.potions
	var definition: Dictionary = registry.get(id, {})
	var art: String = (RELIC_ART if category == "relics" else POTION_ART) % id
	var button: Button = _item_button(str(definition.get("name", id)),
		str(definition.get("text", "")), art, false, false)
	button.pressed.connect(_emit_action.bind("%s:%d" % [category, index]))
	var price_label: Label = _price_label(_price(row), false)
	_register_slot("misc", category, index, button, price_label, RunStyle.GOLD, region)
	add_child(button)
	add_child(price_label)


func _add_offer() -> void:
	var price: int = _price(_quest_offer)
	var button: Button = _item_button(
		str(_quest_offer.get("name", "A Lantern with No Flame")),
		str(_quest_offer.get("text", _content.quests.get("usurper", {}).get(
			"itemText", "Cold glass. No wick."))), "", false, true)
	button.pressed.connect(_emit_action.bind("quest:flamelessLantern"))
	var price_colour: Color = Color("#c7eadf")
	var price_label: Label = _price_label(price, false, price_colour)
	_register_slot("offer", "", 0, button, price_label, price_colour, &"jar")
	add_child(button)
	add_child(price_label)


func _add_removal() -> void:
	var price: int = int(float(str(_stock.get("removeCost", 0))))
	var button: Button = _item_button(
		Locale.active.t("ui.shop.cardRemoval.title").to_upper(),
		Locale.active.t("ui.shop.cardRemoval.desc"), "", false, false, "✂")
	button.pressed.connect(_emit_action.bind("remove"))
	var price_label: Label = _price_label(price, false)
	# The merchant's own service stands in the rack beside the cards.
	_rack.append(_register_slot("removal", "", 0, button, price_label,
		RunStyle.GOLD, &""))
	add_child(button)
	add_child(price_label)


func _register_slot(kind: String, category: String, index: int, control: Control,
		price_label: Label, price_colour: Color, region: StringName) -> Dictionary:
	var entry: Dictionary = {
		"kind": kind,
		"category": category,
		"index": index,
		"control": control,
		"price_label": price_label,
		"price_colour": price_colour,
		"region": region,
		"disabled": false,
	}
	_slots.append(entry)
	_apply_slot_state(entry)
	return entry


func _apply_slot_state(entry: Dictionary) -> void:
	var kind: String = str(entry["kind"])
	var index: int = entry["index"]
	var disabled: bool = false
	match kind:
		"card":
			var rows: Array = _stock.get("cards", [])
			var row: Dictionary = rows[index]
			var sold: bool = row.get("sold", false)
			disabled = sold or _gold < _price(row)
			var view: CardView = entry["control"]
			view.modulate.a = 0.28 if sold else (0.58 if disabled else 1.0)
		"misc":
			var category: String = str(entry["category"])
			var rows: Array = _stock.get(category, [])
			var row: Dictionary = rows[index]
			var sold: bool = row.get("sold", false)
			disabled = sold or _gold < _price(row) \
				or (category == "potions" and not _potion_slot_available)
			var button: Button = entry["control"]
			button.disabled = disabled
			button.modulate.a = 0.28 if sold else 1.0
		"offer":
			# Read live _quest_offer — usurper_offer returns a fresh dict each
			# call, and an EMPTY one once bought: the lantern leaves the stall
			# entirely, exactly as the old full rebuild dropped it.
			var offer_btn: Button = entry["control"]
			var gone: bool = _quest_offer.is_empty()
			offer_btn.visible = not gone
			var offer_price: Label = entry["price_label"]
			offer_price.visible = not gone
			disabled = gone or _gold < _price(_quest_offer) \
				or _quest_offer.get("sold", false)
			offer_btn.disabled = disabled
		"removal":
			var removed: bool = _stock.get("removed", false)
			disabled = removed or _gold < int(float(str(_stock.get("removeCost", 0))))
			var removal_btn: Button = entry["control"]
			removal_btn.disabled = disabled
			removal_btn.modulate.a = 0.28 if removed else 1.0
	entry["disabled"] = disabled
	var price_label: Label = entry["price_label"]
	var price_colour: Color = entry["price_colour"]
	price_label.add_theme_color_override("font_color",
		RunStyle.DANGER if disabled else price_colour)


func _item_button(title: String, description: String, art_path: String,
		disabled: bool, quest: bool, glyph: String = "◇") -> Button:
	var button: Button = Button.new()
	button.text = ("%s\n" % glyph if art_path.is_empty() else "") \
		+ title + ("\n%s" % description if not description.is_empty() else "")
	button.disabled = disabled
	button.tooltip_text = description
	button.clip_text = true
	button.add_theme_font_override("font", GlassStyle.face(GlassStyle.ALEGREYA_400))
	button.add_theme_font_size_override("font_size", 12)
	RunStyle.style_button(button, false, Color("#8ce0cc") if quest else RunStyle.GOLD)
	if not art_path.is_empty() and ResourceLoader.exists(art_path):
		button.icon = load(art_path) as Texture2D
		button.expand_icon = true
	button.mouse_entered.connect(_hover.bind(button))
	return button


func _price_label(price: int, disabled: bool,
		colour: Color = RunStyle.GOLD) -> Label:
	return _label("◈  %d" % price, 16,
		RunStyle.DANGER if disabled else colour, true)


func _emit_action(id: String) -> void:
	_sfx.play(&"click")
	action_selected.emit(id)


func _hover(button: Button) -> void:
	if not button.disabled:
		_sfx.play(&"hover", 0.45)


func _ready() -> void:
	resized.connect(_relayout)
	_relayout()


func set_shape(stage_shape: StringName) -> void:
	if StageShape.REFERENCES.has(stage_shape):
		shape = stage_shape
		_relayout()


## Everything is placed against the painting, so one pass re-seats the whole
## stall whenever the frame changes. Nothing here reads a container's geometry,
## which is why `tests/test_stall_layout.gd` can measure it without a frame.
func _relayout() -> void:
	var frame: Vector2 = size
	if frame.x <= 0.0 or frame.y <= 0.0 or _painting == null:
		return
	var canvas: Rect2 = StallLayout.canvas(frame)
	_painting.position = canvas.position
	_painting.size = canvas.size
	for entry: Dictionary in _slots:
		var region: StringName = entry["region"]
		if region != &"":
			var control: Control = entry["control"]
			var price_label: Label = entry["price_label"]
			_seat(control, price_label, StallLayout.place(frame, region))
	_seat_rack(frame)
	# The canopy compresses to nothing on a wide frame, so the merchant's line
	# is pushed clear of the HUD band rather than clipped behind it.
	var say_box: Rect2 = StallLayout.place(frame, &"say")
	say_box.position.y = maxf(say_box.position.y, _hud_band() + 8.0)
	_say.position = say_box.position
	_say.size = say_box.size
	var stair: Rect2 = StallLayout.place(frame, &"stair")
	_leave.position = stair.position
	_leave.size = Vector2(stair.size.x, maxf(stair.size.y, RunStyle.hit_floor(44.0)))


## The top bar RunHud draws over this screen (`run_hud.gd` `_apply_shape`).
func _hud_band() -> float:
	if shape == &"phone-portrait":
		return 58.0
	return 42.0 if shape == &"phone-landscape" else 56.0


## A ware in its region: the goods above, the price under them. The price band
## is never smaller than the text in it — a Label refuses to shrink below its
## own line height, and a band that ignores that pushes the number out of the
## frame on a short one (measured: 20:9 lost the whole rack price row).
func _seat(control: Control, price_label: Label, box: Rect2) -> void:
	var price_h: float = maxf(price_label.get_combined_minimum_size().y,
		box.size.y * PRICE_BAND)
	control.custom_minimum_size = Vector2.ZERO
	control.position = box.position
	control.size = Vector2(box.size.x, maxf(0.0, box.size.y - price_h))
	price_label.position = Vector2(box.position.x, box.end.y - price_h)
	price_label.size = Vector2(box.size.x, price_h)


func _seat_rack(frame: Vector2) -> void:
	var band: Rect2 = StallLayout.rack_band(frame)
	var count: int = _rack.size()
	if count == 0 or band.size.x <= 0.0 or band.size.y <= 0.0:
		return
	var first_price: Label = _rack[0]["price_label"]
	var price_h: float = maxf(first_price.get_combined_minimum_size().y,
		band.size.y * 0.11)
	var separation: float = band.size.x * 0.012
	var slot_w: float = (band.size.x - separation * float(count - 1)) / float(count)
	var card_h: float = minf(band.size.y - price_h - RACK_PRICE_GAP,
		minf(slot_w * CARD_ART_RATIO, CardView.CARD_H))
	for index: int in range(count):
		var entry: Dictionary = _rack[index]
		var slot: Rect2 = Rect2(
			band.position.x + (slot_w + separation) * float(index),
			band.position.y, slot_w, card_h)
		var control: Control = entry["control"]
		var view: CardView = control as CardView
		if view != null:
			var card_scale: float = card_h / CardView.CARD_H
			view.scale = Vector2.ONE * card_scale
			view.position = slot.position + Vector2(
				(slot.size.x - CardView.CARD_W * card_scale) * 0.5, 0.0) \
				- CARD_SIZE * 0.5 * (1.0 - card_scale)
		else:
			control.custom_minimum_size = Vector2.ZERO
			control.position = slot.position
			control.size = slot.size
		var price_label: Label = entry["price_label"]
		price_label.position = Vector2(slot.position.x, slot.end.y + RACK_PRICE_GAP)
		price_label.size = Vector2(slot.size.x, price_h)


## A rack card's rect on screen. CardView scales around its centre
## (`card_view.gd:333` sets `pivot_offset = size * 0.5`), so its `position` is
## not its visible corner; `_seat_rack` seats it by the inverse of this, and
## `tests/test_stall_layout.gd` measures containment through it.
static func card_rect(view: CardView) -> Rect2:
	return Rect2(view.position + CARD_SIZE * 0.5 * (1.0 - view.scale.x),
		CARD_SIZE * view.scale.x)


static func _price(row: Dictionary) -> int:
	return int(float(str(row.get("price", 0))))


static func _label(text: String, font_size: int, colour: Color,
		centred: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centred \
		else HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_override("font", GlassStyle.face(GlassStyle.ALEGREYA_400))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label
