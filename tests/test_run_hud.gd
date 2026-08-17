extends RefCounted
## #338: pad-portrait is 820 px wide and must not wear pad-landscape chrome.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_run_hud: %s" % what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var run: RunState = RunState.new()
	var pad_portrait: RunHud = RunHud.new(run, content, &"pad-portrait")
	var phone_landscape: RunHud = RunHud.new(run, content, &"phone-landscape")
	var pad_landscape: RunHud = RunHud.new(run, content, &"pad-landscape")
	var phone_portrait: RunHud = RunHud.new(run, content, &"phone-portrait")
	_check(fails, pad_portrait._shape_value(96, 110, 170) == 110,
		"pad-portrait takes compact landscape metrics")
	_check(fails, pad_portrait._shape_value(96, 110, 170)
			== phone_landscape._shape_value(96, 110, 170),
		"pad-portrait chrome matches phone-landscape")
	_check(fails, pad_landscape._shape_value(96, 110, 170) == 170,
		"pad-landscape keeps roomy metrics")
	_check(fails, pad_portrait._hp_wrap.custom_minimum_size.x == 110,
		"pad-portrait HP wrap is compact")
	_check(fails, pad_portrait._row.get_theme_constant("separation") == 10,
		"pad-portrait row gap is compact")
	_check(fails, pad_landscape._row.get_theme_constant("separation") == 18,
		"pad-landscape row gap stays roomy")
	_check(fails, pad_portrait._title.visible,
		"pad-portrait still shows the location title")
	_check(fails, pad_portrait._title.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		"pad-portrait wraps the location title")
	_check(fails, pad_landscape._title.autowrap_mode == TextServer.AUTOWRAP_OFF,
		"pad-landscape keeps a single-line title")
	_check(fails, not phone_portrait._title.visible,
		"phone-portrait still hides the location title")
	pad_portrait.free()
	phone_landscape.free()
	pad_landscape.free()
	phone_portrait.free()
