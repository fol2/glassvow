extends SceneTree
## Print the composition a shape actually resolves to, in stage px.
##
## The benchmark can be measured through the DOM — `#stage` is the reference
## size and every element's client rect divided by the stage transform IS stage
## px. This port had no equivalent: a capture shows where something LOOKS like it
## is, and eyeballing a 390px screenshot is how a 12px error survives.
##
## So: build the real `CombatScreen` at a shape, let it lay out, and read the
## nodes back. Headless, so it costs no window and no focus.
##
##   godot --headless -s res://tools/probe_layout.gd -- --shape=phone-portrait --act=0
##   godot --headless -s res://tools/probe_layout.gd -- --all
##
## Numbers are gaps from the edge each one is bound to, so they can be compared
## with the book without arithmetic.

const SHAPES: Array[StringName] = [
	&"pad-landscape", &"desktop-landscape", &"pad-portrait",
	&"phone-portrait", &"phone-landscape",
]


func _initialize() -> void:
	var shapes: Array[StringName] = []
	var act: int = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shape="):
			shapes.append(StringName(arg.trim_prefix("--shape=")))
		elif arg.begins_with("--act="):
			act = clampi(int(arg.trim_prefix("--act=")), 0, LayoutBook.ACTS - 1)
		elif arg == "--all":
			shapes = SHAPES.duplicate()
	if shapes.is_empty():
		shapes = [StageShape.IDENTITY]
	for shape: StringName in shapes:
		await _probe(shape, act)
	quit(0)


func _probe(shape: StringName, act: int) -> void:
	var content: ContentDB = ContentDB.load_slice()
	var game: GlassvowGame = GlassvowGame.new(content, RunState.new_run(content, 7))
	var ref: Vector2i = StageShape.REFERENCES[shape]
	var screen: CombatScreen = CombatScreen.new(game, shape, act)
	# The screen anchors to its parent, and headless has no window of the right
	# size — so it is given the reference frame explicitly rather than inheriting
	# whatever the boot window happened to be.
	var host: Control = Control.new()
	host.size = Vector2(ref)
	root.add_child(host)
	host.add_child(screen)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.start_encounter(["duskfang"], "normal", "probe")
	# Long enough for the entrance to finish. Actors slide in and the chrome
	# rises 44px behind them, so a probe that reads after a dozen frames reports
	# the animation rather than the composition — the energy orb came back 44px
	# low and the hero 11px left of where they settle.
	for _i: int in range(4):
		await create_timer(0.6).timeout
	print("=== %s  act %d  %dx%d" % [shape, act, ref.x, ref.y])
	for row: Array in _rows(screen, Vector2(ref)):
		print("  %-14s %s" % [row[0], row[1]])
	host.queue_free()
	await process_frame


## Every box worth comparing, as gaps from the stage edges.
func _rows(screen: CombatScreen, stage: Vector2) -> Array[Array]:
	var out: Array[Array] = []
	var origin: Vector2 = screen.global_position
	var say: Callable = func(label: String, node: Node) -> void:
		var c: Control = node as Control
		if c == null:
			out.append([label, "(absent)"])
			return
		var xf: Transform2D = c.get_global_transform()
		var pos: Vector2 = xf.origin - origin
		var span: Vector2 = c.size * xf.get_scale()
		out.append([label, "l%.0f t%.0f w%.0f h%.0f  r%.0f b%.0f" % [
			pos.x, pos.y, span.x, span.y,
			stage.x - pos.x - span.x, stage.y - pos.y - span.y]])
	for name: String in ["_hud", "_hand", "_battlefield", "_hero", "_kindle_toggle"]:
		say.call(name.trim_prefix("_"), screen.get(name))
	# The three plates are anonymous children of the shake host, added in paint
	# order — backdrop, mid, ledge (`combat_screen.gd:904-907`). Named here by
	# that order rather than by a field, because the screen keeps no handles.
	var host: Node = screen.get("_shake_host")
	if host != null:
		var plates: Array[Node] = []
		for kid: Node in host.get_children():
			# `Plate` is an inner class with no `class_name`, so it is recognised
			# by the two properties only it has.
			if kid is Control and "amp" in kid and "period" in kid:
				plates.append(kid)
		for i: int in plates.size():
			var label: String = LayoutBook.LAYERS[i] if i < LayoutBook.LAYERS.size() \
				else "plate%d" % i
			say.call(label, plates[i])
	var hud: Node = screen.get("_hud")
	if hud != null:
		for widget: String in ["_energy_orb", "_lantern", "_end_turn"]:
			say.call(widget.trim_prefix("_"), hud.get(widget))
	return out
