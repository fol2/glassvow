extends Control
## Excluded Development Console. Routes Scenarios; never a rubric.

signal closed

const LOCALE_DIR: String = "res://presentation/dev/locale/"
const WIDTH: float = 420.0

var shape: StringName
var _host: Object
var _content: ContentDB
var _sfx: SfxBus
var _ref: ScenarioReference = ScenarioReference.new()
var _panel: PanelContainer
var _scroll: ScrollContainer
var _field: TextEdit
var _status: Label


static func entry_label() -> String:
	return _t("entry")


static func _t(key: String) -> String:
	var requested: Dictionary = _bundle(String(Locale.active.code))
	if requested.has(key):
		return str(requested[key])
	return str(_bundle("en").get(key, key))


static func _bundle(code: String) -> Dictionary:
	var path: String = "%s%s.json" % [LOCALE_DIR, code]
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _init(host: Object, stage_shape: StringName = StageShape.IDENTITY,
		sfx: SfxBus = null) -> void:
	_host = host
	var raw: Variant = host.get("content")
	if raw is ContentDB:
		_content = raw
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = GlassStyle.theme()
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	_ref.load_from({"id": "custom", "revision": 1})
	_build()
	resized.connect(_fit)
	_fit.call_deferred()


func _build() -> void:
	var scrim: ColorRect = ColorRect.new()
	scrim.color = GlassStyle.scrim()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim)
	add_child(scrim)
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", RunStyle.panel())
	centre.add_child(_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	column.add_child(_label(_t("title").to_upper(), 16, RunStyle.GOLD, true))
	column.add_child(_label(_t("banner"), 15, RunStyle.GOLD, false))
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)
	body.add_child(_label(_t("catalogue").to_upper(), 13, RunStyle.GOLD, false))
	for id_v: Variant in ScenarioReference.CATALOGUE.keys():
		var id: String = str(id_v)
		var rev: int = int(float(str(ScenarioReference.CATALOGUE[id_v])))
		body.add_child(_btn("%s@%d" % [id, rev], _pick.bind(id, rev)))
	body.add_child(_label(_t("reference").to_upper(), 13, RunStyle.GOLD, false))
	_field = TextEdit.new()
	_field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_field.custom_minimum_size.y = RunStyle.hit_floor(88.0)
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.text = JSON.stringify(_ref.encode())
	body.add_child(_field)
	var clip: HBoxContainer = HBoxContainer.new()
	clip.add_theme_constant_override("separation", 8)
	clip.add_child(_btn(_t("paste"), _paste))
	clip.add_child(_btn(_t("copy"), _copy_ref))
	body.add_child(clip)
	_status = _label("", 13, RunStyle.DANGER, false)
	body.add_child(_status)
	body.add_child(_btn(_t("start"), _start))
	body.add_child(_btn(_t("reset"), _reset))
	body.add_child(_btn(_t("restart"), _restart))
	body.add_child(_btn(_t("clear"), _clear))
	column.add_child(_btn(_t("close"), _close))


func _label(text: String, size_px: int, colour: Color, centred: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centred:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", GlassStyle.face(GlassStyle.CINZEL_500))
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", colour)
	return label


func _btn(text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = RunStyle.hit_floor(44.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RunStyle.style_button(button)
	button.pressed.connect(func() -> void:
		_sfx.play(&"click")
		action.call()
	)
	return button


func set_shape(stage_shape: StringName) -> void:
	if StageShape.REFERENCES.has(stage_shape):
		shape = stage_shape
		_fit()


func _fit() -> void:
	if _panel == null or size.x <= 0.0 or size.y <= 0.0:
		return
	_panel.custom_minimum_size.x = minf(WIDTH, maxf(280.0, size.x - 24.0))
	_scroll.custom_minimum_size.y = maxf(220.0, size.y - 160.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _on_scrim(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()
	elif event is InputEventScreenTouch and event.pressed:
		_close()


func _close() -> void:
	closed.emit()

func _pick(id: String, rev: int) -> void:
	_ref = ScenarioReference.new()
	_ref.load_from({"id": id, "revision": rev})
	_field.text = JSON.stringify(_ref.encode())
	_status.text = ""


func _copy_ref() -> void:
	if _absorb_field():
		DisplayServer.clipboard_set(JSON.stringify(_ref.encode()))

func _paste() -> void:
	_field.text = DisplayServer.clipboard_get()
	_absorb_field()


func _absorb_field() -> bool:
	var parsed: Variant = JSON.parse_string(_field.text)
	var next: ScenarioReference = ScenarioReference.new()
	if typeof(parsed) != TYPE_DICTIONARY:
		_status.text = _t("unreadable")
		return false
	var blob: Dictionary = parsed
	if not next.load_from(blob):
		_status.text = next.error if not next.error.is_empty() else _t("unreadable")
		return false
	_ref = next
	_status.text = ""
	return true


func _apply(ref: ScenarioReference) -> void:
	if not _host.has_method("apply_dev_scenario"):
		return
	var ok: Variant = _host.call("apply_dev_scenario", ref)
	if ok != true:
		_status.text = _t("failed")


func _start() -> void:
	if _absorb_field():
		_apply(_ref)


func _reset() -> void:
	var kernel: ScenarioKernel = ScenarioKernel.new(_content)
	var stored: ScenarioReference = kernel.load_reference()
	if stored == null:
		_status.text = kernel.last_error
		return
	_apply(stored)


func _restart() -> void:
	if not _absorb_field():
		return
	ScenarioKernel.new(_content).clear_profile()
	_apply(_ref)


func _clear() -> void:
	ScenarioKernel.new(_content).clear_profile()
	_status.text = ""
