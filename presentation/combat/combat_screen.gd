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
	_build_stage()

	# `.battlefield` — inset 0 with `bottom: var(--ground-y)`. Actors are its only
	# children and are placed by their FEET, so the container's bottom edge is
	# the ground line and nothing has to convert coordinates to say so.
	_battlefield = Control.new()
	_battlefield.set_anchors_preset(Control.PRESET_FULL_RECT)
	_battlefield.offset_bottom = -GROUND_Y
	_battlefield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_battlefield)

	# The whole chrome layer, in one widget, measured against the same
	# 1180x820 the stage above is. `plate = false` because the ward chip and HP
	# rail belong to the actor they describe — see docs/hud-handoff.md §2.
	_hud = HudBar.new(true, true, false)
	_hud.end_turn_pressed.connect(_on_end_turn_pressed)
	_hud.lantern_pressed.connect(_on_art_pressed)
	add_child(_hud)

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
	add_child(_hand)

	# Above the hand: the arc launches 80px over the card it comes from, so it
	# clears the fan on its own, but the reticle must never end up behind a
	# neighbouring card when aiming across the hand.
	_aim = AimArc.new()
	add_child(_aim)

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
	add_child(_kindle_toggle)

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
	var night: ColorRect = ColorRect.new()  # body { background: #000 }
	night.color = Color.BLACK
	night.set_anchors_preset(Control.PRESET_FULL_RECT)
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night)

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
	add_child(r)


func start_encounter(enemy_ids: Array, kind: String, encounter_text: String) -> void:
	_over_emitted = false
	_encounter_text = encounter_text
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


## `mvDef?.intent?.startsWith('attack')` — only an attacking move is thrown.
func _move_is_attack(idx: int, move_key: String) -> bool:
	if idx < 0 or idx >= game.cb.enemies.size():
		return false
	var moves: Dictionary = game.cb.enemies[idx].def.get("moves", {})
	var mv: Dictionary = moves.get(move_key, {})
	return str(mv.get("intent", "")).begins_with("attack")


## Fire-and-forget rising damage/heal number over a view.
func _float_text(over: Control, msg: String, color: Color) -> void:
	if seq.instant or over == null:
		return
	var l: Label = Label.new()
	l.text = msg
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	add_child(l)
	l.global_position = over.global_position + Vector2(over.size.x * 0.5 - 16, -6)
	var tw: Tween = create_tween()
	tw.tween_property(l, "position", l.position + Vector2(0, -46), 0.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _handle_event(ev: Dictionary) -> void:
	var t: StringName = ev["t"]
	match t:
		EventTypes.TURN:
			_push_hud()
		EventTypes.INTENT:
			var idx: int = ev["idx"]
			_refresh_intent(idx)
		EventTypes.ENERGY:
			_push_hud()
		EventTypes.DRAW:
			var uid: int = ev["uid"]
			var inst: CardInst = _find_card(uid)
			if inst != null:
				_hand.add_card(inst, _rules.card_data(inst), _rules.eff_cost(inst))
			await _wait(0.08)
		EventTypes.RESHUFFLE:
			await _wait(0.15)
		EventTypes.PLAY:
			var uid: int = ev["uid"]
			_hand.remove_card(uid)
			_hero_swung = false  # this card's swing is owed
			await _wait(0.12)
		EventTypes.HIT_ENEMY:
			var idx: int = ev["idx"]
			var amount: int = ev["amount"]
			var hp_after: int = ev["hpAfter"]
			# The domain flags a poison tick the same way the benchmark's drain
			# reads `ev.poison`, so the two never have to agree by coincidence.
			var poison: bool = ev.get("poison", false)
			# `choreoDone` (drain.js:542): the hero swings once for the CARD and
			# the blow lands after it, so a three-hit attack is one swing and
			# three recoils rather than three swings.
			if not poison and not _hero_swung and _hero != null:
				_hero_swung = true
				await _wait(_hero.lunge("humanoid"))
			var view: EnemyView = _enemy_view(idx)
			if view != null:
				var e: EnemyCombatant = game.cb.enemies[idx]
				view.set_hp(hp_after, e.max_hp)
				view.take_hit(not poison)
				_float_text(view, str(amount), Color(1, 0.45, 0.4))
			await _wait(0.22)
		EventTypes.HIT_PLAYER:
			var amount: int = ev["amount"]
			var hp_after: int = ev["hpAfter"]
			if _hero != null:
				_hero.set_hp(maxi(0, hp_after), game.cb.player.max_hp)
				# drain.js:626 splits by source: poison, burn, self and thorns
				# take the quiet branch, and only a real blow shoves the body.
				_hero.take_hit(not (str(ev.get("source", "")) in INDIRECT_SOURCES))
				_float_text(_hero, str(amount), Color(1, 0.45, 0.4))
			_push_hud()
			await _wait(0.22)
		EventTypes.CHIP:
			var idx: int = ev["idx"]
			var chips: int = ev["chips"]
			var facet_max: int = ev["facetMax"]
			var view: EnemyView = _enemy_view(idx)
			if view != null:
				view.set_facets(chips, facet_max)
			await _wait(0.1)
		EventTypes.SHATTER:
			var idx: int = ev["idx"]
			var facet_max: int = ev["facetMax"]
			var view: EnemyView = _enemy_view(idx)
			if view != null:
				view.set_facets(0, facet_max)
				_float_text(view, "SHATTER", Color(0.6, 0.85, 1))
			await _wait(0.3)
		EventTypes.STAGGERED:
			var idx: int = ev["idx"]
			var view: EnemyView = _enemy_view(idx)
			if view != null:
				_float_text(view, "staggered", Color(0.6, 0.85, 1))
			await _wait(0.2)
		EventTypes.DIE:
			var idx: int = ev["idx"]
			var view: EnemyView = _enemy_view(idx)
			if view != null:
				view.mark_dead()
			await _wait(0.3)
		EventTypes.EMBER:
			_push_hud()
			await _wait(0.08)
		EventTypes.BLOCK_GAIN:
			var who_v: Variant = ev["who"]
			var total: int = ev["total"]
			if typeof(who_v) == TYPE_STRING:
				if _hero != null:
					_hero.set_ward(total)
			else:
				var who_idx: int = who_v
				var view: EnemyView = _enemy_view(who_idx)
				if view != null:
					view.set_ward(total)
			await _wait(0.1)
		EventTypes.STATUS:
			await _wait(0.08)
		EventTypes.HEAL:
			var n: int = ev["n"]
			_float_text(_hero, "+%d" % n, Color(0.5, 1, 0.6))
			_push_hud()
			await _wait(0.15)
		EventTypes.TO_DISCARD, EventTypes.EXHAUST, EventTypes.POWER_CONSUMED:
			var uid: int = ev["uid"]
			_hand.remove_card(uid)
		EventTypes.KINDLE:
			var uid: int = ev["uid"]
			_hand.remove_card(uid)
			await _wait(0.2)
		EventTypes.ART:
			_float_text(_hero, "ART", Color(1, 0.7, 0.3))
			_push_hud()
			await _wait(0.3)
		EventTypes.POTION:
			await _wait(0.15)
		EventTypes.DISCARD_HAND:
			var uids: Array = ev["uids"]
			for uid_v: Variant in uids:
				var uid_i: int = uid_v
				_hand.remove_card(uid_i)
			await _wait(0.15)
		EventTypes.END_TURN:
			await _wait(0.1)
		EventTypes.ENEMY_ACT:
			var idx: int = ev["idx"]
			var view: EnemyView = _enemy_view(idx)
			if view != null:
				# The telegraph has been spent — clear it rather than restating
				# the move on it. The float text below is what announces the
				# name, and a chip is a promise, not a receipt.
				view.clear_intent()
				_float_text(view, str(ev.get("name", "")), Color(1, 0.85, 0.5))
			# drain.js:905 — the name reads for 300ms, THEN the body moves. A
			# move that does not attack simply holds the beat, so the enemy turn
			# keeps its rhythm whether or not anything swings.
			await _wait(0.3)
			if view != null and _move_is_attack(idx, str(ev.get("move", ""))):
				await _wait(view.lunge(_foe_kind(idx)))
			else:
				await _wait(0.32)
		EventTypes.SMOLDER_JUMP:
			await _wait(0.15)
		EventTypes.RELIC_PROC:
			_float_text(_hero, str(ev.get("id", "")), Color(1, 0.85, 0.5))
			await _wait(0.2)
		EventTypes.VICTORY, EventTypes.DEFEAT:
			await _wait(0.25)
		_:
			push_warning("CombatScreen: unhandled event %s" % String(t))


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
	_hand.clear()
	var first_living: int = -1
	for e: EnemyCombatant in cb.enemies:
		if e.hp > 0:
			first_living = e.idx
			break
	for c: CardInst in cb.hand:
		var view: CardView = _hand.add_card(c, _rules.card_data(c), _rules.eff_cost(c))
		var target_probe: Variant = first_living if view.target_kind == "enemy" else null
		if _kindle_toggle.button_pressed:
			view.set_playable(_rules.can_kindle(cb, c))
		else:
			view.set_playable(_rules.can_play(cb, c, target_probe))
	if cb.over and not _over_emitted:
		_over_emitted = true
		combat_over.emit(cb.result)
