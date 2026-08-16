extends SceneTree
## #303 measurement harness — does the longer zh location line survive the bar?
##
## `run_hud.gd` gives the title a plain Label with OVERRUN_TRIM_ELLIPSIS and no
## autowrap, so the failure the ticket asks about is not a wrap: it is a silent
## truncation to an ellipsis. This measures the natural text width against the
## width the layout actually grants, per shape, per locale, per act. Same
## SubViewport + real-frames pattern as `dawn_phone_containment.gd`, and for the
## same reason — container geometry needs frames.
##
##   godot --headless -s res://tests/measure_hud_location.gd
##
## Not in `run_all.gd`: this is a one-off ruler for the #303 sign-off, not a
## regression gate. `run_hud.gd:267` hides the title on phone-portrait, so the
## narrowest shape it renders at is phone-landscape.

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
		Locale.active = Locale.new(locale_code)
		for stage_shape: StringName in SHAPES:
			for act: int in content.acts.size():
				await _measure(content, locale_code, stage_shape, act)
	Locale.active = previous
	print("MEASURE %s (%d clipped)" % [
		"FAIL" if _clipped > 0 else "OK", _clipped])
	quit(1 if _clipped > 0 else 0)


func _measure(content: ContentDB, locale_code: StringName,
		stage_shape: StringName, act: int) -> void:
	var reference: Vector2i = StageShape.REFERENCES[stage_shape]
	_viewport.size = reference
	var run: RunState = RunState.new()
	run.act = act
	run.floors_climbed = 14
	run.player.gold = 999
	var hud: RunHud = RunHud.new(run, content, stage_shape)
	_viewport.add_child(hud)
	for frame: int in 4:
		await process_frame
	var label: Label = hud._title
	var granted: float = label.size.x
	var natural: float = label.get_theme_font("font").get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		label.get_theme_font_size("font_size")).x
	var over: bool = natural > granted
	if over:
		_clipped += 1
	print("%-8s %-16s act%d  granted=%6.1f  natural=%6.1f  %-7s  %s" % [
		locale_code, stage_shape, act, granted, natural,
		"CLIPPED" if over else "fits", label.text])
	hud.queue_free()
	await process_frame
