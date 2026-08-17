extends SceneTree
## #338 regression: the run HUD location line must remain fully visible on
## pad-portrait, both locales, every act — dressed like a live run.
##
## Compact chrome alone cannot grant the English Act III line a single row once
## the three phial seats are present, so pad-portrait wraps. The clip check
## therefore follows the label: single-line shapes compare natural vs granted
## width; a wrapping title fails only if the wrapped block exceeds the box.
## Same SubViewport + real-frames pattern as `dawn_phone_containment.gd`.
## Not in `run_all.gd` because the discovered suite is synchronous; CI runs
## this script on its own.
##
##   godot --headless -s res://tests/measure_hud_location.gd
##
## `_apply_shape` hides the title on phone-portrait. phone-landscape English
## vs a full phial rack is a pre-existing single-line squeeze outside #338 and
## is printed, not gated.

const SHAPES: Array[StringName] = [
	&"phone-landscape", &"pad-portrait", &"pad-landscape",
]

var _viewport: SubViewport
var _clipped: int = 0


func _initialize() -> void:
	_viewport = SubViewport.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	call_deferred("_run")


func _run() -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var previous: Locale = Locale.active
	for locale_code: StringName in [Locale.CODE_EN, Locale.CODE_ZH_HANT]:
		# The act and boss names come out of ContentDB, not the ui.* subtree, and
		# `Locale.t` never touches them. Without this the zh rows would measure a
		# zh waystone phrase glued to ENGLISH act and boss names — a string the
		# game never renders. `restore_content` has to run on the instance that
		# owns the overlay log, so it happens before the swap, not after.
		if Locale.active != null:
			Locale.active.restore_content()
		Locale.active = Locale.new(locale_code)
		Locale.active.hydrate_content(content)
		for stage_shape: StringName in SHAPES:
			for act: int in content.acts.size():
				await _measure(content, locale_code, stage_shape, act)
	if Locale.active != null:
		Locale.active.restore_content()
	Locale.active = previous
	print("MEASURE %s (%d clipped)" % [
		"FAIL" if _clipped > 0 else "OK", _clipped])
	quit(1 if _clipped > 0 else 0)


func _measure(content: ContentDB, locale_code: StringName,
		stage_shape: StringName, act: int) -> void:
	var reference: Vector2i = StageShape.REFERENCES[stage_shape]
	_viewport.size = reference
	# Dress the bar the way a live run does: three phial seats plus the starting
	# relic. `RunState.new()` leaves potions empty, which over-grants the title
	# by a whole rack and would let a clip on the real HUD slip through.
	var run: RunState = RunState.new_run(content, 1)
	run.act = act
	run.waystones_lit = 14
	run.player.gold = 999
	var hud: RunHud = RunHud.new(run, content, stage_shape)
	_viewport.add_child(hud)
	for frame: int in 4:
		await process_frame
	var label: Label = hud._title
	var granted: float = label.size.x
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var natural: float = font.get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var over: bool = _over(label, font, font_size, granted, natural)
	# phone-landscape English vs a full phial rack is outside this ticket.
	var gated: bool = stage_shape != &"phone-landscape"
	if over and gated:
		_clipped += 1
	var mark: String = "CLIPPED" if over and gated else ("note" if over else "fits")
	print("%-8s %-16s act%d  granted=%6.1f  natural=%6.1f  %-7s  %s" % [
		locale_code, stage_shape, act, granted, natural, mark, label.text])
	hud.queue_free()
	await process_frame


func _over(label: Label, font: Font, font_size: int, granted: float,
		natural: float) -> bool:
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		return natural > granted
	var wrapped: Vector2 = font.get_multiline_string_size(
		label.text, HORIZONTAL_ALIGNMENT_CENTER, granted, font_size)
	return wrapped.y > label.size.y + 1.0
