extends "res://tools/map_workshop/act4/study.gd"
## Uncut native traversal through all five stops via the actual Walk all button.
func _initialize() -> void:
	_run.call_deferred()
	_film.call_deferred()
func _film() -> void:
	for frame: int in range(900):
		await process_frame
		if inspector!=null and inspector.guide!=null: break
	assert(inspector!=null)
	for frame: int in range(4): await process_frame
	var before: String = JSON.stringify(sample)
	inspector.focus_window()
	await create_timer(2).timeout
	var button: Button = inspector.controls["Walk all"]
	await inspector._click(button.get_global_rect().get_center())
	assert(inspector.traveller.active)
	var samples: int = 0
	var errors: Array[String] = []
	for frame: int in range(2400):
		await process_frame
		var p: Vector3 = inspector.pilgrim.global_position
		var projected: Vector2 = camera.unproject_position(p+Vector3.UP)
		if not Rect2(Vector2(0,80),Vector2(dimensions)-Vector2(0,120)).has_point(projected): errors.append("Traveller outside usable view")
		samples += 1
		if not inspector.traveller.active: break
	if not inspector.tour_finished: errors.append("Full journey did not finish")
	var last_raw: Array = sample["anchors"]["n4"]
	if inspector.pilgrim.position.distance_to(M.v3(last_raw))>.03: errors.append("Wrong journey endpoint")
	if JSON.stringify(sample)!=before: errors.append("Snapshot changed")
	inspector.focus_library()
	await create_timer(2).timeout
	inspector.focus_whole()
	await create_timer(2).timeout
	print("ACT4_TOUR ",JSON.stringify({"ok":errors.is_empty(),"failures":errors,"travel_frames":samples,"stops":5,"source_unchanged":JSON.stringify(sample)==before}))
	quit(0 if errors.is_empty() else 1)
