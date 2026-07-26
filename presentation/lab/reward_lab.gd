class_name RewardLab
extends Control
## A VIEWER for the reward screen, over fixed spoils, with no fight behind it.
##
## Not a screenshot rig. Most of what this screen does cannot survive a still —
## the panel deepening into the offering, the lamp walking the cards, a claimed
## object leaving its seat, and above all the card's own material, which is
## angle-driven and therefore shows nothing at all until you move the cursor
## over it. So the lab keeps a control strip and rebuilds the screen live: every
## case, both builds, reset, all without relaunching.
##
##   godot --path . -- --reward                  # the viewer
##   godot --path . -- --reward --case=tiers     # ...opened on a case
##   godot --path . -- --reward --concept=window # ...opened on a concept
##
## ONE VIEWER. There were briefly two — this and a separate RewardDesigns with
## its own cases, its own strip and its own keys — which made the six candidates
## uncomparable in the only way that matters: side by side, same spoils, same
## keystroke apart. All six now build here off one CASES table, so switching
## concept changes exactly one thing.
##
## COMPARING CONCEPTS. The benchmark is ported and settled; what is being chosen
## between now are whole answers to "what IS a reward screen", not tunings of
## one. They differ in what a reward is made of, so the only honest way to judge
## is to flip between them over the SAME spoils without relaunching — Q/W/E do
## that, and the case stays put across the switch.
##
## In the window:
##   1..5   case: gold · cards · full · elite · tiers
##   Q W E R T Y   concept: rows · lancet · rose · embers · window · reliquary
##   B      build: beyond ⇄ benchmark (rows only — the ported floor)
##   O      open the offering (rows only; the others have no second door)
##   0      reset the screen
##   and everything else is the screen itself — hover a row, claim it, hover a
##   card to bring the lamp down onto it, pick or skip.
##
## The same flags still drive a scripted shot, and the strip hides itself
## whenever --shot= is present so it never lands in the frame:
##   --case=    gold | cards | full | elite | tiers   (default full)
##   --concept= rows|lancet|rose|embers|window|reliquary   (default embers)
##   --bench    the benchmark ported straight — the floor the rest is diffed
##              against. Without it: one panel that deepens and seated spoils.
##   --pick     open the offering straight away — it is behind a row press,
##              which a scripted shot cannot make
##   --take=    gold,potion,relic,card — settle those rows first
##   --leave    press Continue — with spoils unclaimed that raises the confirm
##   --strip    keep the control strip in a --shot, for documenting the viewer
##
## The samples are HAND-WRITTEN, not rolled. gen_combat_rewards is seeded off
## the run and the slice's relic pools are all empty, so a real roll can never
## produce the relic case at all — and a shot has to be reproducible anyway.
## They keep the exact shape gen_combat_rewards returns:
##   {"gold": int, "cards": Array[String], "potion": null|String, "relic": null|String}
##
## The backdrop is the lab's, not the screen's. The benchmark's reward panel
## stands over the live scene with the HUD still lit and scrims nothing, so
## RewardScreen paints no ground of its own — this stands in for the map behind
## it. The HUD strip along the top of the benchmark's shot is not drawn: there
## is no HUD in this project yet, and faking one would flatter a layout that has
## to survive without it.
##
## Claims print rather than apply. Nothing here owns a run, so pressing a row
## proves the signal fires with the right id — the strip's log keeps the last
## few, and stdout carries them out of a headless run.

const CASES: Dictionary = {
	# Gold and nothing else: what a dry pool leaves behind, and the case that
	# shows how the panel reads when only two rows are left.
	"gold": {
		"kind": "normal",
		"reward": {"gold": 17, "cards": [], "potion": null, "relic": null},
	},
	# The ordinary win: the purse and three commons behind the card row.
	"cards": {
		"kind": "normal",
		"reward": {"gold": 14, "cards": ["heavyBlow", "cleave", "deflect"],
			"potion": null, "relic": null},
	},
	"full": {
		"kind": "normal",
		"reward": {"gold": 22, "cards": ["flurry", "surge", "fortify"],
			"potion": "healing", "relic": "emberHeart"},
	},
	# Elite money (28-38 in act 1) and the uncommon end of the pool.
	"elite": {
		"kind": "elite",
		"reward": {"gold": 33, "cards": ["executioner", "momentum", "empower"],
			"potion": "fire", "relic": "emberHeart"},
	},
	# THE MATERIAL TEST, and not a reward a run can deal — `strike` is a starter
	# and never lands in a pool. It is here because CardSurface.BY_RARITY makes
	# the tier a MATERIAL (starter=plain, common=card, uncommon=opal) and every
	# other case above happens to offer three cards of the SAME tier, which
	# cannot answer the only question the offering really asks: can you tell a
	# common from an uncommon without a label? Three tiers, one lamp, one look.
	# Rare (nebula) has no card in the slice — judge that one on the card lab's
	# surfaces sheet, which varies material and nothing else.
	"tiers": {
		"kind": "normal",
		"reward": {"gold": 20, "cards": ["strike", "heavyBlow", "flurry"],
			"potion": null, "relic": null},
	},
}

const ORDER: Array[String] = ["gold", "cards", "full", "elite", "tiers"]
## The concepts on offer, in the order they were built. "rows" is the settled
## benchmark port; everything after it is an answer to the same brief that does
## not begin from a list.
const CONCEPTS: Array[String] = ["rows", "lancet", "rose", "embers", "window", "reliquary"]
## Six concepts need six keys, so reset moves off R and onto 0. Cases keep
## 1..5 — the row of number keys is the inner choice and the row of letters
## under it is the outer one, which is the same shape as the strip.
const CONCEPT_KEYS: Array[int] = [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y]
const BAR_H: float = 78.0
## What the footer log takes off the bottom, with a little air over it.
const LOG_H: float = 30.0
const LOG_LINES: int = 3

var content: ContentDB

var _case: String = "full"
## Embers is the chosen concept, so it is what the viewer opens on. The rest are
## on their keys until they are archived.
var _concept: String = "embers"
var _bench: bool = false
var _pick: bool = false
var _leave: bool = false
var _take: PackedStringArray = PackedStringArray()
## Typed as Control, not RewardScreen: the concepts share a shape (same ctor,
## same two signals, same mark_taken / request_leave) but no base class, and
## inventing one to hold three prototypes would outlive two of them.
var _screen: Control = null
var _bar: PanelContainer = null
var _build_btn: Button = null
var _log: Label = null
var _events: Array[String] = []
var _shot: bool = false            # a capture is happening: run the clock out
var _headless_shot: bool = false   # ...and it carries the screen alone
var _force_bar: bool = false


func _init(content_ref: ContentDB) -> void:
	content = content_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	# Read here, not in main: the four labs share that arg loop and this one's
	# flags are nobody else's business (main.gd's own note says so). --shot is
	# main's, but the strip has to know about it — a control bar in a captured
	# frame is noise in every diff.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			_case = arg.trim_prefix("--case=")
		elif arg.begins_with("--concept="):
			_concept = arg.trim_prefix("--concept=")
		elif arg == "--bench":
			_bench = true
		elif arg == "--pick":
			_pick = true
		elif arg == "--leave":
			_leave = true
		elif arg.begins_with("--take="):
			_take = arg.trim_prefix("--take=").split(",", false)
		elif arg.begins_with("--shot="):
			_shot = true
		elif arg == "--strip":
			_force_bar = true
	# Dropping the chrome and running the clock out are two different things, and
	# folding them into one flag meant a --strip shot — the one that documents the
	# VIEWER — was the only one caught mid-entrance, which documents nothing.
	_headless_shot = _shot and not _force_bar
	if _shot:
		# main captures 30 frames in, which lands mid-entrance on every concept
		# — and a still of an entrance is a still of nothing. Running the clock
		# fast makes the shot the SETTLED screen, which is the thing a layout is
		# judged on. The entrance is judged live, in the viewer, where it plays.
		Engine.time_scale = 9.0
	if not CASES.has(_case):
		push_warning("reward lab: no such case: %s" % _case)
		print("reward lab: no such case: %s — have %s" % [_case, ", ".join(ORDER)])
		_case = "full"
	if not CONCEPTS.has(_concept):
		push_warning("reward lab: no such concept: %s" % _concept)
		print("reward lab: no such concept: %s — have %s"
			% [_concept, ", ".join(CONCEPTS)])
		_concept = "embers"

	_build_backdrop()
	_build_bar()
	_log = _footer("")
	add_child(_log)
	_note("ready")


func _ready() -> void:
	_rebuild()
	# The scripted openings, applied to the first screen only. After that the
	# strip owns the state and re-applying them on every rebuild would make a
	# case switch un-resettable.
	for slot: String in _take:
		_screen.mark_taken(StringName(slot))
		_note("marked taken: " + slot)
	if _pick:
		_offering()
	if _leave:
		_screen.request_leave()


## Only the row concept keeps the offering behind a second door; the others put
## it on the screen, so there is nothing to open. Asked anyway, say so rather
## than failing silently — the flag is how a scripted shot reaches that state.
func _offering() -> void:
	if _screen.has_method("open_card_choice"):
		_screen.call("open_card_choice")
	else:
		_note("%s has no second door — the offering is already on screen" % _concept)


# ---------------------------------------------------------------- the screen

## Throw the screen away and build it again. Cheaper than any reset path through
## the screen itself, and it is the honest one: a fresh RewardScreen is exactly
## what main will hand the player after the next fight.
func _rebuild() -> void:
	if _screen != null:
		_screen.queue_free()
	var sample: Dictionary = CASES[_case]
	var reward: Dictionary = sample["reward"]
	var kind: String = str(sample["kind"])
	match _concept:
		"lancet": _screen = RewardLancet.new(reward, content, kind, _enemy())
		"rose": _screen = RewardRose.new(reward, content, kind)
		"window": _screen = RewardWindow.new(reward, content, kind)
		"embers": _screen = RewardEmbers.new(reward, content, kind, _hue())
		"reliquary": _screen = RewardReliquary.new(reward, content, kind)
		_: _screen = RewardScreen.new(reward, content, kind, _bench)
	# The strip is the LAB'S chrome and the screen is the thing being judged, so
	# the screen is told what the chrome is eating rather than being parked under
	# it. The spoils sit 66px off the top of the canvas and the strip is 78 tall:
	# the one row of the layout that arrives first was the one row you could not
	# see. In a --shot there is no strip and no log, and both insets stay zero.
	var embers: RewardEmbers = _screen as RewardEmbers
	if embers != null:
		embers.safe_top = 0.0 if _bar == null else BAR_H
		embers.safe_bottom = 0.0 if _bar == null else LOG_H
	_screen.connect(&"claimed", _on_claimed)
	_screen.connect(&"finished", _on_finished)
	add_child(_screen)
	# Siblings draw and pick front-to-back in child order, so the strip and the
	# log have to stay last or the screen's full-rect scrim swallows both.
	if _bar != null:
		move_child(_bar, -1)
	move_child(_log, -1)
	_note("%s · %s%s" % [_concept, _case,
		"" if _concept != "rows" else " · " + _build()])


## The embers concept is painted in the dead enemy's hue, and a reward
## Dictionary does not carry one — so the lab supplies what main will have to:
## the `art.hue` of what just died. Elites run cold here purely so the two
## cases look different in a still.
func _hue() -> float:
	return 208.0 if _case == "elite" else 22.0


## The lancet memorialises what you killed, and a reward Dictionary carries no
## enemy either — same shape of gap as the hue above, same stand-in. Whoever
## wires a memorial concept into main passes the id of what just died.
func _enemy() -> String:
	return "gravewarden" if _case == "elite" else "duskfang"


func _set_case(name: String) -> void:
	_case = name
	_rebuild()


## Concept switches keep the case, which is the whole point of the switch: the
## comparison is only worth anything over identical spoils.
func _set_concept(name: String) -> void:
	_concept = name
	if _build_btn != null:
		_build_btn.disabled = name != "rows"
	_rebuild()


func _toggle_build() -> void:
	_bench = not _bench
	_build_btn.text = "build: %s" % _build()
	_rebuild()


func _build() -> String:
	return "benchmark" if _bench else "beyond"


# ---------------------------------------------------------------- the strip

func _build_bar() -> void:
	if _headless_shot:
		return          # a captured frame carries the screen and nothing else
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.024, 0.031, 0.059, 0.88)
	sb.border_width_bottom = 1
	sb.border_color = Color(GlassStyle.GLASS, 0.20)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 7.0
	sb.content_margin_bottom = 7.0
	_bar = PanelContainer.new()
	_bar.add_theme_stylebox_override("panel", sb)
	_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar.offset_bottom = BAR_H
	add_child(_bar)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	_bar.add_child(stack)

	# Concepts on their own line and first, because it is the outer choice: the
	# case below it means the same thing whichever concept is showing.
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(top)
	var concepts: ButtonGroup = ButtonGroup.new()
	for i: int in range(CONCEPTS.size()):
		var name: String = CONCEPTS[i]
		var key: String = OS.get_keycode_string(CONCEPT_KEYS[i])
		var b: Button = _bar_button("%s %s" % [key, name], GlassStyle.EMBER, true)
		b.toggle_mode = true
		b.button_group = concepts
		b.button_pressed = name == _concept
		b.pressed.connect(_set_concept.bind(name))
		top.add_child(b)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(row)

	# One radio set, so the strip always says which case you are looking at
	# rather than leaving you to remember.
	var group: ButtonGroup = ButtonGroup.new()
	var n: int = 0
	for name: String in ORDER:
		var b: Button = _bar_button("%d %s" % [n + 1, name], GlassStyle.GLASS, true)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = name == _case
		b.pressed.connect(_set_case.bind(name))
		row.add_child(b)
		n += 1
	row.add_child(_gap(18.0))
	_build_btn = _bar_button("build: %s" % _build(), GlassStyle.EMBER)
	_build_btn.pressed.connect(_toggle_build)
	_build_btn.disabled = _concept != "rows"
	row.add_child(_build_btn)
	row.add_child(_gap(18.0))
	var offering: Button = _bar_button("offering", GlassStyle.GLASS)
	offering.pressed.connect(_offering)
	row.add_child(offering)
	var reset: Button = _bar_button("reset", GlassStyle.GLASS)
	reset.pressed.connect(_rebuild)
	row.add_child(reset)


static func _bar_button(text: String, tint: Color, radio: bool = false) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE   # keys stay with the lab, not a button
	b.custom_minimum_size = Vector2(0.0, 30.0)
	b.add_theme_font_size_override("font_size", 12)
	GlassStyle.style_button(b, tint)
	if radio:
		# A toggled Button draws with its `pressed` box, and GlassStyle makes
		# that the DIMMEST of the four — correct for the moment a finger is
		# down, backwards for "this is the one you are looking at". So the
		# selected case gets its own box, or the strip cannot tell you where
		# you are.
		var on: StyleBoxFlat = StyleBoxFlat.new()
		on.bg_color = Color(GlassStyle.EMBER, 0.30)
		on.set_border_width_all(1)
		on.border_color = Color(GlassStyle.EMBER, 0.85)
		on.set_corner_radius_all(12)
		on.set_content_margin_all(10)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
	return b


static func _gap(w: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(w, 0.0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Keys for everything on the strip. Unhandled, so the screen's own buttons and
## the cards keep first claim on input.
func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo or _headless_shot:
		return
	var idx: int = k.keycode - KEY_1
	var concept: int = CONCEPT_KEYS.find(k.keycode)
	if idx >= 0 and idx < ORDER.size():
		_press(1, ORDER[idx], _set_case)
	elif concept >= 0 and concept < CONCEPTS.size():
		_press(0, CONCEPTS[concept], _set_concept)
	elif k.keycode == KEY_B and _concept == "rows":
		_toggle_build()
	elif k.keycode == KEY_O:
		_offering()
	elif k.keycode == KEY_0:
		_rebuild()
	else:
		return
	accept_event()


## Drive the strip's own button rather than jumping straight to the setter, or
## the radio keeps showing whichever one the mouse last chose. `line` is the row
## within the strip: 0 concepts, 1 cases.
func _press(line: int, name: String, setter: Callable) -> void:
	if _bar == null:
		setter.call(name)
		return
	for node: Node in _bar.get_child(0).get_child(line).get_children():
		var b: Button = node as Button
		if b != null and b.text.ends_with(" " + name):
			b.button_pressed = true
			setter.call(name)
			return


# ---------------------------------------------------------------- chrome

func _build_backdrop() -> void:
	var bg: TextureRect = TextureRect.new()
	bg.texture = GlassStyle.grad_tex(
		PackedColorArray([GlassStyle.NIGHT_TOP, GlassStyle.NIGHT_MID, GlassStyle.NIGHT_BOT]),
		PackedFloat32Array([0.0, 0.55, 1.0]), false, Vector2(0.5, 0.0), Vector2(0.5, 1.0))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var glow: TextureRect = TextureRect.new()
	glow.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(GlassStyle.EMBER, 0.12), Color(GlassStyle.EMBER, 0.0)]),
		PackedFloat32Array([0.0, 1.0]), true, Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	glow.anchor_left = 0.05
	glow.anchor_right = 0.95
	glow.anchor_top = 0.30
	glow.anchor_bottom = 1.0
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)


func _on_claimed(what: StringName, id: String) -> void:
	_note("claimed: %s%s" % [what, "" if id == "" else " " + id])


func _on_finished() -> void:
	_note("finished — continue pressed")


## The log keeps the last few rather than one line: a claim is a sequence
## (take gold, open the offering, skip it, leave), and one line loses the shape
## of what you just did.
func _note(line: String) -> void:
	print("reward lab: " + line)
	_events.append(line)
	while _events.size() > LOG_LINES:
		_events.pop_front()
	if _log != null:
		_log.text = " · ".join(_events)


static func _footer(text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_top = -26.0
	l.offset_bottom = -8.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
