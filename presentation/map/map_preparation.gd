extends Control
## A quiet, honest loading state; no invented percentage or completion time.
var _elapsed: float = 0.0

func _init(chapter: String) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal=Control.GROW_DIRECTION_BOTH
	column.grow_vertical=Control.GROW_DIRECTION_BOTH
	column.offset_left=-240
	column.offset_right=240
	column.offset_top=-12
	column.add_theme_constant_override("separation",16)
	column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var title: Label = Label.new()
	title.text=chapter
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font",RunStyle.tracked(GlassStyle.CINZEL_500, 2))
	title.add_theme_font_size_override("font_size",24)
	title.add_theme_color_override("font_color",Color("d0b782"))
	column.add_child(title)
	var description: Label = Label.new()
	description.text=Locale.active.t("ui.pilgrimage.preparing")
	description.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_font_override("font",RunStyle.tracked(GlassStyle.ALEGREYA_400, 0))
	description.add_theme_font_size_override("font_size",20)
	description.add_theme_color_override("font_color",Color("aaa6b5"))
	column.add_child(description)

func _process(delta: float) -> void:
	_elapsed+=delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0b0d14"))
	var centre: Vector2 = size*.5-Vector2(0,66)
	for i: int in range(5):
		var glow: float = .5 if Preferences.active.reduce_motion else .35+.35*(.5+.5*sin(_elapsed*2.0-i*.65))
		draw_circle(centre+Vector2((i-2)*15,0),2.0,Color(.82,.69,.43,glow),true,-1,true)
