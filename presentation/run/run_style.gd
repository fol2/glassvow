class_name RunStyle
extends RefCounted
## Exact benchmark tokens for title-to-run presentation surfaces.

const GOLD: Color = Color("#f2c14e")
const GOLD_DIM: Color = Color("#9c7c34")
const INK: Color = Color("#0b0e1a")
const PARCHMENT: Color = Color("#e8dfc8")
const TEXT: Color = Color("#d7dcea")
const TEXT_DIM: Color = Color("#8b93ad")
const PANEL: Color = Color(0.055, 0.071, 0.133, 0.86)
const PANEL_LINE: Color = Color(GOLD, 0.28)
const DANGER: Color = Color("#ff8d8d")


static func add_backdrop(parent: Control) -> void:
	parent.add_child(TitleWorld.new())
	var vignette: TextureRect = TextureRect.new()
	vignette.texture = GlassStyle.grad_tex(
		PackedColorArray([
			Color(0.016, 0.020, 0.047, 0.0),
			Color(0.016, 0.020, 0.047, 0.0),
			Color(0.016, 0.020, 0.047, 0.55),
		]),
		PackedFloat32Array([0.0, 0.55, 1.0]), true,
		Vector2(0.5, 0.45), Vector2(1.0, 0.45))
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(vignette)


static func tracked(path: String, glyph_spacing: int) -> FontVariation:
	var font: FontVariation = FontVariation.new()
	font.base_font = load(path) as Font
	font.spacing_glyph = glyph_spacing
	return font


static func panel(radius: int = 12, inset: float = 16.0,
		alpha: float = 0.86) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(PANEL, alpha)
	style.set_border_width_all(1)
	style.border_color = PANEL_LINE
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(inset)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	style.shadow_size = 18
	return style


static func style_button(button: Button, primary: bool = false,
		accent: Color = GOLD, compact: bool = false) -> void:
	var vertical: float = 4.0 if compact else 8.0
	var radius: int = 6 if compact else 8
	# "focus" is deliberately NOT in this loop: an opaque focus box shadows
	# the shared lantern ring (GlassStyle.focus_ring's ADOPTION PREREQUISITE)
	# and leaves keyboard focus indistinguishable from rest — which is what
	# this loop did before P4.5. A primary CTA is an OPAQUE gold body, so a
	# gold ring flush against it reads as the button thickening — the ring
	# borrows the glass blue instead, the one accent that cannot dissolve
	# into the body it rings.
	button.add_theme_stylebox_override("focus",
		GlassStyle.focus_ring(GlassStyle.GLASS if primary else accent, radius))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		if primary:
			style.bg_color = Color("#f2c14e") if state != "pressed" else Color("#c89a30")
			style.border_color = Color.TRANSPARENT
		else:
			style.bg_color = Color(0.055, 0.071, 0.133, 0.60)
			style.border_color = Color(accent, 0.28 if state == "normal" else 0.82)
		style.set_border_width_all(1)
		style.set_corner_radius_all(radius)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = vertical
		style.content_margin_bottom = vertical
		if state == "hover":
			style.shadow_color = Color(accent, 0.24)
			style.shadow_size = 10
		elif state == "disabled":
			style.bg_color = Color(style.bg_color, style.bg_color.a * 0.45)
			style.border_color = Color(style.border_color, style.border_color.a * 0.45)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", INK if primary else PARCHMENT)
	button.add_theme_color_override("font_hover_color", INK if primary else GOLD)
	button.add_theme_color_override("font_pressed_color", INK if primary else PARCHMENT)
	# Unset, focus falls back to Godot's neutral grey — a primary CTA would
	# shed its ink exactly while a keyboard player has it selected.
	button.add_theme_color_override("font_focus_color", INK if primary else PARCHMENT)
	button.add_theme_color_override("font_disabled_color", Color(TEXT_DIM, 0.45))


static func style_card(button: Button, selected: bool) -> void:
	# Same adoption as style_button: the ring overlays, never repaints.
	button.add_theme_stylebox_override("focus", GlassStyle.focus_ring(GOLD, 14))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.118, 0.102, 0.055, 0.50) if selected \
			else Color(0.055, 0.071, 0.133, 0.72)
		style.set_border_width_all(2 if selected else 1)
		style.border_color = GOLD if selected or state == "hover" else PANEL_LINE
		style.set_corner_radius_all(14)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 10
		style.content_margin_bottom = 11
		if selected:
			style.shadow_color = Color(GOLD, 0.20)
			style.shadow_size = 14
		elif state == "hover":
			style.shadow_color = Color(GOLD, 0.12)
			style.shadow_size = 10
		button.add_theme_stylebox_override(state, style)
