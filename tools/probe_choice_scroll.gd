extends SceneTree
## PR #43 finding 6 probe: a >7-choice standard ChoiceScreen puts full-width
## buttons inside its clip — the ring must survive at the edges. Focuses a
## button in the scroll and photographs it. Needs a real renderer:
##   godot --path . --position -4000,-4000 -s res://tools/probe_choice_scroll.gd

const ChoiceScreenType: GDScript = preload("res://presentation/run/choice_screen.gd")


func _initialize() -> void:
	var choices: Array[Dictionary] = []
	for i: int in range(9):
		choices.append({"id": "row%d" % i, "label": "CHOICE ROW %d" % (i + 1)})
	var screen: Control = ChoiceScreenType.new(
		"NINE CHOICES", "The scroll must not cut the ring.", choices)
	root.add_child(screen)
	_shoot()


func _shoot() -> void:
	await process_frame
	await process_frame
	var focused: Control = root.get_viewport().gui_get_focus_owner()
	print("focused: ", focused.text if focused is Button else "none")
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/p45r2-scroll.png")
	print("probe saved")
	quit(0)
