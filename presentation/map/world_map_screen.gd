class_name WorldMapScreen
extends Control
## The benchmark 15×7 pilgrimage graph climbing a navigable Spire.
##
## Presentation only. It reads the WorldMap graph and animates; the map's own
## `enter()` gate decides what is legal. Fully built in _init (no tree
## dependency) so headless tests can drive it — see the M5 screens.

signal node_chosen(index: int)
signal menu_requested

const HORIZON: float = 0.64
const TRAVEL_TIME: float = 0.4
const ASH_COUNT: int = 128
const CAMERA_LEAD: float = 1.6
const CAMERA_MIN: float = 0.5
const CAMERA_MAX: float = WorldMap.ROWS - 0.5

const HINT_PT: float = 13.0
const HINT_TOP: float = -44.0
const HINT_BOTTOM: float = -18.0

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

var _cam_row: float = CAMERA_LEAD
var _cam_target: float = CAMERA_LEAD
var _cam_velocity: float = 0.0
var _dragging: bool = false
var _travelling: bool = false
## Where the last chosen waystone sat on screen, for the combat iris to
## collapse into. INF until a choice has been made.
var _chosen_at: Vector2 = Vector2.INF
var _waystones: Array[GlassWaystone] = []
var _ash: Array[Vector3] = []    # x, y, fall speed
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


func _init(world_map: WorldMap, content_ref: ContentDB,
		stage_shape: StringName = StageShape.IDENTITY) -> void:
	map = world_map
	content = content_ref
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	_trail_layout = LayoutBook.resolve(&"map", shape)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	_set_act_theme(0)
	_build_chrome()
	_build_waystones()
	_seed_ash()
	_seat_marker()
	set_process(true)


# ---------------------------------------------------------------- build

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
	_hint_label.text = "SCROLL OR DRAG TO SURVEY THE SPIRE"
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


func _seed_ash() -> void:
	# Deterministic scatter — the --shot loop diffs frames, so no randomness.
	for i: int in range(ASH_COUNT):
		var fi: float = float(i)
		_ash.append(Vector3(
			fmod(fi * 137.0, 2400.0),
			fmod(fi * 211.0, 900.0),
			14.0 + fmod(fi * 7.0, 22.0)))


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
	queue_redraw()


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
	var row: float = float(map.nodes[map.at].row) if map.at >= 0 and map.at < map.nodes.size() else 0.0
	_cam_row = clampf(row + CAMERA_LEAD, CAMERA_MIN, CAMERA_MAX)
	_cam_target = _cam_row
	_cam_velocity = 0.0


func _cam_for(i: int) -> float:
	return clampf(float(map.nodes[i].row) + CAMERA_LEAD, CAMERA_MIN, CAMERA_MAX)


func _on_waystone_chosen(i: int) -> void:
	choose(i)


## Glide the lantern to node `i`, then hand off. False = not selectable now.
func choose(i: int) -> bool:
	if _travelling or not map.enter(i):
		return false
	if i >= 0 and i < _waystones.size():
		_chosen_at = _waystones[i].get_global_rect().get_center()
	for ws: GlassWaystone in _waystones:
		ws.set_state(false, ws.cleared)  # travel locks the road
	if instant:
		node_chosen.emit(i)
		return true
	_travelling = true
	get_tree().create_timer(TRAVEL_TIME).timeout.connect(_on_arrived.bind(i))
	return true


func _on_arrived(i: int) -> void:
	_travelling = false
	node_chosen.emit(i)


## The screen point the combat iris collapses into — the chosen waystone's
## centre, or the stage centre before any choice was made.
func chosen_point() -> Vector2:
	if _chosen_at == Vector2.INF:
		return size * 0.5
	return _chosen_at


# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
	if not _dragging:
		if absf(_cam_velocity) > 0.02:
			_cam_row = clampf(_cam_row + _cam_velocity * delta, CAMERA_MIN, CAMERA_MAX)
			_cam_target = _cam_row
			_cam_velocity *= pow(0.06, delta)
		else:
			_cam_velocity = 0.0
			_cam_row = lerpf(_cam_row, _cam_target, minf(1.0, delta * 9.0))
	var span: float = maxf(size.x, 1.0) * 2.0
	for i: int in range(_ash.size()):
		var m: Vector3 = _ash[i]
		m.y += m.z * delta
		m.x -= m.z * delta * 0.35  # ash drifts against the walk
		if m.y > size.y:
			m.y -= size.y + 40.0
		_ash[i] = Vector3(fposmod(m.x, span), m.y, m.z)
	_layout_waystones()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		if button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and button.pressed:
			_cam_target = clampf(_cam_target + (
				0.9 if button.button_index == MOUSE_BUTTON_WHEEL_UP else -0.9),
				CAMERA_MIN, CAMERA_MAX)
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
		_pan(motion.relative.y, motion.velocity.y)
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
		_pan(drag.relative.y, drag.velocity.y)
		accept_event()


func _pan(delta_y: float, velocity_y: float) -> void:
	var gap: float = _row_gap()
	_cam_row = clampf(_cam_row + delta_y / gap, CAMERA_MIN, CAMERA_MAX)
	_cam_target = _cam_row
	_cam_velocity = clampf(velocity_y / gap, -8.0, 8.0)


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
	queue_redraw()


func _layout_waystones() -> void:
	var k: float = _trail_num("scale", 0.36)
	var touch: float = _trail_num("touch", 0.0)
	for i: int in range(_waystones.size()):
		var ws: GlassWaystone = _waystones[i]
		var depth: float = absf(float(map.nodes[i].row) - _cam_row)
		var node_scale: float = k * clampf(1.08 - depth * 0.035, 0.72, 1.08)
		ws.scale = Vector2.ONE * node_scale
		ws.modulate.a = clampf(1.15 - depth * 0.12, 0.12, 1.0)
		# Before the seat, not after: the pad changes `size`, and the seat is
		# computed from it. The drawing sits in the middle of the padded rect,
		# so centring the rect still centres the stone.
		ws.set_touch_min(touch, node_scale)
		ws.position = _node_pos(map.nodes[i]) - ws.size * node_scale * 0.5


## Where a node sits, from the book rather than from five literals.
##
## The column gap was `clamp(104, 50, (w - 170) / 6)` inline. Three numbers, no
## shape named, and at 390px the clamp fires: the trail stops following the
## screen and starts running off it. `gutter` is what the columns may not use,
## and `colMin`/`colMax` are the band the gap is held inside.
func _node_pos(node: MapNode) -> Vector2:
	var span: float = (size.x - _trail_num("gutter", 170.0)) / float(WorldMap.COLS - 1)
	var col_gap: float = clampf(span, _trail_num("colMin", 50.0), _trail_num("colMax", 104.0))
	var depth: float = absf(float(node.row) - _cam_row)
	col_gap *= clampf(1.0 - depth * 0.025, 0.78, 1.0)
	return Vector2(
		size.x * 0.5 + float(node.col - 3) * col_gap + node.jx * 20.0,
		size.y * 0.52 - (float(node.row) - _cam_row) * _row_gap() + node.jy * 12.0,
	)


## How far apart two rows of the Spire stand, in stage px.
##
## The rate is what keeps the same NUMBER of rows on screen as the stage grows,
## rather than more of them; the band is what stops a phone held sideways from
## stacking rows into each other. It replaced `trail/top` and `trail/bottom`,
## which described a vertical band the map no longer has.
##
## Worth knowing before tuning: across all five reference shapes the rate never
## decides anything. Every landscape shape is 820 tall and every portrait one
## taller, so the product lands on `rowMax` everywhere except phone-landscape,
## where 390px lands under `rowMin`. The rate only bites between roughly 617
## and 817 stage px — a height no reference sits at, and one flex cannot reach,
## because flex stretches the LONG axis and so never shortens a stage.
func _row_gap() -> float:
	return clampf(size.y * _trail_num("rowRate", 0.12),
		_trail_num("rowMin", 74.0), _trail_num("rowMax", 98.0))


# ---------------------------------------------------------------- draw

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var horizon: float = h * HORIZON
	# The night gradient is drawn, not parented: a child TextureRect would sit
	# above this _draw pass and bury every band under it.
	draw_texture_rect(_sky_tex, Rect2(Vector2.ZERO, size), false)
	draw_texture_rect(SkyField.disc(),
		Rect2(-w * 0.10, h * 0.22, w * 1.20, h * 0.60), false,
		Color(_fog_colour.lightened(0.42), 0.28))
	draw_rect(Rect2(0.0, horizon, w, h - horizon),
		Color(REGION_GROUND, 0.62 if _act == 0 else 0.38))
	_draw_region(w, horizon)
	_draw_spire()
	_draw_graph()
	_draw_marker()
	_draw_veil(w)


func _draw_region(w: float, horizon: float) -> void:
	if _act > 0:
		for cloud: int in range(9):
			var cloud_w: float = w * (0.18 + float(cloud % 3) * 0.035)
			var cloud_h: float = 54.0 + float(cloud % 4) * 13.0
			var x: float = fposmod(float(cloud) * w * 0.17, w + cloud_w) - cloud_w
			draw_texture_rect(SkyField.disc(),
				Rect2(x, horizon - cloud_h * 0.68, cloud_w, cloud_h), false,
				Color(_fog_colour.lightened(0.50), 0.15))
		return
	var span: float = w + 400.0
	var trunk: Color = Color(0.025, 0.065, 0.048, 0.94)
	var rim: Color = Color(_accent_colour, 0.08)
	for tree: int in range(20):
		var index: float = float(tree)
		var x: float = fposmod(index * 163.0, span) - 200.0
		var tree_h: float = 90.0 + fmod(index * 53.0, 90.0)
		var base_y: float = horizon + 26.0 + fmod(index * 29.0, 30.0)
		var top_y: float = base_y - tree_h
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 8.0, base_y), Vector2(x - 2.5, top_y),
			Vector2(x + 2.5, top_y), Vector2(x + 8.0, base_y),
		]), trunk)
		draw_line(Vector2(x, top_y + tree_h * 0.30),
			Vector2(x - 28.0, top_y + tree_h * 0.06), trunk, 4.0)
		draw_line(Vector2(x, top_y + tree_h * 0.46),
			Vector2(x + 32.0, top_y + tree_h * 0.14), trunk, 4.0)
		draw_line(Vector2(x - 2.5, top_y),
			Vector2(x - 5.0, top_y + tree_h * 0.45), rim, 1.0)


func _draw_spire() -> void:
	var centre: float = size.x * 0.5
	var top_w: float = maxf(58.0, size.x * 0.08)
	var bottom_w: float = maxf(180.0, size.x * 0.28)
	draw_colored_polygon(PackedVector2Array([
		Vector2(centre - top_w, 0.0), Vector2(centre + top_w, 0.0),
		Vector2(centre + bottom_w, size.y), Vector2(centre - bottom_w, size.y),
	]), _sky_colour.darkened(0.58))
	for row: int in range(WorldMap.ROWS):
		var y: float = size.y * 0.52 - (float(row) - _cam_row) * _row_gap()
		if y < -20.0 or y > size.y + 20.0:
			continue
		var depth: float = absf(float(row) - _cam_row)
		var half: float = lerpf(top_w, bottom_w, clampf(y / maxf(size.y, 1.0), 0.0, 1.0))
		draw_line(Vector2(centre - half, y), Vector2(centre + half, y),
			Color(GlassStyle.GLASS.r, GlassStyle.GLASS.g, GlassStyle.GLASS.b,
				clampf(0.18 - depth * 0.018, 0.035, 0.18)), 1.0)


## The current lantern's glow sits behind its waystone.
func _draw_marker() -> void:
	if map.at < 0 or map.at >= map.nodes.size():
		return
	var at: Vector2 = _node_pos(map.nodes[map.at])
	var x: float = at.x
	var y: float = at.y
	var ember: Color = GlassStyle.EMBER
	draw_circle(Vector2(x, y), 30.0, Color(ember.r, ember.g, ember.b, 0.10))
	draw_circle(Vector2(x, y), 15.0, Color(ember.r, ember.g, ember.b, 0.18))


func _draw_graph() -> void:
	var by_id: Dictionary = {}
	for node: MapNode in map.nodes:
		by_id[node.id] = node
	for node: MapNode in map.nodes:
		var from: Vector2 = _node_pos(node)
		for next_id: String in node.next:
			var next_v: Variant = by_id.get(next_id)
			if typeof(next_v) == TYPE_OBJECT:
				var next_node: MapNode = next_v
				var to: Vector2 = _node_pos(next_node)
				var from_i: int = map.nodes.find(node)
				var to_i: int = map.nodes.find(next_node)
				var walked: bool = map.is_cleared(from_i) and map.is_cleared(to_i)
				var fade: float = clampf(1.0 - maxf(
					absf(float(node.row) - _cam_row),
					absf(float(next_node.row) - _cam_row)) * 0.12, 0.10, 1.0)
				var control: Vector2 = (from + to) * 0.5 + Vector2(0.0, 10.0)
				var previous: Vector2 = from
				for segment: int in range(1, 13):
					var t: float = float(segment) / 12.0
					var point: Vector2 = from * (1.0 - t) * (1.0 - t) \
						+ control * 2.0 * (1.0 - t) * t + to * t * t
					if walked or segment % 2 == 1:
						var tone: Color = Color(0.85, 0.87, 0.92) if walked else GlassStyle.GLASS
						draw_line(previous, point, Color(tone.r, tone.g, tone.b,
							fade * (0.72 if walked else 0.24)), 3.0 if walked else 2.0)
					previous = point


## Band 4 (1.35) — near ash, overshooting the walk to sell the depth.
func _draw_veil(w: float) -> void:
	var span: float = maxf(w, 1.0) * 2.0
	var glow: Texture2D = SkyField.disc()
	for index: int in range(_ash.size()):
		var m: Vector3 = _ash[index]
		var x: float = fposmod(m.x, span)
		if x > w:
			continue
		var radius: float = 2.0 + m.z * 0.08
		var tint: Color = _glow_colour if index % 3 != 0 else _particle_colour
		var alpha: float = 0.20 + 0.26 * (m.z / 36.0)
		draw_texture_rect(glow, Rect2(
			Vector2(x, m.y) - Vector2.ONE * radius * 2.0,
			Vector2.ONE * radius * 4.0), false, Color(tint, alpha))
