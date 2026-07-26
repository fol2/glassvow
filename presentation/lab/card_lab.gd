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
##   tools/shot.sh --cards --shot=/tmp/cards.png     # contact sheet, then quits
##   godot --path . -- --cards=strike,defend --zoom=3
##   godot --path . -- --cards=bastion --surfaces    # one card, every material
##
## --shot= is what makes a run quit; the lines without it leave a window open to
## work in. Captures go through tools/shot.sh and never carry --headless — a
## headless run has no viewport texture, so the capture hangs instead of failing.
## See that script's header for what it does and does not spare you.
##
## The surfaces sheet is the other axis: the SAME card in every recipe from
## CardSurface, captioned with the four layers it stacks. Cards differ there by
## nothing but what they are made of, which is the only way to judge a material
## — a rarity sheet varies art, text and tint at the same time and tells you
## nothing. Materials are angle-driven, so hover one (or pose the whole sheet
## with GLASSVOW_TILT) to see what a still frame cannot show.
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
## Presentation-only: rows are built from the card catalogue, so a card renders
## here exactly as it would in a fight, whether or not the slice can deal it.

## Every card's display fields, not just the slice's 15+3. Read straight here
## rather than through ContentDB: that registry is the domain's, and the cards
## the domain may legally deal are exactly the slice. This file carries no
## effects, so nothing loaded from it can be played — see the emitter's note in
## roguecardv2 tools/capture-port-fixtures.mjs.
const CATALOG_PATH: String = "res://port_fixtures/content/card-catalog.json"

const BACKDROP: Color = Color(0.043, 0.055, 0.102)   # #0B0E1A, the benchmark field
const GAP_X: float = 26.0
const GAP_Y: float = 34.0
const MARGIN: float = 40.0
## Benchmark: .card-grid .card:hover { transform: translateY(-8px) scale(1.05) }
const HOVER_RISE: float = 8.0
const HOVER_SCALE: float = 1.05
const HOVER_TIME: float = 0.18
const HEADING_H: float = 34.0
const RARITY_ORDER: Array = ["starter", "common", "uncommon", "rare", "special"]

var content: ContentDB

var _catalog: Dictionary = {}        # id -> display fields, all 61 cards
var _zoom: float = 1.0
var _sheet: Control
var _homes: Dictionary = {}          # CardView -> resting position
var _tweens: Dictionary = {}         # CardView -> active hover tween
var _panning: bool = false
var _sheet_h: float = 0.0            # laid-out height, for scroll clamping
var _ordered: Array[CardView] = []   # sheet order: rarity tier, then name
var _tiers: Array[String] = []       # parallel to _ordered
var _headings: Array[Label] = []
var _captions: Array[Label] = []     # parallel to _ordered; empty off the surfaces sheet
var _caption_h: float = 0.0          # extra row height the captions need


## All 61 cards' display fields. Falls back to the slice's own registry if the
## catalogue is absent. Public because the studio reads the same catalogue and
## one JSON contract deserves one reader — an older checkout still gets a working lab, just the
## 18 cards the domain can deal, and says so rather than coming up empty.
static func load_catalog(fallback: ContentDB) -> Dictionary:
	if ResourceLoader.exists(CATALOG_PATH) or FileAccess.file_exists(CATALOG_PATH):
		var text: String = FileAccess.get_file_as_string(CATALOG_PATH)
		if not text.is_empty():
			var raw: Variant = JSON.parse_string(text)
			if typeof(raw) == TYPE_DICTIONARY:
				var doc: Dictionary = raw
				var cards: Variant = doc.get("cards")
				if typeof(cards) == TYPE_DICTIONARY:
					var out: Dictionary = cards
					return out
	push_warning("card lab: %s unreadable — falling back to the slice registry"
		% CATALOG_PATH)
	return fallback.cards


## Place the sheet against the live stage size. Runs after any window resize, so
## the column count reflects the window the user actually gets.
func _layout_sheet() -> void:
	for h: Label in _headings:
		h.queue_free()
	_headings.clear()
	# Off the window, not this Control's `size` — the Control catches up a frame
	# or more after a resize, and on the first pass it still reports the old
	# stage, which lays out one column and looks like the zoom did nothing.
	var stage_w: float = (float(get_window().size.x) / _zoom) - MARGIN * 2.0
	var cols: int = maxi(1, int((stage_w + GAP_X) / (CardView.CARD_W + GAP_X)))
	var col: int = 0
	var y: float = 0.0
	var tier: String = ""
	for i: int in range(_ordered.size()):
		if _tiers[i] != tier:
			# New tier: close the current row, drop a heading, restart the grid.
			# Only advance when the row is part-filled — a row that just wrapped
			# has already moved y, and adding again leaves a blank row.
			if tier != "" and col > 0:
				y += CardView.CARD_H + GAP_Y + _caption_h
			tier = _tiers[i]
			col = 0
			var head: Label = Label.new()
			head.text = "%s — %d" % [tier.to_upper(), _tiers.count(tier)]
			head.add_theme_font_size_override("font_size", 13)
			head.add_theme_color_override("font_color", GlassStyle.EMBER)
			head.position = Vector2(2.0, y + 6.0)
			head.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_sheet.add_child(head)
			_headings.append(head)
			y += HEADING_H
		var card: CardView = _ordered[i]
		var home: Vector2 = Vector2(float(col) * (CardView.CARD_W + GAP_X), y)
		card.position = home
		_homes[card] = home
		if i < _captions.size():
			_captions[i].position = home + Vector2(0.0, CardView.CARD_H + 5.0)
			_captions[i].size.x = CardView.CARD_W
		col += 1
		if col >= cols:
			col = 0
			y += CardView.CARD_H + GAP_Y + _caption_h
	_sheet_h = y + CardView.CARD_H


func _init(content_ref: ContentDB, only: PackedStringArray = PackedStringArray(),
		zoom: float = 1.0,
		surfaces: PackedStringArray = PackedStringArray()) -> void:
	content = content_ref
	_zoom = maxf(1.0, zoom)
	# The offscreen passes are sized in logical px, so they have to grow with
	# the window's content scale or a zoomed sheet inspects a stretched card.
	CardView.oversample = maxf(2.0, _zoom)
	_catalog = load_catalog(content_ref)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()

	var field: ColorRect = ColorRect.new()
	field.color = BACKDROP
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)

	var ids: Array[String] = []
	for k: Variant in _catalog.keys():
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

	# Ordered the way the catalogue reads (docs/card-catalog.md) — rarity tier,
	# then display name — so the sheet lines up against the benchmark gallery
	# card for card instead of by internal id.
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ra: int = RARITY_ORDER.find(str(_catalog.get(a, {}).get("rarity", "")))
		var rb: int = RARITY_ORDER.find(str(_catalog.get(b, {}).get("rarity", "")))
		if ra != rb:
			return ra < rb
		return str(_catalog.get(a, {}).get("name", a)) \
			< str(_catalog.get(b, {}).get("name", b)))

	# Two sheets out of one grid: every card at its own material, or ONE card
	# wearing every material. The recipe rides in on the card data as `surface`
	# — the same override seam content uses — so the lab gets no private path
	# into CardSurface and cannot show a card the game could not build.
	var plan: Array[Array] = []          # [[card id, recipe or ""], ...]
	if surfaces.is_empty():
		for id: String in ids:
			plan.append([id, ""])
	else:
		var base: String = ids[0] if not ids.is_empty() else "strike"
		for r: String in surfaces:
			if not CardSurface.RECIPES.has(r):
				push_warning("card lab: no such surface: %s" % r)
				print("card lab: no such surface: %s" % r)
				continue
			plan.append([base, r])
		_caption_h = 44.0

	# Cards are built here but NOT placed. Column count depends on the stage
	# width, and at zoom > 1 the window is resized in _ready() — after this runs.
	# Laying out now would size the grid to the pre-resize stage and show one card.
	var uid: int = 1
	for row: Array in plan:
		var id: String = row[0]
		var recipe: String = row[1]
		var data: Dictionary = _catalog.get(id, {})
		if recipe != "":
			data = data.duplicate()
			data["surface"] = recipe
		var inst: CardInst = CardInst.new(uid, StringName(id))
		# `cost` is present-but-null on the unplayable cards (burn, hex, wound),
		# so Dictionary.get's default never fires — it only covers a missing key.
		# Same read the domain does in combat.gd eff_cost().
		var cost_v: Variant = data.get("cost")
		var cost_num: int = 0 if cost_v == null else int(float(str(cost_v)))
		var card: CardView = CardView.new(inst, data, cost_num)
		card.pivot_offset = Vector2(CardView.CARD_W, CardView.CARD_H) * 0.5
		card.hover_changed.connect(_on_card_hover.bind(card))
		_sheet.add_child(card)
		_ordered.append(card)
		# The surfaces sheet is one card over and over, so a tier heading would
		# print the same word every row. Blank keeps _layout_sheet's grid plain.
		_tiers.append(str(data.get("rarity", "?")) if recipe == "" else "")
		if recipe != "":
			_captions.append(_spec_label(recipe))
		uid += 1
	# After the cards, so a caption is never drawn under the card beside it.
	for cap: Label in _captions:
		_sheet.add_child(cap)

	var caption: Label = Label.new()
	var scale_note: String = "1:1" if is_equal_approx(_zoom, 1.0) else "%d:1" % int(_zoom)
	caption.text = "card lab · %d cards · %s against roguecardv2@6e069118" % [
		plan.size(), scale_note] if surfaces.is_empty() \
		else "card surfaces · %s · %d materials · %s" % [
			plan[0][0] if not plan.is_empty() else "-", plan.size(), scale_note]
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.offset_top = -26
	caption.offset_bottom = -8
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)


## A recipe's spec sheet, read the way a print job would be quoted: the name,
## then the four layers it stacks, in the order card_surface.gd folds them.
static func _spec_label(recipe: String) -> Label:
	var stack: Array = CardSurface.RECIPES[recipe]
	var parts: PackedStringArray = PackedStringArray()
	for layer: Variant in stack:
		parts.append(str(layer))
	var cap: Label = Label.new()
	cap.text = "%s\n%s" % [recipe.to_upper(), " · ".join(parts)]
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Bounded to the card's own width, or a long stack runs under its neighbour
	# and the sheet reads as one caption for the wrong card.
	cap.custom_minimum_size = Vector2(CardView.CARD_W, 0.0)
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.add_theme_font_size_override("font_size", 9)
	cap.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cap


func _ready() -> void:
	_resize_for_zoom()
	# One frame for the resize to reach `size`, then place the cards against it.
	await get_tree().process_frame
	_layout_sheet()
	get_viewport().size_changed.connect(_layout_sheet)


func _resize_for_zoom() -> void:
	if is_equal_approx(_zoom, 1.0):
		return
	# Re-rasterise at the larger size rather than magnifying pixels.
	var win: Window = get_window()
	win.content_scale_factor = _zoom
	# Grow the window with the zoom, or the stage shrinks to 1180/zoom logical px
	# and a 3x sheet shows one card. Clamped to the usable screen — asking for
	# 3540x2460 on a smaller display just gets whatever fits, and the sheet
	# scrolls for the rest.
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(
		DisplayServer.window_get_current_screen())
	if usable.size.x <= 0 or usable.size.y <= 0:
		return  # headless / no display: content_scale_factor alone is enough
	var want: Vector2i = Vector2i(
		int(1180.0 * _zoom), int(820.0 * _zoom))
	var got: Vector2i = Vector2i(
		mini(want.x, usable.size.x - 40), mini(want.y, usable.size.y - 60))
	win.size = got
	win.position = usable.position + (usable.size - got) / 2


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
			_clamp_sheet()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_sheet.position += Vector2(step, 0.0) if mb.shift_pressed else Vector2(0.0, step)
			_clamp_sheet()
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and _panning:
		_sheet.position += mm.relative
		_clamp_sheet()


## Keep the sheet reachable: it may be dragged up to expose its tail, but never
## so far that every card leaves the stage and the lab looks empty.
func _clamp_sheet() -> void:
	var stage_h: float = float(get_window().size.y) / _zoom
	var min_y: float = minf(MARGIN, stage_h - _sheet_h - MARGIN)
	_sheet.position.y = clampf(_sheet.position.y, min_y, MARGIN)
	_sheet.position.x = clampf(_sheet.position.x, -_sheet_h, MARGIN * 4.0)
