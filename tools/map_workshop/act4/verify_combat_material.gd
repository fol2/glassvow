extends SceneTree
## Native alpha/modulation regression, including inherited translucent canvas colour.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1536,789)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var parent: Control = Control.new()
	parent.modulate = Color(.8,.9,1,.6)
	viewport.add_child(parent)
	var plate: TextureRect = TextureRect.new()
	plate.texture = load("res://assets/art/stage/act4-ledge.png")
	plate.size = Vector2(1536,789)
	plate.modulate = Color(.9,.8,1,.37)
	parent.add_child(plate)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var before: Image = viewport.get_texture().get_image()
	plate.material = preload("res://presentation/stage/mirrored_finish.gd").combat()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var after: Image = viewport.get_texture().get_image()
	var alpha_error: float = 0
	var changed: int = 0
	var opaque: int = 0
	for y: int in range(0,789,4):
		for x: int in range(0,1536,4):
			var a: Color = before.get_pixel(x,y)
			var b: Color = after.get_pixel(x,y)
			alpha_error = maxf(alpha_error,absf(a.a-b.a))
			if a.a>.2:
				opaque += 1
				if Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()>.01: changed += 1
	assert(alpha_error<=1.0/255.0 and changed>1000 and opaque>1000)
	print("ACT4_COMBAT_MATERIAL ",JSON.stringify({"ok":true,"alpha_max_error":alpha_error,"changed_samples":changed,"opaque_samples":opaque,"inherited_alpha":.6,"plate_alpha":.37,"native":true}))
	quit()
