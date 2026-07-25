class_name ChipLab
extends Control
## Contact sheet for the two chip widgets, at the size they ship.
##
##   godot --path . -- --chips [--shot=/tmp/chips.png]
##
## No shell variants: the web benchmark settles both designs, and it settles
## them differently — the status chip has no shell at all, the intent chip is a
## dark lozenge lit by one colour. This sheet exists to check the PORT, not to
## audition alternatives.
##
## Counts run 1 / 2 / 9 / 99 because 1 is the case that draws no numeral and 2
## is the first that does — the interesting boundary is between them, not at 9.

## #0B0E1A, the benchmark's --ink. Held locally rather than reached out of
## CardLab: four sessions share this tree, and importing one Color from a card
## file chains this sheet to that file's compile state.
const BACKDROP: Color = Color(0.043, 0.055, 0.102)

## The status row does NOT sit on flat indigo in the real game — it sits under
## the enemy, over lit stone, lanterns and sprites. That is why the outline is
## black. These are the grounds worth proving it against.
const GROUNDS: Array[Color] = [
	Color(0.043, 0.055, 0.102),   # --ink, the panel case
	Color(0.24, 0.21, 0.20),      # shadowed stone
	Color(0.46, 0.38, 0.28),      # lantern-lit stone, the worst case
]
const GROUND_NAMES: Array[String] = ["--ink", "shadowed stone", "lantern-lit"]

const MARGIN: float = 36.0
const COLS: int = 4
const CELL_W: float = 272.0
const CELL_H: float = 58.0
const CHIP_GAP: float = 6.0          ## .status-row { gap: 6px }
const DETAIL_ZOOM: float = 3.0

const COUNTS: Array[int] = [1, 2, 9, 99]

## Five faces plus the three compound ids content actually ships. The compounds
## render TWO icons, so they belong on the sheet as their own case.
const INTENT_ROW: Array[Array] = [
	["attack", "12"],
	["block", "9"],
	["buff", ""],
	["debuff", "2"],
	["heal", "6"],
	["attack_block", "7"],
	["attack_debuff", "4×2"],
]

var content: ContentDB


func _init(content_ref: ContentDB) -> void:
	content = content_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()

	var field: ColorRect = ColorRect.new()
	field.color = BACKDROP
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)

	var y: float = MARGIN
	y = _title("CHIPS — benchmark port", y)
	y = _section("STATUSES · stacks 1 / 2 / 9 / 99 · 1 draws no numeral · actual size", y)
	y = _status_grid(y)
	y = _section("SAME CHIPS OVER LIT GROUND · the black outline is what has to hold", y)
	y = _ground_strip(y)
	y = _section("INTENTS · last two are compound: two icons, primary's colour", y)
	y = _intent_row(y)
	y = _section("DETAIL ×%d · not shipping size" % int(DETAIL_ZOOM), y)
	_detail_strip(y)


func _title(text: String, y: float) -> float:
	var lab: Label = Label.new()
	lab.text = text
	lab.add_theme_font_override("font", StatusChip.numeral_font())
	lab.add_theme_font_size_override("font_size", 21)
	lab.add_theme_color_override("font_color", GlassStyle.TEXT)
	lab.position = Vector2(MARGIN, y)
	add_child(lab)
	return y + 34.0


func _section(text: String, y: float) -> float:
	var lab: Label = Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", 12)
	lab.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	lab.position = Vector2(MARGIN, y)
	add_child(lab)
	return y + 24.0


## Cast at the boundary, once — content rows arrive as Variant.
func _info(id: StringName) -> Dictionary:
	var row: Dictionary = content.statuses.get(id, {})
	return row


func _display_name(id: StringName) -> String:
	return str(_info(id).get("name", id))


## Ordered by display name, the way the player meets them — the internal ids
## (`str` is Fervor, `vulnerable` is Cracked) sort into nonsense.
func _status_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for k: Variant in content.statuses.keys():
		ids.append(StringName(str(k)))
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return _display_name(a).naturalnocasecmp_to(_display_name(b)) < 0)
	return ids


func _status_grid(y: float) -> float:
	var col: int = 0
	var row_y: float = y
	for id: StringName in _status_ids():
		var cell_x: float = MARGIN + float(col) * CELL_W

		var name_label: Label = Label.new()
		name_label.text = "%s  ·  %s" % [_display_name(id), id]
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
		name_label.position = Vector2(cell_x, row_y)
		add_child(name_label)

		var chip_x: float = cell_x
		for n: int in COUNTS:
			var chip: StatusChip = StatusChip.new(id, n, _info(id))
			chip.position = Vector2(chip_x, row_y + 16.0)
			add_child(chip)
			chip_x += StatusChip.SIZE + CHIP_GAP
		col += 1
		if col >= COLS:
			col = 0
			row_y += CELL_H
	if col > 0:
		row_y += CELL_H
	return row_y + 6.0


## Four representative statuses repeated over each ground, so a black silhouette
## outline can be judged where it is actually hard: on lit stone.
func _ground_strip(y: float) -> float:
	var sample: Array[StringName] = [&"vulnerable", &"regen", &"poison", &"barricade"]
	var swatch_w: float = 4.0 * (StatusChip.SIZE + CHIP_GAP) + 20.0
	for g: int in range(GROUNDS.size()):
		var x: float = MARGIN + float(g) * (swatch_w + 26.0)
		var plate: ColorRect = ColorRect.new()
		plate.color = GROUNDS[g]
		plate.position = Vector2(x, y)
		plate.size = Vector2(swatch_w, StatusChip.SIZE + 20.0)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(plate)

		var cap: Label = Label.new()
		cap.text = GROUND_NAMES[g]
		cap.add_theme_font_size_override("font_size", 10)
		cap.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
		cap.position = Vector2(x, y + StatusChip.SIZE + 22.0)
		add_child(cap)

		var cx: float = x + 10.0
		for id: StringName in sample:
			var chip: StatusChip = StatusChip.new(id, 9, _info(id))
			chip.position = Vector2(cx, y + 10.0)
			add_child(chip)
			cx += StatusChip.SIZE + CHIP_GAP
	return y + StatusChip.SIZE + 46.0


func _intent_row(y: float) -> float:
	var x: float = MARGIN
	for spec: Array in INTENT_ROW:
		var intent: StringName = StringName(str(spec[0]))
		var chip: IntentChip = IntentChip.new(intent, str(spec[1]))
		chip.position = Vector2(x, y)
		add_child(chip)

		var cap: Label = Label.new()
		cap.text = String(intent)
		cap.add_theme_font_size_override("font_size", 10)
		cap.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
		cap.position = Vector2(x, y + IntentChip.HEIGHT + 6.0)
		add_child(cap)
		# +20 on the left of each step: the icon breaks out past the chip's own
		# rect, so laying these out by width alone would overlap them.
		x += maxf(chip.size.x, 86.0) + 30.0
	return y + IntentChip.HEIGHT + 30.0


## The two boundary cases blown up: a status with and without its numeral, and a
## compound intent showing both faces.
func _detail_strip(y: float) -> void:
	var holder: Control = Control.new()
	holder.position = Vector2(MARGIN + 20.0, y)
	holder.scale = Vector2(DETAIL_ZOOM, DETAIL_ZOOM)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	var x: float = 0.0
	x = _detail_chip(holder, &"vulnerable", 1, x)
	x = _detail_chip(holder, &"vulnerable", 99, x)
	x = _detail_chip(holder, &"regen", 9, x)
	var intent: IntentChip = IntentChip.new(&"attack_block", "4×2")
	intent.position = Vector2(x + 8.0, 0.0)
	holder.add_child(intent)


func _detail_chip(holder: Control, id: StringName, count: int, x: float) -> float:
	var chip: StatusChip = StatusChip.new(id, count, _info(id))
	chip.position = Vector2(x, 0.0)
	holder.add_child(chip)
	return x + StatusChip.SIZE + CHIP_GAP
