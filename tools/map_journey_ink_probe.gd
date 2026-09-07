extends SceneTree
## Measure the actual native raster, including focus marks, against the camera ink envelope.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(2)
		return
	var viewport: SubViewport = SubViewport.new()
	viewport.size=Vector2i(864,288)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for row: int in range(3):
		for col: int in range(GlassWaystone.GLYPH_KINDS.size()):
			var stone: GlassWaystone = GlassWaystone.new(col,GlassWaystone.GLYPH_KINDS[col],210,"",row==2)
			viewport.add_child(stone)
			stone.set_journey_presentation(false,row==1)
			stone.set_touch_min(60,1)
			stone.position=Vector2(col*96+18,row*96+18)
			stone.current=row==2
			stone.reachable=row==2
			stone.set_process(false)
	for frame: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var maximum: float = 0
	var failures: Array = []
	for row: int in range(3):
		for col: int in range(GlassWaystone.GLYPH_KINDS.size()):
			var radius: float = 0
			for y: int in range(96):
				for x: int in range(96):
					if image.get_pixel(col*96+x,row*96+y).a>.01:
						radius=maxf(radius,Vector2(x+.5-48,y+.5-48).length())
			maximum=maxf(maximum,radius)
			if radius>MapJourneyCameraContract.INK_RADIUS_PX:
				failures.append({"glyph":GlassWaystone.GLYPH_KINDS[col],"state":row,"radius":radius})
	print("JOURNEY_INK ",JSON.stringify({"maximum_radius_px":maximum,"limit":MapJourneyCameraContract.INK_RADIUS_PX,"cases":27,"failures":failures}))
	image.save_png("/tmp/glassvow-steps4-8/journey-native-ink.png")
	quit(0 if failures.is_empty() else 1)
