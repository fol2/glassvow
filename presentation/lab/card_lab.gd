class_name CardLab
extends Control
## The card designer surface: every card in the loaded content set, laid flat on
## the benchmark's own backdrop, at 1:1 with no hand fan, no rotation, no lift.
##
## Why this exists: card art and typography can only be judged against the
## benchmark (roguecardv2@6e069118), and reading them off a live fight means
## fighting the hand's arc, overlap and viewport clipping at the same time. This
## screen removes all three so a `--shot` here diffs directly against the same
## cards flattened in the browser.
##
##   godot --path . -- --cards                       # window, stays open
##   godot --path . -- --cards --shot=/tmp/cards.png # headless contact sheet
##   godot --path . -- --cards=strike,defend --zoom=3
##
## In the window: hover a card to raise it (the benchmark's `.card-grid .card:hover`
## — translateY(-8) scale(1.05) over 0.18s, plus the cursor glare), drag anywhere
## to pan, wheel to scroll.
##
## Zoom drives Window.content_scale_factor, NOT a node scale. Scaling the node
## would magnify already-rasterised glyphs and read as blur; the content scale
## makes Godot re-rasterise the whole sheet at the larger size, which is the
## same canvas_items path the game uses on a high-DPI display.
##
## Presentation-only and content-driven: it builds CardInst rows straight off
## ContentDB, so a card that renders here renders in a fight the same way.

const BACKDROP: Color = Color(0.043, 0.055, 0.102)   # #0B0E1A, the benchmark field
const GAP_X: float = 26.0
const GAP_Y: float = 34.0
const MARGIN: float = 40.0
## Benchmark: .card-grid .card:hover { transform: translateY(-8px) scale(1.05) }
const HOVER_RISE: float = 8.0
const HOVER_SCALE: float = 1.05
const HOVER_TIME: float = 0.18

var content: ContentDB

var _zoom: float = 1.0
var _sheet: Control
var _homes: Dictionary = {}          # CardView -> resting position
var _tweens: Dictionary = {}         # CardView -> active hover tween
var _panning: bool = false


func _init(content_ref: ContentDB, only: PackedStringArray = PackedStringArray(),
		zoom: float = 1.0) -> void:
	content = content_ref
	_zoom = maxf(1.0, zoom)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()

	var field: ColorRect = ColorRect.new()
	field.color = BACKDROP
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)

	var ids: Array[String] = []
	for k: Variant in content.cards.keys():
		ids.append(str(k))
	ids.sort()
	if not only.is_empty():
		var wanted: Array[String] = []
		for id: String in ids:
			if only.has(id):
				wanted.append(id)
		# Say what was asked for and not found. A filter that silently drops
		# unknown ids reads as "that card renders blank" when it never ran —
		# display names are not ids here (Edge is `strike`, Ward is `defend`).
		var missing: Array[String] = []
		for req: String in only:
			if not wanted.has(req):
				missing.append(req)
		if not missing.is_empty():
			push_warning("card lab: no such card id: %s" % ", ".join(missing))
			print("card lab: no such card id: %s" % ", ".join(missing))
		ids = wanted

	# Hand-placed, not a GridContainer: a container re-asserts child positions
	# every layout pass, which fights the hover rise.
	_sheet = Control.new()
	_sheet.position = Vector2(MARGIN, MARGIN)
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sheet)

	# Columns are counted in the zoomed stage, which content_scale_factor shrinks.
	var usable: float = (1180.0 / _zoom) - MARGIN * 2.0
	var cols: int = maxi(1, int((usable + GAP_X) / (CardView.CARD_W + GAP_X)))

	var uid: int = 1
	for id: String in ids:
		var data: Dictionary = content.cards.get(id, {})
		var inst: CardInst = CardInst.new(uid, StringName(id))
		# `cost` is present-but-null on the unplayable cards (burn, hex, wound),
		# so Dictionary.get's default never fires — it only covers a missing key.
		# Same read the domain does in combat.gd eff_cost().
		var cost_v: Variant = data.get("cost")
		var cost_num: int = 0 if cost_v == null else int(float(str(cost_v)))
		var card: CardView = CardView.new(inst, data, cost_num)
		var col: int = (uid - 1) % cols
		var row: int = (uid - 1) / cols
		var home: Vector2 = Vector2(
			float(col) * (CardView.CARD_W + GAP_X),
			float(row) * (CardView.CARD_H + GAP_Y))
		card.position = home
		card.pivot_offset = Vector2(CardView.CARD_W, CardView.CARD_H) * 0.5
		_homes[card] = home
		card.hover_changed.connect(_on_card_hover.bind(card))
		_sheet.add_child(card)
		uid += 1

	var caption: Label = Label.new()
	var scale_note: String = "1:1" if is_equal_approx(_zoom, 1.0) else "%d:1" % int(_zoom)
	caption.text = "card lab · %d cards · %s against roguecardv2@6e069118" % [
		ids.size(), scale_note]
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.offset_top = -26
	caption.offset_bottom = -8
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)


func _ready() -> void:
	if not is_equal_approx(_zoom, 1.0):
		# Re-rasterise at the larger size rather than magnifying pixels.
		get_window().content_scale_factor = _zoom


## Raise on hover, exactly the benchmark's grid behaviour. The card is also
## brought to the front so its rise is not clipped by the next column.
func _on_card_hover(_uid: int, hovering: bool, card: CardView) -> void:
	var home: Vector2 = _homes.get(card, card.position)
	if hovering:
		_sheet.move_child(card, _sheet.get_child_count() - 1)
	var tw: Tween = _tweens.get(card)
	if tw != null and tw.is_valid():
		tw.kill()
	tw = create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(true)
	tw.tween_property(card, "position",
		home - Vector2(0.0, HOVER_RISE) if hovering else home, HOVER_TIME)
	tw.tween_property(card, "scale",
		Vector2(HOVER_SCALE, HOVER_SCALE) if hovering else Vector2.ONE, HOVER_TIME)
	_tweens[card] = tw


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_panning = mb.pressed
			return
		# Wheel scrolls the sheet; shift-wheel pans sideways.
		var step: float = 60.0
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_sheet.position += Vector2(-step, 0.0) if mb.shift_pressed else Vector2(0.0, -step)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_sheet.position += Vector2(step, 0.0) if mb.shift_pressed else Vector2(0.0, step)
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and _panning:
		_sheet.position += mm.relative
