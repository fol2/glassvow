class_name WorldMapScreen
extends Control
## The pilgrimage (concept brief §1/§5): the run walks west-to-east across the
## glass world toward the Spire on the horizon. Four parallax bands — skyband
## .10, region .35, path 1.0, veil 1.35 — are drawn in a single pass off one
## camera-x, so depth costs arithmetic rather than a scene graph. Waystones are
## the only real children: they take input.
##
## Presentation only. It reads the WorldMap graph and animates; the map's own
## `enter()` gate decides what is legal. Fully built in _init (no tree
## dependency) so headless tests can drive it — see the M5 screens.

signal node_chosen(index: int)

const SPACING: float = 250.0     # stage px per world_x ordinal
const LEFT: float = 210.0        # world_x 0 sits here at camera 0
const PATH_Y: float = 0.70       # path band baseline, fraction of height
const HORIZON: float = 0.52
const F_SKY: float = 0.10
const F_REGION: float = 0.35
const F_VEIL: float = 1.35
const TRAVEL_TIME: float = 0.4
const ASH_COUNT: int = 64

## Act 1 — the Ashen Woods. Act 2/3 swap these three lines (teal caustics,
## violet storm) once their content exists; the bands themselves don't change.
const REGION_NAME: String = "The Ashen Woods"
const REGION_ACCENT: Color = Color(0.49, 0.86, 0.56)  # #7ddb8f
const SPIRE_H: float = 0.20      # Act 1: small and pale. It grows each act.

var instant: bool = false        # headless: travel resolves without a tween
var map: WorldMap
var content: ContentDB

var _cam_x: float = 0.0
var _marker_x: float = 0.0
var _travelling: bool = false
var _waystones: Array[GlassWaystone] = []
var _ash: Array[Vector3] = []    # x, y, fall speed
var _region_label: Label
var _vitals_label: Label
var _hint_label: Label
var _sky_tex: GradientTexture2D


func _init(world_map: WorldMap, content_ref: ContentDB) -> void:
	map = world_map
	content = content_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	_sky_tex = GlassStyle.grad_tex(
		PackedColorArray([GlassStyle.NIGHT_TOP, GlassStyle.NIGHT_MID, GlassStyle.NIGHT_BOT]),
		PackedFloat32Array([0.0, 0.55, 1.0]), false, Vector2(0.5, 0.0), Vector2(0.5, 1.0))
	_build_chrome()
	_build_waystones()
	_seed_ash()
	_seat_marker()
	set_process(true)


# ---------------------------------------------------------------- build

func _build_chrome() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.06, 0.55)
	sb.border_width_bottom = 1
	sb.border_color = Color(GlassStyle.GLASS.r, GlassStyle.GLASS.g, GlassStyle.GLASS.b, 0.22)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	bar.add_theme_stylebox_override("panel", sb)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	bar.add_child(row)
	var title: Label = Label.new()
	title.text = "琉璃誓言"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0, 0.92))
	row.add_child(title)
	_region_label = Label.new()
	_region_label.text = REGION_NAME
	_region_label.add_theme_color_override("font_color",
		Color(REGION_ACCENT.r, REGION_ACCENT.g, REGION_ACCENT.b, 0.85))
	row.add_child(_region_label)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_vitals_label = Label.new()
	_vitals_label.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	row.add_child(_vitals_label)

	_hint_label = Label.new()
	_hint_label.text = "Walk east — the Spire is still far."
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.offset_top = -44
	_hint_label.offset_bottom = -18
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_label)


func _build_waystones() -> void:
	for i: int in range(map.nodes.size()):
		var n: MapNode = map.nodes[i]
		var ws: GlassWaystone = GlassWaystone.new(i, n.type, _node_hue(n), _node_caption(n))
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

## Re-seat and re-light after a run change or a return from combat.
func refresh(run: RunState) -> void:
	if run != null:
		_vitals_label.text = "HP %d / %d   ·   Gold %d" % [
			maxi(0, run.player.hp), run.player.max_hp, run.player.gold]
	var live: Array[int] = map.reachable()
	for i: int in range(_waystones.size()):
		_waystones[i].set_state(live.has(i), map.is_cleared(i))
	if live.is_empty():
		_hint_label.text = "The road ends here."
	else:
		_hint_label.text = "Choose the next waystone."
	_seat_marker()


func _seat_marker() -> void:
	if map.at < 0 or map.at >= map.nodes.size():
		return
	_marker_x = float(map.nodes[map.at].world_x) * SPACING
	_cam_x = _cam_for(map.at)


func _cam_for(i: int) -> float:
	if i < 0 or i >= map.nodes.size():
		return 0.0
	# Keep the marker in the leading third so the road ahead stays visible.
	return maxf(0.0, float(map.nodes[i].world_x) * SPACING - size.x * 0.34)


func _on_waystone_chosen(i: int) -> void:
	choose(i)


## Glide the lantern to node `i`, then hand off. False = not selectable now.
func choose(i: int) -> bool:
	if _travelling or not map.enter(i):
		return false
	for ws: GlassWaystone in _waystones:
		ws.set_state(false, ws.cleared)  # travel locks the road
	var target_x: float = float(map.nodes[i].world_x) * SPACING
	if instant:
		_marker_x = target_x
		_cam_x = _cam_for(i)
		node_chosen.emit(i)
		return true
	_travelling = true
	var tw: Tween = create_tween()
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "_marker_x", target_x, TRAVEL_TIME)
	tw.parallel().tween_property(self, "_cam_x", _cam_for(i), TRAVEL_TIME)
	tw.tween_callback(_on_arrived.bind(i))
	return true


func _on_arrived(i: int) -> void:
	_travelling = false
	node_chosen.emit(i)


# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
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


func _layout_waystones() -> void:
	var y: float = size.y * PATH_Y
	for i: int in range(_waystones.size()):
		var ws: GlassWaystone = _waystones[i]
		ws.position = Vector2(
			_world_to_screen(float(map.nodes[i].world_x) * SPACING) - ws.size.x * 0.5,
			y - GlassWaystone.EMBLEM_H + 8.0)


func _world_to_screen(world_x: float) -> float:
	return LEFT + world_x - _cam_x


# ---------------------------------------------------------------- draw

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var horizon: float = h * HORIZON
	var path_y: float = h * PATH_Y
	# The night gradient is drawn, not parented: a child TextureRect would sit
	# above this _draw pass and bury every band under it.
	draw_texture_rect(_sky_tex, Rect2(Vector2.ZERO, size), false)
	_draw_skyband(w, horizon)
	_draw_region(w, horizon)
	_draw_ground(w, h, horizon, path_y)
	_draw_path(w, path_y)
	_draw_marker(path_y)
	_draw_veil(w)


## Band 1 (.10) — the goal-anchor. The Spire barely moves, so it reads as
## distant and fixed; it grows act by act until it fills the sky.
func _draw_skyband(w: float, horizon: float) -> void:
	var glass: Color = GlassStyle.GLASS
	draw_line(Vector2(0, horizon), Vector2(w, horizon), Color(glass.r, glass.g, glass.b, 0.10), 1.0)
	var base_x: float = w * 0.78 - _cam_x * F_SKY
	var sh: float = size.y * SPIRE_H
	var half: float = sh * 0.14
	var top: float = horizon - sh
	draw_colored_polygon(PackedVector2Array([
		Vector2(base_x - half * 1.5, horizon), Vector2(base_x - half * 0.42, top),
		Vector2(base_x + half * 0.42, top), Vector2(base_x + half * 1.5, horizon),
	]), Color(0.13, 0.15, 0.26, 0.85))
	draw_colored_polygon(PackedVector2Array([
		Vector2(base_x - half * 0.42, top), Vector2(base_x, top - sh * 0.26),
		Vector2(base_x + half * 0.42, top),
	]), Color(0.16, 0.18, 0.30, 0.85))
	# Lit floors: a few pale leaded bands, and a lantern at the crown.
	for k: int in range(1, 5):
		var fy: float = horizon - sh * (float(k) / 5.0)
		var fw: float = half * (1.5 - 0.22 * float(k))
		draw_line(Vector2(base_x - fw, fy), Vector2(base_x + fw, fy),
			Color(glass.r, glass.g, glass.b, 0.16), 1.0)
	draw_circle(Vector2(base_x, top - sh * 0.20), 3.0,
		Color(GlassStyle.EMBER.r, GlassStyle.EMBER.g, GlassStyle.EMBER.b, 0.75))


## Band 2 (.35) — charred glass trees, the Ashen Woods silhouette.
func _draw_region(w: float, horizon: float) -> void:
	var span: float = w + 400.0
	var trunk: Color = Color(0.06, 0.08, 0.12, 0.92)
	var rim: Color = Color(REGION_ACCENT.r, REGION_ACCENT.g, REGION_ACCENT.b, 0.09)
	for j: int in range(14):
		var fj: float = float(j)
		var base_x: float = fposmod(fj * 163.0 - _cam_x * F_REGION, span) - 200.0
		var th: float = 90.0 + fmod(fj * 53.0, 70.0)
		var base_y: float = horizon + 12.0 + fmod(fj * 29.0, 22.0)
		var top_y: float = base_y - th
		draw_colored_polygon(PackedVector2Array([
			Vector2(base_x - 7.0, base_y), Vector2(base_x - 2.5, top_y),
			Vector2(base_x + 2.5, top_y), Vector2(base_x + 7.0, base_y),
		]), trunk)
		draw_line(Vector2(base_x, top_y + th * 0.30),
			Vector2(base_x - 26.0, top_y + th * 0.06), trunk, 3.0)
		draw_line(Vector2(base_x, top_y + th * 0.46),
			Vector2(base_x + 30.0, top_y + th * 0.14), trunk, 3.0)
		draw_line(Vector2(base_x - 2.5, top_y), Vector2(base_x - 5.0, top_y + th * 0.45), rim, 1.0)


func _draw_ground(w: float, h: float, horizon: float, path_y: float) -> void:
	draw_rect(Rect2(0, horizon, w, h - horizon), Color(0.02, 0.025, 0.05, 0.75))
	draw_rect(Rect2(0, path_y + 26.0, w, h - path_y - 26.0), Color(0.01, 0.015, 0.035, 0.7))


## Band 3 (1.0) — the play plane: the leaded road the waystones stand on.
func _draw_path(w: float, path_y: float) -> void:
	var glass: Color = GlassStyle.GLASS
	draw_rect(Rect2(0, path_y, w, 22.0), Color(0.05, 0.07, 0.13, 0.85))
	draw_line(Vector2(0, path_y), Vector2(w, path_y), Color(glass.r, glass.g, glass.b, 0.30), 1.6)
	draw_line(Vector2(0, path_y + 22.0), Vector2(w, path_y + 22.0),
		Color(glass.r, glass.g, glass.b, 0.14), 1.0)
	# Lead ties, laid in world space so they carry the sense of walking.
	var first: float = floorf(_cam_x / 46.0) * 46.0
	for k: int in range(int(w / 46.0) + 3):
		var x: float = _world_to_screen(first + float(k) * 46.0)
		draw_line(Vector2(x, path_y + 3.0), Vector2(x, path_y + 19.0),
			Color(glass.r, glass.g, glass.b, 0.09), 1.0)


## The pilgrim: one lantern, carried east. Seated a stride west of its
## waystone — the screen's own _draw sits under every child, so a marker
## centred on the node would be buried by that node's pane.
func _draw_marker(path_y: float) -> void:
	var x: float = _world_to_screen(_marker_x) - 78.0
	var y: float = path_y - 16.0
	var ember: Color = GlassStyle.EMBER
	draw_circle(Vector2(x, y), 30.0, Color(ember.r, ember.g, ember.b, 0.10))
	draw_circle(Vector2(x, y), 15.0, Color(ember.r, ember.g, ember.b, 0.18))
	draw_colored_polygon(PackedVector2Array([
		Vector2(x, y - 13.0), Vector2(x + 8.0, y - 4.0), Vector2(x + 8.0, y + 9.0),
		Vector2(x - 8.0, y + 9.0), Vector2(x - 8.0, y - 4.0),
	]), Color(ember.r, ember.g, ember.b, 0.55))
	draw_colored_polygon(PackedVector2Array([
		Vector2(x, y - 5.0), Vector2(x + 4.0, y + 3.0),
		Vector2(x, y + 8.0), Vector2(x - 4.0, y + 3.0),
	]), Color(1.0, 0.94, 0.78, 0.9))
	draw_line(Vector2(x - 9.0, y - 13.0), Vector2(x + 9.0, y - 13.0),
		Color(GlassStyle.GLASS.r, GlassStyle.GLASS.g, GlassStyle.GLASS.b, 0.55), 1.6)
	draw_line(Vector2(x, y + 16.0), Vector2(x, y + 26.0),
		Color(ember.r, ember.g, ember.b, 0.25), 2.0)


## Band 4 (1.35) — near ash, overshooting the walk to sell the depth.
func _draw_veil(w: float) -> void:
	var span: float = maxf(w, 1.0) * 2.0
	for m: Vector3 in _ash:
		var x: float = fposmod(m.x - _cam_x * F_VEIL, span)
		if x > w:
			continue
		var a: float = 0.06 + 0.10 * (m.z / 36.0)
		draw_circle(Vector2(x, m.y), 1.0 + m.z * 0.045, Color(0.78, 0.80, 0.86, a))
