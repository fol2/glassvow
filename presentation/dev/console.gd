extends Control
## Excluded Development Console. Routes Scenarios; never a rubric.

signal closed

const LOCALE_DIR: String = "res://presentation/dev/locale/"
const WIDTH: float = 420.0
const INT_OV: PackedStringArray = ["aspect", "vow", "act", "hp", "max_hp", "gold"]
const LIST_OV: PackedStringArray = [
	"enemies", "potions", "add_cards", "remove_cards", "upgrade_cards",
	"add_relics", "remove_relics", "shards",
]

var shape: StringName
var _host: Object
var _content: ContentDB
var _sfx: SfxBus
var _ref: ScenarioReference = ScenarioReference.new()
var _panel: PanelContainer
var _scroll: ScrollContainer
var _field: TextEdit
var _status: Label
var _editors: Dictionary = {}
var _painting: bool = false

var _receipt_visible: bool = false
var _receipt_section: VBoxContainer = null
var _receipt_header: Button = null
var _overlay_visible: bool = false
var _diagnostic_overlay: Node = null


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
	body.add_child(_label(_t("custom").to_upper(), 13, RunStyle.GOLD, false))
	body.add_child(_row("seed", _edit(str(_ref.seed))))
	body.add_child(_row("locale", _choice(ScenarioReference.LOCALES, _ref.locale)))
	body.add_child(_row("shape", _choice(_shape_names(), _ref.shape)))
	for key: String in ScenarioReference.OVERRIDE_KEYS:
		body.add_child(_row(key, _edit("")))
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
	body.add_child(_build_receipt_section())
	body.add_child(_btn(_t("diagnostics"), _toggle_diagnostic_overlay))
	column.add_child(_btn(_t("close"), _close))


func _row(key: String, widget: Control) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.add_child(_label(_t(key), 13, RunStyle.GOLD, false))
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	widget.custom_minimum_size.y = RunStyle.hit_floor(44.0)
	_editors[key] = widget
	col.add_child(widget)
	return col


func _edit(text: String) -> LineEdit:
	var box: LineEdit = LineEdit.new()
	box.text = text
	box.text_changed.connect(func(_value: String) -> void: _sync_from_widgets())
	return box


func _choice(ids: PackedStringArray, current: String) -> OptionButton:
	var button: OptionButton = OptionButton.new()
	button.clip_text = true
	for id: String in ids:
		button.add_item(id)
		if id == current:
			button.select(button.item_count - 1)
	button.item_selected.connect(func(_i: int) -> void: _sync_from_widgets())
	return button


func _shape_names() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for name: StringName in StageShape.REFERENCES:
		ids.append(String(name))
	return ids


func _ov_text(key: String) -> String:
	if not _ref.overrides.has(key):
		return ""
	var value: Variant = _ref.overrides[key]
	if typeof(value) != TYPE_ARRAY:
		return str(value)
	var parts: PackedStringArray = PackedStringArray()
	for item: Variant in value:
		parts.append("-" if item == null else str(item))
	return ",".join(parts)


func _text_of(key: String) -> String:
	var raw: Variant = _editors.get(key)
	if raw is LineEdit:
		var box: LineEdit = raw
		return box.text
	if raw is OptionButton:
		var button: OptionButton = raw
		return button.get_item_text(button.selected) if button.selected >= 0 else ""
	return ""


func _set_text(key: String, text: String) -> void:
	var raw: Variant = _editors.get(key)
	if raw is LineEdit:
		var box: LineEdit = raw
		box.text = text
		return
	if raw is OptionButton:
		var button: OptionButton = raw
		for i: int in range(button.item_count):
			if button.get_item_text(i) == text:
				button.select(i)
				return


func _paint() -> void:
	_painting = true
	_set_text("seed", str(_ref.seed))
	_set_text("locale", _ref.locale)
	_set_text("shape", _ref.shape)
	for key: String in ScenarioReference.OVERRIDE_KEYS:
		_set_text(key, _ov_text(key))
	_painting = false


func _parse_ov(key: String, raw: String) -> Variant:
	if key == "shards" and raw.is_valid_int():
		return int(raw)
	if LIST_OV.has(key):
		var items: Array = []
		for part: String in raw.split(","):
			var token: String = part.strip_edges()
			if token.is_empty():
				continue
			items.append(null if token == "-" or token == "null" else token)
		return items
	if (INT_OV.has(key) or key == "node") and raw.is_valid_int():
		return int(raw)
	return raw


func _sync_from_widgets() -> void:
	if _painting:
		return
	var blob: Dictionary = _ref.encode()
	var seed_text: String = _text_of("seed").strip_edges()
	blob["seed"] = int(seed_text) if seed_text.is_valid_int() else seed_text
	blob["locale"] = _text_of("locale")
	blob["shape"] = _text_of("shape")
	var ov: Dictionary = {}
	for key: String in ScenarioReference.OVERRIDE_KEYS:
		var raw: String = _text_of(key).strip_edges()
		if raw.is_empty():
			continue
		ov[key] = _parse_ov(key, raw)
	blob["overrides"] = ov
	var next: ScenarioReference = ScenarioReference.new()
	if not next.load_from(blob):
		_status.text = next.error
		return
	_ref = next
	_field.text = JSON.stringify(_ref.encode())
	_status.text = ""



func _build_receipt_section() -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	var header: Button = Button.new()
	header.text = _t("receipt").to_upper() + (" ▼" if _receipt_visible else " ►")
	header.custom_minimum_size.y = RunStyle.hit_floor(44.0)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RunStyle.style_button(header)
	header.pressed.connect(func() -> void:
		_sfx.play(&"click")
		_receipt_visible = not _receipt_visible
		_refresh_receipt_display()
	)
	section.add_child(header)
	_receipt_header = header
	if _receipt_visible:
		_populate_receipt_content(section)
	_receipt_section = section
	return section

func _populate_receipt_content(section: VBoxContainer) -> void:
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.name = "receipt_content"
	var run: RunState = _get_run_state()
	var snapshot: Dictionary = {
		"scenario": _ref.encode(),
		"seed": _ref.seed,
		"rng_cursor": run.rng_state() if run != null else null,
		"locale": str(Locale.active.code) if Locale.active else "en",
		"shape": str(shape),
		"act": run.act if run != null else 0,
		"node": run.node_id if run != null else null,
		"hp": run.hp if run != null else 0,
		"gold": run.gold if run != null else 0,
	}
	if run != null:
		snapshot["fingerprint"] = ScenarioKernel.fingerprint(run)
	content.add_child(_label("NOT RELEASE EVIDENCE", 11, RunStyle.DANGER, false))
	var json_text: TextEdit = TextEdit.new()
	json_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	json_text.custom_minimum_size.y = RunStyle.hit_floor(88.0)
	json_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	json_text.text = JSON.stringify(snapshot)
	json_text.editable = false
	content.add_child(json_text)
	var copy_btn: Button = _btn(_t("copy_receipt"), func() -> void:
		DisplayServer.clipboard_set(json_text.text)
	)
	content.add_child(copy_btn)
	section.add_child(content)

func _refresh_receipt_display() -> void:
	if _receipt_header == null or _receipt_section == null:
		return
	_receipt_header.text = _t("receipt").to_upper() + (" ▼" if _receipt_visible else " ►")
	var old_content: Node = _receipt_section.find_child("receipt_content")
	if old_content != null:
		old_content.queue_free()
	if _receipt_visible:
		_populate_receipt_content(_receipt_section)

func _get_run_state() -> Variant:
	if _host == null:
		return null
	var g: Variant = _host.get("game")
	if g is GlassvowGame:
		var game: GlassvowGame = g
		if game.run != null:
			return game.run
	return null

func _toggle_diagnostic_overlay() -> void:
	_overlay_visible = not _overlay_visible
	if _overlay_visible:
		_show_diagnostic_overlay()
	else:
		_hide_diagnostic_overlay()

func _show_diagnostic_overlay() -> void:
	if _diagnostic_overlay != null:
		return
	var script: GDScript = load("res://presentation/dev/diagnostic_overlay.gd") as GDScript
	if script == null:
		return
	_diagnostic_overlay = script.new()
	if _diagnostic_overlay is Node:
		get_tree().root.add_child(_diagnostic_overlay)

func _hide_diagnostic_overlay() -> void:
	if _diagnostic_overlay != null and _diagnostic_overlay is Node:
		_diagnostic_overlay.queue_free()
		_diagnostic_overlay = null

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
	var blob: Dictionary = {"id": id, "revision": rev}
	var script: GDScript = load("res://presentation/dev/catalogue.gd") as GDScript
	if script != null:
		var found: Variant = script.call("recipe_for", id)
		if typeof(found) == TYPE_DICTIONARY:
			var entry: Dictionary = found
			if not entry.is_empty():
				blob["seed"] = int(float(str(entry.get("seed", 0))))
				var ov_v: Variant = entry.get("overrides", {})
				var ov: Dictionary = ov_v if typeof(ov_v) == TYPE_DICTIONARY else {}
				blob["overrides"] = ov.duplicate(true)
	_ref = ScenarioReference.new()
	_ref.load_from(blob)
	_field.text = JSON.stringify(_ref.encode())
	_status.text = ""
	_paint()


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
	_paint()
	return true


func _apply(ref: ScenarioReference) -> void:
	if not _host.has_method("apply_dev_scenario"):
		return
	var ok: Variant = _host.call("apply_dev_scenario", ref)
	if ok != true:
		var err_v: Variant = _host.get("last_dev_error")
		var err: String = str(err_v) if typeof(err_v) == TYPE_STRING else ""
		_status.text = err if not err.is_empty() else _t("failed")


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
