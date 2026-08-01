extends SceneTree
## Throwaway probe for the P4.4 lantern ring. Focus is single, so each
## accent gets its own photograph with its own button holding focus, and a
## third frame warps the mouse over the resting button so focus and hover
## sit side by side — the one comparison that settles which state is
## louder. Not a test; needs a real renderer:
##   godot --path . --position -4000,-4000 -s res://tools/probe_focus_ring.gd

var _ember_focus: Button
var _ember_rest: Button
var _glass_focus: Button


func _initialize() -> void:
	var host: Control = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var ground: ColorRect = ColorRect.new()
	ground.color = Color(0.02, 0.03, 0.06)
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(ground)
	host.theme = GlassStyle.theme()
	_ember_focus = _button("FOCUSED", Vector2(120.0, 120.0), GlassStyle.EMBER)
	_ember_rest = _button("AT REST", Vector2(360.0, 120.0), GlassStyle.EMBER)
	_glass_focus = _button("QUIET FOCUSED", Vector2(120.0, 220.0), GlassStyle.GLASS)
	host.add_child(_ember_focus)
	host.add_child(_ember_rest)
	host.add_child(_glass_focus)
	host.add_child(_button("QUIET AT REST", Vector2(360.0, 220.0), GlassStyle.GLASS))
	_shoot()


func _button(text: String, at: Vector2, accent: Color) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.position = at
	button.size = Vector2(200.0, 44.0)
	GlassStyle.style_button(button, accent)
	return button


func _shoot() -> void:
	await process_frame
	_ember_focus.grab_focus()
	await process_frame
	await process_frame
	_save("/tmp/p44-probe-ember.png")
	_glass_focus.grab_focus()
	await process_frame
	await process_frame
	_save("/tmp/p44-probe-glass.png")
	# Focus beside hover: the ember button keeps focus while the pointer
	# rests on its identical neighbour.
	_ember_focus.grab_focus()
	Input.warp_mouse(_ember_rest.get_screen_position() + _ember_rest.size * 0.5)
	await process_frame
	await process_frame
	await process_frame
	_save("/tmp/p44-probe-hover.png")
	print("probe saved")
	quit(0)


func _save(path: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(path)
