extends "res://tools/map_workshop/common/inspection.gd"
## Read-only five-stop navigation. Shared guidance and Travel never advance a save.
const Guide = preload("res://tools/map_workshop/common/route_guidance.gd")
const Travel = preload("res://tools/map_workshop/common/route_travel.gd")
const NAMES: Array[String] = ["Threshold","Obsidian echo","Sunken echo","Ashen echo","Hearth"]
var pilgrim: Node3D
var walking: MeshInstance3D
var guide: Guide
var traveller: Travel = Travel.new()
var tour: bool = false
var tour_finished: bool = false
var travel_samples: int = 0
var chapter_points: Array[Vector3] = []
var view_heading: float = 12.0
func _ready() -> void:
	chapter_heading = "  IV  /  THE MIRRORED ROAD"
	landmark_label = "Hearth"
	extra_controls = ["Travel","Walk all"]
	for i: int in range(5): ruin_owners["n"+str(i)] = NAMES[i]
	marker_extent = 48
	if get_viewport().get_visible_rect().size.x<900:
		chapter_heading = "  IV / MIRRORED ROAD"
		control_extent = 48
	super._ready()
	for b: Button in markers.values():
		var normal: StyleBox = b.get_theme_stylebox("normal")
		for state: String in ["hover","pressed","focus"]: b.add_theme_stylebox_override(state,normal)
	guide = Guide.new()
	world.add_child(guide)
	assert(guide.configure(data,walking,camera))
	focus_journey()
func _select(id: String, type: String) -> void:
	super._select(id,type)
	guide.show_state(selected,whole,markers_visible)
func _action(action: String) -> void:
	if action in ["Travel","Walk all"]:
		_start_travel(action=="Walk all")
		return
	traveller.cancel()
	super._action(action)
func _start_travel(all: bool) -> void:
	var points: Array[Vector3] = []
	var edges: Dictionary = data["edges"]
	if all:
		for edge: String in MapLayoutCanonical.sorted_keys(edges):
			var values: PackedVector3Array = guide.paths[edge]
			for p: Vector3 in values:
				if points.is_empty() or points[-1].distance_to(p)>.001: points.append(p)
	else:
		var id: String = Guide.selection(data,selected)
		if id.is_empty():
			detail.text = "  Select the available next event, then Travel"
			return
		var values: PackedVector3Array = guide.paths[id]
		points.assign(values)
	var headings: Array[float] = []
	headings.resize(points.size())
	headings.fill(view_heading)
	assert(traveller.begin(points,headings,4.8,35))
	tour = all
	tour_finished = false
	whole = false
	detail.text = "  Window to hearth · read-only journey" if all else "  Following the selected approach · read-only"
func _process(delta: float) -> void:
	if traveller.active:
		var frame: Dictionary = traveller.advance(delta)
		var at: Vector3 = frame["point"]
		if pilgrim!=null: pilgrim.position = at-Vector3.UP*.20
		_pose(at+Vector3(0,3,0),32,view_heading)
		travel_samples += 1
		if frame["finished"]:
			tour_finished = tour
			detail.text = "  Journey complete · the saved run is unchanged"
	super._process(delta)
	if guide!=null: guide.show_state(selected,whole,markers_visible)
func _pose(at: Vector3, size_value: float, heading: float) -> void:
	super._pose(at,size_value,heading)
	camera.far = 400
func focus_library() -> void:
	whole = false
	var end: Vector3 = anchors["n4"]
	_frame([end+Vector3(-8,0,-13),end+Vector3(8,6,3)],false,view_heading)
func focus_journey() -> void:
	super.focus_journey()
	detail.text = "  Select the next event, then Travel · Walk all previews the complete journey"
func focus_whole() -> void:
	_frame(chapter_points,true,view_heading)
	detail.text = "  Gold: travelled · lilac: next · grey: later · the five-stop route is fixed"
func focus_stop(id: String) -> void:
	var at: Vector3 = anchors[id]
	_frame([at+Vector3(-7,0,-5),at+Vector3(7,6,5)],false,view_heading)
func focus_window() -> void:
	var start: Vector3 = anchors["n0"]
	_frame([start+Vector3(-15,0,-9),start+Vector3(15,28,3)],false,view_heading)
func exercise_guidance() -> Dictionary:
	var before: String = JSON.stringify(data)
	var failures: Array[String] = []
	for id: String in data["reachable"]:
		focus_stop(id)
		await RenderingServer.frame_post_draw
		var marker: Button = markers[id]
		await _click(marker.get_global_rect().get_center())
		if selected!=id: failures.append("actual next-node selection failed")
		if guide.selected_edge!=Guide.selection(data,id): failures.append("wrong selected edge")
		var button: Button = controls["Travel"]
		await _click(button.get_global_rect().get_center())
		if not traveller.active: failures.append("actual Travel input failed")
		if not traveller.points.is_empty():
			var target: Vector3 = anchors[id]
			if Vector2(traveller.points[-1].x-target.x,traveller.points[-1].z-target.z).length()>.001: failures.append("wrong travel target")
		traveller.cancel()
	focus_whole()
	if guide.paths.size()!=4: failures.append("incomplete overview")
	if JSON.stringify(data)!=before: failures.append("source mutation")
	return {"ok":failures.is_empty(),"failures":failures,"support_samples":guide.sampled_points,"source_unchanged":JSON.stringify(data)==before}
