class_name CombatScreen
extends Control
## The combat screen (M5a skeleton). Owns the views and the event sequencer;
## game truth lives in GlassvowGame — this layer only plays events back.
## Composition-root injection: main instantiates with the game (SKILL §2).
##
## Playback contract: the startCombat batch is hard-synced (views don't exist
## until after apply returns); every later batch replays through the
## sequencer, then _sync_all() corrects any drift once the pump idles.

signal combat_over(result: String)
signal result_continue

## Where the ground is, in stage px up from the bottom. This project's viewport
## is 1180x820, which `src/stage.js:23` names `pad-landscape` — one of the
## benchmark's five AUTHORED shapes, not an approximation of one — so
## `BF.base.groundY` transfers verbatim rather than being fitted. The
## battlefield ends on this line and every actor stands on it: an actor drawn at
## bottom 0 has its feet here. Foes and the hero are the same animal, which is
## the contract `enemy_view.gd` was already built against.
const GROUND_Y: float = 232.0
## `BF.base.ledgeLip` — how far the lit lip rides above the ground line.
const LEDGE_LIP: float = 14.0
## The stage the plates were measured in. Offsets resolve against the live
## viewport, so a taller window moves the ground rather than stretching the art.
const STAGE: Vector2 = Vector2(1180.0, 820.0)
const STAGE_ART: String = "res://assets/art/stage/act1-%s.png"

## `BF.base.hero.x` merged with `shapes['pad-landscape']` — where the hero's
## centre stands. Its BOX is not from here: char-meta types `duskblade` as tier
## `hero` (`tierSizes.hero` = 285) and EnemyView sizes itself off that, the same
## way it sizes a foe.
const HERO_X: float = 200.0
## The benchmark reads the hero's art off the run's aspect
## (`runCatalogues().aspects[run.aspect].id`). Our slice content carries no
## aspects section, and this port has called the player The Duskblade since M5.
## ponytail: read the aspect the day the exporter carries one.
const HERO_ART: StringName = &"duskblade"
const HERO_HUE: float = 225.0  # HERO_LOOKS[0].hue in art.js

## `UIC.base.hand.bottom` — the hand box hangs this far past the stage's bottom
## edge. The fan is clamped against the STAGE line, so HandView is told the
## overhang rather than left to work it out from where it happens to sit.
const HAND_OVERHANG: float = 12.0

## The damage sources that do not shove the body (drain.js:626). A blow throws
## you; poison does not, and neither does your own burn.
const INDIRECT_SOURCES: Array[String] = ["poison", "burn", "self", "thorns"]

## `tr('ui.combat.*')` — the copy the drain announces with, from `i18n/en/ui.js`.
## Held here rather than typed at each call site so the wording is one edit when
## this port grows a locale table of its own.
const SAY_YOUR_TURN: String = "YOUR TURN"
const SAY_ENEMY_TURN: String = "ENEMY TURN"
const SAY_SHATTER: String = "SHATTER"
const SAY_STAGGERED: String = "STAGGERED"
const SAY_GLASS_HOLDS: String = "THE GLASS HOLDS"
const SAY_GUARD_SHATTERED: String = "GUARD SHATTERED"
const SAY_RESHUFFLE: String = "Reshuffle"
const SAY_PERFECT: String = "PERFECT"

## The palette the drain names inline. Every one of these is a literal in
## `drain.js`; they are the effect layer's own colours, not the theme's.
const GLASS_BLUE: Color = Color(0.8745098, 0.91764706, 1.0)     # #dfeaff
const WARD_BLUE: Color = Color(0.62352943, 0.83137256, 1.0)     # #9fd4ff
const POISON_TAN: Color = Color(0.827451, 0.6313726, 0.3529412) # #d3a15a
const WARM_GOLD: Color = Color(1.0, 0.84705883, 0.627451)       # #ffd8a0
const EMBER_ORANGE: Color = Color(1.0, 0.7019608, 0.3529412)    # #ffb35a
const SPARK_WHITE: Color = Color(1.0, 0.9529412, 0.8392157)     # #fff3d6
const SOUL_VIOLET: Color = Color(0.7882353, 0.6901961, 1.0)     # #c9b0ff
const REVIVE_LILAC: Color = Color(0.9098039, 0.8627451, 1.0)    # #e8dcff
const POWER_LILAC: Color = Color(0.7882353, 0.65882355, 1.0)    # #c9a8ff
const HOLLOW_GREY: Color = Color(0.5686275, 0.627451, 0.6862745) # #91a0af
const HEAL_GREEN: Color = Color(0.56078434, 0.9098039, 0.627451) # #8fe8a0
const BUFF_BLUE: Color = Color(0.62352943, 0.78431374, 1.0)     # #9fc8ff
const WARD_ICON: Texture2D = preload("res://assets/art/ui/ward.png")

## `big` (drain.js:540) — the damage at which a blow earns its own ceremony.
const BIG_HIT: int = 16
## `Math.min(1, ev.amount / 24)` — what counts as a full-power blow.
const POWER_SCALE: float = 24.0

class Plate:
	extends Control
	var tex: Texture2D
	var where: Vector2 = Vector2(0.5, 0.5)

	func _draw() -> void:
		if tex == null:
			return
		var t: Vector2 = tex.get_size()
		if t.x <= 0.0 or t.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
			return
		# cover: the smallest scale that still fills the box, so the window we
		# read out of the source is the box divided by it.
		var s: float = maxf(size.x / t.x, size.y / t.y)
		var window: Vector2 = Vector2(size.x / s, size.y / s)
		var origin: Vector2 = (t - window) * where
		draw_texture_rect_region(tex, Rect2(Vector2.ZERO, size), Rect2(origin, window))


var game: GlassvowGame
var seq: EventSequencer = EventSequencer.new()

var _rules: CombatRules
var _enemy_views: Array[EnemyView] = []
var _hand: HandView
var _hud: HudBar
## The targeting arc, drawn only while a card that targets an enemy is aimed.
var _aim: AimArc
## The region above the ground line, and the only parent an actor ever has. Its
## bottom IS the ground line, so an actor placed at bottom 0 stands on it.
var _battlefield: Control
## The player, as an actor rather than a panel. `char-meta` types `duskblade` as
## tier `hero`, which is how EnemyView knows to leave off the intent chip, the
## name line and the facet gauge without being told.
var _hero: EnemyView
var _kindle_toggle: Button
var _encounter_text: String = ""
var _overlay: ColorRect
var _overlay_title: Label
var _overlay_body: Label
var _overlay_button: Button
var _inspect: PanelContainer
var _inspect_label: Label
var _over_emitted: bool = false
## `choreoDone` — whether the card currently resolving has already been swung
## for. Starts spent, so nothing lunges before a card is ever played.
var _hero_swung: bool = true
## Everything the shake moves: `#shake` wraps the screen, the lantern and the
## chrome, but NOT the effect canvas — which is why sparks hang still while the
## world jolts under them.
var _shake_host: Control
var _vfx: VfxLayer
var _floaters: Floaters
## `vfxSource.archetype` — which blow language the action now resolving speaks.
## Set by `play` from the card's own `vfx` field and by `enemyAct` from the
## body's kind, then read by every hit until the next action replaces it.
var _archetype: String = "slash"
## `hitSeq` — how many numbers this action has already thrown, so a multi-hit
## card fans its damage across three columns instead of stacking it in one.
var _hit_seq: int = 0
## `emberFrom` — where the last fire spilled, so the embers it feeds the lantern
## start at the body that gave them rather than at the hero.
var _ember_from: Vector2 = Vector2.ZERO
var _has_ember_from: bool = false
## `targetIdx` — what the card about to resolve was aimed at, so `play` can
## throw it there. Null for an untargeted card and for anything the engine
## started on its own.
var _play_target: Variant = null


## Fully constructed at new() — no tree dependency, so headless tests can
## drive it before (or without) entering the tree.
func _init(game_ref: GlassvowGame) -> void:
	game = game_ref
	_rules = game.rules
	seq.handler = _handle_event
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	_build_ui()
	seq.busy_changed.connect(_on_busy_changed)


# ---------------------------------------------------------------- build

func _build_ui() -> void:
	# `#shake` — the world wrapper the screen shake translates. Everything the
	# fight happens in goes inside it; the effect canvas and the floaters do not,
	# because `#vfx` and `#floaties` are its SIBLINGS in the benchmark and that
	# is why a spark stays where it was thrown while the stage jolts under it.
	_shake_host = Control.new()
	_shake_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shake_host.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_shake_host)

	_build_stage()

	# `.battlefield` — inset 0 with `bottom: var(--ground-y)`. Actors are its only
	# children and are placed by their FEET, so the container's bottom edge is
	# the ground line and nothing has to convert coordinates to say so.
	_battlefield = Control.new()
	_battlefield.set_anchors_preset(Control.PRESET_FULL_RECT)
	_battlefield.offset_bottom = -GROUND_Y
	_battlefield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shake_host.add_child(_battlefield)

	# The whole chrome layer, in one widget, measured against the same
	# 1180x820 the stage above is. `plate = false` because the ward chip and HP
	# rail belong to the actor they describe — see docs/hud-handoff.md §2.
	_hud = HudBar.new(true, true, false)
	_hud.end_turn_pressed.connect(_on_end_turn_pressed)
	_hud.lantern_pressed.connect(_on_art_pressed)
	_shake_host.add_child(_hud)

	_hand = HandView.new()
	# `.hand-zone` — centred on the stage, 260 tall, hanging 12px past the
	# bottom edge. The WIDTH is not a constant: the benchmark sizes the box to
	# hug the fan, so HandView re-edges itself on every relayout and this is
	# only the resting five-card figure it starts at.
	_hand.anchor_left = 0.5
	_hand.anchor_right = 0.5
	_hand.anchor_top = 1.0
	_hand.anchor_bottom = 1.0
	_hand.offset_left = -HandView.zone_width(5, STAGE.x) * 0.5
	_hand.offset_right = HandView.zone_width(5, STAGE.x) * 0.5
	_hand.offset_top = -248.0
	_hand.offset_bottom = HAND_OVERHANG
	_hand.stage_overhang = HAND_OVERHANG
	_hand.card_tapped.connect(_on_card_tapped)
	_hand.card_drag_moved.connect(_on_card_drag_moved)
	_hand.card_drag_released.connect(_on_card_drag_released)
	_shake_host.add_child(_hand)

	# Above the hand: the arc launches 80px over the card it comes from, so it
	# clears the fan on its own, but the reticle must never end up behind a
	# neighbouring card when aiming across the hand.
	_aim = AimArc.new()
	add_child(_aim)

	# `#vfx` then `#floaties`, both siblings of `#shake` and both above `#aim`:
	# a damage numeral is never hidden by the body it came off, and a spark is
	# never hidden by the HUD.
	_vfx = VfxLayer.new(_shake_host)
	add_child(_vfx)
	_floaters = Floaters.new()
	add_child(_floaters)

	_inspect = PanelContainer.new()
	_inspect.set_anchors_preset(Control.PRESET_CENTER)
	_inspect.visible = false
	_inspect.add_theme_stylebox_override("panel", GlassStyle.pane(GlassStyle.GLASS, 0.96))
	_inspect.gui_input.connect(_on_inspect_input)
	add_child(_inspect)
	_inspect_label = _label("")
	_inspect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspect_label.custom_minimum_size = Vector2(300, 0)
	_inspect.add_child(_inspect_label)

	# Kindle is this port's own control: the benchmark's chrome has no seat for
	# it, and HudBar reserves none. Parked under the strip rather than invented
	# into the furniture, because where it belongs is a design question nobody
	# has answered (docs/assembly-integration-plan.md D4).
	_kindle_toggle = Button.new()
	_kindle_toggle.text = "Kindle: off"
	_kindle_toggle.toggle_mode = true
	_kindle_toggle.anchor_top = 0.0
	_kindle_toggle.anchor_bottom = 0.0
	_kindle_toggle.offset_left = 16
	_kindle_toggle.offset_right = 132
	_kindle_toggle.offset_top = 66
	_kindle_toggle.offset_bottom = 98
	GlassStyle.style_button(_kindle_toggle, GlassStyle.EMBER)
	_kindle_toggle.toggled.connect(_on_kindle_toggled)
	_shake_host.add_child(_kindle_toggle)

	_overlay = ColorRect.new()
	_overlay.color = Color(0.01, 0.015, 0.03, 0.8)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	var overlay_center: CenterContainer = CenterContainer.new()
	overlay_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(overlay_center)
	var overlay_pane: PanelContainer = PanelContainer.new()
	overlay_pane.add_theme_stylebox_override("panel", GlassStyle.pane(GlassStyle.GLASS, 0.95))
	overlay_center.add_child(overlay_pane)
	var overlay_box: VBoxContainer = VBoxContainer.new()
	overlay_box.add_theme_constant_override("separation", 16)
	overlay_box.custom_minimum_size = Vector2(360, 0)
	overlay_pane.add_child(overlay_box)
	_overlay_title = _label("")
	_overlay_title.add_theme_font_size_override("font_size", 34)
	_overlay_title.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0))
	overlay_box.add_child(_overlay_title)
	_overlay_body = _label("")
	_overlay_body.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	overlay_box.add_child(_overlay_body)
	_overlay_button = Button.new()
	_overlay_button.custom_minimum_size = Vector2(220, 48)
	GlassStyle.style_button(_overlay_button, GlassStyle.EMBER)
	_overlay_button.pressed.connect(func() -> void: result_continue.emit())
	overlay_box.add_child(_overlay_button)


# ---------------------------------------------------------------- the stage

## The painted ground the fight happens on: three plates, a glow band pooled at
## the ground line, the lit lip above it, depth mist, and two slow breaths.
## Ported from `combat.js:215-223` and the `.sl` / `.stage-*` rules; the plate
## geometry is `BF.base` merged with `shapes['pad-landscape']` at act 0.
##
## This replaces a procedural indigo gradient, an ember radial and a vignette —
## a look the M5d craft pass invented rather than ported. The art it needed had
## been sitting in `assets/art/stage/` unreferenced the whole time.
##
## Deferred on purpose, each cheap to add later and none of them load-bearing
## for the layout: the plates' idle parallax drift (`--amp`), `.stage-dim`'s
## live lamp tracking, and `.cast-shadow-layer` — EnemyView already projects its
## own shadow, so a shared layer only earns its place once shadows interact.
func _build_stage() -> void:
	# What is behind the plates. `body { background: #000 }` is the page, not the
	# stage: the act's plate art has a transparent sky and `#bg3d` is what shows
	# through it. Black there is the single biggest reason a still frame of this
	# fight read as flat next to the same frame on the benchmark.
	_shake_host.add_child(SkyField.new())

	# Draw order is the benchmark's paint order: the plates and the breath sit
	# at z 0, the mist at 2, the ledge band at 3.
	# h, bottom, dx, zoom, opacity, object-position — all six measured off the
	# running benchmark's own `.sl-*` elements at this shape and act, because
	# the resolved values are what the DOM ends up with, not what BF says.
	_plate("backdrop", 640.0, 280.0, 0.0, 1.0, 0.85, Vector2(0.5, 1.0))
	_plate("mid", 1000.0, 300.0, 100.0, 0.4, 0.95, Vector2(1.0, 1.0))
	_plate("ledge", 450.0, 0.0, 0.0, 1.0, 1.0, Vector2(1.0, 0.0), true)

	# NOT BUILT, and the benchmark's own stylesheet says why:
	#
	#   /* act-themed ground glow off — stage-ledge + stage-breath both tint
	#      --ledge (act1 = green) */
	#   .stage-ledge, .stage-breath { opacity: 0; animation: none; }
	#
	# The 120px ledge glow, its 1.5px lit lip and the two breathing blobs are all
	# defined and then switched OFF at the visual standard, because every one of
	# them tints `--ledge` and act 1 resolves that green. They were ported before
	# that line was read, and the green band across the floor that followed was
	# never a tuning problem — it was two layers that are not meant to exist.
	# Putting them back is a deliberate departure, not a fix.


## One painted plate. `h` and `y` are stage px, `y` being the plate's bottom
## above the stage bottom — except the ledge, which hangs off the ground line
## instead (`combat.js:384`).
##
## The box is `h` tall by at least the stage's width (`min-width: 100%`), scaled
## by `zoom`, and CENTRED BY ITS SCALED WIDTH on the stage's centre plus `dx`.
## That last part was got wrong first time from reading the CSS transform order,
## and then measured off the running build: the mid plate lands at x 394 with a
## 600-wide box, which is 690 minus half of 600, not half of 1500.
func _plate(art: String, h: float, y: float, dx: float, zoom: float,
		alpha: float, where: Vector2, is_ledge: bool = false) -> void:
	var path: String = STAGE_ART % art
	if not ResourceLoader.exists(path):
		# Named rather than silent: a missing plate is otherwise an invisible
		# hole in the ground with nothing in the log saying which one.
		push_warning("stage: missing plate %s" % path)
		return
	var tex: Texture2D = load(path)
	var aspect: float = float(tex.get_width()) / maxf(1.0, float(tex.get_height()))
	var base: Vector2 = Vector2(maxf(STAGE.x, h * aspect), h)  # `min-width: 100%`
	var box: Vector2 = base * zoom
	var bottom: float = maxf(0.0, GROUND_Y + LEDGE_LIP - h + y) if is_ledge else y
	var r: Plate = Plate.new()
	r.tex = tex
	r.where = where
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.modulate = Color(1.0, 1.0, 1.0, alpha)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.5
	r.anchor_right = 0.5
	r.anchor_top = 1.0
	r.anchor_bottom = 1.0
	r.offset_left = -box.x * 0.5 + dx
	r.offset_right = r.offset_left + box.x
	r.offset_top = -(bottom + base.y * zoom)
	r.offset_bottom = -bottom
	_shake_host.add_child(r)


func start_encounter(enemy_ids: Array, kind: String, encounter_text: String) -> void:
	_over_emitted = false
	_encounter_text = encounter_text
	# Headless playback takes no ceremony with it: a test driving the sequencer
	# must never wait on a tween that will not tick.
	_floaters.instant = seq.instant
	_floaters.clear_all()
	# `V.setWeather(theme?.weather, { boss: kind === 'boss' })` — the air a fight
	# happens in, thicker for a boss.
	_vfx.set_weather(not seq.instant, kind == "boss")
	# Live play rolls the elite affix inside start_combat (traces passed it
	# explicitly only to skip the rng draw).
	game.apply({"t": "startCombat", "enemies": enemy_ids, "kind": kind})
	for view: EnemyView in _enemy_views:
		view.queue_free()
	_enemy_views.clear()
	# The hero outlives the encounter — it is the same body between fights, and
	# rebuilding it would throw away a 3D stage for no reason.
	if _hero == null:
		_hero = EnemyView.new(-1, "", HERO_HUE, HERO_ART)
		_battlefield.add_child(_hero)
	_stand(_hero, HERO_X, 0.0)
	var slots: Array[Vector2] = _slots(game.cb.enemies.size())
	# `bfEnemyZOrder`: lower on screen draws in front, so a foe standing further
	# up the ledge sits behind the one nearer the lip. Expressed as the order the
	# actors are ADDED in, because child order is the only ordering that is
	# relative to a sibling. `z_index` is measured against the whole canvas: a
	# foe given z −42 does not go behind its neighbour, it goes behind the STAGE.
	# That is what made two of three foes disappear entirely.
	var order: Array[int] = []
	for i: int in range(game.cb.enemies.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var la: float = slots[a].y if a < slots.size() else 0.0
		var lb: float = slots[b].y if b < slots.size() else 0.0
		return la > lb)
	_enemy_views.resize(game.cb.enemies.size())
	for idx: int in order:
		var e: EnemyCombatant = game.cb.enemies[idx]
		var display: String = e.name
		if game.cb.affix != &"":
			var affix_def: Dictionary = game.content.affixes.get(String(game.cb.affix), {})
			display = "%s %s" % [str(affix_def.get("name", String(game.cb.affix))), e.name]
		var art: Dictionary = e.def.get("art", {})
		var hue_num: int = art.get("hue", 210)
		# The art id is the foe's own key: every slice foe has a painting under
		# that name and char-meta types its box and its feet by the same one.
		# Passing nothing here is what left the fight full of fallback gems.
		var view: EnemyView = EnemyView.new(e.idx, display, float(hue_num), e.key)
		_battlefield.add_child(view)
		_enemy_views[idx] = view
		var slot: Vector2 = slots[idx] if idx < slots.size() else Vector2(STAGE.x * 0.5, 0.0)
		_stand(view, slot.x, slot.y)
	_sync_all()
	_open_fight(slots)


## The opening hand is BUILT by `_sync_all`, not replayed — the startCombat batch
## is hard-synced because the views do not exist until after `apply` returns, so
## its draws never reach `_handle_event` and never fly. Dealt here on the same
## schedule, because otherwise the first thing a fight shows is five cards
## appearing out of nothing, and that is the moment the deal most needs to read.
## Everything that has to wait for the first layout pass. `HudBar._place` hangs
## each cluster off the nearest window edge and `_stand` anchors each actor to
## the ground line, and neither resolves until then — asked in the same frame,
## the draw pile reports a box at y −162 and an actor reports position zero.
func _open_fight(slots: Array[Vector2]) -> void:
	if seq.instant or not is_inside_tree():
		return
	await get_tree().process_frame
	_play_entrance(slots)
	_deal_opening_hand()


## `.combat-screen.intro` (styles.css:739) — the hero walks in from the left,
## the foes from the right, and the furniture rises a beat behind both.
##
## Position is tweened and then handed back to `_stand`, because an actor is
## ANCHORED to the ground line: writing `position` rewrites its offsets, so the
## entrance would quietly cost the layout that keeps its feet on the floor at
## any window height. Re-standing it at the end restores that exactly.
func _play_entrance(slots: Array[Vector2]) -> void:
	if _hero != null:
		_enter(_hero, -70.0, HERO_X, 0.0)
	for idx: int in range(_enemy_views.size()):
		var view: EnemyView = _enemy_views[idx]
		if view == null:
			continue
		var slot: Vector2 = slots[idx] if idx < slots.size() else Vector2(STAGE.x * 0.5, 0.0)
		_enter(view, 90.0, slot.x, slot.y)
	_hud.play_entrance()


func _enter(view: EnemyView, dx: float, x: float, lift: float) -> void:
	var home: Vector2 = view.position
	var rest: float = view.modulate.a
	view.position = home + Vector2(dx, 0.0)
	view.modulate.a = 0.0
	var tw: Tween = view.create_tween()
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(view):
			return
		var e: float = Motion.ease(Motion.ENTER, t)
		view.position = home + Vector2(dx * (1.0 - e), 0.0)
		view.modulate.a = rest * e,
		0.0, 1.0, 0.55)
	tw.tween_callback(_stand.bind(view, x, lift))


func _deal_opening_hand() -> void:
	var opening: Array[int] = _hand.uids()
	if opening.is_empty():
		return
	var flight: float = HandView.deal_flight(opening.size())
	var stagger: float = HandView.deal_stagger(opening.size())
	var pile: Rect2 = _hud.pile_rect(&"draw")
	for i: int in range(opening.size()):
		_hand.deal_in(opening[i], pile, float(i) * stagger, flight)


## `bfSlots` — the authored formations for this shape, as (x centre, lift off
## the ground line). A count nobody authored interpolates between the outer two
## of the widest one, which is what the benchmark does rather than crowding.
static func _slots(count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if count == 1:
		out.append(Vector2(980.0, 0.0))
		return out
	if count == 2:
		out.append(Vector2(820.0, 0.0))
		out.append(Vector2(1035.0, 0.0))
		return out
	if count == 3:
		out.append(Vector2(698.0, 42.0))
		out.append(Vector2(850.0, -18.0))
		out.append(Vector2(996.0, 26.0))
		return out
	var lo: Vector2 = Vector2(698.0, 42.0)
	var hi: Vector2 = Vector2(996.0, 26.0)
	for i: int in range(maxi(count, 0)):
		var t: float = 0.0 if count <= 1 else float(i) / float(count - 1)
		out.append(Vector2(roundf(lo.x + (hi.x - lo.x) * t),
			roundf(lo.y + (hi.y - lo.y) * t)))
	return out


## Stand an actor on the ground line: `x` is where its centre goes, `lift` how
## far off the line it stands. `foot` comes from char-meta and is what lets a
## painting whose feet are not at its own bottom edge still touch the ground.
##
## Anchored rather than positioned, because `_battlefield`'s bottom edge IS the
## ground line — so layout does the arithmetic, at whatever size the window is,
## and nothing here has to know the viewport's height.
func _stand(view: EnemyView, x: float, lift: float) -> void:
	var box: Vector2 = view.size
	view.anchor_left = 0.0
	view.anchor_right = 0.0
	view.anchor_top = 1.0
	view.anchor_bottom = 1.0
	view.offset_left = roundf(x - box.x * 0.5 + view.foot.x)
	view.offset_right = view.offset_left + box.x
	view.offset_bottom = -(lift + view.foot.y)
	view.offset_top = view.offset_bottom - box.y
	# The plate hangs off the GROUND, not off this actor's box. A painting with
	# empty canvas under the creature sinks its box by `foot.y`, and a plate left
	# on the box bottom goes with it — which is why the gravewarden stood on the
	# ledge with its name and its HP rail somewhere under the hand.
	view.align_plate(view.foot.y)


static func _label(initial: String) -> Label:
	var l: Label = Label.new()
	l.text = initial
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func show_result(title: String, body: String, button_text: String) -> void:
	_overlay_title.text = title
	_overlay_body.text = body
	_overlay_button.text = button_text
	_overlay.visible = true


# ---------------------------------------------------------------- input

## Play through the rules gate; false leaves state untouched (drop snaps back).
func request_play(uid: int, target: Variant) -> bool:
	if seq.is_busy() or game.cb.over:
		return false
	var inst: CardInst = _find_card(uid)
	if inst == null or not _rules.can_play(game.cb, inst, target):
		return false
	# `drain(targetIdx)` — the drain is told what was aimed at, because the
	# `play` event does not carry it and a targeted card flies at its foe.
	_play_target = target
	seq.enqueue(game.apply({"t": "playCard", "uid": uid, "target": target}))
	return true


func request_kindle(uid: int) -> bool:
	if seq.is_busy() or game.cb.over:
		return false
	var inst: CardInst = _find_card(uid)
	if inst == null or not _rules.can_kindle(game.cb, inst):
		return false
	seq.enqueue(game.apply({"t": "kindleFromHand", "uid": uid}))
	return true


func _on_card_tapped(uid: int) -> void:
	var inst: CardInst = _find_card(uid)
	if inst == null:
		return
	var d: Dictionary = _rules.card_data(inst)
	var display_name: String = str(d.get("name", String(inst.id)))
	if inst.up:
		display_name += "+"
	var rules_text: String = str(d.get("text", "")).replace("@", "").replace("#", "")
	_inspect_label.text = "%s\n\n%s" % [display_name, rules_text]
	_inspect.visible = true


func _on_inspect_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	var st: InputEventScreenTouch = event as InputEventScreenTouch
	if (mb != null and mb.pressed) or (st != null and st.pressed):
		_inspect.visible = false


func _on_card_drag_moved(uid: int, global_pos: Vector2) -> void:
	if not _hand.is_aiming():
		return
	# The arc reaches the POINTER, not the enemy under it — a shot that misses
	# still has to look aimed somewhere.
	_aim.draw_between(_hand.seat_centre(uid), global_pos)
	var hovered: int = _enemy_at(global_pos)
	for ev: EnemyView in _enemy_views:
		ev.set_targetable(ev.idx == hovered)


func _on_card_drag_released(uid: int, global_pos: Vector2) -> void:
	_aim.clear_aim()
	for ev: EnemyView in _enemy_views:
		ev.set_targetable(false)
	_inspect.visible = false
	var view: CardView = _hand.card_view(uid)
	if view == null:
		return
	if _kindle_toggle.button_pressed:
		if _above_hand(global_pos) and request_kindle(uid):
			return
	elif view.target_kind == "enemy":
		var idx: int = _enemy_at(global_pos)
		if idx >= 0 and request_play(uid, idx):
			return
	elif _above_hand(global_pos) and request_play(uid, null):
		return
	_hand.snap_back(uid)


func _above_hand(global_pos: Vector2) -> bool:
	return global_pos.y < _hand.get_global_rect().position.y


func _enemy_at(global_pos: Vector2) -> int:
	for ev: EnemyView in _enemy_views:
		if not ev.get_global_rect().has_point(global_pos):
			continue
		if ev.idx < game.cb.enemies.size() and game.cb.enemies[ev.idx].hp > 0:
			return ev.idx
	return -1


func _on_end_turn_pressed() -> void:
	if seq.is_busy() or game.cb.over:
		return
	seq.enqueue(game.apply({"t": "endTurn"}))


func _on_art_pressed() -> void:
	if seq.is_busy() or game.cb.over:
		return
	if _rules.can_use_art(game.run, game.cb):
		seq.enqueue(game.apply({"t": "useArt"}))


func _on_kindle_toggled(on: bool) -> void:
	_kindle_toggle.text = "Kindle: on" if on else "Kindle: off"
	_hand.kindle_mode = on
	_aim.clear_aim()
	_hand.cancel_drag()
	_sync_all()  # playability flips between play-cost and kindle rules


func _find_card(uid: int) -> CardInst:
	for pile: Array[CardInst] in [game.cb.hand, game.cb.draw, game.cb.discard, game.cb.exhaust]:
		for c: CardInst in pile:
			if c.uid == uid:
				return c
	return null


# ---------------------------------------------------------------- playback

func _wait(seconds: float) -> void:
	if seq.instant:
		return
	await get_tree().create_timer(seconds).timeout


func _enemy_view(idx: int) -> EnemyView:
	if idx >= 0 and idx < _enemy_views.size():
		return _enemy_views[idx]
	return null


## `combatantView(en).kind` — the body shape `choreoAttack` sorts by. It rides on
## the enemy's own content, so a golem loads in place and a wisp drifts without
## anything here having to know which is which.
func _foe_kind(idx: int) -> String:
	if idx < 0 or idx >= game.cb.enemies.size():
		return "humanoid"
	var art: Dictionary = game.cb.enemies[idx].def.get("art", {})
	return str(art.get("kind", "humanoid"))


## `mvDef?.intent` — what the move about to resolve promises.
func _move_intent(idx: int, move_key: String) -> String:
	if idx < 0 or idx >= game.cb.enemies.size():
		return ""
	var moves: Dictionary = game.cb.enemies[idx].def.get("moves", {})
	var mv: Dictionary = moves.get(move_key, {})
	return str(mv.get("intent", ""))


## `mvDef?.intent?.startsWith('attack')` — only an attacking move is thrown.
func _move_is_attack(idx: int, move_key: String) -> bool:
	return _move_intent(idx, move_key).begins_with("attack")


## `presentation.enemyCenter(idx)` — the middle of a foe's painted body, and the
## point every effect aimed at it is thrown from.
func _enemy_centre(idx: int) -> Vector2:
	var v: EnemyView = _enemy_view(idx)
	if v == null:
		return size * 0.5
	return v.body_centre()


func _hero_centre() -> Vector2:
	if _hero == null:
		return Vector2(HERO_X, size.y - GROUND_Y - 120.0)
	return _hero.body_centre()


## Either side of a hit, by the `who` the domain speaks: a string for the player,
## an index for a foe.
func _who_centre(who: Variant) -> Vector2:
	if typeof(who) == TYPE_STRING:
		return _hero_centre()
	var idx: int = who
	return _enemy_centre(idx)


## Fire-and-forget rising numeral. Thin so the drain branches below read as the
## benchmark's do — `floatText(x, y, text, cls)` and nothing else.
func _float(at: Vector2, msg: String, cls: String = "dmg",
		tint: Color = Color(0, 0, 0, 0), dx: float = 0.0,
		icon: Texture2D = null, icon_px: int = 0) -> void:
	_floaters.float_text(at, msg, cls, tint, dx, icon, icon_px)


## `presentation.holdPendingPileArrivals` in one line: a card in flight has
## already left the engine's hand, so the pile it is heading for would otherwise
## show its new count while the card is still mid-air. Nothing is held here yet —
## the counts are corrected by `_sync_all` when the pump idles — but the bump is
## the arrival the flight was missing.
func _land_in_pile(which: StringName) -> void:
	_hud.bump_pile(which)

func _handle_event(ev: Dictionary) -> void:
	var t: StringName = ev["t"]
	match t:
		EventTypes.TURN:
			# `if (ev.n > 1)` — turn 1 opens the fight and needs no announcement;
			# every turn after it gets the plate and a longer beat.
			var n: int = ev["n"]
			_push_hud()
			if n > 1:
				_floaters.banner(SAY_YOUR_TURN, "turn")
				await _wait(0.5)
			else:
				await _wait(0.12)
		EventTypes.INTENT:
			var idx: int = ev["idx"]
			_refresh_intent(idx)
		EventTypes.ENERGY:
			_push_hud()
			_hud.pulse(&"energy")
		EventTypes.DRAW:
			var uid: int = ev["uid"]
			var inst: CardInst = _find_card(uid)
			if inst != null:
				_hand.add_card(inst, _rules.card_data(inst), _rules.eff_cost(inst))
				# The wave is paced by its own size, so the handler asks how many
				# draws it heads rather than guessing from the hand.
				var wave: int = seq.run_length(EventTypes.DRAW)
				_hand.deal_in(uid, _hud.pile_rect(&"draw"), 0.0,
					HandView.deal_flight(wave))
				# Only the stagger is waited on: the flights overlap, which is
				# what makes a five-card draw read as one deal rather than five.
				await _wait(HandView.deal_stagger(wave))
				if seq.run_length(EventTypes.DRAW) == 1:
					_land_in_pile(&"draw")  # the last of the wave bumps the pile
		EventTypes.RESHUFFLE:
			var shuffled: int = ev.get("n", 0)
			await _reshuffle_ceremony(shuffled)
		EventTypes.PLAY:
			var uid: int = ev["uid"]
			var inst: CardInst = _find_card(uid)
			# `vfxSource` — the card decides what its blows look like, and every
			# hit until the next action reads it back.
			_archetype = "slash"
			if inst != null:
				_archetype = str(_rules.card_data(inst).get("vfx", "slash"))
			_hit_seq = 0
			_hero_swung = false  # this card's swing is owed
			# `if (c && targetIdx != null && cb.enemies[targetIdx])` — a targeted
			# attack does not go quietly to the discard from the hand. The card
			# itself streaks into the foe, and the `toDiscard` that follows moves
			# the pile copy.
			var aimed: int = _play_target if typeof(_play_target) == TYPE_INT else -1
			_play_target = null
			if aimed >= 0 and aimed < game.cb.enemies.size():
				_hand.strike_to(uid, _enemy_centre(aimed))
			else:
				_hand.remove_card(uid)
			await _wait(0.2)
		EventTypes.HIT_ENEMY:
			await _hit_enemy(ev)
		EventTypes.HIT_PLAYER:
			await _hit_player(ev)
		EventTypes.CHIP:
			var idx: int = ev["idx"]
			var chips: int = ev["chips"]
			var facet_max: int = ev["facetMax"]
			var at: Vector2 = _enemy_centre(idx)
			_vfx.burst(at, Color(0.9098039, 0.95686275, 1.0), 5, 190.0,
				TAU, 0.0, 1.8, 240.0)
			var view: EnemyView = _enemy_view(idx)
			if view != null:
				view.set_facets(chips, facet_max)
			await _wait(0.11)
		EventTypes.SHATTER:
			var idx: int = ev["idx"]
			var facet_max: int = ev["facetMax"]
			var at: Vector2 = _enemy_centre(idx)
			_vfx.hitstop(90.0)
			_vfx.ring(at, GLASS_BLUE, 10.0, 700.0, 5.0)
			_vfx.burst(at, GLASS_BLUE, 26, 430.0, TAU, 0.0, 2.4, 300.0)
			_float(at + Vector2(0.0, -58.0), SAY_SHATTER, "shatterf", GLASS_BLUE)
			_vfx.shake(10.0)
			var view: EnemyView = _enemy_view(idx)
			if view != null:
				view.set_facets(0, facet_max)
				view.crack()          # addCrack(x.art, true)
				view.take_hit(false)  # the `hurt` flash without the shove
			await _wait(0.38)
		EventTypes.STAGGERED:
			var idx: int = ev["idx"]
			_float(_enemy_centre(idx) + Vector2(0.0, -76.0), SAY_STAGGERED,
				"staggerf", WARM_GOLD)
			await _wait(0.52)
		EventTypes.DIE:
			var dead_idx: int = ev["idx"]
			await _die(dead_idx)
		EventTypes.EMBER:
			var n: int = ev.get("n", 0)
			_push_hud()
			if n > 0:
				var to: Vector2 = _hud.lantern_rect().get_center()
				var from: Vector2 = _ember_from if _has_ember_from else _hero_centre()
				_vfx.fly_to(from, to, EMBER_ORANGE, mini(n * 2, 5), 6.0, 0.46)
				_hud.pulse(&"lantern")
				await _wait(0.3)
			_has_ember_from = false
		EventTypes.BLOCK_GAIN:
			var who_v: Variant = ev["who"]
			var total: int = ev["total"]
			var n: int = ev.get("n", total)
			var at: Vector2 = _who_centre(who_v)
			if typeof(who_v) == TYPE_STRING:
				if _hero != null:
					_hero.set_ward(total)
				_hud.pulse(&"ward")
			else:
				var who_idx: int = who_v
				var view: EnemyView = _enemy_view(who_idx)
				if view != null:
					view.set_ward(total)
			_float(at + Vector2(0.0, -10.0), str(n), "blockf", WARD_BLUE, 0.0,
				WARD_ICON, 22)
			await _wait(0.14)
		EventTypes.STATUS:
			var who_v: Variant = ev["who"]
			var n: int = ev["n"]
			var id: String = str(ev.get("id", ""))
			var at: Vector2 = _who_centre(who_v)
			var info: Dictionary = game.content.statuses.get(id, {})
			var display: String = str(info.get("name", id))
			# `isDebuff` (drain.js:681) — a status is bad news if the catalogue
			# says so, or if it is strength going the wrong way.
			var debuff: bool = str(info.get("kind", "buff")) == "debuff" \
				or (id == "str" and n < 0)
			var sign: String = "+" if n > 0 else ""
			_float(at + Vector2(0.0, -46.0), "%s%d %s" % [sign, n, display],
				"debufff" if debuff else "bufff")
			if not debuff:
				_vfx.motes(at, BUFF_BLUE, 6)
			await _wait(0.17)
		EventTypes.HEAL:
			var n: int = ev["n"]
			var at: Vector2 = _who_centre(ev.get("who", "player"))
			_vfx.motes(at, HEAL_GREEN, 14)
			_float(at + Vector2(0.0, -30.0), "+%d" % n, "healf")
			_push_hud()
			await _wait(0.2)
		EventTypes.TO_DISCARD, EventTypes.EXHAUST:
			var uid: int = ev["uid"]
			# Each pile takes its own cards back. Ash is not the discard: a card
			# that burns out has to be seen going somewhere else, or the two
			# piles are the same pile wearing different labels.
			var pile: StringName = &"ashes" if t == EventTypes.EXHAUST else &"discard"
			_hand.spend_to(uid, _hud.pile_rect(pile))
			_land_in_pile(pile)
		EventTypes.POWER_CONSUMED:
			# `powerConsumed` (drain.js:935): a power is not discarded — it
			# settles into the glass. The card goes, and what travels to the hero
			# is the power itself.
			var uid: int = ev["uid"]
			var view: CardView = _hand.card_view(uid)
			var from: Vector2 = view.get_global_rect().get_center() if view != null \
				else Vector2(size.x * 0.5, size.y - 180.0)
			_hand.remove_card(uid)
			var hero_at: Vector2 = _hero_centre()
			_vfx.fly_to(from, hero_at, POWER_LILAC, 7, 7.0, 0.56)
			await _wait(0.3)
			_vfx.ring(hero_at, POWER_LILAC, 12.0, 460.0, 4.0)
			_vfx.motes(hero_at, POWER_LILAC, 8)
		EventTypes.KINDLE:
			var uid: int = ev["uid"]
			# Burnt for embers is still burnt: `kindleFromHand` calls
			# `exhaust_card` right after queueing this (combat.gd:752), so the
			# card lands in ash. The EXHAUST that follows finds it already gone
			# and does nothing, which is why it is flown from here rather than
			# left for that event to move twice.
			var view: CardView = _hand.card_view(uid)
			if view != null:
				# `emberFrom = V.centerOf(c)` — the fire this feeds the lantern
				# leaves from the card that burned, not from the hero.
				_ember_from = view.get_global_rect().get_center()
				_has_ember_from = true
				_vfx.burst(_ember_from, EMBER_ORANGE, 22, 190.0, TAU, 0.0,
					2.4, -150.0, "spark", true, 0.85)
			_hand.spend_to(uid, _hud.pile_rect(&"ashes"))
			_land_in_pile(&"ashes")
			await _wait(0.2)
		EventTypes.ART:
			var id: String = str(ev.get("id", ""))
			var art: Dictionary = game.content.arts.get(id, {})
			# `art.tone` is authored in the benchmark's own art catalogue, which
			# the slice exporter does not carry — the lantern's ember stands in
			# until it does.
			var tone: Color = EMBER_ORANGE
			var tone_hex: String = str(art.get("tone", ""))
			if tone_hex.begins_with("#"):
				tone = Color(tone_hex)
			var hero_at: Vector2 = _hero_centre()
			# An art is the lantern's doing: it flares there and settles on the
			# body. The hero does not swing for it (`!startsWith('art:')`).
			_archetype = "fire"
			_hero_swung = true
			_vfx.flash(tone, 0.12, 0.5)
			_vfx.ring(_hud.lantern_rect().get_center(), tone, 10.0, 620.0, 5.0)
			_vfx.motes(hero_at, tone, 12)
			_float(hero_at + Vector2(0.0, -84.0),
				str(art.get("name", id)).to_upper(), "artf", tone)
			_push_hud()
			await _wait(0.12)
		EventTypes.POTION:
			await _wait(0.12)
		EventTypes.DISCARD_HAND:
			var uids: Array = ev["uids"]
			var discard_rect: Rect2 = _hud.pile_rect(&"discard")
			for uid_v: Variant in uids:
				var uid_i: int = uid_v
				_hand.spend_to(uid_i, discard_rect)
			if not uids.is_empty():
				_land_in_pile(&"discard")
			await _wait(0.15)
		EventTypes.END_TURN:
			# `heroActing = false` — nothing swings again until a card is played.
			_hero_swung = true
			_floaters.banner(SAY_ENEMY_TURN, "turn")
			await _wait(0.48)
		EventTypes.ENEMY_ACT:
			await _enemy_act(ev)
		EventTypes.SMOLDER_JUMP:
			var from_idx: int = ev.get("from", -1)
			var to_idx: int = ev.get("to", -1)
			_vfx.fly_to(_enemy_centre(from_idx), _enemy_centre(to_idx),
				POISON_TAN, 5, 7.0, 0.46)
			await _wait(0.4)
		EventTypes.RELIC_PROC:
			# The chrome has no relic row yet (docs/hud-handoff.md D5), so the
			# proc says its own name instead of lighting a chip that is not there.
			_float(_hero_centre() + Vector2(0.0, -110.0),
				str(ev.get("id", "")).to_upper(), "notice")
			await _wait(0.09)
		EventTypes.VICTORY:
			await _wait(0.32)
			_vfx.flash(Color(1.0, 0.9137255, 0.6745098), 0.16, 0.6)
			var perfect: bool = ev.get("perfect", false)
			if perfect:
				await _floaters.banner(SAY_PERFECT, "perfect", 1.4)
				await _wait(0.5)
		EventTypes.DEFEAT:
			await _wait(0.4)
			_vfx.flash(Color(0.2, 0.0, 0.0), 0.5, 1.2)
			await _wait(0.9)
		_:
			push_warning("CombatScreen: unhandled event %s" % String(t))


# ------------------------------------------------------- the heavier branches

## `hitEnemy` (drain.js:532). Poison ticks quietly; everything else is a swing,
## an impact, a number and a shove, in that order.
func _hit_enemy(ev: Dictionary) -> void:
	var idx: int = ev["idx"]
	var amount: int = ev["amount"]
	var hp_after: int = ev["hpAfter"]
	var blocked: int = ev.get("blocked", 0)
	# The domain flags a poison tick the same way the benchmark's drain reads
	# `ev.poison`, so the two never have to agree by coincidence.
	var poison: bool = ev.get("poison", false)
	var view: EnemyView = _enemy_view(idx)
	var at: Vector2 = _enemy_centre(idx)

	if poison:
		_vfx.motes(at, POISON_TAN, 14)
		_float(at + Vector2(0.0, -20.0), str(amount), "poisonf", POISON_TAN)
	else:
		var big: bool = amount >= BIG_HIT
		# `choreoDone` (drain.js:542): the hero swings once for the CARD and the
		# blows land after it, so a three-hit attack is one swing and three
		# recoils rather than three swings.
		if not _hero_swung and _hero != null:
			_hero_swung = true
			await _wait(_hero.lunge("humanoid"))
		_vfx.archetype_hit(at, _archetype, minf(1.0, float(amount) / POWER_SCALE))
		if view != null:
			view.take_hit(true)  # choreoHit — the recoil and the hurt flash
		if blocked > 0:
			_float(at + Vector2(0.0, 26.0), str(blocked), "blockedf",
				Color(0, 0, 0, 0), 0.0, WARD_ICON, 19)
			_vfx.burst(at + Vector2(0.0, 8.0), WARD_BLUE, 9, 210.0, TAU, 0.0,
				2.0, 260.0)  # ward chips off
			if idx < game.cb.enemies.size() and game.cb.enemies[idx].block == 0 \
					and amount == 0:
				_floaters.banner(SAY_GUARD_SHATTERED, "guard-shattered")
				_vfx.shard_spray(at, WARD_BLUE, 14)
		if amount > 0:
			var killing: bool = ev.get("killingBlow", false)
			var overkill: int = ev.get("overkill", 0)
			var tier: String = "dmg"
			if killing and overkill >= 8:
				tier = "dmg-overkill"
			elif killing:
				tier = "dmg-kill"
			elif big:
				tier = "dmg-big"
			# `dx: (hitSeq++ % 3 - 1) * 34` — a multi-hit card lays its numbers
			# in three columns so the second does not land on the first.
			var dx: float = float(_hit_seq % 3 - 1) * 34.0
			_hit_seq += 1
			var tone: Color = VfxLayer.TONES.get(_archetype, Color.WHITE)
			_float(at + Vector2(0.0, -24.0), str(amount), tier, tone, dx)
			if view != null:
				view.crack()  # addCrack(x.art, big)
			_vfx.shake(minf(4.0 + float(amount) * 0.5, 15.0))
			if big:
				_vfx.hitstop(70.0)
				_vfx.ring(at, WARM_GOLD, 10.0, 620.0, 5.0)
			if killing:
				# the blow that ends a life lands heavier — and overkill heavier still
				_vfx.hitstop(130.0 if overkill >= 8 else 90.0)
				_vfx.ring(at, Color.WHITE, 8.0, 780.0, 5.0)
				_vfx.ring(at, WARM_GOLD, 14.0, 900.0, 4.0)
				_vfx.flash(Color(1.0, 0.9019608, 0.6901961), 0.09, 0.28)
				if overkill >= 8:
					_vfx.flash(Color.WHITE, 0.12, 0.24)
					_vfx.burst(at, SPARK_WHITE, 26, 620.0, TAU, 0.0, 2.6, 200.0)
					_vfx.burst(at, Color(1.0, 0.84313726, 0.43137255), 12, 300.0,
						TAU, 0.0, 3.4, 120.0)
		elif blocked == 0:
			_float(at + Vector2(0.0, -24.0), "0", "blockedf")

	if view != null and idx < game.cb.enemies.size():
		view.set_hp(hp_after, game.cb.enemies[idx].max_hp)
		if poison:
			view.take_hit(false)  # the `hurt` flash, with no shove behind it
	await _wait(0.23)


## `hitPlayer` (drain.js:625). The source decides whether the body is thrown:
## a blow shoves, poison and your own burn do not.
func _hit_player(ev: Dictionary) -> void:
	var amount: int = ev["amount"]
	var hp_after: int = ev["hpAfter"]
	var blocked: int = ev.get("blocked", 0)
	var source: String = str(ev.get("source", ""))
	var indirect: bool = source in INDIRECT_SOURCES
	var at: Vector2 = _hero_centre()

	if source == "poison":
		_vfx.motes(at, POISON_TAN, 14)
	elif not indirect:
		if amount > 0:
			_vfx.flash(Color(1.0, 0.13333334, 0.2), minf(0.05 + float(amount) * 0.012, 0.3), 0.3)
		_vfx.archetype_hit(at, _archetype, minf(1.0, float(amount) / POWER_SCALE))
	if _hero != null:
		_hero.set_hp(maxi(0, hp_after), game.cb.player.max_hp)
		_hero.take_hit(not indirect)
	if blocked > 0:
		_float(at + Vector2(0.0, 30.0), str(blocked), "blockedf",
			Color(0, 0, 0, 0), 0.0, WARD_ICON, 19)
		_vfx.burst(at + Vector2(0.0, 8.0), WARD_BLUE, 9, 210.0, TAU, 0.0, 2.0, 260.0)
		if game.cb.player.block == 0 and amount == 0:
			_floaters.banner(SAY_GUARD_SHATTERED, "guard-shattered")
			_vfx.shard_spray(at, WARD_BLUE, 14)
	if amount > 0:
		var dx: float = float(_hit_seq % 3 - 1) * 34.0
		_hit_seq += 1
		var tone: Color = VfxLayer.TONES.get(_archetype, Color.WHITE)
		_float(at + Vector2(0.0, -30.0), str(amount),
			"dmg-big" if amount >= BIG_HIT else "dmg", tone, dx)
		_vfx.shake(minf(5.0 + float(amount) * 0.6, 18.0))
		# no hero cracks (user call, 2026-07-07): the glass language is for foes
	elif blocked == 0:
		_float(at + Vector2(0.0, -30.0), "0", "blockedf")
	_push_hud()
	await _wait(0.24)


## `die` (drain.js:589). The body sags, the fire wells up through its own
## fractures, and at the instant the blaze peaks the glass gives.
func _die(idx: int) -> void:
	var view: EnemyView = _enemy_view(idx)
	var at: Vector2 = _enemy_centre(idx)
	var boss: bool = idx < game.cb.enemies.size() and game.cb.enemies[idx].boss
	var elite: bool = idx < game.cb.enemies.size() and game.cb.enemies[idx].elite
	# the fire inside spills toward the lantern
	_ember_from = at
	_has_ember_from = true
	if boss:
		# world-stop: one silent beat before the vessel is allowed to fail
		_vfx.hitstop(110.0)
		await _wait(0.82)
	if view != null:
		await _wait(view.stagger())
	var beat: float = 0.32 if boss else 0.2
	if view != null:
		view.mark_dead(beat)
	await _wait(beat)
	_vfx.burst(at, GLASS_BLUE, 30, 480.0, TAU, 0.0, 2.6, 340.0)
	_vfx.burst(at, SOUL_VIOLET, 26, 380.0, TAU, 0.0, 3.2, 60.0, "dot")
	_vfx.ring(at, REVIVE_LILAC, 12.0, 720.0, 6.0)
	_vfx.flash(Color.WHITE, 0.24 if boss else 0.1, 0.3)
	_vfx.shake(22.0 if boss else 12.0)
	if elite and not boss:
		_vfx.hitstop(60.0)  # an elite's ending gets a beat a common foe does not
	await _wait(0.9 if boss else 0.5)


## `enemyAct` (drain.js:884). The chip blazes, the name reads, THEN the body
## moves — a move that does not attack still holds the beat, so the enemy turn
## keeps its rhythm whether or not anything swings.
func _enemy_act(ev: Dictionary) -> void:
	var idx: int = ev["idx"]
	var view: EnemyView = _enemy_view(idx)
	var move_key: String = str(ev.get("move", ""))
	var attacking: bool = _move_is_attack(idx, move_key)
	_hit_seq = 0
	# `vfxSource` for the enemy phase: an attack speaks its body's language, a
	# debuff speaks void and a ward speaks ward.
	var kind: String = _foe_kind(idx)
	_archetype = VfxLayer.KIND_ARCHETYPE.get(kind, "slash")
	var intent: String = _move_intent(idx, move_key)
	if intent == "debuff":
		_archetype = "void"
	elif intent == "buff" or intent == "block":
		_archetype = "ward"
	if view != null:
		view.telegraph()
		_float(_enemy_centre(idx) + Vector2(0.0, -90.0),
			str(ev.get("name", "")), "movef")
	await _wait(0.3)
	if view != null and attacking:
		await _wait(view.lunge(kind))
	else:
		await _wait(0.32)


## `playReshuffleCeremony` (drain.js:132) — the discard walks back into the draw
## pile as a stream of card backs, and the pile answers when they land.
func _reshuffle_ceremony(n: int) -> void:
	if seq.instant:
		return
	# `Array.from({ length: n })` — one back per card, capped: past eight the
	# stream stops reading as more cards and starts reading as noise.
	_hud.fly_backs(&"discard", &"draw", maxi(1, mini(n, 8)), 0.6)
	await _wait(0.6)
	_land_in_pile(&"draw")
	_float(_hud.pile_rect(&"draw").get_center() + Vector2(0.0, -46.0),
		SAY_RESHUFFLE, "notice")


# ---------------------------------------------------------------- sync

## Everything the chrome layer shows, in one call. `set_values()` guards on its
## ten ints and returns immediately when none of them moved, so driving this
## from an event handler as well as from the drain-idle sync costs one array
## compare rather than ten label re-shapes.
func _push_hud() -> void:
	var cb: CombatState = game.cb
	if cb == null or _hud == null:
		return
	_hud.set_values(maxi(0, cb.player.hp), cb.player.max_hp, cb.player.block,
		game.run.player.gold, cb.player.energy, cb.player.energy_max,
		cb.draw.size(), cb.discard.size(), cb.exhaust.size(), cb.hand.size())
	# Embers are the number the lantern carries; the rules gate is whether it
	# can be spent at all (docs/hud-handoff.md §3).
	_hud.set_lantern(cb.embers, _rules.can_use_art(game.run, cb))
	# The strip's middle carries the place. The turn rides its dim tail — the
	# benchmark's own bar has no seat for a number it does not show, and the
	# tail is the honest one (assembly-integration-plan.md D3).
	_hud.set_title(_encounter_text, "Turn %d" % cb.turn)


func _on_busy_changed(busy: bool) -> void:
	var locked: bool = busy or game.cb == null or game.cb.over
	# HudBar's buttons do not disable — they are bare art with plain signals —
	# but `_on_end_turn_pressed` and `_on_art_pressed` already refuse while the
	# pump is busy, so the guard holds and only the grey-out is missing.
	# A `set_locked(bool)` on the widget would close that; it is a HUD-lane ask.
	_kindle_toggle.disabled = locked
	_hand.locked = locked
	if locked:
		_aim.clear_aim()
		_hand.cancel_drag()
		for ev: EnemyView in _enemy_views:
			ev.set_targetable(false)
	if not busy:
		_sync_all()


## "7" or "4×2" from the {"dmg", "times"} preview; "" for non-attacks.
func _fmt_enemy_dmg(preview: Variant) -> String:
	if preview == null:
		return ""
	var p: Dictionary = preview
	var dmg: int = p.get("dmg", 0)
	var times: int = p.get("times", 1)
	return str(dmg) if times <= 1 else "%d×%d" % [dmg, times]


func _refresh_intent(idx: int) -> void:
	var view: EnemyView = _enemy_view(idx)
	if view == null:
		return
	var e: EnemyCombatant = game.cb.enemies[idx]
	if e.hp <= 0:
		return
	var mv: Dictionary = e.move()
	view.set_intent(
		StringName(str(mv.get("intent", ""))),
		_fmt_enemy_dmg(_rules.preview_enemy_dmg(game.cb, e)),
		str(mv.get("name", String(e.move_key))))


func _sync_all() -> void:
	var cb: CombatState = game.cb
	if cb == null:
		return
	_push_hud()
	# The hero reads its own numbers, because the plate that shows them is the
	# hero's — the same markup a foe carries (docs/hud-handoff.md §2).
	if _hero != null:
		_hero.set_hp(maxi(0, cb.player.hp), cb.player.max_hp)
		_hero.set_ward(cb.player.block)
		_hero.set_statuses(cb.player.statuses, game.content.statuses)
	for e: EnemyCombatant in cb.enemies:
		var view: EnemyView = _enemy_view(e.idx)
		if view == null:
			continue
		var intent: StringName = &""
		var move_name: String = ""
		var dmg_text: String = ""
		if e.hp > 0:
			var mv: Dictionary = e.move()
			intent = StringName(str(mv.get("intent", "")))
			move_name = str(mv.get("name", String(e.move_key)))
			dmg_text = _fmt_enemy_dmg(_rules.preview_enemy_dmg(cb, e))
		view.sync(e, dmg_text, intent, move_name, game.content.statuses)
	var first_living: int = -1
	for e: EnemyCombatant in cb.enemies:
		if e.hp > 0:
			first_living = e.idx
			break
	# Reconciled, not rebuilt. Adding is idempotent, so a card the drain already
	# dealt keeps the node that is flying it; only what the engine no longer
	# holds is taken out.
	var order: Array[int] = []
	for c: CardInst in cb.hand:
		_hand.add_card(c, _rules.card_data(c), _rules.eff_cost(c))
		order.append(c.uid)
	_hand.sync_hand(order)
	for c: CardInst in cb.hand:
		var view: CardView = _hand.card_view(c.uid)
		if view == null:
			continue
		var target_probe: Variant = first_living if view.target_kind == "enemy" else null
		if _kindle_toggle.button_pressed:
			view.set_playable(_rules.can_kindle(cb, c))
		else:
			view.set_playable(_rules.can_play(cb, c, target_probe))
	if cb.over and not _over_emitted:
		_over_emitted = true
		combat_over.emit(cb.result)
