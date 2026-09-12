extends RefCounted
## Native fixed-step recording of the same journey and camera used interactively.
static func record(view: Control, tree: SceneTree, directory: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:
		return false
	view.journey.set_process(false)
	view.rig.set_process(false)
	var river: Node = view.terrain.get_node("Stream")
	river.animate = false
	var next: Array[int] = view.world_map.reachable()
	if next.is_empty():
		return false
	var target: int = next[0]
	for frame: int in range(420):
		if frame==30:
			view._select(target)
		if frame==90:
			view._travel()
		if frame==270:
			view.focus_all()
		if frame==360:
			view.focus_journey()
		view.journey.advance(1.0/30)
		view.rig._process(1.0/30)
		river.set_time(frame/30.0)
		await tree.process_frame
		await RenderingServer.frame_post_draw
		var error: Error = tree.root.get_texture().get_image().save_png(directory.path_join("frame-%04d.png" % frame))
		if error!=OK:
			return false
	print("JOURNEY_FILM ",JSON.stringify({"frames":420,"seconds":14,"target":target,"arrived":view.world_map.at==target,"completed_steps":view.step_count}))
	return view.world_map.at==target and view.step_count==1
