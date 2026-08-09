class_name RewardScreen
extends Control
## The spoils of a fight, laid out to be CLAIMED.
##
## Two builds live here, and `bench` picks between them:
##
##   bench = true   The benchmark, ported. Every number measured off the running
##                  web build (reward.js + styles.css, stage 1180x820) with
##                  offsetWidth and computed styles — the same method
##                  card_view.gd used on the card, not eyeballed proportions.
##                  This is the floor, and it is what the port is diffed against.
##
##   bench = false  Past it. Same information architecture — the benchmark's
##                  ordering is right and is kept — but rebuilt on three things
##                  a DOM does not have, each aimed at a place the web build had
##                  to compromise. See BEYOND below.
##
##   var screen := RewardScreen.new(rewards, content, "elite")
##   screen.claimed.connect(...)     # &"gold"/&"card"/&"potion"/&"relic"
##   screen.finished.connect(...)    # Continue, past the leave-confirm
##
## THE SHAPE, kept from the benchmark because it is correct: a reward is not a
## full-screen 3-up. It is a glass panel of claim ROWS standing over the live
## scene, and the card pick sits behind the last row. The player banks gold,
## phial and relic without a decision in front of them; only "Add a card to your
## deck" opens the offering. The spoils settle first, the choice comes last and
## gets the room to itself.
##
## Measured spec, in stage px (both builds share it):
##   panel     560 wide, 28 pad, radius 16, 1.5px #05070E rim with a 1px
##             gold-at-55% rim inside it, shadow 0 24 70 rgba(0,0,0,.65).
##             Centred in a box inset 96 top / 20 bottom — so it rides 38px
##             below the stage's middle, clear of where the HUD will be.
##   title     Cinzel 700 @ 26, tracking .12em, #E8DFC8, over an 84x2 gold
##             hairline that fades out at both ends.
##   ornament  ✦ ✦ ✦ @ 13, tracking .4em, #9C7C34
##   row       502 x 56, radius 12, pad 12/18, bg white@4.3%, rim white@12%,
##             Alegreya 17, icon slot 36 holding 30x30 art, gap 14
##   continue  145 x 46, Cinzel 700 @ 17, gold gradient, ink #1A1206
##   offering  640-wide panel, cards at --cw 178 (the benchmark deliberately
##             shows the pick BIGGER than the hand's 152), 16px gaps
##
## ── BEYOND ────────────────────────────────────────────────────────────────
## Three compromises in the web build, and what replaces each here. None of
## them is a new system: all three are machinery this project already owns.
##
## 1. ONE PANEL, TWO DEPTHS. The benchmark opens the pick as a second window
##    over a scrim, because in a DOM a new overlay is cheaper than reshaping a
##    live one — and it costs the player their place, leaves the first panel
##    peeking out underneath, and needs a whole second frame drawn. Here the
##    panel DEEPENS: the rows sink, the frame widens to 640, and the offering
##    rises into the same glass. One object, two states. See _deepen.
##
## 2. THE OFFERING IS DEALT. The cards arrive one after another and are set
##    down slightly turned, the way objects on a shelf are — position and pose,
##    which hold still once they land. The LAMP is deliberately left alone; two
##    versions of this file moved it and both were wrong. See FAN for why, and
##    RARITY below for what that costs.
##
## 3. A CLAIM IS A DEPARTURE, NOT A STRIKETHROUGH. `text-decoration:
##    line-through` is a web idiom for a spent list item; this game already has
##    its own word for a thing that has been used up — GlassWaystone dims a
##    cleared node to "a spent husk". So the object RISES OUT of its seat and
##    the seat goes dark and empty. And the seats are the other half of it: the
##    benchmark's 30px icon in a flex slot becomes a small leaded pane lit from
##    behind in the object's own `tone`, with its rules text on the row instead
##    of hidden in a hover tooltip that a touch device cannot open.
##
## RARITY, and the one thing this file cannot settle: the benchmark's pick shows
## a rarity pill (24x5: common flat #5D6A88, uncommon cyan gradient + 6px glow,
## rare gold gradient + 8px glow) plus per-tier inner rims. card_view.gd
## deliberately ships no pill — "you read it off the stock and the coating
## instead" — and CardSurface.BY_RARITY does make the tier a material
## (starter=plain, common=card, uncommon=opal, rare=nebula).
##
## Measured, under the card's own resting lamp at 178px: the starter separates,
## and common against uncommon does not. Hovering resolves it instantly, which
## is the card's answer and a reasonable one — you hover a card you are actually
## considering. If they must separate at a glance, either the recipes move
## further apart or the pill comes back. Both are the card's call. What this
## screen can honestly offer is the `tiers` case in the reward lab, which puts
## the three side by side so the question can be looked at.
##
## Not ported, each a one-liner when it earns one: the panel's backdrop blur
## (the fill is 93% opaque), its 168deg fill ramp (flattened to the midpoint),
## the 45ms-per-row entry stagger, and the coin/relic flight to the HUD — there
## is no HUD to fly to yet.

## What the player took. `what` is one of &"gold", &"card", &"potion", &"relic";
## `id` is the content id. It is "" for gold, and also "" for &"card" when the
## player SKIPPED the offering — the benchmark spends the slot either way, so
## the screen reports "the card slot is answered", not "a card was taken".
signal claimed(what: StringName, id: String)
## Continue pressed, and the leave-confirm (if it was needed) answered.
signal finished()

const UI_ART: String = "res://assets/art/ui/"
const POTION_ART: String = "res://assets/art/potions/"
const RELIC_ART: String = "res://assets/art/relics/"

# ── measured colours ──────────────────────────────────────────────────────
const LEAD: Color = Color(0.020, 0.027, 0.055)        # #05070E — every rim
const GOLD: Color = Color(0.949, 0.757, 0.306)        # #F2C14E
const GOLD_DIM: Color = Color(0.612, 0.486, 0.204)    # #9C7C34 — the ornament
const GOLD_DEEP: Color = Color(0.784, 0.604, 0.188)   # #C89A30 — button's floor
const PARCHMENT: Color = Color(0.910, 0.875, 0.784)   # #E8DFC8 — display text
const TEXT: Color = Color(0.843, 0.863, 0.918)        # #D7DCEA — reading text
const TEXT_DIM: Color = Color(0.545, 0.576, 0.678)    # #8B93AD — sub lines
const BTN_INK: Color = Color(0.102, 0.071, 0.024)     # #1A1206 — on gold
const DANGER: Color = Color(1.000, 0.349, 0.392)      # #FF5964
## `--glass-fill` is a 168deg ramp from rgba(26,32,52,.92) to rgba(10,13,22,.94);
## at 93% alpha over a dark scene its two ends are a hair apart, so it is carried
## as the midpoint. StyleBoxFlat has no gradient and a mask node for this would
## cost three nodes to move four RGB points.
const GLASS_FILL: Color = Color(0.071, 0.086, 0.145, 0.93)

# ── measured geometry ─────────────────────────────────────────────────────
const PANEL_W: float = 560.0
const PANEL_PAD: float = 28.0
const PANEL_RADIUS: int = 16
const PANEL_TOP: float = 96.0        # .center-panel padding — clears the HUD
const PANEL_BOTTOM: float = 20.0
const ROW_GAP: int = 10
const ROW_RADIUS: int = 12
const ROW_PAD_X: float = 18.0
const RIC_GAP: float = 14.0
const ROW_SLIDE: float = 4.0         # hover: translateX(4px)
const TAKEN_A: float = 0.40
const HAIRLINE: Vector2 = Vector2(84.0, 2.0)
const BTN_H: float = 46.0
const BTN_RADIUS: int = 10
const CHOICE_PANEL_W: float = 640.0
const CHOICE_CARD_W: float = 178.0   # --cw on .choice-cards .card
const CHOICE_GAP: int = 16
const CHOICE_SUB: String = "Add one card to your deck — or skip to keep it lean."
## The offering shows a BIGGER card than the hand does — 178 against 152. Not
## decoration: the pick is decided off the rules text, and the hand's size
## assumes you can hover a card to read it. CardView is fixed at CARD_W, so the
## growth is a node scale; at oversample 2 that still resolves 1.7x above the
## display, so nothing softens.
## The identity column of the book's `reward` scope. Kept as constants because
## they are what `rack/w` and `rack/gap` DEFAULT to, and a fallback that agrees
## with the default is the only kind that cannot introduce a second truth.
const CARD_SCALE: float = CHOICE_CARD_W / CardView.CARD_W
const RACK_H: float = CardView.CARD_H * CARD_SCALE

# ── beyond ────────────────────────────────────────────────────────────────
const ROW_H_BENCH: float = 56.0
const ROW_H: float = 74.0            # room for the rules line the tooltip hid
const RIC_W_BENCH: float = 36.0
const ICON_BENCH: float = 30.0
const SEAT: float = 46.0             # the leaded pane a spoil is set into
const SEAT_ICON: float = 32.0
const SEAT_GLOW: float = 74.0        # the tone bleeding out past the seat
const DEEPEN: float = 0.34           # panel reshape, both directions
## THE LAMP IS NOT THIS SCREEN'S TO MOVE — and that is a correction, not a
## limitation. Two lamp ideas were built here and both are gone: a pass across
## the rack as the cards arrive, and a slow orbit that never stopped afterwards.
##
## Why they were wrong. CardView's lamp has a contract — at rest it is the
## room's, and the CURSOR is where you set it down. Overriding the resting lamp
## for one screen means a card in the offering lights differently from the same
## card in hand, for a reason no player can name. And a light that keeps moving
## under three cards you are trying to READ is not atmosphere, it is a surface
## that will not hold still long enough to be decided on.
##
## What that costs, stated plainly: the tier question goes back open. Under the
## room's lamp the three materials (starter=plain, common=card, uncommon=opal)
## are nearly indistinguishable until you hover one — which is the card's own
## answer, and a fine one, since hovering is what you do to a card you are
## considering. If the tiers must separate WITHOUT hover, that belongs in
## CardSurface pulling the recipes further apart, or in the benchmark's rarity
## pill coming back. Neither is this file's call.
##
## Cards do still sit slightly turned, the way objects set on a shelf do. That
## is a pose, not a light, and it holds still. Normalised against MAX_TILT
## (7deg), so 0.26 is under two degrees.
const FAN: float = 0.26

# ── entrance ──────────────────────────────────────────────────────────────
## The panel arrives rather than existing. All of it lands inside the shot
## harness's ~0.5s settle (main.gd _capture_and_quit waits 30 frames), so a
## scripted capture still catches the finished pose.
const ENTER: float = 0.28
const ENTER_SCALE: float = 0.968
const ENTER_RULE: float = 0.34       # the title's gold line drawing outward
const ROW_STAGGER: float = 0.045     # the benchmark's own 45ms-per-row cascade
const ROW_RISE: float = 7.0
## The offering is DEALT, not revealed: each card arrives a beat after the one
## before, which is also what makes the lamp's pass read as a lantern following
## the deal rather than an effect layered over it.
const DEAL: float = 0.26
const DEAL_STAGGER: float = 0.07
const DEAL_RISE: float = 22.0

var reward: Dictionary = {}
var content: ContentDB
var encounter_kind: String = "normal"
var bench: bool = false

## The stage shape this screen composes for, and its resolved `reward` layout.
## The rack is the only part that varies: a 178px card is 46% of a phone's
## width, and three of them side by side are 137% of it.
var shape: StringName = StageShape.IDENTITY
var _rack_layout: Dictionary = {}

var _rows: Array[Button] = []        # claim order; the card slot is the last
var _row_of: Dictionary = {}         # StringName -> Button
var _card_row: Button = null
var _cards: Array[CardView] = []
var _body: VBoxContainer = null
var _panel: PanelContainer = null
var _panel_inner_style: StyleBoxFlat = null
var _rule: Control = null
var _title: Label = null
var _ornament: Label = null
var _sub: Label = null
var _rows_slot: Control = null
var _rack_slot: Control = null
var _rack: HBoxContainer = null
var _continue: Button = null
var _skip: Button = null
var _overlay: ColorRect = null       # the scrim; one at a time, reused
var _deep: bool = false
var _picked: bool = false

## One FontVariation per (face, tracking); Label wants a Font resource and a
## fresh one per label re-pays the shaping setup.
static var _fonts: Dictionary = {}


func _init(reward_ref: Dictionary, content_ref: ContentDB,
		kind: String = "normal", benchmark: bool = false,
		stage_shape: StringName = StageShape.IDENTITY) -> void:
	reward = reward_ref
	content = content_ref
	encounter_kind = kind
	bench = benchmark
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	_rack_layout = LayoutBook.resolve(&"reward", shape)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	# No ground of its own: the benchmark's reward panel stands over the live
	# scene with the HUD still lit and scrims nothing. The caller owns what is
	# behind — the lab paints a stand-in.
	var frame: MarginContainer = MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_top", int(_rack_num("top", PANEL_TOP)))
	frame.add_theme_constant_override("margin_bottom", int(_rack_num("bottom", PANEL_BOTTOM)))
	frame.add_theme_constant_override("margin_left", 12)
	frame.add_theme_constant_override("margin_right", 12)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(scroll)
	var centre: CenterContainer = CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(centre)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 0)
	_body.custom_minimum_size = Vector2(
		_panel_body_width(_rack_num("panel", PANEL_W), PANEL_PAD - 2.0), 0.0)
	_panel = _glass_panel(_body)
	var inner_style_v: Variant = _panel.get_meta("inner_style")
	if inner_style_v is StyleBoxFlat:
		_panel_inner_style = inner_style_v
	centre.add_child(_panel)

	_title = _heading(_title_text())
	_body.add_child(_title)
	_rule = _hairline()
	_body.add_child(_rule)
	# Two captions in one place: the ornament while the panel is shallow, the
	# offering's instruction once it has deepened. Swapped rather than restyled —
	# they are different faces at different sizes.
	_ornament = _ornament_label()
	_body.add_child(_ornament)
	_sub = _sub_label(Locale.active.t("ui.reward.chooseCardBody"))
	_sub.visible = false
	_body.add_child(_sub)
	_body.add_child(_spacer(14.0))

	_rows_slot = _slot()
	# NOT clipped at rest. A row slides 4px right under the cursor and its rim
	# is the thing that lit up, so a shelf cutting to the body width shears the
	# gold off exactly the edge you were meant to look at. The cut is only for
	# the sink into the offering — _deepen turns it on, _shallow turns it off.
	_rows_slot.clip_contents = false
	_body.add_child(_rows_slot)
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", ROW_GAP)
	list.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_rows_slot.add_child(list)
	_build_rows(list)
	var n: int = _rows.size()
	var rows_h: float = float(n) * _row_h() + float(maxi(0, n - 1)) * float(ROW_GAP)
	list.offset_bottom = rows_h
	_rows_slot.custom_minimum_size = Vector2(0.0, rows_h)

	# The offering's own slot, empty and flat until the panel deepens. Nothing
	# is built into it up front: three CardViews are six offscreen viewports,
	# and a shallow panel should not be paying for a decision nobody opened.
	_rack_slot = _slot()
	_rack_slot.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_body.add_child(_rack_slot)
	_rack = HBoxContainer.new()
	_rack.alignment = BoxContainer.ALIGNMENT_CENTER
	_rack.add_theme_constant_override("separation", roundi(_rack_num("gap", float(CHOICE_GAP))))
	_rack.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_rack.offset_bottom = _rack_h()
	_rack_slot.add_child(_rack)

	_body.add_child(_spacer(20.0))
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	_body.add_child(actions)
	_continue = _button(Locale.active.t("ui.reward.continue"), GO_PRIMARY)
	_continue.pressed.connect(_on_continue)
	actions.add_child(_continue)
	_skip = _button(Locale.active.t("ui.reward.skip"), GO_GHOST)
	_skip.visible = false
	_skip.pressed.connect(func() -> void: _take_card(""))
	actions.add_child(_skip)


## The panel LANDS. One frame is waited out first because a Control's size is
## the container's to set and it is not known until after layout — and the
## pivot has to be the panel's middle or the glass grows out of its top-left
## corner like a dropdown.
func _ready() -> void:
	if bench:
		return                    # the floor arrives the way a DOM does: at once
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var bar: Control = _rule.get_meta("bar")
	bar.scale = Vector2(0.0, 1.0)
	for btn: Button in _rows:
		var slot: Control = btn.get_meta("slot")
		slot.modulate = Color(1.0, 1.0, 1.0, 0.0)
		btn.offset_top = ROW_RISE
		btn.offset_bottom = ROW_RISE
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(ENTER_SCALE, ENTER_SCALE)

	var tw: Tween = create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, ENTER)
	tw.tween_property(_panel, "scale", Vector2.ONE, ENTER)
	# The rule is struck, not faded — it opens from the centre outward, which is
	# the gesture the benchmark's ::after gradient is already drawn for.
	tw.tween_property(bar, "scale", Vector2.ONE, ENTER_RULE).set_delay(0.08)
	# Then the spoils arrive one after another. The benchmark stages this too
	# (--si * 45ms on .reward-row); it is the only part of its entrance that
	# survives being ported, because it is timing rather than CSS.
	var i: int = 0
	for btn: Button in _rows:
		var slot: Control = btn.get_meta("slot")
		var at: float = 0.10 + ROW_STAGGER * float(i)
		tw.tween_property(slot, "modulate:a", 1.0, 0.22).set_delay(at)
		tw.tween_property(btn, "offset_top", 0.0, 0.26).set_delay(at)
		tw.tween_property(btn, "offset_bottom", 0.0, 0.26).set_delay(at)
		i += 1


func _row_h() -> float:
	return ROW_H_BENCH if bench else ROW_H


## A clipped shelf the panel can grow and shrink. Its child is anchored to the
## TOP at a fixed height, so shrinking the shelf slides the content out of sight
## behind the cut instead of squashing it.
static func _slot() -> Control:
	var c: Control = Control.new()
	c.clip_contents = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# ---------------------------------------------------------------- rows

## Reward order is the benchmark's: gold, phial, relic, then the card slot last.
func _build_rows(list: VBoxContainer) -> void:
	list.add_child(_row(&"gold", "", UI_ART + "coin.png",
		Locale.active.t("ui.reward.goldRow", {"tone": GOLD.to_html(false), "n": _gold()}),
		"", GOLD))
	var potion_v: Variant = reward.get("potion")
	if potion_v != null:
		var pid: String = str(potion_v)
		var p: Dictionary = content.potions.get(pid, {})
		list.add_child(_row(&"potion", pid, POTION_ART + pid + ".png",
			str(p.get("name", pid)), str(p.get("text", "")), _tone(p)))
	var relic_v: Variant = reward.get("relic")
	if relic_v != null:
		var rid: String = str(relic_v)
		var r: Dictionary = content.relics.get(rid, {})
		list.add_child(_row(&"relic", rid, RELIC_ART + rid + ".png",
			"[b]%s[/b]" % str(r.get("name", rid)), str(r.get("text", "")),
			_tone(r)))
	# The card row is a door, not a claim: it opens the offering rather than
	# taking anything, and settles once the offering is answered — taken OR
	# skipped. The benchmark always draws it because rollCardReward always
	# returns three; our pools can run dry, and a row that opens onto nothing is
	# worse than no row, so an empty offer simply has no door.
	var ids: Array = reward.get("cards", [])
	if not ids.is_empty():
		list.add_child(_row(&"card", "", UI_ART + "deck.png",
			Locale.active.t("ui.reward.addCard"),
			"" if bench else Locale.active.t("ui.reward.offeredTakeOne", {"n": ids.size()}), GlassStyle.GLASS))
		_card_row = _rows.back()


static func _tone(def: Dictionary) -> Color:
	return Color.from_string(str(def.get("tone", "")), GOLD)


## One claim row. The Button is the frame and the whole hit area; the seat and
## the text are hand-placed children over it (Button is not a container) and
## take no clicks, so a row has exactly one pressed signal however many pieces
## it is made of.
##
## It comes back wrapped, and the wrapper is not decoration: a container child's
## offsets ARE its position, so the hover slide would be wiped by the next
## re-sort. The wrapper is what the list lays out; the Button inside it is a
## hand-placed child nothing re-sorts.
func _row(what: StringName, id: String, art_path: String, bb: String,
		sub: String, tone: Color) -> Control:
	var h: float = _row_h()
	var slot: Control = Control.new()
	slot.custom_minimum_size = Vector2(0.0, h)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var btn: Button = Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(btn)
	_rows.append(btn)
	_row_of[what] = btn

	var rim: StyleBoxFlat = _row_box(Color(1.0, 1.0, 1.0, 0.12))
	btn.add_theme_stylebox_override("normal", rim)
	btn.add_theme_stylebox_override("hover", rim)
	btn.add_theme_stylebox_override("pressed", _row_box(GOLD))
	btn.add_theme_stylebox_override("disabled", rim)

	var art_w: float = ICON_BENCH if bench else SEAT_ICON
	var box_w: float = RIC_W_BENCH if bench else SEAT
	var art: Control = _seat(art_path, tone, art_w) if not bench \
		else _flat_icon(art_path, art_w)
	art.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	art.offset_left = ROW_PAD_X + (box_w - art.custom_minimum_size.x) * 0.5
	art.offset_right = art.offset_left + art.custom_minimum_size.x
	art.offset_top = -art.custom_minimum_size.y * 0.5
	art.offset_bottom = art.custom_minimum_size.y * 0.5
	btn.add_child(art)

	# RichTextLabel rather than Label because the benchmark bolds inside the
	# line — the gold numeral, the relic's name — and marks a spent row with a
	# strikethrough. All of it is one bbcode tag and no extra nodes.
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("normal_font", _font(GlassStyle.ALEGREYA_400, 0))
	label.add_theme_font_override("bold_font", _font(GlassStyle.ALEGREYA_700, 0))
	label.add_theme_font_size_override("normal_font_size", 17)
	label.add_theme_font_size_override("bold_font_size", 17)
	label.add_theme_color_override("default_color", TEXT)
	label.text = bb
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = ROW_PAD_X + box_w + RIC_GAP
	label.offset_right = -ROW_PAD_X
	label.offset_top = 15.0 if sub == "" else 12.0
	label.offset_bottom = -13.0
	btn.add_child(label)

	# What the thing DOES, on the row. The benchmark keeps it in a tooltip bound
	# to hover, which on a touch build is a line of text no player can reach.
	if sub != "":
		var sub_l: Label = Label.new()
		sub_l.text = sub
		sub_l.clip_text = true
		sub_l.add_theme_font_override("font", _font(GlassStyle.ALEGREYA_400, 0))
		sub_l.add_theme_font_size_override("font_size", 13)
		sub_l.add_theme_color_override("font_color", TEXT_DIM)
		sub_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub_l.set_anchors_preset(Control.PRESET_FULL_RECT)
		sub_l.offset_left = label.offset_left
		sub_l.offset_right = -ROW_PAD_X
		sub_l.offset_top = 41.0
		sub_l.offset_bottom = -8.0
		btn.add_child(sub_l)

	btn.set_meta("label", label)
	btn.set_meta("bb", bb)
	btn.set_meta("art", art)
	# The entrance fades the SLOT and the claim fades the BUTTON, deliberately:
	# --take= settles a row while the panel is still arriving, and two tweens on
	# one modulate would fight. On separate nodes they simply multiply.
	btn.set_meta("slot", slot)
	btn.mouse_entered.connect(func() -> void: _row_hover(btn, rim, true))
	btn.mouse_exited.connect(func() -> void: _row_hover(btn, rim, false))
	btn.pressed.connect(_on_row.bind(what, id, btn))
	return slot


## The benchmark's `.ric`: bare art in a flex slot, nothing behind it.
static func _flat_icon(art_path: String, side: float) -> Control:
	var art: TextureRect = TextureRect.new()
	if ResourceLoader.exists(art_path):
		art.texture = load(art_path) as Texture2D
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.custom_minimum_size = Vector2(side, side)
	return art


## BEYOND — the spoil is SET into the panel, not printed on it. A leaded pane in
## the object's own tone with the tone bleeding out behind it, which is the same
## thing the benchmark does for relics with `text-shadow: 0 0 8px tone` and
## cannot do at all for a raster phial. The art rides as a child so a claim can
## lift it out and leave the seat standing empty.
static func _seat(art_path: String, tone: Color, art_w: float) -> Control:
	var holder: Control = Control.new()
	holder.custom_minimum_size = Vector2(SEAT, SEAT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var glow: TextureRect = TextureRect.new()
	glow.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(tone, 0.34), Color(tone, 0.0)]),
		PackedFloat32Array([0.0, 1.0]), true, Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.position = Vector2(SEAT - SEAT_GLOW, SEAT - SEAT_GLOW) * 0.5
	glow.size = Vector2(SEAT_GLOW, SEAT_GLOW)
	holder.add_child(glow)
	holder.set_meta("glow", glow)

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.008, 0.012, 0.027, 0.55)
	sb.set_border_width_all(1)
	sb.border_color = Color(tone, 0.42)
	sb.set_corner_radius_all(11)
	var pane: Panel = Panel.new()
	pane.add_theme_stylebox_override("panel", sb)
	pane.set_anchors_preset(Control.PRESET_FULL_RECT)
	pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(pane)
	holder.set_meta("pane", sb)
	holder.set_meta("tone", tone)

	var art: TextureRect = TextureRect.new()
	if ResourceLoader.exists(art_path):
		art.texture = load(art_path) as Texture2D
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = Vector2(SEAT - art_w, SEAT - art_w) * 0.5
	art.size = Vector2(art_w, art_w)
	holder.add_child(art)
	holder.set_meta("art", art)
	return holder


func _row_hover(btn: Button, rim: StyleBoxFlat, on: bool) -> void:
	if btn.disabled:
		return
	rim.border_color = GOLD if on else Color(1.0, 1.0, 1.0, 0.12)
	var tw: Tween = btn.create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	var to: float = ROW_SLIDE if on else 0.0
	tw.tween_property(btn, "offset_left", to, 0.15)
	tw.tween_property(btn, "offset_right", to, 0.15)


func _on_row(what: StringName, id: String, btn: Button) -> void:
	if what == &"card":
		open_card_choice()
		return
	_settle(btn)
	claimed.emit(what, id)


## A spent row. The benchmark strikes the label through and drops it to 40%;
## past that, the OBJECT LEAVES — it rises out of its seat and fades, the seat's
## rim goes cold, and the row dims with nothing crossed out. Same reading, one
## fewer web idiom, and the seat left standing empty says "this was here" better
## than a line through a word does.
func _settle(btn: Button) -> void:
	if btn.disabled:
		return
	btn.disabled = true
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: RichTextLabel = btn.get_meta("label")
	if bench:
		btn.modulate = Color(1.0, 1.0, 1.0, TAKEN_A)
		label.text = "[s]%s[/s]" % str(btn.get_meta("bb"))
		return
	var seat: Control = btn.get_meta("art")
	var tw: Tween = btn.create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(true)
	tw.tween_property(btn, "modulate:a", TAKEN_A + 0.06, 0.28)
	if seat.has_meta("art"):
		var art: Control = seat.get_meta("art")
		tw.tween_property(art, "position:y", art.position.y - 15.0, 0.34)
		tw.tween_property(art, "modulate:a", 0.0, 0.34)
		# The seat KINDLES as the thing leaves it, then goes cold. A claim that
		# only fades reads as "this stopped mattering"; a flare on the way out
		# reads as "you took it", which is what actually happened — and it is
		# the same beat the web build spends on a coin flying to the purse, kept
		# where the object is rather than aimed at a HUD that does not exist yet.
		var sb: StyleBoxFlat = seat.get_meta("pane")
		var tone: Color = seat.get_meta("tone")
		var glow: Control = seat.get_meta("glow")
		var flare: Tween = seat.create_tween()
		flare.set_parallel(true)
		flare.tween_property(sb, "border_color", Color(tone, 0.95), 0.09)
		flare.tween_property(glow, "modulate:a", 2.1, 0.09)
		flare.chain().set_parallel(true)
		flare.tween_property(sb, "border_color", Color(tone, 0.12), 0.30)
		flare.tween_property(glow, "modulate:a", 0.0, 0.30)


func _gold() -> int:
	var v: int = reward.get("gold", 0)
	return v


## Mark a row already spent without emitting — the state a RESUMED reward is in.
## The web build persists `pendingReward.taken` per slot, so a save reloaded
## mid-reward has to come back with those rows already spent; this is the seam
## that will take it. Silently ignores a slot this reward never offered.
func mark_taken(what: StringName) -> void:
	var btn: Button = _row_of.get(what)
	if btn != null:
		_settle(btn)


## The player asked to leave. Emits `finished` when nothing is left on the glass,
## and otherwise puts the question to them first — spoils walked past are gone.
func request_leave() -> void:
	_on_continue()


func _untaken() -> bool:
	for btn: Button in _rows:
		if not btn.disabled:
			return true
	return false


# ---------------------------------------------------------------- the offering

## Open the pick. Public because the offering is a screen of its own and a still
## of it is otherwise unreachable — it lives behind a row press, which a scripted
## shot cannot make. The game reaches it through the row, like the player does.
func open_card_choice() -> void:
	var ids: Array = reward.get("cards", [])
	if ids.is_empty():
		return           # no offer, no door — see _build_rows
	if bench:
		_open_choice_modal(ids)
		return
	_deepen(ids)


## BEYOND — the panel does not get replaced, it DEEPENS. The rows sink behind
## the shelf's cut, the frame widens from 560 to 640, and the offering rises
## into the same glass. The benchmark opens a second window over a scrim because
## in a DOM that is the cheap move; the cost is that you lose your place, and
## the first panel sits half-visible underneath the second (which is exactly
## what the ported build does — see the scrim shot).
func _deepen(ids: Array) -> void:
	if _deep or _picked:
		return
	_deep = true
	var i: int = 0
	var n: int = ids.size()
	for id_v: Variant in ids:
		var card: CardView = _card(str(id_v), i + 1)
		# Set down on a shelf, so the outer two are turned a hair inward. A pose,
		# not a light: it holds still, and the card's own lamp is untouched.
		var across: float = 0.0 if n < 2 else (float(i) / float(n - 1)) * 2.0 - 1.0
		card.hold_pose(Vector2(-across * FAN, 0.0))
		_cards.append(card)
		var pad: Control = _pedestal(card, _card_scale())
		# Dealt, not revealed. The pedestal carries the arrival so the card's own
		# scale (1.17, the offering's size) is left alone.
		pad.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_rack.add_child(pad)
		var deal: Tween = create_tween()
		deal.set_ease(Tween.EASE_OUT)
		deal.set_trans(Tween.TRANS_CUBIC)
		deal.tween_interval(DEAL_STAGGER * float(i))
		deal.set_parallel(true)
		deal.tween_property(pad, "modulate:a", 1.0, DEAL)
		var home: Vector2 = card.position
		card.position = home + Vector2(0.0, DEAL_RISE)
		deal.tween_property(card, "position", home, DEAL)
		i += 1
	# The rows keep their rects while they slide out of sight, so they would
	# still take a click from behind the cut. Nothing else turns them off.
	for btn: Button in _rows:
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows_slot.clip_contents = true
	# The heading names what the panel is FOR, so it changes with the depth. In
	# the benchmark this was free — the second window had its own title — and it
	# is the one thing the deepening would otherwise lose.
	_title.text = Locale.active.t("ui.reward.chooseCardTitle").to_upper()
	_ornament.visible = false
	_sub.visible = true
	_continue.visible = false
	_skip.visible = true

	var deep_padding: float = _deep_panel_padding(n)
	_set_panel_padding(deep_padding)
	var tw: Tween = create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(true)
	tw.tween_property(_body, "custom_minimum_size:x",
		_panel_body_width(_rack_num("deep", CHOICE_PANEL_W), deep_padding), DEEPEN)
	tw.tween_property(_rows_slot, "custom_minimum_size:y", 0.0, DEEPEN)
	tw.tween_property(_rows_slot, "modulate:a", 0.0, DEEPEN * 0.55)
	tw.tween_property(_rack_slot, "custom_minimum_size:y", _rack_h(), DEEPEN)
	tw.tween_property(_rack_slot, "modulate:a", 1.0, DEEPEN)
	# THE SHELF STOPS CUTTING once the offering is up. A card is not bounded by
	# its own rect — the cost gem overhangs the silhouette by PAD_IN and the
	# table shadow reaches PAD_3D past it on every side — so a shelf clipped to
	# CARD_H exactly shears the top off all three stones. The clip is only there
	# to make the rack RISE rather than pop, so it lives exactly as long as the
	# rise does. _shallow puts it back before the collapse.
	tw.chain().tween_callback(func() -> void: _rack_slot.clip_contents = false)


## The benchmark's own path, kept for the diff: a scrim and a second panel.
func _open_choice_modal(ids: Array) -> void:
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.add_child(_heading("Choose a Card"))
	body.add_child(_hairline())
	body.add_child(_spacer(6.0))
	body.add_child(_sub_label(CHOICE_SUB))
	body.add_child(_spacer(18.0))
	var rack: HBoxContainer = HBoxContainer.new()
	rack.alignment = BoxContainer.ALIGNMENT_CENTER
	rack.add_theme_constant_override("separation", CHOICE_GAP)
	body.add_child(rack)
	var i: int = 0
	for id_v: Variant in ids:
		rack.add_child(_pedestal(_card(str(id_v), i + 1), _card_scale()))
		i += 1
	body.add_child(_spacer(20.0))
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(actions)
	var skip: Button = _button("Skip", GO_GHOST)
	skip.pressed.connect(func() -> void: _take_card(""))
	actions.add_child(skip)
	_show_overlay(body, _rack_num("deep", CHOICE_PANEL_W))


func _card(id: String, uid: int) -> CardView:
	var data: Dictionary = content.cards.get(id, {})
	# `cost` is present-but-null on the unplayable cards, so Dictionary.get's
	# default never fires — the same read combat.gd's eff_cost does.
	var cost_v: Variant = data.get("cost")
	var cost: int = 0 if cost_v == null else int(float(str(cost_v)))
	var card: CardView = CardView.new(CardInst.new(uid, StringName(id)), data, cost)
	var k: float = _card_scale()
	card.scale = Vector2(k, k)
	card.released_at.connect(func(_u: int, _p: Vector2) -> void: _take_card(id))
	return card


## How much bigger than the hand's card the offering draws, for this shape.
##
## Authored as a WIDTH (`rack/w`) rather than as this ratio, because the width
## is the figure a human can measure on the screen and the ratio is not. At the
## identity shape `rack/w` defaults to `CHOICE_CARD_W`, so this is exactly
## `CARD_SCALE` and the pad-landscape composition is untouched.
func _card_scale() -> float:
	return _rack_num("w", CHOICE_CARD_W) / CardView.CARD_W


func _rack_h() -> float:
	return CardView.CARD_H * _card_scale()


func _rack_num(field: String, fallback: float = 0.0) -> float:
	return LayoutBook.num(_rack_layout.get(field), fallback)


func _deep_panel_padding(card_count: int) -> float:
	return _deep_padding_for(
		_rack_num("deep", CHOICE_PANEL_W),
		_rack_num("w", CHOICE_CARD_W),
		_rack_num("gap", float(CHOICE_GAP)),
		card_count)


## The outer two-pixel rim also consumes width. Phone portrait has eleven
## pixels left after its three benchmark-sized cards and gaps, so its deep pane
## uses the remainder instead of keeping the shallow pane's 26-pixel inset.
static func _deep_padding_for(panel_width: float, card_width: float,
		gap: float, card_count: int) -> float:
	var rack_width: float = float(card_count) * card_width \
		+ float(maxi(0, card_count - 1)) * gap
	return clampf((panel_width - rack_width) * 0.5 - 2.0, 3.0, PANEL_PAD - 2.0)


static func _panel_body_width(panel_width: float, padding: float) -> float:
	return panel_width - (padding + 2.0) * 2.0


func _set_panel_padding(padding: float) -> void:
	if _panel_inner_style != null:
		_panel_inner_style.set_content_margin_all(padding)


## Follow a re-pick. Only the rack has anything to say: the panel is 560 wide
## against a stage that is never narrower than its reference, and the rows are
## already bound. The offering is re-scaled in place rather than rebuilt, so a
## card the player is mid-hover over keeps its identity.
func set_shape(stage_shape: StringName) -> void:
	if stage_shape == shape or not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	_rack_layout = LayoutBook.resolve(&"reward", shape)
	if _rack == null:
		return
	var panel_padding: float = _deep_panel_padding(_cards.size()) \
		if _deep else PANEL_PAD - 2.0
	_set_panel_padding(panel_padding)
	_body.custom_minimum_size.x = _panel_body_width(
		_rack_num("deep" if _deep else "panel", CHOICE_PANEL_W if _deep else PANEL_W),
		panel_padding)
	var k: float = _card_scale()
	var span: Vector2 = Vector2(CardView.CARD_W, CardView.CARD_H)
	_rack.add_theme_constant_override("separation", roundi(_rack_num("gap", float(CHOICE_GAP))))
	_rack.offset_bottom = _rack_h()
	for node: Node in _rack.get_children():
		var seat: Control = node as Control
		if seat == null:
			continue
		seat.custom_minimum_size = span * k
		for inner: Node in seat.get_children():
			var card: CardView = inner as CardView
			if card == null:
				continue
			card.scale = Vector2(k, k)
			card.position = (seat.custom_minimum_size - span) * 0.5
	# Only while the offering is actually up: the slot's height is 0 until
	# `_deepen` raises it, and writing a height here would open it early.
	if _rack_slot != null and _rack_slot.custom_minimum_size.y > 0.0:
		_rack_slot.custom_minimum_size.y = _rack_h()


## A scaled CardView still reports its unscaled rect to a container, so three at
## 1.17 would overlap by 26px each. The pedestal reserves the grown box; scale
## runs about CardView's own centred pivot, so the card needs no offset.
static func _pedestal(card: CardView, k: float = CARD_SCALE) -> Control:
	var pad: Control = Control.new()
	pad.custom_minimum_size = Vector2(CardView.CARD_W, CardView.CARD_H) * k
	card.position = (pad.custom_minimum_size
		- Vector2(CardView.CARD_W, CardView.CARD_H)) * 0.5
	pad.add_child(card)
	return pad


## Answering the offering — with a card id, or "" for Skip. Both spend the slot,
## which is the benchmark's rule: the card row settles either way.
func _take_card(id: String) -> void:
	if _picked:
		return
	_picked = true
	if bench:
		_close_overlay()
	else:
		_shallow()
	if _card_row != null:
		_settle(_card_row)
	claimed.emit(&"card", id)


## Back up out of the offering. The cards go with it — they are six offscreen
## viewports and the decision is over.
func _shallow() -> void:
	if not _deep:
		return
	_deep = false
	_rack_slot.clip_contents = true    # cutting again, so the rack sinks
	_title.text = _title_text()
	_ornament.visible = true
	_sub.visible = false
	_skip.visible = false
	_continue.visible = true
	_set_panel_padding(PANEL_PAD - 2.0)
	for btn: Button in _rows:
		if not btn.disabled:
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var rows_h: float = float(_rows.size()) * _row_h() \
		+ float(maxi(0, _rows.size() - 1)) * float(ROW_GAP)
	var tw: Tween = create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(true)
	tw.tween_property(_body, "custom_minimum_size:x",
		_panel_body_width(_rack_num("panel", PANEL_W), PANEL_PAD - 2.0), DEEPEN)
	tw.tween_property(_rack_slot, "custom_minimum_size:y", 0.0, DEEPEN)
	tw.tween_property(_rack_slot, "modulate:a", 0.0, DEEPEN * 0.55)
	tw.tween_property(_rows_slot, "custom_minimum_size:y", rows_h, DEEPEN)
	tw.tween_property(_rows_slot, "modulate:a", 1.0, DEEPEN)
	tw.chain().tween_callback(func() -> void:
		for card: CardView in _cards:
			card.get_parent().queue_free()
		_cards.clear()
		_rows_slot.clip_contents = false)   # rows are back; let them slide again


# ---------------------------------------------------------------- leaving

func _on_continue() -> void:
	if not _untaken():
		finished.emit()
		return
	# Spoils left on the glass are gone for good, so leaving asks first. This is
	# the one place the screen refuses to be quiet about a mistake.
	var body: VBoxContainer = VBoxContainer.new()
	body.add_child(_heading(Locale.active.t("ui.reward.leaveConfirmTitle")))
	body.add_child(_hairline())
	body.add_child(_spacer(6.0))
	var sub: Label = _sub_label(Locale.active.t("ui.reward.leaveConfirmBody"))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(sub)
	body.add_child(_spacer(20.0))
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	body.add_child(actions)
	var leave: Button = _button(Locale.active.t("ui.reward.leaveConfirmYes"), GO_DANGER)
	leave.pressed.connect(func() -> void:
		_close_overlay()
		finished.emit())
	actions.add_child(leave)
	var stay: Button = _button(Locale.active.t("ui.reward.leaveConfirmNo"), GO_GHOST)
	stay.pressed.connect(_close_overlay)
	actions.add_child(stay)
	_show_overlay(body, _rack_num("panel", PANEL_W))


# ---------------------------------------------------------------- furniture

func _show_overlay(body: Control, width: float) -> void:
	_close_overlay()
	_overlay = ColorRect.new()
	_overlay.color = GlassStyle.scrim()  # #overlay
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(centre)
	body.custom_minimum_size = Vector2(width - PANEL_PAD * 2.0,
		body.custom_minimum_size.y)
	centre.add_child(_glass_panel(body))


func _close_overlay() -> void:
	if _overlay == null:
		return
	_overlay.queue_free()
	_overlay = null


## The glass placard: a lead rim outside, a gold hairline inside it, 28 of
## padding, and a wide soft drop. Two nested PanelContainers because that inner
## line is a second border — `inset 0 0 0 1px var(--gold-line)` in the
## benchmark — and a StyleBoxFlat only carries one.
static func _glass_panel(body: Control) -> PanelContainer:
	var outer_sb: StyleBoxFlat = StyleBoxFlat.new()
	outer_sb.bg_color = GLASS_FILL
	outer_sb.set_border_width_all(2)     # the benchmark's 1.5, on a whole pixel
	outer_sb.border_color = LEAD
	outer_sb.set_corner_radius_all(PANEL_RADIUS)
	outer_sb.set_content_margin_all(0.0)
	outer_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	outer_sb.shadow_size = 35            # CSS blur 70 reaches ~35px each side
	outer_sb.shadow_offset = Vector2(0.0, 24.0)
	var outer: PanelContainer = PanelContainer.new()
	outer.add_theme_stylebox_override("panel", outer_sb)

	# `inset 0 10px 20px -12px rgba(255,255,255,.14)` — light caught along the
	# top of the pane, the thing that says this is a sheet of glass lit from
	# above rather than a filled rectangle. Dropped on the first port because a
	# StyleBoxFlat has no inner shadow; it is a gradient, so it can just be one.
	# Added before the content so it sits over the fill and under the text, and
	# it fades out by 16% of the height, which is where a 20px blur lands on a
	# panel this tall.
	var sheen: TextureRect = TextureRect.new()
	sheen.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(1.0, 1.0, 1.0, 0.10), Color(1.0, 1.0, 1.0, 0.0)]),
		PackedFloat32Array([0.0, 0.16]), false, Vector2(0.5, 0.0), Vector2(0.5, 1.0))
	sheen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sheen.stretch_mode = TextureRect.STRETCH_SCALE
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(sheen)

	var inner_sb: StyleBoxFlat = StyleBoxFlat.new()
	inner_sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	inner_sb.set_border_width_all(1)
	inner_sb.border_color = Color(GOLD, 0.55)
	inner_sb.set_corner_radius_all(PANEL_RADIUS - 2)
	inner_sb.set_content_margin_all(PANEL_PAD - 2.0)
	var inner: PanelContainer = PanelContainer.new()
	inner.add_theme_stylebox_override("panel", inner_sb)
	outer.add_child(inner)
	inner.add_child(body)
	outer.set_meta("inner_style", inner_sb)
	return outer


func _title_text() -> String:
	match encounter_kind:
		"elite": return Locale.active.t("ui.reward.eliteSlain")
		"boss": return Locale.active.t("ui.reward.bossVanquished")
		_: return Locale.active.t("ui.reward.victory")


static func _heading(text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _font(GlassStyle.CINZEL_700, 3))  # .12em
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", PARCHMENT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The 84x2 gold bar under every title, transparent at both ends. `.ov-title`
## carries it as an ::after, and it is the one piece of trim that says which
## line of a panel is its heading.
static func _hairline() -> Control:
	var holder: CenterContainer = CenterContainer.new()
	holder.custom_minimum_size = Vector2(0.0, HAIRLINE.y + 12.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar: TextureRect = TextureRect.new()
	bar.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(GOLD, 0.0), GOLD, Color(GOLD, 0.0)]),
		PackedFloat32Array([0.0, 0.5, 1.0]), false,
		Vector2(0.0, 0.5), Vector2(1.0, 0.5))
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.custom_minimum_size = HAIRLINE
	bar.pivot_offset = HAIRLINE * 0.5     # it draws outward from the middle
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bar)
	holder.set_meta("bar", bar)
	return holder


static func _ornament_label() -> Label:
	var l: Label = Label.new()
	l.text = "✦ ✦ ✦"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _font(GlassStyle.ALEGREYA_400, 5))  # .4em
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", GOLD_DIM)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _sub_label(text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _font(GlassStyle.ALEGREYA_400, 0))
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", TEXT_DIM)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _spacer(h: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func _row_box(rim: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 1.0, 1.0, 0.043)
	sb.set_border_width_all(1)
	sb.border_color = rim
	sb.set_corner_radius_all(ROW_RADIUS)
	sb.set_content_margin_all(0.0)
	return sb


enum { GO_PRIMARY, GO_GHOST, GO_DANGER }


## `.btn` in its three dresses. The benchmark stacks a lead rim and an inset
## gold hairline on every one of them; a Button cannot nest a second panel the
## way the placard does, so the gold line is the rim it keeps — that is the one
## you see — and the primary's vertical gold ramp is carried as its midpoint
## over a deeper bottom edge.
static func _button(text: String, kind: int) -> Button:
	var ghost: bool = kind == GO_GHOST
	var b: Button = Button.new()
	b.text = text
	var h: float = 36.0 if ghost else BTN_H
	b.custom_minimum_size = Vector2(0.0, h)
	var px: int = 15 if ghost else 17
	var pad_x: float = 22.0 if ghost else 34.0
	b.add_theme_font_override("font", _font(GlassStyle.CINZEL_700, 1))  # .06em
	b.add_theme_font_size_override("font_size", px)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.set_corner_radius_all(BTN_RADIUS)
		sb.content_margin_left = pad_x
		sb.content_margin_right = pad_x
		sb.content_margin_top = 0.0
		sb.content_margin_bottom = 0.0
		sb.set_border_width_all(1)
		if kind == GO_PRIMARY:
			var fill: Color = GOLD.lerp(GOLD_DEEP, 0.5)
			sb.bg_color = fill.lightened(0.10) if state == "hover" else fill
			sb.border_color = GOLD_DEEP
			sb.border_width_bottom = 2       # the ramp's dark floor
		else:
			sb.bg_color = Color(0.055, 0.071, 0.133, 0.60)
			sb.border_color = GOLD if state == "hover" else LEAD
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
		sb.shadow_size = 7
		sb.shadow_offset = Vector2(0.0, 4.0)
		b.add_theme_stylebox_override(state, sb)
	var face: Color = BTN_INK if kind == GO_PRIMARY \
		else (DANGER if kind == GO_DANGER else PARCHMENT)
	b.add_theme_color_override("font_color", face)
	b.add_theme_color_override("font_hover_color", face)
	b.add_theme_color_override("font_pressed_color", face)
	return b


static func _font(path: String, tracking: int) -> Font:
	var key: String = path + "#" + str(tracking)
	if _fonts.has(key):
		var hit: Font = _fonts[key]
		return hit
	var fv: FontVariation = FontVariation.new()
	fv.base_font = GlassStyle.face(path)
	if tracking != 0:
		fv.spacing_glyph = tracking
	_fonts[key] = fv
	return fv
