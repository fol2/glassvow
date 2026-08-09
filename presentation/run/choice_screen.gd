class_name ChoiceScreen
extends Control
## One quiet glass panel for every non-combat decision. The application owns
## routing and domain mutation; this view only emits the selected id.

signal chosen(id: String)

const TITLE_BACKGROUND: String = "res://assets/art/title-background/background.png"
const TITLE_WORDMARK: String = "res://assets/art/title/title.png"
const ROSE_MURAL: String = "res://assets/art/meta/emberglass-mural.png"
const ROSE_FRAME: String = "res://assets/art/meta/emberglass-frame.png"
const ROSE_MASK: String = "res://assets/art/meta/emberglass-mask-%s.png"
const ROSE_PANE_SHADER: Shader = preload("res://presentation/run/rose_pane.gdshader")
const BANNER_SHADOW_SHADER: Shader = preload("res://presentation/run/drop_shadow.gdshader")

## The title banner, verbatim from `styles.css:341-343`: a plate held at 55% of
## the stage height and 90% of its width, seated 18% up from the bottom, the
## whole group at `opacity: 0.35`, and a `drop-shadow(0 12px 40px rgba(0,0,0,.6))`
## the port had never carried.
const BANNER_ALPHA: float = 0.35
const BANNER_H_RATE: float = 0.55
const BANNER_W_RATE: float = 0.90
const BANNER_LIFT: float = 0.18
const BANNER_SHADOW_BLUR: float = 40.0
const BANNER_SHADOW_DY: float = 12.0
const BANNER_SHADOW_INK: Color = Color(0.0, 0.0, 0.0, 0.6)
const GOLD: Color = Color("#f2c14e")
const PARCHMENT: Color = Color("#e8dfc8")
const BENCH_TEXT_DIM: Color = Color("#8b93ad")

## The panel as authored at the identity shape, and the fallbacks the book's
## `run` scope carries defaults for. Kept as named constants rather than magic
## numbers at the call site so the 1.0 column stays readable next to the book.
const PANEL_W: float = 520.0
const CARD_PANEL_W: float = 1080.0
const PANEL_INSET: float = 24.0
const PANEL_SCROLL: float = 420.0
const PANEL_FLOOR: float = 280.0
const COLUMN_GAP: float = 14.0
const TITLE_PT: float = 30.0
const BODY_PT: float = 18.0
const BUTTON_H: float = 48.0

## The stage shape this panel composes for, and its resolved `run` layout.
var shape: StringName = StageShape.IDENTITY

var _panel_layout: Dictionary = {}
var _first_button: Button = null
var _cancel_button: Button = null
var _panel: PanelContainer
var _frame: MarginContainer = null
var _centre: CenterContainer
var _column: VBoxContainer
var _scroll: ScrollContainer = null
var _card_mode: bool = false
var _card_pick: bool = false
var _card_views: Array[CardView] = []
var _card_pedestals: Array[Control] = []
var _title_variant: bool = false
var _title_banner: TextureRect
var _banner_shadow: ColorRect = null
var _title_column: VBoxContainer
var _wordmark_slot: Control
var _wordmark: TextureRect
var _wordmark_label: Label = null
var _tagline_slot: Control
var _tagline: Label
var _primary: GridContainer
var _primary_buttons: Array[Button] = []
var _utility: GridContainer
var _utility_buttons: Array[Button] = []
var _rose_medallion: Button = null
var _sfx: SfxBus
## When set, Escape emits `chosen` with this id (safe cancel). Absent → Escape ignored.
var _cancel_id: String = ""
var _has_cancel: bool = false
## Overlay mode: scrim over a live routed surface instead of an opaque night ground.
var _overlay: bool = false


func _init(title_text: String, body_text: String, choices: Array[Dictionary],
		context: Dictionary = {}, sfx: SfxBus = null) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	var asked: StringName = StringName(str(context.get("shape", StageShape.IDENTITY)))
	shape = asked if StageShape.REFERENCES.has(asked) else StageShape.IDENTITY
	_panel_layout = LayoutBook.resolve(&"run", shape)
	_title_variant = str(context.get("variant", "")) == "title"
	_overlay = context.get("overlay", false) == true
	if context.has("cancel"):
		_has_cancel = true
		_cancel_id = str(context["cancel"])
	_card_mode = choices.any(func(row: Dictionary) -> bool: return row.has("card"))
	_card_pick = choices.any(func(row: Dictionary) -> bool:
		return row.has("card") and not row.get("disabled", false))
	if _title_variant:
		_build_title(title_text, body_text, choices, context)
	else:
		_build_standard(title_text, body_text, choices)


func _build_standard(title_text: String, body_text: String,
		choices: Array[Dictionary]) -> void:

	var ground: ColorRect = ColorRect.new()
	ground.color = GlassStyle.scrim() if _overlay else GlassStyle.NIGHT_BOT
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	var k: float = _panel_num("scale", 1.0)
	var inset: float = _panel_num("inset", PANEL_INSET)

	# The old inner scroll opened on `choices.size() > 7`, which was a
	# choice-count guard for what is a viewport-height problem: measured at
	# 844x390, six plain choices make a 424px panel and seven make a 479px one,
	# both taller than the 390px stage, and neither tripped the guard. Seating
	# the complete panel in the same
	# ScrollContainer -> Margin -> Centre stack the other run screens use fixes
	# every count at once. The margin sits INSIDE the scroll so the scroll's
	# viewport is the whole stage: a panel that fits is still centred at exactly
	# the position it had before, and one that does not gains travel instead of
	# a clipped edge.
	var page: ScrollContainer = ScrollContainer.new()
	page.follow_focus = true
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(page)

	_frame = MarginContainer.new()
	var frame: MarginContainer = _frame
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_seat_frame(inset)
	page.add_child(frame)

	_centre = CenterContainer.new()
	var centre: CenterContainer = _centre
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(_authored_panel_width(), 0.0)
	_panel.add_theme_stylebox_override("panel", GlassStyle.pane(GlassStyle.GLASS, 0.94))
	centre.add_child(_panel)

	_column = VBoxContainer.new()
	var column: VBoxContainer = _column
	column.add_theme_constant_override("separation", roundi(COLUMN_GAP * k))
	_panel.add_child(column)

	var title: Label = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", GlassStyle.face(GlassStyle.CINZEL_700))
	title.add_theme_font_size_override("font_size", roundi(TITLE_PT * k))
	title.add_theme_color_override("font_color", GlassStyle.TEXT)
	column.add_child(title)

	if not body_text.is_empty():
		var body: Label = Label.new()
		body.text = body_text
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_override("font", GlassStyle.face(GlassStyle.ALEGREYA_400))
		body.add_theme_font_size_override("font_size", roundi(BODY_PT * k))
		body.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
		column.add_child(body)

	if _card_mode:
		_build_card_grid(column, choices, k)
		return

	# Plain choices travel with the complete page. Keeping the old >7 inner
	# scroll under the new page scroll would make eight choices the exact point
	# at which wheel and touch input had two competing vertical owners.
	var button_column: VBoxContainer = column
	for row: Dictionary in choices:
		var button: Button = Button.new()
		button.text = str(row.get("label", row.get("id", "")))
		button.disabled = row.get("disabled", false)
		button.tooltip_text = str(row.get("hint", ""))
		button.custom_minimum_size.y = roundi(BUTTON_H * k)
		var icon_path: String = str(row.get("icon", ""))
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			button.icon = load(icon_path) as Texture2D
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size.y = roundi(72.0 * k)
		GlassStyle.style_button(button, GlassStyle.EMBER if not row.get("quiet", false) else GlassStyle.GLASS)
		_wire_button(button, str(row.get("id", "")))
		button_column.add_child(button)


func _build_card_grid(column: VBoxContainer, choices: Array[Dictionary],
		k: float) -> void:
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size.y = _panel_num("scroll", PANEL_SCROLL)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	var grid: HFlowContainer = HFlowContainer.new()
	grid.alignment = FlowContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("h_separation", roundi(16.0 * k))
	grid.add_theme_constant_override("v_separation", roundi(16.0 * k))
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(grid)
	for row: Dictionary in choices:
		if not row.has("card"):
			continue
		var inst: CardInst = row["card"]
		var definition: Dictionary = row.get("definition", {})
		var cost_v: Variant = definition.get("cost")
		var cost: int = 0 if cost_v == null else int(float(str(cost_v)))
		var view: CardView = CardView.new(inst, definition, cost)
		if not row.get("disabled", false):
			var choice_id: String = str(row.get("id", ""))
			view.released_at.connect(func(_uid: int, _position: Vector2) -> void:
				_sfx.play(&"card")
				chosen.emit(choice_id)
			)
		var pedestal: Control = Control.new()
		grid.add_child(pedestal)
		pedestal.add_child(view)
		_card_views.append(view)
		_card_pedestals.append(pedestal)
	_apply_card_scale()

	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", roundi(COLUMN_GAP * k))
	column.add_child(actions)
	for row: Dictionary in choices:
		if row.has("card"):
			continue
		var button: Button = _title_button(
			str(row.get("label", row.get("id", ""))),
			true if row.get("quiet", false) else false)
		button.custom_minimum_size.x = 180.0
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.disabled = row.get("disabled", false)
		_wire_button(button, str(row.get("id", "")))
		actions.add_child(button)


func _apply_card_scale() -> void:
	var card_scale: float = _card_scale()
	for i: int in range(_card_views.size()):
		var span: Vector2 = Vector2(CardView.CARD_W, CardView.CARD_H) * card_scale
		var view: CardView = _card_views[i]
		var pedestal: Control = _card_pedestals[i]
		pedestal.custom_minimum_size = span
		view.position = (span - Vector2(CardView.CARD_W, CardView.CARD_H)) * 0.5
		view.scale = Vector2.ONE * card_scale


func _card_scale() -> float:
	match shape:
		&"phone-portrait":
			return 0.74 if _card_pick else 0.69
		&"phone-landscape":
			return 0.89 if _card_pick else 0.84
		&"desktop-landscape":
			return 1.17 if _card_pick else 1.0
		_:
			return 0.99 if _card_pick else 0.87


## The benchmark title is a composition, not a panel: the authored raster sits
## over the living sky, the wordmark owns the centre, and utility actions share
## one row at the 1180x820 reference stage.
func _build_title(title_text: String, tagline_text: String, choices: Array[Dictionary],
		context: Dictionary) -> void:
	add_child(TitleWorld.new())

	# The banner's drop-shadow, added FIRST so it sits under the plate it belongs
	# to. `styles.css:343` has carried it since the reference was written and the
	# port never had it, which is why the raster ended flush against the sky.
	_banner_shadow = ColorRect.new()
	var shadow_mat: ShaderMaterial = ShaderMaterial.new()
	shadow_mat.shader = BANNER_SHADOW_SHADER
	shadow_mat.set_shader_parameter("sigma", BANNER_SHADOW_BLUR * 0.5)
	shadow_mat.set_shader_parameter("shade", BANNER_SHADOW_INK)
	_banner_shadow.material = shadow_mat
	_banner_shadow.color = Color(1.0, 1.0, 1.0, 1.0)
	_banner_shadow.modulate.a = BANNER_ALPHA
	_banner_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner_shadow)

	_title_banner = TextureRect.new()
	_title_banner.texture = load(TITLE_BACKGROUND) as Texture2D
	_title_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title_banner.modulate.a = BANNER_ALPHA
	_title_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_banner)

	var vignette: TextureRect = TextureRect.new()
	vignette.texture = GlassStyle.grad_tex(
		PackedColorArray([
			Color(0.016, 0.020, 0.047, 0.0),
			Color(0.016, 0.020, 0.047, 0.0),
			Color(0.016, 0.020, 0.047, 0.58),
		]),
		PackedFloat32Array([0.0, 0.55, 1.0]), true,
		Vector2(0.5, 0.45), Vector2(1.0, 0.45))
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.offset_left = 16.0
	centre.offset_top = 16.0
	centre.offset_right = -16.0
	centre.offset_bottom = -16.0
	add_child(centre)

	_title_column = VBoxContainer.new()
	_title_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_column.add_theme_constant_override("separation", 8)
	centre.add_child(_title_column)

	_wordmark_slot = Control.new()
	_title_column.add_child(_wordmark_slot)
	_wordmark = TextureRect.new()
	_wordmark.texture = load(TITLE_WORDMARK) as Texture2D
	_wordmark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wordmark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_wordmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wordmark.anchor_left = 0.5
	_wordmark.anchor_right = 0.5
	_wordmark.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_wordmark_slot.add_child(_wordmark)
	# The authored raster is the exact English wordmark. Other locales use the
	# same seat and composition, but paint their catalogue title through the
	# display-face fallback chain rather than baking a second language into art.
	if title_text != "GLASSVOW":
		_wordmark.visible = false
		_wordmark_label = Label.new()
		_wordmark_label.text = title_text
		_wordmark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_wordmark_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_wordmark_label.add_theme_font_override(
			"font", _tracked_font(GlassStyle.CINZEL_700, 8))
		_wordmark_label.add_theme_color_override("font_color", PARCHMENT)
		_wordmark_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
		_wordmark_label.add_theme_constant_override("shadow_offset_x", 0)
		_wordmark_label.add_theme_constant_override("shadow_offset_y", 5)
		_wordmark_label.anchor_left = 0.5
		_wordmark_label.anchor_right = 0.5
		_wordmark_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_wordmark_slot.add_child(_wordmark_label)

	_tagline_slot = Control.new()
	_tagline_slot.custom_minimum_size.y = 20.0
	_title_column.add_child(_tagline_slot)
	_tagline = Label.new()
	_tagline.text = tagline_text.to_upper()
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tagline.add_theme_font_override("font", _tracked_font(GlassStyle.CINZEL_500, 5))
	_tagline.add_theme_font_size_override("font_size", 14)
	_tagline.add_theme_color_override("font_color", BENCH_TEXT_DIM)
	_tagline.anchor_left = 0.5
	_tagline.anchor_right = 0.5
	_tagline.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tagline_slot.add_child(_tagline)

	_primary = GridContainer.new()
	_primary.columns = 1
	_primary.add_theme_constant_override("h_separation", 8)
	_primary.add_theme_constant_override("v_separation", 8)
	_primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_column.add_child(_primary)

	_utility = GridContainer.new()
	_utility.add_theme_constant_override("h_separation", 8)
	_utility.add_theme_constant_override("v_separation", 8)
	_utility.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_column.add_child(_utility)

	for row: Dictionary in choices:
		var quiet: bool = row.get("quiet", false)
		var button: Button = _title_button(str(row.get("label", row.get("id", ""))), quiet)
		button.disabled = row.get("disabled", false)
		button.tooltip_text = str(row.get("hint", ""))
		button.set_meta("title_label", button.text)
		_wire_button(button, str(row.get("id", "")))
		if quiet:
			_utility.add_child(button)
			_utility_buttons.append(button)
		else:
			_primary.add_child(button)
			_primary_buttons.append(button)
	# An odd count cannot balance a two-column grid — the orphan hangs in
	# the left cell, off the stack axis. It spans the column instead
	# (DL, issue #49: "three balanced rows").
	if _utility_buttons.size() % 2 == 1 and _utility_buttons.size() > 1:
		var orphan: Button = _utility_buttons[_utility_buttons.size() - 1]
		_utility.remove_child(orphan)
		_title_column.add_child(orphan)
		_title_column.move_child(orphan, _utility.get_index() + 1)
	_add_title_rose(context)

	var stats: Label = Label.new()
	stats.text = str(context.get("stats", ""))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_override("font", _tracked_font(GlassStyle.ALEGREYA_400, 1))
	stats.add_theme_font_size_override("font_size", 14)
	stats.add_theme_color_override("font_color", BENCH_TEXT_DIM)
	_title_column.add_child(stats)

	var version: Label = Label.new()
	version.text = str(context.get("version", ""))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.add_theme_font_override("font", GlassStyle.face(GlassStyle.ALEGREYA_400))
	version.add_theme_font_size_override("font_size", 11)
	version.add_theme_color_override("font_color", Color(BENCH_TEXT_DIM, 0.7))
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -198.0
	version.offset_top = -34.0
	version.offset_right = -18.0
	version.offset_bottom = -18.0
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(version)


func _add_title_rose(context: Dictionary) -> void:
	var shards_v: Variant = context.get("rose_shards", [])
	if typeof(shards_v) != TYPE_ARRAY or shards_v.is_empty():
		return
	var shards: Array = shards_v
	_rose_medallion = Button.new()
	_rose_medallion.tooltip_text = Locale.active.t("ui.rose.openLabel")
	_rose_medallion.clip_contents = true
	_rose_medallion.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_rose_medallion.add_theme_stylebox_override("focus",
		GlassStyle.focus_ring(GOLD, 39))
	for state: String in ["normal", "hover", "pressed"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("#070912")
		style.set_border_width_all(1)
		style.border_color = Color(GOLD, 0.82 if state == "hover" else 0.45)
		style.set_corner_radius_all(39)
		style.shadow_color = Color(GOLD, 0.24 if state == "hover" else 0.16)
		style.shadow_size = 16 if state == "hover" else 10
		_rose_medallion.add_theme_stylebox_override(state, style)
	add_child(_rose_medallion)
	for id_v: Variant in shards:
		var id: String = str(id_v)
		var mask_path: String = ROSE_MASK % id
		if not ResourceLoader.exists(mask_path):
			continue
		var pane: TextureRect = TextureRect.new()
		pane.texture = load(mask_path) as Texture2D
		pane.set_anchors_preset(Control.PRESET_FULL_RECT)
		pane.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pane.stretch_mode = TextureRect.STRETCH_SCALE
		pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = ROSE_PANE_SHADER
		material.set_shader_parameter("mural", load(ROSE_MURAL) as Texture2D)
		material.set_shader_parameter("show_mural", true)
		material.set_shader_parameter("fill_colour", Color.TRANSPARENT)
		pane.material = material
		_rose_medallion.add_child(pane)
	var frame: TextureRect = TextureRect.new()
	frame.texture = load(ROSE_FRAME) as Texture2D
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rose_medallion.add_child(frame)
	_rose_medallion.pressed.connect(func() -> void:
		_sfx.play(&"relic")
		chosen.emit("rose")
	)


func _title_button(text: String, quiet: bool) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 40.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", _tracked_font(GlassStyle.CINZEL_700, 1))
	button.add_theme_font_size_override("font_size", 13 if quiet else 17)
	# The most-seen buttons in the game adopt the shared ring: the old
	# opaque focus box was 1px on the button's own border line with a black
	# shadow — focus ≡ hover-minus-glow (DL, PR #43).
	button.add_theme_stylebox_override("focus", GlassStyle.focus_ring(GOLD, 8))
	button.add_theme_color_override("font_focus_color", PARCHMENT)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color(0.055, 0.071, 0.133, 0.60 if quiet else 0.90)
		box.set_border_width_all(1)
		box.border_color = Color(GOLD, 0.28 if state == "normal" else 0.82)
		box.set_corner_radius_all(8)
		box.content_margin_left = 8.0 if quiet else 24.0
		box.content_margin_right = 8.0 if quiet else 24.0
		box.content_margin_top = 8.0
		box.content_margin_bottom = 8.0
		box.shadow_color = Color(0, 0, 0, 0.50)
		box.shadow_size = 6
		if state == "hover":
			box.shadow_color = Color(GOLD, 0.22)
			box.shadow_size = 12
		elif state == "pressed":
			box.bg_color = Color(0.035, 0.045, 0.090, 0.90)
		elif state == "disabled":
			box.border_color = Color(GOLD, 0.12)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", PARCHMENT)
	button.add_theme_color_override("font_hover_color", Color("#fff3d6"))
	button.add_theme_color_override("font_pressed_color", PARCHMENT)
	button.add_theme_color_override("font_disabled_color", Color(BENCH_TEXT_DIM, 0.45))
	return button


static func _tracked_font(path: String, glyph_spacing: int) -> FontVariation:
	var tracked: FontVariation = FontVariation.new()
	tracked.base_font = GlassStyle.face(path)
	tracked.spacing_glyph = glyph_spacing
	return tracked


func _wire_button(button: Button, id: String) -> void:
	button.pressed.connect(func() -> void:
		_sfx.play(&"click")
		chosen.emit(id)
	)
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			_sfx.play(&"hover", 0.45)
	)
	if _first_button == null and not button.disabled:
		_first_button = button
	if _cancel_button == null and id == _cancel_id and not _cancel_id.is_empty():
		_cancel_button = button


## Optional safe cancel: context key `"cancel"` maps Escape onto that choice id.
## Absent key → Escape does nothing (must-choose dialogs).
func _unhandled_key_input(event: InputEvent) -> void:
	if not _has_cancel:
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	chosen.emit(_cancel_id)
	get_viewport().set_input_as_handled()


func _ready() -> void:
	resized.connect(_fit)
	_fit()
	var focus: Button = _cancel_button if _cancel_button != null else _first_button
	if focus != null:
		focus.grab_focus()
	if _title_variant:
		pivot_offset = size * 0.5
		# REDUCE MOTION: the title arrives standing (`.logo { animation:
		# none; }`, styles.css:2039) instead of breathing in.
		if Preferences.active.reduce_motion:
			modulate.a = 1.0
			scale = Vector2.ONE
			return
		modulate.a = 0.0
		scale = Vector2.ONE * 1.015
		var tween: Tween = create_tween().set_parallel()
		tween.tween_property(self, "modulate:a", 1.0, 0.45)
		tween.tween_property(self, "scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## The panel's authored width, held inside what the stage can actually give it.
##
## This clamp already existed and already worked — it is the reason a narrow
## stage never had the panel hanging off both sides. What it could not do is
## know that a phone wants a NARROWER panel than the clamp alone would leave it
## with, or that the type inside should shrink too. The book supplies the
## authored width and the clamp keeps holding the floor and the ceiling.
func _fit() -> void:
	if _title_variant:
		_fit_title()
		return
	if _panel != null:
		var inset: float = _panel_num("inset", PANEL_INSET)
		_panel.custom_minimum_size.x = minf(_authored_panel_width(),
			maxf(PANEL_FLOOR, size.x - inset * 2.0))


func _panel_num(field: String, fallback: float = 0.0) -> float:
	return LayoutBook.num(_panel_layout.get(field), fallback)


## The title screen's own bucket, hanging off the same `run` scope — the same
## arrangement `map` uses for its top rail.
func _title_num(field: String, fallback: float = 0.0) -> float:
	return LayoutBook.num(_panel_layout.get("title", {}).get(field), fallback)


## Put the banner's drop-shadow under the plate it belongs to.
##
## The Control has to be BIGGER than the plate, because the shadow bleeds past
## every edge — a shader can only draw inside its own rect, so a margin of three
## standard deviations plus the offset is what keeps the tail from being clipped
## into a second hard edge, which would defeat the whole point of adding it.
func _seat_banner_shadow(at: Vector2, span: Vector2) -> void:
	if _banner_shadow == null:
		return
	var sigma: float = BANNER_SHADOW_BLUR * 0.5
	var pad: float = sigma * 3.0 + absf(BANNER_SHADOW_DY)
	_banner_shadow.position = at - Vector2.ONE * pad
	_banner_shadow.size = span + Vector2.ONE * pad * 2.0
	var mat: ShaderMaterial = _banner_shadow.material as ShaderMaterial
	if mat == null:
		return
	var plate_min: Vector2 = Vector2.ONE * pad
	mat.set_shader_parameter("ctrl_size", _banner_shadow.size)
	mat.set_shader_parameter("box_min", plate_min + Vector2(0.0, BANNER_SHADOW_DY))
	mat.set_shader_parameter("box_max", plate_min + span + Vector2(0.0, BANNER_SHADOW_DY))
	mat.set_shader_parameter("plate_min", plate_min)
	mat.set_shader_parameter("plate_max", plate_min + span)


## The panel's breathing room, held by the margin inside the page scroll rather
## than by the centre's offsets — a container's offsets are overwritten by its
## parent, so they stopped being the place to keep this the moment the centre
## gained one.
func _seat_frame(inset: float) -> void:
	if _frame == null:
		return
	for side: String in ["left", "top", "right", "bottom"]:
		_frame.add_theme_constant_override("margin_%s" % side, roundi(inset))


func _authored_panel_width() -> float:
	return CARD_PANEL_W if _card_mode else _panel_num("w", PANEL_W)


## Follow a re-pick. Only the numbers move — the panel keeps its buttons, its
## focus and its fade-in, because none of those depend on the shape.
func set_shape(stage_shape: StringName) -> void:
	if stage_shape == shape or not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	_panel_layout = LayoutBook.resolve(&"run", shape)
	var k: float = _panel_num("scale", 1.0)
	var inset: float = _panel_num("inset", PANEL_INSET)
	_seat_frame(inset)
	if _column != null:
		_column.add_theme_constant_override("separation", roundi(COLUMN_GAP * k))
	if _scroll != null:
		_scroll.custom_minimum_size.y = _panel_num("scroll", PANEL_SCROLL)
	if _card_mode:
		_apply_card_scale()
	_fit()


## The title screen's set-out, from the book.
##
## It used to open on `size.x >= 1000.0 and size.y <= 860.0`, which selects
## exactly pad-landscape and desktop-landscape and nothing else — an enumeration
## of two shapes written as though it were a measurement of one stage. The two
## are not the same claim, and the difference shows up twice: flex leaves the
## test only 38px of margin at pad-landscape's lower bound, and the sixth shape
## anybody authors lands in whichever bucket the arithmetic happens to put it
## in, silently.
##
## Twelve fields across five branches came out, and all twelve were dumped
## through the resolver at all five shapes and compared against the expressions
## they replaced: sixty comparisons, zero differences. The three width formulas
## collapsed to one each on the way, without changing a single resolved output:
## the phone-landscape column was `minf(760, size.x - 32)` and the others were
## flat numbers, which is the same expression once the cap is authored.
func _fit_title() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var wordmark_w: float = minf(_title_num("wordmarkMax", 520.0),
		size.x * _title_num("wordmarkRate", 0.60))
	var wordmark_h: float = wordmark_w * 399.0 / 1536.0
	_wordmark_slot.custom_minimum_size.y = wordmark_h
	_wordmark.offset_left = -wordmark_w * 0.5
	_wordmark.offset_top = 0.0
	_wordmark.offset_right = wordmark_w * 0.5
	_wordmark.offset_bottom = wordmark_h
	if _wordmark_label != null:
		_wordmark_label.offset_left = -wordmark_w * 0.5
		_wordmark_label.offset_top = 0.0
		_wordmark_label.offset_right = wordmark_w * 0.5
		_wordmark_label.offset_bottom = wordmark_h
		_wordmark_label.add_theme_font_size_override(
			"font_size", roundi(clampf(wordmark_h * 0.52, 30.0, 68.0)))

	var tagline_w: float = minf(760.0, size.x - 32.0)
	_tagline.offset_left = -tagline_w * 0.5
	_tagline.offset_top = 0.0
	_tagline.offset_right = tagline_w * 0.5
	_tagline.offset_bottom = 20.0
	_tagline_slot.visible = _title_num("tagline", 1.0) >= 1.0
	_tagline.add_theme_font_override("font", _tracked_font(GlassStyle.CINZEL_500,
		roundi(_title_num("taglineTrack", 5.0))))
	_tagline.add_theme_font_size_override(
		"font_size", roundi(_title_num("taglinePt", 14.0)))

	_title_column.custom_minimum_size.x = minf(_title_num("columnW", 340.0),
		size.x - 32.0)
	_title_column.add_theme_constant_override(
		"separation", roundi(_title_num("gap", 8.0)))
	_primary.columns = roundi(_title_num("primaryCols", 1.0))
	_utility.columns = roundi(_title_num("utilityCols", 2.0))
	var primary_pt: int = roundi(_title_num("primaryPt", 17.0))
	var utility_pt: int = roundi(_title_num("utilityPt", 13.0))
	var wrap_help: bool = _title_num("wrapHelp", 1.0) >= 1.0
	for button: Button in _primary_buttons:
		button.add_theme_font_size_override("font_size", primary_pt)
	for button: Button in _utility_buttons:
		var label: String = str(button.get_meta("title_label", button.text))
		button.text = label.replace("How to Play", "How to\nPlay") if wrap_help \
			else label
		button.add_theme_font_size_override("font_size", utility_pt)

	var image_aspect: float = 1536.0 / 1024.0
	var banner_h: float = minf(size.y * BANNER_H_RATE, size.x * BANNER_W_RATE / image_aspect)
	var banner_w: float = banner_h * image_aspect
	var banner_at: Vector2 = Vector2(
		(size.x - banner_w) * 0.5,
		size.y - size.y * BANNER_LIFT - banner_h)
	_title_banner.position = banner_at
	_title_banner.size = Vector2(banner_w, banner_h)
	_seat_banner_shadow(banner_at, Vector2(banner_w, banner_h))
	if _rose_medallion != null:
		var rose_side: float = _title_num("roseSide", 78.0)
		_rose_medallion.offset_left = 18.0
		_rose_medallion.offset_top = -18.0 - rose_side
		_rose_medallion.offset_right = 18.0 + rose_side
		_rose_medallion.offset_bottom = -18.0
