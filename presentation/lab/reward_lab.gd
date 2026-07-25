class_name RewardLab
extends Control
## Stub. The reward lab lands here — this file is a boot harness, nothing else.
##
##   godot --path . -- --reward                       # window, stays open
##   godot --path . -- --reward --shot=/tmp/reward.png  # headless capture

var content: ContentDB


func _init(content_ref: ContentDB) -> void:
	content = content_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()

	var field: ColorRect = ColorRect.new()
	field.color = CardLab.BACKDROP
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)

	var label: Label = Label.new()
	label.text = "RewardLab"
	label.position = Vector2(40.0, 40.0)
	add_child(label)
