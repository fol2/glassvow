class_name WorldMapScreen
extends Control
## The benchmark 15×7 pilgrimage graph on the 3D lattice road.
##
## Presentation only. It reads the WorldMap graph and animates; the map's own
## `enter()` gate decides what is legal. Fully built in _init (no tree
## dependency) so headless tests can drive it — see the M5 screens.
## Paint order is child order: MapScene (world) → path overlay → waystones →
## veil → chrome. Pins sit on `projected_seats()`. Chips, sealed-door (#217)
## and HUD stay 2D.

signal node_chosen(index: int)
signal sealed_door_requested
## Optional persist-first gate. Main binds hint dismissal here so a failed
## Vigil flush cannot let the lantern walk before the record is on disk.
var before_pick: Callable = Callable()

const TRAVEL_TIME: float = 0.4

const HINT_PT: float = 13.0
const HINT_TOP: float = -44.0
const HINT_BOTTOM: float = -18.0

## Path/waystone PointerDrift amplitude (px); veil ×1.35 (#64).
const PATH_DRIFT_AMP: Vector2 = Vector2(14.0, 12.0)

const REGION_NAME: String = "The Ashen Woods"

var instant: bool = false        # headless: travel resolves without a tween
var map: WorldMap
var content: ContentDB

## The stage shape this screen composes for, and its resolved `map` layout.
## Re-read through `_trail()` rather than cached in locals: `set_shape` swaps it
## under a live screen when the window crosses an aspect boundary.
var shape: StringName = StageShape.IDENTITY

var _travelling: bool = false
## Node index the lantern leaves during a glide; −1 when seated or when the
## run starts with no prior seat (path then collapses to the target).
var _travel_from_i: int = -1
var _travel_t: float = 0.0
var _travel_from_xz: Vector2 = MapCameraRig.DEFAULT_XZ
var _travel_to_xz: Vector2 = MapCameraRig.DEFAULT_XZ
var _waystones: Array[GlassWaystone] = []
var _hint_label: Label
## H1 retires the persistent survey copy so the map does not double-teach.
var _survey_retired: bool = false
var _sealed_door: Button
var _trail_layout: Dictionary = {}
var _title_label: Label
var _run: RunState = null
var _act: int = 0
var _particle_colour: Color
var _glow_colour: Color
## Per-act region knobs (palette + weather). VeilBand reads this;
## built in `_set_act_theme` so a theme pick never leaves stale weather.
var _region: MapRegions = null

var _drift: PointerDrift = PointerDrift.new()
var _map_scene: MapScene = null
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
	# World → path overlay → waystones → veil → chrome: child order is paint order.
	_build_world_surface()
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
	# Theme after the veil exists so apply_region reaches it.
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

func _build_world_surface() -> void:
	_map_scene = MapScene.new()
	_map_scene.surface_tapped.connect(_on_surface_tapped)
	add_child(_map_scene)
	_map_scene.lay_road(_road_segments())


## Every graph edge as a world-space endpoint pair, for MapScene to pave. The
## graph lives here, so the conversion does too: MapScene stays buildable
## without a WorldMap.
func _road_segments() -> PackedVector3Array:
	var by_id: Dictionary = {}
	for node: MapNode in map.nodes:
		by_id[node.id] = node
	var out: PackedVector3Array = PackedVector3Array()
	for node: MapNode in map.nodes:
		var from: Vector3 = MapPinProjection.world_anchor(node)
		for next_id: String in node.next:
			var next_v: Variant = by_id.get(next_id)
			if typeof(next_v) != TYPE_OBJECT:
				continue
			var next_node: MapNode = next_v
			out.append(from)
			out.append(MapPinProjection.world_anchor(next_node))
	return out


func _build_bands() -> void:
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
	# arrived from the other direction: the top rail now carries the act, the
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
		ws.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	# An act with no bossName gets the region alone — the same degraded form this
	# function already falls back to when the full line will not fit. The retired
	# `ui.pilgrimage.summit` used to fill the slot, but the slot is inside
	# "{boss} AWAITS": any sentence put there has to be a noun, and the nearest
	# surviving key (`roadEnds`, "THE ROAD ENDS HERE") is a clause. Act IV's
	# `bossName` is not in the catalogue yet, so this path is reachable.
	if boss.is_empty():
		return region
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
			str(act.get("bossName", "")).to_upper())
	var live: Array[int] = map.reachable()
	var first_live: GlassWaystone = null
	for i: int in range(_waystones.size()):
		_waystones[i].set_state(live.has(i), map.is_cleared(i), i == map.at)
		if first_live == null and live.has(i):
			first_live = _waystones[i]
	if live.is_empty():
		_hint_label.visible = true
		_hint_label.text = Locale.active.t("ui.pilgrimage.roadEnds")
	elif _survey_retired:
		_hint_label.visible = false
	else:
		_hint_label.visible = true
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
	if content != null and not content.acts.is_empty():
		_act = clampi(stage_act, 0, content.acts.size() - 1)
	# MapRegions is the sole source; the content pack theme dict is not read.
	# Veil motes read glow/particle; 3D ramp binds band_shade/band_key on MapScene.
	_particle_colour = _region.particles
	_glow_colour = _region.glow
	if _veil_band != null:
		_veil_band.apply_region(_region)
	if _map_scene != null:
		_map_scene.set_act(stage_act)


## 3D lattice seats in this Control's px. Live waystones sit here.
func projected_seats() -> PackedVector2Array:
	if _map_scene == null:
		return PackedVector2Array()
	if size.x > 1.0 and size.y > 1.0 and _map_scene.size != size:
		_map_scene.size = size
	_map_scene._fit()
	return _map_scene.project_pins(map.nodes)


func set_survey_retired(on: bool) -> void:
	_survey_retired = on
	if _hint_label == null:
		return
	if on and not (_run != null and map.reachable().is_empty()):
		_hint_label.visible = false


func first_live_waystone() -> Control:
	var live: Array[int] = map.reachable()
	for i: int in range(_waystones.size()):
		if live.has(i):
			return _waystones[i]
	return _hint_label


func pick_node_at(screen: Vector2) -> int:
	if _map_scene == null:
		return -1
	return _map_scene.pin_at(screen, map.nodes, _pin_hit())


func _pin_hit() -> float:
	return maxf(36.0, _trail_num("touch", 44.0) * 0.5)


## Dress the bands in another act's region without mutating the run. Used by
## `--map --act=N` so captures can see act 1/2 weather without reaching that
## act in a run — domain map generation stays the run's act (scenery only).
func set_act_scenery(stage_act: int) -> void:
	_set_act_theme(stage_act)
	if content != null and _act < content.acts.size() and _title_label != null:
		var act: Dictionary = content.acts[_act]
		_title_label.text = _act_line(
			str(act.get("name", REGION_NAME)).to_upper(),
			str(act.get("bossName", "")).to_upper())
	_push_bands(true)


## Put the camera where the marker's node sits. Called on every `refresh`, which
## `set_shape` also routes through — and a shape re-pick can land mid-glide, when
## a snap would tear the walk out from under the lantern. Re-aim instead: the
## destination is re-derived at the NEW geometry while the current pose keeps
## easing, so the glide finishes at the right place on the new stage (#69 B2).
func _seat_marker() -> void:
	var i: int = map.at if map.at >= 0 and map.at < map.nodes.size() else 0
	var seat: Vector2 = _focus_xz(i) if not map.nodes.is_empty() \
		else MapCameraRig.DEFAULT_XZ
	_travel_to_xz = seat
	if _map_scene != null:
		_map_scene.set_lock_input(true)
	if _travelling:
		return
	if _map_scene != null:
		_map_scene.set_lock_input(false)
		_map_scene.get_rig().set_camera_xz(seat)
		_map_scene.set_live(false)


func _focus_xz(i: int) -> Vector2:
	if i < 0 or i >= map.nodes.size() or _map_scene == null:
		return MapCameraRig.DEFAULT_XZ
	# Aspect comes from the STAGE SHAPE, not from `_map_scene.size`. The child
	# Control only has its real size after a layout pass, so reading it here
	# would make the camera seat depend on WHEN the seat is asked for — a
	# mid-glide `set_shape` would aim at something a later call could not
	# reproduce, which is exactly what test_map's re-aim gate is watching for.
	# The shape is known without a frame.
	var reference: Vector2 = Vector2(StageShape.REFERENCES[shape])
	var aspect: float = reference.x / maxf(reference.y, 1.0)
	return _map_scene.get_rig().pose_leading(
		MapPinProjection.world_anchor(map.nodes[i]), aspect)


func _on_waystone_chosen(i: int) -> void:
	choose(i)


## Glide the lantern to node `i`, then hand off. False = not selectable now.
## Capture departure BEFORE enter() — that call mutates map.at immediately.
## Unlit is NOT cleared here: main pays the bounty and flips `n.unlit` only
## after node_chosen, so the ceremony covers the same-screen window between
## click and route swap.
func choose(i: int) -> bool:
	if before_pick.is_valid() and not before_pick.call():
		return false
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
	_travel_from_xz = _map_scene.get_rig().camera_xz() if _map_scene != null \
		else MapCameraRig.DEFAULT_XZ
	_travel_to_xz = _focus_xz(i)
	if _map_scene != null:
		_map_scene.set_lock_input(true)
		_map_scene.set_live(true)
	_glide(i, was_unlit)
	return true


func _glide(i: int, was_unlit: bool) -> void:
	# Reduce-motion skips the walk but still arrives through one path so the
	# travelling flag clears the same way a tween finish would. No kindle
	# ceremony — art corrects on the next _show_map rebuild, as today.
	if Preferences.active.reduce_motion:
		if _map_scene != null:
			_map_scene.get_rig().set_camera_xz(_travel_to_xz)
		_on_arrived(i)
		return
	if was_unlit and i >= 0 and i < _waystones.size():
		_waystones[i].kindle_reveal(map.nodes[i].type)
	# Hold the glide so the 0.45s bloom lands before the route swap.
	var dur: float = maxf(TRAVEL_TIME, 0.5) if was_unlit else TRAVEL_TIME
	Motion.bez(self, _set_travel_t, dur, Motion.CSS_EASE) \
		.finished.connect(_on_arrived.bind(i))


func _set_travel_t(v: float) -> void:
	_travel_t = v
	if _map_scene != null:
		_map_scene.get_rig().set_camera_xz(
			_travel_from_xz.lerp(_travel_to_xz, v))
	var path_d: Vector2 = Vector2(
		_drift.n.x * PATH_DRIFT_AMP.x, _drift.n.y * PATH_DRIFT_AMP.y)
	if _path_band != null:
		_path_band.set_view(_rig_cam_x(), path_d, true)


func _on_arrived(i: int) -> void:
	_travelling = false
	_travel_from_i = -1
	_hint_label.modulate.a = 1.0
	if _map_scene != null:
		_map_scene.set_lock_input(false)
		_map_scene.set_live(false)
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
	var lane_rise: float = clampf((to.y - from.y) / maxf(_lane_gap(), 1.0), -1.0, 1.0)
	return (from + to) * 0.5 + Vector2(0.0, lane_rise * 10.0)


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
	# Scroll and pointer chase are user-initiated — PointerDrift settles home
	# off-stage; no second reduce-motion gate (P5.1 / P1).
	_drift.step(self, delta)
	_layout_waystones()
	_push_bands()
	_sync_world_live()


## Freeze the 3D surface at rest; unfreeze for pan, wheel, or travel.
func _sync_world_live() -> void:
	if _map_scene == null:
		return
	var moving: bool = _travelling or _map_scene.is_moving()
	if moving != _map_scene.is_live():
		_map_scene.set_live(moving)


func _push_bands(force: bool = false) -> void:
	var path_d: Vector2 = Vector2(
		_drift.n.x * PATH_DRIFT_AMP.x, _drift.n.y * PATH_DRIFT_AMP.y)
	var cam: float = _rig_cam_x()
	if _path_band != null:
		_path_band.set_view(cam, path_d, force)
	if _chip_band != null:
		_chip_band.set_view(cam, path_d, force)
	if _veil_band != null:
		_veil_band.set_view(cam, path_d * 1.35, force)


func _rig_cam_x() -> float:
	if _map_scene == null:
		return 0.0
	return _map_scene.get_rig().camera_xz().x * 24.0


func _on_surface_tapped(screen: Vector2) -> void:
	if _travelling:
		return
	var i: int = pick_node_at(screen)
	if i >= 0:
		choose(i)


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
	var seats: PackedVector2Array = projected_seats()
	for i: int in range(_waystones.size()):
		var ws: GlassWaystone = _waystones[i]
		var node_scale: float = k
		ws.scale = Vector2.ONE * node_scale
		ws.set_depth_alpha(1.0)
		ws.set_touch_min(touch, node_scale)
		var seat: Vector2 = seats[i] if i < seats.size() else Vector2.ZERO
		ws.position = seat - ws.size * node_scale * 0.5


## Lattice seat of this node, in this Control's px.
func _node_pos(node: MapNode) -> Vector2:
	var i: int = map.nodes.find(node)
	var seats: PackedVector2Array = projected_seats()
	return seats[i] if i >= 0 and i < seats.size() else Vector2.ZERO


## Lane spacing across the path. Col 3 is centre.
func _lane_gap() -> float:
	return clampf(size.y * _trail_num("laneRate", 0.06),
		_trail_num("laneMin", 46.0), _trail_num("laneMax", 50.0))
