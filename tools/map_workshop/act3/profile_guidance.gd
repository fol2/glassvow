extends "res://tools/map_workshop/act3/precinct_study.gd"
## Measure actual selected-route and complete-network rendering after native boot.
func _initialize() -> void:
	_run.call_deferred()
	_profile.call_deferred()
func _profile() -> void:
	var inspector: Inspector
	for frame: int in range(1200):
		await process_frame
		for child: Node in root.get_children():
			if child is Inspector:
				inspector = child as Inspector
		if inspector != null and inspector.guidance != null and inspector.guidance.overview != null:
			break
	if inspector == null:
		push_error("Guidance profiler could not find the native inspector")
		quit(1)
		return
	for mode: String in ["selected","overview"]:
		if mode == "selected":
			inspector.focus_journey()
			var id: String = str(inspector.data["reachable"][0])
			inspector._select(id,"event")
		else:
			inspector.focus_whole()
		for frame: int in range(10): await process_frame
		var result: Dictionary = await preload("res://tools/map_workshop/common/viewport_profile.gd").measure(root)
		result["mode"] = mode
		result["draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		result["surface_samples"] = inspector.guidance.sampled_points
		print("GUIDANCE_TIMING ",JSON.stringify(result))
	quit()
