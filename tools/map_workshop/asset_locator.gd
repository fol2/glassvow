extends Control
## Optional review-only marker at the projected ground pivot of a placed asset.
var point: Vector2
var caption: String
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label: Label = Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size",20)
	label.add_theme_color_override("font_color",Color("f8dfac"))
	label.add_theme_color_override("font_shadow_color",Color("151319"))
	label.add_theme_constant_override("shadow_outline_size",5)
	label.position = point+Vector2(28,-13)
	add_child(label)
	queue_redraw()
func _draw() -> void:
	draw_circle(point,17,Color("161319"),false,6,true)
	draw_circle(point,17,Color("f6cf80"),false,2,true)
	draw_line(point+Vector2(-7,0),point+Vector2(7,0),Color("f6cf80"),1.5,true)
	draw_line(point+Vector2(0,-7),point+Vector2(0,7),Color("f6cf80"),1.5,true)
