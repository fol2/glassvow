class_name CardStudio
extends Control
## THE MATERIAL BENCH. One card, big, with all four surface layers on pickers.
##
##   godot --path . -- --studio               # 2x, the default working size
##   godot --path . -- --studio=bastion --zoom=3
##
## Debug tooling, permanently. It ships in the project and never appears in a
## run: nothing constructs it but the `--studio` flag, and it builds no game
## state — like the card lab, it reads the catalogue directly.
##
## Why it has to exist. Every channel in card_surface.gdshader is angle-driven,
## which means a still card at rest tells you almost nothing about the material
## on it: that is the whole design, and it makes materials nearly impossible to
## judge from a screenshot. Worse, the angle is normally the CURSOR's — so the
## moment you look away from the card to read which layers it is wearing, the
## pose collapses. Here the pose is on sliders and the layers are on pickers,
## so both can be held still at once and the card can be stared at. Hovering
## the card still does everything it does in a fight — the sliders only decide
## where it settles back to when the cursor leaves.
##
## The four pickers are independent by construction, because the layers are:
## pick any material with any texture with any finish with any stock and the
## card rebuilds wearing exactly that. A recipe is only a nickname for one such
## combination, so the recipe picker is a shortcut that sets the other four,
## and `name_of` puts the nickname back when a hand-built stack happens to
## match one. What the panel prints at the bottom is the line to paste into
## CardSurface.RECIPES — which is the point of the tool: compose here, name it
## in code.

const PANEL_W: float = 260.0
## How much bigger than life the card is drawn. This is a NODE scale, not a
## window scale, so the panel stays legible while the card grows — and because
## CardView.oversample is raised to match before every rebuild, the offscreen
## render grows with it and the card is downsampled rather than stretched.
const SIZES: Array = [1.0, 1.5, 2.0, 2.5, 3.0]
const SWEEP_RATE: float = 0.45   # radians/sec of the auto-sweep's slow figure

## The layer pickers, in stack order. Each names its catalogue and the one-word
## question that layer answers, because the four are easy to confuse.
const LAYERS: Array = [
	["material", "made of"],
	["texture", "surface"],
	["finish", "coating"],
	["stock", "body"],
]

## Backdrops worth judging a material against. A foil reads completely
## differently on black than on the game's own field, and a light ground is the
## only way to see whether a matte finish is actually matte.
const GROUNDS: Array = [
	["game field", Color(0.043, 0.055, 0.102)],
	["black", Color(0, 0, 0)],
	["slate", Color(0.35, 0.36, 0.40)],
	["paper", Color(0.86, 0.85, 0.82)],
]

var content: ContentDB

var _catalog: Dictionary = {}
var _ids: Array[String] = []             # catalogue order: rarity tier, then name
var _stack: Array = ["stock", "smooth", "smooth-matte", "standard"]
var _card_id: String = ""
var _zoom: float = 1.0
var _scale: float = 2.5

var _ground: ColorRect
var _stage: Control                      # holds the live card, centred
var _card: CardView = null
var _recipe_pick: OptionButton
var _picks: Array[OptionButton] = []
var _tilt: Vector2 = Vector2(0.0, 0.4)
var _sliders: Array[HSlider] = []
var _sweeping: bool = false
var _sweep_t: float = 0.0
var _readout: RichTextLabel
var _recipe_line: LineEdit


func _init(content_ref: ContentDB, only: PackedStringArray = PackedStringArray(),
		zoom: float = 1.0) -> void:
	content = content_ref
	_zoom = maxf(1.0, zoom)
	# The lab's loader, not a second copy of it — one JSON contract, one reader.
	_catalog = CardLab.load_catalog(content_ref)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()

	for k: Variant in _catalog.keys():
		_ids.append(str(k))
	_ids.sort_custom(func(a: String, b: String) -> bool:
		var ra: int = CardLab.RARITY_ORDER.find(
			str(_catalog.get(a, {}).get("rarity", "")))
		var rb: int = CardLab.RARITY_ORDER.find(
			str(_catalog.get(b, {}).get("rarity", "")))
		if ra != rb:
			return ra < rb
		return str(_catalog.get(a, {}).get("name", a)) \
			< str(_catalog.get(b, {}).get("name", b)))
	_card_id = _ids[0] if not _ids.is_empty() else ""
	for want: String in only:
		if _ids.has(want):
			_card_id = want
			break

	_ground = ColorRect.new()
	var ground0: Color = GROUNDS[0][1]
	_ground.color = ground0
	_ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ground)

	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.offset_left = PANEL_W
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	add_child(_build_panel())
	_adopt(CardSurface.stack_of(StringName(_card_id), _card_data()))


# ── panel ────────────────────────────────────────────────────────────────

func _build_panel() -> Control:
	var frame: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.06, 0.94)
	sb.border_color = Color(GlassStyle.GLASS, 0.20)
	sb.border_width_right = 1
	sb.set_content_margin_all(14)
	frame.add_theme_stylebox_override("panel", sb)
	# Anchored by hand rather than by preset: PRESET_LEFT_WIDE leaves the width
	# to the content, and one long card name then shoves the panel across half
	# the screen. Here the width is the law and the content clips to it.
	frame.anchor_bottom = 1.0
	frame.offset_right = PANEL_W

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	col.add_child(_heading("CARD"))
	var card_pick: OptionButton = _pick()
	for i: int in range(_ids.size()):
		var d: Dictionary = _catalog.get(_ids[i], {})
		card_pick.add_item("%s  ·  %s" % [
			str(d.get("name", _ids[i])), str(d.get("rarity", "?"))], i)
		if _ids[i] == _card_id:
			card_pick.select(i)
	# 61 entries in one popup is a wall; let it scroll rather than paginate.
	card_pick.get_popup().max_size = Vector2i(360, 620)
	card_pick.item_selected.connect(func(i: int) -> void:
		_card_id = _ids[i]
		# The card's OWN material, so picking a card shows what it really wears
		# before you start changing it.
		_adopt(CardSurface.stack_of(StringName(_card_id), _card_data())))
	col.add_child(card_pick)

	col.add_child(_heading("RECIPE"))
	_recipe_pick = _pick()
	_recipe_pick.add_item("— unnamed —", 0)
	var names: Array = CardSurface.RECIPES.keys()
	for i: int in range(names.size()):
		_recipe_pick.add_item(str(names[i]), i + 1)
	_recipe_pick.item_selected.connect(func(i: int) -> void:
		if i > 0:
			var picked: Array = CardSurface.RECIPES[names[i - 1]]
			_adopt(picked))
	col.add_child(_recipe_pick)

	col.add_child(_heading("LAYERS"))
	for slot: int in range(LAYERS.size()):
		var spec: Array = LAYERS[slot]
		col.add_child(_caption("%s — %s" % [str(spec[0]), str(spec[1])]))
		var pick: OptionButton = _pick()
		var keys: Array = _table(slot).keys()
		for i: int in range(keys.size()):
			pick.add_item(str(keys[i]), i)
		pick.item_selected.connect(func(i: int) -> void:
			var next: Array = _stack.duplicate()
			next[slot] = str(keys[i])
			_adopt(next))
		_picks.append(pick)
		col.add_child(pick)

	col.add_child(_heading("POSE"))
	# Same normalised -1..1 the cursor gives, so a slider position is literally
	# "the pointer is here" — the tilt the card would take under the hand.
	var axis_names: Array = ["horizontal — left / right", "vertical — top / bottom"]
	for axis: int in range(2):
		col.add_child(_caption(str(axis_names[axis])))
		var s: HSlider = HSlider.new()
		s.min_value = -1.0
		s.max_value = 1.0
		s.step = 0.01
		s.value = _tilt.x if axis == 0 else _tilt.y
		s.custom_minimum_size = Vector2(0.0, 18.0)
		s.value_changed.connect(func(v: float) -> void:
			if axis == 0:
				_tilt.x = v
			else:
				_tilt.y = v
			_apply_pose())
		_sliders.append(s)
		col.add_child(s)
	var sweep: CheckBox = CheckBox.new()
	sweep.text = "sweep the pose"
	sweep.add_theme_font_size_override("font_size", 12)
	sweep.toggled.connect(func(on: bool) -> void:
		_sweeping = on
		set_process(on))
	col.add_child(sweep)

	col.add_child(_heading("GROUND"))
	var ground_pick: OptionButton = _pick()
	for i: int in range(GROUNDS.size()):
		ground_pick.add_item(str(GROUNDS[i][0]), i)
	ground_pick.item_selected.connect(func(i: int) -> void:
		var ground: Color = GROUNDS[i][1]
		_ground.color = ground)
	col.add_child(ground_pick)

	col.add_child(_heading("SIZE"))
	var size_pick: OptionButton = _pick()
	for i: int in range(SIZES.size()):
		var f: float = SIZES[i]
		size_pick.add_item("%sx life size" % String.num(f, 1), i)
		if is_equal_approx(f, _scale):
			size_pick.select(i)
	size_pick.item_selected.connect(func(i: int) -> void:
		_scale = SIZES[i]
		_rebuild())
	col.add_child(size_pick)

	col.add_child(_heading("STACK"))
	# Selectable, because the whole point is to carry a combination back into
	# CardSurface.RECIPES once it is worth naming.
	_recipe_line = LineEdit.new()
	_recipe_line.editable = false
	_recipe_line.add_theme_font_size_override("font_size", 11)
	col.add_child(_recipe_line)

	_readout = RichTextLabel.new()
	_readout.bbcode_enabled = true
	_readout.fit_content = true
	_readout.scroll_active = false
	_readout.add_theme_font_size_override("normal_font_size", 11)
	_readout.custom_minimum_size = Vector2(0.0, 200.0)
	col.add_child(_readout)
	return frame


## Every picker goes through here: clip_text is what keeps a long entry from
## widening the panel, and it has to be on the button, not the container.
static func _pick() -> OptionButton:
	var b: OptionButton = OptionButton.new()
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 12)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


static func _heading(text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", GlassStyle.EMBER)
	return l


static func _caption(text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	return l


static func _table(slot: int) -> Dictionary:
	match slot:
		0:
			return CardSurface.MATERIAL
		1:
			return CardSurface.TEXTURE
		2:
			return CardSurface.FINISH
		_:
			return CardSurface.STOCK


# ── the card ─────────────────────────────────────────────────────────────

func _card_data() -> Dictionary:
	return _catalog.get(_card_id, {})


## Wear this stack. Everything downstream of a change routes through here, so
## the pickers, the readout and the card can never disagree about what is on
## screen — which is the one bug a tool like this must not have.
func _adopt(stack: Array) -> void:
	_stack = stack.duplicate()
	for slot: int in range(_picks.size()):
		var keys: Array = _table(slot).keys()
		_picks[slot].select(keys.find(_stack[slot]))
	var named: String = CardSurface.name_of(_stack)
	var names: Array = CardSurface.RECIPES.keys()
	_recipe_pick.select(0 if named == "" else names.find(named) + 1)
	_rebuild()
	_write_readout(named)


## CardView resolves its material once, in _init — deliberately, since a card in
## a fight never changes what it is made of. So the studio throws the node away
## and builds another rather than adding a live-reload path to the game code for
## a debug screen's sake.
func _rebuild() -> void:
	if _card != null:
		_card.queue_free()
	# Raise the offscreen render to match how large the card will be drawn, or
	# the studio magnifies a 2x texture and reports blur as a material defect.
	CardView.oversample = clampf(2.0 * _scale * _zoom, 2.0, 8.0)
	var data: Dictionary = _card_data().duplicate()
	data["surface"] = _stack
	var cost_v: Variant = data.get("cost")
	_card = CardView.new(CardInst.new(1, StringName(_card_id)), data,
		0 if cost_v == null else int(float(str(cost_v))))
	# The card keeps its own hover: glare, edge glint, tilt-toward-the-cursor,
	# lift and the release spring all behave exactly as they do in a hand. They
	# do not fight the sliders, because the sliders set the pose the card comes
	# HOME to — let go of the card and it settles back onto whatever the panel
	# is holding, not onto flat. Which of the two is driving is never ambiguous:
	# the cursor is, whenever it is on the card.
	_card.scale = Vector2.ONE * _scale
	_stage.add_child(_card)
	_centre()
	_apply_pose()


func _centre() -> void:
	if _card != null:
		_card.position = (_stage.size - Vector2(CardView.CARD_W, CardView.CARD_H)) * 0.5


func _apply_pose() -> void:
	if _card != null:
		_card.hold_pose(_tilt)


func _write_readout(named: String) -> void:
	var parts: PackedStringArray = PackedStringArray()
	for layer: Variant in _stack:
		parts.append('"%s"' % str(layer))
	_recipe_line.text = '"%s": [%s],' % [
		named if named != "" else "NAME-ME", ", ".join(parts)]

	var p: Dictionary = CardSurface.params(_stack)
	var lines: PackedStringArray = PackedStringArray()
	for slot: int in range(LAYERS.size()):
		var spec: Array = LAYERS[slot]
		lines.append("[color=#ff9a4d]%s[/color]  [color=#8fd0ff]%s[/color]"
			% [str(spec[0]), str(_stack[slot])])
		var row: PackedStringArray = PackedStringArray()
		for k: Variant in _table(slot)[_stack[slot]]:
			row.append("%s %s" % [str(k), _fmt(p[k])])
		lines.append("[color=#94a3cc]  %s[/color]" % "   ".join(row))
	_readout.text = "\n".join(lines)


static func _fmt(v: Variant) -> String:
	if typeof(v) == TYPE_FLOAT:
		# String.num, not "%g" — GDScript's format has no %g, and "%f" pads
		# every number to six decimals, which turns the readout into a wall.
		var f: float = v
		return String.num(f, 4)
	if typeof(v) == TYPE_COLOR:
		var c: Color = v
		return "#" + c.to_html(false)
	return str(v)


## Take the whole screen, but leave content_scale_factor alone unless asked.
## The project already stretches its 1180x820 stage to the window, so raising
## the content scale DIVIDES the logical stage — at 2 it drops to 590x410 and a
## life-and-a-half card no longer fits beside the panel. The card is made big
## by scaling the card, not by shrinking the room it stands in.
func _ready() -> void:
	set_process(false)
	if not is_equal_approx(_zoom, 1.0):
		get_window().content_scale_factor = _zoom
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(
		DisplayServer.window_get_current_screen())
	if usable.size.x > 0:
		var got: Vector2i = Vector2i(usable.size.x - 40, usable.size.y - 60)
		get_window().size = got
		get_window().position = usable.position + (usable.size - got) / 2
	await get_tree().process_frame
	_centre()
	get_viewport().size_changed.connect(_centre)


## The sweep is a Lissajous rather than a circle: at a 2:3 ratio the pose never
## repeats the same path twice in a row, so a slow watch covers the whole
## square instead of tracing one loop the material happens to look good on.
func _process(delta: float) -> void:
	if not _sweeping:
		return
	_sweep_t += delta * SWEEP_RATE
	_tilt = Vector2(sin(_sweep_t * 2.0), cos(_sweep_t * 3.0))
	for axis: int in range(2):
		_sliders[axis].set_value_no_signal(_tilt.x if axis == 0 else _tilt.y)
	_apply_pose()
