class_name ChipLab
extends Control
## Interactive bench for the two chip widgets. Not a contact sheet — the chips
## here are the real Controls, so what you tune is what ships.
##
##   godot --path . -- --chips                  # the viewer
##   godot --path . -- --chips --shot=/tmp/c.png  # same sheet, panel hidden
##
## WHAT YOU CAN DO
##   · click any status in the grid to load it into the inspector
##   · hover any chip for its name and rules text
##   · drag GROUND through the four surfaces these have to hold against
##   · drag the KNOBS — they are the five layers CSS does with blurs and Godot
##     cannot, so their values are judgement calls, not measurements
##   · BAKE prints the current knobs as GDScript, ready to paste back into the
##     widgets as new DEFAULTs
##
## The knobs are statics on the chip classes, so a drag here retunes every chip
## on screen at once — which is the point. Nothing is persisted; BAKE is how a
## setting leaves this window.

const BACKDROP: Color = Color(0.043, 0.055, 0.102)

## The status row does NOT sit on flat indigo in the real game — it sits under
## the enemy, over lit stone and lanterns. That is why its outline is black, and
## why judging these on one ground is how you ship an invisible chip.
const GROUNDS: Array[Color] = [
	Color(0.043, 0.055, 0.102),   # --ink, the panel case
	Color(0.24, 0.21, 0.20),      # shadowed stone
	Color(0.46, 0.38, 0.28),      # lantern-lit stone
	Color(0.72, 0.70, 0.66),      # blown highlight, the worst case
]
const GROUND_NAMES: Array[String] = ["--ink", "shadowed stone", "lantern-lit", "blown"]

const PANEL_W: float = 330.0
const MARGIN: float = 24.0
const COLS: int = 3
const CELL_W: float = 270.0
const CELL_H: float = 56.0
const CHIP_GAP: float = 6.0          ## .status-row { gap: 6px }
const INSPECT_TOP: float = 60.0
const INSPECT_H: float = 176.0

const COUNTS: Array[int] = [1, 2, 9, 99]

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

var _field: ColorRect
var _sheet: Control                  ## everything that gets rebuilt on a change
var _panel: PanelContainer
var _ground: int = 0
var _zoom: float = 3.0
var _sel_id: StringName = &"vulnerable"
var _sel_count: int = 99
## Click targets for the status grid, filled during the rebuild.
var _cells: Array[Dictionary] = []


func _init(content_ref: ContentDB) -> void:
	content = content_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	# STOP, not IGNORE: the chips are MOUSE_FILTER_PASS so their clicks arrive
	# here, at the parent, which is what makes the grid selectable without
	# covering every cell in an invisible Button and killing the tooltips.
	mouse_filter = Control.MOUSE_FILTER_STOP

	_field = ColorRect.new()
	_field.color = GROUNDS[_ground]
	_field.set_anchors_preset(Control.PRESET_FULL_RECT)
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_field)

	_sheet = Control.new()
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sheet)

	# Args are read BEFORE the panel is built, not after. The panel paints the
	# selected treatment in ember, and building it first meant --style= landed
	# after the buttons had already decided which of them was lit — the sheet
	# said CABOCHON while the panel said BENCH.
	#
	# --sheet drops the furniture for a clean contact sheet. A plain --shot
	# captures the viewer as you see it, because the panel is the point now.
	# --ground=N picks the surface, so a headless capture can check the one
	# thing a still frame otherwise cannot: that the outline holds on stone.
	var hide_panel: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--sheet":
			hide_panel = true
		elif arg.begins_with("--ground="):
			_ground = clampi(int(arg.trim_prefix("--ground=")), 0, GROUNDS.size() - 1)
			_field.color = GROUNDS[_ground]
		elif arg.begins_with("--style="):
			var key: String = arg.trim_prefix("--style=")
			if STYLES.has(key):
				StatusChip.style = STYLES[key]
			else:
				print("chip lab: no such style: %s — have %s"
					% [key, ", ".join(PackedStringArray(STYLES.keys()))])
	_build_panel()
	_panel.visible = not hide_panel
	_rebuild()


## `--style=setting|lamp|cabochon` picks a treatment past the port. Default stays
## BENCH so every shot taken before this existed still reproduces exactly.
const STYLES: Dictionary = {
	"bench": StatusChip.Style.BENCH,
	"setting": StatusChip.Style.SETTING,
	"lamp": StatusChip.Style.LAMP,
	"cabochon": StatusChip.Style.CABOCHON,
}


const STYLE_NOTES: Dictionary = {
	"bench": "the ported chip, unchanged — the floor everything is diffed against",
	"setting": "art seated in lead, lit from behind. brass came = boon, cold iron = affliction",
	"lamp": "no shell. boons burn warm and reach further as they stack; afflictions take light",
	"cabochon": "status_gem.gdshader — an analytic dome lit by the room's lamp",
}


static func style_name() -> String:
	for k: String in STYLES:
		if StatusChip.style == STYLES[k]:
			return k
	return "bench"


## The panel is rebuilt rather than just re-tinted, because the selected button
## carries the ember and every other one has to give it up.
func _set_style(key: String) -> void:
	if not STYLES.has(key):
		return
	StatusChip.style = STYLES[key]
	_rebuild_panel()


# ---------------------------------------------------------------- control panel

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", GlassStyle.pane(GlassStyle.GLASS, 0.92))
	_panel.position = Vector2(1180.0 - PANEL_W, 0.0)
	_panel.size = Vector2(PANEL_W, 820.0)
	add_child(_panel)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	_panel.add_child(col)

	_heading(col, "GROUND")
	var grounds: HBoxContainer = HBoxContainer.new()
	grounds.add_theme_constant_override("separation", 4)
	col.add_child(grounds)
	for g: int in range(GROUNDS.size()):
		var b: Button = Button.new()
		b.text = str(g + 1)
		b.tooltip_text = GROUND_NAMES[g]
		b.custom_minimum_size = Vector2(40.0, 26.0)
		b.focus_mode = Control.FOCUS_NONE
		GlassStyle.style_button(b, GlassStyle.GLASS)
		b.pressed.connect(func() -> void:
			_ground = g
			_field.color = GROUNDS[_ground]
			_rebuild())
		grounds.add_child(b)

	# The treatment picker. Flipping between the four is the whole point of the
	# bench right now, and relaunching to compare them makes the differences
	# impossible to actually see — the eye needs them back to back, not a
	# minute apart.
	_heading(col, "TREATMENT")
	var styles: VBoxContainer = VBoxContainer.new()
	styles.add_theme_constant_override("separation", 4)
	col.add_child(styles)
	var pair: HBoxContainer = null
	var n: int = 0
	for key: String in STYLES:
		if n % 2 == 0:
			pair = HBoxContainer.new()
			pair.add_theme_constant_override("separation", 4)
			styles.add_child(pair)
		var sb: Button = Button.new()
		sb.text = key.to_upper()
		sb.custom_minimum_size = Vector2(140.0, 28.0)
		sb.focus_mode = Control.FOCUS_NONE
		sb.tooltip_text = str(STYLE_NOTES.get(key, ""))
		# The selected one takes the ember, so the panel always says which
		# treatment you are looking at — the sheet's title alone is too far
		# from the buttons to answer that while you are clicking.
		var on: bool = StatusChip.style == STYLES[key]
		GlassStyle.style_button(sb, GlassStyle.EMBER if on else GlassStyle.GLASS)
		sb.pressed.connect(_set_style.bind(key))
		pair.add_child(sb)
		n += 1

	_heading(col, "INSPECTOR")
	_slider(col, "zoom", 1.0, 5.0, 0.5, _zoom, func(v: float) -> void:
		_zoom = v
		_rebuild())
	_slider(col, "count", 1.0, 99.0, 1.0, float(_sel_count), func(v: float) -> void:
		_sel_count = int(v)
		_rebuild())

	_heading(col, "STATUS KNOBS")
	_slider(col, "outline px", 0.0, 3.0, 0.1, StatusChip.outline_px, func(v: float) -> void:
		StatusChip.outline_px = v
		_rebuild())
	_slider(col, "numeral ring", 0.0, 8.0, 1.0, float(StatusChip.num_outline),
		func(v: float) -> void:
			StatusChip.num_outline = int(v)
			_rebuild())

	_heading(col, "INTENT KNOBS")
	_slider(col, "halo alpha", 0.0, 0.8, 0.02, IntentChip.glow_out, func(v: float) -> void:
		IntentChip.glow_out = v
		_rebuild())
	_slider(col, "halo size", 0.0, 24.0, 1.0, float(IntentChip.glow_size),
		func(v: float) -> void:
			IntentChip.glow_size = int(v)
			_rebuild())
	_slider(col, "inset glow", 0.0, 0.5, 0.01, IntentChip.glow_in, func(v: float) -> void:
		IntentChip.glow_in = v
		_rebuild())
	_slider(col, "icon rim", 0.0, 4.0, 0.1, IntentChip.icon_rim, func(v: float) -> void:
		IntentChip.icon_rim = v
		_rebuild())
	_slider(col, "numeral bloom", 0.0, 10.0, 1.0, float(IntentChip.num_outline),
		func(v: float) -> void:
			IntentChip.num_outline = int(v)
			_rebuild())

	col.add_child(HSeparator.new())
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	var reset: Button = Button.new()
	reset.text = "RESET"
	reset.focus_mode = Control.FOCUS_NONE
	reset.tooltip_text = "back to the shipped DEFAULTs"
	GlassStyle.style_button(reset, GlassStyle.TEXT_DIM)
	reset.pressed.connect(func() -> void:
		StatusChip.reset_knobs()
		IntentChip.reset_knobs()
		_rebuild_panel())
	row.add_child(reset)
	var bake: Button = Button.new()
	bake.text = "BAKE"
	bake.focus_mode = Control.FOCUS_NONE
	bake.tooltip_text = "print the current knobs to stdout as GDScript"
	GlassStyle.style_button(bake, GlassStyle.EMBER)
	bake.pressed.connect(_bake)
	row.add_child(bake)


## RESET has to move the slider handles too, and a slider's own signal would
## fire back into the knob it is being restored from. Cheapest correct answer:
## drop the panel and build a fresh one off the reset values.
func _rebuild_panel() -> void:
	_panel.queue_free()
	_build_panel()
	_rebuild()


func _heading(col: VBoxContainer, text: String) -> void:
	var lab: Label = Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", 11)
	lab.add_theme_color_override("font_color", GlassStyle.EMBER)
	col.add_child(lab)


func _slider(col: VBoxContainer, name_text: String, lo: float, hi: float, step: float,
		value: float, on_change: Callable) -> void:
	var cap: Label = Label.new()
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	cap.text = "%s  %s" % [name_text, _fmt(value, step)]
	col.add_child(cap)

	var s: HSlider = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(0.0, 16.0)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(v: float) -> void:
		cap.text = "%s  %s" % [name_text, _fmt(v, step)]
		on_change.call(v))
	col.add_child(s)


func _fmt(v: float, step: float) -> String:
	return str(roundi(v)) if step >= 1.0 else "%.2f" % v


func _bake() -> void:
	var lines: PackedStringArray = PackedStringArray([
		"",
		"--- status_chip.gd ---",
		"const OUTLINE_PX_DEFAULT: float = %.2f" % StatusChip.outline_px,
		"const NUM_OUTLINE_DEFAULT: int = %d" % StatusChip.num_outline,
		"--- intent_chip.gd ---",
		"const GLOW_OUT_DEFAULT: float = %.2f" % IntentChip.glow_out,
		"const GLOW_SIZE_DEFAULT: int = %d" % IntentChip.glow_size,
		"const GLOW_IN_DEFAULT: float = %.2f" % IntentChip.glow_in,
		"const ICON_RIM_DEFAULT: float = %.2f" % IntentChip.icon_rim,
		"const NUM_OUTLINE_DEFAULT: int = %d" % IntentChip.num_outline,
		"",
	])
	print("\n".join(lines))


# ------------------------------------------------------------------- selection

## 1-4 flip the treatment, G cycles the ground. Unhandled rather than _gui_input
## because the sheet does not take focus and the panel's buttons would eat the
## key the moment one of them had been clicked.
func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var order: PackedStringArray = PackedStringArray(STYLES.keys())
	var idx: int = k.keycode - KEY_1
	if idx >= 0 and idx < order.size():
		accept_event()
		_set_style(order[idx])
	elif k.keycode == KEY_G:
		accept_event()
		_ground = (_ground + 1) % GROUNDS.size()
		_field.color = GROUNDS[_ground]
		_rebuild()


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	for cell: Dictionary in _cells:
		var r: Rect2 = cell["rect"]
		if r.has_point(click.position):
			_sel_id = StringName(str(cell["id"]))
			_rebuild()
			return


# --------------------------------------------------------------------- rebuild

func _rebuild() -> void:
	for child: Node in _sheet.get_children():
		child.queue_free()
	_cells.clear()

	_title("CHIPS — %s · click a status to inspect it" % style_name().to_upper())
	_inspector()
	var y: float = _section("STATUSES · 1 / 2 / 9 / 99 · 1 draws no numeral · actual size",
		INSPECT_TOP + INSPECT_H)
	y = _status_grid(y)
	y = _section("INTENTS · last two are compound: two icons, primary's colour", y)
	_intent_row(y)


func _add(node: Control) -> void:
	_sheet.add_child(node)


func _title(text: String) -> void:
	var lab: Label = Label.new()
	lab.text = text
	lab.add_theme_font_override("font", StatusChip.numeral_font())
	lab.add_theme_font_size_override("font_size", 19)
	lab.add_theme_color_override("font_color", GlassStyle.TEXT)
	lab.position = Vector2(MARGIN, MARGIN)
	_add(lab)


func _section(text: String, y: float) -> float:
	var lab: Label = Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", 11)
	lab.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	lab.position = Vector2(MARGIN, y)
	_add(lab)
	return y + 22.0


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


## The selected status and a compound intent, blown up on the current ground —
## the only place in this window where anything is drawn off-size.
func _inspector() -> void:
	# No plate behind the specimens: the GROUND buttons repaint the whole field,
	# so the whole window IS the test surface — grid included.
	var cap: Label = Label.new()
	cap.text = "%s · %s · ×%.1f · %s" % [_display_name(_sel_id), _sel_id, _zoom,
		GROUND_NAMES[_ground]]
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	cap.position = Vector2(MARGIN, INSPECT_TOP + INSPECT_H - 22.0)
	_add(cap)

	var holder: Control = Control.new()
	holder.position = Vector2(MARGIN + 18.0, INSPECT_TOP + 16.0)
	holder.scale = Vector2(_zoom, _zoom)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(holder)

	# Count 1 alongside the chosen count: the no-numeral case is the one most
	# easily broken by a knob, so it stays on screen next to its sibling.
	var x: float = 0.0
	var shown: Array[int] = [1, _sel_count]
	for n: int in shown:
		var chip: StatusChip = StatusChip.new(_sel_id, n, _info(_sel_id))
		chip.position = Vector2(x, 0.0)
		holder.add_child(chip)
		x += StatusChip.SIZE + CHIP_GAP
	var intent: IntentChip = IntentChip.new(&"attack_block", "4×2")
	intent.position = Vector2(x + 14.0, 0.0)
	holder.add_child(intent)


func _status_grid(y: float) -> float:
	var col: int = 0
	var row_y: float = y
	for id: StringName in _status_ids():
		var cell_x: float = MARGIN + float(col) * CELL_W
		var chips_w: float = float(COUNTS.size()) * (StatusChip.SIZE + CHIP_GAP)
		_cells.append({
			"id": id,
			"rect": Rect2(Vector2(cell_x, row_y), Vector2(chips_w, CELL_H - 4.0)),
		})

		var name_label: Label = Label.new()
		name_label.text = "%s  ·  %s" % [_display_name(id), id]
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color",
			GlassStyle.EMBER if id == _sel_id else GlassStyle.TEXT_DIM)
		name_label.position = Vector2(cell_x, row_y)
		_add(name_label)

		var chip_x: float = cell_x
		for n: int in COUNTS:
			var chip: StatusChip = StatusChip.new(id, n, _info(id))
			chip.position = Vector2(chip_x, row_y + 16.0)
			_add(chip)
			chip_x += StatusChip.SIZE + CHIP_GAP
		col += 1
		if col >= COLS:
			col = 0
			row_y += CELL_H
	if col > 0:
		row_y += CELL_H
	return row_y + 4.0


func _intent_row(y: float) -> void:
	var x: float = MARGIN
	for spec: Array in INTENT_ROW:
		var intent: StringName = StringName(str(spec[0]))
		var chip: IntentChip = IntentChip.new(intent, str(spec[1]))
		chip.position = Vector2(x, y)
		_add(chip)

		var cap: Label = Label.new()
		cap.text = String(intent)
		cap.add_theme_font_size_override("font_size", 10)
		cap.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
		cap.position = Vector2(x, y + IntentChip.HEIGHT + 6.0)
		_add(cap)
		# The icon breaks out past the chip's own rect, so stepping by width
		# alone would overlap them.
		x += maxf(chip.size.x, 84.0) + 24.0
