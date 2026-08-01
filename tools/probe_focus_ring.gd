extends SceneTree
## Throwaway probe for the P4.4 lantern ring: two identical GlassStyle
## buttons, one holding keyboard focus, photographed side by side.
## Not a test; needs a real renderer:
##   godot --path . -s res://tools/probe_focus_ring.gd


func _initialize() -> void:
	var host: Control = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var ground: ColorRect = ColorRect.new()
	ground.color = Color(0.02, 0.03, 0.06)
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(ground)
	host.theme = GlassStyle.theme()
	var focused: Button = _button("FOCUSED", Vector2(120.0, 120.0), GlassStyle.EMBER)
	host.add_child(focused)
	host.add_child(_button("AT REST", Vector2(360.0, 120.0), GlassStyle.EMBER))
	host.add_child(_button("QUIET FOCUSED", Vector2(120.0, 220.0), GlassStyle.GLASS))
	host.add_child(_button("QUIET AT REST", Vector2(360.0, 220.0), GlassStyle.GLASS))
	_shoot(focused)


func _button(text: String, at: Vector2, accent: Color) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.position = at
	button.size = Vector2(200.0, 44.0)
	GlassStyle.style_button(button, accent)
	return button


func _shoot(focused: Button) -> void:
	await process_frame
	focused.grab_focus()
	print("has_focus: ", focused.has_focus())
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/p44-probe.png")
	print("probe saved")
	quit(0)
