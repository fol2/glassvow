extends SceneTree
## Throwaway probe for the P4.6 toggle hover states. The window sits
## off-screen, so a real NOTIFICATION_MOUSE_ENTER can never arrive — each
## hover twin WEARS its hover box and hover glyph colour as its resting
## state instead: the same pixels a genuine hover paints, deterministically.
## The frame answers the DL's PR #40 round-2 minor 2 with a measurement:
## a hovered OFF toggle must stay dimmer than a resting ON one.
##   godot --path . --position -4000,-4000 -s res://tools/probe_toggle_hover.gd


func _initialize() -> void:
	var host: Control = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var ground: ColorRect = ColorRect.new()
	ground.color = Color(0.02, 0.03, 0.06)
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(ground)
	host.add_child(_toggle("OFF", false, false, Vector2(120.0, 120.0)))
	host.add_child(_toggle("OFF", false, true, Vector2(240.0, 120.0)))
	host.add_child(_toggle("ON", true, false, Vector2(120.0, 180.0)))
	host.add_child(_toggle("ON", true, true, Vector2(240.0, 180.0)))
	_shoot()


func _toggle(text: String, on: bool, hovered: bool, at: Vector2) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.position = at
	button.custom_minimum_size = Vector2(76.0, 26.0)
	button.add_theme_font_override("font", load(GlassStyle.CINZEL_500) as Font)
	button.add_theme_font_size_override("font_size", 12)
	SettingsPanel._style_button(button, RunStyle.GOLD, 4.0, 6)
	SettingsPanel._toggle_state(button, on)
	if hovered:
		button.add_theme_stylebox_override("normal",
			button.get_theme_stylebox("hover"))
		button.add_theme_color_override("font_color",
			button.get_theme_color("font_hover_color"))
	return button


func _shoot() -> void:
	await process_frame
	await process_frame
	await process_frame
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png("/tmp/p46-probe-toggle.png")
	print("saved /tmp/p46-probe-toggle.png")
	quit(0)
