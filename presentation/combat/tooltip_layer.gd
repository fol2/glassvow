class_name TooltipLayer
extends Control
## `#tooltip` (styles.css:136) and the `pointerover` router that feeds it
## (`initTooltip`, tooltip.js:38).
##
## The benchmark hangs a `_tip` payload on any DOM node and walks UP from the
## event target until it finds one. There is no equivalent walk here, because a
## keyword inside a card's rules paragraph is not a node — it is a run of glyphs
## the paragraph drew itself. So the walk is inverted: the screen answers ONE
## question, `tip_at(global_pos)`, and asks its own children in paint order.
## Anything that can answer implements `tip_at` too, and a paragraph can hand
## back a different tip depending on which word the cursor is over.
##
## A tip is `{ "title": String, "body": String, "sub": String }`; an empty
## dictionary means nothing is tipped here.

## `--panel`, `--panel-line`, `--text`, `--text-dim`, `--gold` (styles.css:11).
const PANEL: Color = Color(0.05490196, 0.07058824, 0.13333334, 0.86)
const PANEL_LINE: Color = Color(0.9490196, 0.75686276, 0.30588236, 0.28)
const TEXT: Color = Color(0.84313726, 0.8627451, 0.91764706)
const TEXT_DIM: Color = Color(0.54509807, 0.5764706, 0.6784314)
const GOLD: Color = Color(0.9490196, 0.75686276, 0.30588236)

const MAX_W: float = 300.0
const PAD_X: float = 12.0
const PAD_Y: float = 10.0
const RADIUS: float = 8.0
const BODY_SIZE: int = 14
const TITLE_SIZE: int = 14
const SUB_SIZE: int = 13  # 12.5px, and a font size is an integer here
const LINE_SPACING: float = 6.3  # `line-height: 1.45` at 14px is 20.3px

## `tipIn 0.12s var(--ease-spring)` — `from { opacity: 0; translateY(6px)
## scale(0.96) }`. The spring is the same curve everything else in this port
## overshoots on.
const IN_TIME: float = 0.12
const IN_LIFT: float = 6.0
const IN_SCALE: float = 0.96

## `place()` (tooltip.js:56). A mouse tip sits to the RIGHT of the cursor and
## vertically centred on it; a touch tip sits ABOVE the finger and centred.
const MOUSE_DX: float = 16.0
const EDGE_X: float = 12.0
const EDGE_Y: float = 8.0
const TOUCH_LIFT: float = 26.0
const TOUCH_EDGE: float = 8.0

## `setTimeout(..., 380)` — the long-press that stands in for hover on a
## touchscreen, and the 12px slop that cancels it.
const LONG_PRESS: float = 0.38
const LONG_PRESS_SLOP: float = 12.0

## Answers `tip_at(global_pos) -> Dictionary`. The screen sets this; without it
## the layer is inert rather than broken.
var source: Callable = Callable()

var _panel: PanelContainer
var _box: VBoxContainer
var _title: Label
var _body: RichTextLabel
var _sub: Label
var _shown: Dictionary = {}
## `tipIn` progress, and the placed corner the lift is measured from. The
## entrance cannot be a Tween on `position`: the tip FOLLOWS the cursor, so a
## tween that captured a corner would spend the whole 120ms dragging the panel
## back to wherever it was when it appeared.
var _in_t: float = 1.0
var _base_pos: Vector2 = Vector2.ZERO
var _touch_at: Vector2 = Vector2.ZERO
var _touch_timer: float = -1.0


func _init() -> void:
	name = "TooltipLayer"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Paint-only. A tooltip that ate a click would break every gesture it
	# floated over, and the benchmark's is `pointer-events: none` for the same
	# reason.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	set_process(true)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_panel.custom_minimum_size = Vector2.ZERO
	var box_style: StyleBoxFlat = StyleBoxFlat.new()
	box_style.bg_color = PANEL
	box_style.border_color = PANEL_LINE
	box_style.set_border_width_all(1)
	box_style.set_corner_radius_all(int(RADIUS))
	box_style.content_margin_left = PAD_X
	box_style.content_margin_right = PAD_X
	box_style.content_margin_top = PAD_Y
	box_style.content_margin_bottom = PAD_Y
	# `box-shadow: 0 10px 30px rgba(0,0,0,0.6)` — a drop, not a glow, so the
	# panel reads as lifted off whatever it is covering.
	box_style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	box_style.shadow_size = 14
	box_style.shadow_offset = Vector2(0.0, 6.0)
	_panel.add_theme_stylebox_override(&"panel", box_style)
	add_child(_panel)

	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override(&"separation", 3)
	_panel.add_child(_box)

	_title = Label.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_color_override(&"font_color", GOLD)
	_title.add_theme_font_size_override(&"font_size", TITLE_SIZE)
	var cinzel: Font = GlassStyle.face(GlassStyle.CINZEL_700)
	if cinzel != null:
		_title.add_theme_font_override(&"font", cinzel)
	_box.add_child(_title)

	# RichText rather than Label: every tip body in the catalogue carries <b>
	# runs, and the emphasis is the half of the sentence that matters.
	_body = RichTextLabel.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(MAX_W - PAD_X * 2.0, 0.0)
	_body.add_theme_color_override(&"default_color", TEXT)
	_body.add_theme_font_size_override(&"normal_font_size", BODY_SIZE)
	_body.add_theme_font_size_override(&"bold_font_size", BODY_SIZE)
	_body.add_theme_constant_override(&"line_separation", int(LINE_SPACING))
	var alegreya: Font = GlassStyle.face(GlassStyle.ALEGREYA_400)
	if alegreya != null:
		_body.add_theme_font_override(&"normal_font", alegreya)
	var alegreya_bold: Font = GlassStyle.face(GlassStyle.ALEGREYA_700)
	if alegreya_bold != null:
		_body.add_theme_font_override(&"bold_font", alegreya_bold)
	_box.add_child(_body)

	_sub = Label.new()
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.add_theme_color_override(&"font_color", TEXT_DIM)
	_sub.add_theme_font_size_override(&"font_size", SUB_SIZE)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.custom_minimum_size = Vector2(MAX_W - PAD_X * 2.0, 0.0)
	_box.add_child(_sub)


func _process(delta: float) -> void:
	# The entrance runs whether or not a source is wired: a tip that was placed
	# by hand (a bench, a probe) still has to arrive rather than sit at alpha 0.
	_step_in(delta)
	if not source.is_valid():
		return
	_step_long_press(delta)
	# `document.addEventListener('pointerover', ...)` only fires for a mouse
	# (`if (!FINE || event.pointerType !== 'mouse') return`). A touch pointer
	# has no hover, so it gets the long-press path instead.
	if DisplayServer.is_touchscreen_available() and not _has_mouse():
		return
	var at: Vector2 = get_global_mouse_position()
	var tip_v: Variant = source.call(at)
	var tip: Dictionary = tip_v if tip_v is Dictionary else {}
	if tip.is_empty():
		hide_tip()
		return
	if tip != _shown:
		_apply(tip)
	_place(at, false)


func _has_mouse() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE)


## The touch path. The screen forwards presses; a press that holds still for
## 380ms pops the tip, and 12px of travel cancels it.
func press(at: Vector2) -> void:
	hide_tip()
	_touch_at = at
	_touch_timer = LONG_PRESS


func press_moved(at: Vector2) -> void:
	if _touch_timer >= 0.0 and at.distance_to(_touch_at) > LONG_PRESS_SLOP:
		_touch_timer = -1.0
		hide_tip()


func release() -> void:
	_touch_timer = -1.0


func _step_long_press(delta: float) -> void:
	if _touch_timer < 0.0:
		return
	_touch_timer -= delta
	if _touch_timer > 0.0:
		return
	_touch_timer = -1.0
	var tip_v: Variant = source.call(_touch_at)
	var tip: Dictionary = tip_v if tip_v is Dictionary else {}
	if tip.is_empty():
		return
	_apply(tip)
	_place(_touch_at, true)


func hide_tip() -> void:
	if _shown.is_empty():
		return
	_shown = {}
	_panel.visible = false


func _apply(tip: Dictionary) -> void:
	_shown = tip.duplicate()
	var title: String = str(tip.get("title", ""))
	var body: String = str(tip.get("body", ""))
	var sub: String = str(tip.get("sub", ""))
	_title.text = title
	_title.visible = not title.is_empty()
	_body.text = _bb(body)
	_body.visible = not body.is_empty()
	_sub.text = _bb_strip(sub)
	_sub.visible = not sub.is_empty()
	_panel.visible = true
	# Sized from its own minimum rather than from a layout pass. A container
	# sorts on the next frame, and by then the tip has already been placed
	# against a size of zero — the same trap the damage floaters hit.
	_panel.size = _panel.get_combined_minimum_size()
	_panel.pivot_offset = _panel.size * 0.5
	_in_t = 0.0


## The catalogue writes its emphasis in HTML because the benchmark renders into
## a DOM node. `<b>` and `<br>` are the only two tags any tip body uses.
static func _bb(html: String) -> String:
	return html \
		.replace("<b>", "[b]").replace("</b>", "[/b]") \
		.replace("<br><br>", "\n\n").replace("<br>", "\n")


## The sub line is a plain Label, so the same tags come out rather than over.
static func _bb_strip(html: String) -> String:
	return html \
		.replace("<b>", "").replace("</b>", "") \
		.replace("<br><br>", "\n\n").replace("<br>", "\n")


## `tipIn 0.12s var(--ease-spring) both` — `from { opacity: 0; translateY(6px)
## scale(0.96) }`, folded into whatever corner `_place` last settled on.
func _step_in(delta: float) -> void:
	if _in_t >= 1.0:
		return
	_in_t = minf(1.0, _in_t + delta / IN_TIME)
	_apply_in()


func _apply_in() -> void:
	var e: float = Motion.ease(Motion.SPRING, _in_t)
	_panel.modulate.a = e
	_panel.scale = Vector2.ONE * lerpf(IN_SCALE, 1.0, e)
	_panel.position = _base_pos + Vector2(0.0, IN_LIFT * (1.0 - e))


## `place()` (tooltip.js:56), in stage px because this layer fills the stage.
func _place(at: Vector2, touch: bool) -> void:
	var w: float = _panel.size.x
	var h: float = _panel.size.y
	var stage: Vector2 = size
	var pos: Vector2
	if touch:
		pos = Vector2(
			clampf(at.x - w * 0.5, TOUCH_EDGE, maxf(TOUCH_EDGE, stage.x - w - TOUCH_EDGE)),
			maxf(TOUCH_EDGE, at.y - h - TOUCH_LIFT))
	else:
		pos = Vector2(
			minf(stage.x - w - EDGE_X, at.x + MOUSE_DX),
			clampf(at.y - h * 0.5, EDGE_Y, maxf(EDGE_Y, stage.y - h - EDGE_Y)))
	_base_pos = pos
	_panel.pivot_offset = _panel.size * 0.5
	_apply_in()
