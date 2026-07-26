class_name HudLab
extends Control
## The HUD bench: the combat chrome over an empty stage, with every number it
## takes on a slider. Drag hit points down and watch the rail, the plate and the
## numerals move together; pull ward up and the chip appears with the shield
## hanging off it; take the candles to zero and the whole orb goes cold.
##
## Why knobs and not a contact sheet: HudBar is the benchmark's whole chrome
## layer — top strip, energy bottom-left, piles in both corners, the END seal on
## the right — so it only reads at its real size, in its real corners, one state
## at a time. Six presets cover the states worth signing off; the sliders cover
## everything between them, which is where a layout actually breaks.
##
##   godot --path . -- --hud              # bench: sliders, presets, live HUD
##   tools/shot.sh --hud --state=2 --shot=/tmp/hud-2.png
##
## Captures go through tools/shot.sh and never carry --headless — a headless run
## has no viewport texture, so the capture hangs instead of failing.
##
## Keys: 1-6 presets · ←/→ cycle · H hides the panel · F flips the vial frame ·
## W flips the plate between the benchmark's 150px wrap and this port's 240px ·
## P drops the plate entirely, which is how the fight will run it if the hero
## actor carries its own — assembly's D2.
## A --shot run starts with the panel hidden, so a capture is the HUD alone.
##
## The stage under it is a stand-in for the battlefield — a night gradient and a
## warm floor pool — because the top bar has no edge of its own. It fades into
## whatever it sits on, and against flat black that fade is invisible.

const BACKDROP: Color = Color(0.043, 0.055, 0.102)
## Parked in the battlefield's dead centre-right: the chrome owns the four
## edges, so a panel anywhere else would cover the thing being judged.
const PANEL_RECT: Rect2 = Rect2(380.0, 70.0, 300.0, 560.0)

## caption, hp, max_hp, ward, gold, energy, max_energy, draw, discard, ashes,
## hand, charge.
## The last row is not a real fight — it is the layout's failure case, three
## digits everywhere at once, which is the only way to see what overflows.
const STATES: Array = [
	["full HP · turn 1", 72, 72, 0, 99, 3, 3, 5, 0, 0, 5, 0],
	["5% HP · one hit left", 4, 80, 0, 42, 1, 3, 2, 7, 1, 3, 1],
	["heavy ward", 41, 80, 32, 42, 2, 3, 3, 6, 2, 4, 0],
	["0 energy · turn spent", 41, 80, 12, 42, 0, 3, 0, 10, 3, 0, 2],
	["every candle lit · art ready", 62, 80, 0, 128, 5, 5, 5, 3, 4, 6, 3],
	["big numbers", 999, 999, 999, 999, 6, 6, 99, 99, 99, 99, 9],
]

## name, floor, ceiling — the ten values in set_values order, then the lantern's
## charge, which rides its own setter.
const KNOBS: Array = [
	["hit points", 0, 999], ["max hit points", 1, 999],
	["ward", 0, 999], ["gold", 0, 999],
	["energy", 0, 9], ["max energy", 1, 9],
	["draw pile", 0, 99], ["discard pile", 0, 99], ["ash pile", 0, 99],
	["hand", 0, 99],
	["art charge", 0, 9],
]

var content: ContentDB

var _hud: HudBar
var _panel: PanelContainer
var _status: Label
var _readout: Label
var _knobs: Array[HSlider] = []
var _labels: Array[Label] = []
var _vals: Array[int] = [72, 72, 0, 99, 3, 3, 5, 0, 0, 5, 0]
var _state: int = 0
var _frame: bool = true
var _wide: bool = true
var _plate: bool = true


func _init(content_ref: ContentDB) -> void:
	content = content_ref
	var shooting: bool = false
	var force_panel: bool = false  # --panel: capture the bench itself, controls and all
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--state="):
			_state = clampi(int(arg.trim_prefix("--state=")), 0, STATES.size() - 1)
		elif arg.begins_with("--shot="):
			shooting = true
		elif arg == "--panel":
			force_panel = true
		elif arg == "--noframe":
			_frame = false  # the plate's rail bare, as the benchmark ships it
		elif arg == "--narrow":
			_wide = false  # the plate at the benchmark's own 150px wrap
		elif arg == "--noplate":
			_plate = false  # the chrome without it, as the fight may run it
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()

	_build_stage()
	_rebuild_hud()
	_panel = _build_panel()
	add_child(_panel)
	_panel.visible = force_panel or not shooting

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	_status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.offset_top = -22
	_status.offset_bottom = -6
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)

	_load_state(_state)


## A mock battlefield: the night gradient the combat screen runs, a warm pool
## where the lantern light falls. None of it is HudBar's — it is here so the
## bar's downward fade and the outlined numerals are judged against something,
## the way they will be judged in a fight.
func _build_stage() -> void:
	var field: ColorRect = ColorRect.new()
	field.color = BACKDROP
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)

	var night: TextureRect = TextureRect.new()
	night.texture = GlassStyle.grad_tex(
		PackedColorArray([GlassStyle.NIGHT_TOP, GlassStyle.NIGHT_MID, GlassStyle.NIGHT_BOT]),
		PackedFloat32Array([0.0, 0.55, 1.0]), false, Vector2(0.5, 0.0), Vector2(0.5, 1.0))
	night.set_anchors_preset(Control.PRESET_FULL_RECT)
	night.stretch_mode = TextureRect.STRETCH_SCALE
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night)

	var pool: TextureRect = TextureRect.new()
	pool.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(1.0, 0.62, 0.30, 0.16), Color(1.0, 0.55, 0.25, 0.0)]),
		PackedFloat32Array([0.0, 1.0]), true, Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	pool.anchor_left = 0.08
	pool.anchor_right = 0.92
	pool.anchor_top = 0.30
	pool.anchor_bottom = 0.95
	pool.stretch_mode = TextureRect.STRETCH_SCALE
	pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pool)


## Both plate flags are constructor arguments, so flipping either is a new
## widget. Kept under the panel in the draw order — the chrome owns the edges,
## the panel the middle, and a rebuilt HUD must not jump in front of the
## controls.
func _rebuild_hud() -> void:
	if _hud != null:
		remove_child(_hud)
		_hud.queue_free()
	_hud = HudBar.new(_frame, _wide, _plate)
	add_child(_hud)
	move_child(_hud, 3)
	_hud.end_turn_pressed.connect(_on_pressed.bind("end turn"))
	_hud.menu_pressed.connect(_on_pressed.bind("menu"))
	_hud.deck_pressed.connect(_on_pressed.bind("deck"))
	_hud.lantern_pressed.connect(_on_pressed.bind("lantern"))
	_hud.pile_pressed.connect(func(pile: StringName) -> void: _on_pressed(str(pile)))
	_apply()


# ---------------------------------------------------------------- panel

func _build_panel() -> PanelContainer:
	var frame: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.06, 0.94)
	sb.border_color = Color(GlassStyle.GLASS.r, GlassStyle.GLASS.g, GlassStyle.GLASS.b, 0.20)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	frame.add_theme_stylebox_override("panel", sb)
	frame.position = PANEL_RECT.position
	frame.size = PANEL_RECT.size

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	col.add_child(_caption(
		"1-6 · ←/→ cycle · H panel · F frame · W plate width · P plate on/off"))
	col.add_child(_heading("STATES"))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	for i: int in range(STATES.size()):
		var row: Array = STATES[i]
		var b: Button = Button.new()
		b.text = "%d · %s" % [i + 1, str(row[0])]
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 11)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		GlassStyle.style_button(b, GlassStyle.GLASS)
		b.pressed.connect(_load_state.bind(i))
		grid.add_child(b)

	# The frame switch and the readout sit ABOVE the sliders on purpose: nine
	# knobs are taller than the panel, and the two things you reach for while
	# dragging must not be the two things that scrolled off.
	col.add_child(_heading("PLATE"))
	var box: CheckBox = CheckBox.new()
	box.text = "hp-vial-frame on the rail"
	box.button_pressed = _frame
	box.add_theme_font_size_override("font_size", 11)
	box.toggled.connect(func(on: bool) -> void:
		_frame = on
		_rebuild_hud())
	col.add_child(box)
	# The A/B the decision is waiting on: 240px with the vial's length locked,
	# against the benchmark's own 150px wrap where the ward chip eats into it.
	var wide_box: CheckBox = CheckBox.new()
	wide_box.text = "wide plate (240px) · off = benchmark 150px"
	wide_box.button_pressed = _wide
	wide_box.add_theme_font_size_override("font_size", 11)
	wide_box.toggled.connect(func(on: bool) -> void:
		_wide = on
		_rebuild_hud())
	col.add_child(wide_box)
	# Assembly's D2: if the hero actor carries its own `.cplate`, the HUD must
	# not carry a second one. This is what the chrome looks like without it.
	var plate_box: CheckBox = CheckBox.new()
	plate_box.text = "plate at all · off = the actor owns it"
	plate_box.button_pressed = _plate
	plate_box.add_theme_font_size_override("font_size", 11)
	plate_box.toggled.connect(func(on: bool) -> void:
		_plate = on
		_rebuild_hud())
	col.add_child(plate_box)

	# What the eight sliders currently spell, in the shape the widget takes it —
	# so a pose worth keeping can be typed straight into STATES.
	_readout = _caption("")
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_readout)

	col.add_child(_heading("VALUES"))
	for i: int in range(KNOBS.size()):
		_build_knob(col, i)
	return frame


## One value, one slider, its number in the label above it. The label is
## rewritten on drag rather than bound, because a Label per frame is cheaper
## than a signal round trip through the whole widget.
func _build_knob(col: VBoxContainer, i: int) -> void:
	var spec: Array = KNOBS[i]
	var lo: int = spec[1]
	var hi: int = spec[2]
	var tag: String = str(spec[0])
	var cap: Label = _caption("%s — %d" % [tag, _vals[i]])
	col.add_child(cap)
	var s: HSlider = HSlider.new()
	s.min_value = float(lo)
	s.max_value = float(hi)
	s.step = 1.0
	s.value = float(_vals[i])
	s.custom_minimum_size = Vector2(0.0, 16.0)
	s.value_changed.connect(func(v: float) -> void:
		_vals[i] = int(v)
		cap.text = "%s — %d" % [tag, int(v)]
		_apply())
	_knobs.append(s)
	_labels.append(cap)
	col.add_child(s)


static func _heading(text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", GlassStyle.EMBER)
	return l


static func _caption(text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	return l


# ---------------------------------------------------------------- drive

## Hand the widget what the sliders say. Hit points and energy are clamped to
## their own ceilings here rather than in the sliders, so dragging max down
## drags the current value with it instead of leaving an impossible pose.
func _apply() -> void:
	var hp: int = mini(_vals[0], _vals[1])
	var energy: int = mini(_vals[4], _vals[5])
	_hud.set_values(hp, _vals[1], _vals[2], _vals[3], energy, _vals[5], _vals[6],
		_vals[7], _vals[8], _vals[9])
	_hud.set_lantern(_vals[10], _vals[10] > 0)
	_hud.set_title("The Ashen Woods", "Floor I · The Rootheart")
	if _readout != null:
		_readout.text = "set_values(%d, %d, %d, %d, %d, %d, %d, %d, %d, %d)" % [
			hp, _vals[1], _vals[2], _vals[3], energy, _vals[5], _vals[6], _vals[7],
			_vals[8], _vals[9]]


func _load_state(i: int) -> void:
	_state = posmod(i, STATES.size())
	var row: Array = STATES[_state]
	for k: int in range(KNOBS.size()):
		var v: int = row[k + 1]
		_vals[k] = v
		if k < _knobs.size():
			# no_signal, or nine slider callbacks each fire a full _apply()
			_knobs[k].set_value_no_signal(float(v))
			_labels[k].text = "%s — %d" % [str(KNOBS[k][0]), v]
	_apply()
	if _caption != null:
		_status.text = "hud lab · state %d/%d · %s · vial frame %s · plate %s%s" % [
			_state + 1, STATES.size(), str(row[0]), "on" if _frame else "off",
			"240 wide" if _wide else "150 benchmark",
			"" if _plate else " · no plate"]


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_RIGHT:
		_load_state(_state + 1)
	elif key.keycode == KEY_LEFT:
		_load_state(_state - 1)
	elif key.keycode >= KEY_1 and key.keycode <= KEY_6:
		_load_state(key.keycode - KEY_1)
	elif key.keycode == KEY_H:
		_panel.visible = not _panel.visible
	elif key.keycode == KEY_F:
		_frame = not _frame
		_rebuild_hud()
		_load_state(_state)
	elif key.keycode == KEY_W:
		_wide = not _wide
		_rebuild_hud()
		_load_state(_state)
	elif key.keycode == KEY_P:
		_plate = not _plate
		_rebuild_hud()
		_load_state(_state)


## The bench has nothing behind the buttons, so it says what it received. That
## is the point of the wiring being signals: assembly connects the same five.
func _on_pressed(what: String) -> void:
	print("hud lab: %s pressed" % what)
