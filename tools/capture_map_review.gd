extends SceneTree
## Temporary #291 visual-acceptance probe. Removed after the artifact is reviewed.
## Compatible with both the PR head and its exact base for paired capture.

const OUTPUT: String = "res://artifacts/map-screenshot.png"
const REVIEW_SIZE: Vector2i = Vector2i(1280, 720)


func _initialize() -> void:
	DisplayServer.window_set_size(REVIEW_SIZE)
	var scene: MapScene = MapScene.new()
	root.add_child(scene)
	scene.position = Vector2.ZERO
	scene.size = Vector2(REVIEW_SIZE)
	scene.set_live(true)
	for _frame: int in range(8):
		await process_frame
	if scene.find_child("MapAssetGeometry", true, false) != null:
		printerr("capture_map_review: fallback unexpectedly replaced")
		quit(1)
		return
	for node_name: String in ["FlatWedges", "StackedSlabs", "DabMasses"]:
		var node: Node = scene.find_child(node_name, true, false)
		if not (node is GeometryInstance3D) or not (node as GeometryInstance3D).visible:
			printerr("capture_map_review: missing fallback %s" % node_name)
			quit(1)
			return
	var image: Image = scene.get_stage().get_texture().get_image()
	if image == null or image.get_width() < 1000 or image.get_height() < 500:
		printerr("capture_map_review: invalid image")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var error: Error = image.save_png(OUTPUT)
	if error != OK:
		printerr("capture_map_review: save failed %s" % error_string(error))
		quit(1)
		return
	print("capture_map_review: %dx%d -> %s" % [image.get_width(), image.get_height(), OUTPUT])
	quit(0)
