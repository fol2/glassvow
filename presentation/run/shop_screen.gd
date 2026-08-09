class_name ShopScreen
extends Control
## Benchmark merchant stock. This view is read-only: every purchase is emitted
## using the action id already understood by Main.

signal action_selected(id: String)

const PANEL_W: float = 980.0
const CARD_SCALE: float = 138.0 / CardView.CARD_W
const MERCHANT_ART: String = "res://assets/art/props/merchant.png"
const POTION_ART: String = "res://assets/art/potions/%s.png"
const RELIC_ART: String = "res://assets/art/relics/%s.png"

var shape: StringName = StageShape.IDENTITY

var _stock: Dictionary
var _gold: int
var _content: ContentDB
var _quest_offer: Dictionary
var _potion_slot_available: bool
var _sfx: SfxBus
var _centre: CenterContainer
var _panel: PanelContainer
var _cards: HFlowContainer
var _misc: HFlowContainer
var _card_views: Array[CardView] = []
## Purchasable slots registered at build; update() refreshes state in place.
var _slots: Array[Dictionary] = []


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
	RunStyle.add_backdrop(self)
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	_build()


func _build() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	_centre = CenterContainer.new()
	_centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size.x = PANEL_W
	_panel.add_theme_stylebox_override("panel", RunStyle.panel(16, 24, 0.92))
	_centre.add_child(_panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	_panel.add_child(column)
	column.add_child(_header())

	_cards = HFlowContainer.new()
	_cards.alignment = FlowContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("h_separation", 16)
	_cards.add_theme_constant_override("v_separation", 12)
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_cards)

	_misc = HFlowContainer.new()
	_misc.alignment = FlowContainer.ALIGNMENT_CENTER
	_misc.add_theme_constant_override("h_separation", 16)
	_misc.add_theme_constant_override("v_separation", 12)
	_misc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_misc)

	_add_stock()
	var leave: Button = _action_button(Locale.active.t("ui.shop.leaveUpper"), true)
	leave.custom_minimum_size.x = 160
	leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave.pressed.connect(_emit_action.bind("leave"))
	column.add_child(leave)


func _header() -> HBoxContainer:
	var header: HBoxContainer = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var phone_portrait: bool = shape == &"phone-portrait"
	header.add_theme_constant_override("separation", 12 if phone_portrait else 18)
	var merchant: TextureRect = TextureRect.new()
	merchant.texture = load(MERCHANT_ART) as Texture2D
	merchant.custom_minimum_size = Vector2(100, 86) if phone_portrait else Vector2(130, 110)
	merchant.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	merchant.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	merchant.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(merchant)
	var copy: VBoxContainer = VBoxContainer.new()
	copy.add_theme_constant_override("separation", 4)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(copy)
	var title: Label = _label(Locale.active.t("ui.shop.title"), 22 if phone_portrait else 26,
		RunStyle.PARCHMENT, false)
	title.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 3))
	copy.add_child(title)
	var greeting: Label = _label(
		Locale.active.t("ui.shop.greeting"), 14,
		RunStyle.TEXT_DIM, false)
	greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(greeting)
	return header


func _add_stock() -> void:
	var card_rows: Array = _stock.get("cards", [])
	for index: int in range(card_rows.size()):
		var row: Dictionary = card_rows[index]
		_add_card(row, index)
	for category: String in ["relics", "potions"]:
		var rows: Array = _stock.get(category, [])
		for index: int in range(rows.size()):
			var row: Dictionary = rows[index]
			_add_misc(category, row, index)
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
	view.scale = Vector2.ONE * CARD_SCALE
	var price_label: Label = _price_label(_price(row), false)
	var entry: Dictionary = _register_slot("card", "cards", index, view,
		price_label, RunStyle.GOLD)
	# Always connect; gate on the slot's live disabled flag from _apply_slot_state.
	view.released_at.connect(func(_uid: int, _position: Vector2) -> void:
		if entry.get("disabled", false):
			return
		_emit_action("cards:%d" % index)
	)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 7)
	column.add_child(_card_pedestal(view))
	column.add_child(price_label)
	_cards.add_child(column)
	_card_views.append(view)


func _add_misc(category: String, row: Dictionary, index: int) -> void:
	var id: String = str(row.get("id", ""))
	var registry: Dictionary = _content.relics if category == "relics" \
		else _content.potions
	var definition: Dictionary = registry.get(id, {})
	var art: String = (RELIC_ART if category == "relics" else POTION_ART) % id
	var button: Button = _item_button(str(definition.get("name", id)),
		str(definition.get("text", "")), art, false, false)
	button.pressed.connect(_emit_action.bind("%s:%d" % [category, index]))
	var price_label: Label = _price_label(_price(row), false)
	_register_slot("misc", category, index, button, price_label, RunStyle.GOLD)
	_add_misc_column(button, price_label)


func _add_offer() -> void:
	var price: int = _price(_quest_offer)
	var button: Button = _item_button(
		str(_quest_offer.get("name", "A Lantern with No Flame")),
		str(_quest_offer.get("text", _content.quests.get("usurper", {}).get(
			"itemText", "Cold glass. No wick."))), "", false, true)
	button.pressed.connect(_emit_action.bind("quest:flamelessLantern"))
	var price_colour: Color = Color("#c7eadf")
	var price_label: Label = _price_label(price, false, price_colour)
	_register_slot("offer", "", 0, button, price_label, price_colour)
	_add_misc_column(button, price_label)


func _add_removal() -> void:
	var price: int = int(float(str(_stock.get("removeCost", 0))))
	var button: Button = _item_button(
		Locale.active.t("ui.shop.cardRemoval.title").to_upper(),
		Locale.active.t("ui.shop.cardRemoval.desc"), "", false, false, "✂")
	button.pressed.connect(_emit_action.bind("remove"))
	var price_label: Label = _price_label(price, false)
	_register_slot("removal", "", 0, button, price_label, RunStyle.GOLD)
	_add_misc_column(button, price_label)


func _register_slot(kind: String, category: String, index: int, control: Control,
		price_label: Label, price_colour: Color) -> Dictionary:
	var entry: Dictionary = {
		"kind": kind,
		"category": category,
		"index": index,
		"control": control,
		"price_label": price_label,
		"price_colour": price_colour,
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
			var column: Control = offer_btn.get_parent() as Control
			var gone: bool = _quest_offer.is_empty()
			if column != null:
				column.visible = not gone
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


func _add_misc_column(button: Button, price_label: Label) -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 7)
	column.add_child(button)
	column.add_child(price_label)
	_misc.add_child(column)


func _item_button(title: String, description: String, art_path: String,
		disabled: bool, quest: bool, glyph: String = "◇") -> Button:
	var button: Button = Button.new()
	button.text = ("%s\n" % glyph if art_path.is_empty() else "") \
		+ title + ("\n%s" % description if not description.is_empty() else "")
	button.custom_minimum_size = Vector2(164 if quest else 120, 146 if quest else 122)
	button.disabled = disabled
	button.tooltip_text = description
	button.add_theme_font_override("font", GlassStyle.face(GlassStyle.ALEGREYA_400))
	button.add_theme_font_size_override("font_size", 12)
	RunStyle.style_button(button, false, Color("#8ce0cc") if quest else RunStyle.GOLD)
	if not art_path.is_empty() and ResourceLoader.exists(art_path):
		button.icon = load(art_path) as Texture2D
		button.expand_icon = true
	button.mouse_entered.connect(_hover.bind(button))
	return button


func _action_button(text: String, primary: bool) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.add_theme_font_override("font", GlassStyle.face(GlassStyle.CINZEL_700))
	RunStyle.style_button(button, primary)
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
	resized.connect(_fit)
	_fit()


func set_shape(stage_shape: StringName) -> void:
	if StageShape.REFERENCES.has(stage_shape):
		shape = stage_shape
		_fit()


func _fit() -> void:
	if _centre == null:
		return
	var phone: bool = shape == &"phone-portrait" or shape == &"phone-landscape"
	_centre.custom_minimum_size = Vector2(maxf(0.0, size.x - 24.0),
		maxf(0.0, size.y - 40.0))
	_panel.custom_minimum_size.x = minf(PANEL_W,
		maxf(300.0, size.x - (16.0 if phone else 24.0)))


static func _card_pedestal(view: CardView) -> Control:
	var pedestal: Control = Control.new()
	pedestal.custom_minimum_size = Vector2(
		CardView.CARD_W * CARD_SCALE, CardView.CARD_H * CARD_SCALE)
	view.position = (pedestal.custom_minimum_size
		- Vector2(CardView.CARD_W, CardView.CARD_H)) * 0.5
	pedestal.add_child(view)
	return pedestal


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
