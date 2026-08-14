class_name GlassStyle
extends RefCounted
## Shared procedural palette + stylebox factory for the combat screen. No art,
## no deps — every surface is a StyleBoxFlat / GradientTexture2D tuned to the
## stained-glass night-lantern key: deep indigo ground, pale glass-blue facets,
## ember lantern-fire. Pure factory (RefCounted, static) so the presentation
## layer stays a thin skin over the domain.

const NIGHT_TOP: Color = Color(0.07, 0.08, 0.15)
const NIGHT_MID: Color = Color(0.035, 0.045, 0.095)
const NIGHT_BOT: Color = Color(0.015, 0.02, 0.045)
const GLASS: Color = Color(0.56, 0.82, 1.0)      # #8fd0ff facet blue
const EMBER: Color = Color(1.0, 0.60, 0.30)      # #ff9a4d lantern fire
const GOLD: Color = Color("#f2c14e")             # lantern gold (RunStyle.GOLD)
const INK: Color = Color(0.10, 0.12, 0.19)       # panel body
const TEXT: Color = Color(0.86, 0.90, 1.0)
const TEXT_DIM: Color = Color(0.58, 0.64, 0.80)
const HP_RED: Color = Color(0.85, 0.33, 0.32)


## The benchmark's two faces (roguecardv2@6e069118): Cinzel for display —
## names, cost numerals — and Alegreya for the reading text. Both stay the Latin
## primaries. Noto Serif TC is the complete zh-Hant chain: Regular for reading,
## SemiBold for names/headings, Black for the act plate, then a three-glyph Noto
## Sans Symbols2 subset for the two locale markers and the ticket spelling.
## The lightest weight the benchmark loads, and the one a rule that names no
## `font-weight` lands on: CSS matching for a desired 400 checks 500 before it
## checks anything heavier, and 400 is not in the set. `.enemy .name` is such a
## rule, so a foe's name is 500 on screen and was 700 in this port.
const CINZEL_500: String = "res://assets/fonts/Cinzel-500.woff2"
const CINZEL_700: String = "res://assets/fonts/Cinzel-700.woff2"
const CINZEL_800: String = "res://assets/fonts/Cinzel-800.woff2"
const ALEGREYA_400: String = "res://assets/fonts/Alegreya-400.woff2"
const ALEGREYA_700: String = "res://assets/fonts/Alegreya-700.woff2"
const NOTO_SERIF_TC_REGULAR: String = "res://assets/fonts/NotoSerifTC-Regular.woff2"
const NOTO_SERIF_TC_SEMIBOLD: String = "res://assets/fonts/NotoSerifTC-SemiBold.woff2"
const NOTO_SERIF_TC_BLACK: String = "res://assets/fonts/NotoSerifTC-Black.woff2"
const NOTO_SANS_SYMBOLS_2: String = "res://assets/fonts/NotoSansSymbols2-Glassvow.woff2"

static var _faces: Dictionary = {}


static func _is_serif_tc(path: String) -> bool:
	return path == NOTO_SERIF_TC_REGULAR or path == NOTO_SERIF_TC_SEMIBOLD \
		or path == NOTO_SERIF_TC_BLACK


static func _symbol_face() -> Font:
	var cache_key: String = "symbols"
	if _faces.has(cache_key):
		return _faces[cache_key]
	var symbols: Font = load(NOTO_SANS_SYMBOLS_2) as Font
	_faces[cache_key] = symbols
	return symbols


## Build the CJK/symbol leaf once. Every primary face points at this leaf, so
## its marker glyphs cannot fall through to an OS-specific system font.
static func _serif_tc_face(path: String) -> Font:
	var cache_key: String = "serif:" + path
	if _faces.has(cache_key):
		return _faces[cache_key]
	var serif: Font = load(path) as Font
	var symbols: Font = _symbol_face()
	if serif == null or symbols == null:
		_faces[cache_key] = serif if serif != null else symbols
		return _faces[cache_key]
	var chained: Font = serif.duplicate() as Font
	if chained == null:
		_faces[cache_key] = serif
		return serif
	var chain: Array[Font] = [symbols]
	chained.fallbacks = chain
	_faces[cache_key] = chained
	return chained


## Reading routes to Regular. Display paths (Cinzel plus bold Alegreya) route
## to SemiBold; transition_layer.gd explicitly requests Black for its act plate.
static func _cjk_fallback_for(path: String) -> String:
	if path == ALEGREYA_400 or path == NOTO_SERIF_TC_REGULAR:
		return NOTO_SERIF_TC_REGULAR
	if path == NOTO_SERIF_TC_BLACK:
		return NOTO_SERIF_TC_BLACK
	return NOTO_SERIF_TC_SEMIBOLD


## Load a Latin face with its deterministic serif/symbol fallback leaf. Cached
## by both primary and CJK paths because the same Latin weight has three CJK
## roles: reading, headings, and the act-plate display.
static func face(path: String, cjk_path: String = "") -> Font:
	var resolved_cjk_path: String = cjk_path if not cjk_path.is_empty() else _cjk_fallback_for(path)
	var cache_key: String = path + "|" + resolved_cjk_path
	if _faces.has(cache_key):
		return _faces[cache_key]
	if _is_serif_tc(path):
		var serif: Font = _serif_tc_face(path)
		_faces[cache_key] = serif
		return serif
	var primary: Font = load(path) as Font
	var serif_fallback: Font = _serif_tc_face(resolved_cjk_path)
	var symbols: Font = _symbol_face()
	if primary == null:
		_faces[cache_key] = serif_fallback
		return serif_fallback
	if serif_fallback == null:
		_faces[cache_key] = primary
		return primary
	var chained: Font = primary.duplicate() as Font
	if chained == null:
		_faces[cache_key] = primary
		return primary
	var chain: Array[Font] = [serif_fallback]
	if symbols != null:
		chain.append(symbols)
	chained.fallbacks = chain
	_faces[cache_key] = chained
	return chained


## Canonical modal veil — flat (no blur; backbuffer budget). Shared by Help,
## Settings, reward overlays, and ChoiceScreen overlay mode. RunMenu keeps a
## transparent hit-catcher; it is not a veil. The grain above is deliberately
## not frozen with the world beneath: a held screen must not read as a still.
static func scrim() -> Color:
	return Color(5.0 / 255.0, 7.0 / 255.0, 16.0 / 255.0, 0.72)


## Floating glass placard: translucent ink body, faint accent rim, soft glow.
static func pane(accent: Color, alpha: float = 0.80) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(INK.r, INK.g, INK.b, alpha)
	sb.set_border_width_all(1)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.42)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.14)
	sb.shadow_size = 10
	return sb


## `.stat-cell` (styles.css:1813): a flat white-tinted cell with NO
## shadow. The end screens' grids sat on gold panes whose 10px glows stacked
## in the 6px gutters — a lattice of bright seams the benchmark never draws.
static func stat_cell() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 1.0, 1.0, 0.045)
	sb.set_border_width_all(1)
	sb.border_color = Color(1.0, 1.0, 1.0, 0.1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


## Small rounded pill (intent / ward / status).
static func chip(fill: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(fill.r, fill.g, fill.b, 0.18)
	sb.set_border_width_all(1)
	sb.border_color = Color(fill.r, fill.g, fill.b, 0.72)
	sb.set_corner_radius_all(11)
	sb.content_margin_left = 11
	sb.content_margin_right = 11
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb


## Bright circular gem for the card cost corner.
static func gem(fill: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(fill.r, fill.g, fill.b, 0.95)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 1.0, 1.0, 0.35)
	sb.shadow_color = Color(fill.r, fill.g, fill.b, 0.45)
	sb.shadow_size = 6
	return sb


## The lantern ring — the one keyboard-focus treatment every glass surface
## shares. `draw_center = false` so it lays OVER whichever state box is
## showing without repainting it; the ring is the leading, the glow is the
## lantern behind it. Expanded 2px so it reads as an addition around the
## control, not a swap of its border. The glow outbids the hover box's own
## (0.35 @ 8px) so the persistent keyboard state is never out-glowed by
## the transient pointer state.
##
## ADOPTION PREREQUISITE: a surface that pushes its own "focus" stylebox
## shadows this ring entirely — an opaque focus box repainting the hover
## wash away is exactly the SettingsPanel focus≡hover defect. To adopt,
## DELETE "focus" from your state loop and let this overlay carry it.
static func focus_ring(accent: Color = GOLD, body_radius: int = 12) -> StyleBoxFlat:
	var ring: StyleBoxFlat = StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_border_width_all(2)
	ring.border_color = Color(accent, 0.85)
	# Concentric with the CONTROL it rings: the ring rides a rect expanded
	# 2px, so its radius is the adopter's own body radius plus that — a
	# fixed 14 sat ON the corner of every radius-6-8 adopter (DL, PR #43).
	ring.set_corner_radius_all(body_radius + 2)
	ring.set_expand_margin_all(2.0)
	ring.shadow_color = Color(accent, 0.45)
	ring.shadow_size = 8
	return ring


static func style_button(btn: Button, fill: Color) -> void:
	btn.add_theme_stylebox_override("focus", focus_ring(fill))
	var states: PackedStringArray = PackedStringArray(["normal", "hover", "pressed", "disabled"])
	for state: String in states:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		var a: float = 0.24
		if state == "hover":
			a = 0.38
		elif state == "pressed":
			a = 0.15
		elif state == "disabled":
			a = 0.07
		sb.bg_color = Color(fill.r, fill.g, fill.b, a)
		sb.set_border_width_all(1)
		var rim: float = 0.25 if state == "disabled" else 0.7
		sb.border_color = Color(fill.r, fill.g, fill.b, rim)
		sb.set_corner_radius_all(12)
		sb.set_content_margin_all(10)
		if state == "hover":
			sb.shadow_color = Color(fill.r, fill.g, fill.b, 0.35)
			sb.shadow_size = 8
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_disabled_color", TEXT_DIM)
	# Unset, these fall back to Godot's neutral defaults (0.95 grey and pure
	# white) — a focused or pressed button would shed the glass ink exactly
	# while it is selected.
	btn.add_theme_color_override("font_focus_color", TEXT)
	btn.add_theme_color_override("font_pressed_color", TEXT)


static func style_bar(bar: ProgressBar, fill: Color) -> void:
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.03, 0.06, 0.92)
	bg.set_corner_radius_all(5)
	bg.set_border_width_all(1)
	bg.border_color = Color(fill.r, fill.g, fill.b, 0.28)
	var fg: StyleBoxFlat = StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)


static func grad_tex(colors: PackedColorArray, offsets: PackedFloat32Array,
		radial: bool, from: Vector2, to: Vector2) -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.offsets = offsets
	g.colors = colors
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL if radial else GradientTexture2D.FILL_LINEAR
	tex.fill_from = from
	tex.fill_to = to
	tex.width = 256
	tex.height = 256
	return tex


## Lantern grabber shared by HSlider / VSlider. Settings used to paint this
## per-instance; the canonical Theme carries it so a raw slider is never gray.
static func disc(colour: Color, alpha: float = 1.0, size: int = 16) -> GradientTexture2D:
	var texture: GradientTexture2D = grad_tex(
		PackedColorArray([Color(colour, alpha), Color(colour, alpha * 0.45),
			Color(colour, 0.0)]),
		PackedFloat32Array([0.0, 0.52, 1.0]), true,
		Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	texture.width = size
	texture.height = size
	return texture


## Canonical Theme from RunStyle / GlassStyle tokens. Applied on Main; every
## routed Control inherits it. Per-instance helpers still override geometry
## (compact radius, primary CTA, card seats) — they do not fork the palette.
static func theme() -> Theme:
	var t: Theme = Theme.new()
	# Keep the default UI face in the runtime resource chain. A project-level
	# custom font is resolved before cache-cold import has produced its fontdata,
	# while this factory runs only after resources are ready.
	t.default_font = face(NOTO_SERIF_TC_REGULAR)
	t.default_font_size = 15
	_theme_type(t)
	_theme_chrome(t)
	_theme_fields(t)
	_theme_toggles(t)
	return t


static func _theme_type(t: Theme) -> void:
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", 15)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_color("selection_color", "RichTextLabel", Color(GOLD, 0.28))
	t.set_font("normal_font", "RichTextLabel", face(ALEGREYA_400))
	t.set_font_size("normal_font_size", "RichTextLabel", 15)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 13)
	t.set_stylebox("panel", "TooltipPanel", pane(GOLD, 0.94))
	_theme_button_type(t, "Button")
	_theme_button_type(t, "OptionButton")
	t.set_icon("arrow", "OptionButton", _chevron(GOLD))
	t.set_constant("arrow_margin", "OptionButton", 6)
	t.set_constant("modulate_arrow", "OptionButton", 1)


static func _theme_button_type(t: Theme, type_name: String) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(state, type_name, RunStyle.button_stylebox(state))
	# Radius 8 matches the unstyled secondary box above. Custom-radius
	# surfaces still push their own ring so it stays concentric (PR #43).
	t.set_stylebox("focus", type_name, focus_ring(GOLD, 8))
	t.set_color("font_color", type_name, RunStyle.PARCHMENT)
	t.set_color("font_hover_color", type_name, GOLD)
	t.set_color("font_pressed_color", type_name, RunStyle.PARCHMENT)
	t.set_color("font_focus_color", type_name, RunStyle.PARCHMENT)
	t.set_color("font_hover_pressed_color", type_name, GOLD)
	t.set_color("font_disabled_color", type_name, Color(TEXT_DIM, 0.45))
	t.set_font_size("font_size", type_name, 15)


static func _theme_chrome(t: Theme) -> void:
	t.set_stylebox("panel", "Panel", RunStyle.panel())
	t.set_stylebox("panel", "PanelContainer", RunStyle.panel())
	t.set_stylebox("panel", "PopupPanel", RunStyle.panel(8, 10, 0.94))
	t.set_stylebox("panel", "AcceptDialog", RunStyle.panel(12, 16, 0.92))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("focus", "ScrollContainer", StyleBoxEmpty.new())
	var rule: StyleBoxLine = StyleBoxLine.new()
	rule.color = Color(GOLD, 0.22)
	rule.thickness = 1
	t.set_stylebox("separator", "HSeparator", rule)
	var v_rule: StyleBoxLine = StyleBoxLine.new()
	v_rule.color = Color(GOLD, 0.22)
	v_rule.thickness = 1
	v_rule.vertical = true
	t.set_stylebox("separator", "VSeparator", v_rule)
	var menu_hover: StyleBoxFlat = _fill(Color(GOLD, 0.14), 6, Color(GOLD, 0.40), 1, 6.0)
	t.set_stylebox("panel", "PopupMenu", RunStyle.panel(8, 10, 0.94))
	t.set_stylebox("hover", "PopupMenu", menu_hover)
	t.set_stylebox("separator", "PopupMenu", rule)
	t.set_stylebox("labeled_separator_left", "PopupMenu", rule)
	t.set_stylebox("labeled_separator_right", "PopupMenu", rule)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", GOLD)
	t.set_color("font_disabled_color", "PopupMenu", Color(TEXT_DIM, 0.45))
	t.set_color("font_separator_color", "PopupMenu", Color(GOLD, 0.45))
	t.set_color("font_accelerator_color", "PopupMenu", TEXT_DIM)
	var check_on: Texture2D = _box_icon(Color(GOLD, 0.90), GOLD)
	var check_off: Texture2D = _box_icon(Color.TRANSPARENT, Color(GOLD, 0.55))
	var check_on_dim: Texture2D = _box_icon(Color(GOLD, 0.35), Color(GOLD, 0.30))
	var check_off_dim: Texture2D = _box_icon(Color.TRANSPARENT, Color(GOLD, 0.22))
	t.set_icon("checked", "PopupMenu", check_on)
	t.set_icon("unchecked", "PopupMenu", check_off)
	t.set_icon("checked_disabled", "PopupMenu", check_on_dim)
	t.set_icon("unchecked_disabled", "PopupMenu", check_off_dim)
	t.set_icon("radio_checked", "PopupMenu", _circle_icon(Color(GOLD, 0.90), GOLD))
	t.set_icon("radio_unchecked", "PopupMenu", _circle_icon(Color.TRANSPARENT, Color(GOLD, 0.55)))
	t.set_icon("radio_checked_disabled", "PopupMenu",
		_circle_icon(Color(GOLD, 0.35), Color(GOLD, 0.30)))
	t.set_icon("radio_unchecked_disabled", "PopupMenu",
		_circle_icon(Color.TRANSPARENT, Color(GOLD, 0.22)))
	_theme_scroll(t, "VScrollBar")
	_theme_scroll(t, "HScrollBar")
	var bar_bg: StyleBoxFlat = _fill(Color(0.02, 0.03, 0.06, 0.92), 5, Color(GOLD, 0.28), 1)
	var bar_fg: StyleBoxFlat = _fill(GOLD, 5)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fg)
	t.set_color("font_color", "ProgressBar", TEXT)
	_theme_slider(t, "HSlider")
	_theme_slider(t, "VSlider")


static func _theme_scroll(t: Theme, type_name: String) -> void:
	var track: StyleBoxFlat = _fill(Color(0.02, 0.03, 0.06, 0.90), 4)
	track.set_content_margin_all(3.0)
	var focus_track: StyleBoxFlat = _fill(
		Color(0.02, 0.03, 0.06, 0.90), 4, Color(GOLD, 0.42), 1)
	focus_track.set_content_margin_all(3.0)
	t.set_stylebox("scroll", type_name, track)
	t.set_stylebox("scroll_focus", type_name, focus_track)
	t.set_stylebox("grabber", type_name, _fill(Color(GOLD, 0.55), 4))
	t.set_stylebox("grabber_highlight", type_name, _fill(Color(GOLD, 0.85), 4))
	t.set_stylebox("grabber_pressed", type_name, _fill(GOLD, 4))
	var blank: PlaceholderTexture2D = PlaceholderTexture2D.new()
	blank.size = Vector2.ZERO
	for icon_name: String in [
		"increment", "increment_highlight", "increment_pressed",
		"decrement", "decrement_highlight", "decrement_pressed",
	]:
		t.set_icon(icon_name, type_name, blank)


static func _theme_slider(t: Theme, type_name: String) -> void:
	var track: StyleBoxFlat = _fill(Color(0.02, 0.03, 0.06, 0.90), 3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill: StyleBoxFlat = _fill(GOLD, 3)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("slider", type_name, track)
	t.set_stylebox("grabber_area", type_name, fill)
	t.set_stylebox("grabber_area_highlight", type_name, fill)
	var grabber: Texture2D = disc(GOLD, 1.0)
	t.set_icon("grabber", type_name, grabber)
	t.set_icon("grabber_highlight", type_name, grabber)
	t.set_icon("grabber_disabled", type_name, disc(TEXT_DIM, 0.45))


static func _theme_fields(t: Theme) -> void:
	var field: StyleBoxFlat = _fill(Color(INK.r, INK.g, INK.b, 0.80), 8,
		Color(GOLD, 0.28), 1, 8.0)
	var field_read: StyleBoxFlat = _fill(Color(INK.r, INK.g, INK.b, 0.45), 8,
		Color(GOLD, 0.12), 1, 8.0)
	for type_name: String in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", type_name, field)
		t.set_stylebox("focus", type_name, focus_ring(GOLD, 8))
		t.set_stylebox("read_only", type_name, field_read)
		t.set_color("font_color", type_name, TEXT)
		t.set_color("font_uneditable_color", type_name, TEXT_DIM)
		t.set_color("font_placeholder_color", type_name, TEXT_DIM)
		t.set_color("caret_color", type_name, GOLD)
		t.set_color("selection_color", type_name, Color(GOLD, 0.28))
		t.set_font_size("font_size", type_name, 15)
	t.set_color("font_readonly_color", "TextEdit", TEXT_DIM)
	t.set_color("background_color", "TextEdit", Color(0, 0, 0, 0))
	t.set_stylebox("panel", "ItemList", pane(GOLD, 0.80))
	t.set_stylebox("focus", "ItemList", focus_ring(GOLD, 12))
	t.set_stylebox("hovered", "ItemList", _fill(Color(GOLD, 0.10), 6))
	t.set_stylebox("selected", "ItemList", _fill(Color(GOLD, 0.16), 6, Color(GOLD, 0.40), 1))
	t.set_stylebox("selected_focus", "ItemList",
		_fill(Color(GOLD, 0.22), 6, Color(GOLD, 0.70), 1))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_hovered_color", "ItemList", GOLD)
	t.set_color("font_selected_color", "ItemList", RunStyle.PARCHMENT)


static func _theme_toggles(t: Theme) -> void:
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	var check_on: Texture2D = _box_icon(Color(GOLD, 0.90), GOLD)
	var check_off: Texture2D = _box_icon(Color.TRANSPARENT, Color(GOLD, 0.55))
	var check_on_dim: Texture2D = _box_icon(Color(GOLD, 0.35), Color(GOLD, 0.30))
	var check_off_dim: Texture2D = _box_icon(Color.TRANSPARENT, Color(GOLD, 0.22))
	for type_name: String in ["CheckBox", "CheckButton"]:
		for state: String in ["normal", "pressed", "disabled", "hover", "hover_pressed"]:
			t.set_stylebox(state, type_name, empty)
		t.set_stylebox("focus", type_name, focus_ring(GOLD, 6))
		t.set_color("font_color", type_name, TEXT)
		t.set_color("font_pressed_color", type_name, GOLD)
		t.set_color("font_hover_color", type_name, GOLD)
		t.set_color("font_hover_pressed_color", type_name, GOLD)
		t.set_color("font_focus_color", type_name, TEXT)
		t.set_color("font_disabled_color", type_name, Color(TEXT_DIM, 0.45))
		t.set_font_size("font_size", type_name, 14)
	t.set_icon("checked", "CheckBox", check_on)
	t.set_icon("unchecked", "CheckBox", check_off)
	t.set_icon("checked_disabled", "CheckBox", check_on_dim)
	t.set_icon("unchecked_disabled", "CheckBox", check_off_dim)
	t.set_icon("radio_checked", "CheckBox", _circle_icon(Color(GOLD, 0.90), GOLD))
	t.set_icon("radio_unchecked", "CheckBox", _circle_icon(Color.TRANSPARENT, Color(GOLD, 0.55)))
	t.set_icon("radio_checked_disabled", "CheckBox",
		_circle_icon(Color(GOLD, 0.35), Color(GOLD, 0.30)))
	t.set_icon("radio_unchecked_disabled", "CheckBox",
		_circle_icon(Color.TRANSPARENT, Color(GOLD, 0.22)))
	t.set_color("checkbox_checked_color", "CheckBox", Color.WHITE)
	t.set_color("checkbox_unchecked_color", "CheckBox", Color.WHITE)
	var sw_on: Texture2D = _switch_icon(true, false)
	var sw_off: Texture2D = _switch_icon(false, false)
	t.set_icon("checked", "CheckButton", sw_on)
	t.set_icon("unchecked", "CheckButton", sw_off)
	t.set_icon("checked_disabled", "CheckButton", _switch_icon(true, true))
	t.set_icon("unchecked_disabled", "CheckButton", _switch_icon(false, true))
	t.set_icon("checked_mirrored", "CheckButton", sw_on)
	t.set_icon("unchecked_mirrored", "CheckButton", sw_off)
	t.set_icon("checked_disabled_mirrored", "CheckButton", _switch_icon(true, true))
	t.set_icon("unchecked_disabled_mirrored", "CheckButton", _switch_icon(false, true))
	t.set_color("button_checked_color", "CheckButton", Color.WHITE)
	t.set_color("button_unchecked_color", "CheckButton", Color.WHITE)


static func _fill(bg: Color, radius: int, border: Color = Color.TRANSPARENT,
		width: int = 0, margin: float = 0.0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if width > 0:
		sb.set_border_width_all(width)
		sb.border_color = border
	if margin > 0.0:
		sb.set_content_margin_all(margin)
	return sb


static func _box_icon(fill: Color, stroke: Color, size: int = 14) -> ImageTexture:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	img.fill_rect(Rect2i(0, 0, size, size), stroke)
	img.fill_rect(Rect2i(1, 1, size - 2, size - 2), fill)
	return ImageTexture.create_from_image(img)


static func _circle_icon(fill: Color, stroke: Color, size: int = 14) -> ImageTexture:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var c: float = float(size - 1) * 0.5
	var outer: float = c - 0.4
	var inner: float = outer - 1.4
	for y: int in range(size):
		for x: int in range(size):
			var d: float = Vector2(float(x) - c, float(y) - c).length()
			if d <= inner and fill.a > 0.0:
				img.set_pixel(x, y, fill)
			elif d <= outer and d > inner:
				img.set_pixel(x, y, stroke)
			elif d <= outer and fill.a > 0.0:
				img.set_pixel(x, y, fill)
	return ImageTexture.create_from_image(img)


static func _switch_icon(on: bool, disabled: bool) -> ImageTexture:
	var w: int = 28
	var h: int = 16
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var body: Color = Color(GOLD, 0.55 if on else 0.10)
	var rim: Color = Color(GOLD, 0.85 if on else 0.28)
	if disabled:
		body.a *= 0.45
		rim.a *= 0.45
	if not on:
		body = Color(INK.r, INK.g, INK.b, 0.80 if not disabled else 0.40)
	img.fill_rect(Rect2i(0, 0, w, h), rim)
	img.fill_rect(Rect2i(1, 1, w - 2, h - 2), body)
	var knob: Color = Color(RunStyle.PARCHMENT, 0.95 if not disabled else 0.45)
	var knob_x: int = w - 14 if on else 2
	img.fill_rect(Rect2i(knob_x, 2, 12, h - 4), knob)
	return ImageTexture.create_from_image(img)


static func _chevron(colour: Color, w: int = 11, h: int = 7) -> ImageTexture:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var mid: int = int(float(w - 1) / 2.0)
	var last: int = maxi(h - 1, 1)
	for y: int in range(h):
		var span: int = roundi(float(mid) * float(y) / float(last))
		for x: int in range(mid - span, mid + span + 1):
			if x >= 0 and x < w:
				img.set_pixel(x, y, colour)
	return ImageTexture.create_from_image(img)
