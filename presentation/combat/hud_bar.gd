class_name HudBar
extends Control
## The combat HUD, ported from the benchmark's own combat screen.
##
## It is not a bar. The benchmark spreads the readouts around the fight: a strip
## across the top that fades into the scene, energy standing bottom-left over a
## row of candles, the draw pile in that corner, the END seal on the right with
## the ash and discard piles beneath it, and the ward chip riding the hero's
## plate. This widget is that whole chrome layer.
##
## Every number below is measured, not guessed — the benchmark's combat screen
## is 1180x820, which is exactly this project's viewport, so its CSS pixels are
## our pixels. Sizes, colours, weights and letter-spacing come from the live
## stylesheet (read 2026-07-25); `_place()` re-hangs each cluster off the nearest
## window edge so a taller window keeps the furniture in its corner.
##
## Values in, signals out. No game dependency: `set_values()` takes nine ints,
## `set_title()` the location line, `set_lantern()` the art charge. The lab poses
## states the domain cannot reach yet (999 ward) and assembly wires the signals
## without this widget learning what a RunState is.
##
## The hero plate comes in both widths, because the reason for preferring one was
## never checked: see PLATE_PARITY_W. Everything else — including the pile fan's
## 5°/30° rule and one visible face per card — follows the benchmark's own
## pile-chrome.js.

signal end_turn_pressed
signal menu_pressed
signal deck_pressed
signal lantern_pressed
signal pile_pressed(pile: StringName)

const ART: String = "res://assets/art/"
## The benchmark's `.combat-screen`, and this project's viewport. Offsets are
## measured inside it, then hung off whichever edge each cluster belongs to.
const SCREEN: Vector2 = Vector2(1180.0, 820.0)

# --- palette: the benchmark's CSS custom properties, verbatim ---------------
const TEXT: Color = Color(0.843, 0.863, 0.918)       # --text    #d7dcea
const TEXT_DIM: Color = Color(0.545, 0.576, 0.678)   # --text-dim #8b93ad
const PARCHMENT: Color = Color(0.910, 0.875, 0.784)  # --parchment #e8dfc8
const GOLD: Color = Color(0.949, 0.757, 0.306)       # --gold    #f2c14e
const BLK: Color = Color(0.498, 0.831, 1.0)          # --blk     #7fd4ff
const LEAD: Color = Color(0.020, 0.027, 0.055)       # --lead    #05070e
const HP_NUM: Color = Color(1.0, 0.604, 0.627)       # .hp-num   #ff9aa0
const HP_LABEL: Color = Color(1.0, 0.725, 0.725)     # .hp-label #ffb9b9
const BLK_TEXT: Color = Color(0.804, 0.933, 1.0)     # .block-chip #cdeeff
const PALE: Color = Color(1.0, 0.973, 0.910)         # the big numerals #fff8e8
const WASH: Color = Color(0.031, 0.039, 0.086)       # the bar's own night #080a16
## .hud-hpbar fill: linear-gradient(90deg, #c22f43, #ff7060)
const HP_FILL_A: Color = Color(0.761, 0.184, 0.263)
const HP_FILL_B: Color = Color(1.0, 0.439, 0.376)
## .hpbar > .fill on the plate runs a shade deeper: #b52a3e → #ff6a5e
const PLATE_FILL_A: Color = Color(0.710, 0.165, 0.243)
const PLATE_FILL_B: Color = Color(1.0, 0.416, 0.369)

const BAR_H: float = 56.0
const BAR_PAD: float = 16.0
const BAR_GAP: float = 18.0
const HP_WRAP_W: float = 170.0
## The hero plate, in both widths, sharing one centre so an A/B is honest.
##
## PARITY is `.hpbar-wrap` verbatim: 150px holding [ward chip][gap 6][vial,
## flex:1][gap 6][hp-label, 52 min]. `.block-chip` floors at 34px and never
## sits there — its own content is a 34px shield, a 3px gap and the numeral
## inside 7px of padding either side, so a two-digit ward carries it to ~53px
## and leaves the vial around 33. Reading the floor instead of the content is
## how this gets mis-measured: it says 52px, and the render says half that.
##
## WIDE is this port's answer: the same row at 240px with the vial's length
## locked, so a warded turn does not shorten the gauge to a colour swatch.
## Both are built, because the choice is a judgement about how long a health
## bar has to be before it stops being one, and that is not settled in a
## comment.
const PLATE_PARITY_W: float = 150.0
const PLATE_WIDE_W: float = 240.0
const PLATE_WIDE_VIAL: float = 110.0
## WIDE reserves the chip's slot whether or not the chip is in it. PARITY does
## not, because `.block-chip.zero { display: none }` and a flex row closes up
## behind a removed item. Both are deliberate: the point of the locked vial is
## that a warded turn changes nothing about the gauge, and a gauge that slides
## 66px sideways when the ward expires has changed plenty.
const PLATE_WIDE_LEAD: float = 76.0
const PLATE_CX: float = 245.0       # both widths hang off this centre
const PLATE_Y: float = 614.0
const PLATE_H: float = 34.0
const PLATE_GAP: float = 6.0        # .hpbar-wrap gap
const PLATE_LABEL_W: float = 52.0   # .hp-label min-width
## `.hpbar` is 9px in a border-box layout — 9 including its 1px lead rim, so the
## fill under a bare rail is 7. With the frame on, the benchmark hands the bezel
## over to the art: `.hp-vial:has(.hp-vial-frame) .hpbar` drops the border and
## the shadow, insets the rail 4px each side, and flattens the radius to 2.
const RAIL_H: float = 9.0
const RAIL_FRAMED_INSET: float = 4.0
## The fan, from the benchmark's pile-chrome.js: one visible face per card up to
## a cap, 5° between them, and the whole span averaged down once it would pass
## 30°. The count text stays the true size — the faces are how many you can see.
const FAN_STEP: float = 5.0    # PILE_FAN_DEG
const FAN_SPAN: float = 30.0   # PILE_FAN_MAX_DEG
const FAN_FACES: int = 16      # PILE_FAN_MAX_LAYERS
## `.pile-exhaust { opacity: 0.9 }` — the ash pile sits a shade back.
const ASH_FADE: float = 0.9

static var _tex_cache: Dictionary = {}
static var _font_cache: Dictionary = {}

var _hp_num: Label
var _hp_fill: TextureRect
var _gold_num: Label
var _title_lead: Label
var _title_tail: Label
var _deck_count: Label
var _plate_fill: TextureRect
var _plate_label: Label
var _plate_rail: Panel
var _plate_frame: TextureRect
var _ward: Control  # chip and shield together — the shield is not on the chip
var _ward_chip: PanelContainer
var _ward_num: Label
## The plate's row is resolved from these two: the wrap's width, and the vial's
## length inside it — 0.0 meaning "take whatever the row has left" (flex:1).
var _plate_w: float = PLATE_WIDE_W
var _plate_vial_w: float = PLATE_WIDE_VIAL
var _hp_ratio: float = 1.0
var _energy_num: Label
var _candle_field: Control
var _candles: Array[TextureRect] = []
var _energy_orb: Control
var _lantern: Control
var _lantern_count: Label
var _draw_pile: Pile
var _ashes_pile: Pile
var _discard_pile: Pile
var _vial_frame: bool = true
## The last nine values drawn; empty forces the first pass through.
var _last: PackedInt32Array = PackedInt32Array()


## One pile's parts. A class rather than three sets of members or a dictionary
## of dictionaries: the fan is rebuilt whenever the count moves, and the strict
## gate wants every piece typed at that moment.
class Pile:
	var count: Label
	var stack: Fan
	var shown: int = -1      # last count drawn; -1 forces the first build


## The fan of card backs, drawn rather than assembled.
##
## A pile shows one face per card up to sixteen, so three piles at depth is up
## to FORTY-EIGHT nodes — every one a full Control with its own transform,
## style and layout slot, all of them drawing the identical texture. That is
## how you would do it in a DOM, where a node is the only thing you can rotate;
## in Godot the same picture is one `_draw()` per pile and nothing to allocate
## when the count moves.
##
## The geometry is unchanged: each face is a `face`-square laid on the bottom of
## the box and turned about a point at 50%/92% of it, which is where a real deck
## pivots — near the bottom edge, not the middle.
class Fan:
	extends Control
	var tex: Texture2D
	var face: float = 96.0
	var faces: int = 0

	func _draw() -> void:
		if tex == null or faces <= 0:
			return
		var pivot: Vector2 = Vector2(face * 0.5, size.y - face + face * 0.92)
		var origin: Vector2 = Vector2(0.0, size.y - face) - pivot
		for i: int in range(faces):
			# Qualified: an inner class does not see the outer one's statics.
			var a: float = HudBar._fan_angle(i, faces)
			draw_set_transform(pivot, deg_to_rad(a), Vector2.ONE)
			draw_texture_rect(tex, Rect2(origin, Vector2(face, face)), false)


## A mipmapped copy of one UI texture. The art is 512² and lands here between 14
## and 120px; a straight linear downscale of that sparkles on every value
## change, and the import sidecars are off limits (SKILL §4), so the mip chain is
## built at runtime and cached — nine textures, once per process.
static func icon(icon_name: String) -> Texture2D:
	if _tex_cache.has(icon_name):
		var hit: Texture2D = _tex_cache[icon_name]
		return hit
	var path: String = ART + icon_name + ".png"
	if not ResourceLoader.exists(path):
		# Checked rather than let load() fail: a missing icon otherwise becomes
		# an invisible node with nothing in the log naming which one.
		push_warning("hud: missing art %s" % path)
		_tex_cache[icon_name] = null
		return null
	var src: Texture2D = load(path) as Texture2D
	var made: Texture2D = src
	if src != null:
		var img: Image = src.get_image()
		if img != null:
			img.generate_mipmaps()
			made = ImageTexture.create_from_image(img)
	_tex_cache[icon_name] = made
	return made


## Cinzel at a given tracking. The benchmark spaces its display type in `em`
## (0.14em on the location line, 0.16em on END); those are resolved to pixels at
## each call site, because Godot's spacing_glyph is absolute.
static func _font(path: String, tracking: int) -> Font:
	var key: String = path + "#" + str(tracking)
	if _font_cache.has(key):
		var hit: Font = _font_cache[key]
		return hit
	var fv: FontVariation = FontVariation.new()
	fv.base_font = load(path) as FontFile
	if tracking != 0:
		fv.spacing_glyph = tracking
	_font_cache[key] = fv
	return fv


## Two flags, both A/B switches the lab drives rather than settled facts.
##
## `vial_frame` hangs hp-vial-frame.png over the plate's rail. The art is
## 512x179 and the CSS box is 22px tall over the vial's length — so the frame is
## squashed, but the benchmark squashes it by the same amount (`object-fit:
## fill`), which makes the flattened leading the shipped look rather than our
## error. What it costs is real: the rule it belongs to also strips the rail's
## own bezel, and running the frame without that draws two bezels at once.
##
## `wide_plate` picks between the two widths at PLATE_PARITY_W.
##
## `plate` builds it at all. The benchmark's `.cplate` is not chrome — it sits
## inside `.player-zone` at `top: 100%`, and the enemy carries identical markup,
## so the ward chip and the HP rail belong to whichever actor they describe.
## This widget hangs its own copy at a fixed stage coordinate, which is right in
## a lab with no hero in it and wrong the moment a real hero stands somewhere
## else. Assembly asks the question as D2 in `docs/assembly-integration-plan.md`;
## passing false here is the answer that says the actor owns it.
func _init(vial_frame: bool = true, wide_plate: bool = true,
		plate: bool = true) -> void:
	_vial_frame = vial_frame
	_plate_w = PLATE_WIDE_W if wide_plate else PLATE_PARITY_W
	_plate_vial_w = PLATE_WIDE_VIAL if wide_plate else 0.0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # only the buttons take input
	_build_top_bar()
	if plate:
		_build_plate()
	_build_energy()
	_build_lantern()
	# Three piles, not two, each wearing its own back — the blue vault, the warm
	# discard, the charred ash. Boxes from the benchmark's ui-chrome-layout.js:
	# draw {left 16, bottom 14}, ashes {right 132}, discard {right 22}, 96x148.
	_draw_pile = _build_pile(&"draw", "DRAW", Rect2(16.0, 658.0, 96.0, 148.0), false, 1.0)
	_ashes_pile = _build_pile(&"ashes", "ASHES", Rect2(952.0, 658.0, 96.0, 148.0),
		true, ASH_FADE)
	_discard_pile = _build_pile(&"discard", "DISCARD",
		Rect2(1062.0, 658.0, 96.0, 148.0), true, 1.0)
	_build_end_turn()
	set_title("The Ashen Woods", "Floor I · The Rootheart")
	set_values(72, 72, 0, 99, 3, 3, 5, 0, 0)


# ---------------------------------------------------------------- values

## The whole input surface. Plain ints — no run, no combat, no content.
## `exhaust_count` is the ash pile: the domain has carried `cb.exhaust` since
## M4, and the benchmark gives it a third corner of its own. `hand_count` is not
## drawn anywhere; it is here because the deck seal counts the cards still in
## the fight, and the hand is part of that.
func set_values(hp: int, max_hp: int, block: int, gold: int,
		energy: int, max_energy: int, draw_count: int, discard_count: int,
		exhaust_count: int, hand_count: int = 0) -> void:
	# Assembly will call this off a signal that fires for anything that moved,
	# so most calls change nothing here. Setting a Label's text re-shapes it
	# even when the string is identical; nine of those per call is a real cost
	# for no change on screen. The piles already guarded themselves — this is
	# the same guard for the whole surface.
	var now: PackedInt32Array = PackedInt32Array([hp, max_hp, block, gold,
		energy, max_energy, draw_count, discard_count, exhaust_count, hand_count])
	if now == _last:
		return
	_last = now
	_hp_ratio = clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)
	_hp_num.text = "%d / %d" % [hp, max_hp]
	_hp_fill.size.x = HP_WRAP_W * _hp_ratio
	# Absent, not empty, when the actor owns the plate instead — see `_init`.
	if _plate_rail != null:
		_plate_label.text = "%d/%d" % [hp, max_hp]
		_ward.visible = block > 0  # .block-chip.zero { display: none }
		_ward_num.text = str(block)
		_layout_plate()  # the vial's length is what the chip eats into

	_gold_num.text = str(gold)
	_sync_pile(_draw_pile, draw_count)
	_sync_pile(_discard_pile, discard_count)
	_sync_pile(_ashes_pile, exhaust_count)
	# The top-right seal opens the deck. The benchmark counts the run's whole
	# deck there (`p.deck.length`), a number that never moves during a fight;
	# this port shows the cards still IN the fight instead — draw, hand and
	# discard. Ash is excluded on purpose: a pile whose meaning is "removed from
	# the fight" cannot also be in it.
	_deck_count.text = str(draw_count + hand_count + discard_count)

	_energy_num.text = str(energy)
	_sync_candles(energy, max_energy)
	# .energy-orb.spent { filter: saturate(.35) brightness(.75) } — canvas
	# modulate cannot desaturate, so the cold tint stands in for it.
	_energy_orb.modulate = Color.WHITE if energy > 0 else Color(0.72, 0.74, 0.78)


## One candle per point of max energy, lit up to `energy`, bottom-aligned in a
## fixed 120px field: the benchmark flexes them (`flex: 1`, `max-width: 40px`,
## `object-fit: contain`, `object-position: center bottom`), so five candles are
## narrower than three and all of them stand on the same line.
func _sync_candles(energy: int, max_energy: int) -> void:
	var count: int = maxi(1, max_energy)
	while _candles.size() < count:
		var c: TextureRect = TextureRect.new()
		c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_SCALE
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_candle_field.add_child(c)
		_candles.append(c)
	var cell: float = _candle_field.size.x / float(count)
	var side: float = minf(minf(cell, 40.0), _candle_field.size.y)
	for i: int in range(_candles.size()):
		var c: TextureRect = _candles[i]
		c.visible = i < count
		if not c.visible:
			continue
		var lit: bool = i < energy
		c.texture = icon("ui/candle-lit" if lit else "ui/candle-spent")
		c.size = Vector2(side, side)
		c.position = Vector2(cell * float(i) + (cell - side) * 0.5,
			_candle_field.size.y - side)
		# .candle.is-spent .candle-img { filter: brightness(1.35) contrast(1.08) }
		# — the spent art is already ash-grey, so it is lifted, not dimmed.
		c.modulate = Color.WHITE if lit else Color(1.35, 1.35, 1.35)


## The location line: the place in parchment, the rest dim behind it.
func set_title(lead: String, tail: String = "") -> void:
	_title_lead.text = lead.to_upper()
	_title_tail.text = ("  ·  " + tail) if tail != "" else ""


## The lantern's art charge, and whether it can be spent. Not one of the eight
## values — the benchmark drives it off relic state, so it keeps its own setter.
func set_lantern(charges: int, ready: bool) -> void:
	_lantern_count.text = str(charges)
	# .lantern-btn.unlit { filter: saturate(.55) brightness(.82) }
	_lantern.modulate = Color.WHITE if ready else Color(0.80, 0.82, 0.86)


# ---------------------------------------------------------------- top bar

## `.hud-bar`: 56px, padding 8/16, gap 18, and a background that is a downward
## fade rather than a panel — it has no border, it dissolves into the fight.
func _build_top_bar() -> void:
	var bar: Control = Control.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = BAR_H
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	var wash: TextureRect = TextureRect.new()
	wash.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(WASH.r, WASH.g, WASH.b, 0.92),
			Color(WASH.r, WASH.g, WASH.b, 0.55), Color(WASH.r, WASH.g, WASH.b, 0.0)]),
		PackedFloat32Array([0.0, 0.8, 1.0]), false, Vector2(0.5, 0.0), Vector2(0.5, 1.0))
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(wash)

	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = BAR_PAD
	row.offset_right = -BAR_PAD
	row.add_theme_constant_override("separation", int(BAR_GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)

	# .hud-hp-wrap — numerals over a 7px rail, 3px apart, 170 wide.
	var hp_wrap: VBoxContainer = VBoxContainer.new()
	hp_wrap.custom_minimum_size = Vector2(HP_WRAP_W, 0.0)
	hp_wrap.add_theme_constant_override("separation", 3)
	hp_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hp_wrap)
	var hp_stat: HBoxContainer = _stat_row()
	hp_stat.add_child(_icon_rect("ui/heart", 14.0))
	_hp_num = _num_label(17.0, HP_NUM, GlassStyle.CINZEL_700, 0)
	hp_stat.add_child(_hp_num)
	hp_wrap.add_child(hp_stat)
	var rail: Panel = Panel.new()
	rail.custom_minimum_size = Vector2(HP_WRAP_W, 7.0)
	rail.add_theme_stylebox_override("panel", _flat(Color(1.0, 1.0, 1.0, 0.12), 4))
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_wrap.add_child(rail)
	# The fill keeps the CSS gradient and gives up the CSS rounding: a rounded
	# gradient needs a shader, and at 7px tall the gradient is what reads.
	_hp_fill = _gradient_rect(HP_FILL_A, HP_FILL_B)
	_hp_fill.size = Vector2(HP_WRAP_W, 7.0)
	rail.add_child(_hp_fill)

	var gold_stat: HBoxContainer = _stat_row()
	gold_stat.add_child(_icon_rect("ui/coin", 14.0))
	_gold_num = _num_label(17.0, GOLD, GlassStyle.CINZEL_700, 0)
	gold_stat.add_child(_gold_num)
	row.add_child(gold_stat)

	# .hud-mid — flex:1, centred, Cinzel 14 at 0.14em (0.2em on the place name).
	var mid: HBoxContainer = HBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 0)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mid)
	_title_lead = _num_label(14.0, PARCHMENT, GlassStyle.CINZEL_700, 3)
	mid.add_child(_title_lead)
	_title_tail = _num_label(14.0, TEXT_DIM, GlassStyle.CINZEL_700, 2)
	mid.add_child(_title_tail)

	var right: HBoxContainer = HBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)

	# .icon-btn.deck-btn — a 44px hit area under 56px of art, with the count
	# sitting on the seal in white.
	var deck: Button = _bare_button(Vector2(44.0, 44.0))
	deck.tooltip_text = "Deck"
	deck.pressed.connect(func() -> void: deck_pressed.emit())
	right.add_child(deck)
	var seal: TextureRect = _icon_rect("ui/deck", 56.0)
	seal.position = Vector2(-6.0, -6.0)
	deck.add_child(seal)
	_deck_count = _num_label(22.0, Color.WHITE, GlassStyle.CINZEL_800, 0)
	_deck_count.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deck_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deck_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(_deck_count, 6)
	deck.add_child(_deck_count)

	# .icon-btn — the one piece of chrome that keeps a box: 40px, radius 10,
	# ink fill, hairline rim.
	var menu: Button = Button.new()
	menu.custom_minimum_size = Vector2(40.0, 40.0)
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu.focus_mode = Control.FOCUS_NONE
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var sb: StyleBoxFlat = _flat(Color(0.063, 0.078, 0.149, 0.72), 10)
		sb.set_border_width_all(1)
		sb.border_color = GOLD if state == "hover" else Color(1.0, 1.0, 1.0, 0.14)
		menu.add_theme_stylebox_override(state, sb)
	menu.tooltip_text = "Menu"
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	right.add_child(menu)
	var menu_ic: TextureRect = _icon_rect("ui/menu", 19.0)
	menu_ic.set_anchors_preset(Control.PRESET_CENTER)
	menu_ic.offset_left = -9.5
	menu_ic.offset_top = -9.5
	menu_ic.offset_right = 9.5
	menu_ic.offset_bottom = 9.5
	menu.add_child(menu_ic)


# ---------------------------------------------------------------- clusters

## `.cplate` — the ward chip and the HP rail that live at the hero's feet. The
## chip's shield is bigger than the chip and hangs off its left edge.
##
## The row is a flex in the benchmark and is resolved by hand here. An
## HBoxContainer would lay it out, but a Container owns its children's
## positions, and two pieces of this row deliberately sit outside their own
## slot: the shield overhangs the chip's left edge, and the frame stands 5px
## proud of the rail at each end. `_layout_plate()` is that arithmetic, kept in
## the same measured-absolute idiom as every other cluster in this file.
func _build_plate() -> void:
	var plate: Control = Control.new()
	_place(plate, Rect2(PLATE_CX - _plate_w * 0.5, PLATE_Y, _plate_w, PLATE_H),
		false, true)
	add_child(plate)

	# Chip and shield hide together. The shield is not a child of the chip — it
	# is half again its height and hangs off its left edge (`.block-chip .ic`
	# margin: -6px 2px -6px -14px), so it lives beside it under one switch.
	_ward = Control.new()
	_ward.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(_ward)
	_ward_chip = PanelContainer.new()
	var chip: StyleBoxFlat = _flat(Color(0.110, 0.231, 0.333, 1.0), 13)
	chip.set_border_width_all(2)  # 1.5px in CSS; Godot borders are whole pixels
	chip.border_color = BLK
	chip.content_margin_left = 22.0  # room for the shield's overhang
	chip.content_margin_right = 8.0
	chip.content_margin_top = 3.0
	chip.content_margin_bottom = 3.0
	chip.shadow_color = Color(BLK.r, BLK.g, BLK.b, 0.35)
	chip.shadow_size = 8
	_ward_chip.add_theme_stylebox_override("panel", chip)
	_ward_chip.position = Vector2(14.0, 4.0)
	_ward_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# `.block-chip` floors at 34px; this chip's own padding and numeral clear
	# that on their own, so the floor never binds and is not restated here.
	# Three digits widen it, and the vial behind it has to give the room back.
	_ward_chip.resized.connect(_layout_plate)
	_ward.add_child(_ward_chip)
	_ward_num = _num_label(14.0, BLK_TEXT, GlassStyle.ALEGREYA_700, 0)
	_ward_num.custom_minimum_size = Vector2(16.0, 0.0)
	_ward_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ward_chip.add_child(_ward_num)
	_ward.add_child(_icon_rect("ui/ward", 34.0))

	_plate_rail = Panel.new()
	_plate_rail.add_theme_stylebox_override("panel", _rail_style())
	_plate_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(_plate_rail)
	_plate_fill = _gradient_rect(PLATE_FILL_A, PLATE_FILL_B)
	_plate_rail.add_child(_plate_fill)
	# hp-vial-frame.png: the benchmark's `.hp-vial-frame` rule stretches it over
	# the rail (object-fit: fill, 22px tall, 5px proud at each end). The rule
	# that hands the bezel to the art lives in `_rail_style()`.
	if _vial_frame:
		_plate_frame = TextureRect.new()
		_plate_frame.texture = icon("ui/hp-vial-frame")
		_plate_frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_plate_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_plate_frame.stretch_mode = TextureRect.STRETCH_SCALE
		_plate_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(_plate_frame)

	_plate_label = _num_label(12.0, HP_LABEL, GlassStyle.ALEGREYA_700, 0)
	plate.add_child(_plate_label)
	_layout_plate()


## The rail under the vial. Bare it carries its own lead bezel; under the frame
## the art carries it instead, and keeping both draws two rims over one gauge.
func _rail_style() -> StyleBoxFlat:
	if _vial_frame:
		return _flat(Color(0.0, 0.0, 0.0, 0.35), 2)
	var track: StyleBoxFlat = _flat(Color(0.0, 0.0, 0.0, 0.55), 5)
	track.set_border_width_all(1)
	track.border_color = LEAD
	return track


## Resolve `.hpbar-wrap`: the chip takes what it needs, the label its 52px, and
## the vial either flexes into the gap or keeps the length it was given. Run at
## build and again whenever the chip appears or leaves, since the vial's length
## is what the chip is eating into.
func _layout_plate() -> void:
	var vial_w: float = _plate_vial_w
	var vial_x: float = PLATE_WIDE_LEAD
	if vial_w <= 0.0:
		vial_x = (_ward_chip.size.x + 14.0 + PLATE_GAP) if _ward.visible else 0.0
		vial_w = _plate_w - vial_x - PLATE_GAP - PLATE_LABEL_W
	var inset: float = RAIL_FRAMED_INSET if _vial_frame else 0.0
	var rim: float = 0.0 if _vial_frame else 1.0
	_plate_rail.position = Vector2(vial_x + inset, (PLATE_H - RAIL_H) * 0.5)
	_plate_rail.size = Vector2(maxf(2.0, vial_w - inset * 2.0), RAIL_H)
	_plate_fill.position = Vector2(rim, rim)
	_plate_fill.size = Vector2((_plate_rail.size.x - rim * 2.0) * _hp_ratio,
		RAIL_H - rim * 2.0)
	if _plate_frame != null:
		_plate_frame.position = Vector2(vial_x - 5.0, (PLATE_H - 22.0) * 0.5)
		_plate_frame.size = Vector2(vial_w + 10.0, 22.0)
	_plate_label.position = Vector2(vial_x + vial_w + PLATE_GAP, 8.0)


## `.energy-orb` — a 44px numeral standing on a row of candles, overlapping them
## by 10px. The candles are the gauge; the numeral is the read.
func _build_energy() -> void:
	_energy_orb = Control.new()
	_place(_energy_orb, Rect2(0.0, 568.0, 120.0, 90.0), false, true)
	add_child(_energy_orb)

	_candle_field = Control.new()
	_candle_field.position = Vector2(0.0, 34.0)
	_candle_field.size = Vector2(120.0, 56.0)
	_candle_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_energy_orb.add_child(_candle_field)

	_energy_num = _num_label(44.0, PALE, GlassStyle.CINZEL_800, 0)
	_energy_num.size = Vector2(120.0, 48.0)
	_energy_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(_energy_num, 10)
	_energy_orb.add_child(_energy_num)


## `.lantern-btn` — the art charge. Its own setter, not one of the eight values.
func _build_lantern() -> void:
	_lantern = Control.new()
	_place(_lantern, Rect2(18.0, 448.0, 104.0, 104.0), false, true)
	add_child(_lantern)
	# The benchmark drop-shadows the lantern in its own firelight; a soft radial
	# behind it is the cheap read of the same thing.
	var glow: TextureRect = TextureRect.new()
	glow.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(1.0, 0.71, 0.35, 0.30), Color(1.0, 0.60, 0.25, 0.0)]),
		PackedFloat32Array([0.0, 1.0]), true, Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lantern.add_child(glow)

	var btn: Button = _bare_button(Vector2(104.0, 104.0))
	btn.tooltip_text = "Lantern — spend a charge"
	btn.pressed.connect(func() -> void: lantern_pressed.emit())
	_lantern.add_child(btn)
	var art: TextureRect = _icon_rect("ui/lantern", 94.0)
	art.position = Vector2(5.0, 5.0)
	btn.add_child(art)
	_lantern_count = _num_label(26.0, PALE, GlassStyle.CINZEL_800, 0)
	_lantern_count.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lantern_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lantern_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(_lantern_count, 8)
	btn.add_child(_lantern_count)


## `.pile-btn` — a fan of card backs, the count on its shoulder, the name
## underneath. `.pile-stack` is inset 18px from the bottom to leave that name
## room, and the faces are drawn at the box's own width.
func _build_pile(which: StringName, name_text: String, rect: Rect2,
		from_right: bool, fade: float) -> Pile:
	var root: Control = Control.new()
	_place(root, rect, from_right, true)
	root.modulate = Color(1.0, 1.0, 1.0, fade)
	add_child(root)

	var btn: Button = _bare_button(rect.size)
	btn.pressed.connect(func() -> void: pile_pressed.emit(which))
	root.add_child(btn)

	var p: Pile = Pile.new()
	p.stack = Fan.new()
	p.stack.tex = icon("piles/" + str(which))
	p.stack.face = rect.size.x
	p.stack.size = Vector2(rect.size.x, rect.size.y - 18.0)
	p.stack.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	p.stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(p.stack)

	p.count = _num_label(16.0, PARCHMENT, GlassStyle.CINZEL_800, 0)
	p.count.position = Vector2(0.0, rect.size.y - 34.0)
	p.count.size = Vector2(rect.size.x - 2.0, 16.0)
	p.count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_outline(p.count, 6)
	btn.add_child(p.count)

	var tag: Label = _num_label(10.0, TEXT_DIM, GlassStyle.CINZEL_700, 1)
	tag.text = name_text
	tag.position = Vector2(0.0, rect.size.y - 14.0)
	tag.size = Vector2(rect.size.x, 13.0)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(tag, 4)
	btn.add_child(tag)
	return p


## Where a pile's faces actually sit, in global coordinates — the anchor a card
## flies from when it is dealt and to when it is spent, and the size it is at
## either end (`fromSize: 'pile'`).
##
## An accessor rather than a table the screen keeps its own copy of: `_place`
## re-hangs every cluster off its nearest window edge, so a pile's position is
## not a constant and a second copy of these numbers would be wrong the first
## time the window is not 1180 wide.
func pile_rect(which: StringName) -> Rect2:
	var p: Pile = _draw_pile
	if which == &"discard":
		p = _discard_pile
	elif which == &"ashes":
		p = _ashes_pile
	if p == null or p.stack == null:
		return Rect2(global_position + size * 0.5, Vector2.ZERO)
	return p.stack.get_global_rect()


## One face per card, so the pile is its own gauge — the count text is only
## there for the tail past the cap. An empty pile hides the plate and keeps the
## name and the zero (`.pile-btn.is-empty .pile-stack { visibility: hidden }`).
func _sync_pile(p: Pile, n: int) -> void:
	p.count.text = str(n)
	if p.shown == n:
		return  # the benchmark's own guard: redraw only when the count moves
	p.shown = n
	var faces: int = mini(maxi(n, 0), FAN_FACES)
	p.stack.visible = faces > 0
	p.stack.faces = faces
	p.stack.queue_redraw()


## pileFanAngleDeg: a flat centred fan, 5° a card, the span averaged down once
## it would exceed 30° — so a 20-card pile is no wider than a 7-card one.
static func _fan_angle(i: int, faces: int) -> float:
	if faces <= 1:
		return 0.0
	var span: float = minf(float(faces - 1) * FAN_STEP, FAN_SPAN)
	return -span * 0.5 + float(i) * (span / float(faces - 1))


## `.end-turn` — 120px of seal with END struck across it.
func _build_end_turn() -> void:
	var root: Control = Control.new()
	_place(root, Rect2(1060.0, 537.0, 120.0, 120.0), true, true)
	add_child(root)
	var btn: Button = _bare_button(Vector2(120.0, 120.0))
	btn.pressed.connect(func() -> void: end_turn_pressed.emit())
	root.add_child(btn)
	btn.add_child(_icon_rect("ui/end-turn", 120.0))
	var lbl: Label = _num_label(18.0, PALE, GlassStyle.CINZEL_800, 3)
	lbl.text = "END"
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(lbl, 8)
	btn.add_child(lbl)


# ---------------------------------------------------------------- parts

## Hang a cluster off the window edge it belongs to, from a rect measured in the
## benchmark's 1180x820 screen. Bottom furniture stays in the corner when the
## window grows; the top bar is the only thing that spans.
func _place(node: Control, rect: Rect2, from_right: bool, from_bottom: bool) -> void:
	var ax: float = 1.0 if from_right else 0.0
	var ay: float = 1.0 if from_bottom else 0.0
	node.anchor_left = ax
	node.anchor_right = ax
	node.anchor_top = ay
	node.anchor_bottom = ay
	node.offset_left = rect.position.x - (SCREEN.x if from_right else 0.0)
	node.offset_right = node.offset_left + rect.size.x
	node.offset_top = rect.position.y - (SCREEN.y if from_bottom else 0.0)
	node.offset_bottom = node.offset_top + rect.size.y
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE


## `.hud-stat`: icon and numeral, 7px apart, centred on the bar.
func _stat_row() -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


## A button that is nothing but the art parented onto it — no box in any state,
## which is how every piece of the benchmark's chrome behaves except the menu.
func _bare_button(px: Vector2) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = px
	b.size = px
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.mouse_entered.connect(func() -> void: b.modulate = Color(1.10, 1.10, 1.10))
	b.mouse_exited.connect(func() -> void: b.modulate = Color.WHITE)
	return b


func _icon_rect(icon_name: String, px: float) -> TextureRect:
	var t: TextureRect = TextureRect.new()
	t.texture = icon(icon_name)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.custom_minimum_size = Vector2(px, px)
	t.size = Vector2(px, px)
	return t


func _gradient_rect(from_c: Color, to_c: Color) -> TextureRect:
	var t: TextureRect = TextureRect.new()
	t.texture = GlassStyle.grad_tex(PackedColorArray([from_c, to_c]),
		PackedFloat32Array([0.0, 1.0]), false, Vector2(0.0, 0.5), Vector2(1.0, 0.5))
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _num_label(px: float, tint: Color, face: String, tracking: int) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_override("font", _font(face, tracking))
	l.add_theme_font_size_override("font_size", int(px))
	l.add_theme_color_override("font_color", tint)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The benchmark strokes its big numerals in black and stacks four hard shadows
## behind them so they survive on top of art. Godot's outline is that, in one
## property.
func _outline(l: Label, size: int) -> void:
	l.add_theme_constant_override("outline_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))


func _flat(fill: Color, radius: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	return sb
