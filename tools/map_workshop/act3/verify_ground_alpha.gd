extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(512,192)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rect: TextureRect = TextureRect.new()
	rect.texture = load("res://assets/art/stage/act3-ledge.png")
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.size = Vector2(viewport.size)
	viewport.add_child(rect)
	var failures: int = 0
	for opacity: float in [0.8,0.9,1.0]:
		rect.modulate = Color(1,1,1,opacity)
		rect.material = null
		for i: int in range(4): await process_frame
		await RenderingServer.frame_post_draw
		var before: Image = viewport.get_texture().get_image()
		rect.material = ObsidianFinish.combat()
		for i: int in range(4): await process_frame
		await RenderingServer.frame_post_draw
		var after: Image = viewport.get_texture().get_image()
		failures += _compare(before,after,opacity)
	quit(0 if failures == 0 else 1)

func _compare(before: Image, after: Image, opacity: float) -> int:
	var changed_alpha: int = 0
	var solid: int = 0
	var transparent: int = 0
	for y: int in range(before.get_height()):
		for x: int in range(before.get_width()):
			var alpha: float = before.get_pixel(x,y).a
			if alpha>opacity-.02: solid+=1
			if alpha<.01: transparent+=1
			if absf(alpha-after.get_pixel(x,y).a)>1.01/255.0: changed_alpha+=1
	print("OBSIDIAN_ALPHA ",JSON.stringify({"opacity":opacity,"changed_alpha_pixels":changed_alpha,"solid":solid,"transparent":transparent,"pixels":before.get_width()*before.get_height()}))
	return 0 if changed_alpha==0 and solid>1000 and transparent>100 else 1
