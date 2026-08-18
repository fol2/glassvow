extends RefCounted
## #382: phone-landscape wraps the location title. pad-portrait chrome is retired.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_run_hud: %s" % what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var run: RunState = RunState.new()
	var phone_landscape: RunHud = RunHud.new(run, content, &"phone-landscape")
	var pad_landscape: RunHud = RunHud.new(run, content, &"pad-landscape")
	_check(fails, phone_landscape._shape_value(110, 170) == 110,
		"phone-landscape takes compact metrics")
	_check(fails, pad_landscape._shape_value(110, 170) == 170,
		"pad-landscape keeps roomy metrics")
	_check(fails, phone_landscape._hp_wrap.custom_minimum_size.x == 110,
		"phone-landscape HP wrap is compact")
	_check(fails, phone_landscape._row.get_theme_constant("separation") == 10,
		"phone-landscape row gap is compact")
	_check(fails, pad_landscape._row.get_theme_constant("separation") == 18,
		"pad-landscape row gap stays roomy")
	_check(fails, phone_landscape._title.visible,
		"phone-landscape shows the location title")
	_check(fails, phone_landscape._title.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		"phone-landscape wraps the location title")
	_check(fails, phone_landscape._title.max_lines_visible == 2,
		"phone-landscape location title is two lines")
	_check(fails, phone_landscape._top.offset_bottom == 62.0,
		"phone-landscape wrap bar stays 62")
	_check(fails, pad_landscape._title.autowrap_mode == TextServer.AUTOWRAP_OFF,
		"pad-landscape keeps a single-line title")
	_check(fails, pad_landscape._title.visible,
		"pad-landscape shows the location title")
	phone_landscape.free()
	pad_landscape.free()
