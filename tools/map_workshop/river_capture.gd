extends RefCounted
## Fixed-timestep native frames expose the real material motion for review.
const River = preload("res://presentation/map/landscape/river.gd")
static func record(view: Control, tree: SceneTree, directory: String) -> bool:
	var land: Node3D = view.terrain
	var river: River = land.get_node("Stream") as River
	river.animate = false
	DirAccess.make_dir_recursive_absolute(directory)
	for frame: int in range(241):
		river.set_time(frame/30.0)
		await tree.process_frame
		await RenderingServer.frame_post_draw
		var saved: Error = tree.root.get_texture().get_image().save_png(directory.path_join("%04d.png" % frame))
		if saved!=OK:
			push_error("Cannot save native river animation frame")
			return false
	print("WORKSHOP_RIVER_MOTION 240 playback frames plus closing frame; 30 fps; 8 seconds; native material time 0..8")
	return true
