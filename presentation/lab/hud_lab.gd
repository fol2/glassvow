class_name HudLab
extends Control
## The HUD bench: the combat chrome over an empty stage, posed one state at a
## time — full, nearly dead, buried in ward, out of candles, and the three-digit
## case that decides whether the layout holds.
##
## One state per screen, not a stack of rows: HudBar is the benchmark's whole
## chrome layer (top strip, energy bottom-left, piles in both corners, the END
## seal on the right), so it only reads at its real size, in its real corners.
##
##   godot --path . -- --hud                            # window; 1-6 or ←/→ switch
##   godot --path . -- --hud --state=2 --shot=/tmp/hud-2.png
##
## The stage under it is a stand-in for the battlefield — a night gradient and a
## warm floor pool — because the top bar has no edge of its own. It fades into
## whatever it sits on, and against flat black that fade is invisible.

const MARGIN: float = 20.0

## caption, hp, max_hp, block, gold, energy, max_energy, draw, discard, charges.
## The last row is not a real fight — it is the layout's failure case, three
## digits everywhere at once, which is the only way to see what overflows.
const STATES: Array = [
	["full HP · turn 1", 72, 72, 0, 99, 3, 3, 5, 0, 0],
	["5% HP · one hit left", 4, 80, 0, 42, 1, 3, 2, 7, 1],
	["heavy ward", 41, 80, 32, 42, 2, 3, 3, 6, 0],
	["0 energy · turn spent", 41, 80, 12, 42, 0, 3, 0, 10, 2],
	["every candle lit · art ready", 62, 80, 0, 128, 5, 5, 5, 3, 3],
	["big numbers", 999, 999, 999, 999, 6, 6, 99, 99, 9],
]

var content: ContentDB

var _hud: HudBar
var _caption: Label
var _state: int = 0
var _vial_frame: bool = true


func _init(content_ref: ContentDB) -> void:
	content = content_ref
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--state="):
			_state = clampi(int(arg.trim_prefix("--state=")), 0, STATES.size() - 1)
		elif arg == "--noframe":
			_vial_frame = false  # the plate's rail bare, as the benchmark ships it
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()

	_build_stage()

	_hud = HudBar.new(_vial_frame)
	add_child(_hud)

	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 12)
	_caption.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.offset_top = -22
	_caption.offset_bottom = -6
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)

	_hud.end_turn_pressed.connect(_on_pressed.bind("end turn"))
	_hud.menu_pressed.connect(_on_pressed.bind("menu"))
	_hud.deck_pressed.connect(_on_pressed.bind("deck"))
	_hud.lantern_pressed.connect(_on_pressed.bind("lantern"))
	_hud.pile_pressed.connect(func(pile: StringName) -> void: _on_pressed(str(pile)))
	_show(_state)


## A mock battlefield: the night gradient the combat screen runs, a warm pool
## where the lantern light falls, and a vignette. None of it is HudBar's — it is
## here so the bar's downward fade and the outlined numerals are judged against
## something, the way they will be judged in a fight.
func _build_stage() -> void:
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


func _show(i: int) -> void:
	_state = posmod(i, STATES.size())
	var row: Array = STATES[_state]
	# Packed, not eight `int(row[i])` casts: the elements are Variant, and the
	# strict gate rejects handing those straight to a typed parameter.
	var n: PackedInt32Array = PackedInt32Array(row.slice(1, 9))
	_hud.set_values(n[0], n[1], n[2], n[3], n[4], n[5], n[6], n[7])
	var charges: int = row[9]
	_hud.set_lantern(charges, charges > 0)
	_hud.set_title("The Ashen Woods", "Floor I · The Rootheart")
	_caption.text = "hud lab · state %d/%d · %s · vial frame %s · 1-6 or ←/→" % [
		_state + 1, STATES.size(), str(row[0]), "on" if _vial_frame else "off"]


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_RIGHT:
		_show(_state + 1)
	elif key.keycode == KEY_LEFT:
		_show(_state - 1)
	elif key.keycode >= KEY_1 and key.keycode <= KEY_6:
		_show(key.keycode - KEY_1)


## The bench has nothing behind the buttons, so it says what it received. That
## is the point of the wiring being signals: assembly connects the same five.
func _on_pressed(what: String) -> void:
	print("hud lab: %s pressed" % what)
