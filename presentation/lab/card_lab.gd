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
##   godot --path . -- --cards --shot=/tmp/cards.png
##   godot --path . -- --cards=edge,ward,chisel --shot=/tmp/three.png
##
## Presentation-only and content-driven: it builds CardInst rows straight off
## ContentDB, so a card that renders here renders in a fight the same way.

const BACKDROP: Color = Color(0.043, 0.055, 0.102)   # #0B0E1A, the benchmark field
const GAP_X: float = 26.0
const GAP_Y: float = 34.0
const MARGIN: float = 40.0

var content: ContentDB


func _init(content_ref: ContentDB, only: PackedStringArray = PackedStringArray()) -> void:
	content = content_ref
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

	var grid: GridContainer = GridContainer.new()
	grid.columns = maxi(1, int((1180.0 - MARGIN * 2.0 + GAP_X) / (CardView.CARD_W + GAP_X)))
	grid.add_theme_constant_override("h_separation", int(GAP_X))
	grid.add_theme_constant_override("v_separation", int(GAP_Y))
	grid.position = Vector2(MARGIN, MARGIN)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid)

	var uid: int = 1
	for id: String in ids:
		var data: Dictionary = content.cards.get(id, {})
		var inst: CardInst = CardInst.new(uid, StringName(id))
		var cost_num: int = data.get("cost", 0)
		var card: CardView = CardView.new(inst, data, cost_num)
		# The lab is a contact sheet, not a hand: nothing here takes input.
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(card)
		uid += 1

	var caption: Label = Label.new()
	caption.text = "card lab · %d cards · 1:1 against roguecardv2@6e069118" % ids.size()
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.offset_top = -26
	caption.offset_bottom = -8
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
