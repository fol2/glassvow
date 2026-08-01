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
## names, cost numerals — and Alegreya for the reading text. Both OFL, bundled
## alongside NotoSansTC, which stays the UI face because these two carry no CJK.
## The lightest weight the benchmark loads, and the one a rule that names no
## `font-weight` lands on: CSS matching for a desired 400 checks 500 before it
## checks anything heavier, and 400 is not in the set. `.enemy .name` is such a
## rule, so a foe's name is 500 on screen and was 700 in this port.
const CINZEL_500: String = "res://assets/fonts/Cinzel-500.woff2"
const CINZEL_700: String = "res://assets/fonts/Cinzel-700.woff2"
const CINZEL_800: String = "res://assets/fonts/Cinzel-800.woff2"
const ALEGREYA_400: String = "res://assets/fonts/Alegreya-400.woff2"
const ALEGREYA_700: String = "res://assets/fonts/Alegreya-700.woff2"


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
static func focus_ring(accent: Color = GOLD) -> StyleBoxFlat:
	var ring: StyleBoxFlat = StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_border_width_all(2)
	ring.border_color = Color(accent, 0.85)
	ring.set_corner_radius_all(14)
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


## Root theme: default label/button color + size so children stay coherent
## without per-node overrides.
static func theme() -> Theme:
	var t: Theme = Theme.new()
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", 15)
	t.set_color("font_color", "Button", TEXT)
	t.set_font_size("font_size", "Button", 15)
	# A gold-ring default for buttons nobody styled. Reach is honest, not
	# total: RunStyle's button/card loops and both panels still push their
	# own opaque "focus" boxes that shadow this — deleting those is the
	# P4.5/P4.6 adoption work (see focus_ring's ADOPTION PREREQUISITE).
	t.set_stylebox("focus", "Button", focus_ring())
	return t
