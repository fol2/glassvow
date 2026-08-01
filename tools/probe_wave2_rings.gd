extends SceneTree
## Throwaway probe for the P4.6 wave-2 lantern rings. Two adopters that no
## fresh save can reach on screen: a rose-window pane (needs the emberglass
## unlock) and a lamplighter art button (needs a lamplighter node mid-run).
## Both are built here bare and photographed holding keyboard focus.
##   godot --path . --position -4000,-4000 -s res://tools/probe_wave2_rings.gd

var _rose: RoseWindowView
var _art: Button
var _hud: RunHud


func _initialize() -> void:
	var host: Control = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var ground: ColorRect = ColorRect.new()
	ground.color = Color(0.02, 0.03, 0.06)
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(ground)

	_rose = RoseWindowView.new({}, {}, 0, [])
	_rose.position = Vector2(40.0, 20.0)
	_rose.size = Vector2(520.0, 560.0)
	host.add_child(_rose)

	_art = Button.new()
	_art.custom_minimum_size = Vector2(56.0, 56.0)
	_art.position = Vector2(640.0, 120.0)
	LamplighterScreen._art_style(_art, false)
	host.add_child(_art)

	var content: ContentDB = ContentDB.load_slice()
	var run: RunState = RunState.new_run(content, 12345)
	_hud = RunHud.new(run, content)
	host.add_child(_hud)
	_hud.refresh(run)
	_shoot()


func _shoot() -> void:
	await process_frame
	var panes: Array[Node] = _rose.find_children("", "Button", true, false)
	if panes.is_empty():
		print("no rose pane buttons found")
		quit(1)
		return
	(panes[0] as Button).grab_focus()
	await process_frame
	await process_frame
	_save("/tmp/p46-probe-rose.png")
	_art.grab_focus()
	await process_frame
	await process_frame
	_save("/tmp/p46-probe-lamp.png")
	var hud_buttons: Array[Node] = _hud.find_children("", "Button", true, false)
	if hud_buttons.is_empty():
		print("no run-hud buttons found")
		quit(1)
		return
	(hud_buttons[hud_buttons.size() - 2] as Button).grab_focus()
	await process_frame
	await process_frame
	_save("/tmp/p46-probe-hud.png")
	quit(0)


func _save(path: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png(path)
	print("saved " + path)
