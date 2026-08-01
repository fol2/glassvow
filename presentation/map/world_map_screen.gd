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

const TRAVEL_TIME: float = 0.4

const HINT_PT: float = 13.0
const HINT_TOP: float = -44.0
const HINT_BOTTOM: float = -18.0

## Path/waystone PointerDrift amplitude (px); sky/region ÷3, veil ×1.35 (#64).
const PATH_DRIFT_AMP: Vector2 = Vector2(14.0, 12.0)

const REGION_NAME: String = "The Ashen Woods"
const ACT_SKIES: Array[Color] = [Color("#0c1410"), Color("#081420"), Color("#120a1e")]
const ACT_FOGS: Array[Color] = [Color("#13241a"), Color("#0d2233"), Color("#1e1230")]
const ACT_PARTICLES: Array[Color] = [Color("#ffa04d"), Color("#53e8ff"), Color("#c27bff")]
const ACT_GLOWS: Array[Color] = [Color("#66ff9e"), Color("#2fb8ff"), Color("#ff4fd8")]
const ACT_ACCENTS: Array[Color] = [Color("#7ddb8f"), Color("#5fd6e8"), Color("#c99aff")]
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

var _drift: PointerDrift = PointerDrift.new()
var _sky_band: MapBand.SkyBand = null
var _region_band: MapBand.RegionBand = null
var _path_band: MapBand.PathBand = null
var _veil_band: MapBand.VeilBand = null


func _init(world_map: WorldMap, content_ref: ContentDB,
		stage_shape: StringName = StageShape.IDENTITY) -> void:
	map = world_map
	content = content_ref
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	_trail_layout = LayoutBook.resolve(&"map", shape)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	_set_act_theme(0)
	# Bands → waystones → veil → chrome: child order is paint order.
	_build_bands()
	_build_waystones()
	_veil_band = MapBand.VeilBand.new()
	_veil_band.host = self
	add_child(_veil_band)
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
	_hint_label.text = "SCROLL OR DRAG TO SURVEY THE PILGRIMAGE"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_label)
	_scale_chrome()


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


func _build_waystones() -> void:
	for i: int in range(map.nodes.size()):
		var n: MapNode = map.nodes[i]
		var shown_kind: String = "unlit" if n.unlit else n.type
		var caption: String = "Unlit Way" if n.unlit else _node_caption(n)
		var ws: GlassWaystone = GlassWaystone.new(
			i, shown_kind, _node_hue(n), caption, n.quest_marked)
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
		return "Hearth"
	if n.enemies.is_empty():
		return n.type.capitalize()
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
	var full: String = "%s — %s AWAITS" % [region, boss]
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
		var act_name: String = "The Rose Window" if map.region == "rose_window" \
			else str(act.get("name", REGION_NAME))
		_title_label.text = _act_line(act_name.to_upper(),
			str(act.get("bossName", "THE SUMMIT")).to_upper())
	var live: Array[int] = map.reachable()
	var first_live: GlassWaystone = null
	for i: int in range(_waystones.size()):
		_waystones[i].set_state(live.has(i), map.is_cleared(i), i == map.at)
		if first_live == null and live.has(i):
			first_live = _waystones[i]
	if live.is_empty():
		_hint_label.text = "THE ROAD ENDS HERE"
	else:
		_hint_label.text = "SCROLL OR DRAG · CHOOSE A LIT LANTERN"
		if first_live != null and first_live.is_inside_tree():
			first_live.grab_focus()
	_seat_marker()
	_push_bands(true)


func _set_act_theme(stage_act: int) -> void:
	_act = clampi(stage_act, 0, ACT_SKIES.size() - 1)
	_sky_colour = ACT_SKIES[_act]
	_fog_colour = ACT_FOGS[_act]
	_particle_colour = ACT_PARTICLES[_act]
	_glow_colour = ACT_GLOWS[_act]
	_accent_colour = ACT_ACCENTS[_act]
	_sky_tex = GlassStyle.grad_tex(
		PackedColorArray([_sky_colour, _fog_colour, REGION_GROUND]),
		PackedFloat32Array([0.0, 0.55, 1.0]), false,
		Vector2(0.5, 0.0), Vector2(0.5, 1.0))


func _seat_marker() -> void:
	var i: int = map.at if map.at >= 0 and map.at < map.nodes.size() else 0
	_cam_x = _cam_for(i) if not map.nodes.is_empty() else _cam_min()
	_cam_target = _cam_x
	_cam_velocity = 0.0


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
	# Boss at the lead-third leaves `(1 − lead)·W` of sky to its right.
	return _world_x(float(WorldMap.ROWS - 1))


func _on_waystone_chosen(i: int) -> void:
	choose(i)


## Glide the lantern to node `i`, then hand off. False = not selectable now.
## Capture departure BEFORE enter() — that call mutates map.at immediately.
func choose(i: int) -> bool:
	var from_i: int = map.at
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
	_cam_target = _cam_for(i)
	# Reduce-motion skips the walk but still arrives through one path so the
	# travelling flag clears the same way a tween finish would.
	if Preferences.active.reduce_motion:
		_cam_x = _cam_target
		_on_arrived(i)
		return true
	Motion.bez(self, _set_travel_t, TRAVEL_TIME, Motion.CSS_EASE) \
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
	node_chosen.emit(i)


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
	# Same control the PathBand edges use — rising bows up, falling bows down.
	var control: Vector2 = (from + to) * 0.5 \
		+ Vector2(0.0, signf(to.y - from.y) * 10.0)
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
	_layout_waystones()
	_push_bands()


func _push_bands(force: bool = false) -> void:
	var path_d: Vector2 = Vector2(
		_drift.n.x * PATH_DRIFT_AMP.x, _drift.n.y * PATH_DRIFT_AMP.y)
	var far_d: Vector2 = path_d / 3.0
	_sky_band.set_view(_cam_x, far_d, force)
	_region_band.set_view(_cam_x, far_d, force)
	_path_band.set_view(_cam_x, path_d, force)
	_veil_band.set_view(_cam_x, path_d * 1.35, force)


func _gui_input(event: InputEvent) -> void:
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
	var step: float = _step()
	for i: int in range(_waystones.size()):
		var ws: GlassWaystone = _waystones[i]
		var depth: float = absf(_world_x(float(map.nodes[i].row)) - _cam_x) / maxf(step, 1.0)
		var node_scale: float = k * clampf(1.08 - depth * 0.035, 0.72, 1.08)
		ws.scale = Vector2.ONE * node_scale
		ws.modulate.a = clampf(1.15 - depth * 0.12, 0.12, 1.0)
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
	var step: float = _step()
	var world_x: float = _world_x(float(node.row))
	var depth: float = absf(world_x - _cam_x) / maxf(step, 1.0)
	var lane_gap: float = _lane_gap()
	lane_gap *= clampf(1.0 - depth * 0.025, 0.78, 1.0)
	var d: Vector2 = Vector2(
		_drift.n.x * PATH_DRIFT_AMP.x, _drift.n.y * PATH_DRIFT_AMP.y)
	return Vector2(
		world_x - _cam_x + _lead_px() + node.jy * 24.0 + d.x,
		size.y * _trail_num("pathY", 0.64) + float(node.col - 3) * lane_gap \
			+ node.jx * 6.0 + d.y,
	)


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
