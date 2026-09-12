extends "res://tools/map_workshop/act4/study.gd"
func _initialize() -> void:
	_run.call_deferred()
	_measure.call_deferred()
func _measure() -> void:
	for frame: int in range(900):
		await process_frame
		if inspector!=null and inspector.guide!=null: break
	assert(inspector!=null)
	for mode: String in ["journey","overview"]:
		if mode=="journey": inspector.focus_journey()
		else: inspector.focus_whole()
		var result: Dictionary = await preload("res://tools/map_workshop/common/viewport_profile.gd").measure(root)
		result["mode"] = mode
		result["viewport"] = [dimensions.x,dimensions.y]
		print("ACT4_TIMING ",JSON.stringify(result))
	quit()
