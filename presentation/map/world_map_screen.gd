class_name WorldMapScreen
extends Control
## The benchmark 15×7 pilgrimage graph walking a navigable road toward the Spire.
##
## Presentation only. It reads the WorldMap graph and animates; the map's own
## `enter()` gate decides what is legal. Fully built in _init (no tree
## dependency) so headless tests can drive it — see the M5 screens.
## Paint order is child order: sky → region → path → waystones → veil → chrome
## (DL MAJOR from PR #71: Spire behind trees by construction).

signal node_chosen(index: int)
signal sealed_door_requested

const TRAVEL_TIME: float = 0.4

const HINT_PT: float = 13.0
const HINT_TOP: float = -44.0
const HINT_BOTTOM: float = -18.0

## Path/waystone PointerDrift amplitude (px); sky/region ÷3, veil ×1.35 (#64).
const PATH_DRIFT_AMP: Vector2 = Vector2(14.0, 12.0)
## Wander amplitudes in px. The two domain fields do NOT share a range —
## `domain/state/world_map.gd:134` scales `jx` by 0.5 (±0.25) and `:135` scales
## `jy` by 0.4 (**±0.20**). An earlier draft of this docstring said "about ±0.25"
## for both and the PR body then overstated the step wander by 30% (#69, PR #79
## DL R1 m3). At 72 the step axis realises ±13.8 px on seed 717, which reads as
## 5.7% of pad-landscape's 241.9 px step but **10.8% of phone-portrait's 128 px
## floor** — a ratio is a property of the shape, not of the constant, and quoting
## the roomiest one alone is how the same figure understated itself twice
## (PR #79 DL R2 n5). Both are the "~3×" the review asked for; 1.8% was before.
##
## The lane axis cannot take the same treatment: at 46–50 px of pitch it has no
## room, so it trades amplitude for the per-row application in `_row_lane_jitter`.
##
## BOTH STAY ABSOLUTE PX, which #69 grouped with `BED_HALF` as "decide once for
## all three" and only `BED_HALF` had an answer until now (PR #80 DL R1). The
## other two answer differently, and for the same reason as each other: they are
## measured against quantities that are ALREADY rate-derived. `STEP_JITTER` is
## wander within a step that is `W · stepRate` clamped, and `LANE_JITTER` within
## a pitch that is `H · laneRate` clamped — expressing either as a second rate
## would compound two ratios and make the wander grow fastest exactly where the
## floors have already said there is no room. `laneMin` is the third: a TOUCH
## floor in px by necessity, because 44 px is a finger, not a fraction of a
## stage. `BED_HALF` was the odd one out precisely because it measures nothing.
const STEP_JITTER: float = 72.0
const LANE_JITTER: float = 20.0

const REGION_NAME: String = "The Ashen Woods"
const REGION_GROUND: Color = Color("#05070d")

var instant: bool = false        # headless: travel resolves without a tween
var map: WorldMap
var content: ContentDB

## The stage shape this screen composes for, and its resolved `map` layout.
## Re-read through `_trail()` rather than cached in locals: `set_shape` swaps it
## under a live screen when the window crosses an aspect boundary.
var shape: StringName = StageShape.IDENTITY

var _cam_x: float = 0.0
var _cam_target: float = 0.0
var _cam_velocity: float = 0.0
var _dragging: bool = false
var _travelling: bool = false
## Node index the lantern leaves during a glide; −1 when seated or when the
## run starts with no prior seat (path then collapses to the target).
var _travel_from_i: int = -1
var _travel_t: float = 0.0
var _waystones: Array[GlassWaystone] = []
var _hint_label: Label
var _sealed_door: Button
var _sky_tex: GradientTexture2D
var _trail_layout: Dictionary = {}
var _title_label: Label
var _run: RunState = null
var _act: int = 0
var _sky_colour: Color
var _fog_colour: Color
var _particle_colour: Color
var _glow_colour: Color
var _accent_colour: Color
## Per-act region knobs (palette + weather + lightning). Bands read this;
## built in `_set_act_theme` so a theme pick never leaves stale weather.
var _region: MapRegions = null
## Row → lane offset in px. Built lazily and never invalidated: it derives only
## from the map's own `jx`, which is frozen for the life of the screen.
var _row_jx: Dictionary[int, float] = {}
## Act-2 heat lightning — fixed mark table, no RNG (captures must repeat).
var _lightning_t: float = 0.0
var _flash: float = 0.0

var _drift: PointerDrift = PointerDrift.new()
var _sky_band: MapBand.SkyBand = null
var _region_band: MapBand.RegionBand = null
var _path_band: MapBand.PathBand = null
var _chip_band: MapBand.ChipBand = null
var _veil_band: MapBand.VeilBand = null


func _init(world_map: WorldMap, content_ref: ContentDB,
		stage_shape: StringName = StageShape.IDENTITY) -> void:
	map = world_map
	content = content_ref
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	_trail_layout = LayoutBook.resolve(&"map", shape)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	# Bands → waystones → veil → chrome: child order is paint order.
	_build_bands()
	_build_waystones()
	# Between the stones and the weather: the chips label the play plane, so they
	# sit on it, and the veil still drifts in front of them.
	_chip_band = MapBand.ChipBand.new()
	_chip_band.host = self
	add_child(_chip_band)
	_veil_band = MapBand.VeilBand.new()
	_veil_band.host = self
	add_child(_veil_band)
	# Theme after bands exist so apply_region reaches sky + region + veil.
	_set_act_theme(0)
	_build_chrome()
	_seat_marker()
	_push_bands(true)
	set_process(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_waystones()
		_push_bands(true)


# ---------------------------------------------------------------- build

func _build_bands() -> void:
	_sky_band = MapBand.SkyBand.new()
	_sky_band.host = self
	add_child(_sky_band)
	_region_band = MapBand.RegionBand.new()
	_region_band.host = self
	add_child(_region_band)
	_path_band = MapBand.PathBand.new()
	_path_band.host = self
	add_child(_path_band)


func _build_chrome() -> void:
	_title_label = Label.new()
	_title_label.text = REGION_NAME.to_upper()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# A backstop, not the plan. `_act_line` measures and shortens so the text
	# fits one row; this catches the case it cannot fix — a region name that is
	# on its own too wide, which a translation could produce — by wrapping
	# rather than clipping the player's own location off the edge.
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title_label.offset_top = 38.0
	_title_label.offset_bottom = 66.0
	_title_label.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0, 0.92))
	_title_label.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 3))
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)

	_hint_label = Label.new()
	_hint_label.text = Locale.active.t("ui.pilgrimage.survey")
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_label)
	_build_sealed_door()
	_scale_chrome()


## Overlay button, not a map node — styles.css:2536. Hidden until refresh
## sees the final act with six Shards.
func _build_sealed_door() -> void:
	_sealed_door = Button.new()
	_sealed_door.visible = false
	_sealed_door.z_index = 5
	_sealed_door.custom_minimum_size = Vector2(116, 74)
	_sealed_door.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_sealed_door.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sealed_door.offset_left = -58.0
	_sealed_door.offset_right = 58.0
	_sealed_door.offset_top = 67.0
	_sealed_door.offset_bottom = 141.0
	_sealed_door.tooltip_text = Locale.active.t("ui.map.sealedDoor.aria")
	_style_sealed_door(_sealed_door)
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sealed_door.add_child(col)
	var glyph: DawnScreen.DawnGlyph = DawnScreen.DawnGlyph.new("door")
	glyph.custom_minimum_size = Vector2(42, 42)
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(glyph)
	var caption: Label = Label.new()
	caption.text = Locale.active.t("ui.map.sealedDoor.label")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 1))
	caption.add_theme_font_size_override("font_size", 8)
	caption.add_theme_color_override("font_color", Color("#fff3d6"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(caption)
	_sealed_door.pressed.connect(func() -> void: sealed_door_requested.emit())
	add_child(_sealed_door)


func _style_sealed_door(button: Button) -> void:
	# Arch plate: 48% 48% 12px 12px, parchment rim, night fill (styles.css:2537).
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.02, 0.024, 0.047, 0.9)
		style.set_border_width_all(1)
		style.border_color = Color(1.0, 0.914, 0.675, 0.82 if state == "hover" else 0.55)
		style.corner_radius_top_left = 48
		style.corner_radius_top_right = 48
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.set_content_margin_all(7)
		style.shadow_color = Color(1.0, 0.914, 0.675, 0.2)
		style.shadow_size = 24
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("focus",
		GlassStyle.focus_ring(Color("#ffe9ac"), 12))


## Every rail figure at once, so a shape change is one call rather than a tour of
## the builder. Separated from `_build_chrome` for exactly that reason: the
## builder runs once and this runs again on every re-pick.
func _scale_chrome() -> void:
	var k: float = _bar_num("scale", 1.0)
	# The act line, switched by the book rather than always drawn.
	#
	# `mapbar/title` was authored for the case where a title has no room and
	# should go rather than shrink. It went unread for one afternoon and the case
	# arrived from the other direction: the Spire rail now carries the act, the
	# floor and the boss, so this label says the same thing a second time. At the
	# identity shape that is only redundant. On a phone held upright it is clipped
	# at the right edge, and held sideways it is drawn straight over the top row
	# of waystones.
	#
	# Off in `base`, because the rail's line is strictly the longer of the two —
	# it carries the floor number as well — so nothing is lost. Bringing it back
	# is one value in the book, not a code change, which is the point of the
	# field existing.
	_title_label.visible = _bar_num("title", 1.0) >= 1.0
	_title_label.add_theme_font_size_override("font_size", roundi(15.0 * k))
	# Three shape names spelled out in ternaries were a layout table living
	# outside the book — the same species the `map` scope was opened to collect,
	# and one the editor cannot see or revert. The figures are unchanged.
	var title_top: float = _bar_num("titleTop", 62.0)
	var inset: float = _bar_num("titleInset", 0.0)
	_title_label.offset_top = title_top
	_title_label.offset_bottom = title_top + _bar_num("titleH", 26.0)
	_title_label.offset_left = inset
	_title_label.offset_right = -inset
	_hint_label.add_theme_font_size_override("font_size", roundi(HINT_PT * k))
	_hint_label.offset_top = HINT_TOP * k
	_hint_label.offset_bottom = HINT_BOTTOM * k
	# Web seats the door at 104px from the map-screen top (styles.css:2542).
	# The act line lives on this Control, so when it is on, sit just under it.
	var door_top: float = 67.0
	if _title_label.visible:
		door_top = _title_label.offset_bottom + 8.0
	_sealed_door.offset_top = door_top
	_sealed_door.offset_bottom = door_top + 74.0


func _build_waystones() -> void:
	for i: int in range(map.nodes.size()):
		var n: MapNode = map.nodes[i]
		var shown_kind: String = "unlit" if n.unlit else n.type
		var caption: String = Locale.active.t("ui.pilgrimage.unlitWay") \
			if n.unlit else _node_caption(n)
		var ws: GlassWaystone = GlassWaystone.new(
			i, shown_kind, _node_hue(n), caption, n.quest_marked,
			n.bounty if n.unlit else 0)
		ws.chosen.connect(_on_waystone_chosen)
		add_child(ws)
		_waystones.append(ws)


## Creature nodes wear their enemy's hue (sporeling green, duskfang violet …);
## the rest node is always lantern-amber.
func _node_hue(n: MapNode) -> float:
	if n.enemies.is_empty():
		return 30.0
	var def: Dictionary = content.enemies.get(n.enemies[0], {})
	var art: Dictionary = def.get("art", {})
	var hue_num: int = art.get("hue", 210)  # JSON floats land whole; the combat screen reads it the same way
	return float(hue_num)


func _node_caption(n: MapNode) -> String:
	if n.type == "rest":
		return Locale.active.t("ui.pilgrimage.hearth")
	if n.enemies.is_empty():
		var node_key: String = "ui.map.node.%s" % n.type
		var localized: String = Locale.active.t(node_key)
		return localized if localized != node_key else n.type.capitalize()
	var def: Dictionary = content.enemies.get(n.enemies[0], {})
	var label: String = str(def.get("name", n.enemies[0]))
	if n.enemies.size() > 1:
		label += " ×%d" % n.enemies.size()
	return label


# ---------------------------------------------------------------- state

## The act line, as long as the box can hold on ONE row.
##
## Where the player is beats who is waiting for them, so the region name is
## never dropped and the boss clause is what goes. Measured against the font
## rather than authored per shape: a threshold with a shape name on it is the
## thing this scope exists to abolish, and a measurement cannot be wrong on a
## shape nobody thought to author.
##
## Wrapping to two rows was the other option and it was worse — the second row
## lands on the top waystone row, which on a phone held upright is the row
## nearest the player's thumb.
func _act_line(region: String, boss: String) -> String:
	var full: String = Locale.active.t("ui.pilgrimage.awaits", {
		"region": region, "boss": boss,
	})
	var font: Font = _title_label.get_theme_font("font")
	var pt: int = _title_label.get_theme_font_size("font_size")
	# The shape's reference width, never this Control's, because the first
	# `refresh` runs before any layout pass and `size.x` is still zero there. A
	# stage never goes below its reference, so clamping up to it is the honest
	# reading of a zero rather than a fallback — the same rule `CombatScreen.
	# _layout` states.
	var ref: Vector2i = StageShape.REFERENCES.get(shape,
		StageShape.REFERENCES[StageShape.IDENTITY])
	var box: float = maxf(float(ref.x), size.x) - _bar_num("titleInset", 0.0) * 2.0
	if box <= 0.0 or font == null:
		return full
	return full if font.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		pt).x <= box else region


## Re-seat and re-light after a run change or a return from combat.
func refresh(run: RunState) -> void:
	if run != null:
		_run = run
		_set_act_theme(run.act)
		var act: Dictionary = content.acts[_act]
		var act_name: String = Locale.active.t("ui.pilgrimage.roseWindow") \
			if map.region == "rose_window" \
			else str(act.get("name", REGION_NAME))
		_title_label.text = _act_line(act_name.to_upper(),
			str(act.get("bossName", Locale.active.t("ui.pilgrimage.summit"))).to_upper())
	var live: Array[int] = map.reachable()
	var first_live: GlassWaystone = null
	for i: int in range(_waystones.size()):
		_waystones[i].set_state(live.has(i), map.is_cleared(i), i == map.at)
		if first_live == null and live.has(i):
			first_live = _waystones[i]
	if live.is_empty():
		_hint_label.text = Locale.active.t("ui.pilgrimage.roadEnds")
	else:
		_hint_label.text = Locale.active.t("ui.pilgrimage.surveyChoose")
		if first_live != null and first_live.is_inside_tree():
			first_live.grab_focus()
	_seat_marker()
	_push_bands(true)
	_sync_sealed_door(run)


func _sync_sealed_door(run: RunState) -> void:
	# The door fronts the final act: it stands on the last ordinary map
	# (act == final_act() - 1), not inside the act it opens.
	_sealed_door.visible = run != null and run.shards.size() >= 6 \
		and run.act + 1 == run.final_act()


func _set_act_theme(stage_act: int) -> void:
	_region = MapRegions.for_act(stage_act, content)
	_act = _region.act
	# Palette fields keep their names — bands already read them. Content
	# theme is truth; MapRegions.FALLBACK_* only fills a missing key.
	_sky_colour = _region.sky
	_fog_colour = _region.fog
	_particle_colour = _region.particles
	_glow_colour = _region.glow
	_accent_colour = _region.accent
	_sky_tex = GlassStyle.grad_tex(
		PackedColorArray([_sky_colour, _fog_colour, REGION_GROUND]),
		PackedFloat32Array([0.0, 0.55, 1.0]), false,
		Vector2(0.5, 0.0), Vector2(0.5, 1.0))
	# Lightning clock resets with the region so --act=2 always starts cold.
	_lightning_t = 0.0
	_flash = 0.0
	if _sky_band != null:
		_sky_band.apply_region(_region)
		_sky_band.set_flash(0.0)
	if _region_band != null:
		_region_band.apply_region(_region)
		_region_band.set_flash(0.0)
	if _veil_band != null:
		_veil_band.apply_region(_region)


## Dress the bands in another act's region without mutating the run. Used by
## `--map --act=N` so captures can see act 1/2 weather without climbing there —
## domain map generation stays the run's act (scenery only).
func set_act_scenery(stage_act: int) -> void:
	_set_act_theme(stage_act)
	if content != null and _act < content.acts.size() and _title_label != null:
		var act: Dictionary = content.acts[_act]
		_title_label.text = _act_line(
			str(act.get("name", REGION_NAME)).to_upper(),
			str(act.get("bossName", Locale.active.t("ui.pilgrimage.summit"))).to_upper())
	_push_bands(true)


## Put the camera where the marker's node sits. Called on every `refresh`, which
## `set_shape` also routes through — and a shape re-pick can land mid-glide, when
## a snap would tear the walk out from under the lantern. Re-aim instead: the
## destination is re-derived at the NEW geometry (`_cam_for` reads `_step` and
## `_cam_max`, both shape-dependent) while `_cam_x` keeps easing, so the glide
## finishes at the right place on the new stage (#69 B2, the other door into the
## state PR #79 closed against input).
func _seat_marker() -> void:
	var i: int = map.at if map.at >= 0 and map.at < map.nodes.size() else 0
	var seat: float = _cam_for(i) if not map.nodes.is_empty() else _cam_min()
	_cam_target = seat
	# Kill the fling either way. `_process` drives `_cam_x` from `_cam_velocity`
	# while it lives and overwrites `_cam_target` doing it, so an early return
	# that left a fling running would discard the very re-aim it exists to make
	# (PR #80 DL R1).
	_cam_velocity = 0.0
	if _travelling:
		return
	_cam_x = seat


## World-x of the lead-third seating for node `i`, clamped so node 0 cannot
## underscroll and the terminus keeps act sky to its right.
func _cam_for(i: int) -> float:
	if i < 0 or i >= map.nodes.size():
		return _cam_min()
	return clampf(_world_x(float(map.nodes[i].row)), _cam_min(), _cam_max())


func _cam_min() -> float:
	# Node 0's screen x == lead·W at the floor: with
	# `screen = world − cam + lead·W`, that floor is zero — not `−lead·W`,
	# which would let the map underscroll past the entry seat.
	return 0.0


func _cam_max() -> float:
	# The terminus does NOT get the entry seat. At `_world_x(ROWS − 1)` the boss
	# lands at exactly `lead·W` — the same spot node 0 occupies on the opening
	# frame — leaving 67% of the stage as empty road ahead of it, which reads as
	# a journey that has not finished (#69, carried from P5.1 DL R2). Stopping
	# the camera short seats it at `terminusSeat` of the stage instead, keeping
	# §3's act sky beyond without the frame looking unspent.
	#
	# Mind the sign: a LARGER `_cam_max` moves the terminus LEFT, so arriving
	# further right means stopping EARLIER. Clamped against `_cam_min` so a
	# stage narrower than the shortfall cannot invert the range.
	var last: float = _world_x(float(WorldMap.ROWS - 1))
	var seat: float = size.x * _trail_num("terminusSeat", 0.72)
	return maxf(last - (seat - _lead_px()), _cam_min())


func _on_waystone_chosen(i: int) -> void:
	choose(i)


## Glide the lantern to node `i`, then hand off. False = not selectable now.
## Capture departure BEFORE enter() — that call mutates map.at immediately.
## Unlit is NOT cleared here: main pays the bounty and flips `n.unlit` only
## after node_chosen, so the ceremony covers the same-screen window between
## click and route swap.
func choose(i: int) -> bool:
	var from_i: int = map.at
	var was_unlit: bool = map.nodes[i].unlit
	if _travelling or not map.enter(i):
		return false
	for ws: GlassWaystone in _waystones:
		ws.set_state(false, ws.cleared)  # travel locks the road
	if instant:
		node_chosen.emit(i)
		return true
	_travel_from_i = from_i
	_travel_t = 0.0
	_travelling = true
	# The only instruction on screen names three things the walk has just taken
	# away — scroll, drag and choose are all refused for its duration. Half alpha
	# says "not now" without the label vanishing and re-appearing (PR #79 DL R1).
	_hint_label.modulate.a = 0.4
	_cam_target = _cam_for(i)
	# Reduce-motion skips the walk but still arrives through one path so the
	# travelling flag clears the same way a tween finish would. No kindle
	# ceremony — art corrects on the next _show_map rebuild, as today.
	if Preferences.active.reduce_motion:
		_cam_x = _cam_target
		_on_arrived(i)
		return true
	if was_unlit:
		_waystones[i].kindle_reveal(map.nodes[i].type)
	# Hold the glide so the 0.45s bloom lands before the route swap.
	var dur: float = maxf(TRAVEL_TIME, 0.5) if was_unlit else TRAVEL_TIME
	Motion.bez(self, _set_travel_t, dur, Motion.CSS_EASE) \
		.finished.connect(_on_arrived.bind(i))
	return true


func _set_travel_t(v: float) -> void:
	_travel_t = v
	# Camera lerp already forces band redraws; force the path so the glow
	# tracks even if cam and drift happen to sit still for a frame.
	var path_d: Vector2 = Vector2(
		_drift.n.x * PATH_DRIFT_AMP.x, _drift.n.y * PATH_DRIFT_AMP.y)
	_path_band.set_view(_cam_x, path_d, true)


func _on_arrived(i: int) -> void:
	_travelling = false
	_travel_from_i = -1
	_hint_label.modulate.a = 1.0
	node_chosen.emit(i)


## The one control point for a trail edge, shared by the drawn dashes
## (`MapBand.PathBand._draw_graph`) and by the marker gliding along them.
##
## Rising bows up, falling bows down so crossing paths pull apart rather than
## stacking, SCALED by how far the edge actually climbs — a same-lane run is then
## straight by construction. It used to be `signf(to.y - from.y) * 10.0`, which
## is 0 only on an exact tie, and `node.jx * 6.0` jitter guarantees no tie, so
## every "straight" edge took the full bow off a sub-pixel difference (#69).
##
## It lives here, in one place, because the same expression written twice is how
## it went wrong: the marker's copy kept the old `signf` through the first draft
## of that fix while its comment claimed it was "the same control the PathBand
## edges use" (PR #78 PM R1). One function cannot disagree with itself.
func edge_control(from: Vector2, to: Vector2) -> Vector2:
	var climb: float = clampf((to.y - from.y) / maxf(_lane_gap(), 1.0), -1.0, 1.0)
	return (from + to) * 0.5 + Vector2(0.0, climb * 10.0)


## The glow's live screen point — bezier mid-glide, seated otherwise, stage
## centre before any node. Recomputed each call so cam/drift stay coherent.
func marker_screen_position() -> Vector2:
	if map.at < 0 or map.at >= map.nodes.size():
		return size * 0.5
	var to: Vector2 = _node_pos(map.nodes[map.at])
	if not _travelling or _travel_from_i < 0 \
			or _travel_from_i >= map.nodes.size():
		return to
	var from: Vector2 = _node_pos(map.nodes[_travel_from_i])
	var control: Vector2 = edge_control(from, to)
	var t: float = _travel_t
	var u: float = 1.0 - t
	return from * u * u + control * 2.0 * u * t + to * t * t


# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
	if not _dragging:
		if absf(_cam_velocity) > 0.02:
			_cam_x = clampf(_cam_x + _cam_velocity * delta, _cam_min(), _cam_max())
			_cam_target = _cam_x
			_cam_velocity *= pow(0.06, delta)
		else:
			_cam_velocity = 0.0
			_cam_x = lerpf(_cam_x, _cam_target, minf(1.0, delta * 9.0))
	# Scroll and pointer chase are user-initiated — PointerDrift settles home
	# off-stage; no second reduce-motion gate (P5.1 / P1).
	_drift.step(self, delta)
	_step_lightning(delta)
	_layout_waystones()
	_push_bands()


## Deterministic heat lightning for act 2. Fixed marks in a 26s loop — irregular
## enough to read as weather, fixed so two runs film the same sky. Under
## reduce-motion no flash ever fires (same single gate as weather/sway).
func _step_lightning(delta: float) -> void:
	if _region == null or _region.weather != &"storm":
		if _flash > 0.0:
			_flash = 0.0
			if _sky_band != null:
				_sky_band.set_flash(0.0)
			if _region_band != null:
				_region_band.set_flash(0.0)
		return
	if Preferences.active.reduce_motion:
		if _flash > 0.0:
			_flash = 0.0
			if _sky_band != null:
				_sky_band.set_flash(0.0)
			if _region_band != null:
				_region_band.set_flash(0.0)
		return
	var prev_t: float = _lightning_t
	_lightning_t += delta
	for mark: float in MapRegions.LIGHTNING_MARKS:
		if prev_t < mark and _lightning_t >= mark:
			_flash = 1.0
	if _lightning_t >= MapRegions.LIGHTNING_PERIOD:
		_lightning_t = fmod(_lightning_t, MapRegions.LIGHTNING_PERIOD)
	# Combat sky's own decay (presentation/combat/sky_field.gd LIGHTNING_DECAY).
	if _flash > 0.0:
		_flash *= pow(MapRegions.LIGHTNING_DECAY, delta)
		if _flash < 0.001:
			_flash = 0.0
	if _sky_band != null:
		_sky_band.set_flash(_flash)
	if _region_band != null:
		_region_band.set_flash(_flash)


func _push_bands(force: bool = false) -> void:
	var path_d: Vector2 = Vector2(
		_drift.n.x * PATH_DRIFT_AMP.x, _drift.n.y * PATH_DRIFT_AMP.y)
	var far_d: Vector2 = path_d / 3.0
	_sky_band.set_view(_cam_x, far_d, force)
	_region_band.set_view(_cam_x, far_d, force)
	_path_band.set_view(_cam_x, path_d, force)
	# Ungated: it reads the waystones' own positions, which relayout every frame.
	if _chip_band != null:
		_chip_band.set_view(_cam_x, path_d, force)
	_veil_band.set_view(_cam_x, path_d * 1.35, force)


func _gui_input(event: InputEvent) -> void:
	# The walk owns the camera while it lasts: PAN AND WHEEL are swallowed. A drag
	# or a wheel tick mid-glide used to overwrite `_cam_target`, so the lead-third
	# follow stopped and the lantern finished its bezier somewhere off-frame while
	# the glow kept riding the trail (#69, carried from P5.3 PM R1).
	#
	# This does NOT guard against a stray tap reaching a waystone, whatever an
	# earlier draft of this comment claimed. Godot delivers `_gui_input` to the
	# deepest control first and `GlassWaystone` keeps the default
	# `MOUSE_FILTER_STOP`, so a press over a stone is consumed there and never
	# arrives here. What stops the wrong move is `choose()`'s own `if _travelling`
	# — which predates this guard — plus `set_state(false, …)` unlighting every
	# stone for the duration (PR #79 DL R1 m4).
	if _travelling:
		accept_event()
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		if button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and button.pressed:
			var step: float = _step()
			_cam_target = clampf(_cam_target + (
				0.9 * step if button.button_index == MOUSE_BUTTON_WHEEL_UP else -0.9 * step),
				_cam_min(), _cam_max())
			_cam_velocity = 0.0
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
			if button.pressed:
				_cam_velocity = 0.0
			accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _dragging:
		_pan(motion.relative.x, motion.velocity.x)
		accept_event()
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		_dragging = touch.pressed
		if touch.pressed:
			_cam_velocity = 0.0
		accept_event()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and _dragging:
		_pan(drag.relative.x, drag.velocity.x)
		accept_event()


## Content follows the finger: drag left advances the view right, same
## convention the vertical map used when drag-down showed higher rows.
func _pan(delta_x: float, velocity_x: float) -> void:
	var step: float = _step()
	_cam_x = clampf(_cam_x - delta_x, _cam_min(), _cam_max())
	_cam_target = _cam_x
	_cam_velocity = clampf(-velocity_x, -8.0 * step, 8.0 * step)


## The `map` scope's own numbers. `bar` hangs off it as a sub-dict.
func _trail_num(field: String, fallback: float = 0.0) -> float:
	return LayoutBook.num(_trail_layout.get(field), fallback)


func _bar_num(field: String, fallback: float = 0.0) -> float:
	return LayoutBook.num(_trail_layout.get("bar", {}).get(field), fallback)


## Follow a re-pick without being rebuilt. Safe here in a way it is not on the
## combat screen: nothing on this screen is mid-flight except the travel tween,
## and a waystone carries no state a re-seat would lose.
func set_shape(stage_shape: StringName) -> void:
	if stage_shape == shape or not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	_trail_layout = LayoutBook.resolve(&"map", shape)
	_scale_chrome()
	if _run != null:
		refresh(_run)
	_layout_waystones()
	_push_bands(true)


func _layout_waystones() -> void:
	var k: float = _trail_num("scale", 0.36)
	var touch: float = _trail_num("touch", 0.0)
	for i: int in range(_waystones.size()):
		var ws: GlassWaystone = _waystones[i]
		var depth: float = depth_of(_world_x(float(map.nodes[i].row)))
		# Both falloffs are anchored at the NEAREST stone, not past it. They used
		# to peak at 1.08 and 1.15, so `scale` reached its nominal `k` only at
		# depth 2.29 and alpha stayed pinned at 1.0 until depth 1.25 — everything
		# closer was drawn oversized, and a third of the visible range carried no
		# alpha cue at all (#69, carried from P5.1 DL R2). Anchoring at 1.0 makes
		# `k` mean what the book says and gives every visible step a distinct
		# depth reading.
		var node_scale: float = k * depth_scale(depth)
		ws.scale = Vector2.ONE * node_scale
		ws.set_depth_alpha(clampf(1.0 - depth * 0.10, 0.12, 1.0))
		# Before the seat, not after: the pad changes `size`, and the seat is
		# computed from it. The drawing sits in the middle of the padded rect,
		# so centring the rect still centres the stone.
		ws.set_touch_min(touch, node_scale)
		ws.position = _node_pos(map.nodes[i]) - ws.size * node_scale * 0.5


## Where a node sits: row → walk axis (X), col → lane (Y).
##
## The camera holds the tracked world-x at the lead-third of the frame, so
## `screen_x = world_x − cam_x + lead·W`. The wander budget follows the room
## each axis has — step has 150–290px, lane only 46–50. PointerDrift at the
## path amplitude keeps the stones on the path plane's lean.
func _node_pos(node: MapNode) -> Vector2:
	var world_x: float = _world_x(float(node.row))
	var depth: float = depth_of(world_x)
	var lane_gap: float = lane_pitch(depth)
	var d: Vector2 = Vector2(
		_drift.n.x * PATH_DRIFT_AMP.x, _drift.n.y * PATH_DRIFT_AMP.y)
	return Vector2(
		world_x - _cam_x + _lead_px() + node.jy * STEP_JITTER + d.x,
		size.y * _trail_num("pathY", 0.64) + float(node.col - 3) * lane_gap \
			+ _row_lane_jitter(node.row) + d.y,
	)


## Lane wander, applied per ROW rather than per node.
##
## Per-node jitter breaks the touch floor it sits under: `laneMin` guarantees the
## PITCH, but a thumb hits a GAP, and two neighbours can jitter toward each other.
## Measured over the 33 pairs that actually sit in adjacent lanes on seed 717,
## with the lane gap at the phone-landscape value where it rests on its floor:
## at the old ±6 px, three pairs were already under the 44 px touch rect (worst
## 43.06); the carried "~3× the jitter" ask would have made it nine (worst 37.18).
##
## Shifting the whole column by one amount preserves every gap inside it exactly
## while still setting rows at different heights, which is the lattice-breaking
## the note actually wanted. The offset is domain-derived and deterministic —
## presentation reads `jx` differently, it does not invent any (#69).
##
## It takes the LOWEST-col node's `jx` as the row's representative, and the
## choice matters: the row's MEAN was the first thing I tried, and averaging four
## to six values that span ±0.25 regresses to nothing. Measured on seed 717, the
## mean gave a total span of −3.14…+1.20 px with most rows inside ±0.8 — LESS
## lane variation than the ±1.5 px per-node jitter it replaced, i.e. the exact
## opposite of the intent. A single member keeps the full amplitude.
func _row_lane_jitter(row: int) -> float:
	if _row_jx.has(row):
		return _row_jx[row]
	var pick: MapNode = null
	for n: MapNode in map.nodes:
		if n.row == row and (pick == null or n.col < pick.col):
			pick = n
	var offset: float = 0.0 if pick == null else pick.jx * LANE_JITTER
	_row_jx[row] = offset
	return offset


## How far apart two steps of the pilgrimage stand, in stage px.
##
## The rate keeps the same NUMBER of nodes on screen as the stage grows; the
## band stops a phone held sideways from packing them into each other. It
## replaced the vertical Spire's `rowRate`/`rowMin`/`rowMax`.
func _step() -> float:
	return clampf(size.x * _trail_num("stepRate", 0.22),
		_trail_num("stepMin", 150.0), _trail_num("stepMax", 290.0))


## Lane spacing across the path. Col 3 is centre; depth-compress lives at the
## call site so scale/alpha falloff can share the same depth reading.
func _lane_gap() -> float:
	return clampf(size.y * _trail_num("laneRate", 0.06),
		_trail_num("laneMin", 46.0), _trail_num("laneMax", 50.0))


func _world_x(row: float) -> float:
	return row * _step()


func _lead_px() -> float:
	return _trail_num("lead", 0.333) * size.x


## Distance between two lanes at `depth` steps from the camera, in stage px.
##
## `laneMin` is a TOUCH floor, so depth compression is not allowed to multiply it
## away: 46 × 0.78 = 35.9 px, under the 44 px rect `set_touch_min` exists to
## guarantee. Depth compresses while there is room and stops at the floor (#69,
## carried from P5.1 DL R2). Named rather than inlined because #69 D1 asked
## whether the bounty chip could be seated against it — it cannot, and the
## answer is recorded at `GlassWaystone.paint_bounty_chip`.
func lane_pitch(depth: float) -> float:
	return maxf(_lane_gap() * clampf(1.0 - depth * 0.025, 0.78, 1.0),
		_trail_num("laneMin", 46.0))


## The map's ONE depth projection: how far a world point sits from the camera,
## in steps. Every depth curve on this map reads from here — stone size and
## alpha (`_layout_waystones`), lane compression (`lane_pitch`), the terminus
## arch (`MapBand.PathBand._draw_rose_window`) and the road's taper (`bed_half`).
##
## It is a function rather than the one-line expression it replaces because the
## expression had been written out three times, and this map has twice paid for
## a second copy of one geometry going stale — the arch's radius (PR #79 PM R1)
## and `BED_HALF` (#69 C5). PR #84 PM R1 caught the third.
func depth_of(world_x: float) -> float:
	return absf(world_x - _cam_x) / maxf(_step(), 1.0)


## The same projection read at a point on the STAGE, for the GROUND PLANE.
##
## A node's screen x is `world_x − cam_x + lead·W + jy·STEP_JITTER + drift.x`, so
## dropping the last two terms and inverting gives `world_x = screen_x − lead·W
## + cam_x` — which is what this passes to `depth_of`. It is one function, not an
## identity to be maintained.
##
## **The two dropped terms are why this must not be fed a stone's screen x.** The
## ground does not jitter and does not lean, so for the road they are correctly
## absent; but a stone carries up to `STEP_JITTER + PATH_DRIFT_AMP.x` of them,
## and reading a stone's depth from its drawn position would disagree with the
## depth it was drawn AT. Stones pass their world x to `depth_of` directly
## (PR #84 PM R1).
func depth_at(screen_x: float) -> float:
	return depth_of(screen_x - _lead_px() + _cam_x)


## Half-height of the road bed at a point on the stage, in stage px.
##
## Rate-derived, which is the question #69 C5 recorded and handed here: the 8 px
## constant it replaces was 0.98% of a 820-tall stage and 2.05% of a 390-tall
## one, so the same road read twice as wide on the SHORTEST shape (390 px tall;
## this said "narrowest" until PR #84 DL R3 — 390 is its height). The default
## rate reproduces 8.04 px at 820, where the constant was tuned, and the clamps
## stop a very short or very tall stage from collapsing or flooding it.
##
## **Improved, not settled** — the word was `LayoutBook`'s, on the `trail/bedRate`
## field declaration, and PR #84 DL R1 m3 was right that leaving it there is how
## the same arithmetic gets re-litigated in six weeks. (DL R2 then caught that
## this paragraph was written as though the word had been here: it never was.
## It is retired at its own site and that field now points back to this one.)
## What the change actually bought, measured over the shape matrix:
##
##   phone-portrait      8.27   0.980% of stage H   16.5% of lane pitch
##   pad-portrait       10.00   0.847%  (bedMax)    20.0%
##   pad-landscape       8.04   0.980%              16.3%
##   desktop-landscape   8.04   0.980%              16.3%
##   phone-landscape     6.00   1.538%  (bedMin)    13.0%
##
## Against stage height the spread falls from 3.03× to 1.82× and three shapes
## land exactly on 0.980%. But **the clamps bind at two of the five**, and the
## 390-tall stage that motivated deleting the constant is still 1.57× wider in
## proportion than the reference — `bedMin` floors it at 6.0 where the rate wants
## 3.82, so the excess over what the rate asks for falls from 4.18 px to 2.18,
## **48% of it removed, not all**. (That figure read 40% until PR #84 DL R2:
## 40% is the SPREAD's improvement, 3.03× → 1.82×, two sentences above — a
## number borrowed from the wrong row of the same paragraph.)
##
## And the honest counter-argument, which belongs next to the change rather than
## in a review thread: measured against LANE PITCH — the only other vertical
## rhythm on this plane — the rate is *less* consistent than the constant was.
## `_lane_gap` clamps to 46–50, so lanes vary 8.7% across a 3.03× range of stage
## heights; bed-to-lane was 16.0–17.4% (1.09×) under `BED_HALF` and is now
## 13.0–20.0% (1.53×). The book has already decided that vertical spacing here is
## effectively absolute px, and the road is now measured against a different
## ruler from the lanes it runs between. Stage-relative is defensible and
## phone-portrait — the shape the whole question came from — is now exactly
## right; but if this is ever revisited, `laneMin`/`laneMax` are the precedent
## pointing the other way.
func bed_half(screen_x: float) -> float:
	return clampf(size.y * _trail_num("bedRate", 0.0098),
		_trail_num("bedMin", 6.0), _trail_num("bedMax", 10.0)) \
		* bed_taper(depth_at(screen_x))


## The road's taper — the FIFTH depth curve on this map, and it is not the
## stones' 0.035 for a measurable reason rather than a stylistic one.
##
## The stones sample depth at their own columns, spread over many steps, so
## 0.035 accumulates across the whole walk. The bed is drawn continuously across
## ONE frame, where the visible depth range is only about 0 to 3.3 steps, and the
## stones' coefficient narrows it by 11% edge to edge — a rectangle with a
## gradient, not a road.
##
## 0.18 was picked by measuring on the running map at pad-landscape, seed 717,
## and then re-measured independently by PR #84 DL R1, which isolated the road
## by differencing a 12-frame median against the same frames rendered with the
## bed's alpha at zero (off-road residual 0.18 luma). Their figures, seat →
## right edge: 0.12 gives 7.40 → 5.10 px (**31%**), 0.18 gives 6.85 → 3.45
## (**50%**), 0.24 gives 6.95 → 3.40 (**51%**).
##
## **The argument for 0.18 is not that 50% beats 31% — it is that 0.24 buys
## nothing.** At 0.24 the `0.40` floor below engages at depth 2.5, i.e. x ≈ 998
## on an 1180 stage, so the far sixth of the frame stops tapering entirely
## (3.45 px at x = 1050, 3.40 at x = 1150 — flat) and the road ends in a blunt
## stub exactly where recession should read strongest. At 0.18 the floor lands
## at x ≈ 1199, just past the reference frame. **0.18 is the largest coefficient
## whose taper stays live to the right edge at the reference shape**, which also
## means raising it requires revisiting the floor, not just this constant.
## (On desktop-landscape, 1458 wide, the floor does clip the final 5.8 px even
## at 0.18 — sub-pixel and non-degenerate, PR #84 PM R1.)
##
## Crown lift over the ground measures 15.2 luma (p5 14.4, p95 16.3) and is
## identical at phone-portrait and phone-landscape, against dashes at 36–63,
## stones at 159 and the marker at 208 — the road must not compete with the play
## plane (#66/#67). Worth knowing before anyone tunes this again: at those alphas
## 0.12, 0.18 and 0.24 are close to indistinguishable in the far third. The
## width gradient reads as atmosphere, not as measurement.
##
## The other four are named in `depth_scale`'s docstring; this one belongs with
## them.
static func bed_taper(depth: float) -> float:
	return clampf(1.0 - depth * 0.18, 0.40, 1.0)


## How far a stone shrinks at `depth` steps from the camera. Anchored at 1.0, so
## the nearest stone draws at exactly the book's `scale`.
##
## The map runs FIVE distinct depth curves, and a review round was spent on the
## belief that it ran three — so they are named here once: this one (0.035) for
## stone and arch size, `0.10` for stone alpha in `_layout_waystones`, `0.025`
## for lane compression in `_node_pos`, `0.12` for edge fade in
## `MapBand.PathBand._draw_graph`, and `bed_taper`'s `0.18` for the road plane —
## the steepest of the five, and the reason it is not this one is measured in its
## docstring. All five anchor at 1.0 (PR #79 PM R2, extended by #70).
##
## This is the only one with two call sites, which is why it is a function: the
## arch used to carry a copy, and the copy went stale for a commit.
static func depth_scale(depth: float) -> float:
	return clampf(1.0 - depth * 0.035, 0.72, 1.0)


## Radius of the terminus arch at a given boss depth, in stage px.
##
## `stage_h` is the drawing band's height rather than this screen's, because the
## band is what clips it; the two are equal by `PRESET_FULL_RECT` and the
## parameter keeps that an argument instead of an assumption. The cap exists
## because a fixed 110 px broke phone-landscape at 61% of the stage's height.
func arch_radius(depth: float, stage_h: float) -> float:
	var k: float = _trail_num("scale", 0.36)
	return minf(110.0 * (k / 0.6) * depth_scale(depth), stage_h * 0.22)


## The boss's depth once the camera has run out of map — the terminus frame the
## arch is composed for. Derived from `_cam_max()` itself, not modelled from the
## seat, so it cannot disagree with where the camera actually stops.
func terminus_depth() -> float:
	return absf(_world_x(float(WorldMap.ROWS - 1)) - _cam_max()) / maxf(_step(), 1.0)
