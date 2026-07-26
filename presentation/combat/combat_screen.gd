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
## The act theme's glow (`themes.js` act 1: `glow: 6750110`), which tints the
## ledge band, its lip and the breath. Our slice content carries no theme
## section — `content_db.gd` loads no `themes` — so the act → plate + tint
## mapping lives here rather than in data.
## ponytail: move both to ContentDB the day `capture-port-fixtures.mjs` exports
## themes. The shape is one dictionary per act, not a new system.
const LEDGE: Color = Color(0.4, 1.0, 0.62)  # #66ff9e
const STAGE_ART: String = "res://assets/art/stage/act1-%s.png"

## One breath blob and its phase. A class rather than a dictionary of parts,
## for the reason `HudBar.Pile` is one: the strict gate wants every piece typed
## at the moment it is read.
class Breath:
	var node: TextureRect
	var delay: float = 0.0


var game: GlassvowGame
var seq: EventSequencer = EventSequencer.new()
var _breaths: Array[Breath] = []

var _rules: CombatRules
var _enemy_views: Array[EnemyView] = []
var _hand: HandView
var _turn_label: Label
var _encounter_label: Label
var _player_hp: Label
var _player_hp_bar: ProgressBar
var _player_ward: Label
var _player_statuses: StatusRow
var _embers_label: Label
var _gold_label: Label
var _piles_label: Label
var _end_turn: Button
var _art_button: Button
var _kindle_toggle: Button
var _enemy_row: HBoxContainer
var _overlay: ColorRect
var _overlay_title: Label
var _overlay_body: Label
var _overlay_button: Button
var _inspect: PanelContainer
var _inspect_label: Label
var _over_emitted: bool = false


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

## The ground breathes only once there is a tree to breathe in. Everything else
## this screen owns is built in `_init()`; see the class docblock.
func _ready() -> void:
	for b: Breath in _breaths:
		var tw: Tween = create_tween().set_loops()
		if b.delay > 0.0:
			tw.tween_interval(b.delay)
		tw.tween_property(b.node, "modulate:a", 0.16, 7.0).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(b.node, "scale", Vector2(1.06, 1.06),
			7.0).set_trans(Tween.TRANS_SINE)
		tw.tween_property(b.node, "modulate:a", 0.06, 7.0).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(b.node, "scale", Vector2(0.94, 0.94),
			7.0).set_trans(Tween.TRANS_SINE)


func _build_ui() -> void:
	_build_stage()

	var top_panel: PanelContainer = PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var top_sb: StyleBoxFlat = StyleBoxFlat.new()
	top_sb.bg_color = Color(0.02, 0.03, 0.06, 0.55)
	top_sb.border_width_bottom = 1
	top_sb.border_color = Color(GlassStyle.GLASS.r, GlassStyle.GLASS.g, GlassStyle.GLASS.b, 0.22)
	top_sb.content_margin_left = 20
	top_sb.content_margin_right = 20
	top_sb.content_margin_top = 9
	top_sb.content_margin_bottom = 9
	top_panel.add_theme_stylebox_override("panel", top_sb)
	add_child(top_panel)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	top_panel.add_child(top)
	var title: Label = _label("琉璃誓言")  # the vow itself — proves CJK shaping end to end
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0, 0.92))
	top.add_child(title)
	_turn_label = _label("Turn 1")
	_turn_label.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	top.add_child(_turn_label)
	_gold_label = _label("")
	_gold_label.add_theme_color_override("font_color", Color(GlassStyle.EMBER.r, GlassStyle.EMBER.g, GlassStyle.EMBER.b, 0.9))
	top.add_child(_gold_label)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_encounter_label = _label("")
	_encounter_label.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	top.add_child(_encounter_label)

	var enemy_center: CenterContainer = CenterContainer.new()
	enemy_center.anchor_left = 0.0
	enemy_center.anchor_right = 1.0
	enemy_center.anchor_top = 0.0
	enemy_center.anchor_bottom = 0.0
	enemy_center.offset_top = 90
	enemy_center.offset_bottom = 400
	add_child(enemy_center)
	_enemy_row = HBoxContainer.new()
	_enemy_row.add_theme_constant_override("separation", 28)
	enemy_center.add_child(_enemy_row)

	var hero: Color = Color(0.52, 0.6, 1.0)  # hero hue 225
	var player_pane: PanelContainer = PanelContainer.new()
	player_pane.anchor_top = 1.0
	player_pane.anchor_bottom = 1.0
	player_pane.offset_left = 16
	player_pane.offset_top = -300
	player_pane.offset_right = 228
	player_pane.offset_bottom = -16
	player_pane.add_theme_stylebox_override("panel", GlassStyle.pane(hero))
	add_child(player_pane)
	var player_box: VBoxContainer = VBoxContainer.new()
	player_box.add_theme_constant_override("separation", 8)
	player_pane.add_child(player_box)
	var pname: Label = _label("The Duskblade")
	pname.add_theme_font_size_override("font_size", 17)
	pname.add_theme_color_override("font_color", hero.lerp(GlassStyle.TEXT, 0.55))
	player_box.add_child(pname)
	_player_hp = _label("")
	player_box.add_child(_player_hp)
	_player_hp_bar = ProgressBar.new()
	_player_hp_bar.show_percentage = false
	_player_hp_bar.custom_minimum_size = Vector2(0, 14)
	GlassStyle.style_bar(_player_hp_bar, GlassStyle.HP_RED)
	player_box.add_child(_player_hp_bar)
	var chip_row: HBoxContainer = HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 8)
	chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	player_box.add_child(chip_row)
	_player_ward = _chip_line(chip_row, GlassStyle.GLASS)
	_embers_label = _chip_line(chip_row, GlassStyle.EMBER)
	_player_statuses = StatusRow.new()
	player_box.add_child(_player_statuses)
	var pad: Control = Control.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	player_box.add_child(pad)
	_art_button = Button.new()
	_art_button.text = "Lantern Art"
	GlassStyle.style_button(_art_button, hero)
	_art_button.pressed.connect(_on_art_pressed)
	player_box.add_child(_art_button)
	_kindle_toggle = Button.new()
	_kindle_toggle.text = "Kindle: off"
	_kindle_toggle.toggle_mode = true
	GlassStyle.style_button(_kindle_toggle, GlassStyle.EMBER)
	_kindle_toggle.toggled.connect(_on_kindle_toggled)
	player_box.add_child(_kindle_toggle)

	_hand = HandView.new()
	_hand.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hand.offset_top = -260
	_hand.offset_left = 230
	_hand.offset_right = -230
	_hand.offset_bottom = -10
	_hand.card_tapped.connect(_on_card_tapped)
	_hand.card_drag_moved.connect(_on_card_drag_moved)
	_hand.card_drag_released.connect(_on_card_drag_released)
	add_child(_hand)

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

	var right_box: VBoxContainer = VBoxContainer.new()
	right_box.anchor_left = 1.0
	right_box.anchor_right = 1.0
	right_box.anchor_top = 1.0
	right_box.anchor_bottom = 1.0
	right_box.offset_left = -210
	right_box.offset_right = -16
	right_box.offset_top = -300
	right_box.offset_bottom = -16
	right_box.add_theme_constant_override("separation", 10)
	add_child(right_box)
	var pad_r: Control = Control.new()
	pad_r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.add_child(pad_r)
	_piles_label = _label("")
	_piles_label.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	_piles_label.add_theme_font_size_override("font_size", 13)
	right_box.add_child(_piles_label)
	_end_turn = Button.new()
	_end_turn.text = "End Turn"
	_end_turn.custom_minimum_size = Vector2(0, 58)
	GlassStyle.style_button(_end_turn, GlassStyle.EMBER)
	_end_turn.pressed.connect(_on_end_turn_pressed)
	right_box.add_child(_end_turn)

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
	_plate("backdrop", 640.0, 280.0, 0.0, 1.0, 0.85)
	_plate("mid", 1000.0, 300.0, 100.0, 0.4, 0.95)
	_plate("ledge", 450.0, 0.0, 0.0, 1.0, 1.0, true)

	# `.stage-breath` — 34cqw x 26cqh blobs, container-query units against the
	# stage, so 401 x 213 here. Their opacity and scale breathe 7s alternating
	# (`@keyframes breath`: .06/scale .94 → .16/scale 1.06).
	_breath(0.06 * STAGE.x, GROUND_Y - 0.08 * STAGE.y, 0.0)
	_breath(STAGE.x - 0.08 * STAGE.x - 0.34 * STAGE.x, GROUND_Y - 0.12 * STAGE.y, 3.2)

	# `.combat-screen::after` — depth mist under the ground plate, 300px tall.
	var mist: TextureRect = TextureRect.new()
	mist.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(0.02, 0.027, 0.055, 0.0), Color(0.02, 0.027, 0.055, 0.55)]),
		PackedFloat32Array([0.0, 0.75]), false, Vector2(0.5, 0.0), Vector2(0.5, 1.0))
	mist.anchor_top = 1.0
	mist.anchor_bottom = 1.0
	mist.anchor_right = 1.0
	mist.offset_top = -300.0
	mist.stretch_mode = TextureRect.STRETCH_SCALE
	mist.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mist)

	# `.stage-ledge` — a 120px band whose TOP is the ground line, so the light
	# pools in front of where the actors stand, not behind them.
	var band: TextureRect = TextureRect.new()
	band.texture = _ledge_tex()
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.anchor_right = 1.0
	band.offset_top = -GROUND_Y
	band.offset_bottom = -(GROUND_Y - 120.0)
	band.stretch_mode = TextureRect.STRETCH_SCALE
	# Without this a TextureRect's minimum size is its TEXTURE's size, so a
	# 64px source silently forces the band 256px tall and the ground glow
	# bleeds to the bottom of the screen. Same reason every gradient below
	# says it too.
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)

	# `.stage-ledge::before` — the lip: a hairline of caught light one lip-height
	# above the ground line, faded out at both ends, with its own bloom under it.
	var lip_tint: Color = LEDGE.lerp(Color.WHITE, 0.25)
	var bloom: TextureRect = _lip_band(Color(lip_tint.r, lip_tint.g, lip_tint.b, 0.14), 18.0)
	add_child(bloom)
	add_child(_lip_band(Color(lip_tint.r, lip_tint.g, lip_tint.b, 0.4), 2.0))


## One painted plate. `h` and `y` are stage px, `y` being the plate's bottom
## above the stage bottom — except the ledge, which hangs off the ground line
## instead (`combat.js:384`). `zoom` scales about the plate's own bottom-left,
## which is the CSS order: the individual `scale` property resolves BEFORE
## `transform`'s centring translate, so the centring uses the unscaled width.
func _plate(art: String, h: float, y: float, dx: float, zoom: float,
		alpha: float, is_ledge: bool = false) -> void:
	var path: String = STAGE_ART % art
	if not ResourceLoader.exists(path):
		# Named rather than silent: a missing plate is otherwise an invisible
		# hole in the ground with nothing in the log saying which one.
		push_warning("stage: missing plate %s" % path)
		return
	var tex: Texture2D = load(path)
	var aspect: float = float(tex.get_width()) / maxf(1.0, float(tex.get_height()))
	var base: Vector2 = Vector2(maxf(STAGE.x, h * aspect), h)  # `min-width: 100%`
	var bottom: float = maxf(0.0, GROUND_Y + LEDGE_LIP - h + y) if is_ledge else y
	var r: TextureRect = TextureRect.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.modulate = Color(1.0, 1.0, 1.0, alpha)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.5
	r.anchor_right = 0.5
	r.anchor_top = 1.0
	r.anchor_bottom = 1.0
	r.offset_left = -base.x * 0.5 + dx
	r.offset_right = r.offset_left + base.x * zoom
	r.offset_top = -(bottom + base.y * zoom)
	r.offset_bottom = -bottom
	add_child(r)


## One breath blob, phase-shifted by `delay` so the two never pulse together.
func _breath(x: float, bottom: float, delay: float) -> void:
	var b: TextureRect = TextureRect.new()
	b.texture = GlassStyle.grad_tex(
		PackedColorArray([LEDGE, Color(LEDGE.r, LEDGE.g, LEDGE.b, 0.0)]),
		PackedFloat32Array([0.0, 0.7]), true, Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	b.stretch_mode = TextureRect.STRETCH_SCALE
	b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	var box: Vector2 = Vector2(0.34 * STAGE.x, 0.26 * STAGE.y)
	b.offset_left = x
	b.offset_right = x + box.x
	b.offset_top = -(bottom + box.y)
	b.offset_bottom = -bottom
	b.pivot_offset = box * 0.5
	b.modulate = Color(1.0, 1.0, 1.0, 0.06)
	b.scale = Vector2(0.94, 0.94)
	add_child(b)
	# The tween waits for the tree. This screen is fully constructed at `new()`
	# so headless tests can drive it without ever entering one (see the class
	# docblock), and `create_tween()` is the one thing here that cannot honour
	# that — so the breath starts in `_ready()` and simply never runs headless.
	var held: Breath = Breath.new()
	held.node = b
	held.delay = delay
	_breaths.append(held)


## The lip and its bloom share a shape: a full-width band inset to 6%, fading
## out over the first and last 14% of what remains.
func _lip_band(tint: Color, h: float) -> TextureRect:
	var t: TextureRect = TextureRect.new()
	t.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(tint.r, tint.g, tint.b, 0.0), tint, tint,
			Color(tint.r, tint.g, tint.b, 0.0)]),
		PackedFloat32Array([0.0, 0.2, 0.8, 1.0]), false,
		Vector2(0.0, 0.5), Vector2(1.0, 0.5))
	t.anchor_left = 0.06
	t.anchor_right = 0.94
	t.anchor_top = 1.0
	t.anchor_bottom = 1.0
	t.offset_top = -(GROUND_Y + LEDGE_LIP + h * 0.5)
	t.offset_bottom = t.offset_top + h
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## The ledge band's own texture. The CSS puts a vertical fade under a horizontal
## mask; a plain TextureRect has no mask, and the two ramps are separable, so
## they are multiplied once into an image here instead of costing a shader.
##   background: linear-gradient(180deg, LEDGE@9%, transparent 62%)
##   mask:       linear-gradient(90deg, transparent, #000 14% 86%, transparent)
static func _ledge_tex() -> ImageTexture:
	var side: int = 64
	var img: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	for iy: int in range(side):
		var down: float = clampf(1.0 - (float(iy) / float(side - 1)) / 0.62, 0.0, 1.0)
		for ix: int in range(side):
			var u: float = float(ix) / float(side - 1)
			var across: float = clampf(u / 0.14, 0.0, 1.0) * clampf((1.0 - u) / 0.14, 0.0, 1.0)
			img.set_pixel(ix, iy, Color(LEDGE.r, LEDGE.g, LEDGE.b, 0.09 * down * across))
	return ImageTexture.create_from_image(img)


## A pill chip holding one dynamic label; returns the inner label for text
## updates. Used for player ward / lantern in the panel chip row.
static func _chip_line(parent: Control, accent: Color) -> Label:
	var chip: PanelContainer = PanelContainer.new()
	chip.add_theme_stylebox_override("panel", GlassStyle.chip(accent))
	parent.add_child(chip)
	var l: Label = _label("")
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.95))
	chip.add_child(l)
	return l


static func _label(initial: String) -> Label:
	var l: Label = Label.new()
	l.text = initial
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# ---------------------------------------------------------------- encounters

func start_encounter(enemy_ids: Array, kind: String, encounter_text: String) -> void:
	_over_emitted = false
	_encounter_label.text = encounter_text
	# Live play rolls the elite affix inside start_combat (traces passed it
	# explicitly only to skip the rng draw).
	game.apply({"t": "startCombat", "enemies": enemy_ids, "kind": kind})
	for view: EnemyView in _enemy_views:
		view.queue_free()
	_enemy_views.clear()
	for e: EnemyCombatant in game.cb.enemies:
		var display: String = e.name
		if game.cb.affix != &"":
			var affix_def: Dictionary = game.content.affixes.get(String(game.cb.affix), {})
			display = "%s %s" % [str(affix_def.get("name", String(game.cb.affix))), e.name]
		var art: Dictionary = e.def.get("art", {})
		var hue_num: int = art.get("hue", 210)
		var view: EnemyView = EnemyView.new(e.idx, display, float(hue_num))
		_enemy_row.add_child(view)
		_enemy_views.append(view)
	_sync_all()


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
	var view: CardView = _hand.card_view(uid)
	if view == null or view.target_kind != "enemy":
		return
	var hovered: int = _enemy_at(global_pos)
	for ev: EnemyView in _enemy_views:
		ev.set_targetable(ev.idx == hovered)


func _on_card_drag_released(uid: int, global_pos: Vector2) -> void:
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
			var n: int = ev["n"]
			_turn_label.text = "Turn %d" % n
		EventTypes.INTENT:
			var idx: int = ev["idx"]
			_refresh_intent(idx)
		EventTypes.ENERGY:
			var n: int = ev["n"]
			_end_turn.text = "End Turn\nEnergy %d" % n
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
			await _wait(0.12)
		EventTypes.HIT_ENEMY:
			var idx: int = ev["idx"]
			var amount: int = ev["amount"]
			var hp_after: int = ev["hpAfter"]
			var view: EnemyView = _enemy_view(idx)
			if view != null:
				var e: EnemyCombatant = game.cb.enemies[idx]
				view.set_hp(hp_after, e.max_hp)
				_float_text(view, str(amount), Color(1, 0.45, 0.4))
			await _wait(0.22)
		EventTypes.HIT_PLAYER:
			var amount: int = ev["amount"]
			var hp_after: int = ev["hpAfter"]
			_player_hp.text = "HP %d / %d" % [hp_after, game.cb.player.max_hp]
			_player_hp_bar.value = maxi(0, hp_after)
			_float_text(_player_hp, str(amount), Color(1, 0.45, 0.4))
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
			var total: int = ev["total"]
			_embers_label.text = "Lantern %d / %d" % [total, game.cb.ember_cap]
			await _wait(0.08)
		EventTypes.BLOCK_GAIN:
			var who_v: Variant = ev["who"]
			var total: int = ev["total"]
			if typeof(who_v) == TYPE_STRING:
				_player_ward.text = "Ward %d" % total
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
			_float_text(_player_hp, "+%d" % n, Color(0.5, 1, 0.6))
			await _wait(0.15)
		EventTypes.TO_DISCARD, EventTypes.EXHAUST, EventTypes.POWER_CONSUMED:
			var uid: int = ev["uid"]
			_hand.remove_card(uid)
		EventTypes.KINDLE:
			var uid: int = ev["uid"]
			_hand.remove_card(uid)
			await _wait(0.2)
		EventTypes.ART:
			_float_text(_embers_label, "ART", Color(1, 0.7, 0.3))
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
			await _wait(0.3)
		EventTypes.SMOLDER_JUMP:
			await _wait(0.15)
		EventTypes.RELIC_PROC:
			_float_text(_gold_label, str(ev.get("id", "")), Color(1, 0.85, 0.5))
			await _wait(0.2)
		EventTypes.VICTORY, EventTypes.DEFEAT:
			await _wait(0.25)
		_:
			push_warning("CombatScreen: unhandled event %s" % String(t))


# ---------------------------------------------------------------- sync

func _on_busy_changed(busy: bool) -> void:
	var locked: bool = busy or game.cb == null or game.cb.over
	_end_turn.disabled = locked
	_art_button.disabled = locked
	_kindle_toggle.disabled = locked
	_hand.locked = locked
	if locked:
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
	_turn_label.text = "Turn %d" % cb.turn
	_gold_label.text = "Gold %d" % game.run.player.gold
	_player_hp.text = "HP %d / %d" % [maxi(0, cb.player.hp), cb.player.max_hp]
	_player_hp_bar.max_value = cb.player.max_hp
	_player_hp_bar.value = maxi(0, cb.player.hp)
	_player_ward.text = "Ward %d" % cb.player.block
	_embers_label.text = "Lantern %d / %d" % [cb.embers, cb.ember_cap]
	_end_turn.text = "End Turn\nEnergy %d" % cb.player.energy
	_player_statuses.sync(cb.player.statuses, game.content.statuses)
	_piles_label.text = "Draw %d\nDiscard %d\nExhaust %d" % [
		cb.draw.size(), cb.discard.size(), cb.exhaust.size()
	]
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
