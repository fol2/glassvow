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
## Every number below is measured, not guessed. Sizes, colours, weights and
## letter-spacing come from the live stylesheet (read 2026-07-25) at 1180x820,
## which the benchmark names `pad-landscape` and whose CSS pixels are this
## project's pixels at that shape.
##
## WHERE each cluster sits is no longer among them: the ten `UIC` boxes come from
## `assets/layout/combat-layout.json` for the shape this HUD was built for, so a
## phone gets the phone's chrome rather than the pad's shrunk. `_place()` hangs
## each one off the corner it belongs to, and because every value in that scope
## is a distance from an edge, a stage that flexes moves nothing.
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
signal potion_pressed(slot: int)
signal lantern_pressed
signal pile_pressed(pile: StringName)

const ART: String = "res://assets/art/"

## Where each cluster hangs, for the shape this HUD was built for. Ten of the
## boxes below used to be literals measured inside a 1180x820 screen; they are
## `UIC` (`src/ui-chrome-layout.js`) and now come out of the book instead, which
## is the same table read rather than transcribed. At `pad-landscape` it resolves
## to exactly the numbers that were here.
##
## The whole scope is edge-relative — every widget is a distance from the corner
## it sits in, never a coordinate — so the flex passes straight through it and
## `_place` never needs to know how wide the stage is. See `LayoutBook.place`.
var shape: StringName = StageShape.IDENTITY
var _chrome: Dictionary = {}

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

## `.hud-bar`'s content height — `UIC.hud.height`, which every shape re-authors
## (56 on a pad, 47 on a phone in portrait, 34 held sideways). `UIC.hud.scale`
## rides alongside it and is 1 in all five shapes at 6e06911, so nothing reads it
## yet; the editor is what will make it earn its place.
const BAR_H_FALLBACK: float = 56.0
const BAR_PAD: float = 16.0
const BAR_GAP: float = 18.0
const HP_WRAP_W: float = 170.0
## How the two HP rails travel. See `_hp_shown_bar` for why there are two.
const HP_BAR_TIME: float = 0.4
const HP_PLATE_TIME: float = 0.35
const HP_EASE: Array[float] = [0.3, 1.0, 0.4, 1.0]
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
## A pile's box where the book authors none. Every shape at 6e06911 does author
## one, so this is a floor rather than a default in practice.
const PILE_BOX: Vector2 = Vector2(96.0, 148.0)

const PLATE_CX: float = 245.0       # both widths hang off this centre
## The hero plate is NOT a `UIC` widget — the benchmark rides it on the actor,
## and this port hangs it off the corner instead (`docs/hud-handoff.md` §2). Its
## two numbers stay here, restated as a distance UP from the bottom edge so they
## survive a taller stage the same way every book widget does.
const PLATE_BOTTOM: float = 172.0
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
const LANTERN_CAP_MAX: int = 12
const LANTERN_PIP_SIDE: float = 5.0
const LANTERN_PIP_RADIUS: float = 50.0

## The HUD's beacons. `artReady` 1.6s ease-in-out infinite — brightness 1.22
## with a 14px amber halo at the 50% mark — beckons from BOTH "you can act"
## seats: the lantern when the art can be spent (styles.css:1116-1118) and the
## END seal once the energy is gone (`artReady` again, styles.css:1352-1354).
## `kindleCall` 1.1s is
## the lantern as a drop target while a burnable card is in the air: brighter,
## a wider halo, and a 1.07 swell (styles.css:1123-1124).
const ART_READY_TIME: float = 1.6
const ART_READY_BRIGHT: float = 1.22
const KINDLE_TIME: float = 1.1
const KINDLE_BRIGHT: float = 1.2
const KINDLE_SCALE: float = 1.07
## `.lbp { transition: background .25s, box-shadow .25s }` (styles.css:1112) —
## an ember pip fades between its two readings rather than snapping.
const LBP_BLEND: float = 0.25
## `.end-turn`/`.pile-btn` hover glides — `transition: transform .15s, filter
## .15s`, −1px/−3px lift with brightness 1.08 (styles.css:1344-1349, :1403).
const HOVER_TIME: float = 0.15
const HOVER_BRIGHT: Color = Color(1.08, 1.08, 1.08, 1.0)

static var _tex_cache: Dictionary = {}
static var _font_cache: Dictionary = {}

var _hp_num: Label
var _hp_fill: TextureRect
var _gold_num: Label
var _title_lead: Label
var _title_tail: Label
var _deck_count: Label
var _potion_slots: Array[Button] = []
var _potion_art: Array[TextureRect] = []
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
## What the two rails are SHOWING, which lags what the player HAS.
##
##     .hud-hpbar > div { transition: width 0.4s  cubic-bezier(0.3, 1, 0.4, 1); }
##     .hpbar > .fill   { transition: width 0.35s cubic-bezier(0.3, 1, 0.4, 1); }
##                                                    (styles.css:182, 834)
##
## Two rails, two durations, one curve. They are separate elements in the
## reference and they are separate here, even though 50ms apart is not something
## anyone will time — the ghost rail beside them already glides, and a fill that
## jumps to its new width next to a ghost that slides is visible on every hit.
##
## Held as a ratio rather than a width because the plate's rail is re-measured by
## `_layout_plate` whenever the ward chip changes size: a tween writing a WIDTH
## would be overwritten by the next layout, and a tween writing the ratio the
## layout reads survives it.
var _hp_shown_bar: float = 1.0
var _hp_shown_plate: float = 1.0
var _hp_bar_tween: Tween = null
var _hp_plate_tween: Tween = null
## A CSS transition does not fire on the first render — the element is born at
## its width. The first sync therefore SNAPS, or a fight resumed at half health
## would open with both rails sweeping down from full, which is a thing the
## reference never shows.
var _hp_seeded: bool = false
var _energy_num: Label
var _candle_field: Control
var _candles: Array[TextureRect] = []
var _energy_orb: Control
var _lantern: Control
var _lantern_count: Label
var _lantern_art: TextureRect
var _lantern_glow: TextureRect
var _lantern_pips: Array[TextureRect] = []
## The lantern's inner frame (`shell`) and its button body — the shell takes
## the `nope` shove and the beacon brightness, the body takes the tilt and the
## kindle swell, because the shell's scale is the shape adapter and its pivot
## must stay at the origin.
var _lantern_shell: Control
var _lantern_body: Button
var _lantern_ready: bool = false
var _kindle_target: bool = false
## Per-pip .25s crossfade state — from, target, and progress.
var _pip_from: Array[Color] = []
var _pip_target: Array[Color] = []
var _pip_u: Array[float] = []
var _pips_live: bool = false
var _nope_tween: Tween = null
var _dim_tween: Tween = null
## The END seal's own root — dimmed while the queue drains.
var _end_turn: Control
var _end_shell: Control
var _end_glow: TextureRect
var _end_ready: bool = false
var _locked: bool = false
## One clock for both artReady beacons, so the lantern and the seal breathe in
## phase the way two CSS animations started the same frame do.
var _beacon_t: float = 0.0
var _hover_tw: Dictionary = {}
var _draw_pile: Pile
var _ashes_pile: Pile
var _discard_pile: Pile
var _vial_frame: bool = true
## The last nine values drawn; empty forces the first pass through.
var _last: PackedInt32Array = PackedInt32Array()
## `chromeIn` (styles.css:741) names four clusters — the energy orb, the END
## seal, the piles and the lantern — and not the top strip, which fades into the
## scene rather than sliding into it. Collected at build time so the entrance
## does not have to go looking for them.
var _chrome_in: Array[Control] = []


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
## The shape is injected the same way `CombatScreen`'s is, and defaults the same
## way: `pad-landscape` resolves to exactly the ten boxes that used to be written
## out in this file, so every existing caller gets an unchanged HUD.
func _init(vial_frame: bool = true, wide_plate: bool = true,
		plate: bool = true, stage_shape: StringName = StageShape.IDENTITY) -> void:
	_vial_frame = vial_frame
	_plate_w = PLATE_WIDE_W if wide_plate else PLATE_PARITY_W
	_plate_vial_w = PLATE_WIDE_VIAL if wide_plate else 0.0
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	# Chrome authors no acts at 6e06911, so the act is not a parameter here; the
	# book still resolves through one, which is what lets a future act add chrome
	# without this signature changing.
	_chrome = LayoutBook.resolve(&"chrome", shape, 0)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # only the buttons take input
	_build_top_bar()
	if plate:
		_build_plate()
	_build_energy()
	_build_lantern()
	# Three piles, not two, each wearing its own back — the blue vault, the warm
	# discard, the charred ash. Their boxes are `UIC.draw` / `.ashes` / `.discard`
	# and come from the book, which is where the three rects that used to be
	# written out here were copied from in the first place.
	_draw_pile = _build_pile(&"draw", "DRAW", 1.0)
	_ashes_pile = _build_pile(&"ashes", "ASHES", ASH_FADE)
	_discard_pile = _build_pile(&"discard", "DISCARD", 1.0)
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
	_glide_hp()
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


func set_potions(ids: Array[String], shown: bool) -> void:
	for slot: int in range(_potion_slots.size()):
		var id: String = ids[slot] if slot < ids.size() else ""
		var full: bool = shown and not id.is_empty()
		_potion_slots[slot].visible = shown
		_potion_slots[slot].disabled = not full
		_potion_slots[slot].tooltip_text = id.capitalize() if full else "Empty phial seat"
		_potion_art[slot].texture = icon("potions/" + id) if full else null
		_potion_art[slot].visible = full


func _emit_potion(slot: int) -> void:
	potion_pressed.emit(slot)


## The lantern's art charge, and whether it can be spent. The benchmark arcs one
## pip per emberCap from -140° to 140° (combat.js:754-762; styles.css:1101-1120).
func set_lantern(charges: int, ready: bool, cap: int = 9, spent: bool = false) -> void:
	_lantern_count.text = str(charges)
	var shown_cap: int = clampi(cap, 1, LANTERN_CAP_MAX)
	for i: int in range(_lantern_pips.size()):
		var pip: TextureRect = _lantern_pips[i]
		pip.visible = i < shown_cap
		if not pip.visible:
			continue
		var angle: float = 0.0 if shown_cap == 1 else deg_to_rad(
			lerpf(-140.0, 140.0, float(i) / float(shown_cap - 1)))
		pip.position = Vector2(52.0, 52.0) \
			+ Vector2(sin(angle), -cos(angle)) * LANTERN_PIP_RADIUS \
			- Vector2.ONE * (LANTERN_PIP_SIDE * 0.5)
		# `.lbp` blends between its readings over .25s; the build itself snaps,
		# because a DOM element is born wearing its classes.
		_pip_to(i, Color(1.0, 0.70, 0.35) if i < charges \
			else Color(0.47, 0.39, 0.27, 0.35))
	_pips_live = true
	_lantern_ready = ready
	# `.lantern-btn { transition: filter .25s }` over
	# `.unlit { filter: saturate(.55) brightness(.82) }` — the dim GLIDES on
	# and off rather than snapping, on the stylesheet's own ease.
	var dim_to: Color = Color.WHITE if ready else Color(0.80, 0.82, 0.86)
	var halo_to: float = 1.0 if ready else 0.45
	if not _lantern.modulate.is_equal_approx(dim_to):
		if _dim_tween != null and _dim_tween.is_valid():
			_dim_tween.kill()
		var dim_from: Color = _lantern.modulate
		var halo_from: float = _lantern_glow.modulate.a
		_dim_tween = Motion.bez(self,
			func(t: float) -> void:
				_lantern.modulate = dim_from.lerp(dim_to, t)
				if not _kindle_target:
					_lantern_glow.modulate.a = lerpf(halo_from, halo_to, t),
			LBP_BLEND, Motion.CSS_EASE)
	# .lantern-btn.art-spent .lb-ic { opacity: .35 }
	_lantern_art.modulate.a = 0.35 if spent else 1.0


## Aim (or snap) one ember pip's tint. Progress is stepped in `_process`.
func _pip_to(i: int, want: Color) -> void:
	if _pip_target[i].is_equal_approx(want):
		return
	_pip_target[i] = want
	if not _pips_live:
		_lantern_pips[i].modulate = want
		_pip_from[i] = want
		_pip_u[i] = 1.0
		return
	_pip_from[i] = _lantern_pips[i].modulate
	_pip_u[i] = 0.0


# ---------------------------------------------------------------- top bar

## `.hud-bar`: 56px, padding 8/16, gap 18, and a background that is a downward
## fade rather than a panel — it has no border, it dissolves into the fight.
func _build_top_bar() -> void:
	# One ratio for everything that merely shrinks, and two numbers for the two
	# things that are decisions rather than shrinkage. See `LayoutBook.FIELDS`
	# under `hud/scale` for why the bar is not simply scaled whole.
	var k: float = _hud_num("scale", 1.0)
	var hp_w: float = _hud_num("stat", HP_WRAP_W)
	var bar: Control = Control.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = bar_height()
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
	row.offset_left = BAR_PAD * k
	row.offset_right = -BAR_PAD * k
	row.add_theme_constant_override("separation", int(BAR_GAP * k))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)

	# .hud-hp-wrap — numerals over a 7px rail, 3px apart, 170 wide.
	var hp_wrap: VBoxContainer = VBoxContainer.new()
	hp_wrap.custom_minimum_size = Vector2(hp_w, 0.0)
	hp_wrap.add_theme_constant_override("separation", 3)
	hp_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hp_wrap)
	var hp_stat: HBoxContainer = _stat_row()
	hp_stat.add_child(_icon_rect("ui/heart", 14.0 * k))
	_hp_num = _num_label(17.0 * k, HP_NUM, GlassStyle.CINZEL_700, 0)
	hp_stat.add_child(_hp_num)
	hp_wrap.add_child(hp_stat)
	var rail: Panel = Panel.new()
	rail.custom_minimum_size = Vector2(hp_w, 7.0 * k)
	rail.add_theme_stylebox_override("panel", _flat(Color(1.0, 1.0, 1.0, 0.12), 4))
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_wrap.add_child(rail)
	# The fill keeps the CSS gradient and gives up the CSS rounding: a rounded
	# gradient needs a shader, and at 7px tall the gradient is what reads.
	_hp_fill = _gradient_rect(HP_FILL_A, HP_FILL_B)
	_hp_fill.size = Vector2(hp_w, 7.0 * k)
	rail.add_child(_hp_fill)

	var gold_stat: HBoxContainer = _stat_row()
	gold_stat.add_child(_icon_rect("ui/coin", 14.0 * k))
	_gold_num = _num_label(17.0 * k, GOLD, GlassStyle.CINZEL_700, 0)
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
	_title_lead = _num_label(14.0 * k, PARCHMENT, GlassStyle.CINZEL_700, 3)
	mid.add_child(_title_lead)
	_title_tail = _num_label(14.0 * k, TEXT_DIM, GlassStyle.CINZEL_700, 2)
	mid.add_child(_title_tail)
	# `.hud-mid { display: none }` — a phone held upright has 22px of bar left
	# after the HP block, the purse and the two seals, and a title that shrinks
	# to fit that is not a title. It goes, and the act and floor are read off the
	# map instead (`styles.css:2109`, whose comment says exactly that).
	#
	# The LABELS go, not the box. `.hud-mid` is `flex: 1` and upstream's `display:
	# none` frees that space for the row's own `justify-content` to take up;
	# hiding this container instead just collapses it and leaves the deck and
	# menu seals stranded a third of the way from the right edge.
	if _hud_num("title", 1.0) < 1.0:
		_title_lead.visible = false
		_title_tail.visible = false

	var right: HBoxContainer = HBoxContainer.new()
	right.add_theme_constant_override("separation", int(10.0 * k))
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)

	# Empty seats remain visible: the benchmark keeps the three 38 × 44 phial
	# frames in the bar so capacity is readable before the first pickup.
	for slot: int in range(3):
		var potion: Button = Button.new()
		potion.custom_minimum_size = Vector2(38.0, 44.0) * k
		potion.focus_mode = Control.FOCUS_NONE
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var seat: StyleBoxFlat = _flat(Color(0.025, 0.032, 0.068, 0.78), 8)
			seat.set_border_width_all(1)
			seat.border_color = GOLD if state == "hover" \
				else Color(1.0, 1.0, 1.0, 0.20)
			potion.add_theme_stylebox_override(state, seat)
		potion.pressed.connect(_emit_potion.bind(slot))
		right.add_child(potion)
		_potion_slots.append(potion)
		var potion_art: TextureRect = TextureRect.new()
		potion_art.set_anchors_preset(Control.PRESET_FULL_RECT)
		potion_art.offset_left = 5.0 * k
		potion_art.offset_top = 5.0 * k
		potion_art.offset_right = -5.0 * k
		potion_art.offset_bottom = -5.0 * k
		potion_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		potion_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		potion_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		potion.add_child(potion_art)
		_potion_art.append(potion_art)

	# .icon-btn.deck-btn — a 44px hit area under 56px of art, with the count
	# sitting on the seal in white.
	var deck: Button = _bare_button(Vector2(44.0, 44.0) * k)
	deck.tooltip_text = "Deck"
	deck.pressed.connect(func() -> void: deck_pressed.emit())
	right.add_child(deck)
	var seal: TextureRect = _icon_rect("ui/deck", 56.0 * k)
	seal.position = Vector2(-6.0, -6.0) * k
	deck.add_child(seal)
	_deck_count = _num_label(22.0 * k, Color.WHITE, GlassStyle.CINZEL_800, 0)
	_deck_count.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deck_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deck_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(_deck_count, 6)
	deck.add_child(_deck_count)

	# .icon-btn — the one piece of chrome that keeps a box: 40px, radius 10,
	# ink fill, hairline rim.
	var menu: Button = Button.new()
	menu.custom_minimum_size = Vector2(40.0, 40.0) * k
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
	var menu_ic: TextureRect = _icon_rect("ui/menu", 19.0 * k)
	menu_ic.set_anchors_preset(Control.PRESET_CENTER)
	menu_ic.offset_left = -9.5 * k
	menu_ic.offset_top = -9.5 * k
	menu_ic.offset_right = 9.5 * k
	menu_ic.offset_bottom = 9.5 * k
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
	_place(plate, PLATE_CX - _plate_w * 0.5, PLATE_BOTTOM,
		Vector2(_plate_w, PLATE_H))
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


## Run the two rails toward the HP the player now has. Nothing here waits for a
## layout: the top bar owns its own width, and the plate's rail is re-measured by
## `_layout_plate`, so the plate's step asks for that instead of writing a width
## the next layout would throw away.
func _glide_hp() -> void:
	if _hp_bar_tween != null and _hp_bar_tween.is_valid():
		_hp_bar_tween.kill()
	if _hp_plate_tween != null and _hp_plate_tween.is_valid():
		_hp_plate_tween.kill()
	if not _hp_seeded:
		_hp_seeded = true
		_set_hp_bar(1.0, _hp_ratio, _hp_ratio)
		if _plate_rail != null:
			_set_hp_plate(1.0, _hp_ratio, _hp_ratio)
		return
	_hp_bar_tween = create_tween()
	_hp_bar_tween.tween_method(_set_hp_bar.bind(_hp_shown_bar, _hp_ratio),
		0.0, 1.0, HP_BAR_TIME)
	if _plate_rail == null:
		return
	_hp_plate_tween = create_tween()
	_hp_plate_tween.tween_method(_set_hp_plate.bind(_hp_shown_plate, _hp_ratio),
		0.0, 1.0, HP_PLATE_TIME)


func _set_hp_bar(t: float, from: float, to: float) -> void:
	_hp_shown_bar = lerpf(from, to, Motion.ease(HP_EASE, t))
	_hp_fill.size.x = _hud_num("stat", HP_WRAP_W) * _hp_shown_bar


func _set_hp_plate(t: float, from: float, to: float) -> void:
	_hp_shown_plate = lerpf(from, to, Motion.ease(HP_EASE, t))
	_layout_plate()


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
	_plate_fill.size = Vector2((_plate_rail.size.x - rim * 2.0) * _hp_shown_plate,
		RAIL_H - rim * 2.0)
	if _plate_frame != null:
		_plate_frame.position = Vector2(vial_x - 5.0, (PLATE_H - 22.0) * 0.5)
		_plate_frame.size = Vector2(vial_w + 10.0, 22.0)
	_plate_label.position = Vector2(vial_x + vial_w + PLATE_GAP, 8.0)


## `.energy-orb` — a 44px numeral standing on a row of candles, overlapping them
## by 10px. The candles are the gauge; the numeral is the read.
func _build_energy() -> void:
	_energy_orb = Control.new()
	var shell: Control = _place_widget(_energy_orb, "energy", Vector2(120.0, 90.0))
	add_child(_energy_orb)
	_chrome_in.append(_energy_orb)

	_candle_field = Control.new()
	_candle_field.position = Vector2(0.0, 34.0)
	_candle_field.size = Vector2(120.0, 56.0)
	_candle_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(_candle_field)

	_energy_num = _num_label(44.0, PALE, GlassStyle.CINZEL_800, 0)
	_energy_num.size = Vector2(120.0, 48.0)
	_energy_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(_energy_num, 10)
	shell.add_child(_energy_num)


## `.lantern-btn` — the art charge. Its own setter, not one of the eight values.
func _build_lantern() -> void:
	_lantern = Control.new()
	var shell: Control = _place_widget(_lantern, "lantern", Vector2(104.0, 104.0))
	_lantern_shell = shell
	add_child(_lantern)
	_chrome_in.append(_lantern)
	# The benchmark drop-shadows the lantern in its own firelight; a soft radial
	# behind it is the cheap read of the same thing.
	_lantern_glow = TextureRect.new()
	_lantern_glow.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(1.0, 0.71, 0.35, 0.30), Color(1.0, 0.60, 0.25, 0.0)]),
		PackedFloat32Array([0.0, 1.0]), true, Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	_lantern_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lantern_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_lantern_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lantern_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(_lantern_glow)

	var btn: Button = _bare_button(Vector2(104.0, 104.0))
	btn.tooltip_text = "Lantern — spend a charge"
	btn.pressed.connect(func() -> void: lantern_pressed.emit())
	shell.add_child(btn)
	_lantern_body = btn
	_lantern_art = _icon_rect("ui/lantern", 94.0)
	_lantern_art.position = Vector2(5.0, 5.0)
	btn.add_child(_lantern_art)
	_lantern_count = _num_label(26.0, PALE, GlassStyle.CINZEL_800, 0)
	_lantern_count.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lantern_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lantern_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(_lantern_count, 8)
	btn.add_child(_lantern_count)

	var pip_texture: Texture2D = GlassStyle.grad_tex(
		PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)]),
		PackedFloat32Array([0.0, 1.0]), true, Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	for i: int in range(LANTERN_CAP_MAX):
		var pip: TextureRect = TextureRect.new()
		pip.texture = pip_texture
		# Expand mode FIRST: while a TextureRect is in KEEP_SIZE its texture is
		# its minimum, so a `size` written before this line is clamped to the
		# gradient's 256px and stays there — nine quarter-screen "pips" whose
		# stacked 35% unlit tint was measured halving the hero plate under them.
		pip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pip.stretch_mode = TextureRect.STRETCH_SCALE
		pip.size = Vector2.ONE * LANTERN_PIP_SIDE
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shell.add_child(pip)
		_lantern_pips.append(pip)
		_pip_from.append(Color.WHITE)
		_pip_target.append(Color.WHITE)
		_pip_u.append(1.0)
	set_lantern(0, false)


## `.pile-btn` — a fan of card backs, the count on its shoulder, the name
## underneath. `.pile-stack` is inset 18px from the bottom to leave that name
## room, and the faces are drawn at the box's own width.
func _build_pile(which: StringName, name_text: String, fade: float) -> Pile:
	var root: Control = Control.new()
	# The pile is drawn against PILE_BOX whatever the shape; the shell is what
	# turns that into the 68x108 a phone actually gets.
	var box: Vector2 = PILE_BOX
	var shell: Control = _place_widget(root, String(which), box)
	root.modulate = Color(1.0, 1.0, 1.0, fade)
	add_child(root)
	_chrome_in.append(root)

	var btn: Button = _bare_button(box)
	btn.pressed.connect(func() -> void: pile_pressed.emit(which))
	shell.add_child(btn)
	# `.pile-btn:hover { transform: translateY(-3px); filter: brightness(1.08) }`
	# on the same .15s glide (styles.css:1403).
	_hover_glide(btn, shell, 3.0)

	var p: Pile = Pile.new()
	p.stack = Fan.new()
	p.stack.tex = icon("piles/" + str(which))
	p.stack.face = box.x
	p.stack.size = Vector2(box.x, box.y - 18.0)
	p.stack.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	p.stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(p.stack)

	p.count = _num_label(16.0, PARCHMENT, GlassStyle.CINZEL_800, 0)
	p.count.position = Vector2(0.0, box.y - 34.0)
	p.count.size = Vector2(box.x - 2.0, 16.0)
	p.count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_outline(p.count, 6)
	btn.add_child(p.count)

	var tag: Label = _num_label(10.0, TEXT_DIM, GlassStyle.CINZEL_700, 1)
	tag.text = name_text
	tag.position = Vector2(0.0, box.y - 14.0)
	tag.size = Vector2(box.x, 13.0)
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
	# Spelled out from the transform rather than taken from `get_global_rect()`,
	# and the two agree: measured on 4.7.1, that accessor IS scale-aware in both
	# origin and size, so a phone's pile reports 68px and not the 96 it is drawn
	# at. This form is here because the shell scaling makes the question worth
	# asking at the call site, not because the accessor is wrong.
	var xf: Transform2D = p.stack.get_global_transform()
	return Rect2(xf.origin, p.stack.size * xf.get_scale())


## `.end-turn.enemy-phase` (styles.css:1397) — while the queue drains, the END
## seal dims to 0.45 and stops taking the pointer. The screen already refuses a
## press while the pump is busy; this is the half that says so.
func set_locked(locked: bool) -> void:
	_locked = locked
	if _end_turn == null:
		return
	_end_turn.modulate.a = 0.45 if locked else 1.0
	_end_turn.mouse_filter = Control.MOUSE_FILTER_IGNORE if locked \
		else Control.MOUSE_FILTER_PASS
	# `.end-turn.enemy-phase { animation: none }` — a seal that cannot be
	# pressed does not beckon (styles.css:1394).
	if locked and _end_glow != null:
		_end_glow.modulate.a = 0.0


## `.end-turn.ready` — the energy is spent and the fight is live, so the seal
## beckons on the same `artReady` breath as the lantern (combat.js:779).
func set_end_ready(on: bool) -> void:
	if _end_ready == on:
		return
	_end_ready = on
	if not on and _end_glow != null:
		_end_glow.modulate.a = 0.0


## `.lantern-btn.kindle-target` — a burnable card is in the air and the lantern
## calls for it: brighter, wider halo, a 1.07 swell (combat.js:1127, :1140).
func set_kindle_target(on: bool) -> void:
	if _kindle_target == on:
		return
	_kindle_target = on
	if not on:
		_lantern_neutral()


## The lantern at rest — every beacon channel returned to what `set_lantern`
## last said. Called when a pulse ends, never per frame.
func _lantern_neutral() -> void:
	if _lantern_shell == null:
		return
	_lantern_shell.modulate = Color.WHITE
	if _lantern_body != null:
		_lantern_body.scale = Vector2.ONE
	_lantern_glow.scale = Vector2.ONE
	_lantern_glow.modulate.a = 1.0 if _lantern_ready else 0.45


## `@keyframes nope` — the refusal shake, 0.32s ease: −7px/−1.5° at 25%,
## +7px/+1.5° at 65%, home (styles.css:610-611). The shell takes the shove and
## the body the tilt, because the shell's pivot is the shape adapter's origin
## and must not move.
func nope() -> void:
	if _lantern_shell == null or not is_inside_tree():
		return
	if _nope_tween != null and _nope_tween.is_valid():
		_nope_tween.kill()
		_nope_at(1.0)
	_lantern_body.pivot_offset = _lantern_body.size * 0.5
	_nope_tween = create_tween()
	_nope_tween.tween_method(_nope_at, 0.0, 1.0, Motion.NOPE_TIME).set_trans(Tween.TRANS_LINEAR)


func _nope_at(u: float) -> void:
	if _lantern_shell == null or _lantern_body == null:
		return
	_lantern_shell.position.x = Motion.css_keyframe(u, Motion.NOPE_AT, Motion.NOPE_X, Motion.CSS_EASE)
	_lantern_body.rotation_degrees = Motion.css_keyframe(u, Motion.NOPE_AT, Motion.NOPE_ROT, Motion.CSS_EASE)


## The beacons' one clock, and the pip blends. 17.6s is a common multiple of
## both pulse periods, so the wrap is invisible to either. One clock for both
## `artReady` seats keeps the lantern and the seal breathing in phase, the way
## two CSS animations started on the same frame do.
func _process(delta: float) -> void:
	_beacon_t = fmod(_beacon_t + delta, 17.6)
	var pstep: float = delta / LBP_BLEND
	for i: int in range(_lantern_pips.size()):
		if _pip_u[i] < 1.0:
			_pip_u[i] = minf(1.0, _pip_u[i] + pstep)
			_lantern_pips[i].modulate = _pip_from[i].lerp(_pip_target[i], _pip_u[i])
	if _lantern_shell != null:
		if _kindle_target:
			var p: float = Motion.css_pulse(
				fmod(_beacon_t, KINDLE_TIME) / KINDLE_TIME, 0.0, 1.0)
			_lantern_shell.modulate = Color.WHITE.lerp(
				Color(KINDLE_BRIGHT, KINDLE_BRIGHT, KINDLE_BRIGHT), p)
			_lantern_body.pivot_offset = _lantern_body.size * 0.5
			_lantern_body.scale = Vector2.ONE * lerpf(1.0, KINDLE_SCALE, p)
			_lantern_glow.pivot_offset = _lantern_glow.size * 0.5
			_lantern_glow.scale = Vector2.ONE * lerpf(1.0, 1.4, p)
			_lantern_glow.modulate.a = lerpf(0.6, 1.0, p)
		elif _lantern_ready:
			var p: float = Motion.css_pulse(
				fmod(_beacon_t, ART_READY_TIME) / ART_READY_TIME, 0.0, 1.0)
			_lantern_shell.modulate = Color.WHITE.lerp(
				Color(ART_READY_BRIGHT, ART_READY_BRIGHT, ART_READY_BRIGHT), p)
			_lantern_glow.pivot_offset = _lantern_glow.size * 0.5
			_lantern_glow.scale = Vector2.ONE * lerpf(1.0, 1.28, p)
		elif not _lantern_shell.modulate.is_equal_approx(Color.WHITE) \
				or _lantern_body.scale != Vector2.ONE:
			_lantern_neutral()
	# The seal's beckon lives on its halo alone: hover owns the shell's own
	# modulate, and two writers on one channel is how a glide gets stomped.
	if _end_glow != null:
		if _end_ready and not _locked:
			var p: float = Motion.css_pulse(
				fmod(_beacon_t, ART_READY_TIME) / ART_READY_TIME, 0.0, 1.0)
			_end_glow.pivot_offset = _end_glow.size * 0.5
			_end_glow.scale = Vector2.ONE * lerpf(1.0, 1.28, p)
			_end_glow.modulate.a = p
		elif (not _end_ready or _locked) and _end_glow.modulate.a > 0.0:
			_end_glow.modulate.a = 0.0


## Hover glide — `transition: transform .15s, filter .15s` on the stylesheet's
## own `ease`: the host lifts `lift` px and brightens 1.08 while the pointer
## rests on it.
func _hover_glide(btn: Button, host: Control, lift: float) -> void:
	btn.mouse_entered.connect(func() -> void: _glide(host, -lift, HOVER_BRIGHT))
	btn.mouse_exited.connect(func() -> void: _glide(host, 0.0, Color.WHITE))


func _glide(host: Control, to_y: float, tint: Color) -> void:
	var prev: Variant = _hover_tw.get(host)
	if prev is Tween:
		var prev_tw: Tween = prev
		if prev_tw.is_valid():
			prev_tw.kill()
	var from_y: float = host.position.y
	var from_c: Color = host.modulate
	_hover_tw[host] = Motion.bez(host,
		func(s: float) -> void:
			host.position.y = lerpf(from_y, to_y, s)
			host.modulate = from_c.lerp(tint, s),
		HOVER_TIME, Motion.CSS_EASE)


## `chromeIn` (styles.css:741) — the furniture rises 44px into place a beat
## behind the actors: 0.5s on a 0.4s delay, `backwards`, so it is already at its
## start pose when the fight opens rather than snapping there.
##
## The top strip is deliberately not in the list. The benchmark names four
## clusters and the strip is not one of them — it belongs to the scene, and a
## bar that slides in reads as a second stage entrance competing with the first.
func play_entrance() -> void:
	if not is_inside_tree():
		return
	for node: Control in _chrome_in:
		if node == null or not is_instance_valid(node):
			continue
		var home: Vector2 = node.position
		var rest: float = node.modulate.a
		node.position = home + Vector2(0.0, 44.0)
		node.modulate.a = 0.0
		var tw: Tween = node.create_tween()
		tw.tween_interval(0.4)
		tw.tween_method(func(x: float) -> void:
			if not is_instance_valid(node):
				return
			var e: float = Motion.ease(Motion.ENTER, x)
			node.position = home + Vector2(0.0, 44.0 * (1.0 - e))
			node.modulate.a = rest * e,
			0.0, 1.0, 0.5)


## `playReshuffleCeremony` (drain.js:132) — the discard walks back into the draw
## pile. The faces belong to the piles, so the flight is flown from here rather
## than from the hand: no CardView exists for a card nobody has drawn, and the
## art in the air is the same pile back the stack is already drawing.
##
## Fire-and-forget: the caller waits `seconds` and then bumps the pile, exactly
## as the drain awaits `flyCardBacks` and calls `bumpPile` after it.
func fly_backs(from: StringName, to: StringName, n: int, seconds: float) -> void:
	var src: Rect2 = pile_rect(from)
	var dst: Rect2 = pile_rect(to)
	var tex: Texture2D = icon("piles/" + str(from))
	if tex == null or n <= 0:
		return
	# Staggered inside the same window the whole ceremony gets, so a six-card
	# reshuffle reads as a stream rather than as one thick card.
	var stagger: float = seconds * 0.35 / float(maxi(1, n))
	var flight: float = maxf(0.12, seconds - stagger * float(n - 1))
	for i: int in range(n):
		var face: TextureRect = TextureRect.new()
		face.texture = tex
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.size = src.size
		face.pivot_offset = src.size * 0.5
		face.position = src.position - global_position
		face.modulate.a = 0.0
		add_child(face)
		# A lifted arc, so the stream bows over the stage instead of sliding
		# along the bottom edge behind the hand.
		var lift: float = 90.0 + float(i % 3) * 26.0
		var p0: Vector2 = face.position
		var p1: Vector2 = dst.position - global_position
		var ctrl: Vector2 = (p0 + p1) * 0.5 - Vector2(0.0, lift)
		var tw: Tween = face.create_tween()
		tw.tween_interval(stagger * float(i))
		tw.tween_method(func(x: float) -> void:
			if not is_instance_valid(face):
				return
			var e: float = Motion.ease(Motion.OUT_SOFT, x)
			face.position = Motion.quad(p0, ctrl, p1, e)
			face.rotation = deg_to_rad(lerpf(0.0, 18.0, sin(e * PI)))
			face.modulate.a = minf(1.0, e * 6.0),
			0.0, 1.0, flight)
		tw.tween_callback(face.queue_free)


## Where the lantern hangs, in global px — embers spilled by dying glass fly to
## it, and the drain needs the target before the flight can be aimed.
func lantern_rect() -> Rect2:
	if _lantern == null:
		return Rect2(global_position + size * 0.5, Vector2.ZERO)
	return _lantern.get_global_rect()


## `pileBump` (styles.css:1453) — 0.28s ease-out, up 4px and 5% wider at 40%.
## The pile answers the card that just landed in it; without it a flight ends in
## silence and the deck reads as scenery.
func bump_pile(which: StringName) -> void:
	var p: Pile = _draw_pile
	if which == &"discard":
		p = _discard_pile
	elif which == &"ashes":
		p = _ashes_pile
	if p == null or p.stack == null:
		return
	_keyframe_pop(p.stack, 1.05, -4.0, 0.28)


## `chipPop` / `blockPulse` — 40% of the way through, the widget swells and
## comes back. Which widget and how far is the caller's business.
func pulse(which: StringName) -> void:
	match which:
		&"energy":
			_keyframe_pop(_energy_orb, 1.35, 0.0, 0.35)
		&"lantern":
			_keyframe_pop(_lantern, 1.35, 0.0, 0.4)
		&"ward":
			_keyframe_pop(_ward_chip, 1.3, 0.0, 0.4)
		_:
			push_warning("HudBar: no widget named %s to pulse" % String(which))


## The shared two-beat: out to `peak` scale and `lift` px at 40% of `seconds`,
## then back. Pivoted on the widget's own centre so nothing walks sideways.
func _keyframe_pop(node: Control, peak: float, lift: float, seconds: float) -> void:
	if node == null or not node.is_inside_tree() or node.size == Vector2.ZERO:
		return
	node.pivot_offset = node.size * 0.5
	var home: Vector2 = node.position
	var tw: Tween = node.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(node, "scale", Vector2.ONE * peak, seconds * 0.4)
	tw.parallel().tween_property(node, "position", home + Vector2(0.0, lift), seconds * 0.4)
	tw.tween_property(node, "scale", Vector2.ONE, seconds * 0.6)
	tw.parallel().tween_property(node, "position", home, seconds * 0.6)


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
	var shell: Control = _place_widget(root, "endTurn", Vector2(120.0, 120.0))
	add_child(root)
	_chrome_in.append(root)
	_end_turn = root
	_end_shell = shell
	# The `.ready` beckon's halo — the drop-shadow the stylesheet paints when
	# the energy is spent, as a radial behind the seal. Dark at rest.
	_end_glow = TextureRect.new()
	_end_glow.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(1.0, 0.745, 0.353, 0.55), Color(1.0, 0.706, 0.314, 0.0)]),
		PackedFloat32Array([0.0, 1.0]), true, Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	_end_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_end_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_end_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_glow.modulate.a = 0.0
	shell.add_child(_end_glow)
	var btn: Button = _bare_button(Vector2(120.0, 120.0))
	btn.pressed.connect(func() -> void: end_turn_pressed.emit())
	shell.add_child(btn)
	# `.end-turn { transition: transform .15s, filter .15s }` with hover
	# translateY(-1px) brightness(1.08) (styles.css:1344-1349).
	_hover_glide(btn, shell, 1.0)
	btn.add_child(_icon_rect("ui/end-turn", 120.0))
	var lbl: Label = _num_label(18.0, PALE, GlassStyle.CINZEL_800, 3)
	lbl.text = "END"
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(lbl, 8)
	btn.add_child(lbl)


# ---------------------------------------------------------------- parts

## Hang a cluster off the edges it belongs to. `x` is a distance from the LEFT
## edge, or from the right when `from_right`; `bottom` is always a distance UP
## from the bottom edge. Bottom furniture stays in its corner when the stage
## grows; the top bar is the only thing that spans.
##
## Every figure is a GAP now, where it used to be a coordinate inside a fixed
## 1180x820 screen that `_place` then converted by subtracting the screen size.
## The anchors were always doing that work; stating the gap directly means this
## function no longer needs to know the stage's size at all, which is precisely
## what lets the same call serve a phone.
func _place(node: Control, x: float, bottom: float, box: Vector2,
		from_right: bool = false) -> void:
	var ax: float = 1.0 if from_right else 0.0
	node.anchor_left = ax
	node.anchor_right = ax
	node.anchor_top = 1.0
	node.anchor_bottom = 1.0
	node.offset_left = -(x + box.x) if from_right else x
	node.offset_right = node.offset_left + box.x
	node.offset_bottom = -bottom
	node.offset_top = node.offset_bottom - box.y
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Hang a cluster where the book puts it for this shape, and hand back the shell
## its parts are drawn inside.
##
## `natural` is the size this port DRAWS the widget at — the pad-landscape
## figure every internal offset, font size and icon here was authored against.
## The book states the widget's real size per shape, and those disagree by up to
## a third: `endTurn` is 120 on a pad and 84 held sideways, a pile 96x148 and
## 64x102, the energy orb 120x90 and 72x57. Nothing here was reading that. Every
## widget drew itself at the pad's size wherever it was placed, so a phone got a
## 120px seal on a 390px stage sitting on top of the fight.
##
## Rather than teach nine widgets to lay themselves out at any size — nine
## chances to disagree, which is the shape of the duplication this whole book
## exists to remove — each is drawn ONCE at `natural` inside a shell, and the
## shell carries the difference as a scale. The node itself is the authored box,
## so `_keyframe_pop` still pops the real thing and `_place` still speaks in
## gaps.
##
## The scale is deliberately non-uniform: the book's `w` and `h` are an
## element's CSS width and height upstream, and honouring only one of them would
## put the widget's own edge somewhere the book did not say. The two differ by
## at most 3% on any authored shape, so nothing visibly stretches.
func _place_widget(node: Control, widget: String, natural: Vector2) -> Control:
	var seat: Dictionary = _chrome.get(widget, {})
	if seat.is_empty():
		push_warning("hud: the book has no %s for %s" % [widget, shape])
	var span: Vector2 = Vector2(LayoutBook.num(seat.get("w"), natural.x),
		LayoutBook.num(seat.get("h"), natural.y))
	var from_right: bool = seat.has("right")
	var x: float = LayoutBook.num(seat.get("right" if from_right else "left"))
	_place(node, x, LayoutBook.num(seat.get("bottom")), span, from_right)

	var shell: Control = Control.new()
	shell.size = natural
	# From the top-left, so the shell's box IS the node's box and no part of it
	# has to be nudged back afterwards.
	shell.pivot_offset = Vector2.ZERO
	shell.scale = Vector2(span.x / maxf(1.0, natural.x), span.y / maxf(1.0, natural.y))
	shell.mouse_filter = Control.MOUSE_FILTER_PASS
	node.add_child(shell)
	return shell


## `.hud-bar`'s height for this shape.
func bar_height() -> float:
	return _hud_num("height", BAR_H_FALLBACK)


## One of the rail's four authored numbers.
func _hud_num(field: String, fallback: float) -> float:
	return LayoutBook.num(_chrome.get("hud", {}).get(field), fallback)


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
