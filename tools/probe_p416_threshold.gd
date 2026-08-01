extends SceneTree
## Throwaway probe for the P4.16 threshold screen. No fresh save can reach it
## (needs a six-shard vigil), so it is built bare and driven through both CTA
## states, photographing each.
##   godot --path . --position -4000,-4000 -s res://tools/probe_p416_threshold.gd

var _screen: ThresholdScreen
var _touched: int = 0
var _vigil: int = 0
var _failed: bool = false
var _passed: int = 0


func _initialize() -> void:
	var host: Control = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)

	_screen = ThresholdScreen.new()
	_screen.threshold_touched.connect(func() -> void: _touched += 1)
	_screen.vigil_requested.connect(func() -> void: _vigil += 1)
	host.add_child(_screen)
	_drive()


func _drive() -> void:
	await process_frame
	await process_frame

	var lit: int = 0
	for node: Node in _screen.find_children("", "TextureRect", true, false):
		var rect: TextureRect = node
		var material: ShaderMaterial = rect.material as ShaderMaterial
		if material == null:
			continue
		var shows: bool = material.get_shader_parameter("show_mural") == true
		if shows:
			lit += 1
	if not _check(lit == 6, "six lit panes (got %d)" % lit):
		return

	var cta: Button = _find_cta()
	if not _check(cta != null, "CTA button exists"):
		return
	if not _check(cta.text == "Stand at the Threshold",
			"CTA opens as Stand at the Threshold (got %s)" % cta.text):
		return
	if not _check(cta.has_focus(), "CTA holds first-frame focus"):
		return
	var answer: Label = _find_label("The glass holds fast. The way is not yet cut.")
	if not _check(answer != null, "honest copy exists in tree"):
		return
	var answer_box: CanvasItem = answer.get_parent() as CanvasItem
	if not _check(answer_box.modulate.a == 0.0, "honest copy at zero alpha before touch"):
		return
	var cta_rect: Rect2 = cta.get_global_rect()
	_save("/tmp/p416-probe-before.png")

	cta.pressed.emit()
	await process_frame
	await process_frame
	if not _check(_touched == 1, "threshold_touched fired once (got %d)" % _touched):
		return
	if not _check(answer_box.modulate.a > 0.0, "honest copy fading in after touch"):
		return
	# The reveal must cost no relayout: a moving CTA turns the second press
	# into a dead click at the first press's coordinates (PR #55 MAJOR 1).
	if not _check(cta.get_global_rect().is_equal_approx(cta_rect),
			"CTA rect unmoved by the reveal (%s -> %s)"
			% [cta_rect, cta.get_global_rect()]):
		return
	if not _check(cta.text == "Return to the Vigil",
			"CTA becomes Return to the Vigil (got %s)" % cta.text):
		return
	if not _check(cta.has_focus(), "CTA keeps focus after the retitle"):
		return
	_save("/tmp/p416-probe-after.png")

	# Two frames in, the fade is still running: this press must complete the
	# reveal, not leave — a stray double-tap cannot skip the payoff.
	cta.pressed.emit()
	await process_frame
	if not _check(_vigil == 0, "press inside the fade does not leave (got %d)" % _vigil):
		return
	if not _check(answer_box.modulate.a == 1.0,
			"press inside the fade completes the reveal (alpha %.2f)"
			% answer_box.modulate.a):
		return

	cta.pressed.emit()
	await process_frame
	if not _check(_vigil == 1, "vigil_requested fired once (got %d)" % _vigil):
		return
	if not _check(_touched == 1, "threshold_touched did not replay (got %d)" % _touched):
		return

	print("PASS: threshold probe (%d checks)" % _passed)
	quit(0)


func _find_cta() -> Button:
	for node: Node in _screen.find_children("", "Button", true, false):
		return node
	return null


func _find_label(wanted: String) -> Label:
	for node: Node in _screen.find_children("", "Label", true, false):
		var label: Label = node
		if label.text == wanted:
			return label
	return null


func _check(ok: bool, what: String) -> bool:
	if ok:
		_passed += 1
		print("  ok: " + what)
		return true
	_failed = true
	print("FAIL: " + what)
	quit(1)
	return false


func _save(path: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("wrote " + path)
