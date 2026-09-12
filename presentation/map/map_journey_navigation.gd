class_name MapJourneyNavigation
extends Control
## Read-only map inspection. Only explicit confirmation emits a travel request.
const CameraContract = preload("res://presentation/map/map_journey_camera_contract.gd")
signal view_changed
signal travel_requested(index: int)
var caption_resolver: Callable
var world: WorldMap
var overview: bool = false
var selected: int = -1
var area: int = -1
var locked: bool = false
var _last_at: int = -2
var _by_id: Dictionary = {}
var _journey: Button
var _overview: Button
var _travel: Button
var _caption: Label
var _row: HBoxContainer

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop: Panel = Panel.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	backdrop.offset_top = -88
	var glass: StyleBoxFlat = GlassStyle.pane(Color("655745"),.86)
	glass.set_corner_radius_all(0)
	glass.shadow_size = 0
	backdrop.add_theme_stylebox_override("panel",glass)
	add_child(backdrop)
	_row = HBoxContainer.new()
	_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_row.offset_left = 18
	_row.offset_right = -18
	_row.offset_top = -74
	_row.offset_bottom = -14
	_row.add_theme_constant_override("separation", 10)
	add_child(_row)
	_journey = _button("ui.pilgrimage.journeyView")
	_journey.pressed.connect(return_to_journey)
	_overview = _button("ui.pilgrimage.wholeAct")
	_overview.pressed.connect(show_overview)
	_caption = Label.new()
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size",18)
	_caption.add_theme_color_override("font_color",GlassStyle.TEXT)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_row.add_child(_caption)
	_travel = _button("ui.pilgrimage.travel")
	_travel.pressed.connect(_confirm)

func _button(key: String) -> Button:
	var button: Button = Button.new()
	button.text = Locale.active.t(key)
	button.custom_minimum_size = Vector2(108,60)
	button.add_theme_font_size_override("font_size",18)
	button.add_theme_stylebox_override("normal",GlassStyle.pane(GlassStyle.GOLD,.88))
	button.add_theme_stylebox_override("hover",GlassStyle.pane(GlassStyle.GOLD,.97))
	button.add_theme_stylebox_override("pressed",GlassStyle.pane(GlassStyle.EMBER,1.0))
	button.add_theme_stylebox_override("disabled",GlassStyle.pane(GlassStyle.TEXT_DIM,.72))
	button.add_theme_stylebox_override("focus",GlassStyle.focus_ring())
	_row.add_child(button)
	return button

func synchronise(map: WorldMap) -> void:
	locked = false
	world = map
	_by_id.clear()
	for i: int in range(world.nodes.size()):
		_by_id[world.nodes[i].id] = i
	if world.at != _last_at:
		_last_at = world.at
		area = -1
		selected = -1
		overview = false
	_update_controls()

func context_indices() -> Array[int]:
	var out: Array[int] = []
	if world == null:
		return out
	if overview:
		for i: int in range(world.nodes.size()): out.append(i)
		return out
	var focus: int = area if area >= 0 else world.at
	if focus < 0:
		var entrances: Array[int] = world.reachable()
		if not entrances.is_empty(): focus = entrances[0]
	if focus < 0 or focus >= world.nodes.size(): return out
	out.append(focus)
	for id: String in world.nodes[focus].next:
		if _by_id.has(id): out.append(_by_id[id])
	return out

func inspect(index: int) -> void:
	if locked or world == null or index < 0 or index >= world.nodes.size():
		return
	if overview:
		area = index
		overview = false
	elif not context_indices().has(index):
		return
	selected = index
	_update_controls()
	view_changed.emit()

func show_overview() -> void:
	if locked: return
	overview = true
	selected = -1
	_update_controls()
	view_changed.emit()

func return_to_journey() -> void:
	if locked: return
	overview = false
	area = -1
	selected = -1
	_update_controls()
	view_changed.emit()

func set_locked(value: bool) -> void:
	locked = value
	_update_controls()

func _update_controls() -> void:
	_journey.disabled = locked
	_overview.disabled = locked
	_travel.disabled = locked or overview or world == null or selected < 0
	if not _travel.disabled:
		_travel.disabled = not world.reachable().has(selected)
	_caption.text = Locale.active.t("ui.pilgrimage.inspectArea" if overview else "ui.pilgrimage.inspectWaystone")
	if world != null and selected >= 0:
		var node: MapNode = world.nodes[selected]
		_caption.text = Locale.active.t("ui.pilgrimage.unlitWay") if node.unlit else (str(caption_resolver.call(node)) if caption_resolver.is_valid() else "")
		if node.unlit and node.bounty > 0:
			_caption.text += "  ·  "+Locale.active.t("ui.pilgrimage.journeyBounty")+" %d" % node.bounty

func _confirm() -> void:
	if locked or world == null or overview or not world.reachable().has(selected):
		return
	travel_requested.emit(selected)
