class_name ShopScreen
extends Control
## The Night Stall. Concept C1 (`docs/design/2026-08-14-ui-direction`): the
## painting IS the screen — no panel, heading, section label or button box.
## Goods stand on the painted furniture, and `StallLayout` owns where that is
## and how the crop keeps it on screen at every shape.
##
## Slice 2 of #242 hangs the wares' tags (`WareTag`) and the state grammar off
## that scaffold: SOLD is a physical gap with a struck name, unaffordable is the
## same ware with a red number, and the quest offer stands under `BellJar` on
## its own ledge. This view stays read-only: every purchase is emitted using the
## action id already understood by Main.

signal action_selected(id: String)

const CARD_SIZE: Vector2 = Vector2(CardView.CARD_W, CardView.CARD_H)
const CARD_ART_RATIO: float = CardView.CARD_H / CardView.CARD_W
const POTION_ART: String = "res://assets/art/potions/%s.png"
const RELIC_ART: String = "res://assets/art/relics/%s.png"
## Cold glass, no wick: the quest lantern is the ember lantern's art with its
## fire drained by `OFFER_TINT`, not a new raster.
const OFFER_ART: String = "res://assets/art/relics/emberLantern.png"
const OFFER_TINT: Color = Color(0.40, 0.78, 1.20, 0.94)
## The mock's two scrims (`shop-c1.html` .vig-top/.vig-bot), which is what keeps
## the HUD readable over the canopy and the prices readable over the counter.
const SCRIM_INK: Color = GlassStyle.NIGHT_BOT
const SCRIM_TOP: float = 0.21
const SCRIM_BOTTOM: float = 0.33
const RACK_PRICE_GAP: float = 2.0
## The least of its region the goods keep when the tag wants more.
const WARE_SHARE: float = 0.45

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
var _leave_font: FontVariation = RunStyle.tracked(GlassStyle.CINZEL_700, 3)
var _jar: BellJar
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
	# A tag's height now depends on its state — a struck name and a SOLD word
	# are not a price row — so the seat has to run again after the state does.
	_relayout()


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
	accessibility_name = Locale.active.t("ui.shop.title")
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

	_say = Label.new()
	_say.text = Locale.active.t("ui.shop.greeting")
	_say.add_theme_font_override("font", RunStyle.slanted(GlassStyle.ALEGREYA_400))
	_say.add_theme_color_override("font_color", RunStyle.PARCHMENT)
	_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_say)

	_add_stock()

	# Leaving is walking up the stair, so the control is the words on the
	# treads: a real Button for focus and touch, with its box taken away.
	_leave = Button.new()
	_leave.text = "←  " + Locale.active.t("ui.shop.leaveUpper")
	_leave.flat = true
	_leave.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_leave.add_theme_font_override("font", _leave_font)
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
	# Phials stand on the shelf, relics stand on the counter.
	var potion_rows: Array = _stock.get("potions", [])
	for index: int in range(potion_rows.size()):
		var potion: Dictionary = potion_rows[index]
		_add_misc("potions", potion, index,
			StallLayout.SHELF_SEATS[index % StallLayout.SHELF_SEATS.size()])
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
	# A card carries its own name and rules on its face, so its tag is the price
	# row alone — until it sells and the pocket needs the struck name.
	var tag: WareTag = _tag(str(definition.get("name", id)), "", _price(row))
	tag.price_only = true
	var entry: Dictionary = _register_slot("card", "cards", index, view, tag, &"")
	# Always connect; gate on the slot's live disabled flag from _apply_slot_state.
	view.released_at.connect(func(_uid: int, _position: Vector2) -> void:
		if entry.get("disabled", false):
			return
		_emit_action("cards:%d" % index)
	)
	add_child(view)
	add_child(tag)
	_rack.append(entry)
	_card_views.append(view)


func _add_misc(category: String, row: Dictionary, index: int,
		region: StringName) -> void:
	var id: String = str(row.get("id", ""))
	var registry: Dictionary = _content.relics if category == "relics" \
		else _content.potions
	var definition: Dictionary = registry.get(id, {})
	var button: Button = _ware_button(
		(RELIC_ART if category == "relics" else POTION_ART) % id)
	button.pressed.connect(_emit_action.bind("%s:%d" % [category, index]))
	var tag: WareTag = _tag(str(definition.get("name", id)),
		str(definition.get("text", "")), _price(row))
	_register_slot("misc", category, index, button, tag, region)
	add_child(button)
	add_child(tag)


## The quest offer, set apart at the counter's right end under cold glass: the
## one thing in the room the merchant is not selling for its own sake.
func _add_offer() -> void:
	var button: Button = _ware_button(OFFER_ART)
	button.modulate = OFFER_TINT
	button.pressed.connect(_emit_action.bind("quest:flamelessLantern"))
	var tag: WareTag = _tag(str(_quest_offer.get("name", "A Lantern with No Flame")),
		str(_quest_offer.get("text", _content.quests.get("usurper", {}).get(
			"itemText", "Cold glass. No wick."))), _price(_quest_offer))
	tag.cold = true
	tag.eyebrow = Locale.active.t("ui.shop.gate")
	_register_slot("offer", "", 0, button, tag, &"jar")
	add_child(button)
	# The glass stands in FRONT of what it covers, so it is added after the ware
	# and passes the mouse through to it.
	_jar = BellJar.new()
	add_child(_jar)
	add_child(tag)


func _add_removal() -> void:
	var button: Button = _ware_button("")
	button.pressed.connect(_emit_action.bind("remove"))
	var tag: WareTag = _tag(Locale.active.t("ui.shop.cardRemoval.title"),
		Locale.active.t("ui.shop.cardRemoval.desc"),
		int(float(str(_stock.get("removeCost", 0)))))
	tag.emblem = true
	tag.state_word = Locale.active.t("ui.shop.removalSpent")
	# The merchant's own service stands in the rack beside the cards.
	_rack.append(_register_slot("removal", "", 0, button, tag, &""))
	add_child(button)
	add_child(tag)


## An unboxed ware: a real Button so keyboard focus and the touch floor survive
## the loss of the chrome, with the goods themselves as its whole face.
func _ware_button(art_path: String) -> Button:
	var button: Button = Button.new()
	RunStyle.hide_button_boxes(button)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	if not art_path.is_empty() and ResourceLoader.exists(art_path):
		button.icon = load(art_path) as Texture2D
	button.mouse_entered.connect(_hover.bind(button))
	return button


func _tag(ware_name: String, effect: String, price: int) -> WareTag:
	var tag: WareTag = WareTag.new()
	tag.ware_name = ware_name
	tag.effect = effect
	tag.price = price
	tag.state_word = Locale.active.t("ui.shop.sold")
	return tag


func _register_slot(kind: String, category: String, index: int, control: Control,
		tag: WareTag, region: StringName) -> Dictionary:
	var entry: Dictionary = {
		"kind": kind,
		"category": category,
		"index": index,
		"control": control,
		"tag": tag,
		"region": region,
		"disabled": false,
	}
	_slots.append(entry)
	_apply_slot_state(entry)
	return entry


## The whole state grammar, in one place. SOLD/SPENT takes the ware away and
## leaves the tag with a struck name; unaffordable leaves the ware exactly where
## it stands and turns one number red. Nothing else changes between them.
func _apply_slot_state(entry: Dictionary) -> void:
	var index: int = entry["index"]
	var sold: bool = false
	var price: int = 0
	# The offer, once bought, leaves the stall entirely — jar, ware and tag.
	var gone: bool = false
	var blocked: bool = false
	match str(entry["kind"]):
		"card", "misc":
			var category: String = str(entry["category"])
			var rows: Array = _stock.get(category, [])
			var row: Dictionary = rows[index]
			sold = row.get("sold", false)
			price = _price(row)
			blocked = category == "potions" and not _potion_slot_available
		"offer":
			# Read live _quest_offer — usurper_offer returns a fresh dict each
			# call, and an EMPTY one once bought.
			gone = _quest_offer.is_empty()
			sold = _quest_offer.get("sold", false)
			price = _price(_quest_offer)
		"removal":
			sold = _stock.get("removed", false)
			price = int(float(str(_stock.get("removeCost", 0))))
	var payable: bool = _gold >= price
	entry["disabled"] = sold or gone or blocked or not payable
	var control: Control = entry["control"]
	control.visible = not (sold or gone)
	var button: Button = control as Button
	if button != null:
		button.disabled = entry["disabled"]
	if entry["region"] == &"jar" and _jar != null:
		_jar.visible = not gone
	var tag: WareTag = entry["tag"]
	tag.visible = not gone
	tag.set_state(sold, payable)


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
	# One factor, derived from the painting rather than the window, drives every
	# face on the screen. See `StallLayout.type_scale`.
	var factor: float = StallLayout.type_scale(frame)
	for entry: Dictionary in _slots:
		var region: StringName = entry["region"]
		if region != &"":
			_seat(entry, StallLayout.place(frame, region), frame, factor)
	_seat_rack(frame, factor)
	# The canopy compresses to nothing on a wide frame, so the merchant's line
	# is pushed clear of the HUD band rather than clipped behind it.
	var say_box: Rect2 = StallLayout.place(frame, &"say")
	say_box.position.y = maxf(say_box.position.y, _hud_band() + 8.0)
	_say.add_theme_font_size_override("font_size", maxi(10, int(roundf(17.0 * factor))))
	_say.position = say_box.position
	_say.size = say_box.size
	var stair: Rect2 = StallLayout.place(frame, &"stair")
	_leave_font.spacing_glyph = maxi(1, int(roundf(3.0 * factor)))
	_leave.add_theme_font_size_override("font_size", maxi(9, int(roundf(14.0 * factor))))
	_leave.position = stair.position
	_leave.size = Vector2(stair.size.x, maxf(stair.size.y, RunStyle.hit_floor(44.0)))


## The top bar RunHud draws over this screen (`run_hud.gd` `_apply_shape`).
## Phone-landscape shares the 62 px wrap bar (#382). No pad-portrait special case
## — that identity is retired (`docs/design/2026-08-18-landscape-only.md`).
func _hud_band() -> float:
	if shape == &"phone-landscape":
		return 62.0
	return 56.0


## A ware in its region. The region box is the WARE PLUS ITS TAG — that is how
## the mock was measured — so the tag takes one end of it, the goods take the
## rest, and the thread crosses the gap left between them.
##
## The tag is then clamped back inside the frame. Below a certain painting scale
## a region is narrower than the smallest legible tag, so the tag grows past its
## region rather than becoming unreadable; containment has to survive that, and
## clamping is what makes `tests/test_stall_layout.gd` able to assert it.
func _seat(entry: Dictionary, box: Rect2, frame: Vector2, factor: float) -> void:
	var tag: WareTag = entry["tag"]
	var above: bool = StallLayout.TAG_ABOVE.has(entry["region"])
	var tag_h: float = tag.reflow(box.size.x, factor)
	var thread: float = maxf(5.0, box.size.y * 0.05)
	# The goods keep at least this much of their region whatever the tag needs.
	# A long effect line otherwise squeezes the ware to a thumbnail, and it is
	# the ware that has to read from across the room, not the second sentence.
	var ware_h: float = maxf(box.size.y * WARE_SHARE, box.size.y - tag_h - thread)
	# A PHIAL ON THE SHELF KEEPS A FIXED FOOTING (#242 slice 3). Its tag hangs
	# below it, so the residual above would be its height AND its foot: two
	# phials whose rules text wraps differently then stand at two different
	# heights on one painted board — measured at 20px apart with the slice's own
	# stock. Its ware rect is its column instead, square, which is also what
	# makes an `expand_icon` square sprite exactly fill it.
	if StallLayout.SHELF_SEATS.has(entry["region"]):
		ware_h = box.size.x
	# A ware whose tag is above it STANDS on something, so it keeps a footing
	# clear of the region's bottom edge — flush, it reads as hung over the lip.
	var ware: Rect2 = Rect2(box.position.x,
		box.end.y - ware_h - thread if above else box.position.y,
		box.size.x, ware_h)
	var control: Control = entry["control"]
	control.custom_minimum_size = Vector2.ZERO
	control.position = ware.position
	control.size = ware.size
	tag.position = _inside(frame, Vector2(box.position.x,
		ware.position.y - thread - tag_h if above else ware.end.y + thread),
		tag.size)
	tag.tie = Vector2(ware.get_center().x,
		ware.position.y if above else ware.end.y)
	if entry["region"] == &"jar" and _jar != null:
		_jar.position = ware.position
		_jar.size = ware.size


func _seat_rack(frame: Vector2, factor: float) -> void:
	var band: Rect2 = StallLayout.rack_band(frame)
	var count: int = _rack.size()
	if count == 0 or band.size.x <= 0.0 or band.size.y <= 0.0:
		return
	# One landscape row. Phone-landscape's short 844×390 stage scales the
	# cards into the strip below the lip; it does not restack.
	var separation: float = band.size.x * 0.012
	var slot_w: float = (band.size.x - separation * float(count - 1)) / float(count)
	for index: int in range(count):
		var entry: Dictionary = _rack[index]
		var tag: WareTag = entry["tag"]
		var tag_h: float = tag.reflow(slot_w, factor)
		var left: float = band.position.x + (slot_w + separation) * float(index)
		var control: Control = entry["control"]
		var view: CardView = control as CardView
		if view == null:
			# The merchant's service stands the full height of the rack: shears,
			# name, effect and price are one drawn block over one hit rect.
			control.custom_minimum_size = Vector2.ZERO
			control.position = Vector2(left, band.position.y)
			control.size = Vector2(slot_w, band.size.y)
			tag.position = _inside(frame,
				Vector2(left, band.end.y - tag_h), tag.size)
			continue
		var card_h: float = maxf(8.0, minf(band.size.y - tag_h - RACK_PRICE_GAP,
			minf(slot_w * CARD_ART_RATIO, CardView.CARD_H)))
		var card_scale: float = card_h / CardView.CARD_H
		view.scale = Vector2.ONE * card_scale
		view.position = Vector2(
			left + (slot_w - CardView.CARD_W * card_scale) * 0.5,
			band.position.y) - CARD_SIZE * 0.5 * (1.0 - card_scale)
		# A sold card leaves a pocket, and the struck name stands IN the gap
		# rather than under it — the absence is the point.
		var tag_y: float = band.position.y + card_h + RACK_PRICE_GAP
		if tag.sold:
			tag_y = band.position.y + maxf(0.0, card_h - tag_h) * 0.42
		tag.position = _inside(frame, Vector2(left, tag_y), tag.size)


static func _inside(frame: Vector2, at: Vector2, box: Vector2) -> Vector2:
	return Vector2(clampf(at.x, 0.0, maxf(0.0, frame.x - box.x)),
		clampf(at.y, 0.0, maxf(0.0, frame.y - box.y)))


## A rack card's rect on screen. CardView scales around its centre
## (`card_view.gd:333` sets `pivot_offset = size * 0.5`), so its `position` is
## not its visible corner; `_seat_rack` seats it by the inverse of this, and
## `tests/test_stall_layout.gd` measures containment through it.
static func card_rect(view: CardView) -> Rect2:
	return Rect2(view.position + CARD_SIZE * 0.5 * (1.0 - view.scale.x),
		CARD_SIZE * view.scale.x)


static func _price(row: Dictionary) -> int:
	return int(float(str(row.get("price", 0))))
